
import Foundation
import FlutterMacOS
import Combine
import SwiftUICore

//MARK: - LsteningViewModel
final class ListeningViewModel:NSObject, ObservableObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    
    private var newMicService: NewMicrophoneService
    private var newMicService2: MicrophoneService2 = MicrophoneService2()
    
    //    private var newMicService = NewMicrophoneService()
    private var newSysService = NewScreenCaptureService()
    
    private let newSysOnlyService = SystemAudioOnlyService()
    
    private var microphoneService = MicrophoneService()
    private var screenCaptureService = ScreenCaptureService()
    private var coreAudioService = CoreAudioService()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var showListeningView: Bool = false
    
    @Published var counter: Int = 0
    @Published var imagePath: String?
    @Published var lottiePath: String?
    @Published var waveformLottie: String?
    @Published var donePath: String?
    @Published var cancelPath: String?
    @Published var minimizePath: String?
    
    @Published var isAudioSaveOn: Bool = false
    @Published var hotkeys: String = ""
    
    @Published var currentTime: TimeInterval = 0
    @Published var isRecording: Bool = false
    @Published var noiseLevel: Float = 0.0
    
    @Published var defaultInputDevice: AudioDeviceID?
    @Published var defaultOutputDevice: AudioDeviceID?
    @Published var inputDevices: [AudioDevice] = []
    
    @Published var username: String?
    @Published var micFileName: String?
    @Published var sysFileName: String?
    @Published var uuid: String = ""
    
    @Published var countdownNumber: Int? = nil
    @Published var countdownTimer: AnyCancellable? = nil
    @Published var isCountdownActive: Bool = false
    private var shouldStartRecording: Bool = false
    
    @Published var micNoiseLevel: Float = 0.0
    @Published var sysNoiseLevel: Float = 0.0
    
    var shouldAnimateWaveform: Bool {
        return micNoiseLevel > 0 || sysNoiseLevel > 0
    }
    
    @Published private(set) var stickColors: [Int: Color] = [:]
    private var lastActiveColors: [Int: Color] = [1: .gray, 2: .gray, 3: .gray, 4: .gray]
//    private var lastActiveColors: [Int: Color] = [:]
    
    // Computed property that updates stickColors whenever noise levels change
    private var computeStickColors: [Int: Color] {
        if sysNoiseLevel > 0 && micNoiseLevel <= 0 {
            // 시스템 오디오만 있을 때
            lastActiveColors = [1: .green, 2: .green, 3: .green, 4: .green]
            return lastActiveColors
        } else if sysNoiseLevel > 0 && micNoiseLevel > 0 {
            // 시스템 오디오와 마이크 모두 있을 때
            lastActiveColors = [1: .green, 3: .green]
            return lastActiveColors
        } else if micNoiseLevel > 0 && sysNoiseLevel <= 0 {
            // 마이크만 있을 때
            lastActiveColors = [:]
            return lastActiveColors
        } else {
            // 모든 소리가 없을 때 마지막 활성 색상 유지
            return lastActiveColors
        }
    }
    
    @Published var defaultInputDeviceName: String = "Unknown Device"
    
    // Computed property to get the name of the default input device
    //    var defaultInputDeviceName: String {
    //        if let defaultID = defaultInputDevice,
    //           let device = inputDevices.first(where: { $0.id == defaultID }) {
    //            return device.name
    //        }
    //        return "Unknown Device"
    //    }
    
    private func updateDefaultDeviceName() {
        if let defaultID = defaultInputDevice,
           let device = inputDevices.first(where: { $0.id == defaultID }) {
            defaultInputDeviceName = device.name
        } else {
            defaultInputDeviceName = "Unknown Device"
        }
    }
    
    override init() {
        newMicService = NewMicrophoneService(coreAudioService: coreAudioService)
        super.init()
        print("ListeningViewModel initialized 🦊")
        setupSubscriptions()
    }
    
    deinit {
        print("ListeningViewModel deinitialized 🦊")
        print("ListeningViewModel deinitializing - memory address: \(Unmanaged.passUnretained(self).toOpaque())")
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
    
    func startListening() {
        guard let sysFileName = sysFileName,
              let micFileName = micFileName else {
            print("No File Name Given")
            return
        }
        do {
//            Task {
//                do {
////                    try await newSysService.startCapture(fileName: sysFileName)
//                   
//                } catch let error {
//                    print("error in startListening -- \(error.localizedDescription)")
//                }
//            }
            try newSysOnlyService.startRecording(sysFileName: sysFileName)
            newMicService2.startRecording(name: micFileName)
            //            try newMicService.startRecording(fileName: micFileName)
        } catch let error {
            print(error.localizedDescription)
        }
    }
    
    func stopListening() {
        // TODO: Stop Listening
        //        newMicService.stopRecording()
//        newSysService.stopCapture()
        newSysOnlyService.stopRecording()
        newMicService2.stopRecording()
        
        // Clean up all references
        cancellables.removeAll()
        
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.shouldStartRecording = false
            self?.isCountdownActive = false
            self?.countdownTimer?.cancel()
            self?.countdownNumber = nil
        }
    }
    
    func cancelListening() {
        //        newMicService.stopRecording(isCancelled: true)
        newMicService2.stopRecording(isCancelled: true)
//        newSysService.stopCapture(isCancelled: true)
        newSysOnlyService.cancelRecording()
        
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.shouldStartRecording = false
            self?.isCountdownActive = false
            self?.countdownTimer?.cancel()
            self?.countdownNumber = nil
        }
    }
    
    func startCountdownRecording() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.countdownNumber = 3
            self.isCountdownActive = true
            self.shouldStartRecording = true
            self.startCountdown()
        }
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
                        self.finishCountdownNew()
                    }
                }
            }
    }
    
    private func finishCountdownNew() {
        self.countdownNumber = nil
        self.countdownTimer?.cancel()
        self.countdownTimer = nil
        self.isCountdownActive = false
        
        if self.shouldStartRecording && WindowManager.shared.currentWindow != nil {
            self.startListening()
        } else {
            self.shouldStartRecording = false
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
        //        if !isAudioSaveOn,
        //           let micFileName = micFileName,
        //           let sysFileName = sysFileName,
        //           let micfileURL = FileManagerHelper.getURL(for: micFileName, in: "ApplicationSupportDirectory"),
        //           let sysFileURL = FileManagerHelper.getURL(for: sysFileName, in: "ApplicationSupportDirectory") {
        //
        //            // Delete files if they exist
        //            FileManagerHelper.deleteFileIfExists(at: micfileURL)
        //            FileManagerHelper.deleteFileIfExists(at: sysFileURL)
        //        }
        
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
        screenCaptureService.stopCapture()
        microphoneService.stopRecording()
        isRecording = false
        shouldStartRecording = false
        isCountdownActive = false
        countdownTimer?.cancel()
        countdownNumber = nil
    }
    
    func setRecordingProperties(userName: String, micFileName: String, sysFileName: String, uuid: String) {
        self.username = userName
        self.micFileName = micFileName
        self.sysFileName = sysFileName
        self.uuid = uuid
    }
    
    func setHotkeys(with hotkey: String) {
        self.hotkeys = hotkey
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
    
    func clearEventSink() {
        eventSink = nil
    }
    
    func cleanupCombines() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        print("cancellables ====",cancellables)
    }
    
    private func setupSubscriptions() {
        // Replace all assign(to:on:) with sink using [weak self]
        
        newSysOnlyService.$noiseLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.sysNoiseLevel = value
            }
            .store(in: &cancellables)
        
        newMicService2.$noiseLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.micNoiseLevel = value
            }
            .store(in: &cancellables)
        
        $micNoiseLevel
            .combineLatest($sysNoiseLevel)
            .map { [weak self] _, _ in
                self?.computeStickColors ?? [:]
            }
            .sink { [weak self] value in
                self?.stickColors = value
            }
            .store(in: &cancellables)
        
//        newSysService.$noiseLevel
//            .receive(on: RunLoop.main)
//            .sink { [weak self] value in
//                self?.sysNoiseLevel = value
//            }
//            .store(in: &cancellables)
        
        Publishers.CombineLatest($defaultInputDevice, $inputDevices)
            .receive(on: RunLoop.main)
            .sink { [weak self] (deviceID, devices) in
                self?.updateDefaultDeviceName()
            }
            .store(in: &cancellables)
        
        microphoneService.$currentTime
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.currentTime = value
            }
            .store(in: &cancellables)
        
        microphoneService.$isRecording
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.isRecording = value
            }
            .store(in: &cancellables)
        
        microphoneService.$noiseLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.noiseLevel = value
            }
            .store(in: &cancellables)
        
        coreAudioService.$inputDevices
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.inputDevices = value
            }
            .store(in: &cancellables)
        
        coreAudioService.$defaultInputDevice
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.defaultInputDevice = value
            }
            .store(in: &cancellables)
        
        $isRecording
            .receive(on: RunLoop.main)
            .sink { [weak self] newValue in
                self?.sendEvent(["isRecording": newValue])
            }
            .store(in: &cancellables)
    }
    
    //    private func setupSubscriptions() {
    //
    //        newMicService2.$noiseLevel
    //            .receive(on: RunLoop.main)
    //            .assign(to: \.micNoiseLevel, on: self)
    //            .store(in: &cancellables)
    //
    //
    //        $micNoiseLevel
    //            .combineLatest($sysNoiseLevel)
    //            .map { [weak self] _, _ in
    //                self?.computeStickColors ?? [:]
    //            }
    //            .assign(to: &$stickColors)
    //
    //        newSysService.$noiseLevel
    //            .receive(on: RunLoop.main)
    //            .assign(to: \.sysNoiseLevel, on: self)
    //            .store(in: &cancellables)
    //
    ////        newMicService.$noiseLevel
    ////            .receive(on: RunLoop.main)
    ////            .assign(to: \.micNoiseLevel, on: self)
    ////            .store(in: &cancellables)
    //
    //        // defaultInputDevice나 inputDevices가 변경될 때마다 defaultInputDeviceName 업데이트
    //        Publishers.CombineLatest($defaultInputDevice, $inputDevices)
    //            .receive(on: RunLoop.main)
    //            .sink { [weak self] (deviceID, devices) in
    //                self?.updateDefaultDeviceName()
    //            }
    //            .store(in: &cancellables)
    //
    //        microphoneService.$currentTime
    //            .receive(on: RunLoop.main)
    //            .assign(to: \.currentTime, on: self)
    //            .store(in: &cancellables)
    //
    //        microphoneService.$isRecording
    //            .receive(on: RunLoop.main)
    //            .assign(to: \.isRecording, on: self)
    //            .store(in: &cancellables)
    //
    //
    //        // Subscribe to noiseLevel
    //        microphoneService.$noiseLevel
    //            .receive(on: RunLoop.main)
    //            .assign(to: \.noiseLevel, on: self)
    //            .store(in: &cancellables)
    //
    //
    //        coreAudioService.$inputDevices
    //            .receive(on: RunLoop.main)
    //            .assign(to: \.inputDevices, on: self)
    //            .store(in: &cancellables)
    //
    //        coreAudioService.$defaultInputDevice
    //            .receive(on: RunLoop.main)
    //            .assign(to: \.defaultInputDevice, on: self)
    //            .store(in: &cancellables)
    //
    //        $isRecording
    //            .receive(on: RunLoop.main)
    //            .sink { [weak self] newValue in
    //                self?.sendEvent(["isRecording": newValue])
    //            }
    //            .store(in: &cancellables)
    //    }
    
    func updateWaveformPath(_ path: String) {
        self.waveformLottie = path
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
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(event)
        }
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
            _ = coreAudioService.setDefaultAudioInputDevice(deviceID: audioDeviceID)
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
