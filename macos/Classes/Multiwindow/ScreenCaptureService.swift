import Foundation
import ScreenCaptureKit
import AVFoundation
import Combine

// MARK: - ScreenCapture System Audio Service
final class ScreenCaptureService: NSObject, ObservableObject {
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private let systemAudioQueue = DispatchQueue(label: "systemAudioQueue")
    private let videoQueue = DispatchQueue(label: "videoQueue")
    
    func startCapture(name: String) async throws {
        // Set up the output file URL
        let fileManager = FileManager.default
        let downloadsURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let outputURL = downloadsURL.appendingPathComponent("systemAudio-\(name).m4a")

        // Remove existing file if necessary
        if fileManager.fileExists(atPath: outputURL.path) {
            try fileManager.removeItem(at: outputURL)
        }

        // Initialize AVAssetWriter
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        let audioOutputSettings = AudioSetting.setAudioConfiguration(format: .mpeg4AAC, channels: .mono, sampleRate: .rate16K)
        
        // Set up audio input settings
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 128000
        ]
        
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
        audioInput?.expectsMediaDataInRealTime = true
        
        // Add audio input to asset writer
        if let audioInput = audioInput, assetWriter!.canAdd(audioInput) {
            assetWriter!.add(audioInput)
        } else {
            throw NSError(domain: "ScreenCaptureService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot add audio input"])
        }
        
        // Start writing
        assetWriter!.startWriting()
        assetWriter!.startSession(atSourceTime: .zero)
        
        // Configure and start the SCStream
        try await configureStream()
    }
    
    func stopCapture() {
        // Stop the stream
        stream?.stopCapture { error in
            if let error = error {
                print("Failed to stop capture: \(error)")
            } else {
                print("Capture stopped")
            }
        }
        
        // Mark the audio input as finished
        audioInput?.markAsFinished()
        
        // Finish writing
        assetWriter?.finishWriting {
            if let error = self.assetWriter?.error {
                print("Failed to finish writing: \(error)")
            } else {
                print("Writing finished")
            }
            // Clean up
            self.assetWriter = nil
            self.audioInput = nil
            self.stream = nil
        }
    }
    
    private func configureStream() async throws {
        // Get the list of displays (we need at least one display)
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
        guard let display = content.displays.first else {
            throw NSError(domain: "ScreenCaptureService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No displays found"])
        }
        
        let excludedApps = content.applications.filter { app in
            Bundle.main.bundleIdentifier == app.bundleIdentifier
        }

        // Create a content filter with the main display
        let filter = SCContentFilter(display: display, excludingApplications: excludedApps, exceptingWindows: [])
 

        // Create the stream configuration
        let streamConfig = SCStreamConfiguration()
        streamConfig.capturesAudio = true
        // Use a minimal but reasonable resolution
        streamConfig.width = 128
        streamConfig.height = 72
        
        // Use a standard low frame rate to maintain sync
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30 FPS
        
        // Queue depth can remain minimal since video is not important
        streamConfig.queueDepth = 3
        streamConfig.scalesToFit = true

        // Create the stream
        stream = SCStream(filter: filter, configuration: streamConfig, delegate: self)
        
        // Add self as an output
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: systemAudioQueue)
        try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
        
        // Start the stream
        try await stream?.startCapture()
    }
}

extension ScreenCaptureService: SCStreamOutput, SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("Stream did stop with error: \(error)")
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else {
            debugPrint("SampleBuffer - \(sampleBuffer.isValid)")
            return
        }
        
        guard type == .audio else {
            return
        }
        
        guard let audioInput = audioInput, audioInput.isReadyForMoreMediaData else {
            return
        }
        
        // Append the sample buffer to the asset writer input
        if !audioInput.append(sampleBuffer) {
            print("Failed to append audio sample buffer")
        }
    }
}
