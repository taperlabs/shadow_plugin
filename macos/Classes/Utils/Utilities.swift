import Foundation
import FlutterMacOS
import AVFAudio
import AppKit

//MARK: - Arguments parsing helper type method
struct ArgumentParser {
    static func parse(from call: FlutterMethodCall) -> [String: Any]? {
        return call.arguments as? [String: Any]
    }
}

//MARK: - Audio Setting helper type method
struct AudioSetting {
    static func setAudioConfiguration(format: AudioFormatOption,
                                      channels: NumberOfChannels,
                                      sampleRate: SampleRateOption) -> [String: Any] {
        var settings: [String: Any] = [
            AVFormatIDKey: format.formatID,
            AVSampleRateKey: sampleRate.sampleRate,
            AVNumberOfChannelsKey: channels.channelCount
        ]
        
        if format == .pcm {
            settings[AVLinearPCMIsBigEndianKey] = false
            settings[AVLinearPCMIsFloatKey] = false
            settings[AVLinearPCMBitDepthKey] = 16
            settings[AVLinearPCMIsNonInterleaved] = false
        } else {
            settings[AVEncoderAudioQualityKey] = AVAudioQuality.high.rawValue
        }
        
        return settings
    }
}


//struct AudioSetting {
//    static func setAudioConfiguration(format: AudioFormatOption,
//                                      channels: NumberOfChannels,
//                                      sampleRate: SampleRateOption) -> [String: Any] {
//        return [
//            AVFormatIDKey: format.formatID,
//            AVSampleRateKey: sampleRate.sampleRate,
//            AVNumberOfChannelsKey: channels.channelCount,
//            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
//        ]
//    }
//}

struct RestartApplication {
    static func relaunch(afterDelay seconds: TimeInterval = 0.5) -> Never {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", "sleep \(seconds); open \"\(Bundle.main.bundlePath)\""]
        task.launch()
        
        NSApp.terminate(self)
        exit(0)
    }
}


//TODO: Video Setting Helper Type Method
