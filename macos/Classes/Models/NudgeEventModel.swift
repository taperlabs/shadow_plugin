import Foundation

struct NudgeEventModel {
    let appName: String
    let isInMeeting: Bool
    let windowID: Int
    let googleMeetID: String?
    
    init(appName: String, isInMeeting: Bool, windowID: Int, googleMeetID: String? = nil) {
        self.appName = appName
        self.isInMeeting = isInMeeting
        self.windowID = windowID
        self.googleMeetID = googleMeetID
    }
    
    
    var nudgeEventDictionary: [String: Any] {
         var dict: [String: Any] = ["appName": appName, "isInMeeting": isInMeeting, "windowID": windowID]
         if let meetID = googleMeetID {
             dict["googleMeetID"] = meetID
         }
         return dict
     }
}
