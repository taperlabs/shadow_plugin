//import Cocoa
//import FlutterMacOS
//
//public class ShadowPlugin: NSObject, FlutterPlugin {
//    private static let micEventChannelName = "phoenixMicEventChannel"
//    private static let eventChannelName = "phoenixEventChannel"
//    static var screenEventChannel: FlutterEventChannel?
//    var micAudioRecording = MicrophoneRecorder()
//    var screenRecorder = ScreenRecorder()
//    var captureEngineStreamOutput: ScreenRecorderOutputHandler?
//
//    public static func register(with registrar: FlutterPluginRegistrar) {
//        let channel = FlutterMethodChannel(name: "shadow", binaryMessenger: registrar.messenger)
//        let instance = ShadowPlugin()
//        registrar.addMethodCallDelegate(instance, channel: channel)
//
//        let micEventChannel = FlutterEventChannel(name: micEventChannelName, binaryMessenger: registrar.messenger)
//
//        screenEventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger)
//
//        micEventChannel.setStreamHandler(instance.micAudioRecording)
//    }
//
//    //MARK: - Flutter MethodCall Handler
//    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
//        guard let method = MethodChannelCall(rawValue: call.method) else {
//            result(FlutterMethodNotImplemented)
//            return
//        }
//
//        // 1. Create a set of methods that require arguments.
//        let methodsRequiringArgs: Set<MethodChannelCall> = [
//            .startMicRecording,
//            .startMicRecordingWithConfig,
//            .startSystemAudioRecordingWithConfig,
//            .startSystemAndMicAudioRecordingWithConfig
//        ]
//
//        var argsFromFlutter: [String: Any]? = nil
//
//        if methodsRequiringArgs.contains(method) {
//            argsFromFlutter = ArgumentParser.parse(from: call)
//        }
//
//        switch method {
//        case .startMicRecordingWithConfig:
//            //Mic recording with custom configurations
//            handleMicRecordingWithConfig(args: argsFromFlutter, result: result)
//
//        case .startMicRecordingWithDefault:
//            //Mic Recording with default configurations
//            handleMicRecordingWithDefault(result: result)
//
//        case .startSystemAudioRecordingWithConfig:
//            //System audio recording with custom configurations
//            handleSystemAudioRecordingWithConfig(args: argsFromFlutter, result: result)
//
//        case .startSystemAudioRecordingWithDefault:
//            //System audio recording with default configurations
//            handleSystemAudioRecordingWithDefault(result: result)
//
//        case .startSystemAndMicAudioRecordingWithConfig:
//            //System and mic recording with custom configurations
//            print("ARGS 플러터에서 왔어용~~~🥯", argsFromFlutter)
//            handleSystemAudioAndMicRecordingWithConfig(args: argsFromFlutter, result: result)
//            break
//
//        case .startSystemAndMicAudioRecordingWithDefault:
//            //System and mic recording with default configurations
//            handleSystemAudioAndMicRecordingWithDefault(result: result)
//
//        case .stopSystemAndMicAudioRecording:
//            //Stop system and mic recording
//            //            handleStopMicRecording(result: result)
//            //            handleStopScreenCapture(result: result)
//            handleStopSystemAudioAndMicRecording(result: result)
//
//        case .startMicRecording:
//            break
//            //            handleMicRecording(args: argsFromFlutter, result: result)
//
//        case .stopMicRecording:
//            handleStopMicRecording(result: result)
//
//        case .startScreenCapture:
//            handleStartScreenCapture(result: result)
//
//        case .stopScreenCapture:
//            handleStopScreenCapture(result: result)
//
//        case .startFileIO:
//            // Handle startFileIO
//            break
//        }
//    }
//
//
//
//    //    private func parseArguments(from call: FlutterMethodCall) -> [String: Any]? {
//    //        return call.arguments as? [String: Any]
//    //    }
//
//
//    //Start Both System Audio and Microphone Recording
//    //    private func handleSystemAudioAndMicRecordingWithDefault(result: @escaping FlutterResult) {
//    //        Task {
//    //            do {
//    //
//    //                try await screenRecorder.getAvailableContent()
//    //                handleMicRecordingWithDefault(result: result)
//    //
//    //                guard let screenEventChannel = ShadowPlugin.screenEventChannel, let screenRecorderOutput = screenRecorder.streamOutput else { return }
//    //                captureEngineStreamOutput = screenRecorderOutput
//    //                screenEventChannel.setStreamHandler(captureEngineStreamOutput)
//    //                result("스크린 녹화 시작")
//    //            } catch {
//    //                handleError(error: error, result: result)
//    //            }
//    //        }
//    //    }
//
//    //    Handling System Audio Method Call
//    //        private func handleSystemAudioRecording(args: [String: Any]? = nil, result: @escaping FlutterResult) {
//    //            Task {
//    //                do {
//    //                    if let args = args {
//    //                        print("system audio 아규먼트:", args)
//    //                        // Here, you can set up anything specific for the configurable behavior
//    //                        // For example, pass the args to the screenRecorder or any other component that needs it
//    //                        try await screenRecorder.getAvailableContent(withConfig: args)
//    //                    } else {
//    //                        try await screenRecorder.getAvailableContent()
//    //                    }
//    //
//    //                    guard let screenEventChannel = ShadowPlugin.screenEventChannel, let screenRecorderOutput = screenRecorder.streamOutput else { return }
//    //                    captureEngineStreamOutput = screenRecorderOutput
//    //                    screenEventChannel.setStreamHandler(captureEngineStreamOutput)
//    //                    result("스크린 녹화 시작")
//    //                } catch {
//    //                    handleError(error: error, result: result)
//    //                }
//    //            }
//    //        }
//    //
//    //        private func handleSystemAudioRecordingWithConfig(args: [String: Any]?, result: @escaping FlutterResult) {
//    //            handleSystemAudioRecording(args: args, result: result)
//    //        }
//    //
//    //        private func handleSystemAudioRecordingWithDefault(result: @escaping FlutterResult) {
//    //            handleSystemAudioRecording(result: result)
//    //        }
//
//    //    Handling Mic Method Call
//    //        private func handleMicRecordingWithConfig(args: [String: Any]?, result: @escaping FlutterResult) {
//    //            guard let args = args else {
//    //                return
//    //            }
//    //            micAudioRecording.startMicAudioRecording(withConfig: args)
//    //            result("Recording started")
//    //        }
//    //
//    //        private func handleMicRecordingWithDefault(result: @escaping FlutterResult) {
//    //            micAudioRecording.startMicAudioRecording()  // Use default settings
//    //            result("Recording started")
//    //        }
//
//
//
//
//    //    private func handleMicRecording(args: [String: Any]?, result: @escaping FlutterResult) {
//    //        guard let arguments = args, !arguments.isEmpty else {
//    //            micAudioRecording.startMicAudioRecording()  // Use default settings
//    //            result("Recording started")
//    //            return
//    //        }
//    //
//    //        micAudioRecording.startMicAudioRecording(withConfig: arguments)
//    //        result("Recording started")
//
//
//    //        print("startMicRecording called!!!")
//    //        if let arguments = args {
//    //            print("args:", arguments)
//    //        }
//    //        micAudioRecording.startAudioRecording()
//    //        result("Recording started")
//    //    }
//
//    //        private func handleStopMicRecording(result: @escaping FlutterResult) {
//    //            print("stopMicRecording called!!!")
//    //            micAudioRecording.stopMicAudioRecording()
//    //            result("Recording stopped")
//    //        }
//    //
//    //        private func handleStartScreenCapture(result: @escaping FlutterResult) {
//    //            print("startScreen Capture called!!!")
//    //            Task {
//    //                do {
//    //                    try await screenRecorder.getAvailableContent()
//    //                    guard let screenEventChannel = ShadowPlugin.screenEventChannel, let screenRecorderOutput = screenRecorder.streamOutput else { return }
//    //                    captureEngineStreamOutput = screenRecorderOutput
//    //                    screenEventChannel.setStreamHandler(captureEngineStreamOutput)
//    //                    result("스크린 녹화 시작")
//    //                } catch {
//    //                    handleError(error: error, result: result)
//    //                }
//    //            }
//    //        }
//    //
//    //        private func handleStopScreenCapture(result: @escaping FlutterResult) {
//    //            print("stopScreenCapture Capture called!!!")
//    //            Task {
//    //                do {
//    //                    try await screenRecorder.stopCapture()
//    //                    result("스크린 녹화 중지")
//    //                } catch {
//    //                    handleError(error: error, result: result)
//    //                }
//    //            }
//    //        }
//    //
//    //        private func handleError(error: Error, result: @escaping FlutterResult) {
//    //            result(FlutterError(code: "UNAVAILABLE",
//    //                                message: "Failed to handle method call",
//    //                                details: error.localizedDescription))
//    //        }
//}
//
////MARK: - MethodChannel Call Error Handling extension
//extension ShadowPlugin {
//    public func handleError(error: Error, result: @escaping FlutterResult) {
//        result(FlutterError(code: "UNAVAILABLE",
//                            message: "Failed to handle method call",
//                            details: error.localizedDescription))
//    }
//}
//
