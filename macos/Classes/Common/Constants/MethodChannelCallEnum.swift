import Foundation

//MARK: - MethodChannel Call 상수
enum MethodChannelCall: String {
    //System Audio Only
    case startSystemAudioRecordingWithConfig = "startSystemAudioRecordingWithConfig"
    case startSystemAudioRecordingWithDefault = "startSystemAudioRecordingWithDefault"
    
    //Microphone Audio Only
    case startMicRecordingWithConfig = "startMicRecordingWithConfig"
    case startMicRecordingWithDefault = "startMicRecordingWithDefault"
    
    //Combined System and Mic Audio Recording
    case startSystemAndMicAudioRecordingWithConfig = "startSystemAndMicAudioRecordingWithConfig"
    case startSystemAndMicAudioRecordingWithDefault = "startSystemAndMicAudioRecordingWithDefault"
    case stopSystemAndMicAudioRecording = "stopSystemAndMicAudioRecording"
    
    
    case requestMicPermission = "requestMicPermission"
    case requestScreenPermission = "requestScreenPermission"
    
    
    case getAudioInputDeviceList = "getAudioInputDeviceList"
    case setAudioInputDevice = "setAudioInputDevice"
    case deleteFileIfExists = "deleteFileIfExists"
    
    //System Settings
    case openMicSystemSetting = "openMicSystemSetting"
    case openScreenSystemSetting = "openScreenSystemSetting"
    
    case isMicPermissionGranted = "isMicPermissionGranted"
    case isScreenPermissionGranted = "isScreenPermissionGranted"
    
    case restartApp = "restartApp"
    
    case getAllScreenPermissionStatuses = "getAllScreenPermissionStatuses"
    
    //Before
    case startScreenCapture = "startScreenCapture"
    case stopScreenCapture = "stopScreenCapture"
    case startMicRecording = "startMicRecording"
    case stopMicRecording = "stopMicRecording"
    case startFileIO = "startFileIO"
}

