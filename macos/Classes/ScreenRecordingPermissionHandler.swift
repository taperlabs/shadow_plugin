import Cocoa
import Foundation
import AVFoundation
import CoreGraphics
import FlutterMacOS
import ScreenCaptureKit

//MARK: - Screen Recording permission handler class
public final class ScreenRecordingPermissionHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var timer: Timer?
    private var scAPICallCount: Int = 0
    private let scAPICallCounterThreshold = 2
    private var isSCError: Bool = false
    
    var isScreenRecordingGranted: Bool {
        return Self.canRecordScreen()
    }
    
    deinit {
        stopTimer()
    }
    
    private func checkAPIResponse() {
        if self.scAPICallCount > self.scAPICallCounterThreshold {
            print("API did not respond in time, taking corrective action...")
            self.isSCError = true
        }
    }
    
    private func fetchWindows() -> Void {
        print("Fetch Window for ScreenRecording Permission")
        self.scAPICallCount += 1
        DispatchQueue.global().async { [weak self] in
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
                print("Fetch Window for ScreenRecording Permission inside a closure")
                if let error = error {
                    self?.scAPICallCount = 0
                    print(error.localizedDescription)
                }
                guard let content = content else { return }
                print("Fetch Window for ScreenRecording Permission inside a closure 2")
                DispatchQueue.main.async {
                    self?.scAPICallCount = 0
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAPIResponse()
        }
    }
    
    public func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink) -> FlutterError? {
        print("OnListen for ScreenRecording permission called")
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
            self.fetchWindows()
            let canRecordstatus = Self.canRecordScreen()
            eventSink(["canRecord": canRecordstatus, "isSCError": self.isSCError])
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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
        let runningApplication = NSRunningApplication.current
        let processIdentifier = runningApplication.processIdentifier

        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
            as? [[String: AnyObject]] else
        {
            assertionFailure("Invalid window info")
            return false
        }

        for window in windows {
            // Get information for each window
            guard let windowProcessIdentifier = (window[String(kCGWindowOwnerPID)] as? Int).flatMap(pid_t.init) else {
                assertionFailure("Invalid window info")
                continue
            }

            // Don't check windows owned by this process
            if windowProcessIdentifier == processIdentifier {
                continue
            }

            // Get process information for each window
            guard let windowRunningApplication = NSRunningApplication(processIdentifier: windowProcessIdentifier) else {
                // Ignore processes we don't have access to, such as WindowServer, which manages the windows named
                // "Menubar" and "Backstop Menubar"
                continue
            }

            if window[String(kCGWindowName)] as? String != nil {
                if windowRunningApplication.executableURL?.lastPathComponent == "Dock" {
                    // Ignore the Dock, which provides the desktop picture
                    continue
                } else {
                    return true
                }
            }
        }

        return false
    }
    
    



    
//    private static func canRecordScreen() -> Bool {
//        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: AnyObject]] else {
//            print("Failed to fetch window information")
//            return false
//        }
//        
////        print("Total windows fetched: \(windows.count)")
//        
//        for (index, window) in windows.enumerated() {
////            print("Details of window \(index + 1): \(window)")
//            if let windowName = window[kCGWindowName as String] as? String {
//                print("Window name: \(windowName)")
//                return true
//            } else {
//                print("This window doesn't have a name or the name is inaccessible.")
//            }
//        }
//        
//        return false
//    }
    
//    private static func canRecordScreen() -> Bool {
//        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: AnyObject]] else {
//            print("Failed to fetch window information")
//            return false
//        }
//        
////        print("Total windows fetcheds: \(windows.count)")
//        let hasAccess = CGPreflightScreenCaptureAccess()
//        
//        print("CGPreflihgtCheck \(hasAccess)")
//        
//        for (index, window) in windows.enumerated() {
////            print("Details of window \(index + 1): \(window)")
//            if let windowOwnerName = window[kCGWindowOwnerName as String] as? String {
////                print("window Owner name: \(windowOwnerName)")
//            }
////            
////            if let windowName = window[kCGWindowName as String] as? String {
////                print("Window name: \(windowName)")
////            } else {
////                print("This window, \(window) doesn't have a name or the name is inaccessible.")
////            }
//        }
//        
//        return windows.allSatisfy({ window in
//            window[kCGWindowName as String] as? String != nil
//        })
//    }
    
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


