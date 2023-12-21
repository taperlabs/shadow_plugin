//import Foundation
//import ScreenCaptureKit
//import FlutterMacOS
//import RegexBuilder
//import CoreAudio
//
//extension Notification.Name {
//    static let windowDetected = Notification.Name("NudgeServiceWithScreenCaptureKit")
//    static let microphoneUsageDetected = Notification.Name("NudgeServiceWithCoreAudio")
//}
//
//class NudgeServiceWithScreenCaptureKit {
//    private var windows: [SCWindow]?
//    private var apps: [SCRunningApplication]?
//    private var displays: [SCDisplay]?
//    
//    private var lastFoundWindowID: Int?
//    private var lastFoundAppName: String?
//    private var lastGoogleMeetID: String?
//    private var isInMeeting = false
//    
//    private var foundWindowID: Int?
//    private var foundAppName: String?
//    private var googleMeetID: String?
//    
//    init() {
//        print("NudgeServiceWithScreenCaptureKit called!!")
//        
//        
//        NotificationCenter.default.post(name: .windowDetected, object: self, userInfo: ["data": "Hi!!"])
//    }
//    
//    deinit {
//        
//    }
//    
//    //Enum for Constant String values
//    enum WindowTitles {
//        case googleMeet
//        case zoom
//        case slack
//        
//        var detectionString: String {
//            switch self {
//            case .googleMeet: return "Meet -"
//            case .zoom: return "Zoom Meeting"
//            case .slack: return "Huddle"
//            }
//        }
//        
//        var appName: String {
//            switch self {
//            case .googleMeet: return "Google Meet"
//            case .zoom: return "Zoom"
//            case .slack: return "Slack"
//            }
//        }
//    }
//    
//    private func resetMeetingProperties() -> Void {
//        self.isInMeeting = false
//        self.lastFoundAppName = nil
//        self.lastGoogleMeetID = nil
//        self.lastFoundAppName = nil
//    }
//    
//    @objc private func fetchWindows() -> Void {
//        //Background Thread for executing the logic
//        DispatchQueue.global().async { [weak self] in
//            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
//                guard let content = content else { return }
//                DispatchQueue.main.async {
//                    self?.windows = content.windows
//                    self?.apps = content.applications
//                    self?.displays = content.displays
//                    
//                    self?.detectInMeeting()
//                }
//            }
//        }
//    }
//    
//    private func processWindow(_ window: SCWindow) -> Void {
//        guard let title = window.title else { return }
//        
//        if title.contains(WindowTitles.zoom.detectionString) {
//            updateMeetingDetails(window, with: .zoom)
//        } else if title.contains(WindowTitles.googleMeet.detectionString) {
//            updateMeetingDetails(window, with: .googleMeet)
//        } else if title.contains(WindowTitles.slack.detectionString) {
//            updateMeetingDetails(window, with: .slack)
//        }
//    }
//    
//    private func updateMeetingDetails(_ window: SCWindow, with titleType: WindowTitles) {
//        
//        if titleType == .googleMeet, let title = window.title {
//            self.googleMeetID = extractGoogleMeetID(from: title)
//        }
//        
//        self.foundAppName = titleType.appName
//        self.foundWindowID = Int(window.windowID)
//        self.isInMeeting = true
//        
//        
//    }
//    
//    
//    private func detectInMeeting() -> Void {
//        guard let unWrappedWindows = self.windows else { return }
//        DispatchQueue.global().async { [weak self] in
//            var foundWindowID: Int?
//            var foundAppName: String?
//            var googleMeetID: String?
//            
//            for window in unWrappedWindows {
//                if let title = window.title {
//                    if title.contains(WindowTitles.zoom.detectionString) {
//                        foundWindowID = Int(window.windowID)
//                        foundAppName = WindowTitles.zoom.appName
//                        self?.isInMeeting = true
//                        break
//                    } else if title.contains(WindowTitles.googleMeet.detectionString) {
//                        foundWindowID = Int(window.windowID)
//                        foundAppName = WindowTitles.googleMeet.appName
//                        googleMeetID = self?.extractGoogleMeetID(from: title)
//                        self?.isInMeeting = true
//                        break
//                    } else if title.contains(WindowTitles.slack.detectionString) {
//                        foundWindowID = Int(window.windowID)
//                        foundAppName = WindowTitles.slack.appName
//                        self?.isInMeeting = true
//                        break
//                    }
//                }
//            }
//            
//            DispatchQueue.main.async {
//                if let windowID = foundWindowID, let appName = foundAppName, let isInMeeting = self?.isInMeeting, let googleMeetID = googleMeetID {
//                    if googleMeetID != self?.lastGoogleMeetID {
//                        let nudgeEvent = NudgeEventModel(appName: appName, isInMeeting: isInMeeting, windowID: windowID, googleMeetID: googleMeetID)
////                        self?.eventSink?(nudgeEvent.nudgeEventDictionary)
//                        
//                        self?.lastFoundWindowID = windowID
//                        self?.lastFoundAppName = appName
//                        self?.lastGoogleMeetID = googleMeetID
//                    }
//                }
//                
//                if let windowID = foundWindowID, let appName = foundAppName, let isInMeeting = self?.isInMeeting {
//                    // Check if the found meeting is different from the last one
//                    if windowID != self?.lastFoundWindowID || appName != self?.lastFoundAppName {
//                        let nudgeEvent = NudgeEventModel(appName: appName, isInMeeting: isInMeeting, windowID: windowID)
////                        self?.eventSink?(nudgeEvent.nudgeEventDictionary)
//                        
//                        // Update the last found meeting details
//                        self?.lastFoundWindowID = windowID
//                        self?.lastFoundAppName = appName
//                    }
//                }
//            }
//        }
//    }
//    
//    private func extractGoogleMeetID(from title: String) -> String? {
//        guard let meetingIDPattern = try? Regex("[a-zA-Z]{3}-[a-zA-Z]{4}-[a-zA-Z]{3}") else { return nil }
//        guard let match = title.firstMatch(of: meetingIDPattern) else { return nil }
//        return String(title[match.range])
//    }
//}
//
//class NudgeServiceWithCoreAudio {
//    var isMicrophoneInUse = false
//    var microphoneListenerBlock: AudioObjectPropertyListenerBlock?
//    
//    func getDefaultInputDevice() -> AudioDeviceID {
//        var defaultInputDeviceID = kAudioObjectUnknown
//        var propertyAddress = AudioObjectPropertyAddress(
//            mSelector: kAudioHardwarePropertyDefaultInputDevice,
//            mScope: kAudioObjectPropertyScopeGlobal,
//            mElement: kAudioObjectPropertyElementMain)
//        
//        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
//        
//        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
//                                                &propertyAddress,
//                                                0,
//                                                nil,
//                                                &propertySize,
//                                                &defaultInputDeviceID)
//        
//        print("Get Input Device Status :", status)
//        
//        if status != kAudioHardwareNoError {
//            print("Error getting default input device: \(status)")
//            return kAudioObjectUnknown
//        }
//        
//        return defaultInputDeviceID
//    }
//    
//   @objc func detectMicInUsage() -> Void {
//        var deviceID = self.getDefaultInputDevice()
//        
//        var propertyAddress = AudioObjectPropertyAddress(
//            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
//            mScope: kAudioObjectPropertyScopeGlobal,
//            mElement: kAudioObjectPropertyElementMain
//        )
//        
//        
//        let microphoneID: AudioObjectID = deviceID // Obtain the ID of the microphone device
//        
//        // Remove existing listener if it exists
//        if let existingBlock = microphoneListenerBlock {
//            AudioObjectRemovePropertyListenerBlock(microphoneID, &propertyAddress, nil, existingBlock)
//        }
//        
//        microphoneListenerBlock = { [weak self] (numberAddresses, addresses) in
//            // Implement the logic to handle the property change
//            // For example, query the property and react to its new value
//            guard let self = self else { return }
//            print("Number of Properties Changed: \(numberAddresses)")
//            self.isMicrophoneInUse.toggle()
//            
//            if self.isMicrophoneInUse {
//                let data = ["isMicInUse": true]
//                print("Microphone is now in use")
//
//            } else {
//                print("Microphone is no longer in use")
//
//            }
//        }
//        
//        if let listenerBlock = microphoneListenerBlock {
//            let status = AudioObjectAddPropertyListenerBlock(microphoneID,
//                                                             &propertyAddress,
//                                                             nil,
//                                                             listenerBlock)
//            
//            if status != noErr {
//                print("Error adding property listener: \(status)")
//            }
//            
//        }
//    }
//}
//
//
//final class NudgeService: NSObject, FlutterStreamHandler {
//    private var eventSink: FlutterEventSink?
//    private var nudgeTimer: Timer?
//    private var nudgeServiceWithCoreAudio: NudgeServiceWithCoreAudio?
//    private var nudgeServiceWithScreenCaptureKit: NudgeServiceWithScreenCaptureKit?
//    private var eventQueue: [[String: Any]] = [] // Queue to hold events if eventSink is nil.
//   
//    var isMicrophoneInUse = false
//    var microphoneListenerBlock: AudioObjectPropertyListenerBlock?
//    
//    override init() {
//        super.init()
//        self.nudgeServiceWithCoreAudio = NudgeServiceWithCoreAudio()
//        self.nudgeServiceWithScreenCaptureKit = NudgeServiceWithScreenCaptureKit()
//        
//        //After Creating a instance, maybe add observers? Is it possible?
//        NotificationCenter.default.addObserver(self, selector: #selector(handleWindowDetection(_:)), name: .windowDetected, object: nil)
//    }
//    
//    @objc private func handleWindowDetection(_ notification: Notification) {
//        print("하하하하하하")
//        guard let userInfo = notification.userInfo,
//              let nudgeEventDictionary = userInfo["data"] as? [String: Any] else { return }
//        
//        print("NudgeEventDictionary!!", nudgeEventDictionary)
//        
//        eventSink?(nudgeEventDictionary)
//        
//        if let eventSink = self.eventSink {
//            eventSink(nudgeEventDictionary)
//        } else {
//            eventQueue.append(nudgeEventDictionary) // Queue the event if eventSink is not available.
//        }
//    }
//
//
//    
//
//    
//    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
//        print("Nudge OnListen 시작 🟢")
//        self.eventSink = events
//        
//        eventQueue.forEach { print($0)}
//        
//        eventQueue.forEach { events($0) }
//        eventQueue.removeAll() // Clear the queue after flushing.
//        
//        return nil
//    }
//    
//    func onCancel(withArguments arguments: Any?) -> FlutterError? {
//        print("Nudge onCancel 캔슬 🔴")
//
//        self.eventSink = nil
//        
//        return nil
//    }
//}
//
//
