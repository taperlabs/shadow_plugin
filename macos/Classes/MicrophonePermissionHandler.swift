import Cocoa

import Foundation
import AVFoundation
import CoreGraphics
import FlutterMacOS

//MARK: - Microphone Permission Handler class
public final class MicrophonePermissionStreamHandler: NSObject, FlutterStreamHandler {
    
    private var eventSink: FlutterEventSink?
    private var timer: Timer?

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

    var isMicrophonePermissionGranted: Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
 
    deinit {
        stopTimer()
    }
    
    private func startTimer(eventSink: @escaping FlutterEventSink) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let status = AVCaptureDevice.authorizationStatus(for: .audio).rawValue
            let statusString = self.stringRepresentation(of: status)
            print("Timer ofss ", statusString)
            eventSink(statusString)
        }
    }
    
    private func stringRepresentation(of status: Int) -> String {
        if let status = AVAuthorizationStatus(rawValue: status) {
            switch status {
            case .notDetermined:
                return "notDetermined"
            case .restricted:
                return "restricted"
            case .denied:
                return "denied"
            case .authorized:
                return "authorized"
            @unknown default:
                return "unknown"
            }
        } else {
            return "invalid"
        }
    }

    private func stopTimer() {
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

