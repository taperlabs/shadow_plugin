
import Foundation
import FlutterMacOS
import Combine
import SwiftUI

//MARK: - LsteningViewModel
final class ListeningViewModel:NSObject, ObservableObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?
    
    private var newMicService: NewMicrophoneService
    private var newMicService2: MicrophoneService2 = MicrophoneService2()
    
    private let coordinator = AudioSegmentCoordinator.shared
    
    //    private var newMicService = NewMicrophoneService()
    private var newSysService = NewScreenCaptureService()
    
    private let newSysOnlyService = SystemAudioOnlyService()
    
    private var microphoneService = MicrophoneService()
    private var screenCaptureService = ScreenCaptureService()
    private var coreAudioService = CoreAudioService()
    var screenshotCaptureService = ScreenshotCaptureService()
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

    @Published var captureTargets: [CaptureTarget] = []
    @Published var selectedCaptureTarget: CaptureTarget? = .autoCapture(nil)
    @Published var shouldScreenshotCapture: Bool = false

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
        setAudioDeviceListener()
    }
    
    deinit {
        print("ListeningViewModel deinitialized 🦊")
        print("ListeningViewModel deinitializing - memory address: \(Unmanaged.passUnretained(self).toOpaque())")
        removeAudioDeviceListener()
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
            coordinator.startCoordination()
            newMicService2.startRecording(name: micFileName)
            try newSysOnlyService.startRecording(sysFileName: sysFileName)
        } catch let error {
            ShadowLogger.shared.error("Failed to start Listening -- \(error.localizedDescription)")
            print(error.localizedDescription)
            let systemError = SystemAudioListeningError(
                error: error,
                segmentIndex: 0
            )
            ListeningStatusService.shared.sendSystemAudioListeningErrorEvent(systemError.toDict())
        }
    }
    
    func stopListening() {
        // TODO: Stop Listening
        //        newMicService.stopRecording()
//        newSysService.stopCapture()
        newSysOnlyService.stopRecording()
        newMicService2.stopRecording()
        
        coordinator.stopCoordination()
        
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
        
        coordinator.stopCoordination()
        
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
    
    func setRecordingProperties(userName: String, micFileName: String, sysFileName: String, uuid: String, shouldScreenshotCapture: Bool) {
        self.username = userName
        self.micFileName = micFileName
        self.sysFileName = sysFileName
        self.uuid = uuid
        self.shouldScreenshotCapture = shouldScreenshotCapture

        // shouldScreenshotCapture가 false이면 noCapture로 시작
        if !shouldScreenshotCapture {
            self.selectedCaptureTarget = .noCapture
        }
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

        // ScreenshotCaptureService subscriptions
        screenshotCaptureService.$windows
            .combineLatest(screenshotCaptureService.$displays, $selectedCaptureTarget)
            .map { windows, displays, selectedTarget in
                let displayTargets = displays.map { CaptureTarget.display($0) }
                let windowTargets = windows.map { CaptureTarget.window($0) }

                // Smart index 0 logic
                // State 1: Show .autoCapture(nil) at index 0 when selectedTarget is .autoCapture without window info
                // State 2: Show .autoCapture(windowInfo) at index 0 when a window is found
                // Note: We keep the window in the list (Slack-like behavior), not filtering it out
                var firstElement: CaptureTarget = .autoCapture(nil)

                if let selectedTarget = selectedTarget,
                   case .autoCapture(let windowInfo) = selectedTarget,
                   let window = windowInfo {
                    // State 2: Auto-captured window at index 0
                    firstElement = .autoCapture(window)
                }

                return [firstElement, .noCapture] + displayTargets + windowTargets
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] (targets: [CaptureTarget]) in
                guard let self = self else { return }
                self.captureTargets = targets

                // Validate selectedCaptureTarget still exists
                if let selected = self.selectedCaptureTarget, !selected.isNoCapture && !selected.isAutoCapture {
                    let stillExists = targets.contains { $0.id == selected.id }
                    if !stillExists {
                        self.selectedCaptureTarget = .autoCapture(nil)
                        ShadowLogger.shared.info("⚠️ Selected capture target '\(selected.name)' no longer available, reset to .autoCapture")

                        // Notify Flutter about the auto-reset
                        ShadowPlugin.sendToFlutter(
                            method: "onCaptureTargetAutoReset",
                            data: ["reason": "target_unavailable", "previousTarget": selected.asDictionary()]
                        )
                    }
                }
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

    func fetchCaptureTargets() async {
        await screenshotCaptureService.getAvailableDisplays()
        await screenshotCaptureService.getAvailableTargets()
    }
    
    func fetchAppIcon(bundleID: String) -> NSImage? {
        return ScreenshotCaptureService.getAppIcon(for: bundleID)
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

    // MARK: - Capture Target Selection

    /// Update capture target by searching in captureTargets list
    /// - Parameters:
    ///   - type: Type of capture target ("noCapture", "autoCapture", "window", "display")
    ///   - windowID: Optional window ID for exact match
    ///   - windowTitle: Optional window title for partial match (case-insensitive)
    ///   - displayID: Optional display ID for exact match
    ///   - displayName: Optional display name for partial match (case-insensitive)
    /// - Returns: The found CaptureTarget, or nil if not found
    func updateCaptureTarget(
        type: String,
        windowID: Int? = nil,
        windowTitle: String? = nil,
        displayID: Int? = nil,
        displayName: String? = nil
    ) async -> CaptureTarget? {

        // Refresh the latest capture targets before searching
        await fetchCaptureTargets()

        // Build fresh targets directly from the service (no delay needed)
        let freshTargets = screenshotCaptureService.buildCaptureTargets()

        // Update the @Published property for UI
        await MainActor.run {
            self.captureTargets = freshTargets
        }

        switch type {
        case "noCapture":
            await MainActor.run {
                self.selectedCaptureTarget = .noCapture
            }
            return .noCapture

        case "autoCapture":
            // If windowID or windowTitle is provided, search for the window
            if windowID != nil || windowTitle != nil {
                // Search for window
                for target in freshTargets {
                    if case .window(let windowInfo) = target {
                        // Match by ID if provided
                        if let id = windowID {
                            if windowInfo.windowID == CGWindowID(id) {
                                let updatedTarget = CaptureTarget.autoCapture(windowInfo)
                                await MainActor.run {
                                    self.selectedCaptureTarget = updatedTarget
                                }
                                return updatedTarget
                            }
                        }
                        // Match by title if provided (case-insensitive partial match)
                        else if let title = windowTitle {
                            if windowInfo.title.lowercased().contains(title.lowercased()) {
                                let updatedTarget = CaptureTarget.autoCapture(windowInfo)
                                await MainActor.run {
                                    self.selectedCaptureTarget = updatedTarget
                                }
                                return updatedTarget
                            }
                        }
                    }
                }
                // Window not found, return nil
                return nil
            } else {
                // No search parameters, return .autoCapture(nil) for "Meeting Screen (Auto)"
                await MainActor.run {
                    self.selectedCaptureTarget = .autoCapture(nil)
                }
                return .autoCapture(nil)
            }

        case "window":
            // Search for window
            for target in freshTargets {
                if case .window(let windowInfo) = target {
                    // Match by ID if provided
                    if let id = windowID {
                        if windowInfo.windowID == CGWindowID(id) {
                            let updatedTarget = CaptureTarget.window(windowInfo)
                            await MainActor.run {
                                self.selectedCaptureTarget = updatedTarget
                            }
                            return updatedTarget
                        }
                    }
                    // Match by title if provided (case-insensitive partial match)
                    else if let title = windowTitle {
                        if windowInfo.title.lowercased().contains(title.lowercased()) {
                            let updatedTarget = CaptureTarget.window(windowInfo)
                            await MainActor.run {
                                self.selectedCaptureTarget = updatedTarget
                            }
                            return updatedTarget
                        }
                    }
                }
            }
            return nil

        case "display":
            // Search for display
            for target in freshTargets {
                if case .display(let displayInfo) = target {
                    // Match by ID if provided
                    if let id = displayID {
                        if displayInfo.displayID == id {
                            await MainActor.run {
                                self.selectedCaptureTarget = target
                            }
                            return target
                        }
                    }
                    // Match by name if provided (case-insensitive partial match)
                    else if let name = displayName {
                        if displayInfo.localizedName.lowercased().contains(name.lowercased()) {
                            await MainActor.run {
                                self.selectedCaptureTarget = target
                            }
                            return target
                        }
                    }
                }
            }
            return nil

        default:
            return nil
        }
    }
}
