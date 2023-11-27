import Foundation
import ScreenCaptureKit
import FlutterMacOS

final class NudgeHelper: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var nudgeTimer: Timer?
    private var windows: [SCWindow]?
    private var apps: [SCRunningApplication]?
    private var displays: [SCDisplay]?
    var isZoomMeetingIn = false
    var isGoogleMeetIn = false
    var isInMeeting = false
    
    //Enum for Constant String values
    enum WindowTitles {
        case googleMeet
        case zoom
        case slack

        var detectionString: String {
            switch self {
            case .googleMeet: return "Meet -"
            case .zoom: return "Zoom Meeting"
            case .slack: return "Huddle"
            }
        }

        var appName: String {
            switch self {
            case .googleMeet: return "Google Meet"
            case .zoom: return "Zoom"
            case .slack: return "Slack"
            }
        }
    }
    

    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("Nudge OnListen 시작 🟢")
        self.eventSink = events
        nudgeTimer = Timer.scheduledTimer(timeInterval: 2.0, target: self, selector: #selector(fetchWindows), userInfo: nil, repeats: true)
        
        
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("Nudge onCancel Event 🔴")
        nudgeTimer?.invalidate()
        self.eventSink = nil
        
        return nil
    }
    
    @objc private func fetchWindows() -> Void {
        //Background Thread for executing the logic
        DispatchQueue.global().async { [weak self] in
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
                guard let content = content else { return }
                DispatchQueue.main.async {
                    self?.windows = content.windows
                    self?.apps = content.applications
                    self?.displays = content.displays
                    
                    self?.detectInMeeting()
                }
            }
        }
    }
    
    private func detectInMeeting() -> Void {
        guard let unWrappedWindows = self.windows else { return }
        DispatchQueue.global().async { [weak self] in
            var foundWindowID: Int?
            var foundAppName: String?

            for window in unWrappedWindows {
                 if let title = window.title {
                     if title.contains(WindowTitles.zoom.detectionString) {
                         foundWindowID = Int(window.windowID)
                         foundAppName = WindowTitles.zoom.appName
                         self?.isInMeeting = true
                         break
                     } else if title.contains(WindowTitles.googleMeet.detectionString) {
                         foundWindowID = Int(window.windowID)
                         foundAppName = WindowTitles.googleMeet.appName
                         self?.isInMeeting = true
                         break
                     } else if title.contains(WindowTitles.slack.detectionString) {
                         foundWindowID = Int(window.windowID)
                         foundAppName = WindowTitles.slack.appName
                         self?.isInMeeting = true
                         break
                     }
                 }
             }

            DispatchQueue.main.async {
                if let windowID = foundWindowID, let appName = foundAppName, let isInMeeting = self?.isInMeeting {
                    let nudgeEvent = NudgeEventModel(appName: appName, isInMeeting: isInMeeting, windowID: windowID)
                    self?.eventSink?(nudgeEvent.nudgeEventDictionary)
                }
            }
        }
    }
    
    
//    private func detectInMeeting() -> Void {
//        guard let unWrappedWindows = self.windows else { return }
//        DispatchQueue.global().async { [weak self] in
////            unWrappedWindows.forEach { print($0.title, $0.owningApplication?.applicationName, $0.windowID) }
//            let titles = unWrappedWindows.compactMap { $0.title }
////            titles.forEach { print($0) }
//
//            let isInZoomMeeting = titles.contains(WindowTitles.zoom.detectionString)
//            let isInGoogleMeet = titles.contains(WindowTitles.googleMeet.detectionString)
//            let isInSlackHuddle = titles.contains(WindowTitles.slack.detectionString)
//
//            DispatchQueue.main.async {
//                var nudgeEvent: NudgeEventModel?
//
//                if isInZoomMeeting {
//                    nudgeEvent = NudgeEventModel(appName: WindowTitles.zoom.appName, isInMeeting: isInZoomMeeting)
//                } else if isInGoogleMeet {
//                    nudgeEvent = NudgeEventModel(appName: WindowTitles.googleMeet.appName, isInMeeting: isInGoogleMeet)
//                } else if isInSlackHuddle {
//                    nudgeEvent = NudgeEventModel(appName: WindowTitles.slack.appName, isInMeeting: isInSlackHuddle)
//                }
//
//                if let event = nudgeEvent {
//                    self?.eventSink?(event.nudgeEventDictionary)
//                }
//            }
//        }
//    }
    
    
    private func detectZoomMeetingIn() -> Void {
        guard let unWrappedWindows = self.windows else { return }
        DispatchQueue.global().async { [weak self] in
            for window in unWrappedWindows {
                print(window)
            }
            
            let titles = unWrappedWindows.compactMap { $0.title }
            
            for title in titles {
                print(title)
            }
            
            let owningApps = unWrappedWindows.compactMap { $0.owningApplication }
            let isZoomRunning = titles.contains("Zoom Meeting")
            
            DispatchQueue.main.async {
                self?.isZoomMeetingIn = isZoomRunning
            }
        }
    }
    
    private func detectGoogleMeetingIn() -> Void {
        guard let unWrappedWindows = self.windows else { return }
        let titles = unWrappedWindows.compactMap { $0.title }
        
        for title in titles {
            print(title)
        }
        
        let owningApps = unWrappedWindows.compactMap { $0.owningApplication }
        let isZoomRunning = titles.contains("Meet -")
        self.isZoomMeetingIn = isZoomRunning
    }
    
    private func getCurrentlyActiveApp() -> Void {
        let runningApplication = NSRunningApplication.current
        print(runningApplication)
    }
}

extension NudgeHelper {
    //TODO:
}

extension NudgeHelper {
    //TODO:
}
