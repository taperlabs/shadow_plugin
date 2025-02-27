import Foundation
import FlutterMacOS


// MARK: - Listening Status Window Event
final class ListeningStatusService: NSObject, FlutterStreamHandler {
    static let shared = ListeningStatusService()
    private var eventSink: FlutterEventSink?
    
    private override init() {
        super.init()
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("ListeningStatusService On")
        self.eventSink = events
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("ListeningStatusService Off")
        eventSink = nil
        return nil
    }
    
    func sendListeningEvent(_ event: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
    }
}
