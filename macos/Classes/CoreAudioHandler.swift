import Foundation
import CoreAudio

//MARK: - Core Audio 관련 로직 처리 핸들러
class CoreAudioHandler {
    var deviceListWithStringNames: Set<String> = Set<String>()
    
    func getDefaultAudioInputDevice() -> AudioDeviceID? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        
        
        var deviceID = AudioDeviceID()
        var dataSize = UInt32(MemoryLayout.size(ofValue: deviceID))
        
        let result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceID)
        
        return result == noErr ? deviceID : nil
    }

    
    func getInputDeviceID(fromName name: String) -> AudioDeviceID? {
        let allDevices = getAllAudioInputDevices()
        for device in allDevices {
            let deviceName = getDeviceName(deviceID: device)
            if deviceName == name {
                return device
            }
        }
        return nil
    }
    
    func setAudioInputDevice(deviceID: AudioDeviceID) -> Bool {
        var deviceID = deviceID
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
            &deviceID
        )

        return result == noErr
    }
    
    func getAllAudioInputDevicesByNames() -> Set<String> {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var dataSize: UInt32 = 0
        var result = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        guard result == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = Array(repeating: AudioDeviceID(), count: deviceCount)

        result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &audioDevices)
        guard result == noErr else { return [] }

        // Filter out non-input devices and log them
        let inputDevices = audioDevices.filter { isInputDevice(deviceID: $0) }
        for device in inputDevices {
            let name = getDeviceName(deviceID: device)
            deviceListWithStringNames.insert(name)
            print("deviceListWithStringNaems :", deviceListWithStringNames)
            print("Detected input device: ID = \(device), Name = \(name)", type(of: name))
        }
        return deviceListWithStringNames
    }
    
    func getAllAudioInputDevices() -> [AudioDeviceID] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var dataSize: UInt32 = 0
        var result = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        guard result == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = Array(repeating: AudioDeviceID(), count: deviceCount)

        result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &audioDevices)
        guard result == noErr else { return [] }

        // Filter out non-input devices and log them
        let inputDevices = audioDevices.filter { isInputDevice(deviceID: $0) }
        for device in inputDevices {
            let name = getDeviceName(deviceID: device)
            deviceListWithStringNames.insert(name)
            print("deviceListWithStringNaems :", deviceListWithStringNames)
            print("Detected input device: ID = \(device), Name = \(name)", type(of: name))
        }
        return inputDevices
    }
    
    // Function to determine if a device is an input device
    func isInputDevice(deviceID: AudioDeviceID) -> Bool {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain)

        var dataSize: UInt32 = 0
        let status = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        return status == noErr && dataSize > 0
    }
    
    func getDeviceName(deviceID: AudioDeviceID) -> String {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var dataSize: UInt32 = 0
        var result = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
        guard result == noErr else { return "Unknown Device" }

        var name = [CChar](repeating: 0, count: Int(dataSize))
        result = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &name)

        if result == noErr {
            if let deviceName = String(cString: name, encoding: .utf8) {
                return deviceName + "마이크"
            }
        }

        return "Unknown Device"
    }
    
    
//    func getDeviceName(deviceID: AudioDeviceID) -> String {
//        var propertyAddress = AudioObjectPropertyAddress(
//            mSelector: kAudioDevicePropertyDeviceName,
//            mScope: kAudioObjectPropertyScopeGlobal,
//            mElement: kAudioObjectPropertyElementMain)
//
//        var dataSize: UInt32 = 0
//        var result = AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize)
//        guard result == noErr else { return "Unknown Device" }
//
//        var name = Array(repeating: 0 as CChar, count: Int(dataSize))
//        result = AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &name)
//
//        return result == noErr ? String(cString: name) : "Unknown Device"
//    }
    
    
    func getAllAudioDevices() -> [AudioDeviceID] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        var dataSize: UInt32 = 0
        var result = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize)
        guard result == noErr else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var audioDevices = Array(repeating: AudioDeviceID(), count: deviceCount)

        result = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &dataSize, &audioDevices)
        guard result == noErr else { return [] }
        
        print("audioDevices", audioDevices)

        return audioDevices
    }
}
