import Foundation
import AppKit
import SwiftUI

enum WindowNames: String, CaseIterable {
    case listening = "listening"
    case preListening = "preListening"
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
    
    // Method to update the window position
    func moveWindowToBottomLeft() {
        guard let window = currentWindow else {
            print("No window available to move")
            return
        }
        
        // Get screen size and window size
        if let screen = NSScreen.main {
            let screenFrame = screen.frame
            let windowSize = window.frame.size

            // Calculate the bottom-left position
            let xPos = screenFrame.minX + 50
            let yPos = screenFrame.minY - 20

            // Set the window's new position
            window.setFrameOrigin(NSPoint(x: xPos, y: yPos))
        }
    }
    
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

    
    func hotkeyPressed() {
        print("Hotkey pressed in AppDelegate")
    }
    
    func createWindow(with viewState: String) {
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
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
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
            
            newWindow.isReleasedWhenClosed = false
            
            let resizeWindow: (CGSize) -> Void = { [weak self] newSize in
                self?.resizeWindow(to: newSize, window: newWindow)
            }
            
            if viewState == "preview" {
                let preListeningView = PreListeningView(vm: listeningVM)
                    .environment(\.resizeWindow, resizeWindow)
                let hostingView = NSHostingView(rootView: preListeningView)
                newWindow.contentView = hostingView
            } else {
                let listeningView = RealListeningView(vm: listeningVM)
                let hostingView = NSHostingView(rootView: listeningView)
                newWindow.contentView = hostingView
            }
            
      
            
            
            self.currentWindow = newWindow
            //            self.windows[newWindowId] = newWindow
            print("Assigned newWindow to windows with ID \(newWindowId).")
            // Center the window on screen
            
            
            if viewState == "preview" {
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
                    let yPos = screenFrame.minY + 50
                    
                    // Set the window's new position
                    newWindow.setFrameOrigin(NSPoint(x: xPos, y: yPos))
                }
            }

            print("New window has been created and configured with ID \(newWindowId).")
        }
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
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        print("Window should close called")
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        print("Window is closing")
        self.currentWindow = nil
        self.listeningViewModel = nil
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        print("Window became key: \(notification)")
    }
}
