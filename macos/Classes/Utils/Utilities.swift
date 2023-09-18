import Foundation
import FlutterMacOS
import AVFAudio

//MARK: - Arguments parsing Helper Type method
struct ArgumentParser {
    static func parse(from call: FlutterMethodCall) -> [String: Any]? {
        return call.arguments as? [String: Any]
    }
}

//MARK: - Audio Setting Helper Type Method
struct AudioSetting {
    static func setAudioConfiguration(format: AudioFormatOption,
                                      channels: NumberOfChannels,
                                      sampleRate: SampleRateOption) -> [String: Any] {
        return [
            AVFormatIDKey: format.formatID,
            AVSampleRateKey: sampleRate.sampleRate,
            AVNumberOfChannelsKey: channels.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }
}


//TODO: Video Setting Helper Type Method
