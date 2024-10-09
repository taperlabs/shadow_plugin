import Foundation
import FlutterMacOS
import Combine

enum WindowState: String, Codable {
    case closed
    case preListening
    case listening
}

struct WindowStatus {
    let windowState: WindowState
    let isRecording: Bool
    let windowCloseType: WindowCloseType?
    
    init(windowState: WindowState, isRecording: Bool, windowCloseType: WindowCloseType? = nil) {
        self.windowState = windowState
        self.isRecording = isRecording
        self.windowCloseType = windowCloseType
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "windowState": windowState.rawValue,
            "isRecording": isRecording
        ]
        
        if let closeType = windowCloseType {
            dict["windowCloseType"] = closeType.rawValue
        }
        
        return dict
    }
}

final class MultiWindowStatusService: NSObject, FlutterStreamHandler {
    static let shared = MultiWindowStatusService()
    private var eventSink: FlutterEventSink?
    static var isConnected: Bool {
        return shared.eventSink != nil
    }
    
    private override init() {
        super.init()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("MultiWindowStatus Service OnListen!!")
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("MultiWindowStatus Service onCancel!!")
        eventSink = nil
        return nil
    }
    
    func sendEvent(_ event: Any) {
        eventSink?(event)
    }
    
    func sendWindowStatus(_ status: WindowStatus) {
        sendEvent(status.toDictionary())
    }
    
    
}
