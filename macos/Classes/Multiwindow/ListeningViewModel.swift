
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
    @Published var uuid: String?
    
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
        print("ListeningViewModel deinitialized")
    }
    
    func setupRecordingProperties(userName: String, uuid: String) {
        self.username = userName
        self.uuid = uuid
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

    func buttonClicked() {
        print("Button clicked via global hotkey!")
        sendEvent("Button Clicked!!!")
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
           let _ = coreAudioService.setDefaultAudioInputDevice(deviceID: audioDeviceID)
        }
    }
    
    func startMicRecording() {
        Task {
            try await screenCaptureService.startCapture()
        }
        microphoneService.startRecording()
    }
    
    func stopMicRecording() {
        screenCaptureService.stopCapture()
        microphoneService.stopRecording()
        showListeningView = false
    }
}
