import Foundation
import FlutterMacOS

//MARK: - An extension for system audio related MethodChannel Call
extension ShadowPlugin {
    
    public func handleSystemAudioRecording(args: [String: Any]? = nil, result: @escaping FlutterResult) {
        Task {
            do {
                if let args = args {
                    print("system audio 아규먼트:", args)
                    // Here, you can set up anything specific for the configurable behavior
                    // For example, pass the args to the screenRecorder or any other component that needs it
                    try await screenRecorder.getAvailableContent(withConfig: args)
                } else {
                    try await screenRecorder.getAvailableContent()
                }
                
                if captureEngineStreamOutput == nil {
                    guard let screenEventChannel = ShadowPlugin.screenEventChannel,
                          let screenRecorderOutput = screenRecorder.streamOutput else {
                        ShadowLogger.shared.log("screenRecorderOutput \(screenRecorder)")
                            return
                    }
                    ShadowLogger.shared.log("captureEngineStreamOutput == nil")
                    
                    captureEngineStreamOutput = screenRecorderOutput
                    screenEventChannel.setStreamHandler(captureEngineStreamOutput)
                }
                
                //                guard let screenEventChannel = ShadowPlugin.screenEventChannel, let screenRecorderOutput = screenRecorder.streamOutput else { return }
                //                captureEngineStreamOutput = screenRecorderOutput
                //                screenEventChannel.setStreamHandler(captureEngineStreamOutput)
                result("스크린 녹화 시작")
                ShadowLogger.shared.log("Start SC For System Sound")
            } catch {
                handleError(error: error, result: result)
            }
        }
    }
    
    public func handleSystemAudioRecordingWithConfig(args: [String: Any]?, result: @escaping FlutterResult) {
        handleSystemAudioRecording(args: args, result: result)
    }
    
    public func handleSystemAudioRecordingWithDefault(result: @escaping FlutterResult) {
        handleSystemAudioRecording(result: result)
    }
    
    public func handleStartScreenCapture(result: @escaping FlutterResult) {
        print("startScreen Capture called!!!")
        Task {
            do {
                try await screenRecorder.getAvailableContent()
                guard let screenEventChannel = ShadowPlugin.screenEventChannel, let screenRecorderOutput = screenRecorder.streamOutput else { return }
                captureEngineStreamOutput = screenRecorderOutput
                screenEventChannel.setStreamHandler(captureEngineStreamOutput)
                result("스크린 녹화 시작")
            } catch {
                handleError(error: error, result: result)
            }
        }
    }
    
    public func handleStopScreenCapture(result: @escaping FlutterResult) {
        print("stopScreenCapture Capture called!!!")
        Task {
            do {
                try await screenRecorder.stopCapture()
                result("스크린 녹화 중지")
            } catch {
                handleError(error: error, result: result)
            }
        }
    }
}
