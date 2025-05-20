import Foundation
import AVFoundation
import Combine
import QuartzCore

final class MicrophoneService2: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    // 다음 세그먼트를 위한 미리 준비된 recorder
    private var nextAudioRecorder: AVAudioRecorder?
    private var noiseTimer: Timer?
    private var isFinishedListening: Bool = false
    private var isCancelled: Bool = false
    
    private var baseFileName: String = ""
    private var micSegmentFileName: String = ""
    private var nextMicSegmentFileName: String = ""
    
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var noiseLevel: Float = 0.0
    
    
    /// 시작할 때 base 파일 이름을 받고 첫 번째 세그먼트 녹음을 시작
    func startRecording(name: String) {
        // 마이크 권한 요청
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            guard let self = self else { return }
            if granted {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.baseFileName = name
                    let initialIndex = AudioSegmentCoordinator.shared.getCurrentSegmentIndex()
                    self.startNewSegment(segmentIndex: initialIndex)
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
    private func startNewSegment(segmentIndex: Int) {
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
                print("Started recording segment \(segmentIndex) at \(audioFileURL.absoluteString)")
            } catch {
                print("Failed to initialize AVAudioRecorder: \(error.localizedDescription)")
            }
        }
    }
    
    /// 다음 세그먼트 미리 준비
    private func prepareNextSegmentRecorder(nextIndex: Int) {
        // 베이스 파일명을 이용해 다음 세그먼트 파일명 준비
        let baseFile = baseFileName.replacingOccurrences(of: ".m4a", with: "")
        let nextSegmentMicAudio = "\(baseFile)-\(nextIndex).m4a"
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
            
            print("🎙️ Prepared next segment \(nextIndex) at \(nextAudioFileURL.absoluteString)")
        } catch {
            print("Failed to initialize next AVAudioRecorder: \(error.localizedDescription)")
        }
    }
    
    // 다음 세그먼트로 전환
    private func switchToNextSegment(newIndex: Int) {
        guard let recorder = audioRecorder else { return }
        
        // 현재 녹음 중지하기 전에 참조 보관
        let oldRecorder = recorder
        // 현재 녹음기에서 delegate 제거 (더 이상 이벤트를 받지 않도록)
        oldRecorder.delegate = nil
        // 현재 녹음 중지
        oldRecorder.stop()
        
        let currentIndex = AudioSegmentCoordinator.shared.getCurrentSegmentIndex()
        
        // 현재 세그먼트 처리를 직접 수행 (delegate에 의존하지 않음)
        if !isCancelled && !isFinishedListening {
            ListeningCoordinator.shared.handleMicrophoneSegment(index: currentIndex, fileName: micSegmentFileName)
            
            // 전체 녹음이 중단되지 않았다면 다음 세그먼트를 시작합니다.
            if isRecording {
                startNewSegment(segmentIndex: newIndex)
            }
        } else if isCancelled {
            ListeningCoordinator.shared.handleMicrophoneSegment(index: currentIndex, fileName: micSegmentFileName, isFinished: true, isCancelled: true)
        } else if isFinishedListening {
            ListeningCoordinator.shared.handleMicrophoneSegment(index: currentIndex, fileName: micSegmentFileName, isFinished: true)
        }
    }
    
    /// 녹음 중지 (전체 녹음 종료)
    func stopRecording(isCancelled: Bool = false) {
        print("stopRecording with isCancelled = \(isCancelled)")
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
            
            let currentIndex = AudioSegmentCoordinator.shared.getCurrentSegmentIndex()
            
            // 마지막 세그먼트 처리를 직접 수행
            if let recorder = currentRecorder, recorder.isRecording {
                recorder.stop()
                
                // delegate 메서드를 대신해서 직접 처리
                ListeningCoordinator.shared.handleMicrophoneSegment(
                    index: currentIndex,
                    fileName: micSegmentFileName,
                    isFinished: true,
                    isCancelled: isCancelled
                )
            }
            
            // 모든 상태 및 참조 초기화
            self.baseFileName = ""
            self.nextMicSegmentFileName = ""
            self.audioRecorder = nil
            self.nextAudioRecorder = nil
        }
    }
    
    // 타이머 시작 (Noise level 및 경과 시간 업데이트)
    private func startTimers() {
        noiseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            let averagePower = recorder.averagePower(forChannel: 0)
            self.noiseLevel = self.normalizedPowerLevel(fromDecibels: averagePower)
        }
    }
    
    private func stopTimers() {
        noiseTimer?.invalidate()
        noiseTimer = nil
        nextAudioRecorder = nil  // 다음 세그먼트용 recorder도 정리
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
    func prepareNextSegment(nextSegmentIndex: Int) {
        print("📝 MicrophoneService: Preparing next segment via coordinator")
        prepareNextSegmentRecorder(nextIndex: nextSegmentIndex)
    }
    
    func rotateSegment(currentSegmentIndex: Int) {
        print("🔄 MicrophoneService: Rotating segment via coordinator")
        switchToNextSegment(newIndex: currentSegmentIndex + 1)
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        // 이제 대부분의 로직은 switchToNextSegment와 stopRecording에서 직접 처리하므로
        // 여기서는 예상치 못한 recorder 중단만 처리.
        
        let currentIndex = AudioSegmentCoordinator.shared.getCurrentSegmentIndex()
        
        // recorder가 switchToNextSegment나 stopRecording에 의해 의도적으로 중지된 경우가 아닌지 확인
        guard isRecording, !isFinishedListening, !isCancelled else {
            // 의도적으로 중지된 경우 - 아무 작업도 수행하지 않음
            print("Recorder delegate called after intentional stop - ignoring")
            return
        }
        
        // 여기까지 도달한다면 예상치 못한 중단이 발생한 경우 (오류, 권한 취소 등)
        print("Unexpected recording termination detected")
        if !flag {
            print("Segment \(currentIndex) recording failed unexpectedly")
        } else {
            print("Segment \(currentIndex) stopped unexpectedly but successfully")
        }
        
        // 상태 정리 및 알림
        isRecording = false
        stopTimers()
        
        // 예상치 못한 종료도 처리해줌
        ListeningCoordinator.shared.handleMicrophoneSegment(
            index: currentIndex,
            fileName: micSegmentFileName,
            isFinished: true
        )
    }
}
