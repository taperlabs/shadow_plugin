import Foundation
import AVFoundation
import ScreenCaptureKit
import CoreGraphics

//MARK: - Microphone Permission Handler
struct MicrophonePermissionHandler {
    
    static func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("authorized!!! The user has previously granted access to the microphone")
            completion(true)
            
        case .notDetermined:
            print(".notDetermined:  The user has not yet been asked for microphone access.")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    print("permission granted")
                    completion(granted)
                } else {
                    SystemSettingsHandler.openSystemSetting(for: "microphone")
                    completion(granted)
                }
            }
            
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
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("Authorized")
        case .denied:
            print("Denied")
        case .notDetermined:
            print("notDetermined!!!")
        case .restricted:
            print("Restricted")
        @unknown default:
            print("default 임")
        }
        
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
}

//MARK: - Screen Recording Permission Handler
struct ScreenRecorderPermissionHandler {
    
    //Request screen recording permission
    static func requestScreenRecorderPermission() {
        CGRequestScreenCaptureAccess()
    }
    
    //Check the permission status of screen recording
    static func checkScreenRecordingPermission() -> Bool {
        return CGPreflightScreenCaptureAccess()
    }
    
    static func requestScreenRecordingPermission() {
         // Request screen recording permission
         CGRequestScreenCaptureAccess()
         
         // Check the permission status after a delay
         DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
             let hasAccess = CGPreflightScreenCaptureAccess()
             if !hasAccess {
                 // Open system settings if permission is not granted
                 SystemSettingsHandler.openSystemSetting(for: "screen")
             }
         }
     }
    
    static func requestScreenRecorderPermission() async throws {
        do {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        } catch {
            SystemSettingsHandler.openSystemSetting(for: "screen")
            print("error", error.localizedDescription)
        }
    }
}

//MARK: - System Settings Open Type Method
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
    
    static func checkScreenRecordingPermission() -> Bool {
        let hasAccess = CGPreflightScreenCaptureAccess()
        return hasAccess
    }
    
//    static func checkScreenRecordingPermission() {
//        let hasAccess = CGPreflightScreenCaptureAccess()
//        if hasAccess {
//            print("App has screen recording permission", hasAccess)
//        } else {
//            print("App does not have screen recording permission", hasAccess)
//            openSystemSetting(for: "screen")
//        }
//    }
}

