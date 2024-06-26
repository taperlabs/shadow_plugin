import Foundation
import Cocoa
import FlutterMacOS

final class ShadowServerHandler {
    private let appBundleID = "com.taperlabs.shadowServer"
    private let appName = "ShadowHelper.app"
    private let applicationSupportPath = "com.taperlabs.shadow"
    
    private var appPathURL: URL? {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        guard let applicationSupportURL = urls.first else { return nil }
        return applicationSupportURL.appendingPathComponent(applicationSupportPath).appendingPathComponent(appName)
    }
    
    func isAppRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == appBundleID }
    }
    
    func launchShadowServer(result: @escaping FlutterResult) {
        guard let appPathURL = appPathURL else {
            print("Could not find Application Support directory")
            return
        }
        
        let workspace = NSWorkspace.shared
        let configuration = NSWorkspace.OpenConfiguration()
        
        workspace.openApplication(at: appPathURL, configuration: configuration) { (app, error) in
            if let error = error {
                print("Failed to launch application: \(error)")
                result("failed")
                ShadowLogger.shared.log("Failed to launch Shadow Server: \(error.localizedDescription)")
            } else {
                print("Application launched successfully")
                result("success")
                ShadowLogger.shared.log("Application launched successfully")
            }
        }
    }
    
    func terminateApp() {
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.bundleIdentifier == appBundleID }) {
            print(app.localizedName ?? "Unknown application")
            
            // Attempt to terminate cleanly
            app.forceTerminate()
            ShadowLogger.shared.log("App termination requested")
            
            // Allow some time for the app to terminate gracefully
//            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
//                if app.isTerminated {
//                    print("Application terminated successfully")
//                } else {
//                    // Fallback to force termination
//                    app.forceTerminate()
//                    print("Application forcibly terminated")
//                }
//            }
        } else {
            print("Application is not running")
        }
    }
}
