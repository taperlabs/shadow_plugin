//import Foundation
//import AVFAudio
//import AVFoundation
//
//// MARK: - AssetWriter Class : Stream 데이터를 파일로 생성
//class AssetWriterHelper {
//    var assetWriter: AVAssetWriter?
//    var systemAudioAssetWriter: AVAssetWriter?
//    var systemAudioInput: AVAssetWriterInput?
//    var videoInput: AVAssetWriterInput?
//    var audioInput: AVAssetWriterInput?
//
//    //    private var audioSetting: [String: Any]?
//
//    //    private func setUpAudioConfiguration() {
//    //        audioSetting = [
//    //            AVFormatIDKey: kAudioFormatMPEG4AAC,
//    //            AVNumberOfChannelsKey: 1,
//    //            AVSampleRateKey: 16000.0,
//    //            AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
//    //        ]
//    //    }
//
//    //Audio Configuration Setting
//    private func setAudioConfiguration(format: AudioFormatOption ,
//                                       channels: NumberOfChannels,
//                                       sampleRate: SampleRateOption ) -> [String: Any] {
//        return [
//            AVFormatIDKey: format.formatID,
//            AVSampleRateKey: sampleRate.sampleRate,
//            AVNumberOfChannelsKey: channels.channelCount,
//            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
//        ]
//    }
//
//    //System Audio만 셋업
//    func setUpSystemAudioAssetWriter(withConfig config: [String: Any]? = nil) {
//        let systemAudioFileName = "FlutterSystemAudio.m4a"
//        let format: AudioFormatOption
//        let channels: NumberOfChannels
//        let sampleRate: SampleRateOption
//        let filename: String
//
//        if let config = config {
//            format = AudioFormatOption(rawValue: config["format"] as? String ?? "") ?? .mpeg4AAC
//            channels = NumberOfChannels(rawValue: config["channels"] as? String ?? "") ?? .mono
//            sampleRate = SampleRateOption(rawValue: config["sampleRate"] as? String ?? "") ?? .rate16K
//            filename = config["fileName"] as? String ?? systemAudioFileName
//        } else {
//            format = .mpeg4AAC
//            channels = .mono
//            sampleRate = .rate16K
//            filename = systemAudioFileName
//        }
//
//        print("format", format)
//        print("channels", channels)
//        print("sampleRate", sampleRate)
//        print("file Name", filename)
//
//        //System Audio Output URL 설정 + Nil Check
//        guard let audioOutputURL = FileManagerHelper.getURL(for: filename) else {
//            print("audioOutputURL을 가져오는데 실패하였습니다.")
//            return
//        }
//
//        //이전에 저장한 시스템 오디오 파일이 존재하는지 체크 후 존재 시 삭제
//        FileManagerHelper.deleteFileIfExists(at: audioOutputURL)
//
//        do {
//            //AssetWriter Setting
//            systemAudioAssetWriter = try AVAssetWriter(outputURL: audioOutputURL, fileType: .m4a)
//
//            // AudioOuput Setting
//            let audioOutputSettings = AudioSetting.setAudioConfiguration(format: format, channels: channels, sampleRate: sampleRate)
////            let audioOutputSettings = setAudioConfiguration(format: format, channels: channels, sampleRate: sampleRate)
//
//            //            let audioOutputSettings: [String: Any] = [
//            //                AVFormatIDKey: kAudioFormatMPEG4AAC,
//            //                AVNumberOfChannelsKey: 1,
//            //                AVSampleRateKey: 16000.0,
//            //                AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
//            //            ]
//
//            //AssetWriterInput 셋업
//            systemAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
//            systemAudioInput?.expectsMediaDataInRealTime = true
//            if let audioInput = systemAudioInput, systemAudioAssetWriter?.canAdd(audioInput) == true {
//                systemAudioAssetWriter?.add(audioInput)
//            }
//
//            systemAudioAssetWriter?.startWriting()
//            systemAudioAssetWriter?.startSession(atSourceTime: CMTime.zero)
//
//        } catch  {
//            print("AVAssetWriter initalizer 실패", error)
//        }
//    }
//
////    func setUpSystemAudioAssetWriter() {
////        let systemAudioFileName = "FlutterSystemAudio.m4a"
////
////        //System Audio Output URL 설정 + Nil Check
////        guard let audioOutputURL = FileManagerHelper.getURL(for: systemAudioFileName) else {
////            print("audioOutputURL을 가져오는데 실패하였습니다.")
////            return
////        }
////
////        //이전에 저장한 시스템 오디오 파일이 존재하는지 체크 후 존재 시 삭제
////        FileManagerHelper.deleteFileIfExists(at: audioOutputURL)
////
////        do {
////            //AssetWriter Setting
////            systemAudioAssetWriter = try AVAssetWriter(outputURL: audioOutputURL, fileType: .m4a)
////
////            // AudioOuput Setting
////            let audioOutputSettings = setAudioConfiguration(format: .mpeg4AAC, channels: .stereo, sampleRate: .rate48K)
////
////            //            let audioOutputSettings: [String: Any] = [
////            //                AVFormatIDKey: kAudioFormatMPEG4AAC,
////            //                AVNumberOfChannelsKey: 1,
////            //                AVSampleRateKey: 16000.0,
////            //                AVEncoderAudioQualityKey: AVAudioQuality.min.rawValue
////            //            ]
////
////            //AssetWriterInput 셋업
////            systemAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
////            systemAudioInput?.expectsMediaDataInRealTime = true
////            if let audioInput = systemAudioInput, systemAudioAssetWriter?.canAdd(audioInput) == true {
////                systemAudioAssetWriter?.add(audioInput)
////            }
////
////            systemAudioAssetWriter?.startWriting()
////            systemAudioAssetWriter?.startSession(atSourceTime: CMTime.zero)
////
////        } catch  {
////            print("AVAssetWriter initalizer 실패", error)
////        }
////    }
//
//    //Screen + System Audio AssetWriter
//    func setUpAssetWriter() {
//
//        guard let outputURL = FileManagerHelper.getURL(for: "FlutterSCCapture.m4a") else {
//            print("audioOutputURL을 가져오는데 실패하였습니다.")
//            return
//        }
//
//        //이전에 저장한 시스템 오디오 파일이 존재하는지 체크 후 존재 시 삭제
//        FileManagerHelper.deleteFileIfExists(at: outputURL)
//
//        do {
//            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
//
//            // Video Ouput Setting
//            let videoOutputSettings: [String: Any] = [
//                AVVideoCodecKey: AVVideoCodecType.h264,
//                AVVideoWidthKey: 1920,
//                AVVideoHeightKey: 1080
//            ]
//
//
//            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoOutputSettings)
//            videoInput?.expectsMediaDataInRealTime = true
//            if let videoInput = videoInput, assetWriter?.canAdd(videoInput) == true {
//                assetWriter?.add(videoInput)
//            }
//
//            let audioOutputSettings = setAudioConfiguration(format: .mpeg4AAC, channels: .mono, sampleRate: .rate44_1K)
//
//            // Create and configure the audio input
//            //            let audioOutputSettings: [String: Any] = [
//            //                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
//            //                AVNumberOfChannelsKey: 2,
//            //                AVSampleRateKey: 44100.0,
//            //                AVEncoderBitRateKey: 192000
//            //            ]
//            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
//            audioInput?.expectsMediaDataInRealTime = true
//            if let audioInput = audioInput, assetWriter?.canAdd(audioInput) == true {
//                assetWriter?.add(audioInput)
//            }
//
//            //            videoBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: nil)
//
//            assetWriter?.startWriting()
//            assetWriter?.startSession(atSourceTime: CMTime.zero)
//        } catch {
//            print("Could not initialize AVAssetWriter: \(error)")
//        }
//    }
//}
//
//
