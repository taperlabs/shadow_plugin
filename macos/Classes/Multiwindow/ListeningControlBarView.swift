import SwiftUI
import Combine

struct LottieButton: View {
    @EnvironmentObject var viewModel: ListeningViewModel
    @State private var animationID = UUID()
    @State private var isAnimationRunning = false

    // 애니메이션 전체 사이클의 예상 시간 (초)
    let animationDuration: TimeInterval = 1.0
    let noiseThreshold: Float = 0.1

    var body: some View {
        Group {
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
//    let action: () -> Void
//    
//    // 애니메이션 전체 사이클의 예상 시간 (초)
//    let animationDuration: TimeInterval = 1.0
//    let noiseThreshold: Float = 0.1
//    
//    var body: some View {
//        Button(action: {
//
//        }) {
//            if let waveformLottie = viewModel.waveformLottie {
//                LottieView(
//                    lottieFile: waveformLottie,
//                    loopMode: .playOnce,
//                    autostart: true,
//                    contentMode: .scaleAspectFit,
//                    stickColors: viewModel.stickColors
//                )
//                .id(animationID)
//                .frame(width: 20, height: 20)
//            }
//        }
//        .buttonStyle(.plain)
//        .onReceive(
//             Publishers.CombineLatest(
//                 viewModel.$micNoiseLevel,
//                 viewModel.$sysNoiseLevel
//             )
//         ) { micNoise, sysNoise in
//             let shouldAnimate = micNoise > noiseThreshold || sysNoise > noiseThreshold
//             
//             if !isAnimationRunning && shouldAnimate {
//                 isAnimationRunning = true
//                 animationID = UUID()
//                 DispatchQueue.main.asyncAfter(deadline:.now() + animationDuration) {
//                     isAnimationRunning = false
//                 }
//             }
//         }
//    }
//}

struct CountdownTimerView: View {
    @State private var countdown = 3
    let onComplete: () -> Void
    
    var body: some View {
        Text("\(countdown)")
            .foregroundColor(.white)
            .font(.system(size: 15, weight: .bold))
            .onAppear {
                print("CotunDown Timer 렌더링 됐다")
                // Start countdown timer
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    if countdown > 0 {
                        countdown -= 1
                    } else {
                        timer.invalidate()
                        onComplete()
                    }
                }
            }
    }
}

// Custom button component
struct ControlBarButton: View {
    let systemName: String
    let action: () -> Void
    var color: Color = .white
    var minimumTapArea: CGFloat = 44
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .foregroundStyle(color)
                .font(.system(size: 17))
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle()) // Makes the entire frame area tappable
                .frame(width: minimumTapArea, height: minimumTapArea) // Larger hit area
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
                                   showingCancelConfirmation = true
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
                           color: Color.brandPrimaryColor
                       )
                       
                       ControlDivider()
                   }
                   
                   // Timer/Waveform slot (always visible)
                   if viewModel.isCountdownActive {
                       Text("\(viewModel.countdownNumber ?? 0)")
                           .foregroundColor(.white)
                           .font(.system(size: 15, weight: .bold))
                   } else {
                       LottieButton()
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
    }
}
