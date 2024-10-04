import SwiftUI
import Combine

struct RealListeningView: View {
    @ObservedObject var vm: ListeningViewModel
    @State private var showingCancelConfirmation = false
    
    
    @State private var expand = false
    @State private var selectedDevice: AudioDevice?
    
    @State private var countdownNumber: Int? = nil
    @State private var countdownTimer: AnyCancellable? = nil
    
    var body: some View {
        VStack(spacing: 16) { // The vertical gap between the dropdown and the buttons
            // Dropdown or input source
            VisualEffectBlur(material: .menu, blendingMode: .behindWindow, isActive: true, cornerRadius: 16)
                .overlay {
                    //                    CustomDropdown2()
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(vm.defaultInputDeviceName)
                            Spacer()
                            Image(systemName: expand ? "chevron.up" : "chevron.down")
                        }
                        .padding(10)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .onTapGesture {
                            withAnimation(.spring()) {
                                self.expand.toggle()
                            }
                        }
                        
                        if expand {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(vm.inputDevices, id: \.id) { device in
                                        Text(device.name)
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .foregroundColor(selectedDevice?.id == device.id ? .primaryColor : .white)
                                            .onTapGesture {
                                                self.selectedDevice = device
                                                vm.setDefaultAudioInputDevice(with: device.name)
                                                withAnimation(.spring()) {
                                                    self.expand = false
                                                }
                                            }
                                    }
                                }
                            }
                            .frame(maxHeight: vm.inputDevices.count >= 5 ? 200 : CGFloat(vm.inputDevices.count * 40))
                            .cornerRadius(10)
                            .offset(y: -5)
                        }
                    }
                    .frame(maxWidth: 200, maxHeight: expand ? .infinity : 50) // Adjust frame height based on expand state
                    .animation(.spring(), value: expand)
                }
                .opacity(0.8)
            
            
            
            
            // The HStack containing the timer and action buttons
            VisualEffectBlur(material: .popover, blendingMode: .behindWindow, isActive: true, cornerRadius: 16)
                .overlay {
                    HStack(alignment: .center,spacing: 20) { // Adjust spacing between items in HStack
                        // Timer View
                        VStack {
                            if let count = countdownNumber {
                                // Countdown View
                                Text("\(count)")
                                    .frame(width: 30, height: 30)
                                    .font(.largeTitle)
                                    .transition(.scale)
                                    .animation(.easeInOut)
                                    .onAppear {
                                        startCountdown()
                                    }
                            } else {
                                ProgressiveFillShadowLogo(fillLevel: CGFloat(vm.noiseLevel), fillColor: Color.primaryColor)
                                    .frame(width: 30, height: 30)
                                
                                Text(formatTime(vm.currentTime))
                                    .font(.caption)
                            }
                        }
                        
                        
                        VStack {
                            Button(action: {
                                // Done action + Close Main Window
                                vm.stopMicRecording()
                                //                                RealWindowManager.shared.closeWindow()
                                WindowManager.shared.currentWindow?.close()
                            }) {
                                if let donePath = vm.donePath, let doneImage = NSImage(contentsOfFile: donePath) {
                                    Image(nsImage: doneImage)
                                } else {
                                    Text("Image not found")
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 30, height: 30)
                            Text("Done")
                                .font(.caption)
                        }
                        
                        VStack {
                            Button(action: {
                                print("Cancel Clicked")
                                //Cancel Confirmation only if 3 seconds buffer time is not on.
                                if countdownTimer == nil {
                                    showingCancelConfirmation = true
                                } else {
                                    WindowManager.shared.currentWindow?.close()
                                }
                                // Cancel action
                            }) {
                                if let cancelImage = NSImage(contentsOfFile: vm.cancelPath!) {
                                    Image(nsImage: cancelImage) // Use the NSImage in SwiftUI
                                } else {
                                    Text("Image not found")
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 30, height: 30)
                            Text("Cancel")
                                .font(.caption)
                        }
                        
                        Divider()
                            .frame(height: 40) // Adjust height of the divider
                        
                        VStack {
                            Button(action: {
                                print("miniaturize")
                                WindowManager.shared.miniaturizeWindow()
                            }) {
                                if let minimizeImage = NSImage(contentsOfFile: vm.minimizePath!) {
                                    Image(nsImage: minimizeImage) // Use the NSImage in SwiftUI
                                } else {
                                    Text("Image not found")
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .frame(width: 30, height: 30)
                            Text("Minimize")
                                .font(.caption)
                        }
                    }
                }
        }
        .onAppear(perform: {
            print("real listening View appeared")
            startCountdownRecording()
            vm.setAudioDeviceListener()
        })
        .onDisappear(perform: {
            print("real listening View disappeared")
            vm.removeAudioDeviceListener()
        })
        .frame(maxWidth: 250, maxHeight: 200)
        .ignoresSafeArea(.all)
    }
    
    /// Initiates the countdown before starting recording
    func startCountdownRecording() {
        countdownNumber = 3
    }
    
    /// Handles the countdown logic
    func startCountdown() {
        // Ensure only one timer is running
        countdownTimer?.cancel()
        
        // Create a Timer publisher that emits every second
        countdownTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if let current = countdownNumber {
                    if current > 1 {
                        countdownNumber = current - 1
                    } else {
                        countdownNumber = nil
                        countdownTimer?.cancel()
                        countdownTimer = nil
                        // Start recording after countdown
                        vm.startMicRecording()
                    }
                }
            }
    }
    
    func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
