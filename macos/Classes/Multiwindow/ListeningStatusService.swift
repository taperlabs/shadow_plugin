import Foundation
import FlutterMacOS


struct SystemAudioListeningError {
    let errorMessage: String
    let errorCode: Int
    let segmentIndex: Int
    
    func toDict() -> [String: Any] {
        return [
            "type": "system_audio_error",
            "error_message": errorMessage,
            "error_code": errorCode,
            "segment_index": segmentIndex
        ]
    }
    
    init(error: Error, segmentIndex: Int) {
        let nsError = error as NSError
        self.errorMessage = nsError.localizedDescription
        self.errorCode = nsError.code
        self.segmentIndex = segmentIndex
    }
}

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
    
    func sendSystemAudioListeningErrorEvent(_ event: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
    }
    
    func sendListeningEvent(_ event: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
    }
}
