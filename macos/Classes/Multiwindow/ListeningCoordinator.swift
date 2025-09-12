import Foundation

// MARK: - Audio Segment Event
struct AudioSegmentEvent {
    let microphoneFile: String?
    let systemAudioFile: String?
    let segmentIndex: Int
    let isFinishedListening: Bool
    let isCancelledListening: Bool  // Added flag
    
    func toDictionary() -> [String: Any] {
        return [
            "microphone_segment": microphoneFile ?? "",
            "system_audio_segment": systemAudioFile ?? "",
            "segment_index": segmentIndex,
            "isFinishedListening": isFinishedListening,
            "isCancelledListening": isCancelledListening  // Added to dictionary
        ]
    }
}

final class ListeningCoordinator {
    static let shared = ListeningCoordinator()
    
    private init() {}
    
    // MARK: - Thread Safety
    private let queue = DispatchQueue(label: "com.yourapp.listeningCoordinator", attributes: .concurrent)
    
    // MARK: - Segment Management
    private var currentSegmentEvents: [Int: AudioSegmentEvent] = [:]
//    private var isFinishedListening: Bool = false
//    private var isCancelledListening: Bool = false
    
    // MARK: - Event Handling
    func handleMicrophoneSegment(index: Int, fileName: String, isFinished: Bool = false, isCancelled: Bool = false) {
        print("🎙️ \(index) -- \(fileName) got called for Mic Audio")
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
//            self.isFinishedListening = isFinished
//            self.isCancelledListening = isCancelled
            self.updateSegmentEvent(index: index) { event in
                AudioSegmentEvent(
                    microphoneFile: fileName,
                    systemAudioFile: event?.systemAudioFile,
                    segmentIndex: index,
                    isFinishedListening: isFinished,
                    isCancelledListening: isCancelled
                )
            }
        }
    }
    
    func handleSystemAudioSegment(index: Int, fileName: String) {
        print("🖥️ \(index) -- \(fileName) got called for System Audio")
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            self.updateSegmentEvent(index: index) { event in
                AudioSegmentEvent(
                    microphoneFile: event?.microphoneFile,
                    systemAudioFile: fileName,
                    segmentIndex: index,
                    isFinishedListening: event?.isFinishedListening ?? false,
                    isCancelledListening: event?.isCancelledListening ?? false
                )
            }
        }
    }
    
    private func updateSegmentEvent(index: Int, updateHandler: (AudioSegmentEvent?) -> AudioSegmentEvent) {
        // This should only be called from within the queue
        let currentEvent = currentSegmentEvents[index]
        let updatedEvent = updateHandler(currentEvent)
        currentSegmentEvents[index] = updatedEvent
        
        print("🗂️ Update Segment Event Called ")
        
        // If we have both audio files, send the event
        if updatedEvent.microphoneFile != nil && updatedEvent.systemAudioFile != nil {
            ListeningStatusService.shared.sendListeningEvent(updatedEvent.toDictionary())
            currentSegmentEvents.removeValue(forKey: index)
        }
    }
}

// MARK: - Audio Segment Coordinator
//final class ListeningCoordinator {
//    static let shared = ListeningCoordinator()
//
//    private init() {}
//
//    // MARK: - Segment Management
//    private var currentSegmentEvents: [Int: AudioSegmentEvent] = [:]
//    private var isFinishedListening: Bool = false
//    private var isCancelledListening: Bool = false  // Added flag
//
//    // MARK: - Event Handling
//    func handleMicrophoneSegment(index: Int, fileName: String, isFinished: Bool = false, isCancelled: Bool = false) {
//        print("🎙️ \(index) -- \(fileName) got called for Mic Audio")
//
//        isFinishedListening = isFinished
//        isCancelledListening = isCancelled
//        updateSegmentEvent(index: index) { event in
//            AudioSegmentEvent(
//                microphoneFile: fileName,
//                systemAudioFile: event?.systemAudioFile,
//                segmentIndex: index,
//                isFinishedListening: isFinishedListening,
//                isCancelledListening: isCancelledListening  // Added to constructor
//            )
//        }
//    }
//
//    func handleSystemAudioSegment(index: Int, fileName: String) {
//        print("🖥️ \(index) -- \(fileName) got called for System Audio")
//
//        updateSegmentEvent(index: index) { event in
//            AudioSegmentEvent(
//                microphoneFile: event?.microphoneFile,
//                systemAudioFile: fileName,
//                segmentIndex: index,
//                isFinishedListening: isFinishedListening,
//                isCancelledListening: isCancelledListening  // Added to constructor
//            )
//        }
//    }
//
//    private func updateSegmentEvent(index: Int, updateHandler: (AudioSegmentEvent?) -> AudioSegmentEvent) {
//        let currentEvent = currentSegmentEvents[index]
//        let updatedEvent = updateHandler(currentEvent)
//        currentSegmentEvents[index] = updatedEvent
//
//        print("🗂️ Update Segment Event Called ")
//
//        // If we have both audio files, send the event
//        if updatedEvent.microphoneFile != nil && updatedEvent.systemAudioFile != nil {
//            ListeningStatusService.shared.sendListeningEvent(updatedEvent.toDictionary())
//            currentSegmentEvents.removeValue(forKey: index)
//        }
//    }
//}
