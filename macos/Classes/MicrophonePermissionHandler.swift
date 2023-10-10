import Cocoa

import Foundation
import AVFoundation
import CoreGraphics
import FlutterMacOS

public class MicrophonePermissionStreamHandler: NSObject, FlutterStreamHandler {
    
    private var eventSink: FlutterEventSink?

    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        self.startTimer(eventSink: eventSink)
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.stopTimer()
        eventSink = nil
        return nil
    }
    
    var isMicrophoneAccessGranted: Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private var timer: Timer?
 
    deinit {
        stopTimer()
    }
    
    func startTimer(eventSink: @escaping FlutterEventSink) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let status = AVCaptureDevice.authorizationStatus(for: .audio).rawValue
            print("Timer ", status)
            eventSink(status)
        }
    }

    func stopTimer() {
        timer?.invalidate()
    }

    func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            print("authorized")
            completion(true)
            
        case .notDetermined:
            print("notDetermined")
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    completion(granted)
                } else {
                    completion(granted)
                }
            }
            
        case .denied, .restricted:
            print("denied")
            SystemSettingsHandler.openSystemSetting(for: "microphone")
            completion(false)
            
        @unknown default:
            print("unknown")
            completion(false)
        }
    }
}


//MARK: - Microphone Permission Handler class
//final class MicrophonePermissionHandler {
//
//    var isMicrophoneAccessGranted: Bool {
//        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
//    }
//
//    private var timer: Timer?
//
//    // Singleton instance for shared access
//    static let shared: MicrophonePermissionHandler = .init()
//
//    private init() { } // Private initializer to prevent multiple instances
//
//    deinit {
//        stopTimer()
//    }
//
//    func startTimer(eventSink: @escaping FlutterEventSink) {
//        timer?.invalidate()
//        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
//            guard let self = self else { return }
//            let status = AVCaptureDevice.authorizationStatus(for: .audio).rawValue
//            print("Timer ", status)
//            eventSink(status)
//        }
//    }
//
//    func stopTimer() {
//        timer?.invalidate()
//    }
//
//    func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
//        switch AVCaptureDevice.authorizationStatus(for: .audio) {
//        case .authorized:
//            print("authorized")
//            completion(true)
//
//        case .notDetermined:
//            print("notDetermined")
//            AVCaptureDevice.requestAccess(for: .audio) { granted in
//                if granted {
//                    completion(granted)
//                } else {
//                    completion(granted)
//                }
//            }
//
//        case .denied, .restricted:
//            print("denied")
//            SystemSettingsHandler.openSystemSetting(for: "microphone")
//            completion(false)
//
//        @unknown default:
//            print("unknown")
//            completion(false)
//        }
//    }
//}

