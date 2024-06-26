import Foundation
import FlutterMacOS
//MARK: - An extension for both system and mic audio related MethodChannel Call
extension ShadowPlugin {
    
    public func handleSystemAudioAndMicRecordingWithConfig(args: [String: Any]?, result: @escaping FlutterResult) {
        guard let args = args else { return }
        guard let systemAudioConfig = args["systemAudioConfig"],
              let micAudioConfig = args["micConfig"] else {
            return
        }
        
        ShadowLogger.shared.log("MIC Config - \(micAudioConfig), SYS Config - \(systemAudioConfig)")
        
//        print("여기는 인사이드 입니다 1111 \(type(of: systemAudioConfig))", systemAudioConfig)
//        print("여기는 인사이드 입니다 1111 \(type(of: micAudioConfig))", micAudioConfig)
        
        handleSystemAudioRecordingWithConfig(args: (systemAudioConfig as? [String : Any]), result: result)
        handleMicRecordingWithConfig(args: (micAudioConfig as? [String : Any]), result: result)
    }
    
    public func handleSystemAudioAndMicRecordingWithDefault(result: @escaping FlutterResult) {
        Task {
            do {
                try await screenRecorder.getAvailableContent()
                handleMicRecordingWithDefault(result: result)

                // Check if a stream handler is already set
                if captureEngineStreamOutput == nil {
                    guard let screenEventChannel = ShadowPlugin.screenEventChannel,
                          let screenRecorderOutput = screenRecorder.streamOutput else { return }

                    captureEngineStreamOutput = screenRecorderOutput
                    screenEventChannel.setStreamHandler(captureEngineStreamOutput)
                }
                result("스크린 녹화 시작")
            } catch {
                // If there's an error, make sure to clear the existing stream handler
                ShadowPlugin.screenEventChannel?.setStreamHandler(nil)
                captureEngineStreamOutput = nil
                handleError(error: error, result: result)
            }
        }
    }
    
//    public func handleSystemAudioAndMicRecordingWithDefault(result: @escaping FlutterResult) {
//        Task {
//            do {
//                try await screenRecorder.getAvailableContent()
//                handleMicRecordingWithDefault(result: result)
//
//                guard let screenEventChannel = ShadowPlugin.screenEventChannel, let screenRecorderOutput = screenRecorder.streamOutput else { return }
//                captureEngineStreamOutput = screenRecorderOutput
//                screenEventChannel.setStreamHandler(captureEngineStreamOutput)
//                result("스크린 녹화 시작")
//            } catch {
//                handleError(error: error, result: result)
//            }
//        }
//    }
    
    
    public func handleStopSystemAudioAndMicRecording(result: @escaping FlutterResult) {
        
        Task {
            do {
                try await screenRecorder.stopCapture()
                micAudioRecording.stopMicAudioRecording()
                result("스크린 녹화 중지")
                ShadowLogger.shared.log("handleStopSystemAudioAndMicRecording called")
            } catch {
                handleError(error: error, result: result)
                ShadowLogger.shared.log("Stop Sys + Mic Recording Handler - \(error.localizedDescription)")
            }
        }
        
        
        //        let group = DispatchGroup()
        //
        //        group.enter()
        //        DispatchQueue.global().async {
        //            let semaphore = DispatchSemaphore(value: 0)
        //            Task {
        //                do {
        //                    try await self.screenRecorder.stopCapture()
        //                } catch {
        //                    // Handle error if needed
        //                }
        //                semaphore.signal()
        //            }
        //            semaphore.wait()
        //            group.leave()
        //        }
        //
        //        group.enter()
        //        DispatchQueue.global().async {
        //            self.micAudioRecording.stopMicAudioRecording()
        //            group.leave()
        //        }
        //
        //        group.notify(queue: .main) {
        //            result("스크린 녹화 중지")
        //        }
        
        
    }
}
