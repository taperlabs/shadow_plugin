import Foundation

//MARK: - Event Data Model To Flutter
struct RecordingStatusEventModel {
    let type: EventChannelAction
    let isRecording: Bool
    let elapsedTime: Int
    
    //recordingStatus dictionary (computed property)
    var recordingStatusDictionary: [String: Any] {
        return ["type": type.rawValue, "isRecording": isRecording, "elapsedTime": elapsedTime]
    }
}

//MARK: - MOCK DATA MODEL
struct DataModel {
    static let sharedValue: String = "phoenix from DataModel"
    
    static let sharedValue2: [String] = ["Hello World"]
}


