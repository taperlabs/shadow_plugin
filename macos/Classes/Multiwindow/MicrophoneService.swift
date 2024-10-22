import Foundation
import AVFoundation
import Combine
import QuartzCore

final class MicrophoneService: NSObject, ObservableObject {
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var noiseTimer: Timer?
    private var timeTimer: Timer?
    private var startTime: TimeInterval?
    
    // Create a dedicated serial queue for time updates
    private let timeQueue = DispatchQueue(label: "com.app.microphoneService.timeQueue")
    
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var noiseLevel: Float = 0.0

    /// Starts recording audio from the microphone.
    func startRecording(name: String) {
        // Request microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            guard let self = self else { return }
            if granted {
                DispatchQueue.main.async {
                    self.setupAndStartRecording(name: name)
                }
            } else {
                print("Microphone permission not granted")
            }
        }
    }

    /// Sets up and starts the recording.
    private func setupAndStartRecording(name: String) {
        // Get audio settings
        let settings = AudioSetting.setAudioConfiguration(
            format: .mpeg4AAC,
            channels: .mono,
            sampleRate: .rate16K
        )

        // Create a unique file name
        let fileName = name
        let documentsDirectory = FileManager.default.urls(
            for: .downloadsDirectory,
            in: .userDomainMask
        )[0]
//        let audioFileURL = documentsDirectory.appendingPathComponent(fileName)
        
        guard let audioFileURL = FileManagerHelper.getURL(for: fileName, in: "ApplicationSupportDirectory") else {
            print("File URL을 가져오는데 실패하였습니다.")
            return
        }

        do {
            // Initialize and prepare the recorder
            audioRecorder = try AVAudioRecorder(url: audioFileURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true // Enable metering
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            isRecording = true // Update isRecording
            startTimers()

            print("Recording started at \(audioFileURL.absoluteString)")
        } catch {
            print("Failed to initialize AVAudioRecorder: \(error.localizedDescription)")
        }
    }

    /// Stops the recording.
    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        stopTimers()
    }
    
    private func startTimers() {
        timeQueue.sync {
            currentTime = 0
            startTime = Date().timeIntervalSinceReferenceDate
        }
        
        // Timer for noise level updates (0.1 second intervals)
        noiseTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self,
                  let recorder = self.audioRecorder else { return }
            
            recorder.updateMeters()
            let averagePower = recorder.averagePower(forChannel: 0)
            self.noiseLevel = self.normalizedPowerLevel(fromDecibels: averagePower)
        }
        
        // Timer for time updates (1 second intervals)
        timeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.timeQueue.sync {
                guard let startTime = self.startTime else { return }
                let currentSystemTime = Date().timeIntervalSinceReferenceDate
  
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
        
        timeQueue.sync {
            startTime = nil
            DispatchQueue.main.async {
                self.currentTime = 0
            }
        }
    }
    
//    private func startTimer() {
//        currentTime = 0 // Reset currentTime
//        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
//            guard let self = self, let recorder = self.audioRecorder else { return }
//            print("recorder 시간 ---> \(recorder.currentTime)")
//            self.currentTime = recorder.currentTime
//            // Update metering
//            recorder.updateMeters()
//            let averagePower = recorder.averagePower(forChannel: 0)
//            self.noiseLevel = self.normalizedPowerLevel(fromDecibels: averagePower)
//        }
//    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        currentTime = 0
    }
    
    private func normalizedPowerLevel(fromDecibels decibels: Float) -> Float {
        // Decibels range from -160 (silence) to 0 (maximum power)
        let minDecibels: Float = -80.0
        if decibels < minDecibels {
            return 0.0
        } else if decibels >= 0.0 {
            return 1.0
        } else {
            return (decibels - minDecibels) / -minDecibels
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension MicrophoneService: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if flag {
            print("Recording finished successfully.")
        } else {
            print("Recording failed to finish.")
        }
        DispatchQueue.main.async { [weak self] in
             self?.isRecording = false // Update isRecording
             self?.stopTimers()
         }
    }
}




