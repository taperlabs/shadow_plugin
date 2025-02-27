import Foundation
import ScreenCaptureKit
import AVFoundation
import Combine
import AVFAudio

// MARK: - ScreenCapture System Audio Service
final class NewScreenCaptureService: NSObject, ObservableObject {
    // MARK: - Configuration
    private let defaultSegmentDuration: TimeInterval = 60.0 // 2 minutes in seconds
    private var segmentDuration: TimeInterval
    
    // MARK: - Stream Components
    private var stream: SCStream?
    private var fullLengthWriter: AVAssetWriter?
    private var segmentWriter: AVAssetWriter?
    private var fullLengthAudioInput: AVAssetWriterInput?
    private var segmentAudioInput: AVAssetWriterInput?
    
    // MARK: - Queues
    private let systemAudioQueue = DispatchQueue(label: "systemAudioQueue")
    private let videoQueue = DispatchQueue(label: "videoQueue")
    
    // MARK: - State Management
    private var isRecording = false
    private var currentSegmentIndex = 0
    private var sysFileName: String = ""
    private var sysSegmentFileName: String = ""
    private var currentSegmentStartTime: TimeInterval = 0
    private var recordingStartTime: TimeInterval = 0
    private var isRotatingSegment = false  // Add this property to prevent concurrent rotations
    
    @Published private(set) var noiseLevel: Float = 0.0
    
    
    // MARK: - Initialization
    override init() {
        self.segmentDuration = defaultSegmentDuration
        super.init()
    }
    
    init(segmentDuration: TimeInterval) {
        self.segmentDuration = segmentDuration
        super.init()
    }
    
    func startCapture(fileName: String) async throws {
        guard let downloadsDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "ScreenCaptureService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to locate Downloads directory."])
        }
        // Set System File Name
        sysFileName = fileName
        
        guard let outputURL = FileManagerHelper.getURL(for: sysFileName, in: "ApplicationSupportDirectory") else {
            print("File URL을 가져오는데 실패하였습니다.")
            return
        }
        
        print("아웃풋 URL System Audio File Path - \(outputURL)")
        
        // Initialize timing
        recordingStartTime = CACurrentMediaTime()
        currentSegmentStartTime = recordingStartTime
        currentSegmentIndex = 0
        
        // Set up full length recording
//        try setupFullLengthRecording(at: outputURL)
        
        // Set up first segment
        try setupNewSegment(fileName: sysFileName)
        
        // Configure and start the stream
        try await configureStream()
        isRecording = true
    }
    
    private func setupFullLengthRecording(at url: URL) throws {
        // Remove existing file if necessary
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        
        // Initialize writer and input for full length recording
        fullLengthWriter = try AVAssetWriter(outputURL: url, fileType: .m4a)
        
        let audioSettings = AudioSetting.setAudioConfiguration(
            format: .mpeg4AAC,
            channels: .mono,
            sampleRate: .rate16K
        )
        
        fullLengthAudioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: audioSettings
        )
        fullLengthAudioInput?.expectsMediaDataInRealTime = true
        
        if let audioInput = fullLengthAudioInput,
           fullLengthWriter!.canAdd(audioInput) {
            fullLengthWriter!.add(audioInput)
        }
        
        fullLengthWriter!.startWriting()
        fullLengthWriter!.startSession(atSourceTime: .zero)
    }
    
    private func setupNewSegment(fileName: String) throws {
        // Remove .m4a extension and create segmented filename
        let baseFileName = fileName.replacingOccurrences(of: ".m4a", with: "")
        let segmentFileName = "\(baseFileName)-\(currentSegmentIndex).m4a"
        sysSegmentFileName = segmentFileName
        guard let outputURL = FileManagerHelper.getURL(for: segmentFileName, in: "ApplicationSupportDirectory") else {
            throw NSError(domain: "ScreenCaptureService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to get Application Support directory URL"])
        }
        
        // Remove existing file if necessary - now checking the correct path
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        
        // Initialize writer and input for segment
        segmentWriter = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        
        let audioSettings = AudioSetting.setAudioConfiguration(
            format: .mpeg4AAC,
            channels: .mono,
            sampleRate: .rate16K
        )
        
        segmentAudioInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: audioSettings
        )
        segmentAudioInput?.expectsMediaDataInRealTime = true
        
        if let audioInput = segmentAudioInput,
           segmentWriter!.canAdd(audioInput) {
            segmentWriter!.add(audioInput)
        }
        
        segmentWriter!.startWriting()
        segmentWriter!.startSession(atSourceTime: .zero)
    }
    
    func stopCapture(isCancelled: Bool = false) {
        guard isRecording else { return }
        isRecording = false
        
        // Create a dispatch group to coordinate cleanup
        let cleanupGroup = DispatchGroup()
        
        // Stop the stream
        cleanupGroup.enter()
        stream?.stopCapture { [weak self] error in
            guard let self = self else {
                cleanupGroup.leave()
                return
            }
            
            if let error = error {
                print("Failed to stop capture: \(error)")
            }
            
            // Safely remove stream outputs
            do {
                try self.stream?.removeStreamOutput(self, type: .audio)
                try self.stream?.removeStreamOutput(self, type: .screen)
            } catch {
                print("Failed to remove stream outputs: \(error)")
            }
            cleanupGroup.leave()
        }
        
        // Finish full length recording
        cleanupGroup.enter()
        fullLengthAudioInput?.markAsFinished()
        fullLengthWriter?.finishWriting { [weak self] in
            if let error = self?.fullLengthWriter?.error {
                print("Failed to finish writing full length file: \(error)")
            }
            cleanupGroup.leave()
        }
        
        // Finish current segment
        cleanupGroup.enter()
        segmentAudioInput?.markAsFinished()
        segmentWriter?.finishWriting { [weak self] in
            if let error = self?.segmentWriter?.error {
                print("Failed to finish writing segment file: \(error)")
            } else{
                self?.finalizeLastSegment(isCancelled: isCancelled)
            }
            cleanupGroup.leave()
        }
        
        // Only cleanup after all async operations complete
        cleanupGroup.notify(queue: .main) { [weak self] in
            self?.cleanup()
        }
    }
    
    private func finalizeLastSegment(isCancelled: Bool) {
        ListeningCoordinator.shared.handleSystemAudioSegment(
            index: currentSegmentIndex,
            fileName: sysSegmentFileName
        )
    }
    
    private func cleanup() {
        fullLengthWriter = nil
        fullLengthAudioInput = nil
        segmentWriter = nil
        segmentAudioInput = nil
        stream = nil
    }
    
    private func rotateSegment() {
        // Prevent concurrent rotations
        guard !isRotatingSegment else {
            print("Segment rotation already in progress")
            return
        }
        
        isRotatingSegment = true
        
        // Create a temporary reference to current writer/input
        let currentWriter = segmentWriter
        let currentInput = segmentAudioInput
        
        // Only finish if we have a valid writer
        guard currentWriter?.status == .writing else {
            isRotatingSegment = false
            return
        }
        
        currentInput?.markAsFinished()
        currentWriter?.finishWriting { [weak self] in
            guard let self = self else { return }
            ListeningCoordinator.shared.handleSystemAudioSegment(
                index: currentSegmentIndex,
                fileName: sysSegmentFileName
            )
            
            // Setup new segment
            self.currentSegmentIndex += 1
            self.currentSegmentStartTime = CACurrentMediaTime()
            
            do {
                try self.setupNewSegment(fileName: sysFileName)
            } catch {
                print("Failed to create new segment: \(error)")
            }
            
            self.isRotatingSegment = false
        }
    }
    
    private func configureStream() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        guard let display = content.displays.first else {
            throw NSError(domain: "ScreenCaptureService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No displays found"])
        }
        
        let excludedApps = content.applications.filter { app in
            Bundle.main.bundleIdentifier == app.bundleIdentifier
        }
        
        let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
        
        let streamConfig = SCStreamConfiguration()
        streamConfig.capturesAudio = true
        streamConfig.width = 128
        streamConfig.height = 72
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        streamConfig.queueDepth = 3
        streamConfig.scalesToFit = true
        
        stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        
        do {
            try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: systemAudioQueue)
        } catch let error {
            print("Failed to add audio output : \(error), \(error.localizedDescription)")
        }
        
       
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
        
        try await stream?.startCapture()
    }
    
    private func normalizeAudioLevel(_ dbLevel: Float) -> Float {
        // Define our dB range
        let maxDB: Float = -10.0  // Loudest expected
        let minDB: Float = -70.0  // Quietest expected
        
        // If level is -100 (our silence indicator) or lower, return 0
        if dbLevel <= -100 {
            return 0.0
        }
        
        // Clamp the value between our min and max
        let clampedDB = min(maxDB, max(minDB, dbLevel))
        
        // Convert to 0-1 range
        let normalizedValue = (clampedDB - minDB) / (maxDB - minDB)
        
        return normalizedValue
    }
    
    private func calculateAudioLevel(from sampleBuffer: CMSampleBuffer) -> Float {
        var level: Float = 0.0
        
        do {
            try sampleBuffer.withAudioBufferList { audioBufferList, blockBuffer in
                // audioBufferList is already a pointer, no need for pointee
                let buffer = audioBufferList[0] // Get first buffer
                
                // Get the raw audio data
                guard let samples = buffer.mData?.assumingMemoryBound(to: Float.self) else {
                    return
                }
                
                let sampleCount = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                var sumSquares: Float = 0.0
                
                // Calculate RMS (Root Mean Square)
                for i in 0..<sampleCount {
                    let sample = samples[i]
                    sumSquares += sample * sample
                }
                
                // Calculate the RMS value
                let rms = sqrtf(sumSquares / Float(sampleCount))
                
                // Convert to decibels, with minimum threshold
                if rms > 0 {
                    level = 20 * log10f(rms)
                } else {
                    level = -100 // Set minimum level instead of -inf
                }
            }
        } catch {
            print("Error processing audio buffer: \(error)")
        }
        
        //           print("Audio Level --- \(level)")
        
        return level
    }
    
    private func isAudioPresent(level: Float) -> Bool {
        // Threshold in decibels - adjust this value based on your needs
        let threshold: Float = -65.0
        return level > threshold
    }
    
}

extension NewScreenCaptureService: SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream did stop with error: \(error.localizedDescription)")
        let nsError = error as NSError
        print("Error domain: \(nsError.domain)")
        print("Error code: \(nsError.code)")
        print("Error user info: \(nsError.userInfo)")
        
        stopCapture()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid, type == .audio, isRecording else { return }
        
        // Calculate audio level in dB
        let dbLevel = calculateAudioLevel(from: sampleBuffer)
        
        // Convert to normalized 0-1 range
        let normalizedLevel = normalizeAudioLevel(dbLevel)
        
        // Convert to normalized 0-1 range and update published property
        DispatchQueue.main.async { [weak self] in
            self?.noiseLevel = normalizedLevel
        }
        
        // Write to full length recording
        if let audioInput = fullLengthAudioInput, audioInput.isReadyForMoreMediaData {
            if !audioInput.append(sampleBuffer) {
                print("Failed to append audio sample buffer to full length recording")
            }
        }
        
        // Write to current segment only if we have valid writer and input
        if let writer = segmentWriter,
           let audioInput = segmentAudioInput,
           writer.status == .writing,
           audioInput.isReadyForMoreMediaData {
            if !audioInput.append(sampleBuffer) {
                print("Failed to append audio sample buffer to segment")
            }
        }
        
        // Check if we need to rotate to a new segment
        let currentTime = CACurrentMediaTime()
        let segmentElapsedTime = currentTime - currentSegmentStartTime
        
        if segmentElapsedTime >= segmentDuration {
            rotateSegment()
        }
    }
}
