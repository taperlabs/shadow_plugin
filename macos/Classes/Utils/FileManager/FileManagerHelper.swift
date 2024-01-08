import Foundation

extension FileManager.SearchPathDirectory {
    static func from(string: String) -> FileManager.SearchPathDirectory? {
        switch string {
        case "DocumentsDirectory":
            return .documentDirectory
        case "ApplicationSupportDirectory":
            return .applicationSupportDirectory
        // ... other cases as needed
        default:
            return .applicationSupportDirectory
        }
    }
}

// MARK: - File Manager Helper 관리 구조체
struct FileManagerHelper {
    
    static func getURL(for filename: String, in directoryString: String ) -> URL? {
        guard let directory = FileManager.SearchPathDirectory.from(string: directoryString) else {
            print("Invalid directory string: \(directoryString)")
            return nil
        }
        
        guard let directoryURL = FileManager.default.urls(for: directory, in: .userDomainMask).first else {
            print("Unable to find directory URL")
            return nil
        }
        
        // Append the app's bundle identifier to the path
        let appSpecificDirectoryURL = directoryURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.taperlabs.shadow")

        // Create the directory if it doesn't exist
        do {
            try FileManager.default.createDirectory(at: appSpecificDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Failed to create directory: \(error)")
            return nil
        }

        return appSpecificDirectoryURL.appendingPathComponent(filename)
    }
    
    //set or get a file path
//    static func getURL(for filename: String, in directoryString: String ) -> URL? {
//        guard let directory = FileManager.SearchPathDirectory.from(string: directoryString) else {
//            print("Invalid directory string: \(directoryString)")
//            return nil
//        }
//        
//        return FileManager.default.urls(for: directory, in: .userDomainMask).first?.appendingPathComponent(filename)
//    }
    
    //get url and delete file if existing
    static func deleteFileIfExists(at url: URL) {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: url.path) {
            do {
                try fileManager.removeItem(at: url)
            } catch let error {
                print("파일 삭제 실패 했습니다 at URL: \(url), error: \(error)")
            }
        }
    }
}

