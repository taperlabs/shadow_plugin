import Foundation
import CoreAudio
import Combine


// Struct to represent an audio device
struct AudioDevice: Identifiable {
    let id: AudioDeviceID
    let name: String
}

class CoreAudioService: ObservableObject {
    
    // Published properties to notify observers about changes
    @Published var defaultInputDevice: AudioDeviceID?
    @Published var defaultOutputDevice: AudioDeviceID?
    @Published var inputDevices: [AudioDevice] = []
    private var propertyListenerBlock: AudioObjectPropertyListenerBlock?
    
    init() {
        print("CoreAudio Service Init")
    }
    
    deinit {
        print("CoreAudio Service Deinit")
    }
    
    // MARK: - Device Management
    func getDefaultAudioInputDevice() -> AudioDeviceID? {
        return defaultInputDevice
    }
    
    func setDefaultAudioInputDevice(deviceID: AudioDeviceID) -> Bool {
        var mutableDeviceID = deviceID
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let result = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &mutableDeviceID
        )
        
        return result == noErr
    }
    
    func getInputDeviceID(fromName name: String) -> AudioDeviceID? {
        return inputDevices.first(where: { $0.name == name })?.id
    }
    
    func getAllAudioInputDevices() -> [AudioDevice] {
        return inputDevices
    }
    
    // MARK: - Monitoring
    func setupListeners() {
        if propertyListenerBlock == nil {
            
            propertyListenerBlock = { [weak self] _, _ in
                self?.fetchCurrentAudioDevices()
            }
            
            guard let block = propertyListenerBlock else { return }
            
            var inputPropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var outputPropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            
            var audioPropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            
            // Listen for changes to the default input device
            AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &inputPropertyAddress,
                DispatchQueue.main,
                block
            )
            
            // Listen for changes to the default output device
            AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &outputPropertyAddress,
                DispatchQueue.main,
                block
            )
            
            AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &audioPropertyAddress,
                DispatchQueue.main,
                block
            )
        }
        
    }
    
    func removeListeners() {
        guard let block = propertyListenerBlock else { return }
        
        print("remove 리스너 호출")
        
        var inputPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var outputPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var audioPropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &inputPropertyAddress,
            DispatchQueue.main,
            block
        )
        
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &outputPropertyAddress,
            DispatchQueue.main,
            block
        )
        
        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &audioPropertyAddress,
            DispatchQueue.main,
            block
        )
    }
    
    // MARK: - Fetching Devices
    
    func fetchInitialDevices() {
        fetchCurrentAudioDevices()
    }
    
    private func fetchCurrentAudioDevices() {
        fetchDefaultDevices()
        fetchInputDevices()
    }
    
    private func fetchDefaultDevices() {
        if let inputDeviceID = getDefaultDevice(selector: kAudioHardwarePropertyDefaultInputDevice) {
            DispatchQueue.main.async {
                self.defaultInputDevice = inputDeviceID
            }
        }
        
        if let outputDeviceID = getDefaultDevice(selector: kAudioHardwarePropertyDefaultOutputDevice) {
            DispatchQueue.main.async {
                self.defaultOutputDevice = outputDeviceID
            }
        }
    }
    
    private func fetchInputDevices() {
        let devices = retrieveAllInputDevices()
        DispatchQueue.main.async {
            self.inputDevices = devices
        }
    }
    
    private func getDefaultDevice(selector: AudioObjectPropertySelector) -> AudioDeviceID? {
        var deviceID: AudioDeviceID = 0
        var propertySize = UInt32(MemoryLayout.size(ofValue: deviceID))
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )
        
        return status == noErr ? deviceID : nil
    }
    
    private func retrieveAllInputDevices() -> [AudioDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        var result = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )
        guard result == noErr else { return [] }
        
        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = Array(repeating: AudioDeviceID(), count: deviceCount)
        
        result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &audioDevices
        )
        guard result == noErr else { return [] }
        
        // Filter input devices
        let inputDeviceIDs = audioDevices.filter { isInputDevice(deviceID: $0) }
        let inputDevices = inputDeviceIDs.compactMap { deviceID -> AudioDevice? in
            let name = getDeviceName(deviceID: deviceID)
            return AudioDevice(id: deviceID, name: name)
        }
        //        print(inputDevices)
        
        return inputDevices
    }
    
    // MARK: - Helper Methods
    
    private func isInputDevice(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        return status == noErr && dataSize > 0
    }
    
    private func getDeviceName(deviceID: AudioDeviceID) -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        var dataSize: UInt32 = 0
        var result = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        guard result == noErr else { return "Unknown Device" }
        
        var name = Array(repeating: 0 as CChar, count: Int(dataSize))
        result = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &name)
        
        return result == noErr ? String(cString: name) : "Unknown Device"
    }
}
