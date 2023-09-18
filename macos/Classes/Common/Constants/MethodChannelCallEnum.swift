import Foundation

//MARK: - MethodChannel Call 상수
enum MethodChannelCall: String {
    //SystemAudio Only
    case startSystemAudioRecordingWithConfig = "startSystemAudioRecordingWithConfig"
    case startSystemAudioRecordingWithDefault = "startSystemAudioRecordingWithDefault"
    
    //Microphone Audio Only
    case startMicRecordingWithConfig = "startMicRecordingWithConfig"
    case startMicRecordingWithDefault = "startMicRecordingWithDefault"
    
    //Combined System and Mic Recording
    case startSystemAndMicAudioRecordingWithConfig = "startSystemAndMicAudioRecordingWithConfig"
    case startSystemAndMicAudioRecordingWithDefault = "startSystemAndMicAudioRecordingWithDefault"
    case stopSystemAndMicAudioRecording = "stopSystemAndMicAudioRecording"
    
    //Before
    case startScreenCapture = "startScreenCapture"
    case stopScreenCapture = "stopScreenCapture"
    case startMicRecording = "startMicRecording"
    case stopMicRecording = "stopMicRecording"
    case startFileIO = "startFileIO"
}

