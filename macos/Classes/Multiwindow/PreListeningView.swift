import SwiftUI
import AppKit
import Lottie
import Carbon.HIToolbox

struct WindowResizeKey: EnvironmentKey {
    static let defaultValue: (CGSize) -> Void = { _ in }
}

extension EnvironmentValues {
    var resizeWindow: (CGSize) -> Void {
        get { self[WindowResizeKey.self] }
        set { self[WindowResizeKey.self] = newValue }
    }
}

struct PreListeningView: View {
    @ObservedObject var vm: ListeningViewModel
    @State private var localMonitor: Any?
    @State private var isAudioOn = true
    @State private var isVideoOn = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // VisualEffectBlur applies to the background and main content
                VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow, isActive: true, cornerRadius: 16)
                    .overlay {
                        VStack {
                            Spacer()
                            
                            if let lottiePath = vm.lottiePath {
                                LottieView(lottieFile: lottiePath, loopMode: .loop, autostart: true, contentMode: .scaleAspectFit)
                                    .frame(width: 80, height: 80)
                                    .padding(.bottom, 10)
                            } else {
                                // Handle the nil case, perhaps show a placeholder or an error message
                                Text("Loading...")
                                    .frame(width: 75, height: 75)
                                    .padding(.bottom, 20)
                            }
                            
                            Spacer()
                            // Text label
                            if let username = vm.username {
                                Text("Hey \(username), I'm ready to listen.")
                                    .foregroundStyle(Color.white)
                                    .font(.system(size: 14, weight: .bold))
                                    .fontWeight(.bold)
                                    .padding(.bottom,  20)
                            } else {
                                Text("Hey no-name-user, I'm ready to listen")
                                    .font(.system(size: 14, weight: .bold))
                                    .fontWeight(.bold)
                                    .padding(.bottom,  20)
                            }
                            
                            
                            // Start Listening Button
                            Button {
                                removeKeyMonitor()
                                vm.showListeningView = true
                                //                                vm.startMicRecording()
                                vm.isRecording = true
                                WindowManager.shared.moveWindowToBottomLeft()
                                MultiWindowStatusService.shared.sendWindowStatus(WindowStatus(windowState: .listening, isRecording: true))
                            } label: {
                                Text("Start Listening  \(vm.hotkeys)")
                                    .font(.system(size: 14, weight: .bold))
                                    .frame(width: 200, height: 30)
                                    .foregroundColor(.primaryColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5) // Adjust the cornerRadius as needed
                                    .stroke(Color.primaryColor, lineWidth: 1)
                            )
                            .background(Color.primaryColor.opacity(0.1))
                            .padding(.bottom, 20)
                            .frame(width: 200, height: 30)
                            
                            
                            
                            // Dismiss Button
                            Button {
                                print("Dismiss")
                                removeKeyMonitor()
                                WindowManager.shared.closeCurrentWindow(for: .dismiss)
                            } label: {
                                Text("Dismiss")
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            HStack {
                                Spacer()
                                // Audio Toggle
                                Toggle(isOn: $vm.isAudioSaveOn) {
                                    Text("Save Audio")
                                        .foregroundColor(.gray)
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color.primaryColor))
                                .scaleEffect(0.8)
                                .padding(.trailing, 20)
                                .onChange(of: vm.isAudioSaveOn) { newValue in
                                    vm.sendEvent(["isAudioSaveOn": newValue])
                                    MultiWindowStatusService.shared.sendWindowStatus(WindowStatus(windowState: .preListening, isRecording: false, isAudioSaveOn: newValue))
                                }
                                
                                // Video Toggle
                                Toggle(isOn: $isVideoOn) {
                                    Text("Video")
                                        .foregroundColor(.gray)
                                }
                                
                                .toggleStyle(SwitchToggleStyle(tint: .gray))
                                .scaleEffect(0.8)
                                .disabled(true)
                            }
                            .padding(.trailing, 10)
                            .padding(.vertical, 3)
                            .background(Color.bgColor.edgesIgnoringSafeArea(.all))
                        }
                        //                        .background(Color(hex: "5B5B5B"))
                        //                        .background(Color(hex: "000000"))
                    }
                    .edgesIgnoringSafeArea(.all)
            }
            // Define navigation destination here
            .navigationDestination(isPresented: $vm.showListeningView) {
                ListeningView(vm: vm)
                
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                setupKeyMonitor()
                print("PreListeningView appeared")
                //                vm.updateViewState(view: "prelisteningview")
            }
            .onDisappear(perform: {
                removeKeyMonitor()
                print("PreListeningView disappeared")
            })
        }
    }
    
    private func setupKeyMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if keyDown(with: event) {
                return nil
            } else {
                return event
            }
        }
    }
    
    private func removeKeyMonitor() {
        if let monitor = localMonitor {
            print("키모니터 이벤트 삭제!!!!!")
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
    
    private func keyDown(with event: NSEvent) -> Bool {
        if Int(event.keyCode) == kVK_Escape {
            print("Escape key pressed!")
            removeKeyMonitor()
            WindowManager.shared.closeCurrentWindow(for: .dismiss)
            return true
        } else {
            return false
        }
    }
}
