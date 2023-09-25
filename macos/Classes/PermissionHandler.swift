import Foundation
import AVFoundation
import ScreenCaptureKit

struct MicrophonePermissionHandler {
    
    static func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("authorized!!!")
            // The user has previously granted access to the microphone
            completion(true)
            
        case .notDetermined:
            // The user has not yet been asked for microphone access.
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                completion(granted)
            }
            
        case .denied, .restricted:
            // The user has previously denied access or access is restricted.
            completion(false)
            
        @unknown default:
            // Handle unknown case
            completion(false)
        }
    }
    
    static func requestMicPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            print("granted", granted)
        }
    }
    
    static func isMicrophoneAccessGranted() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
}

struct ScreenRecorderPermissionHandler {
    
    static func requestScreenRecorderPermission() async throws {
        do {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch let error {
            print("error", error.localizedDescription)
        }
    }
}

