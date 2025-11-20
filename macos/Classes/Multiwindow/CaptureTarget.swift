import Foundation

/// 캡처 대상을 나타내는 열거형 (디스플레이 또는 윈도우)
enum CaptureTarget: Identifiable {
    case autoCapture(WindowInfo?)
    case noCapture
    case display(DisplayInfo)
    case window(WindowInfo)

    /// 고유 식별자 (Identifiable 프로토콜)
    var id: String {
        switch self {
        case .autoCapture:
            return "auto_capture"
        case .noCapture:
            return "no_capture"
        case .display(let info):
            return "display_\(info.displayID)"
        case .window(let info):
            return "window_\(info.windowID)"
        }
    }

    /// 표시 이름
    var name: String {
        switch self {
        case .autoCapture(let windowInfo):
            if let window = windowInfo {
                return "Meeting Screen (\(window.title))"
            } else {
                return "Meeting Screen (Auto)"
            }
        case .noCapture:
            return "No Screenshots"
        case .display(let info):
            return info.localizedName
        case .window(let info):
            return "\(info.owningApplicationName) — \(info.title)"
        }
    }

    /// 번들 ID (윈도우만 해당, 디스플레이는 nil)
    var bundleID: String? {
        switch self {
        case .autoCapture:
            return nil
        case .noCapture:
            return nil
        case .display:
            return nil
        case .window(let info):
            return info.bundleID
        }
    }

    /// No capture 타입인지 확인
    var isNoCapture: Bool {
        if case .noCapture = self {
            return true
        }
        return false
    }

    /// 디스플레이 타입인지 확인
    var isDisplay: Bool {
        if case .display = self {
            return true
        }
        return false
    }

    /// 윈도우 타입인지 확인
    var isWindow: Bool {
        if case .window = self {
            return true
        }
        return false
    }

    /// Auto capture 타입인지 확인
    var isAutoCapture: Bool {
        if case .autoCapture = self {
            return true
        }
        return false
    }

    /// Flutter 메서드 채널 전송용 딕셔너리 변환
    /// - Returns: WindowInfo/DisplayInfo의 전체 정보를 포함한 딕셔너리, noCapture와 autoCapture는 타입만 반환
    func asDictionary() -> [String: Any] {
        switch self {
        case .autoCapture(let windowInfo):
            if let window = windowInfo {
                var dict = window.asDictionary()
                dict["type"] = "autoCapture"
                return dict
            } else {
                return ["type": "autoCapture"]
            }
        case .noCapture:
            return ["type": "noCapture"]
        case .display(let info):
            return info.asDictionary()
        case .window(let info):
            return info.asDictionary()
        }
    }
}
