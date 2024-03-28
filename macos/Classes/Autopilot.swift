import Foundation
import ScreenCaptureKit
import FlutterMacOS

struct LsofEntry {
    let appName: String
    let port: String
    let pid: String
    let startTime: Date
    
    func toDictionary() -> [String: Any] {
        return ["appName": appName, "port": port, "pid": pid, "startTime": startTime]
    }
    
    var isConnectionOlderThanNSeconds: Bool {
        //        print("Time ===>",floor(-startTime.timeIntervalSinceNow))
        return -startTime.timeIntervalSinceNow > 2
    }
}

final class Autopilot: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var process: Process?
    private var windows: [SCWindow]?
    private var isInMeetingByMic: Bool = false
    private var isInMeetingByWindowTitle: Bool = false
    private var isMeetingDetected: Bool = false
    private var windowCheckTimer: Timer?
    private var activeMeetingApp: MicrophoneApp?
    
    private var isMeetingInProgress: Bool = false
    private var activeConnections: [String: LsofEntry] = [:] // Use PID as the key
    private let blacklistAppNames: Set<String> = ["firefox", "Spotify"]
    private var lsofUDPCheckTimer: Timer?
    
    private var isLogStreamSuspended: Bool = false
    
    enum WhitelistAppName: String, CaseIterable {
        case Around = "Around"
        case Discord = "Discord"
        case Zoom = "zoom.us"
        case Slack = "Slack"
        case Webex = "WebexHelper"
        case GoTo = "GoTo"
    }

    //"com.apple.Safari"
    enum WindowTitles {
        case googleMeet
        case teams
        case webex
        case around
        
        var detectionString: String {
            switch self {
            case .googleMeet: return "Meet -"
                //            case .teams: return "Meeting with"
            case .teams: return "(Meeting) | Microsoft Teams classic"
            case .webex: return "Cisco Webex"
            case .around: return "Room | Around"
            }
        }
        
        var appName: String {
            switch self {
            case .googleMeet: return "Google Meet"
            case .teams: return "Microsoft Teams"
            case .webex: return "Cisco Webex"
            case .around: return "Around"
            }
        }
    }
    
    //"mic:com.microsoft.teams2" -- Teams New
    //"mic:com.microsoft.teams" -- Teams Classic
    
    //MARK: Webex, discord, slack, zoom, arc, goto는 앱 기반이지만 마이크 역시 같이 체크해야 함.
    enum MicrophoneApp: String {
        case chrome = "\"mic:com.google.Chrome\""
        case safari = "\"mic:com.apple.WebKit.GPU\""
        case arc = "\"mic:company.thebrowser.Browser\""
        case edge = "\"mic:com.microsoft.edgemac\""
        case firefox = "\"mic:org.mozilla.firefox\""
        case zoom = "\"mic:us.zoom.xos\""
        case around = "\"mic:co.teamport.around\""
        case teamsclassic = "\"mic:com.microsoft.teams\""
        case teamsnew = "\"mic:com.microsoft.teams2\""
        case slack = "mic:com.tinyspeck.slackmacgap"
        case discord = "mic:com.hnc.Discord"
        case webex = "mic:Cisco-Systems.Spark"
        case goto = "mic:com.logmein.goto"
        
        static let allValues = [chrome, safari, arc, edge, firefox, zoom, around, teamsnew, teamsclassic, slack, discord, webex, goto]
    }
    
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        
        self.eventSink = events
        if self.isLogStreamSuspended {
            resumeLogStream()
        } else {
            runStream()
        }
        startWindowCheckTimer()
        startLSOFUDPCheckTimer()
        print("Autopilot OnListen 시작 🟢")
        
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        stopStream()
        endWindowCheckTimer()
        endLSOFUDPCheckTimer()
        print("Autopilot OnCancel 캔슬 🔴")
        
        return nil
    }
    
    // Start a timer to check window titles every second
    private func startWindowCheckTimer() {
        windowCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.fetchWindows()
        }
    }
    
    private func endWindowCheckTimer() {
        windowCheckTimer?.invalidate()
        windowCheckTimer = nil
    }
    
    private func startLSOFUDPCheckTimer() {
        lsofUDPCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.detectMeetingInSession()
        }
    }
    
    private func endLSOFUDPCheckTimer() {
        lsofUDPCheckTimer?.invalidate()
        lsofUDPCheckTimer = nil
    }
    
    private func resumeLogStream() {
        self.process?.resume()
    }
    
    private func isAppNameWhitelisted(appName: String) -> Bool {
        return WhitelistAppName.allCases.contains { appName.contains($0.rawValue) }
    }
    
    private func detectMeetingInSession() {
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            guard let self = self else { return }
            //let startTime = Date()
            do {
                let output = try self.executeLsof()
                DispatchQueue.main.async {
                    self.parseLsofOutput(output)
                    //print("🏄‍♂️", activeConnections)
                    
                    if self.activeConnections.isEmpty && self.isMeetingInProgress {
                        //print("You were in a Meeting but now ended 🔴")
                        self.isMeetingInProgress = false
                        self.isInMeetingByMic = false
                        self.isInMeetingByWindowTitle = false
                        self.updateMeetingStatus()
                        //Condition met, now end the function block
                        return
                    }
                    
                    for entry in self.activeConnections.values {
                        //print("Entry", entry)
                        
                        if self.isAppNameWhitelisted(appName: entry.appName) {
                            if entry.isConnectionOlderThanNSeconds {
                                //print("You are in a Meeting! 🟢 App Name: \(entry.appName), Port: \(entry.port), PID: \(entry.pid)")
                                self.isMeetingInProgress = true
                                self.isInMeetingByMic = true
                                self.isInMeetingByWindowTitle = true
                                self.updateMeetingStatus()
                                //Logic
                            } else {
                                print("Connection is too short, might not be a meeting")
                            }
                        }
                    }
                }
                
            } catch let error {
                print("Failed to run lsof: \(error.localizedDescription)")
            }
        }
        
        
        
        //        let endTime = Date()  // Record the end time after all operations, including executeLsof, are completed
        //        let executionTime = endTime.timeIntervalSince(startTime)
        //        print("Total Execution Time for CoreNetwork: \(executionTime) seconds")
    }
    
    private func executeLsof() throws -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["lsof", "-i", "UDP:40000-69999", "+c", "30"]
        process.standardOutput = pipe
        
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func parseLsofOutput(_ output: String) {
        let newLines = output.components(separatedBy: .newlines)
        let pattern = "UDP (\\*|\\d{1,3}(\\.\\d{1,3}){3}):([4-6]\\d{4,5})(?!.*->)"
        var foundPIDs: Set<String> = []
        
        for line in newLines {
            if let range = line.range(of: pattern, options: .regularExpression), line.contains("UDP") {
                let matchedLine = String(line[range])
                let lineArr = line.split(separator: " ")
                let pid = extractPID(from: lineArr)
                let appName = extractAppName(from: lineArr)
                
                if isAppNameWhitelisted(appName: appName) {
                    foundPIDs.insert(pid)
                }
                
                // Check pid active connection
                if activeConnections[pid] == nil {
                    // New connection detected, add it to activeConnection
                    let entry = LsofEntry(appName: appName,
                                          port: extractPort(from: matchedLine),
                                          pid: pid,
                                          startTime: Date())
                    activeConnections[pid] = entry
                    
                }
            }
        }
        
        // Remove any entries not found in the latest lsof output
        activeConnections.keys.forEach { key in
            if !foundPIDs.contains(key) {
                activeConnections.removeValue(forKey: key)
            }
        }
    }
    
    private func extractPID(from line: [Substring]) -> String {
        //        print("This is PID ->", line[1])
        let pid = String(line[1])
        
        return pid
    }
    
    private func extractAppName(from line: [Substring]) -> String {
        //        print("This is extractAppName ->", line[0])
        let appName = String(line[0])
        
        return appName
    }
    
    private func extractPort(from line: String) -> String {
        let components = line.split(separator: " ")
        if let lastComponent = components.last {
            let portNumber = lastComponent.split(separator: ":")
            if portNumber.count > 1 {
                return String(portNumber[1])
            }
        }
        return "Unknown Port Number"
    }
    
    private func updateMeetingStatus() {
        if isInMeetingByMic && isInMeetingByWindowTitle && !isMeetingDetected {
            isMeetingDetected = true
            self.eventSink?(["isInMeeting": isMeetingDetected])
            print("✈️ 미팅 시작 감지 성공 Flutter로 메세지 보냅니다 🟢")
            // Perform actions for meeting start
        } else if isMeetingDetected && !isInMeetingByMic {
            isMeetingDetected = false
            self.eventSink?(["isInMeeting": isMeetingDetected])
            print("🗳️ 미팅 종료 감지 성공 Flutter로 메세지 보냅니다 🔴")
            // Perform actions for meeting end
        }
    }
    
    private func fetchWindows() -> Void {
//        print("Fetch Window")
        //Background Thread for executing the logic
        DispatchQueue.global().async { [weak self] in
            SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { content, error in
//                print("Fetch Window 2222")
                guard let content = content else { return }
//                print("Fetch Window 3333")
 
                
                //                DispatchQueue.main.async {
                self?.windows = content.windows
                self?.detectInMeeting()
                //                }
            }
        }
    }
    
    private func detectInMeeting() -> Void {
        guard let unWrappedWindows = self.windows else { return }
        DispatchQueue.global().async { [weak self] in
            
            var foundWindowID: Int?
            var foundAppName: String?
            var googleMeetID: String?
            
            self?.isInMeetingByWindowTitle = false
            
            for window in unWrappedWindows {
                guard let title = window.title, let bundleID = window.owningApplication?.bundleIdentifier else { continue }
         
                if bundleID == "company.thebrowser.Browser" && self?.isGoogleMeetFormat(title: title) == true {
                    self?.isInMeetingByWindowTitle = true
                    break
                } else if title.contains(WindowTitles.teams.detectionString) {
                    self?.isInMeetingByWindowTitle = true
                    
                    foundWindowID = Int(window.windowID)
                    foundAppName = WindowTitles.teams.appName
                    break
                } else if let extractedID = self?.extractGoogleMeetID(from: title) {
                    // Check if title contains the detection string and the extracted ID is in the correct format
                    if title.contains(WindowTitles.googleMeet.detectionString) && self?.isGoogleMeetFormat(title: extractedID) == true {
                        self?.isInMeetingByWindowTitle = true
                        foundWindowID = Int(window.windowID)
                        foundAppName = WindowTitles.googleMeet.appName
                        googleMeetID = extractedID
                        break
                    }
                } else if title.contains(WindowTitles.webex.detectionString) {
                    self?.isInMeetingByWindowTitle = true
                    foundWindowID = Int(window.windowID)
                    foundAppName = WindowTitles.webex.appName
                    break
                }  else if title.contains(WindowTitles.around.detectionString) {
                    self?.isInMeetingByWindowTitle = true
                    foundWindowID = Int(window.windowID)
                    foundAppName = WindowTitles.around.appName
                    break
                }
            }
            
            DispatchQueue.main.async {
                self?.updateMeetingStatus()  // Call the update method here
            }
        }
    }
    
    private func isGoogleMeetFormat(title: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: "^[a-zA-Z]{3}-[a-zA-Z]{4}-[a-zA-Z]{3}$", options: [])
        let range = NSRange(location: 0, length: title.utf16.count)
        return regex?.firstMatch(in: title, options: [], range: range) != nil
    }
    
    private func extractGoogleMeetID(from title: String) -> String? {
        guard let meetingIDPattern = try? Regex("[a-zA-Z]{3}-[a-zA-Z]{4}-[a-zA-Z]{3}") else { return nil }
        guard let match = title.firstMatch(of: meetingIDPattern) else { return nil }
        return String(title[match.range])
    }
    
    private func runStream() {
        DispatchQueue.global(qos: .default).async {
            let newProcess = Process()
            let pipe = Pipe()
            
            newProcess.executableURL = URL(fileURLWithPath: "/usr/bin/log")
            newProcess.arguments = ["stream", "--predicate", "subsystem == 'com.apple.controlcenter' AND eventMessage CONTAINS 'Active activity attributions changed to'"]
            newProcess.standardOutput = pipe
            
            let readHandle = pipe.fileHandleForReading
            readHandle.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                if let string = String(data: data, encoding: .utf8), !string.isEmpty {
                    print("스트리입니다", string)
                    if string.contains("Active activity attributions changed to") {
                        let components = string.components(separatedBy: "Active activity attributions changed to")
                        if components.count > 1 {
                            let arrayPart = components[1]
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            // Remove the square brackets and newline characters
                            let cleanedArrayPart = arrayPart
                                .trimmingCharacters(in: CharacterSet(charactersIn: "[]\n"))
                            
                            // Split the cleaned array part by commas and remove any surrounding whitespace
                            let arrayElements = cleanedArrayPart
                                .components(separatedBy: ",")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            
                            // Remove the escaped backslashes and double quotes from each element
                            let cleanedArrayElements = arrayElements.map { element in
                                let unescapedElement = element
                                    .replacingOccurrences(of: "\\\"", with: "\"")
                                    .replacingOccurrences(of: "\\\\", with: "\\")
                                return unescapedElement.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                            }
                            
                            print("Cleaned Array elements ->", cleanedArrayElements)
                            
                            for app in MicrophoneApp.allValues {
                                let appIdentifier = app.rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                                print("appIdentifier", appIdentifier, app)
                                if cleanedArrayElements.contains(where: { element in
                                    element.contains(appIdentifier)
                                }) {
                                    // Special handling for teamsclassic and teamsnew
                                    if app == .teamsclassic || app == .teamsnew {
                                        print("Teams Detected")
                                        self.isInMeetingByMic = true
                                        self.activeMeetingApp = app
                                        self.isInMeetingByWindowTitle = true
                                        
                                        break
                                    }
                                    
                                    
                                    self.isInMeetingByMic = true
                                    self.activeMeetingApp = app
                                    print("Active Meeting App", app)
                                    print("Microphone is in use by \(app)")
                                    // React to microphone being used by this app
                                    break
                                }
                            }
                            
                            if !cleanedArrayElements.contains(where: { element in
                                MicrophoneApp.allValues.contains { app in
                                    element.contains(app.rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
                                }
                            }) {
                                self.isInMeetingByMic = false
                                self.activeMeetingApp = nil
                                print("Microphone is no longer in use by listed apps")
                                // React to microphone not being used by listed apps
                            }
                            
                            DispatchQueue.main.async {
                                self.process = newProcess
                                self.updateMeetingStatus()
                            }
                        }
                    }
                }
            }
            do {
                try newProcess.run()
            } catch {
                print("Error occurred: \(error)")
            }
        }
    }
    
    
//    private func runStream() {
//        DispatchQueue.global(qos: .default).async {
//            let newProcess = Process()
//            let pipe = Pipe()
//            
//            newProcess.executableURL = URL(fileURLWithPath: "/usr/bin/log")
//            newProcess.arguments = ["stream", "--predicate", "subsystem == 'com.apple.controlcenter' AND eventMessage CONTAINS 'Active activity attributions changed to'"]
//            newProcess.standardOutput = pipe
//            
//            let readHandle = pipe.fileHandleForReading
//            readHandle.readabilityHandler = { fileHandle in
//                let data = fileHandle.availableData
//                if let string = String(data: data, encoding: .utf8), !string.isEmpty {
//                    print("스트리입니다", string)
//                    if string.contains("Active activity attributions changed to") {
//                        let components = string.components(separatedBy: "Active activity attributions changed to")
//                        if components.count > 1 {
//                            let arrayPart = components[1]
//                                .trimmingCharacters(in: .whitespacesAndNewlines)
//                                .trimmingCharacters(in: CharacterSet(charactersIn: "[]\"\n"))
//                            let arrayElements = arrayPart
//                                .components(separatedBy: ",")
//                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
//                            print("Array element ->", arrayElements)
//                            
//                            for app in MicrophoneApp.allValues {
//                                let appIdentifier = app.rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
//                                print("appIdentifier", appIdentifier, app)
//                                if arrayElements.contains(where: { element in
//                                    element.contains(appIdentifier)
//                                }) {
//                                    // Special handling for teamsclassic and teamsnew
//                                    if app == .teamsclassic || app == .teamsnew {
//                                        print("Teams Detected")
//                                        self.isInMeetingByMic = true
//                                        self.activeMeetingApp = app
//                                        self.isInMeetingByWindowTitle = true
//                                        
//                                        break
//                                    }
//                                    
//                                    
//                                    self.isInMeetingByMic = true
//                                    self.activeMeetingApp = app
//                                    print("Active Meeting App", app)
//                                    print("Microphone is in use by \(app)")
//                                    // React to microphone being used by this app
//                                    break
//                                }
//                            }
//                            
//                            if !arrayElements.contains(where: { element in
//                                MicrophoneApp.allValues.contains { app in
//                                    element.contains(app.rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"")))
//                                }
//                            }) {
//                                self.isInMeetingByMic = false
//                                self.activeMeetingApp = nil
//                                print("Microphone is no longer in use by listed apps")
//                                // React to microphone not being used by listed apps
//                            }
//                            
//                            DispatchQueue.main.async {
//                                self.process = newProcess
//                                self.updateMeetingStatus()
//                            }
//                        }
//                    }
//                }
//            }
//            do {
//                try newProcess.run()
//            } catch {
//                print("Error occurred: \(error)")
//            }
//        }
//    }
    
    private func stopStream() {
        guard self.process != nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isLogStreamSuspended = self.process?.suspend() ?? false
        }
    }
}
