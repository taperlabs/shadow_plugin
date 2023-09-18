import Foundation
import AVFAudio

//MARK: - Audio Codec Value
enum AudioFormatOption: String {
    case mpeg4AAC = "mpeg4AAC"
    case pcm = "pcm"
    
    var formatID: AudioFormatID {
        switch self {
        case .mpeg4AAC:
            return kAudioFormatMPEG4AAC
        case .pcm:
            return kAudioFormatLinearPCM
        }
    }
}
//enum AudioFormatOption {
//    case mpeg4AAC // .m4a
//    case pcm      // .caf (Apple Only)
//
//    var formatID: AudioFormatID {
//        switch self {
//        case .mpeg4AAC:
//            return kAudioFormatMPEG4AAC
//        case .pcm:
//            return kAudioFormatLinearPCM
//        }
//    }
//}

//MARK: - Channel Value
enum NumberOfChannels: String {
    case mono = "mono"
    case stereo = "stereo"
    
    var channelCount: Int {
        switch self {
        case .mono:
            return 1
        case .stereo:
            return 2
        }
    }
}
//enum NumberOfChannels: Int {
//    case mono = 1
//    case stereo = 2
//
//}

//MARK: - Sample rate value
enum SampleRateOption: String {
    case rate12K = "rate12K"
    case rate16K = "rate16K"
    case rate32K = "rate32K"
    case rate44_1K = "rate44_1K"
    case rate48K = "rate48K"
    
    var sampleRate: Double {
        switch self {
        case .rate12K:
            return 12000.0
        case .rate16K:
            return 16000.0
        case .rate32K:
            return 32000.0
        case .rate44_1K:
            return 44100.0
        case .rate48K:
            return 48000.0
        }
    }
}
//enum SampleRateOption: Double {
//    case rate12K = 12000.0 //12 kHz
//    case rate16K = 16000.0 //16 kHz
//    case rate32K = 32000.0 //32 kHz
//    case rate44_1K = 44100.0 //44.1 kHz
//    case rate48K = 48000.0 // 48 kHz
//}


