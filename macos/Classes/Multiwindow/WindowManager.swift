import Foundation
import AppKit
import SwiftUI
import FlutterMacOS

enum WindowViewState: String, CaseIterable {
    case listening = "listening"
    case preListening = "preListening"
}

enum WindowCloseType: String {
    case done = "done"
    case cancel = "cancel"
    case dismiss = "dismiss"
}


final class WindowManager: NSObject, NSWindowDelegate {
    // Singleton instance
    static let shared = WindowManager()
    
    var windows: [Int64: NSWindow] = [:]
    var nextWindowId: Int64 = 1
    var listeningViewModel: ListeningViewModel?
    var currentWindow: NSWindow?
    
    // Private initializer to prevent creating additional instances
    private override init() {
        print("Window Manager has been initialized..")
        super.init()
    }
    
    deinit {
        print("Window Manager has been deinitialized.")
    }
    
    func updateWindowState(_ state: WindowState, isRecording: Bool) {
        let eventData: [String: Any] = [
            "windowState": state.rawValue,
            "isRecording": isRecording
        ]
        
        print("updateWindowState 불렸습니다~~ \(eventData)")
        listeningViewModel?.sendEvent(eventData)
    }
    
    // Setup method to initialize or update the listeningViewModel
    func setListeningViewModel(listeningViewModel: ListeningViewModel) {
        self.listeningViewModel = listeningViewModel
        print("WindowManager setup with ListeningViewModel")
    }
    
    // Method to miniaturize the window
    func miniaturizeWindow() {
        guard let window = currentWindow else {
            print("No window available to miniaturize")
            return
        }
        window.miniaturize(nil)
    }
    
    func moveWindowToBottomLeft(completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            guard let window = self.currentWindow else {
                print("No window available to move")
                completion?()
                return
            }
            
            guard let screen = NSScreen.main else {
                print("No main screen available")
                completion?()
                return
            }
            
            let screenFrame = screen.frame
            let windowSize = window.frame.size
            
            // Calculate the bottom-left position
            let xPos = screenFrame.minX + 50
            let yPos = screenFrame.minY + 70
            
            // Create the target frame
            let newFrame = NSRect(x: xPos, y: yPos, width: windowSize.width, height: windowSize.height)
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.3  // Animation duration in seconds
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(newFrame, display: true)
            }, completionHandler: completion)
        }
    }
    
    // Method to update the window position
//    func moveWindowToBottomLeft() {
//        guard let window = currentWindow else {
//            print("No window available to move")
//            return
//        }
//        
//        // Get screen size and window size
//        if let screen = NSScreen.main {
//            let screenFrame = screen.frame
//            let windowSize = window.frame.size
//            
//            // Calculate the bottom-left position
//            let xPos = screenFrame.minX + 50
//            let yPos = screenFrame.minY + 60
//            
//            // Set the window's new position
//            window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
//        }
//    }
    
    func setupGlobalHotkeyMonitor() {
        let mask: NSEvent.EventTypeMask = [.keyDown]
        print(mask)
        NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handleKeyEvent)
    }
    
    func handleKeyEvent(event: NSEvent) {
        print(event)
        switch event.type {
        case .keyDown:
            let keyCode = event.keyCode
            let modifierFlags = event.modifierFlags
            print("Key pressed: \(keyCode), Modifiers: \(modifierFlags)")
            if keyCode == 36 && modifierFlags.contains(.command) {
                // Command + 6 was pressed
                // Perform your desired action here
            }
        default:
            break
        }
    }
    
    func resizeWindow(to newSize: CGSize, window: NSWindow) {
        let frame = NSRect(origin: window.frame.origin, size: newSize)
        window.setFrame(frame, display: true, animate: true)
        
        // Re-center the window after resizing
        if let screen = window.screen {
            let newOrigin = NSPoint(
                x: screen.frame.midX - newSize.width / 2,
                y: screen.frame.midY - newSize.height / 2
            )
            window.setFrameOrigin(newOrigin)
        }
    }
    
    func createWindow(with viewState: WindowViewState) {
        print("Creating a new window... with \(viewState)")
        
        DispatchQueue.main.async {
            let newWindowId = self.nextWindowId
            self.nextWindowId += 1
            if self.currentWindow != nil {
                self.currentWindow = nil
            }
            
            guard let listeningVM = self.listeningViewModel else {
                print("ListeningViewModel is not available.")
                return
            }
            
            var newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 300),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView, .borderless],
                backing: .buffered,
                defer: false,
                screen: .main
            )
            
            newWindow.level = .floating
            newWindow.orderFront(nil)
            newWindow.titlebarSeparatorStyle = .none
            newWindow.standardWindowButton(.closeButton)?.isHidden = true
            newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
            newWindow.standardWindowButton(.zoomButton)?.isHidden = true
            newWindow.titlebarAppearsTransparent = true
            newWindow.titleVisibility = .hidden
            newWindow.backgroundColor = .clear
            newWindow.isMovableByWindowBackground = true
            newWindow.delegate = self
            newWindow.hasShadow = false
            
            newWindow.contentView?.wantsLayer = true
            newWindow.contentView?.layer?.cornerRadius = 0
            //            newWindow.contentView?.layer?.masksToBounds = true
            newWindow.isOpaque = false
            
            newWindow.isReleasedWhenClosed = false
            
            let resizeWindow: (CGSize) -> Void = { [weak self] newSize in
                self?.resizeWindow(to: newSize, window: newWindow)
            }
            
            if viewState == .preListening {
                let preListeningView = PreListeningView(vm: listeningVM)
                    .environment(\.resizeWindow, resizeWindow)
                let hostingView = NSHostingView(rootView: preListeningView)
                newWindow.contentView = hostingView
                self.updateWindowState(.preListening, isRecording: false)
                MultiWindowStatusService.shared.sendWindowStatus(WindowStatus(windowState: .preListening, isRecording: false))
                newWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                let listeningView = ListeningView(vm: listeningVM)
                let hostingView = NSHostingView(rootView: listeningView)
                newWindow.contentView = hostingView
                self.updateWindowState(.listening, isRecording: true)
                MultiWindowStatusService.shared.sendWindowStatus(WindowStatus(windowState: .listening, isRecording: true))
            }
            
            
            
            
            self.currentWindow = newWindow
            //            self.windows[newWindowId] = newWindow
            print("Assigned newWindow to windows with ID \(newWindowId).")
            // Center the window on screen
            
            
            if viewState == .preListening {
                if let screen = NSScreen.main {
                    let screenFrame = screen.frame
                    let windowSize = newWindow.frame.size
                    let xPos = screenFrame.midX - windowSize.width / 2
                    let yPos = screenFrame.midY - windowSize.height / 2
                    newWindow.setFrameOrigin(NSPoint(x: xPos, y: yPos))
                }
            } else {
                if let screen = NSScreen.main {
                    let screenFrame = screen.frame
                    let windowSize = newWindow.frame.size
                    
                    // Calculate the bottom-left position
                    let xPos = screenFrame.minX + 50
                    let yPos = screenFrame.minY + 70
                    
                    // Set the window's new position
                    newWindow.setFrameOrigin(NSPoint(x: xPos, y: yPos))
                }
            }
            
            
            
            print("New window has been created and configured with ID \(newWindowId).")
        }
    }
    
    func closeCurrentWindow(for windowCloseType: WindowCloseType ) {
        guard let currentWindow = currentWindow else {
            print("No current window exists")
            return
        }
        
        print("Closing the current Window \(windowCloseType.rawValue)")
        currentWindow.close()
        
        guard let app = NSApplication.shared.delegate as? FlutterAppDelegate else {
            debugPrint("failed to find flutter main window, application delegate is not FlutterAppDelegate")
            return
        }
        guard let mainFlutterWindow = app.mainFlutterWindow else {
            debugPrint("failed to find flutter main window")
            return
        }
        if windowCloseType == .dismiss {
            print("아하아하 \( app.mainFlutterWindow?.isKeyWindow)")
        }
        
        MultiWindowStatusService.shared.sendWindowStatus(WindowStatus(windowState: .closed, isRecording: false, windowCloseType: windowCloseType))
    }
    
    func closeWindow() {
        print("Closing the first window...")
        
        // Check if there is at least one window in the dictionary
        if let firstWindowEntry = windows.first {
            let windowId = firstWindowEntry.key
            let window = firstWindowEntry.value
            
            // Close the window
            window.close()
            
            // Remove the window from the dictionary
            windows.removeValue(forKey: windowId)
            
            print("Closed and removed window with ID \(windowId)")
        } else {
            print("No window available to close.")
        }
    }
    
    func closeWindow(windowId: Int64) {
        print("Closing window...")
        if let window = windows[windowId] {
            window.close()
        }
    }
    
    func showWindow(windowId: Int64) {
        if let window = windows[windowId] {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    func centerWindow(windowId: Int64) {
        if let window = windows[windowId] {
            window.center()
        }
    }
}

extension WindowManager {
    
    func windowDidMiniaturize(_ notification: Notification) {
        print("window is miniaturizing")
        
        guard let app = NSApplication.shared.delegate as? FlutterAppDelegate else {
            debugPrint("failed to find flutter main window, application delegate is not FlutterAppDelegate")
            return
        }
        guard let mainFlutterWindow = app.mainFlutterWindow else {
            debugPrint("failed to find flutter main window")
            return
        }
        
        print("occulusionState !!!",mainFlutterWindow.occlusionState.contains(.visible))
        let isMainWindowVisible = mainFlutterWindow.occlusionState.contains(.visible)
        
        if !isMainWindowVisible {
            mainFlutterWindow.orderBack(nil)
        }
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        print("Window should close called")
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        print("Window is closing")
        self.currentWindow = nil
        //        MultiWindowStatusService.shared.sendWindowStatus(WindowStatus(windowState: .closed, isRecording: false))
        self.listeningViewModel = nil
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        print("Window became key: \(notification)")
    }
}
