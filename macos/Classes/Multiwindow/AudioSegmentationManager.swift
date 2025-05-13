import Foundation
import QuartzCore

// Protocol that audio services must conform to
protocol AudioSegmentService: AnyObject {
    func prepareNextSegment()
    func rotateSegment()
}


class AudioSegmentCoordinator: ObservableObject {
    // Singleton instance
    static let shared = AudioSegmentCoordinator()
    
    // Services that need coordination
    private weak var systemAudioService: AudioSegmentService?
    private weak var microphoneService: AudioSegmentService?
    
    // Timing configuration
    private let segmentDuration: TimeInterval = 60.0
    private let prepareBeforeRotation: TimeInterval = 3.0
    
    // Timing state
    private var isRunning = false
    private var segmentStartTime: CFTimeInterval = 0
    private var currentSegmentIndex: Int = 0
    
    // High-precision timer for coordination
    private var coordinationTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.audiocoordinator.timer", qos: .userInitiated)
    
    // Published properties for UI or debugging
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var nextRotationTime: TimeInterval = 60.0
    
    private var hasPreparedCurrentSegment = false
    private var hasRotatedCurrentSegment = false
    
    private init() {}
    
    // Register services with the coordinator
    func registerSystemAudioService(_ service: AudioSegmentService) {
        systemAudioService = service
        print("✅ System Audio Service registered with coordinator")
    }
    
    func registerMicrophoneService(_ service: AudioSegmentService) {
        microphoneService = service
        print("✅ Microphone Service registered with coordinator")
        startCoordination()
    }
    
    // Start coordinated recording
    func startCoordination() {
        guard !isRunning else {
            print("⚠️ Coordination already running, ignoring start request")
            return
        }
        
        isRunning = true
        currentSegmentIndex = 0
        segmentStartTime = CACurrentMediaTime()
        
        print("🎬 Starting audio segment coordination at time: \(segmentStartTime)")
        
        // Start high-precision timer
        startCoordinationTimer()
    }
    
    // Stop coordinated recording
    func stopCoordination() {
        guard isRunning else { return }
        
        isRunning = false
        coordinationTimer?.cancel()
        coordinationTimer = nil
        
        systemAudioService = nil
        microphoneService = nil
        
        print("🛑 Stopped audio segment coordination")
    }
    
    private func startCoordinationTimer() {
        // Cancel any existing timer
        coordinationTimer?.cancel()
        
        // Create new timer with high precision
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(10), leeway: .nanoseconds(0))
        
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isRunning else { return }
            
            let currentTime = CACurrentMediaTime()
            let elapsedTime = currentTime - self.segmentStartTime
            
            // 경과 시간을 이용해 현재 세그먼트 번호 계산
            let calculatedSegmentNumber = Int(elapsedTime / self.segmentDuration)
            
            // prepare 이벤트 처리 - 세그먼트가 바뀔 때 플래그 리셋
            let timeUntilNextRotation = self.segmentDuration - elapsedTime.truncatingRemainder(dividingBy: self.segmentDuration)
            if timeUntilNextRotation <= self.prepareBeforeRotation && timeUntilNextRotation > self.prepareBeforeRotation - 0.1 {
                // 현재 세그먼트에 대해 아직 prepare를 실행하지 않았으면 실행
                if !self.hasPreparedCurrentSegment {
                    print("⏱ Coordinator triggering prepare at elapsed time: \(elapsedTime)")
                    self.notifyServicesToPrepare()
                    self.hasPreparedCurrentSegment = true
                }
            }
            
            // rotate 이벤트 처리
            if elapsedTime.truncatingRemainder(dividingBy: self.segmentDuration) < 0.02 && elapsedTime > 0.1 {
                // 현재 세그먼트에 대해 아직 rotate를 실행하지 않았으면 실행
                if !self.hasRotatedCurrentSegment {
                    print("🔄 Coordinator triggering rotation at elapsed time: \(elapsedTime)")
                    self.notifyServicesToRotate()
                    self.currentSegmentIndex += 1
                    
                    // 로테이션 후에는 플래그 리셋
                    segmentStartTime = CACurrentMediaTime()
                    self.hasRotatedCurrentSegment = false
                    self.hasPreparedCurrentSegment = false
                }
            }
        }
        
        timer.resume()
        coordinationTimer = timer
    }
    
    private func notifyServicesToPrepare() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("📝 Coordinator notifying services to prepare segment \(self.currentSegmentIndex + 1)")
            self.systemAudioService?.prepareNextSegment()
            self.microphoneService?.prepareNextSegment()
        }
    }
    
    private func notifyServicesToRotate() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("🔄 Coordinator notifying services to rotate to segment \(self.currentSegmentIndex)")
            self.systemAudioService?.rotateSegment()
            self.microphoneService?.rotateSegment()
        }
    }
    
    // For debugging
    func getCurrentStatus() -> String {
        return """
        Running: \(isRunning)
        Current Segment: \(currentSegmentIndex)
        Elapsed Time: \(elapsedTime)
        Next Rotation In: \(nextRotationTime) seconds
        """
    }
}
