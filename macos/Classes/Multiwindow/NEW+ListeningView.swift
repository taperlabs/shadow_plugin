import SwiftUI

struct NewListeningView: View {
    @ObservedObject var viewModel: ListeningViewModel
    @State private var showDevices = false
    @State private var showCaptureTargets = false
    @State private var isControlBarExpanded = false
    @State private var initialLoad = true  // 초기 로드 상태를 추적
    @State private var isInPersonMeeting = false  // Toggle state
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 15) {
            // Settings Panel - grouped with styling
            VStack(alignment: .leading, spacing: 12) {
                // Toggle은 항상 같은 위치에서 렌더링 - 흔들림 방지
                InPersonMeetingToggleView(
                    isInPersonMeeting: $isInPersonMeeting,
                    textColor: .borderColor,
                    fontSize: 13,
                    fontWeight: .light,
                    opacity: isControlBarExpanded ? 1 : 0
                )
//                .padding(.bottom, 5)
                
                Divider()

                // Device list는 조건부로 표시
                if viewModel.shouldScreenshotCapture && showCaptureTargets && isControlBarExpanded {
                    SelectCaptureTargetListView()
//                        .transition(.opacity.combined(with: .scale))
                    
                    Divider()
                }
                
                if viewModel.shouldScreenshotCapture {
                    SelectCaptureTargetView()
                        .contentShape(Rectangle())  // Makes entire frame tappable
                        .onTapGesture {
                            withAnimation { showCaptureTargets.toggle() }
                        }
//                        .padding(.bottom, 5)
//                        .animation(.easeInOut, value: isControlBarExpanded)
                    Divider()
                }
                
                // Device list는 조건부로 표시
                if showDevices && isControlBarExpanded {
                    ListeningDeviceListView()
//                        .transition(.opacity.combined(with: .scale))
                    
                    Divider()
                }
                
//                else {
//                    // Device list가 숨겨져 있을 때도 같은 공간 차지하도록
//                    ListeningDeviceListView()
//                        .frame(width: 0, height: 0)
//                        .allowsTightening(false)
//                        .opacity(0)
//                        .clipped()
//                }
                
                ListeningDeviceView()
                    .onTapGesture {
                        withAnimation { showDevices.toggle() }
                    }
                    .opacity(isControlBarExpanded ? 1 : 0)
//                    .animation(.easeInOut, value: isControlBarExpanded)
            }
            .frame(width: 220)
            .padding(EdgeInsets(top: 13, leading: 15, bottom: 13, trailing: 15))
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.newBgColor)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .opacity(isControlBarExpanded ? 1 : 0)
            .animation(.easeInOut, value: isControlBarExpanded)
            
            ListeningControlBar(isExpanded: $isControlBarExpanded)
                .onHover { hovering in
                    guard !initialLoad else { return }
                    withAnimation {
                        if !isControlBarExpanded && hovering {
                            showDevices = false
                            showCaptureTargets = false
                            isControlBarExpanded = true
                        }
                    }
                }
        }
        .environmentObject(viewModel)
        .padding(EdgeInsets(top: 15, leading: 0, bottom: 5, trailing: 3))
        .onAppear {
            isControlBarExpanded = true
            viewModel.isRecording = true
            _ = SleepUtility.preventSleep()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    initialLoad = false
                    isControlBarExpanded = false
                }
            }
        }
        .onDisappear {
            SleepUtility.allowSleep()
            print("listening View disappeared")
        }
        .onHover { hovering in
            if isControlBarExpanded {
                withAnimation {
                    isControlBarExpanded = hovering
                    if !isControlBarExpanded {
                        showDevices = false
                    }
                }
            }
        }
        .background(.clear)
    }
}
