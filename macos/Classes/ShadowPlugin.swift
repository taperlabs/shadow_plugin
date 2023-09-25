import Cocoa
import FlutterMacOS

//MARK: - Fluuter <-> Swift native code entry point class
public class ShadowPlugin: NSObject, FlutterPlugin {
    private static let micEventChannelName = "phoenixMicEventChannel"
    private static let eventChannelName = "phoenixEventChannel"
    static var screenEventChannel: FlutterEventChannel?
    var micAudioRecording = MicrophoneRecorder()
    var screenRecorder = ScreenRecorder()
    var captureEngineStreamOutput: ScreenRecorderOutputHandler?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "shadow", binaryMessenger: registrar.messenger)
        let instance = ShadowPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let micEventChannel = FlutterEventChannel(name: micEventChannelName, binaryMessenger: registrar.messenger)
        
        screenEventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger)
        
        micEventChannel.setStreamHandler(instance.micAudioRecording)
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
            .startSystemAndMicAudioRecordingWithConfig
        ]
        
        var argsFromFlutter: [String: Any]? = nil
        
        if methodsRequiringArgs.contains(method) {
            argsFromFlutter = ArgumentParser.parse(from: call)
        }
        
        switch method {
        case .requestMicPermission:
            print("Microphone 퍼미션 핸드럴")
            MicrophonePermissionHandler.requestMicPermission()
            
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
