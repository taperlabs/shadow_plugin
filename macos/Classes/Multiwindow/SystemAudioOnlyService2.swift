import Foundation
import AVFoundation
import CoreAudio
import AudioToolbox
import AVFAudio

class SystemAudioOnlyService: ObservableObject {
    private var tap: AudioObjectID = 0
    private var aggregateDevice: AudioObjectID = 0
    private var procID: AudioDeviceIOProcID?
    
    // Asset Writer properties
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private let prepareIntervalBeforeRotation: TimeInterval = 5 // Prepare new writer 5 seconds before rotation
    private var prepareRotationTimer: Timer?
    private var nextAssetWriter: AVAssetWriter?
    private var nextAssetWriterInput: AVAssetWriterInput?
    
    // File rotation properties
    private var rotationTimer: Timer?
    private var segmentCounter: Int = 0
    private var segmentFileURLs: [Int: URL] = [:]
    private var baseFileURL: URL?
    private var isRotationInProgress = false
    private let rotationInterval: TimeInterval = 60.0 // 60 seconds per file
    
    
    private var currentFileName: String = ""
    private var currentSegmentIndex: Int = 0
    private var nextSegmentIndex: Int = 1
    private var nextFileName: String = ""
    
    // Track segment start time with high precision
    private var segmentStartTime: CFTimeInterval = 0
    
    // Queue for thread safety
    private let writerQueue = DispatchQueue(label: "com.audiorecorder.writer", qos: .userInitiated)
    
    // File naming properties
    private var sessionId: String = ""
    private var baseFilename: String = "SystemAudio"
    
    // Keep track of running state
    @Published private(set) var isRunning = false
    
    // Also add cleanup in deinit to ensure resources are freed
    deinit {
        stopRecording()
    }
    
    func getPropertyAddress(selector: AudioObjectPropertySelector,
                            scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                            element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        return AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }
    
    // New method to create a file URL for the current segment
    private func createFileURL() -> URL? {
        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("❌ Unable to find directory URL")
            return nil
        }
        
        let appSpecificDirectoryURL = appSupportDirectory.appendingPathComponent("com.taperlabs.shadow")
        
        // Use the format: UUID-BaseFilename-SegmentNumber.m4a
        let filename = "\(baseFilename)-\(segmentCounter).m4a"
        return appSpecificDirectoryURL.appendingPathComponent(filename)
    }
    
    // New method to setup a new asset writer
    private func setupNewAssetWriter(with originalStreamDescription: AudioStreamBasicDescription, isInitial: Bool = false) throws -> (AVAssetWriter, AVAssetWriterInput) {
        guard let fileURL = createFileURL() else {
            throw NSError(domain: "Unable to create file URL", code: -1)
        }
        
        // Store the URL for this segment
        segmentFileURLs[segmentCounter] = fileURL
        
        // Remove existing file if needed
        try? FileManager.default.removeItem(at: fileURL)
        
        // Create asset writer
        let writer = try AVAssetWriter(outputURL: fileURL, fileType: .m4a)
        
        let audioOutputSettings = AudioSetting.setAudioConfiguration(
            format: .mpeg4AAC,
            channels: .mono,
            sampleRate: .rate16K
        )
        
        // Create asset writer input
        let writerInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: audioOutputSettings
        )
        writerInput.expectsMediaDataInRealTime = true
        
        if writer.canAdd(writerInput) {
            writer.add(writerInput)
        } else {
            throw NSError(domain: "Cannot add writer input", code: -1)
        }
        
        // Start asset writer
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        
        // Increment segment counter for next file
        if isInitial {
            print("Skipping += segmentCounter because It's Initial")
            return (writer, writerInput)
        }
        currentSegmentIndex = segmentCounter
        segmentCounter += 1
        
        print("📝 Created new file segment: \(fileURL.lastPathComponent)")
        return (writer, writerInput)
    }
    
    // New method to handle file rotation
    @objc private func rotateFile() {
        // Calculate actual elapsed time since last rotation
        let currentTime = CACurrentMediaTime()
        let elapsedTime = currentTime - segmentStartTime
        print("🕒 Rotation triggered at \(elapsedTime) seconds since last rotation")
        
        let completedSegmentIndex = self.currentSegmentIndex - 1
        let completedFileURL = self.segmentFileURLs[completedSegmentIndex]
        let completedFileName = completedFileURL?.lastPathComponent ?? "\(self.baseFilename)-\(completedSegmentIndex).m4a"
        
        print("⭐️ Rotation triggered the file completed -- \(completedFileName), index == \(completedSegmentIndex), \(self.segmentFileURLs)")
        
        writerQueue.async { [weak self] in
            guard let self = self,
                  !self.isRotationInProgress,
                  self.isRunning else { return }
            
            print("🔄 Rotating audio file...")
            self.isRotationInProgress = true
            
            // Finish current writer
            let oldWriter = self.assetWriter
            let oldInput = self.assetWriterInput
            
            // Mark old input as finished
            oldInput?.markAsFinished()
            
            // Finish old writer asynchronously
            oldWriter?.finishWriting { [weak self] in
                print("✅ Finished writing previous audio segment")
                
                // Notify the ListeningCoordinator about the completed segment
                DispatchQueue.main.async {
                    ListeningCoordinator.shared.handleSystemAudioSegment(
                        index: completedSegmentIndex,
                        fileName: completedFileName
                    )
                }
            }
            
            // Check if we have a prepared writer ready
            if let preparedWriter = self.nextAssetWriter, let preparedInput = self.nextAssetWriterInput {
                print("✅ Using pre-prepared writer for seamless transition")
                
                // Update current writer and input with the prepared ones
                self.assetWriter = preparedWriter
                self.assetWriterInput = preparedInput
                self.nextAssetWriter = nil
                self.nextAssetWriterInput = nil
            } else {
                // Fallback: create a new writer on the spot
                print("⚠️ No prepared writer available, creating one now")
                
                // Get current format for creating new writer
                var address = AudioObjectPropertyAddress(
                    mSelector: kAudioTapPropertyFormat,
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                
                var originalStreamDescription = AudioStreamBasicDescription()
                var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
                
                let formatStatus = AudioObjectGetPropertyData(
                    self.tap,
                    &address,
                    0,
                    nil,
                    &size,
                    &originalStreamDescription
                )
                
                guard formatStatus == noErr else {
                    print("❌ Failed to get audio format for rotation")
                    self.isRotationInProgress = false
                    return
                }
                
                // Create a new writer
                do {
                    let (newWriter, newInput) = try self.setupNewAssetWriter(with: originalStreamDescription)
                    self.assetWriter = newWriter
                    self.assetWriterInput = newInput
                } catch {
                    print("❌ Failed to create new writer during rotation: \(error.localizedDescription)")
                    self.isRotationInProgress = false
                    return
                }
            }
            
            // Update segment start time for next segment
            self.segmentStartTime = CACurrentMediaTime()
            
 
            
            self.isRotationInProgress = false
        }
    }
    
    private func startIOProc() throws {
        var procID: AudioDeviceIOProcID?
        
        // First get the tap's audio format
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyFormat,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var originalStreamDescription = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        
        let formatStatus = AudioObjectGetPropertyData(
            tap,
            &address,
            0,
            nil,
            &size,
            &originalStreamDescription
        )
        
        print("Original format:")
        print(" Sample Rate: \(originalStreamDescription.mSampleRate)")
        print(" Channels: \(originalStreamDescription.mChannelsPerFrame)")
        
        // Initialize first file and asset writer
        let (writer, writerInput) = try setupNewAssetWriter(with: originalStreamDescription)
        self.assetWriter = writer
        self.assetWriterInput = writerInput
        
        // Initialize with precise timing using CACurrentMediaTime
        self.segmentStartTime = CACurrentMediaTime()
        
        // Create format for working with the input
        guard let inputFormat = AVAudioFormat(streamDescription: &originalStreamDescription) else {
            print("❌ Failed to create AVAudioFormat from stream description")
            print("Stream description: \(originalStreamDescription)")  // Add more logging
            throw NSError(domain: "Failed to create audio format", code: -1)
        }
        
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: AVAudioChannelCount(originalStreamDescription.mChannelsPerFrame),
            interleaved: false
        )!
        
        guard let _ = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw NSError(domain: "Failed to create audio converter", code: -1)
        }
        
        let status = AudioDeviceCreateIOProcIDWithBlock(&procID,
                                                        aggregateDevice,
                                                        nil) { [weak self] timestamp, inData, inTime, outData, outTime in
            guard let self = self else { return }
            
            // Use captured reference to prevent race condition with rotation
            self.writerQueue.sync {
                // Skip if rotation is in progress
                if self.isRotationInProgress {
                    return
                }
                
                // Skip if writer input isn't ready
                guard let writerInput = self.assetWriterInput,
                      writerInput.isReadyForMoreMediaData else { return }
                
                guard let format = AVAudioFormat(streamDescription: &originalStreamDescription) else {
                    print("❌ Failed to create AVAudioFormat from stream description")
                    return
                }
                
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    bufferListNoCopy: inData,
                    deallocator: nil
                ) else {
                    print("❌ Failed to create PCM buffer")
                    return
                }
                
                // Calculate presentation time
                let sampleTime = timestamp.pointee.mSampleTime
                let sampleRate = originalStreamDescription.mSampleRate
                let presentationTime = CMTime(seconds: Double(sampleTime) / sampleRate, preferredTimescale: 44100)
                
                buffer.frameLength = buffer.frameCapacity
                
                // Create CMBlockBuffer
                var blockBuffer: CMBlockBuffer?
                let blockSize = Int(buffer.frameLength) * Int(format.streamDescription.pointee.mBytesPerFrame)
                
                let blockStatus = CMBlockBufferCreateWithMemoryBlock(
                    allocator: kCFAllocatorDefault,
                    memoryBlock: nil,
                    blockLength: blockSize,
                    blockAllocator: kCFAllocatorDefault,
                    customBlockSource: nil,
                    offsetToData: 0,
                    dataLength: blockSize,
                    flags: 0,
                    blockBufferOut: &blockBuffer
                )
                
                guard blockStatus == noErr, let blockBuffer = blockBuffer else {
                    print("❌ Failed to create block buffer")
                    return
                }
                
                // Copy audio data to block buffer
                CMBlockBufferReplaceDataBytes(
                    with: buffer.audioBufferList.pointee.mBuffers.mData!.assumingMemoryBound(to: UInt8.self),
                    blockBuffer: blockBuffer,
                    offsetIntoDestination: 0,
                    dataLength: blockSize
                )
                
                // Create audio format description
                var formatDescription: CMAudioFormatDescription?
                var asbd = format.streamDescription.pointee
                
                let formatStatus = CMAudioFormatDescriptionCreate(
                    allocator: kCFAllocatorDefault,
                    asbd: &asbd,
                    layoutSize: 0,
                    layout: nil,
                    magicCookieSize: 0,
                    magicCookie: nil,
                    extensions: nil,
                    formatDescriptionOut: &formatDescription
                )
                
                guard formatStatus == noErr, let formatDescription = formatDescription else {
                    print("❌ Failed to create format description")
                    return
                }
                
                // Create sample buffer
                var sampleBuffer: CMSampleBuffer?
                var timingInfo = CMSampleTimingInfo(
                    duration: CMTime(value: CMTimeValue(buffer.frameLength), timescale: CMTimeScale(format.sampleRate)),
                    presentationTimeStamp: presentationTime,
                    decodeTimeStamp: .invalid
                )
                
                let sampleStatus = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                    allocator: kCFAllocatorDefault,
                    dataBuffer: blockBuffer,
                    formatDescription: formatDescription,
                    sampleCount: CMItemCount(buffer.frameLength),
                    presentationTimeStamp: presentationTime,
                    packetDescriptions: nil,
                    sampleBufferOut: &sampleBuffer
                )
                
                if sampleStatus == noErr, let sampleBuffer = sampleBuffer {
                    writerInput.append(sampleBuffer)
                } else {
                    print("❌ Failed to create or append sample buffer")
                }
            }
        }
        
        guard status == noErr else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        
        self.procID = procID
        
        // Start the IO Proc
        let startStatus = AudioDeviceStart(aggregateDevice, procID)
        guard startStatus == noErr else {
            AudioDeviceDestroyIOProcID(aggregateDevice, procID!)
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(startStatus))
        }
        
        // Start rotation timer
        startRotationTimer()
    }
    
    private func startRotationTimer() {
        print("🎉 StartRotationTimer")
        // Invalidate any existing timers
        rotationTimer?.invalidate()
        prepareRotationTimer?.invalidate()
        
        // Record current time as segment start time
        segmentStartTime = CACurrentMediaTime()
        
        // Dispatch the actual timer scheduling to the main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("Timer scheduling skipped: self is nil")
                return
            }
            
            // Ensure we don't accidentally create multiple timers if start gets called rapidly
            // (Though the invalidation above should mostly handle this)
            self.prepareRotationTimer?.invalidate()
            self.rotationTimer?.invalidate()
            
            print("Scheduling timers on Main RunLoop...")
            
            // Timer for preparing the next writer
            self.prepareRotationTimer = Timer.scheduledTimer(
                timeInterval: self.rotationInterval - self.prepareIntervalBeforeRotation,
                target: self, // Use the captured weak self
                selector: #selector(self.prepareNextWriter),
                userInfo: nil,
                repeats: true
            )
            // Optional: More robust against UI blocking, add to common modes
            RunLoop.main.add(self.prepareRotationTimer!, forMode: .common)
            
            
            // Create and start the rotation timer
            self.rotationTimer = Timer.scheduledTimer(
                timeInterval: self.rotationInterval,
                target: self, // Use the captured weak self
                selector: #selector(self.rotateFile),
                userInfo: nil,
                repeats: true
            )
            // Optional: More robust against UI blocking, add to common modes
            RunLoop.main.add(self.rotationTimer!, forMode: .common)
            
            print("✅ Timers scheduled on Main RunLoop.")
        }
    }
    
    
    // New method to prepare the next writer before rotation happens
    @objc private func prepareNextWriter() {
        writerQueue.async { [weak self] in
            guard let self = self,
                  self.isRunning,
                  self.nextAssetWriter == nil else { return }
            
            print("📝 Preparing next segment writer...")
            
            // Get current format for creating new writer
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioTapPropertyFormat,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var originalStreamDescription = AudioStreamBasicDescription()
            var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            
            let formatStatus = AudioObjectGetPropertyData(
                self.tap,
                &address,
                0,
                nil,
                &size,
                &originalStreamDescription
            )
            
            guard formatStatus == noErr else {
                print("❌ Failed to get audio format for preparation")
                return
            }
            
            do {
                let (writer, input) = try self.setupNewAssetWriter(with: originalStreamDescription)
                self.nextAssetWriter = writer
                self.nextAssetWriterInput = input
                print("✅ Next segment writer ready")
            } catch {
                print("❌ Failed to prepare next writer: \(error.localizedDescription)")
            }
        }
    }
    
    func stopRecording(isCancelled: Bool = false) {
        print("\n🔄 Starting cleanup process...")
        
        // Stop all timers
        rotationTimer?.invalidate()
        rotationTimer = nil
        prepareRotationTimer?.invalidate()
        prepareRotationTimer = nil
        self.sessionId = ""
        self.baseFilename = ""
        
        // First stop and destroy the IO proc if it exists
        if let procID = procID {
            AudioDeviceStop(aggregateDevice, procID)
            AudioDeviceDestroyIOProcID(aggregateDevice, procID)
            self.procID = nil
            isRunning = false
        }
        
        // First destroy the aggregate device if it exists
        if aggregateDevice != 0 {
            print("🗑️ Destroying aggregate device: \(aggregateDevice)")
            let aggregateStatus = AudioHardwareDestroyAggregateDevice(aggregateDevice)
            if aggregateStatus == noErr {
                print("✅ Aggregate device destroyed successfully")
            } else {
                print("⚠️ Failed to destroy aggregate device with status: \(aggregateStatus)")
            }
            aggregateDevice = 0
        }
        
        // Then destroy the tap if it exists
        if tap != 0 {
            print("🗑️ Destroying tap: \(tap)")
            let tapStatus = AudioHardwareDestroyProcessTap(tap)
            if tapStatus == noErr {
                print("✅ Tap destroyed successfully")
            } else {
                print("⚠️ Failed to destroy tap with status: \(tapStatus)")
            }
            tap = 0
        }
        
        print("🏁 Cleanup complete")
        
        writerQueue.async { [weak self] in
            guard let self = self else { return }
            // Capture the current segment info before cleanup
            let finalSegmentIndex = self.currentSegmentIndex
            let finalFileURL = self.segmentFileURLs[finalSegmentIndex]
            let finalFileName = finalFileURL?.lastPathComponent ?? "\(self.baseFilename)-\(finalSegmentIndex).m4a"
            // Finish current recording
            let currentWriter = self.assetWriter
            let currentInput = self.assetWriterInput
            
            // Finish any prepared next writer
            let nextWriter = self.nextAssetWriter
            let nextInput = self.nextAssetWriterInput
            
            // Finish writing the current segment
            currentInput?.markAsFinished()
            currentWriter?.finishWriting {
                print("✅ Finished writing final audio segment")
                
                DispatchQueue.main.async {
                    ListeningCoordinator.shared.handleSystemAudioSegment(
                        index: finalSegmentIndex,
                        fileName: finalFileName
                    )
                }
            }
            
            // Cancel any prepared next writer
            if let nextWriter = nextWriter {
                nextInput?.markAsFinished()
                nextWriter.cancelWriting()
                print("❌ Cancelled prepared next writer")
            }
            
            // Reset all state
            self.assetWriter = nil
            self.assetWriterInput = nil
            self.nextAssetWriter = nil
            self.nextAssetWriterInput = nil
            self.segmentCounter = 0
            self.currentFileName = ""
            self.currentSegmentIndex = 0
            self.isRotationInProgress = false
        }
    }
    
    func cancelRecording() {
        // Use the existing stopRecording method but indicate it was cancelled
        stopRecording(isCancelled: true)
    }
    
    func startRecording(sysFileName: String) throws {
        // Reset state
        segmentCounter = 0
        isRotationInProgress = false
        
        // Set session identification properties
        let baseFileName = sysFileName.replacingOccurrences(of: ".m4a", with: "")
        
        self.baseFilename = baseFileName
        
        // 1. Create a tap for all system audio
        let tapDescription = CATapDescription(monoGlobalTapButExcludeProcesses: [])
        tapDescription.name = "SystemAudioTapPhoenix"
        tapDescription.isPrivate = false
        //        tapDescription.muteBehavior = .mutedWhenTapped
        tapDescription.muteBehavior = .unmuted
        tapDescription.isMixdown = false
        tapDescription.isMono = true
        tapDescription.isExclusive = true
        tapDescription.processes = []
        
        var tapID = AudioObjectID(kAudioObjectUnknown)
        let tapStatus = AudioHardwareCreateProcessTap(tapDescription, &tapID)
        
        guard tapStatus == noErr else {
            print("❌ Tap creation failed with status: \(tapStatus)")
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(tapStatus))
        }
        print("✅ Tap created successfully with ID: \(tapID)")
        self.tap = tapID
        
        // 2. Create aggregate device
        let deviceDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "SystemAudioTapPhoenix",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceIsPrivateKey: false,
            kAudioAggregateDeviceTapListKey: [tapDescription.uuid.uuidString],
            //            kAudioAggregateDeviceTapAutoStartKey: true
        ]
        
        print("📝 Creating aggregate device with description: \(deviceDescription)")
        
        var aggregateDeviceID: AudioObjectID = 0
        let createStatus = AudioHardwareCreateAggregateDevice(
            deviceDescription as CFDictionary,
            &aggregateDeviceID
        )
        
        guard createStatus == noErr else {
            print("❌ Aggregate device creation failed with status: \(createStatus)")
            AudioHardwareDestroyProcessTap(tapID)
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(createStatus))
        }
        print("✅ Aggregate device created successfully with ID: \(aggregateDeviceID)")
        self.aggregateDevice = aggregateDeviceID
        
        // 3. Get the tap's UID
        var tapPropertyAddress = getPropertyAddress(selector: kAudioTapPropertyUID)
        var tapPropertySize = UInt32(MemoryLayout<CFString>.stride)
        var tapUID: CFString = "" as CFString
        _ = withUnsafeMutablePointer(to: &tapUID) { tapUID in
            AudioObjectGetPropertyData(tapID, &tapPropertyAddress, 0, nil, &tapPropertySize, tapUID)
        }
        print("📍 Retrieved tap UID: \(tapUID)")
        
        // 4. Get and update the aggregate device's tap list
        print("\n🔄 Starting tap list update process...")
        
        var propertyAddress = getPropertyAddress(selector: kAudioAggregateDevicePropertyTapList)
        var propertySize: UInt32 = 0
        
        // Get size of tap list
        let sizeStatus = AudioObjectGetPropertyDataSize(aggregateDeviceID, &propertyAddress, 0, nil, &propertySize)
        print("📊 Property size status: \(sizeStatus), Size: \(propertySize)")
        
        var list: CFArray? = nil
        let getStatus = withUnsafeMutablePointer(to: &list) { list in
            AudioObjectGetPropertyData(aggregateDeviceID, &propertyAddress, 0, nil, &propertySize, list)
        }
        print("📥 Get tap list status: \(getStatus)")
        
        if var listAsArray = list as? [CFString] {
            print("📋 Current tap list: \(listAsArray)")
            
            // Add the new tap UID if it's not already in the list
            if !listAsArray.contains(tapUID) {
                print("➕ Adding new tap UID to list")
                listAsArray.append(tapUID)
                propertySize += UInt32(MemoryLayout<CFString>.stride)
                
                // Set the updated list back on the aggregate device
                list = listAsArray as CFArray
                let setStatus = withUnsafeMutablePointer(to: &list) { list in
                    AudioObjectSetPropertyData(aggregateDeviceID, &propertyAddress, 0, nil, propertySize, list)
                }
                print("📤 Set tap list status: \(setStatus)")
                print("📋 Updated tap list: \(listAsArray)")
            } else {
                print("ℹ️ Tap UID already in list")
            }
        } else {
            print("⚠️ Failed to get tap list as array")
        }
        
        // 5. Verify final state
        propertySize = 0
        AudioObjectGetPropertyDataSize(aggregateDeviceID, &propertyAddress, 0, nil, &propertySize)
        list = nil
        _ = withUnsafeMutablePointer(to: &list) { list in
            AudioObjectGetPropertyData(aggregateDeviceID, &propertyAddress, 0, nil, &propertySize, list)
        }
        if let finalList = list as? [CFString] {
            print("\n📋 Final tap list verification: \(finalList)")
        }
        
        //        try verifyDeviceSetup()
        try startIOProc()
        isRunning = true
    }
}
