import Foundation

//MARK: - Custom Error Handler
enum CaptureError: Error {
    case missingParameters
    case streamOutputNotInitialized
    case missingScreenRecordingPermission
    case microphonePermissionNotGranted
}



//TODO: - handle various errors for AVAudioRecorder

//TODO: - handle various errors for AVAssetWriter

//TODO: - handle various errors for Timer
