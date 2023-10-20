import Cocoa
import Foundation
import AVFoundation
import CoreGraphics
import FlutterMacOS

//MARK: - Screen Recording permission handler class
public final class ScreenRecordingPermissionHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var timer: Timer?
    
    var isScreenRecordingGranted: Bool {
        return Self.canRecordScreen()
    }
    
    deinit {
        stopTimer()
    }
    
    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        print("OnListen for ScreenRecording이 불렸습니다!!!")
        self.eventSink = eventSink
        self.startTimer(eventSink: eventSink)
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.stopTimer()
        eventSink = nil
        return nil
    }
    
    private func startTimer(eventSink: @escaping FlutterEventSink) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let status = Self.canRecordScreen()
            eventSink(status)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
    }
    
    //    func requestScreenRecordingPermission() {
    //        CGRequestScreenCaptureAccess()
    //    }
    
    func requestScreenRecordingPermission() {
        
        // Request screen recording permission
        CGRequestScreenCaptureAccess()
        
        // Check the permission status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let hasAccess = CGPreflightScreenCaptureAccess()
            let hasAccessViaCGWIndow = Self.canRecordScreen()
            if !hasAccess || !hasAccessViaCGWIndow {
                // Open system settings if permission is not granted
                SystemSettingsHandler.openSystemSetting(for: "screen")
            }
        }
    }
    
    private static func canRecordScreen() -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: AnyObject]] else {
            print("Failed to fetch window information")
            return false
        }
        
        print("Total windows fetcheds: \(windows.count)")
        
        for (index, window) in windows.enumerated() {
            print("Details of window \(index + 1): \(window)")
            if let windowName = window[kCGWindowName as String] as? String {
                print("Window name: \(windowName)")
            } else {
                print("This window doesn't have a name or the name is inaccessible.")
            }
        }
        
        return windows.allSatisfy({ window in
            window[kCGWindowName as String] as? String != nil
        })
    }
}


//public class ScreenRecordingStreamHandler: NSObject, FlutterStreamHandler {
//
//    private var eventSink: FlutterEventSink?
//    private let screenRecordingService = ScreenRecordingPermissionHandler.shared
//
//    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
//        print("OnListen for ScreenRecording이 불렸습니다!!!")
//        self.eventSink = eventSink
//        screenRecordingService.startTimer(eventSink: eventSink)
//        return nil
//    }
//
//    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
//        screenRecordingService.stopTimer()
//        eventSink = nil
//        return nil
//    }
//}


