import Foundation
import ScreenCaptureKit

// MARK: - Models

/// 윈도우 정보를 Flutter로 전달하기 위한 구조체
struct WindowInfo: Codable, Identifiable {
    var id: CGWindowID { windowID }

    let windowID: CGWindowID
    let title: String
    let owningApplicationName: String
    let windowLayer: Int?
    let bundleID: String?
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let isOnScreen: Bool
    let isActive: Bool

    /// Flutter 메서드 채널 전송용 딕셔너리 변환
    func asDictionary() -> [String: Any] {
        [
            "windowID": Int(windowID),
            "title": title,
            "owningApplicationName": owningApplicationName,
            "windowLayer": windowLayer as Any,
            "bundleID": bundleID as Any,
            "x": Double(x),
            "y": Double(y),
            "width": Double(width),
            "height": Double(height),
            "isOnScreen": isOnScreen,
            "isActive": isActive
        ]
    }
}

/// 디스플레이 정보를 Flutter로 전달하기 위한 구조체
struct DisplayInfo: Codable {
    let displayID: Int
    let localizedName: String
    let frame: CGRect
    let width: Int
    let height: Int
    
    /// Flutter 메서드 채널 전송용 딕셔너리 변환
    func asDictionary() -> [String: Any] {
        [
            "displayID": displayID,
            "localizedName": localizedName,
            "x": Double(frame.origin.x),
            "y": Double(frame.origin.y),
            "width": width,
            "height": height
        ]
    }
}

// MARK: - ScreenCaptureKit Extensions

extension SCWindow {
    /// SCWindow를 WindowInfo로 변환
    func toWindowInfo() -> WindowInfo {
        let app = owningApplication
        let f = frame

        return WindowInfo(
            windowID: windowID,
            title: title ?? "",
            owningApplicationName: app?.applicationName ?? "Unknown App",
            windowLayer: windowLayer,
            bundleID: app?.bundleIdentifier,
            x: f.origin.x,
            y: f.origin.y,
            width: f.size.width,
            height: f.size.height,
            isOnScreen: isOnScreen,
            isActive: isActive
        )
    }
}

extension SCDisplay {
    /// SCDisplay를 DisplayInfo로 변환 (NSScreen과 매칭하여 localizedName 포함)
    func toDisplayInfo() -> DisplayInfo {
        let localizedName = NSScreen.screens.first { screen in
            screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID == self.displayID
        }?.localizedName ?? "Unknown Display"

        return DisplayInfo(
            displayID: Int(self.displayID),
            localizedName: localizedName,
            frame: self.frame,
            width: self.width,
            height: self.height
        )
    }
}

// MARK: - Configuration

private enum FilterConfiguration {
    // 윈도우 크기 제한
    static let minWindowSize: CGFloat = 50
    static let maxWindowSize: CGFloat = 16000
    static let maxAbsoluteOrigin: CGFloat = 20000

    // 윈도우 레이어 범위 (일반 앱 윈도우)
    static let validWindowLayerRange = 0...20

    // 제외할 시스템 앱 번들 ID
    static let excludedBundleIDs: Set<String> = [
        "com.apple.dock",
        "com.apple.notificationcenterui",
        "com.apple.Spotlight",
        "com.apple.wallpaper.agent",
        "com.apple.WindowManager",
        "com.apple.systemuiserver"
    ]
}

// MARK: - Service

/// ScreenCaptureKit을 사용하여 캡처 가능한 윈도우와 디스플레이 목록을 제공하는 서비스
final class ScreenshotCaptureService: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var displays: [DisplayInfo] = []
    @Published var isLoading = false

    /// 번들 ID로 앱 아이콘 가져오기
    /// - Parameters:
    ///   - bundleID: 앱 번들 식별자
    ///   - size: 아이콘 크기 (기본값: 12pt)
    /// - Returns: NSImage 아이콘 또는 nil
    static func getAppIcon(for bundleID: String?, size: CGFloat = 12) -> NSImage? {
        guard
            let bundleID = bundleID,
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return nil }

        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        return icon
    }
}

// MARK: - Public API - Display Discovery

extension ScreenshotCaptureService {
    /// 사용 가능한 모든 디스플레이 목록 가져오기
    /// - 연결된 모든 디스플레이 정보를 업데이트하고 로깅
    func getAvailableDisplays() async {
        isLoading = true
        defer { isLoading = false }

        guard let content = try? await SCShareableContent.current else {
            logError("SCShareableContent.current 불러오기 실패")
            return
        }

        let displayInfos = content.displays.map { $0.toDisplayInfo() }
        displays = displayInfos

        logDisplayCandidates(displayInfos)
        logNSScreens()
    }
}

// MARK: - Public API - Window Discovery

extension ScreenshotCaptureService {
    /// 캡처 가능한 윈도우 목록 가져오기
    /// - 필터링 규칙을 적용하여 유효한 윈도우만 반환
    func getAvailableTargets() async {
        isLoading = true
        defer { isLoading = false }

        guard let content = try? await SCShareableContent.current else {
            logError("SCShareableContent.current 불러오기 실패")
            return
        }

        let filteredWindows = content.windows.filter { shouldIncludeWindow($0) }
        let windowInfos = filteredWindows.map { $0.toWindowInfo() }

        windows = windowInfos
        logWindowCandidates(windowInfos, originalWindows: filteredWindows)
    }
}

// MARK: - Window Filtering Logic

private extension ScreenshotCaptureService {
    /// 윈도우가 캡처 대상에 포함되어야 하는지 판단
    func shouldIncludeWindow(_ window: SCWindow) -> Bool {
        let bundleID = window.owningApplication?.bundleIdentifier ?? ""

        return hasValidTitle(window) &&
               isVisibleOnScreen(window) &&
               hasValidBundleID(bundleID) &&
               isNotSystemApp(bundleID) &&
               hasValidWindowLayer(window) &&
               hasValidBounds(window.frame)
    }

    /// 윈도우 제목이 유효한지 확인
    func hasValidTitle(_ window: SCWindow) -> Bool {
        let title = window.title ?? ""
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 윈도우가 화면에 표시 중인지 확인
    func isVisibleOnScreen(_ window: SCWindow) -> Bool {
        window.isOnScreen
    }

    /// 번들 ID가 유효한지 확인 (Desktop 등 제외)
    func hasValidBundleID(_ bundleID: String) -> Bool {
        !bundleID.isEmpty
    }

    /// 시스템 앱이 아닌지 확인
    func isNotSystemApp(_ bundleID: String) -> Bool {
        !FilterConfiguration.excludedBundleIDs.contains(bundleID)
    }

    /// 윈도우 레이어가 정상 범위인지 확인
    func hasValidWindowLayer(_ window: SCWindow) -> Bool {
        FilterConfiguration.validWindowLayerRange.contains(window.windowLayer)
    }

    /// 윈도우 크기와 위치가 유효한지 확인
    func hasValidBounds(_ frame: CGRect) -> Bool {
        hasValidSize(frame) && hasValidPosition(frame)
    }

    /// 윈도우 크기가 유효 범위 내인지 확인
    private func hasValidSize(_ frame: CGRect) -> Bool {
        let min = FilterConfiguration.minWindowSize
        let max = FilterConfiguration.maxWindowSize

        return frame.width >= min && frame.height >= min &&
               frame.width <= max && frame.height <= max
    }

    /// 윈도우 위치가 유효 범위 내인지 확인
    private func hasValidPosition(_ frame: CGRect) -> Bool {
        let maxOrigin = FilterConfiguration.maxAbsoluteOrigin
        return abs(frame.origin.x) <= maxOrigin && abs(frame.origin.y) <= maxOrigin
    }
}

// MARK: - Logging

private extension ScreenshotCaptureService {
    /// 에러 메시지 로깅
    func logError(_ message: String) {
        print("⚠️ \(message)")
    }

    /// 윈도우 후보 목록 로깅
    func logWindowCandidates(_ windowInfos: [WindowInfo], originalWindows: [SCWindow]) {
        print("🪟 Capturable Window candidates (\(windowInfos.count))")

        for (idx, info) in windowInfos.enumerated() {
            let window = originalWindows[idx]
            let iconExists = Self.getAppIcon(for: window.owningApplication?.bundleIdentifier) != nil

            print(
                """
                [\(info.windowID)] \(info.owningApplicationName) — "\(info.title)"
                • bundleID: \(info.bundleID ?? "nil")
                • layer: \(info.windowLayer ?? -1)
                • frame: x:\(Int(info.x)) y:\(Int(info.y)) w:\(Int(info.width)) h:\(Int(info.height))
                • onScreen:\(info.isOnScreen) active:\(info.isActive)
                • icon: \(iconExists ? "✅" : "—")
                """
            )
        }
    }

    /// 디스플레이 후보 목록 로깅
    func logDisplayCandidates(_ displayInfos: [DisplayInfo]) {
        print("🖥️ Display candidates (\(displayInfos.count))")

        for info in displayInfos {
            print(
                """
                [Display \(info.displayID)] \(info.localizedName)
                • frame: x:\(Int(info.frame.origin.x)) y:\(Int(info.frame.origin.y)) w:\(info.width) h:\(info.height)
                """
            )
        }
    }

    /// NSScreen 목록 로깅 (디버깅용)
    func logNSScreens() {
        print("\n🖥️ NSScreen.screens:")
        NSScreen.screens.forEach { screen in
            print("• \(screen.localizedName)")
        }
    }
}
