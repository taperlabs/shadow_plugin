import Foundation
import AVFAudio
import AVFoundation

// MARK: - AssetWriter Class : Stream 데이터를 파일로 생성
class AssetWriterHelper {
    var assetWriter: AVAssetWriter?
    var systemAudioAssetWriter: AVAssetWriter?
    var systemAudioInput: AVAssetWriterInput?
    var videoInput: AVAssetWriterInput?
    var audioInput: AVAssetWriterInput?
    
    //Audio Configuration Setting
    private func setAudioConfiguration(format: AudioFormatOption ,
                                       channels: NumberOfChannels,
                                       sampleRate: SampleRateOption ) -> [String: Any] {
        return [
            AVFormatIDKey: format.formatID,
            AVSampleRateKey: sampleRate.sampleRate,
            AVNumberOfChannelsKey: channels.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }
    
    //System Audio만 셋업
    func setUpSystemAudioAssetWriter(withConfig config: [String: Any]? = nil) {
        let systemAudioFileName = "FlutterSystemAudio.m4a"
//        let systemAudioFileName = "FlutterSystemAudio.wav"
        let defaultFilePath = "ApplicationSupportDirectory"
        let format: AudioFormatOption
        let channels: NumberOfChannels
        let sampleRate: SampleRateOption
        let filename: String
        let filePath: String
        if let config = config {
            format = AudioFormatOption(rawValue: config["format"] as? String ?? "") ?? .mpeg4AAC
//            format = AudioFormatOption(rawValue: config["format"] as? String ?? "") ?? .pcm
            channels = NumberOfChannels(rawValue: config["channels"] as? String ?? "") ?? .mono
            sampleRate = SampleRateOption(rawValue: config["sampleRate"] as? String ?? "") ?? .rate16K
            filename = config["fileName"] as? String ?? systemAudioFileName
            filePath = config["filePath"] as? String ?? defaultFilePath
        } else {
            format = .mpeg4AAC
//            format = .pcm
            channels = .mono
            sampleRate = .rate16K
            filename = systemAudioFileName
            filePath = defaultFilePath
        }
        
        print("format", format)
        print("channels", channels)
        print("sampleRate", sampleRate)
        print("file Name", filename)
        
        ShadowLogger.shared.log("format - \(format), channels - \(channels), - sampleRate - \(sampleRate), filePath - \(filePath)")
        
        //System Audio Output URL 설정 + Nil Check
        guard let audioOutputURL = FileManagerHelper.getURL(for: filename, in: filePath) else {
            print("audioOutputURL을 가져오는데 실패하였습니다.")
            return
        }
        
        //이전에 저장한 시스템 오디오 파일이 존재하는지 체크 후 존재 시 삭제
        FileManagerHelper.deleteFileIfExists(at: audioOutputURL)
        
        do {
            //AssetWriter Setting
            systemAudioAssetWriter = try AVAssetWriter(outputURL: audioOutputURL, fileType: .wav)
            
            // AudioOuput Setting
            let audioOutputSettings = AudioSetting.setAudioConfiguration(format: format, channels: channels, sampleRate: sampleRate)
            
            //AssetWriterInput 셋업
            systemAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
            systemAudioInput?.expectsMediaDataInRealTime = true
            if let audioInput = systemAudioInput, systemAudioAssetWriter?.canAdd(audioInput) == true {
                systemAudioAssetWriter?.add(audioInput)
            }
            
            systemAudioAssetWriter?.startWriting()
            systemAudioAssetWriter?.startSession(atSourceTime: CMTime.zero)
            
        } catch  {
            print("AVAssetWriter initalizer 실패", error)
            ShadowLogger.shared.log("AVAsset Init failed \(error.localizedDescription)")
        }
    }
        
    //Screen + System Audio AssetWriter
    func setUpAssetWriter() {
        
        guard let outputURL = FileManagerHelper.getURL(for: "FlutterSCCapture.m4a", in: "ApplicationSupportDirectory") else {
            print("audioOutputURL을 가져오는데 실패하였습니다.")
            ShadowLogger.shared.log("failed to get audioOutputURL")
            return
        }
        
        //이전에 저장한 시스템 오디오 파일이 존재하는지 체크 후 존재 시 삭제
        FileManagerHelper.deleteFileIfExists(at: outputURL)
        
        do {
            assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
            
            // Video Ouput Setting
            let videoOutputSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: 1920,
                AVVideoHeightKey: 1080
            ]
            
            
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoOutputSettings)
            videoInput?.expectsMediaDataInRealTime = true
            if let videoInput = videoInput, assetWriter?.canAdd(videoInput) == true {
                assetWriter?.add(videoInput)
            }
            
            let audioOutputSettings = setAudioConfiguration(format: .mpeg4AAC, channels: .mono, sampleRate: .rate44_1K)

            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
            audioInput?.expectsMediaDataInRealTime = true
            if let audioInput = audioInput, assetWriter?.canAdd(audioInput) == true {
                assetWriter?.add(audioInput)
            }
            
            //            videoBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput!, sourcePixelBufferAttributes: nil)
            
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: CMTime.zero)
        } catch {
            print("Could not initialize AVAssetWriter: \(error)")
            
            ShadowLogger.shared.log("Failed to initialize AVAsset - \(error.localizedDescription)")
        }
    }
}

