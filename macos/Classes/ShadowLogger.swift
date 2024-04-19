import Foundation

//MARK: Logger
class ShadowLogger {
    static let shared = ShadowLogger()
    private let logQueue = DispatchQueue(label: "com.shadowPlugin.app.logger")
    
    private var fileURL: URL {
        // Get the Application Support directory
        guard let documentDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Could not find the application support directory")
        }
        // Append the specific folder path
        let folderURL = documentDirectory.appendingPathComponent("com.taperlabs.shadow")
        
        // Return the full path to the log file within the specific folder
        return folderURL.appendingPathComponent("s_logs.txt")
    }
    
    private init() {
        let folderPath = fileURL.deletingLastPathComponent().path
        
        // Check if the folder exists, and if not, create it
        if !FileManager.default.fileExists(atPath: folderPath) {
            do {
                try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                fatalError("Could not create the directory: \(error)")
            }
        }
        
        // Check if the file exists, and if not, create it
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }
    }
    
    func log(_ message: String) {
        logQueue.async {
             let dateFormatter = DateFormatter()
             dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
             let dateString = dateFormatter.string(from: Date())
             let logEntry = "\(dateString): \(message)\n"
             
             do {
                 let fileHandle = try FileHandle(forWritingTo: self.fileURL)
                 defer {
                     do {
                         try fileHandle.close()
                     } catch {
                         print("Failed to close file: \(error)")
                     }
                 }
                 _ = try fileHandle.seekToEnd()
                 if let data = logEntry.data(using: .utf8) {
                     try fileHandle.write(contentsOf: data)
                 }
             } catch {
                 print("Failed to write to log file: \(error)")
             }
         }
     }
}
