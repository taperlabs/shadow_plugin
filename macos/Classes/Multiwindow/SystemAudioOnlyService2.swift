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
    private var prepareRotationTimer: Timer?
    private var nextAssetWriter: AVAssetWriter?
    private var nextAssetWriterInput: AVAssetWriterInput?
    
    // File rotation properties
    private var rotationTimer: Timer?
    private var segmentFileURLs: [Int: URL] = [:]
    private var isRotationInProgress = false
    
    
    // Queue for thread safety
    private let writerQueue = DispatchQueue(label: "com.audiorecorder.writer", qos: .userInitiated)
    
    // File naming properties
    private var sessionId: String = ""
    private var baseFilename: String = "SystemAudio"
    
    // Keep track of running state
    @Published private(set) var isRunning = false
    
    @Published private(set) var noiseLevel: Float = 0.0
    
    /// A dedicated serial queue for rotation timers
    private let rotationTimerQueue = DispatchQueue(label: "com.yourapp.rotationTimerQueue")
    
    /// Dispatch timers
    private var prepareRotationTimerDS: DispatchSourceTimer?
    private var rotationTimerDS: DispatchSourceTimer?
    
    // Also add cleanup in deinit to ensure resources are freed
    deinit {
        stopRecording()
    }
    
    private func calculateNoiseLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else {
            return 0.0
        }
        
        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)
        
        // Calculate RMS value across all channels
        var rms: Float = 0.0
        
        for channel in 0..<channelCount {
            let channelDataPtr = channelData[channel]
            
            for frame in 0..<frameLength {
                let sample = channelDataPtr[frame]
                rms += sample * sample
            }
        }
        
        // Average across all samples
        rms = rms / Float(frameLength * channelCount)
        rms = sqrt(rms)
        
        // Convert to decibels (relative to full scale)
        // Avoid log(0) by adding a small epsilon
        let epsilon: Float = 0.000001
        var decibels: Float = 20.0 * log10(rms + epsilon)
        
        // Normalize to a 0...1 scale for UI purposes
        // Typical values: -60dB (quiet) to 0dB (maximum)
        decibels = max(-80.0, min(0.0, decibels))
        let normalizedLevel = (decibels + 80.0) / 80.0
        
        return normalizedLevel
    }
    
    func getPropertyAddress(selector: AudioObjectPropertySelector,
                            scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                            element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        return AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }
    
    // New method to create a file URL for the current segment
    private func createFileURL(segmentIndex index: Int) -> URL? {
        guard let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            print("❌ Unable to find directory URL")
            return nil
        }
        print("🦊 CREATE FILE URL -- \(index)")
        let appSpecificDirectoryURL = appSupportDirectory.appendingPathComponent("com.taperlabs.shadow")
        // Use the format: UUID-BaseFilename-SegmentNumber.m4a
        let filename = "\(baseFilename)-\(index).m4a"
        return appSpecificDirectoryURL.appendingPathComponent(filename)
    }
    
    // New method to setup a new asset writer
    private func setupNewAssetWriter(with originalStreamDescription: AudioStreamBasicDescription, segmentIndex: Int) throws -> (AVAssetWriter, AVAssetWriterInput) {
        
        guard let fileURL = createFileURL(segmentIndex: segmentIndex) else {
            throw NSError(domain: "Unable to create file URL", code: -1)
        }
        
        
        // Store the URL for this segment
        segmentFileURLs[segmentIndex] = fileURL
        
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
        
        // For initial segment, use hostClock timing
        if segmentIndex == 0 {
            let hostClock = CMClockGetHostTimeClock()
            let startHostTime = CMClockGetTime(hostClock) + CMTime(seconds: 1.0, preferredTimescale: 1)
            writer.startSession(atSourceTime: startHostTime)
        } else {
            writer.startSession(atSourceTime: .zero)
        }
        
        print("📝 Created new file segment: \(fileURL.lastPathComponent)")
        return (writer, writerInput)
    }
    
    // New method to handle file rotation
    private func rotateFile(currentIndex: Int) {
        let completedSegmentIndex = currentIndex
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
            
            // The new segment index will be currentIndex + 1
            let newSegmentIndex = currentIndex + 1
            
            // Check if we have a prepared writer ready
            if let preparedWriter = self.nextAssetWriter, let preparedInput = self.nextAssetWriterInput {
                print("✅ Using pre-prepared writer for seamless transition")
                
                // Update current writer and input with the prepared ones
                self.assetWriter = preparedWriter
                self.assetWriterInput = preparedInput
                self.nextAssetWriter = nil
                self.nextAssetWriterInput = nil
                
                print("🖥️ Started pre-prepared recording segment \(newSegmentIndex) with file:")
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
                    let (newWriter, newInput) = try self.setupNewAssetWriter(with: originalStreamDescription,segmentIndex: newSegmentIndex)
                    self.assetWriter = newWriter
                    self.assetWriterInput = newInput
                } catch {
                    print("❌ Failed to create new writer during rotation: \(error.localizedDescription)")
                    self.isRotationInProgress = false
                    return
                }
            }
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
        
        let initialSegmentIndex = AudioSegmentCoordinator.shared.getCurrentSegmentIndex()
        
        // Initialize first file and asset writer
        let (writer, writerInput) = try setupNewAssetWriter(with: originalStreamDescription, segmentIndex: initialSegmentIndex)
        self.assetWriter = writer
        self.assetWriterInput = writerInput
        
        // Create format for working with the input
        guard let inputFormat = AVAudioFormat(streamDescription: &originalStreamDescription) else {
            print("❌ Failed to create AVAudioFormat from stream description")
            print("Stream description: \(originalStreamDescription)")  // Add more logging
            
            ShadowLogger.shared.error("❌ Failed to create AVAudioFormat from stream description -- \(originalStreamDescription)")
            throw NSError(domain: "Failed to create audio format", code: -1)
        }
        
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: AVAudioChannelCount(originalStreamDescription.mChannelsPerFrame),
            interleaved: false
        )!
        
        guard let _ = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            ShadowLogger.shared.error("Failed to create audio converter")
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
                    ShadowLogger.shared.error("❌ Failed to create AVAudioFormat from stream description")
                    return
                }
                
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: format,
                    bufferListNoCopy: inData,
                    deallocator: nil
                ) else {
                    print("❌ Failed to create PCM buffer")
                    ShadowLogger.shared.error("❌ Failed to create PCM buffer")
                    return
                }
                
                // ADD THIS CODE HERE for noise level calculation
                let currentNoiseLevel = self.calculateNoiseLevel(from: buffer)
                // Update the noise level on the main thread
                DispatchQueue.main.async { [weak self] in
                    //                    print("🤖 Noise Level ==== \(self?.noiseLevel)")
                    self?.noiseLevel = currentNoiseLevel
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
                    ShadowLogger.shared.error("❌ Failed to create block buffer")
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
                    ShadowLogger.shared.error("❌ Failed to create format description")
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
                    ShadowLogger.shared.error("❌ Failed to create or append sample buffer")
                }
            }
        }
        
        guard status == noErr else {
            ShadowLogger.shared.error("❌ An error occurred before ADS -- \(Int(status))")
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        
        self.procID = procID
        
        // Start the IO Proc
        let startStatus = AudioDeviceStart(aggregateDevice, procID)
        guard startStatus == noErr else {
            ShadowLogger.shared.error("❌ An error occurred after ADS -- \(Int(status))")
            AudioDeviceDestroyIOProcID(aggregateDevice, procID!)
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(startStatus))
        }
    }
    
    
    
    // New method to prepare the next writer before rotation happens
    private func prepareNextWriter(nextIndex: Int) {
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
                let (writer, input) = try self.setupNewAssetWriter(with: originalStreamDescription, segmentIndex: nextIndex)
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
        
        
        DispatchQueue.main.async { [weak self] in
            // Stop all timers
            self?.sessionId = ""
            self?.baseFilename = ""
        }
        
        cleanupResources()
        
        print("🏁 Cleanup complete")
        
        writerQueue.async { [weak self] in
            guard let self = self else { return }
            // Capture the current segment info before cleanup
            //            if self.nextAssetWriter == nil && self.nextAssetWriterInput == nil {
            //                segmentIndex = self.currentSegmentIndex
            //            } else {
            //                segmentIndex = self.currentSegmentIndex - 1
            //            }
            
            let finalSegmentIndex = AudioSegmentCoordinator.shared.getCurrentSegmentIndex()
            let finalFileURL = self.segmentFileURLs[finalSegmentIndex]
            let finalFileName = finalFileURL?.lastPathComponent ?? "\(self.baseFilename)-\(finalSegmentIndex).m4a"
            
            print("🛑 Stop system audio recording for segment index \(finalSegmentIndex)")
            
            // Finish current recording
            let currentWriter = self.assetWriter
            let currentInput = self.assetWriterInput
            
            // Finish any prepared next writer
            let nextWriter = self.nextAssetWriter
            let nextInput = self.nextAssetWriterInput
            
            // Finish writing the current segment
            currentInput?.markAsFinished()
            currentWriter?.finishWriting {
                print("✅ Finished writing final audio segment -- Index : \(finalSegmentIndex), FileName : \(finalFileName)")
                
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
            self.isRotationInProgress = false
        }
    }
    
    func cancelRecording() {
        // Use the existing stopRecording method but indicate it was cancelled
        stopRecording(isCancelled: true)
    }
    
    func startRecording(sysFileName: String) throws {
        // Reset state
        isRotationInProgress = false
        
        cleanupResources()
        
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
        
        try startIOProc()
        isRunning = true
        
        AudioSegmentCoordinator.shared.registerSystemAudioService(self)
    }
    
    private func cleanupResources() {
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
                ShadowLogger.shared.info("✅ Aggregate device destroyed successfully")
                print("✅ Aggregate device destroyed successfully")
            } else {
                ShadowLogger.shared.error("⚠️ Failed to destroy aggregate device with status: \(aggregateStatus)")
                print("⚠️ Failed to destroy aggregate device with status: \(aggregateStatus)")
            }
            aggregateDevice = 0
        }
        
        // Then destroy the tap if it exists
        if tap != 0 {
            print("🗑️ Destroying tap: \(tap)")
            let tapStatus = AudioHardwareDestroyProcessTap(tap)
            if tapStatus == noErr {
                ShadowLogger.shared.info("✅ Tap destroyed successfully")
                print("✅ Tap destroyed successfully")
            } else {
                ShadowLogger.shared.error("⚠️ Failed to destroy tap with status: \(tapStatus)")
                print("⚠️ Failed to destroy tap with status: \(tapStatus)")
            }
            tap = 0
        }
    }
}


extension SystemAudioOnlyService: AudioSegmentService {
    func prepareNextSegment(nextSegmentIndex: Int) {
        print("📝 SystemAudioService: Preparing next segment via coordinator")
        self.prepareNextWriter(nextIndex: nextSegmentIndex)
    }
    
    func rotateSegment(currentSegmentIndex: Int) {
        print("🔄 SystemAudioService: Rotating segment via coordinator")
        self.rotateFile(currentIndex: currentSegmentIndex)
    }
}
