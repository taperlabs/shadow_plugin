import Foundation

// MARK: - File Manager Helper 관리 구조체
struct FileManagerHelper {
    
    // 마이크 녹음 음성 파일 저장 위치 URL 셋업
    static func getURL(for filename: String) -> URL? {
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.appendingPathComponent(filename)
    }
    
    //URL을 인자로 받아 해당 URL에 존재하는 파일 삭제
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

