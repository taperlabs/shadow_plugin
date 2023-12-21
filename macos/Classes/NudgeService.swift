import Foundation
import RegexBuilder
import Network
import FlutterMacOS

struct LsofEntry {
    let appName: String
    let port: String
    let pid: String
    
    func toDictionary() -> [String: Any] {
        return ["appName": appName, "port": port, "pid": pid]
    }
}

//MARK: - NudgeService Class
class NudgeService: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    private var nudgeTimer: Timer?
    var appName: String?
    var portNumber: Int?
    
    enum WhitelistAppName: String, CaseIterable {
        case Around = "Around"
        case Discord = "Discord"
        case Zoom = "zoom.us"
        case Slack = "Slack"
        case Chrome = "Google"
        case Safari = "com.apple"
        case Edge = "Edge"
        case Arc = "Arc"
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("Nudge OnListen 시작 🟢")
        self.eventSink = events
        nudgeTimer = Timer.scheduledTimer(timeInterval: 2.5, target: self, selector: #selector(runLsofCommand), userInfo: nil, repeats: true)
        
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("Nudge onCancel 캔슬 🔴")
        nudgeTimer?.invalidate()
        self.eventSink = nil
        
        return nil
    }
    
    private func isAppNameWhitelisted(appName: String) -> Bool {
        return WhitelistAppName.allCases.contains { appName.contains($0.rawValue) }
    }
    
    @objc private func runLsofCommand() {

        do {
            let output = try executeLsof()
            let entries = parseLsofOutput(output)
            
            if entries.isEmpty {
                print("You are not in a meeting ❌")
                self.eventSink?(["IsInMeeting": false])
            }
            
            entries.forEach { entry in
                let appName = entry.appName
                print("You are in a Meeting! 🔴,App Name: \(entry.appName), Port: \(entry.port), PID: \(entry.pid)")
                if isAppNameWhitelisted(appName: appName) {
                    print("App Name is Whitelisted!!")
                    self.eventSink?(entry.toDictionary())
                } else {
                    print("It's not whitelisted")
                }
            }

        } catch let error {
            print("Failed to run lsof: \(error.localizedDescription)")
        }
    }
    
    private func executeLsof() throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["lsof", "-i", "UDP:40000-69999"]
        process.standardOutput = pipe
        
        print("여기가 문제니?")

        try process.run()
        print("여기가 문제니?222")
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        print(data)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    private func parseLsofOutput(_ output: String) -> [LsofEntry] {
        let newLines = output.components(separatedBy: .newlines)
        let pattern = "UDP (\\*|\\d{1,3}(\\.\\d{1,3}){3}):([4-6]\\d{4,5})(?!.*->)"
        var entries: [LsofEntry] = []

        for line in newLines {
            if let range = line.range(of: pattern, options: .regularExpression), line.contains("UDP") {
                let matchedLine = String(line[range])
                
                print(matchedLine)
                print(line)
                let lineArr = line.split(separator: " ")
                // Further processing to extract appName and port
                let entry = LsofEntry(appName: extractAppName(from: lineArr), port: extractPort(from: matchedLine), pid: extractPID(from: lineArr))
                entries.append(entry)
            }
        }
        return entries
    }
    
    private func extractPID(from line: [Substring]) -> String {
        print("This is PID ->", line[1])
        let pid = String(line[1])
        
        return pid
    }
    
    private func extractAppName(from line: [Substring]) -> String {
        print("This is extractAppName ->", line[0])
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

    
    
//    private func runLsofCommand() {
//        let process = Process()
//        let pipe = Pipe()
//
//        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
//        process.arguments = ["lsof", "-i", "UDP:40000-69999"]
//        process.standardOutput = pipe
//
//        do {
//            try process.run()
//            let data = pipe.fileHandleForReading.readDataToEndOfFile()
//            if let output = String(data: data, encoding: .utf8) {
//                let newLines = output.components(separatedBy: .newlines)
//                print(newLines)
//                let pattern = "UDP (\\*|\\d{1,3}(\\.\\d{1,3}){3}):([4-6]\\d{4,5})(?!.*->)"
//                
//                for line in newLines {
//                    if let range = line.range(of: pattern, options: .regularExpression), line.contains("UDP") {
//                        print("Matched Line: \(line[range])")
//                        // Further processing can be done here
//                    }
//                }
//            }
//        } catch let error {
//            print("Failed to run lsof: \(error.localizedDescription)")
//        }
//    }
}
