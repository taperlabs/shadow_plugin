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
                        ShadowLogger.shared.info("screenRecorderOutput \(screenRecorder)")
                            return
                    }
                    ShadowLogger.shared.info("captureEngineStreamOutput == nil")
                    
                    captureEngineStreamOutput = screenRecorderOutput
                    screenEventChannel.setStreamHandler(captureEngineStreamOutput)
                }
                
                //                guard let screenEventChannel = ShadowPlugin.screenEventChannel, let screenRecorderOutput = screenRecorder.streamOutput else { return }
                //                captureEngineStreamOutput = screenRecorderOutput
                //                screenEventChannel.setStreamHandler(captureEngineStreamOutput)
                result("스크린 녹화 시작")
                ShadowLogger.shared.info("Start SC For System Sound")
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

    public func updateCaptureTarget(targetConfig: [String: Any], result: @escaping FlutterResult) {
        Task {
            // Extract type from targetConfig
            guard let type = targetConfig["type"] as? String else {
                result(FlutterError(code: "INVALID_TYPE", message: "Missing or invalid 'type' field in targetConfig", details: nil))
                return
            }

            guard let viewModel = windowManager?.listeningViewModel else {
                result(FlutterError(code: "NO_VIEW_MODEL", message: "ListeningViewModel not available", details: nil))
                return
            }

            // Parse optional search parameters
            let windowID = targetConfig["windowID"] as? Int
            let windowTitle = targetConfig["windowTitle"] as? String
            let displayID = targetConfig["displayID"] as? Int
            let displayName = targetConfig["displayName"] as? String

            // Call ViewModel method to update capture target (now async)
            guard let foundTarget = await viewModel.updateCaptureTarget(
                type: type,
                windowID: windowID,
                windowTitle: windowTitle,
                displayID: displayID,
                displayName: displayName
            ) else {
            // Target not found
            let searchParam: String
            if let id = windowID {
                searchParam = "windowID: \(id)"
            } else if let title = windowTitle {
                searchParam = "windowTitle: '\(title)'"
            } else if let id = displayID {
                searchParam = "displayID: \(id)"
            } else if let name = displayName {
                searchParam = "displayName: '\(name)'"
            } else {
                searchParam = "no search parameters"
            }

            result(FlutterError(
                code: "TARGET_NOT_FOUND",
                message: "Capture target not found for type '\(type)' with \(searchParam)",
                details: nil
            ))
            return
        }

            // Success - return the target info
            ShadowLogger.shared.info("Capture target updated to: \(foundTarget.name)")
            result(foundTarget.asDictionary())
        }
    }

    public func handleEnumerateWindows(result: @escaping FlutterResult) {
        Task {
            // Create a new ScreenshotCaptureService instance for fresh data
            let screenshotService = ScreenshotCaptureService()

            // Fetch both windows and displays
            await screenshotService.getAvailableTargets()
            await screenshotService.getAvailableDisplays()

            // Convert to dictionaries for Flutter
            let windowDictionaries = screenshotService.windows.map { $0.asDictionary() }
            let displayDictionaries = screenshotService.displays.map { $0.asDictionary() }

            // Return response with both windows and displays
            let response: [String: Any] = [
                "windows": windowDictionaries,
                "displays": displayDictionaries
            ]

            DispatchQueue.main.async {
                result(response)
            }
            // screenshotService is automatically deallocated here
        }
    }
}
