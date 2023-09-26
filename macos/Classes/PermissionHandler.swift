import Foundation
import AVFoundation
import ScreenCaptureKit
import CoreGraphics

struct MicrophonePermissionHandler {
    
    static func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("authorized!!! The user has previously granted access to the microphone")
            completion(true)
            
        case .notDetermined:
            print(".notDetermined:  The user has not yet been asked for microphone access.")
            SystemSettingsHandler.openSystemSetting(for: "microphone")
//            AVCaptureDevice.requestAccess(for: .audio) { granted in
//                completion(granted)
//            }
            
        case .denied, .restricted:
            print(".denied or restrcited: The user has previously denied access or access is restricted.")
            SystemSettingsHandler.openSystemSetting(for: "microphone")
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
        } catch {
            SystemSettingsHandler.openSystemSetting(for: "screen")
            print("error", error.localizedDescription)
        }
    }
}


struct SystemSettingsHandler {
    
    static func openSystemSetting(for type: String) {
        guard type == "microphone" || type == "screen" else {
            return
        }
        
        let microphoneURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        let screenURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        let urlString = type == "microphone" ? microphoneURL : screenURL
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
    
    static func checkScreenRecordingPermission() {
        let hasAccess = CGPreflightScreenCaptureAccess()
        if hasAccess {
            print("App has screen recording permission", hasAccess)
        } else {
            print("App does not have screen recording permission", hasAccess)
        }
    }
}

