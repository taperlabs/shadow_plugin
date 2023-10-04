import Foundation
import AVFAudio
import AVFoundation
import ScreenCaptureKit
import FlutterMacOS


struct CapturedFrame {
    static let invalid = CapturedFrame(surface: nil, contentRect: .zero, contentScale: 0, scaleFactor: 0)
    
    let surface: IOSurface?
    let contentRect: CGRect
    let contentScale: CGFloat
    let scaleFactor: CGFloat
    var size: CGSize { contentRect.size }
}


// MARK: - Screen Video + System Audio Capture 클래스
class ScreenRecorder {
    var stream: SCStream?
    var display : [SCDisplay]?
    var windows: [SCWindow]?
    var apps: [SCRunningApplication]?
    var filtered: SCContentFilter?
    var streamConfig: SCStreamConfiguration?
    //    var streamOutput: CaptureEngineStreamOutput?
    var streamOutput: ScreenRecorderOutputHandler?
    var assetWriterSetup = AssetWriterHelper()
    
    var timeIndicator = TimeIndicator()
    
    var isRecording: Bool = false
    
    var micRecording = MicrophoneRecorder()
    
    //    var isRecording: Bool = false {
    //        didSet {
    //            streamOutput?.sendRecordingStatusToFlutter(isRecording)
    //        }
    //    }
    
    func getAvailableContent(withConfig config: [String: Any]? = nil) async throws {
        if !SystemSettingsHandler.checkScreenRecordingPermission() {
            //            // If permission is not granted, request it or open system settings
            //            // ScreenRecorderPermissionHandler.requestScreenRecordingPermission()
            SystemSettingsHandler.openSystemSetting(for: "screen")
            throw CaptureError.missingScreenRecordingPermission
        }
        
        do {
            let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            display = availableContent.displays
            
            let excludedApps = availableContent.applications.filter { app in
                Bundle.main.bundleIdentifier == app.bundleIdentifier
            }
            
            filtered = SCContentFilter(display: availableContent.displays[0],
                                       excludingApplications: excludedApps,
                                       exceptingWindows: [])
            
            setStreamConfig()
            
            if let config = config {
                try await startCapture(withConfig: config)
            } else {
                try await startCapture()
            }
        } catch {
            print(error)
            display = [] // Set display to an empty array in case of an error
        }
    }
    
    
    func startCapture(withConfig config: [String: Any]? = nil) async throws {
        //        if !ScreenRecorderPermissionHandler.checkScreenRecordingPermission() {
        //            // If permission is not granted, request it or open system settings
        //            // ScreenRecorderPermissionHandler.requestScreenRecordingPermission()
        //            SystemSettingsHandler.openSystemSetting(for: "screen")
        //            throw CaptureError.missingScreenRecordingPermission
        //        }
        
        guard let filtered = filtered, let streamConfig = streamConfig else {
            throw CaptureError.missingParameters
        }
        
        if let config = config {
            configureAssetWriter(withConfig: config)
        } else {
            configureAssetWriter()
        }
        
        setupStreamOutput()
        try setupStream(with: filtered, config: streamConfig)
        try await initiateCapture()
    }
    
    private func setupStreamOutput() {
        streamOutput = ScreenRecorderOutputHandler(recorder: self, timeIndicator: timeIndicator)
        timeIndicator.timeUpdateHandler = { [weak self] _ in
            self?.streamOutput?.sendTimeUpdate()
        }
    }
    
    private func configureAssetWriter(withConfig config: [String: Any]? = nil) {
        if let config = config {
            assetWriterSetup.setUpSystemAudioAssetWriter(withConfig: config)
        } else {
            assetWriterSetup.setUpSystemAudioAssetWriter()
        }
    }
    
    private func setupStream(with filter: SCContentFilter, config: SCStreamConfiguration) throws {
        let videoSampleBufferQueue = DispatchQueue(label: "phoenix")
        let audioSampleBufferQueue = DispatchQueue(label: "phoenix2")
        
        stream = SCStream(filter: filter, configuration: config, delegate: streamOutput)
        
        guard let streamOutput = streamOutput else {
            throw CaptureError.streamOutputNotInitialized
        }
        
        try stream?.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
        try stream?.addStreamOutput(streamOutput, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)
        //        micRecording.startMicAudioRecording()
        isRecording = true
        streamOutput.startSendingStatus()
        timeIndicator.start()
    }
    
    private func initiateCapture() async throws {
        try await stream?.startCapture()
    }
    
    
    func stopCapture() async throws {
        do {
            print("Stop Capture Called!!!!")
            try await stream?.stopCapture()
            //            micRecording.stopMicAudioRecording()
            
            isRecording = false
            print("Stop Capture IsRecording", isRecording)
            streamOutput?.stopSendingStatus()
            timeIndicator.stop()
            
            finishAssetWriting(assetWriter: assetWriterSetup.systemAudioAssetWriter)
            finishAssetWriting(assetWriter: assetWriterSetup.assetWriter)
        } catch  {
            print(error.localizedDescription)
        }
        print("Stop Capture() Completed")
    }
    
    private func finishAssetWriting(assetWriter: AVAssetWriter?) {
        guard let writer = assetWriter else {
            print("AssetWriter is nil")
            return
        }
        
        switch writer.status {
        case .writing:
            writer.finishWriting {
                print("Finished writing to output file at:", writer.outputURL)
            }
        case .failed:
            print("Asset writer failed with error: \(writer.error?.localizedDescription ?? "Unknown error")")
        case .completed:
            print("AssetWriter Status: Completed successfully")
        case .cancelled:
            print("AssetWriter Status: Cancelled")
        case .unknown:
            print("AssetWriter Status: Unknown")
        @unknown default:
            print("AssetWriter Status: Encountered unknown status")
        }
    }
    
    
    func setStreamConfig() {
        streamConfig = SCStreamConfiguration()
        
        guard let streamConfig = streamConfig else {
            fatalError("stream Config nill")
        }
        
        //Audio Capture
        streamConfig.capturesAudio = true
        
        //Width & Height
        streamConfig.width = 1920
        streamConfig.height = 1080
        
        streamConfig.scalesToFit = true
        // Optimizing Performance
        streamConfig.queueDepth = 6
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        
    }
    
}

