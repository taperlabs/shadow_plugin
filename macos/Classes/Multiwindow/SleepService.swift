import Foundation


import Foundation
import IOKit.pwr_mgt

final class SleepUtility {
    private static var assertionID: IOPMAssertionID = IOPMAssertionID(0)
    private static var isPreventingSleep = false
    
    // Private initializer to prevent instantiation
    private init() {}
    
    static func preventSleep() -> Bool {
        guard !isPreventingSleep else { return true }  // Already preventing sleep
        
        let reason = "Reason for preventing sleep" as CFString
        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypeNoDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &assertionID
        )
        
        print("Prevent sleep successfully \(success == kIOReturnSuccess)")
        isPreventingSleep = (success == kIOReturnSuccess)
        return isPreventingSleep
    }
    
    static func allowSleep() {
        if isPreventingSleep {
            IOPMAssertionRelease(assertionID)
            isPreventingSleep = false
            print("Sleep allowed")
        }
    }
}
