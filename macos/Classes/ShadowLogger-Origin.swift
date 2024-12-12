//import Foundation
//
////MARK: Logger
//final class ShadowLogger {
//    static let shared = ShadowLogger()
//    private let logQueue = DispatchQueue(label: "com.shadowPlugin.app.logger")
//
//    private enum DateFormat: String {
//        case fullDateTime = "yyyy-MM-dd HH:mm:ss"
//        case dateOnly = "yyyy-MM-dd"
//        
//        var description: String {
//            return self.rawValue
//        }
//    }
//
//    private var fileURL: URL {
//        // Get the Application Support directory
//        guard let documentDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
//            // Handle error: Could not find the application support directory
//            print("Could not find the application support directory")
//            // Optionally, return a URL to a default or temporary directory as a fallback
//            return FileManager.default.temporaryDirectory.appendingPathComponent("com.taperlabs.shadow/logs")
//        }
//
//        // Append the specific folder path for 'com.taperlabs.shadow', then a 'logs' subfolder
//        let folderURL = documentDirectory
//            .appendingPathComponent("com.taperlabs.shadow")
//            .appendingPathComponent("logs")
//
//        // Get the current date in the desired format for file naming
//        let dateStamp = formatDate(with: .dateOnly)
//        
//        // Return the full path to the log file within the logs subfolder with the current date
//        return folderURL.appendingPathComponent("s_logs_\(dateStamp).txt")
//    }
//
//    
//    private init() {
//        let folderPath = fileURL.deletingLastPathComponent().path
//        if !FileManager.default.fileExists(atPath: folderPath) {
//            do {
//                try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
//            } catch {
//                fatalError("Could not create the directory: \(error)")
//            }
//        }
//        ensureLogFileExists()
//    }
//    
//    private func ensureLogFileExists() {
//        if !FileManager.default.fileExists(atPath: fileURL.path) {
//            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
//        }
//    }
//    
//    private func formatDate(with format: DateFormat, date: Date = Date()) -> String {
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = format.description
//        return dateFormatter.string(from: date)
//    }
//
//    func log(_ message: String) {
//        logQueue.async {
//            self.ensureLogFileExists()
//            let dateString = self.formatDate(with: .fullDateTime)
//            let logEntry = "\(dateString): \(message)\n"
//            do {
//                let fileHandle = try FileHandle(forWritingTo: self.fileURL)
//                defer { try? fileHandle.close() }
//                _ = try fileHandle.seekToEnd()
//                if let data = logEntry.data(using: .utf8) {
//                    try fileHandle.write(contentsOf: data)
//                }
//            } catch {
//                print("Failed to write to log file: \(error)")
//            }
//        }
//    }
//}
//
