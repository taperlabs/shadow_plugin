import Foundation
import AVFAudio
import AVFoundation
import FlutterMacOS

// MARK: - Microphone 녹음 클래스
class MicrophoneRecorder: NSObject, FlutterStreamHandler {
    
    private var audioRecorder: AVAudioRecorder?
    private let recordingFileName = "FlutterMicRecording.m4a"
    private var sink: FlutterEventSink?
    private var decibelTimer: Timer?
    private var isRecording = false
    private var timeIndicator = TimeIndicator()
    private let timeIntervalValue = 1.0
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        decibelTimer = Timer.scheduledTimer(timeInterval: timeIntervalValue, target: self, selector: #selector(sendTimeUpdate), userInfo: nil, repeats: true)
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("이벤트 구독 취소 입니다!!! 🔥")
        sink = nil
        decibelTimer?.invalidate()
        decibelTimer = nil
        return nil
    }
    
    @objc private func sendTimeUpdate() {
        guard let sink = sink else { return }
        
        let time = timeIndicator.elapsedTime
        print("sendTimeUpdate from Mic Recording 🎤", time)
        
        let eventData = RecordingStatusEventModel(type: .microphoneStatus, isRecording: isRecording, elapsedTime: time)
        sink(eventData.recordingStatusDictionary)
    }
    
    func startMicAudioRecording() {
//        print("isMicrophoneAccess Granted : 111",MicrophonePermissionHandler.isMicrophoneAccessGranted())
//        if !MicrophonePermissionHandler.isMicrophoneAccessGranted() {
//            SystemSettingsHandler.openSystemSetting(for: "microphone")
////            throw CaptureError.microphonePermissionNotGranted
//            return
//        }
        
        let audioSettings = AudioSetting.setAudioConfiguration(format: .mpeg4AAC, channels: .mono, sampleRate: .rate16K)
        setupAndStartRecording(with: audioSettings, filename: recordingFileName)
    }
    
    
    func startMicAudioRecording(withConfig config: [String: Any]) {
//        print("isMicrophoneAccess Granted : 222",MicrophonePermissionHandler.isMicrophoneAccessGranted())
//        if !MicrophonePermissionHandler.isMicrophoneAccessGranted() {
//            SystemSettingsHandler.openSystemSetting(for: "microphone")
////            throw CaptureError.microphonePermissionNotGranted
//            return
//        }
        
        print("config!!!", config)
        let format = AudioFormatOption(rawValue: config["format"] as? String ?? "") ?? .mpeg4AAC
        let channels = NumberOfChannels(rawValue: config["channels"] as? String ?? "") ?? .mono
        let sampleRate = SampleRateOption(rawValue: config["sampleRate"] as? String ?? "") ?? .rate44_1K
        let filename = config["fileName"] as? String ?? recordingFileName
        
        print("format 🎤", format)
        print("channels 🎤", channels)
        print("sampleRate 🎤", sampleRate)
        print("file Name 🎤", filename)
        
        //TODO: - Change setMicRecordingSettings with Helper method
        let settings = setMicRecordingSettings(format: format, channels: channels, sampleRate: sampleRate)
        setupAndStartRecording(with: settings, filename: filename)
    }
    
    private func setupAndStartRecording(with audioSettings: [String: Any], filename: String) {
        guard let fileURL = FileManagerHelper.getURL(for: filename) else {
            print("Error generating recording URL")
            return
        }
        
        //이전에 저장한 시스템 오디오 파일이 존재하는지 체크 후 존재 시 삭제
        FileManagerHelper.deleteFileIfExists(at: fileURL)
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: audioSettings)
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            isRecording = true
            
            timeIndicator.start()
            timeIndicator.timeUpdateHandler = { [weak self] _ in
                self?.sendTimeUpdate()
            }
            
            audioRecorder?.isMeteringEnabled = true
            
        } catch {
            print("Error setting up audio recorder: \(error)")
        }
    }
    
    
    //stop mic audio recording
    func stopMicAudioRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        audioRecorder?.isMeteringEnabled = false
        isRecording = false
        timeIndicator.stop()
    }
    
    private func setMicRecordingSettings(format: AudioFormatOption,
                                         channels: NumberOfChannels,
                                         sampleRate: SampleRateOption) -> [String: Any] {
        return [
            AVFormatIDKey: format.formatID,
            AVSampleRateKey: sampleRate.sampleRate,
            AVNumberOfChannelsKey: channels.channelCount,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }
}

// MARK: - Microphone Decibel 측정 Extension
extension MicrophoneRecorder {
    
    //recorder nill check
    private func ensureRecorderInitialized() -> AVAudioRecorder? {
        guard let recorder = audioRecorder else {
            print("Error: Audio recorder가 생성되지 않았습니다.")
            return nil
        }
        return recorder
    }
    
    // Mic Audio Decibel Enable
    func enableMetering(enabled: Bool) {
        guard let recorder = ensureRecorderInitialized() else { return }
        recorder.isMeteringEnabled = enabled
    }
    
    // Update Audio Decibel measurement values
    func refreshMeters() {
        guard let recorder = ensureRecorderInitialized() else { return }
        recorder.updateMeters()
    }
    
    // Get average value for Audio Decibel measurement
    func getAveragePower(for channel: Int) -> Float {
        guard let recorder = ensureRecorderInitialized() else { return 0.0 }
        return recorder.averagePower(forChannel: channel)
    }
    
    // Get peak value for Audio Decibel measurement
    func getPeakPower(for channel: Int) -> Float {
        guard let recorder = ensureRecorderInitialized() else { return 0.0 }
        return recorder.peakPower(forChannel: channel)
    }
}

