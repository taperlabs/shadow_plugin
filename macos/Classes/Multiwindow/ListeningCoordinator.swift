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

// MARK: - Audio Segment Coordinator
final class ListeningCoordinator {
    static let shared = ListeningCoordinator()
    
    private init() {}
    
    // MARK: - Segment Management
    private var currentSegmentEvents: [Int: AudioSegmentEvent] = [:]
    private var isFinishedListening: Bool = false
    private var isCancelledListening: Bool = false  // Added flag
    
    // MARK: - Event Handling
    func handleMicrophoneSegment(index: Int, fileName: String, isFinished: Bool = false, isCancelled: Bool = false) {
        isFinishedListening = isFinished
        isCancelledListening = isCancelled
        updateSegmentEvent(index: index) { event in
            AudioSegmentEvent(
                microphoneFile: fileName,
                systemAudioFile: event?.systemAudioFile,
                segmentIndex: index,
                isFinishedListening: isFinishedListening,
                isCancelledListening: isCancelledListening  // Added to constructor
            )
        }
    }
    
    func handleSystemAudioSegment(index: Int, fileName: String) {
        updateSegmentEvent(index: index) { event in
            AudioSegmentEvent(
                microphoneFile: event?.microphoneFile,
                systemAudioFile: fileName,
                segmentIndex: index,
                isFinishedListening: isFinishedListening,
                isCancelledListening: isCancelledListening  // Added to constructor
            )
        }
    }
    
    private func updateSegmentEvent(index: Int, updateHandler: (AudioSegmentEvent?) -> AudioSegmentEvent) {
        let currentEvent = currentSegmentEvents[index]
        let updatedEvent = updateHandler(currentEvent)
        currentSegmentEvents[index] = updatedEvent
        
        // If we have both audio files, send the event
        if updatedEvent.microphoneFile != nil && updatedEvent.systemAudioFile != nil {
            ListeningStatusService.shared.sendListeningEvent(updatedEvent.toDictionary())
            currentSegmentEvents.removeValue(forKey: index)
        }
    }
}
