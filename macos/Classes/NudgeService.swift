//import Foundation
//import RegexBuilder
//import Network
//import FlutterMacOS
//import ScreenCaptureKit
//
//struct LsofEntry {
//    let appName: String
//    let port: String
//    let pid: String
//    let startTime: Date
//    var isConnectionOlderThanNSeconds: Bool {
//        print("Time ===>",-startTime.timeIntervalSinceNow)
//        return -startTime.timeIntervalSinceNow > 5
//    }
//    
//    func toDictionary() -> [String: Any] {
//        return ["appName": appName, "port": port, "pid": pid, "startTime": startTime]
//    }
//    
//    func toDitionaryWithoutTime() -> [String: Any] {
//        return ["appName": appName, "port": port, "pid": pid,]
//    }
//}
//
////MARK: - NudgeService Class
//final class NudgeService: NSObject, FlutterStreamHandler {
//    private var eventSink: FlutterEventSink?
//    private var nudgeTimer: Timer?
//    private var isMeetingInProgress: Bool = false
//    private var activeConnections: [String: LsofEntry] = [:] // Use PID as the key
//    private let blacklistAppNames: Set<String> = ["firefox", "Spotify"]
//    
//    private var windows: [SCWindow]?
//    
//    //MARK: Whitelist enum
//    private enum WhitelistAppName: String, CaseIterable {
//        case around = "Around"
//        case discord = "Discord"
//        case zoom = "zoom.us"
//        case slack = "Slack"
//        case chrome = "Google"
//        case safari = "com.apple"
//        case edge = "Microsoft"
//        case arc = "Arc"
//        case firefox = "plugin-co"
//    }
//    
//    
//    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
//        print("Nudge OnListen 시작 🟢")
//        self.eventSink = events
//        nudgeTimer = Timer.scheduledTimer(timeInterval: 2.5, target: self, selector: #selector(detectMeetingInSession), userInfo: nil, repeats: true)
//        
//        return nil
//    }
//    
//    func onCancel(withArguments arguments: Any?) -> FlutterError? {
//        print("Nudge onCancel 캔슬 🔴")
//        nudgeTimer?.invalidate()
//        self.eventSink = nil
//        
//        return nil
//    }
//    
//    @objc private func fetchWindows() -> Void {
//        //Background Thread for executing the logic
//        DispatchQueue.global().async { [weak self] in
//            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
//                guard let content = content else { return }
//                DispatchQueue.main.async {
//                    self?.windows = content.windows
//                }
//            }
//        }
//    }
//    
//    private func resetAllProperties() -> Void {
//        self.isMeetingInProgress = false
//    }
//    
//    
//    private func isAppNameWhitelisted(appName: String) -> Bool {
//        return WhitelistAppName.allCases.contains { appName.contains($0.rawValue) }
//    }
//    
//    
//    @objc private func detectMeetingInSession() {
//        do {
//            let output = try executeLsof()
//            parseLsofOutput(output)
//            
//            if activeConnections.isEmpty && self.isMeetingInProgress {
//                print("You were in a meeting but now ended 🔴")
//                self.eventSink?(["isInMeeting": false])
//                self.isMeetingInProgress = false
//            }
//            
//            activeConnections.values.forEach { entry in
//                if isAppNameWhitelisted(appName: entry.appName) {
//                    if entry.isConnectionOlderThanNSeconds {
//                        print("You are in a Meeting! 🟢 App Name: \(entry.appName), Port: \(entry.port), PID: \(entry.pid)")
//                        self.isMeetingInProgress = true
//                        self.eventSink?(["isInMeeting": self.isMeetingInProgress])
//                    } else {
//                        print("Connection is too short, might not be a meeting")
//                    }
//                }
//            }
//            
//            for entry in activeConnections.values {
//                if isAppNameWhitelisted(appName: entry.appName) {
//                    if entry.isConnectionOlderThanNSeconds {
//                        print("You are in a Meeting! 🟢 App Name: \(entry.appName), Port: \(entry.port), PID: \(entry.pid)")
//                        self.isMeetingInProgress = true
//                        self.eventSink?(["isInMeeting": self.isMeetingInProgress])
//                        //                        self.eventSink?(entry.toDitionaryWithoutTime())
//                    } else {
//                        print("Connection is too short, might not be a meeting")
//                    }
//                }
//            }
//            
//            
//            //            if entries.isEmpty {
//            //                print("You are not in a meeting ❌")
//            //                if self.isMeetingInProgress {
//            //                    self.eventSink?(["isInMeeting": false])
//            //                    self.isMeetingInProgress = false
//            //                }
//            //            }
//            
//            //            entries.forEach { entry in
//            //                if isAppNameWhitelisted(appName: entry.appName) {
//            //                    print("You are in a Meeting! 🟢 App Name: \(entry.appName), Port: \(entry.port), PID: \(entry.pid)")
//            ////                 Chromium based Web Apps Double-check
//            //                    var whitelistAppNamesArray = [WhitelistAppName.arc.rawValue, WhitelistAppName.chrome.rawValue, WhitelistAppName.edge.rawValue]
//            //                    if whitelistAppNamesArray.contains(where: entry.appName.contains) {
//            //                        let isMicInUse = self.isMicrophoneInUse()
//            //                        if isMicInUse {
//            //                            self.isMeetingInProgress = true
//            //                            self.eventSink?(entry.toDictionary())
//            //                        }
//            //                    }
//            //                } else {
//            //                    print("Looks like you are in a meeting but it's not whitelisted app!")
//            //                }
//            //            }
//            
//        } catch let error {
//            print("Failed to run lsof: \(error.localizedDescription)")
//        }
//    }
//    
//    private func executeLsof() throws -> String {
//        let process = Process()
//        let pipe = Pipe()
//        
//        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
//        process.arguments = ["lsof", "-i", "UDP:40000-69999"]
//        process.standardOutput = pipe
//        
//        try process.run()
//        let data = pipe.fileHandleForReading.readDataToEndOfFile()
//        return String(data: data, encoding: .utf8) ?? ""
//    }
//    
//    private func parseLsofOutput(_ output: String) {
//        let newLines = output.components(separatedBy: .newlines)
//        let pattern = "UDP (\\*|\\d{1,3}(\\.\\d{1,3}){3}):([4-6]\\d{4,5})(?!.*->)"
//        var foundPIDs: Set<String> = []
//        
//        for line in newLines {
//            if let range = line.range(of: pattern, options: .regularExpression), line.contains("UDP") {
//                let matchedLine = String(line[range])
//                let lineArr = line.split(separator: " ")
//                let pid = extractPID(from: lineArr)
//                let appName = extractAppName(from: lineArr)
//                
//                if isAppNameWhitelisted(appName: appName) {
//                    foundPIDs.insert(pid)
//                }
//                
//                if !blacklistAppNames.contains(extractAppName(from: lineArr)) && activeConnections[pid] == nil {
//                    let entry = LsofEntry(appName: extractAppName(from: lineArr),
//                                          port: extractPort(from: matchedLine),
//                                          pid: pid,
//                                          startTime: Date())
//                    activeConnections[pid] = entry
//                }
//            }
//        }
//        
//        activeConnections.keys.forEach { key in
//            if !foundPIDs.contains(key) {
//                activeConnections.removeValue(forKey: key)
//            }
//        }
//        
//        
//        //        var entries: [LsofEntry] = []
//        //
//        //        for line in newLines {
//        //            if let range = line.range(of: pattern, options: .regularExpression), line.contains("UDP") {
//        //                let matchedLine = String(line[range])
//        //
//        //                print(matchedLine)
//        //                print(line)
//        //                let lineArr = line.split(separator: " ")
//        //                let entry = LsofEntry(appName: extractAppName(from: lineArr), port: extractPort(from: matchedLine), pid: extractPID(from: lineArr))
//        //                entries.append(entry)
//        //            }
//        //        }
//        //        return entries
//    }
//    
//    private func extractPID(from line: [Substring]) -> String {
//        //        print("This is PID ->", line[1])
//        let pid = String(line[1])
//        
//        return pid
//    }
//    
//    private func extractAppName(from line: [Substring]) -> String {
//        //        print("This is extractAppName ->", line[0])
//        let appName = String(line[0])
//        
//        return appName
//    }
//    
//    private func extractPort(from line: String) -> String {
//        let components = line.split(separator: " ")
//        if let lastComponent = components.last {
//            let portNumber = lastComponent.split(separator: ":")
//            if portNumber.count > 1 {
//                return String(portNumber[1])
//            }
//        }
//        return "Unknown Port Number"
//    }
//    
//    //MARK: - Mic Related
//    
//    private func isMicrophoneInUse() -> Bool {
//        var isRunningSomewhere: UInt32 = 0
//        var deviceID = self.getDefaultInputDevice()
//        var propertySize = UInt32(MemoryLayout<UInt32>.size)
//        var propertyAddress = AudioObjectPropertyAddress(
//            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
//            mScope: kAudioObjectPropertyScopeGlobal,
//            mElement: kAudioObjectPropertyElementMain)
//        
//        let status = AudioObjectGetPropertyData(deviceID,
//                                                &propertyAddress,
//                                                0,
//                                                nil,
//                                                &propertySize,
//                                                &isRunningSomewhere)
//        
//        if status != kAudioHardwareNoError {
//            print("Error getting device running status: \(status)")
//            return false
//        }
//        
//        return isRunningSomewhere != 0
//    }
//    
//    private func getDefaultInputDevice() -> AudioDeviceID {
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
//        if status != kAudioHardwareNoError {
//            print("Error getting default input device: \(status)")
//            return kAudioObjectUnknown
//        }
//        
//        return defaultInputDeviceID
//    }
//}
