import Foundation
import AVFoundation
import Combine
import Accelerate

class NewMicrophoneService {
    // MARK: - Configuration
    private let sampleRate: Double = 16000.0
    private let channelCount: AVAudioChannelCount = 1
    private let defaultSegmentDuration: TimeInterval = 60.0 // 2 minutes in seconds
    
    // MARK: - Audio Engine Components
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var segmentFileWriter: AVAudioFile?
    private var fullFileWriter: AVAudioFile?
    private var audioConverter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?
    private var targetFormat: AVAudioFormat?
    
    private var testAudioFile: AVAudioFile?
    
    // MARK: - State Management
    private var isRecording = false
    private var currentSegmentIndex = 0
    private var currentSegmentStartTime: TimeInterval = 0
    private var recordingStartTime: TimeInterval = 0
    private var segmentDuration: TimeInterval
    
    // MARK: - File Management
    private let fileManager = FileManager.default
    
    private var micFileName: String = ""
    private var micSegmentFileName: String = ""
    
    //MARK: - Timer State
    @Published private(set) var currentTime: TimeInterval = 0
    private var timeTimer: Timer?
    private let timeQueue = DispatchQueue(label: "com.app.newMicrophoneService.timeQueue")
    
    private let noiseThreshold: Float = 0.1
    @Published private(set) var noiseLevel: Float = 0.0
    
    private var coreAudioService: CoreAudioService
    private var cancellables = Set<AnyCancellable>()
    
    
    // MARK: - Initialization
    init(segmentDuration: TimeInterval? = nil, coreAudioService: CoreAudioService) {
        self.inputNode = audioEngine?.inputNode
        self.segmentDuration = segmentDuration ?? defaultSegmentDuration
        self.coreAudioService = coreAudioService
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConfigurationChange),
            name: .AVAudioEngineConfigurationChange,
            object: nil // Note: Changed to nil since audioEngine is now optional
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("Deinit Mic Service")
    }
    
    @objc private func handleConfigurationChange(_ notification: Notification) {
        print("Audio configuration change detected")
        
        // If we're recording, we need to restart the engine
        if isRecording {
            updateRecordingConfiguration()
        }
    }
    
    // MARK: - Audio Engine Setup
    private func setupAudioEngine() throws -> (AVAudioEngine, AVAudioInputNode, AVAudioFormat) {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        let inputFormat = input.inputFormat(forBus: 0)
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        
        print("Raw inputNode format:  \(inputFormat)")
        print("Raw outputNode format: \(outputFormat)")
        logAudioEngineFormats(engine)
        
        return (engine, input, format)
    }
    
    private func createTargetFormat() -> AVAudioFormat? {
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: false
        )
    }
    
    func logAudioEngineFormats(_ engine: AVAudioEngine) {
        let inputNode = engine.inputNode
        let mainMixer = engine.mainMixerNode
        let outputNode = engine.outputNode
        
        // inputNode
        let inputBusFormat   = inputNode.inputFormat(forBus: 0)
        let inputOutBusFormat = inputNode.outputFormat(forBus: 0)
        print("inputNode inputBus format:  sampleRate=\(inputBusFormat.sampleRate), channels=\(inputBusFormat.channelCount)")
        print("inputNode outputBus format: sampleRate=\(inputOutBusFormat.sampleRate), channels=\(inputOutBusFormat.channelCount)")
        
        // mainMixerNode
        let mixerInBusFormat  = mainMixer.inputFormat(forBus: 0)
        let mixerOutBusFormat = mainMixer.outputFormat(forBus: 0)
        print("mainMixerNode inputBus format:  sampleRate=\(mixerInBusFormat.sampleRate), channels=\(mixerInBusFormat.channelCount)")
        print("mainMixerNode outputBus format: sampleRate=\(mixerOutBusFormat.sampleRate), channels=\(mixerOutBusFormat.channelCount)")
        
        // outputNode
        let outputBusFormat = outputNode.inputFormat(forBus: 0)   // The output node only has an input bus
        let outputOutBusFormat = outputNode.outputFormat(forBus: 0)
        print("outputNode inputBus format:  sampleRate=\(outputBusFormat.sampleRate), channels=\(outputBusFormat.channelCount)")
        print("outputNode outputBus format: sampleRate=\(outputOutBusFormat.sampleRate), channels=\(outputOutBusFormat.channelCount)")
    }
    
    private func updateRecordingConfiguration() {
        guard let currentAudioFile = self.segmentFileWriter else {
            print("오디오 파일이 없으므로 설정 업데이트를 건너뜁니다.")
            return
        }
        
        // 기존 엔진에서 탭 제거 및 엔진 중단
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        
        do {
            // 새 엔진, 입력 노드, 포맷을 설정
            let (newEngine, newInput, newFormat) = try setupAudioEngine()
            self.audioEngine = newEngine
            self.inputNode = newInput
            self.inputFormat = newFormat
            
            // 타깃 포맷 및 컨버터 재생성
            guard let targetFormat = createTargetFormat() else {
                throw NSError(domain: "AudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create target format"])
            }
            guard let newConverter = AVAudioConverter(from: newFormat, to: targetFormat) else {
                throw NSError(domain: "AudioRecorder", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
            }
            self.audioConverter = newConverter
            
            self.audioConverter?.sampleRateConverterQuality = .max
            
            // 기존 녹음 파일 (currentAudioFile)을 그대로 사용하여 새 탭 설치
            newInput.installTap(onBus: 0, bufferSize: 4096, format: newFormat) { [weak self] (buffer, time) in
                guard let self = self,
                      let converter = self.audioConverter else { return }
                
                // 출력 버퍼 크기는 샘플레이트 비율에 따라 계산
                let ratio = self.sampleRate / buffer.format.sampleRate
                let outputFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
                
                guard let outputBuffer = AVAudioPCMBuffer(
                    pcmFormat: targetFormat,
                    frameCapacity: outputFrames
                ) else { return }
                
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                var error: NSError?
                let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
                
                guard status != .error else {
                    print("Conversion error: \(error?.localizedDescription ?? "unknown error")")
                    return
                }
                self.processAudioBuffer(outputBuffer, time: time)
            }
            
            try newEngine.start()
            print("Recording configuration updated without stopping recording")
            
        } catch let error {
            print("Failed to update recording configuration: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Recording Control
    func startRecording(fileName: String) throws {
        guard !isRecording else { return }
        
        print(fileName)
        micFileName = fileName
        
        // Set up documents path
        guard let documentDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "AudioRecordingSystem",
                          code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Unable to access Documents directory"])
        }
        
        // Set up audio engine if not already set up
        do {
            let (engine, input, format) = try setupAudioEngine()
            self.audioEngine = engine
            self.inputNode = input
            self.inputFormat = format
            // Create target format for 16kHz
            guard let targetFormat = createTargetFormat() else {
                throw NSError(domain: "AudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create target format"])
            }
            
            // Create audio converter
            guard let converter = AVAudioConverter(from: format, to: targetFormat) else {
                throw NSError(domain: "AudioRecorder", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio converter"])
            }
            self.audioConverter = converter
            
            self.audioConverter?.sampleRateConverterQuality = .max
            
            currentSegmentIndex = 0
            recordingStartTime = CACurrentMediaTime()
            currentSegmentStartTime = recordingStartTime
            
            // Create full length file
//            try createNewFullLengthFile(fileName: micFileName)
            // Create first segment file
            try createNewSegmentFile(fileName: micFileName)

            input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] (buffer, time) in
                guard let self = self,
                      let audioFile = self.segmentFileWriter,
                      let converter = self.audioConverter else { return }
                
                // Calculate output buffer size based on ratio of sample rates
                let ratio = self.sampleRate / buffer.format.sampleRate
                let outputFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
                
                guard let outputBuffer = AVAudioPCMBuffer(
                    pcmFormat: targetFormat,
                    frameCapacity: outputFrames
                ) else { return }
                
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }
                
                var error: NSError?
                let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
                
                guard status != .error else {
                    print("Conversion error: \(error?.localizedDescription ?? "unknown error")")
                    return
                }
                
                self.processAudioBuffer(outputBuffer, time: time)
            }
            
            try audioEngine?.start()
            isRecording = true
            
        } catch let error {
            print (error.localizedDescription)
        }
    }
    
    func stopRecording(isCancelled: Bool = false) {
        guard isRecording else { return }
        
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        
        
        DispatchQueue.main.async { [weak self] in
            self?.segmentFileWriter = nil
            self?.fullFileWriter = nil
            self?.isRecording = false
        }
        
        ListeningCoordinator.shared.handleMicrophoneSegment(
            index: currentSegmentIndex,
            fileName: micSegmentFileName,
            isFinished: true,
            isCancelled: isCancelled
        )
        
    }
    
    // MARK: - File Creation
    private func createNewFullLengthFile(fileName: String) throws {
        guard let outputURL = FileManagerHelper.getURL(for: fileName, in: "ApplicationSupportDirectory") else {
            print("File URL을 가져오는데 실패하였습니다.")
            return
        }
        
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
        ]
        
        guard let targetFormat = createTargetFormat() else {
            throw NSError(domain: "AudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create target format"])
        }
        
        
        fullFileWriter = try AVAudioFile(
            forWriting: outputURL,
            settings: targetFormat.settings
        )
    }
    
    private func createNewSegmentFile(fileName: String) throws {
        //TODO: 여기 리팩토링 필요 file path
        let baseFileName = fileName.replacingOccurrences(of: ".wav", with: "")
        var segmentMicAudio = "\(baseFileName)-\(currentSegmentIndex).wav"
        micSegmentFileName = segmentMicAudio
        guard let outputURL = FileManagerHelper.getURL(for: segmentMicAudio, in: "ApplicationSupportDirectory") else {
            print("File URL을 가져오는데 실패하였습니다.")
            return
        }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channelCount,
        ]
        
        guard let targetFormat = createTargetFormat() else {
            throw NSError(domain: "AudioRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create target format"])
        }
        
        
        segmentFileWriter = try AVAudioFile(
            forWriting: outputURL,
            settings: targetFormat.settings
        )
    }
    
    // MARK: - Audio Processing
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        let currentTime = CACurrentMediaTime()
        let relativeTime = currentTime - recordingStartTime  // Calculate time since recording started
        
        // Calculate noise level from buffer using Accelerate framework
        var sum: Float = 0
        vDSP_svesq(buffer.floatChannelData![0], 1, &sum, vDSP_Length(buffer.frameLength))
        let rms = sqrt(sum / Float(buffer.frameLength))
        
        //         Calculate normalized noise level
        let normalizedNoise = normalizedPowerLevel(fromRMS: rms)
        
        //         Log noise levels with relative timestamp
        if normalizedNoise > noiseThreshold {
            print("🎤 [\(String(format: "%.2f", relativeTime))s] Noise Level: \(String(format: "%.3f", normalizedNoise))")
            
            // Additional debug info for significant noise
            if normalizedNoise > 0.5 {
                print("📢 [\(String(format: "%.2f", relativeTime))s] High noise detected!")
                print("RMS: \(String(format: "%.6f", rms))")
                print("Buffer length: \(buffer.frameLength)")
            }
        }
        
        // Update noise level on main thread
        DispatchQueue.main.async {
            self.noiseLevel = normalizedNoise
        }
        
        
        // Write to full length file
        do {
            try fullFileWriter?.write(from: buffer)
        } catch {
            ShadowLogger.shared.error("Error writing to full length file: \(error.localizedDescription)")
            print("Error writing to full length file: \(error)")
        }
        
        // Write to current segment file
        do {
            try segmentFileWriter?.write(from: buffer)
        } catch {
            ShadowLogger.shared.error("Error writing to segment file: \(error)")
            print("Error writing to segment file: \(error)")
        }
        
        // Check if we need to start a new segment
        let segmentElapsedTime = currentTime - currentSegmentStartTime
        if segmentElapsedTime >= segmentDuration {
            ListeningCoordinator.shared.handleMicrophoneSegment(index: currentSegmentIndex, fileName: micSegmentFileName)
            currentSegmentIndex += 1
            currentSegmentStartTime = currentTime
            do {
                try createNewSegmentFile(fileName: micFileName)
            } catch {
                ShadowLogger.shared.error("Error creating new segment file: \(error)")
                print("Error creating new segment file: \(error)")
            }
        }
    }
}

extension NewMicrophoneService {
    private func startTimer() {
        timeQueue.sync {
            currentTime = 0
            recordingStartTime = Date().timeIntervalSinceReferenceDate
        }
        
        timeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.timeQueue.sync {
                let currentSystemTime = Date().timeIntervalSinceReferenceDate
                DispatchQueue.main.async {
                    self.currentTime = floor(currentSystemTime - self.recordingStartTime)
                }
            }
        }
    }
    
    private func stopTimer() {
        timeTimer?.invalidate()
        timeTimer = nil
        
        timeQueue.sync {
            DispatchQueue.main.async {
                self.currentTime = 0
            }
        }
    }
    
    private func normalizedPowerLevel(fromRMS rms: Float) -> Float {
        // Handle zero RMS case explicitly
        guard rms > 0 else {
            print("📉 Silence detected (RMS = 0)")
            return 0.0
        }
        
        let minDecibels: Float = -50.0
        let maxDecibels: Float = 0.0
        
        // Convert RMS to decibels
        let db = 20 * log10(rms)
        
        if db < minDecibels {
            return 0.0
        } else if db >= maxDecibels {
            print("📈 Peak level reached: \(db) dB")
            return 0.95
        } else {
            let normalized = (db - minDecibels) / (maxDecibels - minDecibels)
            return sqrt(normalized) * 0.95
        }
    }
    
    // MARK: - Utility Methods
    func getRecordingDuration() -> TimeInterval {
        guard isRecording else { return 0 }
        return CACurrentMediaTime() - recordingStartTime
    }
    
    func getCurrentSegmentDuration() -> TimeInterval {
        guard isRecording else { return 0 }
        return CACurrentMediaTime() - currentSegmentStartTime
    }
}
