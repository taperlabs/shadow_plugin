import Foundation
import AVFoundation
import Combine
import QuartzCore

final class MicrophoneService2: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    // 다음 세그먼트를 위한 미리 준비된 recorder
    private var nextAudioRecorder: AVAudioRecorder?
    private var noiseTimer: Timer?
    private var timeTimer: Timer?
    private var segmentTimer: Timer?
    private var startTime: TimeInterval?
    private var segmentStartTime: TimeInterval?
    private var isFinishedListening: Bool = false
    private var isCancelled: Bool = false
    
    // 세그먼트 인덱스 관리
    private var segmentIndex = 0
    private var nextSegmentIndex = 1
    private var baseFileName: String = ""
    private var micSegmentFileName: String = ""
    private var nextMicSegmentFileName: String = ""
    private let segmentDuration: TimeInterval = 10.0
    // 다음 세그먼트 미리 준비 시점 (세그먼트 종료 몇 초 전)
    private let prepareNextSegmentBeforeSeconds: TimeInterval = 3.0
    
    // Create a dedicated serial queue for time updates
    private let timeQueue = DispatchQueue(label: "com.app.microphoneService.timeQueue")
    
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var noiseLevel: Float = 0.0
    
    private let sampleRate: Double = 16_000
    private var segmentTimerDS: DispatchSourceTimer?
    private let segmentTimerDSQueue = DispatchQueue(label: "com.yourapp.segmentTimerQueue")
    
    /// 시작할 때 base 파일 이름을 받고 첫 번째 세그먼트 녹음을 시작
    func startRecording(name: String) {
        // 마이크 권한 요청
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            guard let self = self else { return }
            if granted {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.baseFileName = name
                    self.segmentIndex = 0
                    self.startNewSegment()
                    self.startTimers()
                    self.isRecording = true
                    
                    AudioSegmentCoordinator.shared.registerMicrophoneService(self)
                }
            } else {
                print("Microphone permission not granted")
            }
        }
    }
    
    /// 세그먼트 녹음 시작 (1분 단위)
    private func startNewSegment() {
        // 이미 준비된 다음 세그먼트 recorder가 있는 경우
        if let nextRecorder = nextAudioRecorder, !micSegmentFileName.isEmpty {
            // 준비된 recorder를 현재 recorder로 설정
            audioRecorder = nextRecorder
            audioRecorder?.delegate = self  // 현재 recorder가 될 때 delegate 설정
            nextAudioRecorder = nil
            
            // 미리 준비된 파일명으로 설정
            micSegmentFileName = nextMicSegmentFileName
            nextMicSegmentFileName = ""
            
            // 녹음 시작

            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            
//            audioRecorder?.record(atTime: audioRecorder!.deviceCurrentTime + 0.5)
            
            // 세그먼트 시작 시간 기록
            segmentStartTime = CACurrentMediaTime()
            
            // 세그먼트 타이머 시작
//            startSegmentTimer()
            
            print("🎙️ Started pre-prepared recording segment \(segmentIndex) with file: \(micSegmentFileName)")
        } else {
            // 미리 준비된 recorder가 없는 경우, 새로 생성
            let baseFile = baseFileName.replacingOccurrences(of: ".m4a", with: "")
            let segmentMicAudio = "\(baseFile)-\(segmentIndex).m4a"
            micSegmentFileName = segmentMicAudio
            
            print("self.micSegmentFileName -- \(self.micSegmentFileName)")
            
            // 파일 저장 경로 설정 (예: ApplicationSupportDirectory)
            guard let audioFileURL = FileManagerHelper.getURL(for: segmentMicAudio, in: "ApplicationSupportDirectory") else {
                print("Failed to get file URL for segment \(segmentMicAudio)")
                return
            }
            
            let settings = AudioSetting.setAudioConfiguration(
                format: .mpeg4AAC,
                channels: .mono,
                sampleRate: .rate16K
            )
            
            do {
                audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
                audioRecorder?.delegate = self
                audioRecorder?.isMeteringEnabled = true
                audioRecorder?.prepareToRecord()
                // 무한 녹음 시작 (segmentDuration으로 제한하지 않음)
                audioRecorder?.record()
                
                // 세그먼트 시작 시간 기록
                segmentStartTime = CACurrentMediaTime()
                
                // 세그먼트 타이머 시작
//                startSegmentTimer()
                
                print("Started recording segment \(segmentIndex) at \(audioFileURL.absoluteString)")
            } catch {
                print("Failed to initialize AVAudioRecorder: \(error.localizedDescription)")
            }
        }
        
        // 다음 세그먼트를 위한 인덱스 설정
        nextSegmentIndex = segmentIndex + 1
    }
    
    /// 다음 세그먼트 미리 준비
    private func prepareNextSegmentRecorder() {
        // 베이스 파일명을 이용해 다음 세그먼트 파일명 준비
        let baseFile = baseFileName.replacingOccurrences(of: ".m4a", with: "")
        let nextSegmentMicAudio = "\(baseFile)-\(nextSegmentIndex).m4a"
        nextMicSegmentFileName = nextSegmentMicAudio
        
        // 파일 저장 경로 설정
        guard let nextAudioFileURL = FileManagerHelper.getURL(for: nextSegmentMicAudio, in: "ApplicationSupportDirectory") else {
            print("Failed to get file URL for next segment \(nextSegmentMicAudio)")
            return
        }
        
        let settings = AudioSetting.setAudioConfiguration(
            format: .mpeg4AAC,
            channels: .mono,
            sampleRate: .rate16K
        )
        
        do {
            nextAudioRecorder = try AVAudioRecorder(url: nextAudioFileURL, settings: settings)
            // 다음 세그먼트 recorder에는 delegate를 설정하지 않음
            // 실제 현재 recorder가 될 때 delegate를 설정
            nextAudioRecorder?.isMeteringEnabled = true
            nextAudioRecorder?.prepareToRecord()
            
            print("🎙️ Prepared next segment \(nextSegmentIndex) at \(nextAudioFileURL.absoluteString)")
        } catch {
            print("Failed to initialize next AVAudioRecorder: \(error.localizedDescription)")
        }
    }
    
    private func startSegmentTimer() {
        // Cancel any existing timer
        segmentTimerDS?.cancel()
        segmentTimer = nil

        // Create a new DispatchSourceTimer
        let timer = DispatchSource.makeTimerSource(queue: segmentTimerDSQueue)
        // Fire every 0.01s (10ms), leeway 1ms for power efficiency
        timer.schedule(deadline: .now(),
                       repeating: .milliseconds(10),
                       leeway: .nanoseconds(0))

        timer.setEventHandler { [weak self] in
            guard let self = self,
                  let segmentStartTime = self.segmentStartTime,
                  self.isRecording,
                  !self.isFinishedListening,
                  !self.isCancelled else {
                return
            }

            let currentTime = CACurrentMediaTime()
            let elapsedTime = currentTime - segmentStartTime
            
            print("🔥 elapsedTime: currentTime = \(elapsedTime)")

            // Prepare next segment slightly before current ends
            if elapsedTime >= (self.segmentDuration - self.prepareNextSegmentBeforeSeconds),
               self.nextAudioRecorder == nil {
                self.prepareNextSegmentRecorder()
            }

            // Switch segments when duration reached
            if elapsedTime >= self.segmentDuration {
                self.switchToNextSegment()
            }
        }

        // Start the timer
        timer.resume()
        segmentTimerDS = timer
    }
    
    // 세그먼트 타이머 시작 (60초마다 세그먼트 변경)
//    private func startSegmentTimer() {
//        segmentTimer?.invalidate()
//        
//        // 0.1초마다 현재 세그먼트 녹음 시간을 체크
//        segmentTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
//            guard let self = self,
//                  let segmentStartTime = self.segmentStartTime,
//                  self.isRecording,
//                  !self.isFinishedListening,
//                  !self.isCancelled else { return }
//            
//            let currentTime = CACurrentMediaTime()
//            let elapsedTime = currentTime - segmentStartTime
//            
////            print("🔥 elapsedTime: currentTime = \(elapsedTime)")
//            
//            // 세그먼트 종료 몇 초 전에 다음 세그먼트 미리 준비
//            if elapsedTime >= (self.segmentDuration - self.prepareNextSegmentBeforeSeconds) && self.nextAudioRecorder == nil {
//                self.prepareNextSegment()
//            }
//            
//            // 세그먼트 지속 시간이 지나면 다음 세그먼트로 전환
//            if elapsedTime >= self.segmentDuration {
//                self.switchToNextSegment()
//            }
//        }
//    }
    
    // 다음 세그먼트로 전환
    private func switchToNextSegment() {
        guard let recorder = audioRecorder else { return }
        
        // 현재 녹음 중지하기 전에 참조 보관
        let oldRecorder = recorder
        
        // 현재 녹음기에서 delegate 제거 (더 이상 이벤트를 받지 않도록)
        oldRecorder.delegate = nil
        
        // 현재 녹음 중지
        oldRecorder.stop()
        
        // 세그먼트 타이머 중지
        segmentTimer?.invalidate()
        segmentTimer = nil
        
        print("Segment \(segmentIndex) completed by timer at \(CACurrentMediaTime())")
        
        // 현재 세그먼트 처리를 직접 수행 (delegate에 의존하지 않음)
        if !isCancelled && !isFinishedListening {
            ListeningCoordinator.shared.handleMicrophoneSegment(index: segmentIndex, fileName: micSegmentFileName)
            segmentIndex += 1
            
            // 전체 녹음이 중단되지 않았다면 다음 세그먼트를 시작합니다.
            if isRecording {
                startNewSegment()
            }
        } else if isCancelled {
            ListeningCoordinator.shared.handleMicrophoneSegment(index: segmentIndex, fileName: micSegmentFileName, isFinished: true, isCancelled: true)
        } else if isFinishedListening {
            ListeningCoordinator.shared.handleMicrophoneSegment(index: segmentIndex, fileName: micSegmentFileName, isFinished: true)
        }
    }
    
    /// 녹음 중지 (전체 녹음 종료)
    func stopRecording(isCancelled: Bool = false) {
        print("stopRecording with isCancelled = \(isCancelled)")
        
        segmentTimerDS?.cancel()
        AudioSegmentCoordinator.shared.stopCoordination()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isRecording = false
            self.isFinishedListening = true
            self.isCancelled = isCancelled
            self.stopTimers()
            
            // 현재 녹음기 참조를 복사
            let currentRecorder = self.audioRecorder
            
            // 녹음기의 delegate를 nil로 설정하여 더 이상 이벤트를 받지 않도록 함
            currentRecorder?.delegate = nil
            
            // 마지막 세그먼트 처리를 직접 수행
            if let recorder = currentRecorder, recorder.isRecording {
                recorder.stop()
                
                // delegate 메서드를 대신해서 직접 처리
                ListeningCoordinator.shared.handleMicrophoneSegment(
                    index: segmentIndex,
                    fileName: micSegmentFileName,
                    isFinished: true,
                    isCancelled: isCancelled
                )
            }
            
            // 모든 상태 및 참조 초기화
            self.segmentIndex = 0
            self.nextSegmentIndex = 0
            self.baseFileName = ""
            self.nextMicSegmentFileName = ""
            self.audioRecorder = nil
            self.nextAudioRecorder = nil
        }
    }
    
    // 타이머 시작 (Noise level 및 경과 시간 업데이트)
    private func startTimers() {
        timeQueue.sync {
            currentTime = 0
            startTime = CACurrentMediaTime() // Date().timeIntervalSinceReferenceDate 대신 CACurrentMediaTime() 사용
        }
        
        noiseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            let averagePower = recorder.averagePower(forChannel: 0)
            self.noiseLevel = self.normalizedPowerLevel(fromDecibels: averagePower)
        }
        
        timeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.timeQueue.sync {
                guard let startTime = self.startTime else { return }
                let currentSystemTime = CACurrentMediaTime() // Date().timeIntervalSinceReferenceDate 대신 CACurrentMediaTime() 사용
                DispatchQueue.main.async {
                    self.currentTime = floor(currentSystemTime - startTime)
                }
            }
        }
    }
    
    private func stopTimers() {
        noiseTimer?.invalidate()
        noiseTimer = nil
        timeTimer?.invalidate()
        timeTimer = nil
        segmentTimer?.invalidate()
        segmentTimer = nil
        timeQueue.sync {
            startTime = nil
            segmentStartTime = nil
            nextAudioRecorder = nil  // 다음 세그먼트용 recorder도 정리
            DispatchQueue.main.async {
                self.currentTime = 0
            }
        }
    }
    
    private func normalizedPowerLevel(fromDecibels decibels: Float) -> Float {
        let minDecibels: Float = -50.0
        let maxDecibels: Float = 10.0
        
        if decibels < minDecibels {
            return 0.0
        } else if decibels >= maxDecibels {
            return 0.95
        } else {
            let normalized = (decibels - minDecibels) / (maxDecibels - minDecibels)
            return sqrt(normalized) * 0.95
        }
    }
}


// MARK: - AVAudioRecorderDelegate

extension MicrophoneService2: AVAudioRecorderDelegate, AudioSegmentService {
    func prepareNextSegment() {
        print("📝 MicrophoneService: Preparing next segment via coordinator")
        prepareNextSegmentRecorder()
    }
    
    func rotateSegment() {
        print("🔄 MicrophoneService: Rotating segment via coordinator")
        switchToNextSegment()
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // 이제 대부분의 로직은 switchToNextSegment와 stopRecording에서 직접 처리하므로
        // 여기서는 예상치 못한 recorder 중단만 처리.
        
        // recorder가 switchToNextSegment나 stopRecording에 의해 의도적으로 중지된 경우가 아닌지 확인
        guard isRecording, !isFinishedListening, !isCancelled else {
            // 의도적으로 중지된 경우 - 아무 작업도 수행하지 않음
            print("Recorder delegate called after intentional stop - ignoring")
            return
        }
        
        // 여기까지 도달한다면 예상치 못한 중단이 발생한 경우 (오류, 권한 취소 등)
        print("Unexpected recording termination detected")
        if !flag {
            print("Segment \(segmentIndex) recording failed unexpectedly")
        } else {
            print("Segment \(segmentIndex) stopped unexpectedly but successfully")
        }
        
        // 상태 정리 및 알림
        isRecording = false
        stopTimers()
        
        // 예상치 못한 종료도 처리해줌
        ListeningCoordinator.shared.handleMicrophoneSegment(
            index: segmentIndex,
            fileName: micSegmentFileName,
            isFinished: true
        )
    }
}
