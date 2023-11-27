import Foundation

struct NudgeEventModel {
    let appName: String
    let isInMeeting: Bool
    let windowID: Int
    
    
    var nudgeEventDictionary: [String: Any] {
        return ["appName": appName, "isInMeeting": isInMeeting, "windowID": windowID]
    }
}
