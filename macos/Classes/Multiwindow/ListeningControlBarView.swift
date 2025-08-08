import SwiftUI
import Combine

struct LottieButton: View {
    let action: () -> Void
    @EnvironmentObject var viewModel: ListeningViewModel
    @State private var animationID = UUID()
    @State private var isAnimationRunning = false
    
    let animationDuration: TimeInterval = 1.0
    let noiseThreshold: Float = 0.1

    var body: some View {
        Group {
            ZStack {
                if let waveformLottie = viewModel.waveformLottie {
                    LottieView(
                        lottieFile: waveformLottie,
                        loopMode: .playOnce,
                        autostart: true,
                        contentMode: .scaleAspectFit,
                        stickColors: viewModel.stickColors
                    )
                    .id(animationID)
                    .frame(width: 20, height: 20)
                }
                Color.clear
                    .contentShape(Rectangle()) // Makes the entire frame tappable
                    .onTapGesture {
                        // This gesture will now fire correctly on the first click!
                        action()
                    }
            }

        }
        .onReceive(
            Publishers.CombineLatest(
                viewModel.$micNoiseLevel,
                viewModel.$sysNoiseLevel
            )
        ) { micNoise, sysNoise in
            let shouldAnimate = micNoise > noiseThreshold || sysNoise > noiseThreshold

            if !isAnimationRunning && shouldAnimate {
                isAnimationRunning = true
                animationID = UUID()
                DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                    isAnimationRunning = false
                }
            }
        }
    }
}

//struct LottieButton: View {
//    @EnvironmentObject var viewModel: ListeningViewModel
//    @State private var animationID = UUID()
//    @State private var isAnimationRunning = false
//
//    // 애니메이션 전체 사이클의 예상 시간 (초)
//    let animationDuration: TimeInterval = 1.0
//    let noiseThreshold: Float = 0.1
//
//    var body: some View {
//        Group {
//            if let waveformLottie = viewModel.waveformLottie {
//                LottieView(
//                    lottieFile: waveformLottie,
//                    loopMode: .playOnce,
//                    autostart: true,
//                    contentMode: .scaleAspectFit,
//                    stickColors: viewModel.stickColors,
//                    onTap: {
//                        WindowManager.shared.showMainAppWindow()
//                        print("Lottie Button Clicked!!!")
//                    }
//                )
//                .id(animationID)
//                .frame(width: 20, height: 20)
//            }
//        }
//        .onReceive(
//            Publishers.CombineLatest(
//                viewModel.$micNoiseLevel,
//                viewModel.$sysNoiseLevel
//            )
//        ) { micNoise, sysNoise in
//            let shouldAnimate = micNoise > noiseThreshold || sysNoise > noiseThreshold
//
//            if !isAnimationRunning && shouldAnimate {
//                isAnimationRunning = true
//                animationID = UUID()
//                DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
//                    isAnimationRunning = false
//                }
//            }
//        }
//    }
//}

// Custom button component
struct ControlBarButton: View {
    let systemName: String
    let action: () -> Void
    var color: Color = .white
    var minimumTapArea: CGFloat = 45
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(color)
                .font(.system(size: 17))
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle()) // Makes the entire frame area tappable
                .frame(width: minimumTapArea, height: minimumTapArea) // Larger hit area
                .background(Color.newBgColor.opacity(0.001))
        }
        .frame(width: 20, height: 20)
        .buttonStyle(.plain)
    }
}

// Custom divider component
struct ControlDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 1, height: 20)
    }
}

struct ListeningControlBar: View {
    @EnvironmentObject var viewModel: ListeningViewModel
    @Binding var isExpanded: Bool
    @State private var showCountdown = true
    @State private var showingCancelConfirmation = false {
        didSet {
            if showingCancelConfirmation {
                isExpanded = true
            }
        }
    }
    
    @State private var hasListenedForNSeconds = false
    
    // Define the button configurations
    struct ButtonConfig: Identifiable {
        let id = UUID()
        let systemName: String
        let color: Color
        let action: () -> Void
    }
    
    var body: some View {
        HStack(spacing: 15) {
                   if isExpanded {
                       // Minimize button
                       ControlBarButton(
                           systemName: "minus",
                           action: {
                               WindowManager.shared.miniaturizeWindow()
                           },
                           color: Color.buttonWhiteColor
                       )
                       
                       ControlDivider()
                       
                       // Close button
                       ControlBarButton(
                           systemName: "xmark",
                           action: {
                               print("Close")
                               if viewModel.countdownTimer == nil {
                                   if hasListenedForNSeconds {
                                       showingCancelConfirmation = true
                                   } else {
                                       viewModel.cancelListening()
                                       WindowManager.shared.closeCurrentWindow(for: .cancel)
                                   }
                               } else {
                                   viewModel.cancelListening()
                                   WindowManager.shared.closeCurrentWindow(for: .cancel)
                               }
                           },
                           color: Color.buttonWhiteColor
                       )
                       
                       ControlDivider()
                       
                       // Confirm button
                       ControlBarButton(
                           systemName: "checkmark",
                           action: {
                               viewModel.stopListening()
                               WindowManager.shared.closeCurrentWindow(for: .done)
                           },
                           color: viewModel.countdownTimer != nil ? Color.gray: Color.brandPrimaryColor
                       )
                       .disabled(viewModel.countdownTimer != nil)
                       
                       ControlDivider()
                   }
                   
                   // Timer/Waveform slot (always visible)
                   if viewModel.isCountdownActive {
                       Text("\(viewModel.countdownNumber ?? 0)")
                           .foregroundColor(.white)
                           .font(.system(size: 15, weight: .bold))
                   } else {
//                       LottieButton()
//                           .onTapGesture {
//                               WindowManager.shared.showMainAppWindow()
//                               print("Lottie Button Clicked!!!")
//                           }
                       LottieButton(action: {
                           WindowManager.shared.showMainAppWindow()
                           print("Lottie Button Clicked!!!")
                       })
                   }
               }
        .confirmationDialog("Are you sure you want to cancel?",
            isPresented: $showingCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("Yes, delete", role: .destructive) {
                viewModel.cancelListening()
                WindowManager.shared.closeCurrentWindow(for: .cancel)
            }
            Button("No, keep listening", role: .cancel) {
                // dismiss dialog
            }
        } message: {
            Text("This will delete all data from the current meeting.")
        }
        .foregroundColor(.white)
        .padding(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        .frame(width: isExpanded ? 200 : 44, height: 44)
        .background(Color.newBgColor)
        .clipShape(Capsule())
        .shadow(color: .brandSecondaryColor.opacity(0.15), radius: 5, x: 0, y: 0)
        .onAppear{
            viewModel.startCountdownRecording()
        }
        .onChange(of: viewModel.isCountdownActive) { newValue in
            if newValue == false {
                print("isCountdownActive tracking -- \(newValue)")
                // The countdown just finished, set the 10-second timer
                DispatchQueue.main.asyncAfter(deadline: .now() + 29) {
                    hasListenedForNSeconds = true
                }
            }
        }
    }
}
