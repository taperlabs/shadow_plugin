
import Foundation
import FlutterMacOS
import Combine

//MARK: - LsteningViewModel
final class ListeningViewModel:NSObject, ObservableObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    
    private var microphoneService = MicrophoneService()
    private var screenCaptureService = ScreenCaptureService()
    private var coreAudioService = CoreAudioService()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var showListeningView: Bool = false
    
    @Published var counter: Int = 0
    @Published var imagePath: String?
    @Published var lottiePath: String?
    @Published var donePath: String?
    @Published var cancelPath: String?
    @Published var minimizePath: String?
    
    @Published var isAudioSaveOn: Bool = false
    
    @Published var currentTime: TimeInterval = 0
    @Published var isRecording: Bool = false
    @Published var noiseLevel: Float = 0.0
    
    @Published var defaultInputDevice: AudioDeviceID?
    @Published var defaultOutputDevice: AudioDeviceID?
    @Published var inputDevices: [AudioDevice] = []
    
    @Published var username: String?
    @Published var micFileName: String?
    @Published var sysFileName: String?
    
    @Published var countdownNumber: Int? = nil
    @Published var countdownTimer: AnyCancellable? = nil
    @Published var isCountdownActive: Bool = false
    private var shouldStartRecording: Bool = false
    
    // Computed property to get the name of the default input device
    var defaultInputDeviceName: String {
        if let defaultID = defaultInputDevice,
           let device = inputDevices.first(where: { $0.id == defaultID }) {
            return device.name
        }
        return "Unknown Device"
    }
    
    override init() {
        super.init()
        setupSubscriptions()
    }
    
    deinit {
        print("ListeningViewModel deinitialized 🦊")
    }
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("onListen!!!")
        self.eventSink = events
        //        sendEvent("Test event from Swift!!!")
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("onListen Cancel!!")
        return nil
    }
    
    func startCountdownRecording() {
        countdownNumber = 3
        isCountdownActive = true
        shouldStartRecording = true
        startCountdown()
    }
    
    func startCountdown() {
        // Ensure only one timer is running
        countdownTimer?.cancel()
        
        // Create a Timer publisher that emits every second
        countdownTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isCountdownActive else { return }
                
                if let current = self.countdownNumber {
                    if current > 1 {
                        self.countdownNumber = current - 1
                    } else {
                        self.finishCountdown()
                    }
                }
            }
    }
    
    private func finishCountdown() {
        self.countdownNumber = nil
        self.countdownTimer?.cancel()
        self.countdownTimer = nil
        self.isCountdownActive = false
        
        if self.shouldStartRecording && WindowManager.shared.currentWindow != nil {
            self.startMicRecording()
        } else {
            self.shouldStartRecording = false
        }
    }
    
    func stopMicRecording() {
        screenCaptureService.stopCapture()
        microphoneService.stopRecording()
        showListeningView = false
        shouldStartRecording = false
        isCountdownActive = false
        countdownTimer?.cancel()
        countdownNumber = nil
    }
    
    // Call this method when the window is about to close
    func cancelRecording() {
        isRecording = false
        shouldStartRecording = false
        isCountdownActive = false
        countdownTimer?.cancel()
        countdownNumber = nil
    }

    func setupRecordingProperties(userName: String, micFileName: String, sysFileName: String, isAudioSaveOn: Bool) {
        self.username = userName
        self.micFileName = micFileName
        self.sysFileName = sysFileName
        self.isAudioSaveOn = isAudioSaveOn
    }
    
    func renderListeningView() {
        self.showListeningView = true
        self.isRecording = true
    }
    
    private func setupSubscriptions() {
        microphoneService.$currentTime
            .receive(on: RunLoop.main)
            .assign(to: \.currentTime, on: self)
            .store(in: &cancellables)
        
        microphoneService.$isRecording
            .receive(on: RunLoop.main)
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)
        
        
        // Subscribe to noiseLevel
        microphoneService.$noiseLevel
            .receive(on: RunLoop.main)
            .assign(to: \.noiseLevel, on: self)
            .store(in: &cancellables)
        
        coreAudioService.$inputDevices
            .receive(on: RunLoop.main)
            .assign(to: \.inputDevices, on: self)
            .store(in: &cancellables)
        
        coreAudioService.$defaultInputDevice
            .receive(on: RunLoop.main)
            .assign(to: \.defaultInputDevice, on: self)
            .store(in: &cancellables)
        
        $isRecording
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.sendEvent(["isRecording": newValue])
            }
            .store(in: &cancellables)
    }

    func updateLottiePath(_ path: String) {
        self.lottiePath = path
    }
    
    func updateDonePath(_ path: String) {
        self.donePath = path
    }
    
    func updateCancelPath(_ path: String) {
        self.cancelPath = path
    }
    
    func updateMinimizePath(_ path: String) {
        self.minimizePath = path
    }
    
    func updateImagePath(_ path: String) {
        self.imagePath = path
    }
    
    func sendEvent(_ event: Any) {
        eventSink?(event)
    }
    
    func setAudioDeviceListener() {
        coreAudioService.setupListeners()
        coreAudioService.fetchInitialDevices()
    }
    
    func removeAudioDeviceListener() {
        coreAudioService.removeListeners()
    }
    
    func setDefaultAudioInputDevice(with name: String)  {
        if let audioDeviceID = coreAudioService.getInputDeviceID(fromName: name) {
            coreAudioService.setDefaultAudioInputDevice(deviceID: audioDeviceID)
        }
    }
    
    func startMicRecording() {
        guard let sysFileName = sysFileName,
              let micFileName = micFileName else {
            print("No File Name Given")
            return
        }
        
        Task {
            try await screenCaptureService.startCapture(name: sysFileName)
        }
        
        microphoneService.startRecording(name: micFileName)
    }
}
