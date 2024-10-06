import SwiftUI
import AppKit
import Lottie

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
    
    @State private var isAudioOn = true
    @State private var isVideoOn = false
//    @State private var showListeningView = false
    var body: some View {
        NavigationStack {
            ZStack {
                // VisualEffectBlur applies to the background and main content
                VisualEffectBlur(material: .menu, blendingMode: .behindWindow, isActive: true, cornerRadius: 16)
                    .overlay {
                        VStack {
                            Spacer()
                            
                            LottieView(lottieFile: vm.lottiePath!, loopMode: .loop, autostart: true, contentMode: .scaleAspectFit)
                                .frame(width: 75, height: 75)
                                .padding(.bottom, 20)
                            // Text label
                            if let username = vm.username {
                                Text("Hey \(username), I'm ready to listen.")
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
                                vm.showListeningView = true
//                                vm.startMicRecording()
                                vm.isRecording = true
                                WindowManager.shared.moveWindowToBottomLeft()
                            } label: {
                                Text("Start Listening  ⌃ ⌘")
                                    .font(.system(size: 14, weight: .bold))
                                    .frame(width: 200, height: 30)
                                    .foregroundColor(.primaryColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.primaryColor, lineWidth: 1)
                            )
                            .background(Color.primaryColor.opacity(0.1))
                            .padding(.bottom, 20)
                            .frame(width: 200, height: 30)

                            // Dismiss Button
                            Button {
                                print("Dismiss")
                            } label: {
                                Text("Dismiss")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Spacer()
                            HStack {
                                Spacer()
                                // Audio Toggle
                                Toggle(isOn: $isAudioOn) {
                                    Text("Save Audio")
                                        .foregroundColor(.gray)
                                }
                                .toggleStyle(SwitchToggleStyle(tint: Color.primaryColor))
                                .padding(.trailing, 20)
                                .onChange(of: isAudioOn) { newValue in
                                    let oldValue = isAudioOn
                                    vm.sendEvent(["isAudioOn": newValue])
                                    // Use `oldValue` here if needed
                                }

                                // Video Toggle
                                Toggle(isOn: $isVideoOn) {
                                    Text("Video")
                                        .foregroundColor(.gray)
                                }
                                
                                .toggleStyle(SwitchToggleStyle(tint: .gray))
                                .disabled(true)
                            }
                            .padding(.trailing, 20)
                            .background(Color.bgColor.edgesIgnoringSafeArea(.all))
                        }
                    }
                    .edgesIgnoringSafeArea(.all)
            }
            .navigationDestination(isPresented: $vm.showListeningView) {
                RealListeningView(vm: vm)
                
            }
            .navigationBarBackButtonHidden(true)
            .onAppear {
                print("PreListeningView appeared")
            }
            .onDisappear{
                print("PreListeningView appeared")
            }

        }
    }
}
