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
//        guard PermissionStatusCheckerHelper.checkScreenRecordingPermission() else {
//            //TODO: Add Custom Error Propagation
//            print("Screen Recording permission is not granted.")
//            return
//        }
        
        do {
            let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            
            display = availableContent.displays
            
            let excludedApps = availableContent.applications.filter { app in
                Bundle.main.bundleIdentifier == app.bundleIdentifier
            }
            
//            print("Display Name!! 000", availableContent.displays[0].displayID, availableContent.displays[0].frame)
//            print("Display Name!! 111", availableContent.displays[1].displayID, availableContent.displays[1].frame)
//            
//            currentDisplay = availableContent.displays[0]
                
            
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
        ShadowLogger.shared.log("SC StartCapture EXECUTED")
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
    
    func stopCaptureForError() {
            streamOutput?.stopSendingStatus()
            timeIndicator.stop()
            finishAssetWriting(assetWriter: assetWriterSetup.systemAudioAssetWriter)
            finishAssetWriting(assetWriter: assetWriterSetup.assetWriter)
            ShadowLogger.shared.log("stopCaptureForError Called")
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
//            stream = nil
//            streamOutput = nil
            ShadowLogger.shared.log("STOP SC EXECUTED")
        } catch let error  {
            print(error.localizedDescription)
            ShadowLogger.shared.log("Stop SC Error: \(error.localizedDescription)")
        }
        print("Stop Capture() Completed")
    }
    
     private func finishAssetWriting(assetWriter: AVAssetWriter?) {
        guard let writer = assetWriter else {
            print("AssetWriter is nil")
            ShadowLogger.shared.log("AssetWriter nil")
            return
        }
        
        switch writer.status {
        case .writing:
            writer.finishWriting {
                print("Finished writing to output file at:", writer.outputURL)
                ShadowLogger.shared.log("Finished Writing output file")
            }
        case .failed:
            print("Asset writer failed with error: \(writer.error?.localizedDescription ?? "Unknown error")")
            ShadowLogger.shared.log("AS Error .failed: \(writer.error?.localizedDescription ?? "Unknown error")")
        case .completed:
            print("AssetWriter Status: Completed successfully")
        case .cancelled:
            print("AssetWriter Status: Cancelled")
            ShadowLogger.shared.log("AS Error .cancelled")
        case .unknown:
            print("AssetWriter Status: Unknown")
            ShadowLogger.shared.log("AS Error .Unknown")
        @unknown default:
            print("AssetWriter Status: Encountered unknown status")
        }
    }
    
    
    func setStreamConfig() {
        streamConfig = SCStreamConfiguration()
        
        guard let streamConfig = streamConfig else {
            fatalError("stream Config nill")
        }
        
        // Audio Capture
        streamConfig.capturesAudio = true
        
        // Use a minimal but reasonable resolution
        streamConfig.width = 128
        streamConfig.height = 72
        
        // Use a standard low frame rate to maintain sync
        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30 FPS
        
        // Queue depth can remain minimal since video is not important
        streamConfig.queueDepth = 3
        
        streamConfig.scalesToFit = true
        

        
        //Audio Capture
//        streamConfig.capturesAudio = true
//        
//        //Width & Height
//        streamConfig.width = 1920
//        streamConfig.height = 1080
//        
//        streamConfig.scalesToFit = true
//        // Optimizing Performance
//        streamConfig.queueDepth = 6
//        streamConfig.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        
    }
    
}

