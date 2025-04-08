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
        let oldAddress = self.listeningViewModel != nil ?
        "\(Unmanaged.passUnretained(self.listeningViewModel!).toOpaque())" : "nil"
        let newAddress = "\(Unmanaged.passUnretained(listeningViewModel).toOpaque())"
        
        print("WindowManager changing viewModel from \(oldAddress) to \(newAddress)")
        
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
            let xPos = screenFrame.minX + 20
            let yPos = screenFrame.minY + 40
            
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
    
    func createListeningWindow() {
        print("Creating a Listening Window")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                return
            }
            
            if self.currentWindow != nil {
                self.currentWindow = nil
            }
            
            guard let listeningVM = self.listeningViewModel else {
                print("ListeningViewModel is not available")
                fatalError("[WindowManager] ListeningViewModel is not available")
            }
            
            let listeningWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 240, height: 150),
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView, .borderless],
                backing: .buffered,
                defer: false,
                screen: .main
            )
            
            listeningWindow.level = .floating
            listeningWindow.orderFront(nil)
            listeningWindow.titlebarSeparatorStyle = .none
            listeningWindow.standardWindowButton(.closeButton)?.isHidden = true
            listeningWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
            listeningWindow.standardWindowButton(.zoomButton)?.isHidden = true
            listeningWindow.titlebarAppearsTransparent = true
            listeningWindow.titleVisibility = .hidden
            listeningWindow.backgroundColor = .clear
            listeningWindow.isMovableByWindowBackground = true
            listeningWindow.delegate = self
            listeningWindow.hasShadow = false
            
            listeningWindow.contentView?.wantsLayer = true
            listeningWindow.contentView?.layer?.cornerRadius = 0
            listeningWindow.isOpaque = false
            
            listeningWindow.isReleasedWhenClosed = false
            
            let listeningView = NewListeningView(viewModel: listeningVM)
            let hostingView = NSHostingView(rootView: listeningView)
            listeningWindow.contentView = hostingView
            self.updateWindowState(.listening, isRecording: true)
            MultiWindowStatusService.shared.sendWindowStatus(WindowStatus(windowState: .listening, isRecording: true))
            
            self.currentWindow = listeningWindow
            
            
            guard let app = NSApplication.shared.delegate as? FlutterAppDelegate else {
                debugPrint("failed to find flutter main window, application delegate is not FlutterAppDelegate")
                return
            }
            guard let mainFlutterWindow = app.mainFlutterWindow else {
                debugPrint("failed to find flutter main window")
                return
            }
            
            
            // 메인 Flutter 앱 윈도우의 프레임 정보 로깅
            let mainWindowFrame = mainFlutterWindow.frame
            let contentFrame = mainFlutterWindow.contentView?.frame
            
            print("Main Flutter Window frame: \(mainWindowFrame)")
            print("Main Flutter Content frame: \(contentFrame ?? CGRect.zero)")
            print("Main Flutter Window - Position ✅: (\(mainWindowFrame.origin.x), \(mainWindowFrame.origin.y)), Size: (\(mainWindowFrame.size.width), \(mainWindowFrame.size.height))")
            
            if let screen = NSScreen.main {
                let visibleFrame = screen.visibleFrame
                let screenFrame = screen.frame
                let windowSize = listeningWindow.frame.size
                
                // X 위치: 오른쪽에 최대한 붙임
                let xPos = visibleFrame.origin.x + visibleFrame.width - windowSize.width
                
                // Y 위치: visible frame의 정중앙에 위치시킴
                let yPos = visibleFrame.origin.y + (visibleFrame.height - windowSize.height) / 2
                
                print("Screen frame: \(screenFrame)")
                print("Visible frame: \(visibleFrame)")
                print("Window size: \(windowSize)")
                print("Calculated position: (\(xPos), \(yPos))")
                
                // 윈도우 위치 설정
                listeningWindow.setFrameOrigin(NSPoint(x: xPos, y: yPos))
                
                // 설정 후 위치 확인
                print("Current window position after: \(listeningWindow.frame.origin)")
                print("Window is visible: \(listeningWindow.isVisible)")
                print("Window level: \(listeningWindow.level.rawValue)")
                
                print("Window bottom edge will be at: \(yPos)")
                print("Window top edge will be at: \(yPos + windowSize.height)")
                print("Visible frame bottom: \(visibleFrame.origin.y)")
                print("Visible frame top: \(visibleFrame.origin.y + visibleFrame.height)")
            }
            
//            if let screen = NSScreen.main {
//                // 실제 사용 가능한 화면 영역 (dock, 메뉴바 등 제외)
//                let visibleFrame = screen.visibleFrame
//                let screenFrame = screen.frame
//                let windowSize = listeningWindow.frame.size
//                
//                // x축으로는 오른쪽에 최대한 붙이고, y축으로는 중앙에 위치
//                let xPos = visibleFrame.origin.x + visibleFrame.width - windowSize.width
//                let yPos = visibleFrame.origin.y + (visibleFrame.height - windowSize.height) / 2
//                
//                // 디버깅을 위한 자세한 로깅
//                print("Screen frame: \(screenFrame)")
//                print("Visible frame: \(visibleFrame)")
//                print("Window size: \(windowSize)")
//                print("Calculated position: (\(xPos), \(yPos))")
//                
//                // 다른 방법 시도 - 작은 여백 추가
//                let margin: CGFloat = 0  // 필요시 조정
//                let finalX = xPos - margin
//                let finalY = yPos
//                
//                print("Final position with margin: (\(finalX), \(finalY))")
//                
//                // 윈도우 위치 설정 전에 현재 위치 확인
//                print("Current window position before: \(listeningWindow.frame.origin)")
//                
//                // 윈도우 위치 설정
//                listeningWindow.setFrameOrigin(NSPoint(x: finalX, y: finalY))
//                
//                // 설정 후 위치 확인
//                print("Current window position after: \(listeningWindow.frame.origin)")
//                
//                // 추가 확인을 위한 윈도우 속성 확인
//                print("Window is visible: \(listeningWindow.isVisible)")
//                print("Window level: \(listeningWindow.level.rawValue)")
//            }
            
            //            // Flutter 메인 윈도우의 크기를 코드와 일치시킴
            //            let mainWindowWidth: CGFloat = 400
            //            let mainWindowHeight: CGFloat = 800  // 840에서 830으로 수정 (Flutter 코드에 맞춤)
            //
            //            if let screen = NSScreen.main {
            //                let visibleFrame = screen.visibleFrame  // 메뉴바, 독 등을 제외한 실제 사용 가능 영역
            //
            //                // Flutter 코드와 동일한 계산 방식 사용
            //                let mainWindowX = visibleFrame.origin.x + visibleFrame.width - mainWindowWidth
            //                let mainWindowY = visibleFrame.origin.y + (visibleFrame.height - mainWindowHeight) / 2
            //
            //                debugPrint("Expected main window position: (\(mainWindowX), \(mainWindowY))")
            //
            //                // listeningWindow 크기
            //                let windowSize = listeningWindow.frame.size
            //
            //                // 메인 윈도우 우측 하단에 배치
            //                let xPos = mainWindowX + mainWindowWidth - windowSize.width
            //                let yPos = mainWindowY
            //
            //                // 패딩 추가
            //                let xPadding: CGFloat = 10
            //                let yPadding: CGFloat = 10
            //                let xPosWithPadding = xPos - xPadding
            //                let yPosWithPadding = yPos + yPadding
            //
            //                debugPrint("Positioning listeningWindow at: (\(xPosWithPadding), \(yPosWithPadding))")
            //                listeningWindow.setFrameOrigin(NSPoint(x: xPosWithPadding, y: yPosWithPadding))
            //            }
            
            //            if let screen = NSScreen.main {
            //                let screenFrame = screen.frame
            //                let visibleFrame = screen.visibleFrame
            //                let scaleFactor = screen.backingScaleFactor
            //                let windowSize = listeningWindow.frame.size
            //
            //                print("Screen frame: \(screenFrame)")
            //                print("Visible frame: \(visibleFrame)")
            //                print("Backing scale factor: \(scaleFactor)")
            //
            //                let dockDifference = CGSize(
            //                    width: screenFrame.width - visibleFrame.width,
            //                    height: screenFrame.height - visibleFrame.height
            //                )
            //                print("Dock/menubar space: \(dockDifference)")
            //
            //                // 화면 좌표 변환 검증
            //                let flippedYOrigin = screenFrame.height - (mainWindowFrame.origin.y + mainWindowFrame.size.height)
            //                print("Y origin (flipped): \(flippedYOrigin)")
            //
            //                // 메인 Flutter 윈도우의 우측 하단 좌표 계산
            //                let xPos = mainWindowFrame.origin.x + mainWindowFrame.size.width - windowSize.width
            //                let yPos = mainWindowFrame.origin.y
            //
            //                // main Flutter 윈도우의 우측 하단 좌표 계산 (정확히)
            //                let mainWindowBottomRightX = mainWindowFrame.origin.x + mainWindowFrame.size.width
            //                let mainWindowBottomRightY = mainWindowFrame.origin.y
            //
            //                // ListeningWindow 배치 (우측에 약간 간격을 두고)
            //                let listeningWindowX = mainWindowBottomRightX - windowSize.width
            //                let listeningWindowY = mainWindowBottomRightY
            //
            //
            //
            //                // 로그 출력
            //                debugPrint("Main window bottom right: (\(mainWindowBottomRightX), \(mainWindowBottomRightY))")
            //                debugPrint("Setting listening window to: (\(listeningWindowX), \(listeningWindowY))")
            //
            //
            //                // 적절한 간격 추가 (필요시 조정)
            //                let padding: CGFloat = 20
            //                let xPosWithPadding = xPos - padding
            //                let yPosWithPadding = yPos + padding
            //
            //                let newX = mainWindowBottomRightX - windowSize.width - padding
            //                let newY = mainWindowBottomRightY + padding
            //
            //                // 추가적인 로깅
            //                print("Final position for listening window: (\(newX), \(newY))")
            //
            //                // 로그 출력
            ////                debugPrint("New listeningWindow Position 🦊: (\(xPosWithPadding), \(yPosWithPadding))")
            //
            //                // 새 윈도우 위치 설정
            ////                listeningWindow.setFrameOrigin(NSPoint(x: xPosWithPadding, y: yPosWithPadding))
            //                listeningWindow.setFrameOrigin(NSPoint(x: newX, y: newY))
            //            }
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
            
            //TODO: - PreListeningView 제거 해야함
            //            if viewState == .preListening {
            //                let preListeningView = PreListeningView(vm: listeningVM)
            //                    .environment(\.resizeWindow, resizeWindow)
            //                let hostingView = NSHostingView(rootView: preListeningView)
            //                newWindow.contentView = hostingView
            //                self.updateWindowState(.preListening, isRecording: false)
            //                MultiWindowStatusService.shared.sendWindowStatus(WindowStatus(windowState: .preListening, isRecording: false))
            //                newWindow.makeKeyAndOrderFront(nil)
            //                NSApp.activate(ignoringOtherApps: true)
            //            } else {
            //                let listeningView = ListeningView(vm: listeningVM)
            //                let hostingView = NSHostingView(rootView: listeningView)
            //                newWindow.contentView = hostingView
            //                self.updateWindowState(.listening, isRecording: true)
            //                MultiWindowStatusService.shared.sendWindowStatus(WindowStatus(windowState: .listening, isRecording: true))
            //            }
            
            let listeningView = ListeningView(vm: listeningVM)
            let hostingView = NSHostingView(rootView: listeningView)
            newWindow.contentView = hostingView
            self.updateWindowState(.listening, isRecording: true)
            MultiWindowStatusService.shared.sendWindowStatus(WindowStatus(windowState: .listening, isRecording: true))
            
            
            
            
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
                    let xPos = screenFrame.minX + 20
                    let yPos = screenFrame.minY + 40
                    
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
        
        // First save a reference to avoid early deallocation
        let windowToClose = currentWindow
        
        // Update state
        //        MultiWindowStatusService.shared.sendWindowStatus(WindowStatus(windowState: .closed, isRecording: false, windowCloseType: windowCloseType))
        
        // Clear references BEFORE closing to ensure proper cleanup order
        // IMPORTANT: Clear the listeningViewModel reference BEFORE closing the window
        self.listeningViewModel = nil
        self.currentWindow = nil
        
        // Now actually close the window
        windowToClose.close()
        
        //        let emptyView = NSHostingView(rootView: Text(""))
        //        currentWindow.contentView = emptyView
        
        print("Closing the current Window \(windowCloseType.rawValue)")
        //        currentWindow.close()
        
        guard let app = NSApplication.shared.delegate as? FlutterAppDelegate else {
            debugPrint("failed to find flutter main window, application delegate is not FlutterAppDelegate")
            return
        }
        guard let mainFlutterWindow = app.mainFlutterWindow else {
            debugPrint("failed to find flutter main window")
            return
        }
        if windowCloseType == .dismiss {
            //            print("아하아하 \( app.mainFlutterWindow?.isKeyWindow)")
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
        let isMainWindowMinimized = mainFlutterWindow.isMiniaturized
        
        print("isMainWindowMinimized", isMainWindowMinimized)
        
        //Main Window가 minimized인 상태면 orderOut으로 처리해야 함
        if isMainWindowMinimized {
            mainFlutterWindow.orderOut(nil)
            return
        }
        
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
        
        print(CFGetRetainCount(listeningViewModel as CFTypeRef))
        
        //        MultiWindowStatusService.shared.sendWindowStatus(WindowStatus(windowState: .closed, isRecording: false))
        self.listeningViewModel = nil
    }
    
    func windowDidBecomeKey(_ notification: Notification) {
        print("Window became key: \(notification)")
    }
}
