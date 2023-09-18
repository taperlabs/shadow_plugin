//import Foundation
//import AVFAudio
//import AVFoundation
//import ScreenCaptureKit
//import FlutterMacOS
//
//
//struct CapturedFrame {
//    static let invalid = CapturedFrame(surface: nil, contentRect: .zero, contentScale: 0, scaleFactor: 0)
//
//    let surface: IOSurface?
//    let contentRect: CGRect
//    let contentScale: CGFloat
//    let scaleFactor: CGFloat
//    var size: CGSize { contentRect.size }
//}
//
//
//// MARK: - Screen Video + System Audio Capture 클래스
//class ScreenRecorder {
//    var stream: SCStream?
//    var display : [SCDisplay]?
//    var windows: [SCWindow]?
//    var apps: [SCRunningApplication]?
//    var filtered: SCContentFilter?
//    var streamConfig: SCStreamConfiguration?
//    //    var streamOutput: CaptureEngineStreamOutput?
//    var streamOutput: ScreenRecorderOutputHandler?
//    var assetWriterSetup = AssetWriterHelper()
//
//    var timeIndicator = TimeIndicator()
//
//    var isRecording: Bool = false
//
//    var micRecording = MicrophoneRecorder()
//
////    var isRecording: Bool = false {
////        didSet {
////            streamOutput?.sendRecordingStatusToFlutter(isRecording)
////        }
////    }
//
//    func getAvailableContent() async throws {
//        do {
//            let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
//
//            display = availableContent.displays
//
//            let excludedApps = availableContent.applications.filter { app in
//                Bundle.main.bundleIdentifier == app.bundleIdentifier
//            }
//
//            filtered = SCContentFilter(display: availableContent.displays[0],
//                                       excludingApplications: excludedApps,
//                                       exceptingWindows: [])
//
//            setStreamConfig()
//
//            try await startCapture()
//        } catch  {
//            print(error)
//            display = [] // Set display to an empty array in case of an error
//        }
//    }
//
//
//    func startCapture() async throws {
//
//        guard let filtered = filtered,
//              let streamConfig = streamConfig else {
//            print("Required parameters are nil.")
//            return
//        }
//
//        //이곳에서 Screen Recorder Instance를 인자로 넘겨준다
//        //그래야 Set up 된 AVAssetWriter 클래스를 사용할 수 있음
////        streamOutput = ScreenRecorderOutputHandler(recorder: self)
//        streamOutput = ScreenRecorderOutputHandler(recorder: self, timeIndicator: timeIndicator)
//
//        let videoSampleBufferQueue = DispatchQueue(label: "phoenix")
//        let audioSampleBufferQueue = DispatchQueue(label: "phoenix2")
//
//        do {
//            //            assetWriterSetup.setUpAssetWriter()
//            assetWriterSetup.setUpSystemAudioAssetWriter()
//            stream = SCStream(filter: filtered, configuration: streamConfig, delegate: streamOutput)
//
//            //Stream Delegate 넘기기
//            try stream?.addStreamOutput(streamOutput!, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
//            try stream?.addStreamOutput(streamOutput!, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)
//            micRecording.startMicAudioRecording()
//
//            isRecording = true
//            print("Start Capture IsRecording", isRecording)
//            streamOutput?.startSendingStatus()
//
//            timeIndicator.start()
//
//            timeIndicator.timeUpdateHandler = { [weak self] _ in
//                self?.streamOutput?.sendTimeUpdate()
//            }
//
//        } catch {
//            print("Failed to add stream output: \(error)")
//            return
//        }
//
//        do {
//            try await stream?.startCapture()
//        } catch {
//            print("Failed to start capture: \(error)")
//        }
//    }
//
//    func stopCapture() async throws {
//        do {
//            print("Stop Capture Called!!!!")
//            try await stream?.stopCapture()
//            micRecording.stopMicAudioRecording()
//
//            isRecording = false
//            print("Stop Capture IsRecording", isRecording)
//            streamOutput?.stopSendingStatus()
//            timeIndicator.stop()
//
//            finishAssetWriting(assetWriter: assetWriterSetup.systemAudioAssetWriter)
//            finishAssetWriting(assetWriter: assetWriterSetup.assetWriter)
//
//            if let systemAudioAssetWriter = assetWriterSetup.systemAudioAssetWriter {
//                switch systemAudioAssetWriter.status {
//                case .unknown:
//                    print("AssetWriter Status: Unknown")
//
//                case .writing:
//                    print("AssetWriter Status: Writing")
//                    systemAudioAssetWriter.finishWriting {
//                        print("Finished writing to output file at:", systemAudioAssetWriter.outputURL)
//                    }
//
//                case .completed:
//                    print("AssetWriter Status: Completed successfully")
//
//                case .failed:
//                    if let error = systemAudioAssetWriter.error {
//                        print("Asset writer failed with error: \(error.localizedDescription)")
//                    } else {
//                        print("AssetWriter Status: Failed (Unknown reason)")
//                    }
//
//                case .cancelled:
//                    print("AssetWriter Status: Cancelled")
//
//                @unknown default:
//                    print("AssetWriter Status: Encountered unknown status")
//                }
//            } else {
//                print("AssetWriter is nil")
//            }
//
//            if let assetWriter = assetWriterSetup.assetWriter {
//                switch assetWriter.status {
//                case .unknown:
//                    print("AssetWriter Status: Unknown")
//
//                case .writing:
//                    print("AssetWriter Status: Writing")
//                    assetWriter.finishWriting {
//                        print("Finished writing to output file at:", assetWriter.outputURL)
//                    }
//
//                case .completed:
//                    print("AssetWriter Status: Completed successfully")
//
//                case .failed:
//                    if let error = assetWriter.error {
//                        print("Asset writer failed with error: \(error.localizedDescription)")
//                    } else {
//                        print("AssetWriter Status: Failed (Unknown reason)")
//                    }
//
//                case .cancelled:
//                    print("AssetWriter Status: Cancelled")
//
//                @unknown default:
//                    print("AssetWriter Status: Encountered unknown status")
//                }
//            } else {
//                print("AssetWriter is nil")
//            }
//
//        } catch  {
//            print(error)
//        }
//        print("Stop Capture() Completed")
//    }
//
//    private func finishAssetWriting(assetWriter: AVAssetWriter?) {
//        guard let writer = assetWriter else {
//            print("AssetWriter is nil")
//            return
//        }
//
//        switch writer.status {
//        case .writing:
//            writer.finishWriting {
//                print("Finished writing to output file at:", writer.outputURL)
//            }
//        case .failed:
//            print("Asset writer failed with error: \(writer.error?.localizedDescription ?? "Unknown error")")
//        case .completed:
//            print("AssetWriter Status: Completed successfully")
//        case .cancelled:
//            print("AssetWriter Status: Cancelled")
//        case .unknown:
//            print("AssetWriter Status: Unknown")
//        @unknown default:
//            print("AssetWriter Status: Encountered unknown status")
//        }
//    }
//
//
//    func setStreamConfig() {
//        streamConfig = SCStreamConfiguration()
//
//        guard let streamConfig = streamConfig else {
//            fatalError("stream Config nill")
//        }
//
//        //Audio Capture
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
//
//    }
//
//}
//
//
