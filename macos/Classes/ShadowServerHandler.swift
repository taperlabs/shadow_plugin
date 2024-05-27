import Foundation
import Cocoa

final class ShadowServerHandler {
    
    func isAppRunning(bundleIdentifier: String) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == bundleIdentifier }
    }

    func terminateApp(bundleIdentifier: String) {
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            print(app.localizedName)
            app.forceTerminate()
            print("Application terminated successfully")
        } else {
            print("Application is not running")
        }
    }
    
    func launchShadowServer() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        
//        guard let directory = FileManager.SearchPathDirectory.from(string: "ApplicationSupportDirectory") else {
//            print("No Application Support Directory found")
//            return
//        }
//        
//        guard let directoryURL = fileManager.urls(for: directory, in: .userDomainMask).first else {
//            print("Unable to find directory URL")
//            return
//        }
        
        print("url - \(urls)")
        
        guard let applicationSupportURL = urls.first else {
            print("Could not find Application Support directory")
            return
        }
        
        print("applicationSupportURL --> \(applicationSupportURL)")
        
        let appName = "ShadowServer.app"
        let appPathURL = applicationSupportURL.appendingPathComponent("com.taperlabs.shadow").appendingPathComponent(appName)
        
        print("appPathURL --> \(appPathURL)")

        let workspace = NSWorkspace.shared
        let configuration = NSWorkspace.OpenConfiguration()
        
        workspace.openApplication(at: appPathURL, configuration: configuration) { (app, error) in
            if let error = error {
                print("Failed to launch application: \(error)")
            } else {
                print("Application launched successfully")
            }
        }
    }
}
