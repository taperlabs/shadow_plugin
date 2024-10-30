
import SwiftUI
import Combine

extension View {
    public func cursor(_ cursor: NSCursor) -> some View {
        if #available(macOS 13.0, *) {
            return self.onContinuousHover { phase in
                switch phase {
                case .active(_):
                    guard NSCursor.current != cursor else { return }
                    cursor.push()
                case .ended:
                    NSCursor.pop()
                }
            }
        } else {
            return self.onHover { inside in
                if inside {
                    cursor.push()
                } else {
                    NSCursor.pop()
                }
            }
        }
    }
}

// MARK: - Timer View Component
struct TimerDisplayView: View {
    let currentTime: TimeInterval
    
    var body: some View {
        Text(formatTime(currentTime))
            .foregroundStyle(Color(hex: "EEEEEE"))
            .font(.caption)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Progress Logo Component
struct ProgressLogoView: View {
    let noiseLevel: Float
    
    var body: some View {
        ProgressiveFillShadowLogo(fillLevel: CGFloat(noiseLevel), fillColor: Color.primaryColor)
            .frame(width: 25, height: 25)
            .padding(.bottom, 7)
    }
}

// MARK: - Control Button Component
struct ControlButton: View {
    let imagePath: String
    let label: String
    let isDisabled: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack {
            Button(action: action) {
                if let image = NSImage(contentsOfFile: imagePath) {
                    Image(nsImage: image)
                } else {
                    Text("Image not found")
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 30, height: 30)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1.0)
            .cursor(.pointingHand)
            .onHover { hovering in
//                if hovering && !isDisabled {
//                    NSCursor.pointingHand.push()
//                } else {
//                    NSCursor.pop()
//                }
                isHovered = hovering
            }
            
            Text(label)
                .font(.caption)
                .opacity(isDisabled ? 0.5 : 1.0)
//                .foregroundColor(Color(
//                    red: Double.random(in: 0...1),
//                    green: Double.random(in: 0...1),
//                    blue: Double.random(in: 0...1)
//                ))
                .foregroundColor(isHovered && !isDisabled ? Color(hex: "EEEEEE") : Color(hex: "BBBBBB"))
        }
    }
}

// MARK: - Modified ListeningView
struct ListeningView: View {
    @ObservedObject var vm: ListeningViewModel
    @State private var showingCancelConfirmation = false {
        didSet {
            if showingCancelConfirmation {
                isExpanded = true
            }
        }
    }
    @State private var isExpanded = false
    @State private var isForcedHover = true
    @State private var isMicSettingVisible = false
    @State private var selectedDevice: AudioDevice?
    
    var timerView: some View {
        VStack {
            if let count = vm.countdownNumber {
                Text("\(count)")
                    .foregroundStyle(Color(hex: "BBBBBB"))
                    .frame(width: 30, height: 30)
                    .font(.largeTitle)
                    .transition(.scale)
                    .animation(.easeInOut, value: 0.3)
                    .onAppear {
                        vm.startCountdown()
                    }
            } else {
                ProgressLogoView(noiseLevel: vm.noiseLevel)
                TimerDisplayView(currentTime: vm.currentTime)
            }
        }
        .frame(width: 30)
        .onHover { hovering in
            if !isForcedHover && !showingCancelConfirmation && !isExpanded {
                withAnimation(.easeOut(duration: 0.2)) {
                    isExpanded = hovering
                    if !isExpanded {
                        isMicSettingVisible = false
                    }
                }
            }
        }
    }
    
    var listeningControlsView: some View {
        HStack(alignment: .center, spacing: 25) {
            timerView
            
            if isExpanded {
                ControlButton(
                    imagePath: vm.donePath ?? "",
                    label: "Done",
                    isDisabled: vm.countdownNumber != nil
                ) {
                    vm.stopMicRecording()
                    WindowManager.shared.closeCurrentWindow(for: .done)
                }
                
                ControlButton(
                    imagePath: vm.cancelPath ?? "",
                    label: "Cancel",
                    isDisabled: false
                ) {
                    if vm.countdownTimer == nil {
                        showingCancelConfirmation = true
                    } else {
                        vm.cancelRecording()
                        WindowManager.shared.closeCurrentWindow(for: .cancel)
                    }
                }
                
                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.2))
                
                ControlButton(
                    imagePath: vm.minimizePath ?? "",
                    label: "Minimize",
                    isDisabled: false
                ) {
                    WindowManager.shared.miniaturizeWindow()
                }
            }
        }
        .padding()
        .frame(maxWidth: isExpanded ? .infinity : 70, alignment: .center)
        .frame(
            maxWidth: isExpanded ? .infinity : 75,
            maxHeight: isExpanded ? nil : 75
        )
        .background(Color.black.opacity(0.8))
        .cornerRadius(10)
    }
    
    var audioDeviceListView: some View {
          ScrollView {
              VStack(alignment: .leading, spacing: 0) {
                  ForEach(vm.inputDevices, id: \.id) { device in
                      Text(device.name)
                          .foregroundColor(selectedDevice?.id == device.id ? .primaryColor : .white)
                          .padding(.horizontal, 20)
                          .padding(.vertical, 7)
                          .frame(maxWidth: .infinity, alignment: .leading)
                          .background(Color.black.opacity(0.8))
                          .onTapGesture {
                              self.selectedDevice = device
                              vm.setDefaultAudioInputDevice(with: device.name)
                              withAnimation {
                                  isMicSettingVisible = false
                              }
                          }
                  }
              }
          }
          .frame(maxHeight: 80)
          .background(Color.black.opacity(0.8))
          .cornerRadius(8)
          .padding(.bottom, -8)
      }
      
      var currentAudioDeviceView: some View {
          Text("Input Source: \(vm.defaultInputDeviceName)")
              .font(.system(size: 12))
              .foregroundColor(Color(hex: "BBBBBB"))
              .padding()
              .padding(.vertical, 1)
              .frame(height: 40)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color.black.opacity(0.8))
              .cornerRadius(10)
              .onTapGesture {
                  withAnimation {
                      isMicSettingVisible.toggle()
                  }
              }
      }
      
      // Rest of the views remain the same...

      func startForcedExpand() {
          DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
              withAnimation {
                  self.isForcedHover = false
                  if !self.isExpanded {
                      self.isExpanded = true
                  } else {
                      self.isExpanded = false
                      isMicSettingVisible = false
                  }
              }
          }
      }
    
    var body: some View {
        VStack(spacing: 10) {
            if isMicSettingVisible && isExpanded {
                audioDeviceListView
                    .transition(.opacity)
                    .frame(height: 80)
            } else {
                Spacer()
                    .frame(height: 80)
            }
            
            if isExpanded {
                currentAudioDeviceView
            } else {
                Spacer()
            }
            
            listeningControlsView
        }
        .frame(width: 280, alignment: .leading)
        .background(Color.clear)
        .padding()
        .onHover { hovering in
            if !isForcedHover && !showingCancelConfirmation && isExpanded {
                withAnimation(.easeOut(duration: 0.2)) {
                    isExpanded = hovering
                    if !isExpanded {
                        isMicSettingVisible = false
                    }
                }
            }
        }
        .confirmationDialog("Are you sure you want to cancel?",
            isPresented: $showingCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Yes, delete", role: .destructive) {
                vm.stopMicRecording()
                WindowManager.shared.closeCurrentWindow(for: .cancel)
            }
            Button("No, keep listening", role: .cancel) {
                // dismiss dialog
            }
        } message: {
            Text("This will delete all data from the current meeting.")
        }
        .onAppear {
            print("listening View appeared")
            vm.startCountdownRecording()
            vm.setAudioDeviceListener()
            vm.isRecording = true
            isExpanded = true
            startForcedExpand()
        }
        .onDisappear {
            print("listening View disappeared")
            vm.removeAudioDeviceListener()
        }
        .ignoresSafeArea(.all)
    }
}





//import SwiftUI
//import Combine
//
//struct ListeningView: View {
//    @ObservedObject var vm: ListeningViewModel
//    @State private var showingCancelConfirmation = false {
//        didSet {
//            if showingCancelConfirmation {
//                isExpanded = true
//            }
//        }
//    }
//    @State private var expand = false
//    @State private var selectedDevice: AudioDevice?
//    @State private var isMicSettingVisible = false
//    @State private var isExpanded = false
//    @State private var isForcedHover = true
//    @State private var isDoneHover = false
//    @State private var isCancelHover = false
//    @State private var isMinimizeHover = false
//    
//    var audioDeviceListView: some View {
//        ScrollView {
//            VStack(alignment: .leading, spacing: 0) {
//                ForEach(vm.inputDevices, id: \.id) { device in
//                    Text(device.name)
//                        .foregroundColor(selectedDevice?.id == device.id ? .primaryColor : .white)
//                        .padding(.horizontal, 20)
//                        .padding(.vertical, 7)
//                        .frame(maxWidth: .infinity, alignment: .leading)
//                        .background(Color.black.opacity(0.8))
//                        .onTapGesture {
//                            self.selectedDevice = device
//                            vm.setDefaultAudioInputDevice(with: device.name)
//                            withAnimation {
//                                isMicSettingVisible = false
//                            }
//                        }
//                }
//            }
//        }
//        .frame(maxHeight: 80)
//        .background(Color.black.opacity(0.8))
//        .cornerRadius(8)
//        .padding(.bottom, -8)
//    }
//    
//    /// Current Audio Device Display View
//    var currentAudioDeviceView: some View {
//        Text("Input Source: \(vm.defaultInputDeviceName)")
//            .font(.system(size: 12))
//            .foregroundColor(Color(hex: "BBBBBB"))
//            .padding()
//            .padding(.vertical, 1)
//            .frame(height: 40)
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .background(Color.black.opacity(0.8))
//            .cornerRadius(10)
//            .onTapGesture {
//                withAnimation {
//                    isMicSettingVisible.toggle()
//                }
//            }
//    }
//    
//    var listeningControlsView: some View {
//        HStack(alignment: .center,spacing: 25) {
////            timerView
//            
//            if isExpanded {
//                doneButton
//                cancelButton
//                
//                Divider()
//                    .frame(height: 40)
//                    .background(Color.white.opacity(0.2))
//                
//                minimizeButton
//            }
//        }
//        .padding()
//        .frame(maxWidth: isExpanded ? .infinity : 70, alignment: .center)
//        .frame(
//            maxWidth: isExpanded ? .infinity : 75,  // Increased from 70 to 90
//            maxHeight: isExpanded ? nil : 75        // Added height constraint
//        )
//        .background(Color.black.opacity(0.8))
//        .cornerRadius(10)
//    }
//    
//    var timerView: some View {
//        VStack {
//            if let count = vm.countdownNumber {
//                // Countdown View
//                Text("\(count)")
//                    .foregroundStyle(Color(hex: "BBBBBB"))
//                    .frame(width: 30, height: 30)
//                    .font(.largeTitle)
//                    .transition(.scale)
//                    .animation(.easeInOut, value: 0.3)
//                    .onAppear {
//                        vm.startCountdown()
//                    }
//            } else {
//                ProgressiveFillShadowLogo(fillLevel: CGFloat(vm.noiseLevel), fillColor: Color.primaryColor)
//                    .frame(width: 25, height: 25) //logo size affects the element to move when time changes
//                    .padding(.bottom, 7)
//                
//                Text(formatTime(vm.currentTime))
//                    .foregroundStyle(Color(hex: "EEEEEE"))
//                    .font(.caption)
////                    .font(.system(.caption, design: .monospaced))
//            }
//            
//        }
//        .frame(width: 30)
//        .onHover { hovering in
//            if !isForcedHover && !showingCancelConfirmation && !isExpanded {
//                withAnimation(.easeOut(duration: 0.2)) {
//                    isExpanded = hovering
//                    if !isExpanded {
//                        isMicSettingVisible = false
//                    }
//                }
//            }
//            
//        }
//    }
//    
//    
//    
//    var doneButton: some View {
//        VStack {
//            Button(action: {
//                // Done action + Close Main Window
//                vm.stopMicRecording()
//                WindowManager.shared.closeCurrentWindow(for: .done)
//            }) {
//                if let donePath = vm.donePath, let doneImage = NSImage(contentsOfFile: donePath) {
//                    Image(nsImage: doneImage)
//                } else {
//                    Text("Image not found")
//                }
//            }
//            .buttonStyle(PlainButtonStyle())
//            .frame(width: 30, height: 30)
//            .disabled(vm.countdownNumber != nil)
//            .opacity(vm.countdownNumber != nil ? 0.5 : 1.0)
//            .foregroundColor(vm.countdownNumber != nil ? .gray : .primary)
//            .onHover { hovering in
//                print("Hover state changed: \(hovering), isKey: \(NSApp.keyWindow != nil)")
//                DispatchQueue.main.async {
//                    if hovering && vm.countdownNumber == nil {
//                        NSCursor.pointingHand.push()
//                    } else {
//                        NSCursor.pop()
//                    }
//                    isDoneHover = hovering
//                }
//            }
//
//            
//            Text("Done")
//                .font(.caption)
//                .opacity(vm.countdownNumber != nil ? 0.5 : 1.0)
//                .foregroundColor(isDoneHover && vm.countdownNumber == nil ? Color(hex: "EEEEEE") : Color(hex: "BBBBBB"))
//                .onHover { hovering in
//                    print("Hover state changed: \(hovering), isKey: \(NSApp.keyWindow != nil)")
//                    DispatchQueue.main.async {
//                        if hovering && vm.countdownNumber == nil {
//                            NSCursor.pointingHand.push()
//                        } else {
//                            NSCursor.pop()
//                        }
//                        isDoneHover = hovering
//                    }
//                }
//        }
//    }
//    
//    var cancelButton: some View {
//        VStack {
//            Button(action: {
//                print("Cancel Clicked")
//                //Cancel Confirmation only if 3 seconds buffer time is not on.
//                if vm.countdownTimer == nil {
//                    showingCancelConfirmation = true
//                } else {
//                    vm.cancelRecording()
//                    WindowManager.shared.closeCurrentWindow(for: .cancel)
//                }
//                // Cancel action
//            }) {
//                if let cancelImage = NSImage(contentsOfFile: vm.cancelPath!) {
//                    Image(nsImage: cancelImage) // Use the NSImage in SwiftUI
//                } else {
//                    Text("Image not found")
//                }
//            }
//            .buttonStyle(PlainButtonStyle())
//            .frame(width: 30, height: 30)
//            .onHover { hovering in
//                if hovering {
//                    NSCursor.pointingHand.push()
//                } else {
//                    NSCursor.pop()
//                }
//                isCancelHover = hovering
//            }
//            
//            Text("Cancel")
//                .font(.caption)
//                .foregroundColor(isCancelHover ? Color(hex: "EEEEEE") : Color(hex: "BBBBBB"))
//        }
//        
//    }
//    
//    var minimizeButton: some View {
//        VStack {
//            Button(action: {
//                print("miniaturize")
//                WindowManager.shared.miniaturizeWindow()
//            }) {
//                if let minimizeImage = NSImage(contentsOfFile: vm.minimizePath!) {
//                    Image(nsImage: minimizeImage) // Use the NSImage in SwiftUI
//                } else {
//                    Text("Image not found")
//                }
//            }
//            .buttonStyle(PlainButtonStyle())
//            .frame(width: 30, height: 30)
//            .onHover { hovering in
//                if hovering {
//                    NSCursor.pointingHand.push()
//                } else {
//                    NSCursor.pop()
//                }
//                isMinimizeHover = hovering
//            }
//            
//            Text("Minimize")
//                .font(.caption)
//                .foregroundColor(isMinimizeHover ? Color(hex: "EEEEEE") : Color(hex: "BBBBBB"))
//        }
//    }
//    
//    
//    
//    var body: some View {
//        VStack(spacing: 10) {
//            
//            if isMicSettingVisible {
//                audioDeviceListView
//                    .transition(.opacity)
//            } else {
//                Spacer()
//                    .frame(height: 80)
//            }
//            
//            // Current Audio Device Display
//            if isExpanded {
//                currentAudioDeviceView
//            } else {
//                Spacer()
//            }
//            
//            listeningControlsView
//        }
//        .frame(width: 280, alignment: .leading)
//        .background(Color.clear)
//        .padding()
//        .onHover { hovering in
//            if !isForcedHover && !showingCancelConfirmation && isExpanded {
//                withAnimation(.easeOut(duration: 0.2)) {
//                    isExpanded = hovering
//                    if !isExpanded {
//                        isMicSettingVisible = false
//                    }
//                }
//            }
//            
//        }
//        .confirmationDialog("Are you sure you want to cancel?", isPresented: $showingCancelConfirmation, titleVisibility: .visible) {
//            HStack {
//                Button("Yes, delete", role: .destructive) {
//                    vm.stopMicRecording()
//                    WindowManager.shared.closeCurrentWindow(for: .cancel)
//                }
//                Button("No, keep listening", role: .cancel) {
//                    //dismiss dialog
//                }
//            }
//            
//        } message: {
//            Text("This will delete all data from the current meeting.")
//        }
//        .onAppear(perform: {
//            print("listening View appeared")
//            vm.startCountdownRecording()
//            vm.setAudioDeviceListener()
//            vm.isRecording = true
//            isExpanded = true // Start in expanded state
//            startForcedExpand() // Start the 5-second timer
//        })
//        .onDisappear(perform: {
//            print("listening View disappeared")
//            vm.removeAudioDeviceListener()
//        })
//        //        .frame(maxWidth: 250, maxHeight: 200)
//        .ignoresSafeArea(.all)
//    }
//    
//    func startForcedExpand() {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
//            withAnimation {
//                self.isForcedHover = false
//                if !self.isExpanded {
//                    self.isExpanded = true
//                } else {
//                    self.isExpanded = false
//                    isMicSettingVisible = false
//                }
//            }
//        }
//    }
//    
//    
//    func formatTime(_ time: TimeInterval) -> String {
//        let totalSeconds = Int(time)
//        let minutes = totalSeconds / 60
//        let seconds = totalSeconds % 60
//        return String(format: "%02d:%02d", minutes, seconds)
//    }
//}
