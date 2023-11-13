////import Foundation
////import ScreenCaptureKit
////import FlutterMacOS
////
////
////final class NudgeHelper:  NSObject, FlutterStreamHandler {
////    private var eventSink: FlutterEventSink?
////    private var timer: Timer?
////    private var windows: [SCWindow]?
////    private var apps: [SCRunningApplication]?
////    private var displays: [SCDisplay]?
////
////    var isZoomMeetingIn = false
////    var isGoogleMeetIn = false
////
////    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
////        print("hey")
////    }
////
////    func onCancel(withArguments arguments: Any?) -> FlutterError? {
////        print("Hi")
////    }
////
//func startNudging() -> Void {
//    let availableContent = SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: false) { [weak self] content, error in
//        guard let content = content else { return }
//        self?.windows = content.windows
//        self?.apps = content.applications
//        self?.display = content.displays
//
//        //            print(self?.windows)
//    }
//}
////
////
//private func detectZoomMeetingIn() -> Void {
//    guard let unWrappedWindows = self.windows else { return }
//    let titles = unWrappedWindows.compactMap { $0.title }
//
//    for title in titles {
//        print(title)
//    }
//
//    let owningApps = unWrappedWindows.compactMap { $0.owningApplication }
//    let isZoomRunning = titles.contains("Zoom Meeting")
//    self.isZoomRunning = isZoomRunning
//
//}
////
////    private func detectGoogleMeetingIn() -> Void {
////
////    }
////
////    private func getAllRunningApps() -> Void {
////
////    }
////
////
////}
////
////extension NudgeHelper {
////    //TODO:
////}
////
////extension NudgeHelper {
////    //TODO:
////}
