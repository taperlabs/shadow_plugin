import Cocoa
import AVFoundation
import FlutterMacOS
import RegexBuilder


//MARK: - Fluuter <-> Swift native code entry point class
public class ShadowPlugin: NSObject, FlutterPlugin {
    private static let micEventChannelName = "phoenixMicEventChannel"
    private static let eventChannelName = "phoenixEventChannel"
    private static let micPermissionEventChannelName = "phoenixMicrophonePermissionEventChannel"
    private static let screenRecordingPermissionEventChannelName = "phoenixScreenRecordingPermissionEventChannel"
    private static let shadowMethodChannelName = "shadow"
    private static let nudgeEventChannelName = "phoenixNudgeEventChannel"
    private static let micAudioLevelEventsName = "micAudioLevelEventChannel"
    private static let screenCaptureKitBugEventsName = "screenCaptureKitBugEventChannel"
    
    private static let multiWindowEventChannelName = "multiWindowEventChannel"
    private static let multiWindowStatusEventChannelName = "multiWindowStatusEventChannel"
    private static let listeningStatusEventChannelName = "listeningStatusEventChannel"
    
    private var windowManager: WindowManager?
    private var listeningViewModel: ListeningViewModel?
    static var multiWindowEventChannel: FlutterEventChannel?
    static var multiWindowStatusEventChannel: FlutterEventChannel?
    static var listeningStatusEventChannel: FlutterEventChannel?
    private var registrar: FlutterPluginRegistrar?
    private static var instance: ShadowPlugin?
    
    static var screenEventChannel: FlutterEventChannel?
    var micAudioRecording = MicrophoneRecorder()
    var screenRecorder = ScreenRecorder()
    var captureEngineStreamOutput: ScreenRecorderOutputHandler?
    var microphonePermissionClass = MicrophonePermissionStreamHandler()
    var screenRecordingPermissionClass = ScreenRecordingPermissionHandler()
    //    var nudgeHelperClass = NudgeHelper()
    //    var nudgeHelperClass = NudgeService()
    var autopilotClass = Autopilot()
    let coreAudioHandler = CoreAudioHandler()
    let screenCaptureKitBugEventsClass = ScreenCaptureKitBugHandler()
    var systemAudioOnlyPermission = SystemAudioOnlyPermission()

    
    func isFontAvailable(_ fontName: String) -> Bool {
        _ = NSFontManager.shared.availableFontFamilies
        _ = NSFontManager.shared.availableMembers(ofFontFamily: fontName)?.map { $0[0] as! String } ?? []
        
        //        print("Available font families: \(fontFamilyNames)")
        //        print("Available font names for family '\(fontName)': \(fontNames)")
        
        return NSFont(name: fontName, size: 12) != nil
    }
    
    private func handleStopListening(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let listeningVM = windowManager?.listeningViewModel else {
            result(FlutterError(code: "UNAVAILABLE", message: "ListeningViewModel not available in windowManager", details: nil))
            return
        }
        
        guard listeningVM.isRecording else {
            result(FlutterError(code: "Not in Recording", message: "The recording is not in session.", details: nil))
            return
        }
        
        if let countDownNumber = listeningVM.countdownNumber {
            if countDownNumber >= 1 {
                listeningVM.stopMicRecording()
                listeningVM.isRecording = false
                WindowManager.shared.closeCurrentWindow(for: .cancel)
            }
        } else {
            listeningVM.stopMicRecording()
            listeningVM.isRecording = false
            WindowManager.shared.closeCurrentWindow(for: .done)
        }
        result("Stop Listening Successful")
    }
    
    private func handleCreateNewWindow(call: FlutterMethodCall , result: @escaping FlutterResult) {
        if windowManager == nil {
            windowManager = WindowManager.shared
        }
        
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments for sendHotKeyEvent", details: nil))
            return
        }
        
        guard let listeningConfig = args["listeningConfig"] as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid listeningConfig value", details: nil))
            return
        }
        
        print("listeningConifg 값 확인입니다 -- \(listeningConfig)")
        
        //        guard let micFileName = listeningConfig["micFileName"] as? String,
        //              let sysFileName = listeningConfig["sysFileName"] as? String else {
        //            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid listeningConfig value", details: nil))
        //            return
        //        }
        let hotkeys = listeningConfig["hotkeys"] as? String ?? ""
        let plusPattern = Regex {
            "+"
        }
        let formattedHotkeys = hotkeys.replacing(plusPattern, with: " ")
        
        let username = listeningConfig["userName"] as? String ?? ""
        _ = listeningConfig["key"] as? Int ?? 0
        _ = listeningConfig["modifiers"] as? Int ?? 0
        _ = listeningConfig["uuid"] as? String ?? ""
        
        // TODO: - 파일 네임 고민 (세그먼트, Full Length)
        let micFileName = listeningConfig["micFileName"] as? String ?? ""
        let sysFileName = listeningConfig["sysFileName"] as? String ?? ""
        let isAudioSaveOn = listeningConfig["isAudioSaveOn"] as? Bool ?? false
        
        guard let registrar = registrar else {
            result(FlutterError(code: "UNAVAILABLE", message: "Registrar not available", details: nil))
            return
        }
        
        // Use the existing listeningViewModel or create a new one if nil
        if windowManager?.listeningViewModel == nil {
            let newListeningVM = ListeningViewModel()
            if !loadAssets(registrar: registrar, listeningVM: newListeningVM) {
                result(FlutterError(code: "ASSET_LOADING_FAILED", message: "Failed to load assets", details: nil))
                return
            }
            // Set the new ViewModel and update the event channel
            windowManager?.setListeningViewModel(listeningViewModel: newListeningVM)
            if let eventChannel = ShadowPlugin.multiWindowEventChannel {
                eventChannel.setStreamHandler(newListeningVM)
            } else {
                print("Warning: eventChannel is nil, unable to set stream handler")
            }
        }
        
        guard let newListeningVM = windowManager?.listeningViewModel else {
            result(FlutterError(code: "UNAVAILABLE", message: "ListeningViewModel not available in windowManager", details: nil))
            return
        }
        newListeningVM.setHotkeys(with: formattedHotkeys)
        newListeningVM.setupRecordingProperties(userName: username, micFileName: micFileName, sysFileName: sysFileName, isAudioSaveOn: isAudioSaveOn)
        
        if WindowManager.shared.currentWindow == nil {
            let windowViewState = ShadowPlugin.from(method: call.method)
            windowManager?.createWindow(with: windowViewState)
        } else {
            if newListeningVM.isRecording {
                print("녹화중")
                if let countDownNumber = newListeningVM.countdownNumber {
                    if countDownNumber > 1 {
                        newListeningVM.stopMicRecording()
                        newListeningVM.isRecording = false
                        WindowManager.shared.closeCurrentWindow(for: .cancel)
                    }
                } else {
                    newListeningVM.stopMicRecording()
                    newListeningVM.isRecording = false
                    WindowManager.shared.closeCurrentWindow(for: .done)
                }
            } else {
                print("녹화아님")
                newListeningVM.renderListeningView()
                WindowManager.shared.moveWindowToBottomLeft()
                MultiWindowStatusService.shared.sendWindowStatus(WindowStatus(windowState: .listening, isRecording: true))
                WindowManager.shared.updateWindowState(.listening, isRecording: true)
            }
        }
        result(nil)
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "shadow", binaryMessenger: registrar.messenger)
        let instance = ShadowPlugin()
        
        instance.registrar = registrar
        multiWindowEventChannel = FlutterEventChannel(name: multiWindowEventChannelName, binaryMessenger: registrar.messenger)
        let multiWindowStatusEventChannel = FlutterEventChannel(name: multiWindowStatusEventChannelName, binaryMessenger: registrar.messenger)
        multiWindowStatusEventChannel.setStreamHandler(MultiWindowStatusService.shared)
        
        listeningStatusEventChannel = FlutterEventChannel(name: listeningStatusEventChannelName, binaryMessenger: registrar.messenger)
        listeningStatusEventChannel?.setStreamHandler(ListeningStatusService.shared)
        
        let windowManager = WindowManager.shared
        instance.windowManager = windowManager
        
        
        guard let app = NSApplication.shared.delegate as? FlutterAppDelegate else {
            debugPrint("failed to find flutter main window, application delegate is not FlutterAppDelegate")
            return
        }
        guard let window = app.mainFlutterWindow else {
            debugPrint("failed to find flutter main window")
            return
        }
        
        print("app - \(app), window - \(window)")
        
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        let micEventChannel = FlutterEventChannel(name: micEventChannelName, binaryMessenger: registrar.messenger)
        let micAudioLevelEventChannel = FlutterEventChannel(name: micAudioLevelEventsName, binaryMessenger: registrar.messenger)
        
        screenEventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: registrar.messenger)
        
        let micPermissionEventChannel = FlutterEventChannel(name: micPermissionEventChannelName, binaryMessenger: registrar.messenger)
        let screenRecordingPermissionEventChannel = FlutterEventChannel(name: screenRecordingPermissionEventChannelName, binaryMessenger: registrar.messenger)
        
        
        let screenCaptureKitBugEventChannel = FlutterEventChannel(name: screenCaptureKitBugEventsName, binaryMessenger: registrar.messenger)
        screenCaptureKitBugEventChannel.setStreamHandler(instance.screenCaptureKitBugEventsClass)
        
        //        let nudgeEventChannel = FlutterEventChannel(name: nudgeEventChannelName, binaryMessenger: registrar.messenger)
        let autopilotEventChannel = FlutterEventChannel(name: nudgeEventChannelName, binaryMessenger: registrar.messenger)
        autopilotEventChannel.setStreamHandler(instance.autopilotClass)
        
        //        nudgeEventChannel.setStreamHandler(instance.nudgeHelperClass)
        
        micEventChannel.setStreamHandler(instance.micAudioRecording)
        micAudioLevelEventChannel.setStreamHandler(instance.micAudioRecording)
        
        //Permission Status Event Channel
        micPermissionEventChannel.setStreamHandler(instance.microphonePermissionClass)
        screenRecordingPermissionEventChannel.setStreamHandler(instance.screenRecordingPermissionClass)
    }
    
    private func handleCancelListening(call: FlutterMethodCall, result: @escaping FlutterResult){
        guard let listeningVM = windowManager?.listeningViewModel else {
            result(FlutterError(code: "UNAVAILABLE", message: "ListeningViewModel not available in windowManager", details: nil))
            return
        }
        
        guard listeningVM.isRecording else {
            result(FlutterError(code: "Not_in_listening_mode", message: "Listening is not in session.", details: nil))
            return
        }
        
        listeningVM.cancelListening()
        WindowManager.shared.closeCurrentWindow(for: .cancel)
        result("Cancelled Listening")
    }
    
    private func newHandleStopListening(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let listeningVM = windowManager?.listeningViewModel else {
            result(FlutterError(code: "UNAVAILABLE", message: "ListeningViewModel not available in windowManager", details: nil))
            return
        }
        
        guard listeningVM.isRecording else {
            result(FlutterError(code: "Not_in_listening_mode", message: "Listening is not in session.", details: nil))
            return
        }
        
        if let countDownNumber = listeningVM.countdownNumber {
            if countDownNumber >= 0 {
                listeningVM.cancelListening()
                
                WindowManager.shared.closeCurrentWindow(for: .cancel)
            }
        } else {
            listeningVM.stopListening()
            WindowManager.shared.closeCurrentWindow(for: .done)
        }
        result("Stop Listening Successful")
    }
    
    private func handleListening(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = ArgumentParser.parse(from: call),
              let listeningConfig = args["listeningConfig"] as? [String: Any],
              let userName = listeningConfig["userName"] as? String,
              let micFileName = listeningConfig["micFileName"] as? String,
              let sysFileName = listeningConfig["sysFileName"] as? String,
              let convUuid = listeningConfig["uuid"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGUMENTS",
                message: "Missing or invalid listeningConfig parameters",
                details: nil))
            return
        }
        
        print("UserName: \(userName), micFileName: \(micFileName), sysFileName: \(sysFileName), uuid: \(convUuid)")
        
        // Create a Listening window
        // First check if windowManager is available
        if windowManager == nil {
            windowManager = WindowManager.shared
        }
        
        // Window 생성 및 뷰모델 생성 이벤트 채널 스트림 셋하기
        guard let registrar = registrar else {
            result(FlutterError(code: "UNAVAILABLE_registrar", message: "Registrar not available", details: nil))
            return
        }
        
        // Use the existing listeningViewModel or create a new one if nil
        if windowManager?.listeningViewModel == nil {
            let newListeningVM = ListeningViewModel()
            if !loadAssets(registrar: registrar, listeningVM: newListeningVM) {
                result(FlutterError(code: "ASSET_LOADING_FAILED", message: "Failed to load assets", details: nil))
                return
            }
            // Set the new ViewModel and update the event channel
            windowManager?.setListeningViewModel(listeningViewModel: newListeningVM)
            if let eventChannel = ShadowPlugin.multiWindowEventChannel {
                eventChannel.setStreamHandler(newListeningVM)
            } else {
                result(FlutterError(code: "EVENTCHANNEL_SET_ERROR", message: "eventChannel is nil, unable to set stream handler", details: nil))
                print("Warning: eventChannel is nil, unable to set stream handler")
            }
        }
        
        guard let newListeningVM = windowManager?.listeningViewModel else {
            result(FlutterError(code: "UNAVAILABLE", message: "ListeningViewModel not available in windowManager", details: nil))
            return
        }
        newListeningVM.setRecordingProperties(userName: userName, micFileName: micFileName, sysFileName: sysFileName, uuid: convUuid)
        
        if WindowManager.shared.currentWindow == nil {
            windowManager?.createListeningWindow()
            
            result("Create a new listening window")
            
        } else {
            if newListeningVM.isRecording {
                print("녹화 시작 했습니다")
                if let countDownNumber = newListeningVM.countdownNumber {
                    if countDownNumber >= 0 {
                        print("CountDown 중 종료입니다 캔슬하겠습니다 \(countDownNumber)")
                        newListeningVM.stopListening()
                        newListeningVM.isRecording = false
                        WindowManager.shared.closeCurrentWindow(for: .cancel)
                        result("Cancel Listening")
                    } else {
                        print("녹음을 종료하겠습니다")
                        newListeningVM.stopListening()
                        newListeningVM.isRecording = false
                        WindowManager.shared.closeCurrentWindow(for: .done)
                        result("Done Listening")
                    }
                }
            }
        }
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
            .deleteFileIfExists,
            .setAudioInputDevice
        ]
        
        var argsFromFlutter: [String: Any]? = nil
        
        if methodsRequiringArgs.contains(method) {
            argsFromFlutter = ArgumentParser.parse(from: call)
        }
        
        switch method {
            
        case .checkSystemAudioPermission:
            print("Cehck System Audio Permission")
            result("Cehck System Audio Permission")
        
        case .requestSystemAudioPermission:
            print("requestSystemAudioPermission")
            result("requestSystemAudioPermission")
            systemAudioOnlyPermission.request()
            
        case .testStopListening:
            print("TEST STOP LISTENING")
            newHandleStopListening(call: call, result: result)
            
            
        case .testStartListening:
            handleListening(call: call, result: result)
            
        case .cancelListening:
            print("Cancel Listening")
            handleCancelListening(call: call, result: result)
            
        case .startListening:
            print("Start Listening")
            handleCreateNewWindow(call: call, result: result)
            
        case .stopListening:
            print("Stop Listening")
            //            handleCreateNewWindow(call: call, result: result)
            handleStopListening(call: call, result: result)
            
        case .createNewWindow:
            handleCreateNewWindow(call: call, result: result)
            
        case .sendHotKeyEvent:
            handleCreateNewWindow(call: call, result: result)
            
        case .stopShadowServer:
            print("stopShadowServer 불렸다")
            stopShadowServer(result: result)
            
        case .startShadowServer:
            print("startShadowServer 불렸다")
            startShadowServer(result: result)
        case .getDefaultAudioInputDevice:
            getDefaultAudioInputDevice(result: result)
            
        case .setAudioInputDevice:
            setAudioDeviceList(args: argsFromFlutter, result: result)
            
        case .getAudioInputDeviceList:
            let audioDeviceList = coreAudioHandler.getAllAudioInputDevicesByNames()
            let deviceArray = Array(audioDeviceList)
            result(deviceArray)
            
        case .getAllScreenPermissionStatuses:
            let statusCGPREFLIGHT = PermissionStatusCheckerHelper.checkScreenRecordingPermission()
            let statusCGWINDOW = screenRecordingPermissionClass.isScreenRecordingGranted
            let micPermissionStatus = microphonePermissionClass.isMicrophonePermissionGranted
            let response: [String: Any] = ["statusCGPREFLIGHT": statusCGPREFLIGHT, "statusCGWINDOW": statusCGWINDOW, "micPermissionStatus": micPermissionStatus]
            print("getAllScreenPermissionStatuses \(response)")
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
        ShadowLogger.shared.log("Failed to handle Stop SC error called - \(error.localizedDescription)")
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
        guard let fileURL = FileManagerHelper.getURL(for: fileName, in: "ApplicationSupportDirectory") else {
            print("File URL을 가져오는데 실패하였습니다.")
            return
        }
        
        FileManagerHelper.deleteFileIfExists(at: fileURL)
        
        result("파일 삭제 성공!!!")
    }
}

extension ShadowPlugin {
    struct AssetPaths {
//        let lottie: String
        let waveform: String
        let font: String
//        let done: String
//        let cancel: String
//        let minimize: String
    }
    
    func loadAssets(registrar: FlutterPluginRegistrar, listeningVM: ListeningViewModel) -> Bool {
        let bundlePath = Bundle.main.bundlePath
        let fileManager = FileManager.default
        
        let assetPaths = AssetPaths(
//            lottie: registrar.lookupKey(forAsset: "assets/lotties/loading_white.json"),
            waveform: registrar.lookupKey(forAsset: "assets/lotties/waveformicon.json"),
            font: registrar.lookupKey(forAsset: "assets/fonts/Inter-Regular.ttf")
//            done: registrar.lookupKey(forAsset: "assets/images/icon/listening/done.svg"),
//            cancel: registrar.lookupKey(forAsset: "assets/images/icon/listening/cancel.svg"),
//            minimize: registrar.lookupKey(forAsset: "assets/images/icon/listening/minimize.svg")
        )
        
        // Log the asset paths returned by lookupKey
        print("Asset paths from lookupKey:")
//        print("Lottie: \(assetPaths.lottie)")
        print("Waveform: \(assetPaths.waveform)")
        print("Font: \(assetPaths.font)")
//        print("Done: \(assetPaths.done)")
//        print("Cancel: \(assetPaths.cancel)")
//        print("Minimize: \(assetPaths.minimize)")
        
        let fullPaths = AssetPaths(
//            lottie: "\(bundlePath)/\(assetPaths.lottie)",
            waveform: "\(bundlePath)/\(assetPaths.waveform)",
            font: "\(bundlePath)/\(assetPaths.font)"
//            done: "\(bundlePath)/\(assetPaths.done)",
//            cancel: "\(bundlePath)/\(assetPaths.cancel)",
//            minimize: "\(bundlePath)/\(assetPaths.minimize)"
        )
        
        // Log the full paths
        print("Bundle path: \(bundlePath)")
        print("Full paths:")
//        print("Lottie: \(fullPaths.lottie)")
        print("Waveform: \(fullPaths.waveform)")
        print("Font: \(fullPaths.font)")
//        print("Done: \(fullPaths.done)")
//        print("Cancel: \(fullPaths.cancel)")
//        print("Minimize: \(fullPaths.minimize)")
        
        // Check if files exist and log the results
        for (assetName, path) in [
//            ("Lottie", fullPaths.lottie),
            ("Waveform", fullPaths.waveform),
            ("Font", fullPaths.font),
//            ("Done", fullPaths.done),
//            ("Cancel", fullPaths.cancel),
//            ("Minimize", fullPaths.minimize)
        ] {
            if fileManager.fileExists(atPath: path) {
                print("✅ \(assetName) file exists at path: \(path)")
            } else {
                print("❌ \(assetName) file does not exist at path: \(path)")
            }
        }
        
        // Register font
        if !registerFont(at: fullPaths.font) {
            print("❌ Failed to register font at path: \(fullPaths.font)")
            return false
        }
        
        // Update ViewModel paths
        listeningVM.updateWaveformPath(fullPaths.waveform)
//        listeningVM.updateLottiePath(fullPaths.lottie)
//        listeningVM.updateDonePath(fullPaths.done)
//        listeningVM.updateCancelPath(fullPaths.cancel)
//        listeningVM.updateMinimizePath(fullPaths.minimize)
        
        return true
    }
    
    private func registerFont(at path: String) -> Bool {
        guard let fontData = NSData(contentsOfFile: path),
              let dataProvider = CGDataProvider(data: fontData),
              let font = CGFont(dataProvider) else {
            print("Couldn't create font from file: \(path)")
            return false
        }
        
        var error: Unmanaged<CFError>?
        guard CTFontManagerRegisterGraphicsFont(font, &error) else {
            print("Error registering font: \(error.debugDescription)")
            return false
        }
        
        let fontName = "Inter-Regular"
        if isFontAvailable(fontName) {
            print("Font '\(fontName)' is available")
        } else {
            print("Font '\(fontName)' is not available")
            return false
        }
        
        return true
    }
}

extension ShadowPlugin {
    public func setAudioDeviceList(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = args else {
            return
        }
        
        guard let deviceName = args["deviceName"] as? String else {
            result("Wrong argument passed from Flutter")
            return
        }
        
        guard let deviceID = coreAudioHandler.getInputDeviceID(fromName: deviceName) else {
            result("Audio input device does not exist")
            return
        }
        
        let isChaningDeviceSuccessful = coreAudioHandler.setAudioInputDevice(deviceID: deviceID)
        result(isChaningDeviceSuccessful)
    }
    
    public func getDefaultAudioInputDevice(result: @escaping FlutterResult) {
        guard let currentAudioInputDeviceID = coreAudioHandler.getDefaultAudioInputDevice() else {
            result("Current audio input device ID does not exist")
            return
        }
        let currentAudioInputDeviceName = coreAudioHandler.getDeviceName(deviceID: currentAudioInputDeviceID)
        
        result(currentAudioInputDeviceName)
    }
}

//MARK: Shadow Server
extension ShadowPlugin {
    public func startShadowServer(result: @escaping FlutterResult) {
        let shadowServerApp = ShadowServerHandler()
        
        if shadowServerApp.isAppRunning() {
            result("App already running")
            ShadowLogger.shared.log("App already running - \(shadowServerApp.isAppRunning())")
            return
        }
        shadowServerApp.launchShadowServer(result: result)
    }
    
    public func stopShadowServer(result: @escaping FlutterResult) {
        let shadowServerApp = ShadowServerHandler()
        
        if !shadowServerApp.isAppRunning() {
            result("App is not running")
            ShadowLogger.shared.log("App is not running - \(shadowServerApp.isAppRunning())")
            return
        }
        
        shadowServerApp.terminateApp()
        result("App termination requested")
    }
    
    public func checkIsShadowServerRunning(result: @escaping FlutterResult) {
        let shadowServerApp = ShadowServerHandler()
        let isServerRunning = shadowServerApp.isAppRunning()
        result(isServerRunning)
    }
}

extension ShadowPlugin {
    static func from(method: String) -> WindowViewState {
        method == "startListening" ? .listening : .preListening
    }
}

