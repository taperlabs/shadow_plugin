import Foundation
import ScreenCaptureKit
import FlutterMacOS

//MARK: SCBug Handler (Closure Bug)
final class ScreenCaptureKitBugHandler: NSObject, FlutterStreamHandler {
    private(set) var scAPICallCount: Int = 0
    private let scAPICallCounterThreshold: Int = 2
    private var windowCheckTimer: Timer?
    private(set) var isSCError: Bool = false
    private var eventSink: FlutterEventSink?
    
    deinit {
        self.resetAllVariables()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("SCBug Handler Event On 🟢")
        self.eventSink = events
        self.startWindowCheckTimer()
        ShadowLogger.shared.log("SC Bug Handler ON")
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("SCBug Handler Event Off 🔴")
        ShadowLogger.shared.log("SC Bug Handler Off")
        self.resetAllVariables()
        return nil
    }
    
    private func resetAllVariables() {
        self.scAPICallCount = 0
        self.eventSink = nil
        self.endWindowCheckTimer()
        self.isSCError = false
    }
    
    private func startWindowCheckTimer() {
        windowCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.fetchWindows()
        }
    }
    
    private func endWindowCheckTimer() {
        windowCheckTimer?.invalidate()
        windowCheckTimer = nil
    }
    
    private func checkAPIResponse() {
        if self.scAPICallCount > self.scAPICallCounterThreshold {
            print("API did not respond in time, taking corrective action...")
            self.isSCError = true
            eventSink?(["isSCError": self.isSCError])
            ShadowLogger.shared.log("ScreenCaptureKit Bug Detected :\(isSCError)")
        }
    }
    
    private func fetchWindows() -> Void {
        print("SC Bug Handler 1")
        self.scAPICallCount += 1
        DispatchQueue.global().async { [weak self] in
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
//                print("SC inside a closure")
                if let error = error {
                    self?.scAPICallCount = 0
                    print(error.localizedDescription)
                }
                guard let content = content else { return }
//                print("SC inside a closure 2")
                DispatchQueue.main.async {
                    self?.scAPICallCount = 0
                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkAPIResponse()
        }
    }
}
