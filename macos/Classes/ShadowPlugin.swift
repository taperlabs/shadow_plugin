import Cocoa
import AVFoundation
import FlutterMacOS

//MARK: - Fluuter <-> Swift native code entry point class
public class ShadowPlugin: NSObject, FlutterPlugin {
    private static let micEventChannelName = "phoenixMicEventChannel"
    private static let eventChannelName = "phoenixEventChannel"
    private static let micPermissionEventChannelName = "phoenixMicrophonePermissionEventChannel"
    private static let screenRecordingPermissionEventChannelName = "phoenixScreenRecordingPermissionEventChannel"
    private static let shadowMethodChannelName = "shadow"
    private static let nudgeEventChannelName = "phoenixNudgeEventChannel"
    static var screenEventChannel: FlutterEventChannel?
    var micAudioRecording = MicrophoneRecorder()
    var screenRecorder = ScreenRecorder()
    var captureEngineStreamOutput: ScreenRecorderOutputHandler?
    var microphonePermissionClass = MicrophonePermissionStreamHandler()
    var screenRecordingPermissionClass = ScreenRecordingPermissionHandler()
    var nudgeHelperClass = NudgeHelper()
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "shadow", binaryMessenger: registrar.messenger)
        let instance = ShadowPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let micEventChannel = FlutterEventChannel(name: micEventChannelName, binaryMessenger: registrar.messenger)
        screenEventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger)
        let micPermissionEventChannel = FlutterEventChannel(name: micPermissionEventChannelName, binaryMessenger: registrar.messenger)
        let screenRecordingPermissionEventChannel = FlutterEventChannel(name: screenRecordingPermissionEventChannelName, binaryMessenger: registrar.messenger)
        
        let nudgeEventChannel = FlutterEventChannel(name: nudgeEventChannelName, binaryMessenger: registrar.messenger)
        
        nudgeEventChannel.setStreamHandler(instance.nudgeHelperClass)
        
        micEventChannel.setStreamHandler(instance.micAudioRecording)
        
        //Permission Status Event Channel
        micPermissionEventChannel.setStreamHandler(instance.microphonePermissionClass)
        screenRecordingPermissionEventChannel.setStreamHandler(instance.screenRecordingPermissionClass)
    }
    
    
    //MARK: - Flutter MethodCall Handler
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let method = MethodChannelCall(rawValue: call.method) else {
            result(FlutterMethodNotImplemented)
            return
        }
        
        //A set of methods that require arguments from Flutter.
        let methodsRequiringArgs: Set<MethodChannelCall> = [
            .startMicRecordingWithConfig,
            .startSystemAudioRecordingWithConfig,
            .startSystemAndMicAudioRecordingWithConfig,
            .deleteFileIfExists
        ]
        
        var argsFromFlutter: [String: Any]? = nil
        
        if methodsRequiringArgs.contains(method) {
            argsFromFlutter = ArgumentParser.parse(from: call)
        }
        
        switch method {
            
        case .getAllScreenPermissionStatuses:
            let statusCGPREFLIGHT = PermissionStatusCheckerHelper.checkScreenRecordingPermission()
            let statusCGWINDOW = screenRecordingPermissionClass.isScreenRecordingGranted
            let response: [String: Any] = ["statusCGPREFLIGHT": statusCGPREFLIGHT, "statusCGWINDOW": statusCGWINDOW]
            result(response)
            
        case .restartApp:
            RestartApplication.relaunch()
        case .isMicPermissionGranted:
//            let status = PermissionStatusCheckerHelper.checkMicrophonePermission()
            let status = microphonePermissionClass.isMicrophonePermissionGranted
            result(status)
        case .isScreenPermissionGranted:
            let response = PermissionStatusCheckerHelper.checkScreenRecordingPermission()
            result(response)
            
        case .openMicSystemSetting:
            SystemSettingsHandler.openSystemSetting(for: "microphone")
        
        case .openScreenSystemSetting:
            SystemSettingsHandler.openSystemSetting(for: "screen")
            
        case .deleteFileIfExists:
            handleFileDeletion(args: argsFromFlutter, result: result)
            
        case .requestScreenPermission:
            screenRecordingPermissionClass.requestScreenRecordingPermission()
            
            
            
//            ScreenRecorderPermissionHandler.requestScreenRecordingPermission()
            //            SystemSettingsHandler.checkScreenRecordingPermission()

            //            Task {
            //                try await ScreenRecorderPermissionHandler.requestScreenRecorderPermission()
            //            }
            
        case .requestMicPermission:
            microphonePermissionClass.requestMicrophoneAccess { granted in
                if granted {
                    print("GrantedD!!")
                } else {
                    print("dfsdfs")
                }
            }
//            let microphoneService = MicrophonePermissionHandler.shared
//            microphoneService.requestMicrophoneAccess { granted in
//                // Handle the result
//
//                if granted {
//                    print("Granted!!!! Mic")
//                } else {
//                    print("Not granted")
//                }
//            }
            
//            MicrophonePermissionHandler.requestMicrophonePermission { granted in
//                if granted {
//                    print("granted!!!")
//                    // Proceed with your audio recording or processing code
//                } else {
//                    print("grant denied")
//                }
//            }
            
        case .startMicRecordingWithConfig:
            //Mic recording with custom configurations
            handleMicRecordingWithConfig(args: argsFromFlutter, result: result)
            
        case .startMicRecordingWithDefault:
            //Mic Recording with default configurations
            handleMicRecordingWithDefault(result: result)
            
        case .startSystemAudioRecordingWithConfig:
            //System audio recording with custom configurations
            handleSystemAudioRecordingWithConfig(args: argsFromFlutter, result: result)
            
        case .startSystemAudioRecordingWithDefault:
            //System audio recording with default configurations
            handleSystemAudioRecordingWithDefault(result: result)
            
        case .startSystemAndMicAudioRecordingWithConfig:
            //System and mic recording with custom configurations
            handleSystemAudioAndMicRecordingWithConfig(args: argsFromFlutter, result: result)
            break
            
        case .startSystemAndMicAudioRecordingWithDefault:
            //System and mic recording with default configurations
            handleSystemAudioAndMicRecordingWithDefault(result: result)
            
        case .stopSystemAndMicAudioRecording:
            //Stop system and mic recording
            handleStopSystemAudioAndMicRecording(result: result)
            
        case .startMicRecording:
            break
            
        case .stopMicRecording:
            handleStopMicRecording(result: result)
            
        case .startScreenCapture:
            handleStartScreenCapture(result: result)
            
        case .stopScreenCapture:
            handleStopScreenCapture(result: result)
            
        case .startFileIO:
            // Handle startFileIO
            break
        }
    }
}

//MARK: - MethodChannel Call Error Handling extension
extension ShadowPlugin {
    public func handleError(error: Error, result: @escaping FlutterResult) {
        result(FlutterError(code: "UNAVAILABLE",
                            message: "Failed to handle method call",
                            details: error.localizedDescription))
    }
}

//MARK: - File deletion handler extension
extension ShadowPlugin {
    public func handleFileDeletion(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = args else { return }
        guard let fileName = args["fileName"] as? String else { return }
        guard let fileURL = FileManagerHelper.getURL(for: fileName) else {
            print("File URL을 가져오는데 실패하였습니다.")
            return
        }
        
        FileManagerHelper.deleteFileIfExists(at: fileURL)
        
        result("파일 삭제 성공!!!")
    }
}
