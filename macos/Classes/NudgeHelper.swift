//import Foundation
//import ScreenCaptureKit
//import FlutterMacOS
//import RegexBuilder
//import CoreAudio
//
//
//final class NudgeHelper: NSObject, FlutterStreamHandler {
//    private var eventSink: FlutterEventSink?
//    private var nudgeTimer: Timer?
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
//    private var isMicrophoneInUse = false
//    private var microphoneListenerBlock: AudioObjectPropertyListenerBlock?
//    
//    private var deviceID: AudioDeviceID?
//    
//    override init() {
//        super.init()
//        self.setUpDefaultInputDeviceListener() // Set up listener for default input device changes
//        self.detectMicInUsage()
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
//            case .googleMeet: return "Meet"
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
//    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
//        print("Nudge OnListen 시작 🟢")
//        self.eventSink = events
//        nudgeTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateSCWindows2), userInfo: nil, repeats: true)
//        
//        return nil
//    }
//    
//    func onCancel(withArguments arguments: Any?) -> FlutterError? {
//        print("Nudge onCancel 캔슬 🔴")
//        nudgeTimer?.invalidate()
//        self.resetMeetingProperties()
//        self.eventSink = nil
//
//        
//        return nil
//    }
//    
//    func setUpDefaultInputDeviceListener() {
//        var propertyAddress = AudioObjectPropertyAddress(
//            mSelector: kAudioHardwarePropertyDefaultInputDevice,
//            mScope: kAudioObjectPropertyScopeGlobal,
//            mElement: kAudioObjectPropertyElementMain
//        )
//
//        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
//            // Default input device changed, update microphone monitoring
//            self?.updateMicMonitoring()
//        }
//
//        let status = AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject),
//                                                         &propertyAddress,
//                                                         nil,
//                                                         block)
//
//        if status != noErr {
//            print("Error adding default input device listener: \(status)")
//        }
//    }
//    
//    func updateMicMonitoring() {
//        // First, remove existing microphone listener if it exists
//        if let existingBlock = microphoneListenerBlock, let oldDeviceID = self.deviceID {
//            var propertyAddress = AudioObjectPropertyAddress(
//                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
//                mScope: kAudioObjectPropertyScopeGlobal,
//                mElement: kAudioObjectPropertyElementMain
//            )
//            AudioObjectRemovePropertyListenerBlock(AudioObjectID(oldDeviceID), &propertyAddress, nil, existingBlock)
//        }
//
//        // Now, set up the microphone listener for the new default input device
//        detectMicInUsage()
//    }
//
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
//    func detectMicInUsage() -> Void {
//        print("Detect Mic Usage 메소드 호출")
//        var deviceID = self.getDefaultInputDevice()
//        self.deviceID = deviceID
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
//            print("Is Mic in Use? :", self.isMicrophoneInUse)
//            
//            if self.isMicrophoneInUse {
//                print("Microphone is now in use")
////                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
////                    print("2초 뒤 호출이다")
////
////                }
//                self.updateSCWindows { [weak self] in
//                    self?.detectInMeeting2()
//                }
//                
//              
//                
//            } else {
//                print("Microphone is no longer in use")
//                DispatchQueue.main.async {
//                    self.eventSink?(["isInMeeting": false])
//                }
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
//    
//    
//    private func resetMeetingProperties() -> Void {
//        self.isMicrophoneInUse = false
//        self.isInMeeting = false
//        self.lastFoundAppName = nil
//        self.lastGoogleMeetID = nil
//        self.lastFoundAppName = nil
//    }
//    
//    @objc private func updateSCWindows2() -> Void {
//        print("updateSCWindow START!!")
//        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
//                guard let content = content else { return }
//                DispatchQueue.main.async {
//                    self?.windows = content.windows
//                    self?.apps = content.applications
//                    self?.displays = content.displays
//                }
//            }
//        }
//    }
//    
//    private func updateSCWindows(completion: @escaping () -> Void) {
//        DispatchQueue.global(qos:.userInitiated).async { [weak self] in
//            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
//                guard let content = content else { return }
//                DispatchQueue.main.async {
//                    self?.windows = content.windows
//                    self?.apps = content.applications
//                    self?.displays = content.displays
//                    completion()
//                }
//            }
//        }
//    }
//    
//    @objc private func fetchWindows() -> Void {
//        print("Called Fetch Windows!!")
//        
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
//    private func detectInMeeting2() {
//        DispatchQueue.main.async {
//            guard let frontmostApp = NSWorkspace.shared.frontmostApplication?.localizedName else {
//                print("No Front Most App Detected")
//                return
//            }
//            
//            if frontmostApp == "zoom.us" || frontmostApp == "Slack" {
//                print("In a meeting app: \(frontmostApp)")
//                self.eventSink?(["IsInMeeting": true, "appName": frontmostApp])
//            } else if frontmostApp == "Google Chrome" {
//                    self.updateSCWindows {
//                        self.checkForGoogleMeetInChrome()
//                    }
//            } else {
//                self.eventSink?(["IsInMeeting": false])
//            }
//        }
//    }
//    
//    private func checkForGoogleMeetInChrome() {
//        guard let unWrappedWindows = self.windows else {
//            print("Window is Nil")
//            return
//        }
//        
//        let isGoogleMeetSession = unWrappedWindows.contains { window in
//            window.title?.contains(WindowTitles.googleMeet.detectionString) ?? false
//        }
//
//        if isGoogleMeetSession {
//            print("Google Meet session detected in Chrome")
//            self.eventSink?(["IsInMeeting": true, "appName": WindowTitles.googleMeet.appName])
//        } else {
//            print("Not a Google Meet session in Chrome")
//            self.eventSink?(["IsInMeeting": false])
//        }
//    }
//    
//    
//    private func detectInMeeting() -> Void {
//        guard let unWrappedWindows = self.windows else { return }
//        DispatchQueue.global().async { [weak self] in
//            
//            var foundWindowID: Int?
//            var foundAppName: String?
//            var googleMeetID: String?
//            var isOnScreen: Bool?
//            
//            for window in unWrappedWindows {
//                if let title = window.title {
//                    if title.contains(WindowTitles.zoom.detectionString) {
//                        foundWindowID = Int(window.windowID)
//                        foundAppName = WindowTitles.zoom.appName
//                        isOnScreen = window.isOnScreen
//                        self?.isInMeeting = true
//                        break
//                    } else if title.contains(WindowTitles.googleMeet.detectionString) {
//                        print("Google meet 찾았다", title)
//                        foundWindowID = Int(window.windowID)
//                        foundAppName = WindowTitles.googleMeet.appName
//                        googleMeetID = self?.extractGoogleMeetID(from: title)
//                        isOnScreen = window.isOnScreen
//                        self?.isInMeeting = true
//                        break
//                    } else if title.contains(WindowTitles.slack.detectionString) {
//                        foundWindowID = Int(window.windowID)
//                        foundAppName = WindowTitles.slack.appName
//                        isOnScreen = window.isOnScreen
//                        self?.isInMeeting = true
//                        break
//                    }
//                }
//            }
//            
//            DispatchQueue.main.async {
//                if let windowID = foundWindowID, let appName = foundAppName, let isInMeeting = self?.isInMeeting, let googleMeetID = googleMeetID{
//                    if googleMeetID != self?.lastGoogleMeetID {
//                        print("Detect In Meeting")
//                        let nudgeEvent = NudgeEventModel(appName: appName, isInMeeting: isInMeeting, windowID: windowID, googleMeetID: googleMeetID)
//                        self?.eventSink?(nudgeEvent.nudgeEventDictionary)
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
//                        print("Detect In Meeting2222")
//                        let nudgeEvent = NudgeEventModel(appName: appName, isInMeeting: isInMeeting, windowID: windowID)
//                        self?.eventSink?(nudgeEvent.nudgeEventDictionary)
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
//
