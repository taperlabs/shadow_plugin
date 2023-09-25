import Foundation

// MARK: - File Manager Helper 관리 구조체
struct FileManagerHelper {
    
    //set or get a file path
    static func getURL(for filename: String) -> URL? {
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.appendingPathComponent(filename)
    }
    
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

