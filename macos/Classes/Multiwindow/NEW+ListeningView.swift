import SwiftUI

struct NewListeningView: View {
    @ObservedObject var viewModel: ListeningViewModel
    @State private var showDevices = false
    @State private var isControlBarExpanded = false
    @State private var initialLoad = true  // 초기 로드 상태를 추적
    @State private var isInPersonMeeting = false  // Toggle state
    
    var body: some View {
        VStack(alignment: .trailing, spacing: showDevices && isControlBarExpanded ? 15 : 10) {
            // Toggle은 항상 같은 위치에서 렌더링 - 흔들림 방지
            InPersonMeetingToggleView(
                isInPersonMeeting: $isInPersonMeeting,
                textColor: .borderColor,
                fontSize: 13,
                fontWeight: .light,
                opacity: isControlBarExpanded ? 1 : 0
            )
            
            // Device list는 조건부로 표시
            if showDevices && isControlBarExpanded {
                ListeningDeviceListView()
                    .transition(.opacity.combined(with: .scale))
            } else {
                // Device list가 숨겨져 있을 때도 같은 공간 차지하도록
                ListeningDeviceListView()
                    .frame(width: 0,height: 0)
                    .allowsTightening(false)
                    .opacity(0)
                    .clipped()
            }
            
            ListeningDeviceView()
                .onTapGesture {
                    withAnimation { showDevices.toggle() }
                }
                .padding(.bottom, showDevices ? 0 : 10)
                .opacity(isControlBarExpanded ? 1 : 0)
                .animation(.easeInOut, value: isControlBarExpanded)
            
            ListeningControlBar(isExpanded: $isControlBarExpanded)
                .onHover { hovering in
                    guard !initialLoad else { return }
                    withAnimation {
                        if !isControlBarExpanded && hovering {
                            showDevices = false
                            isControlBarExpanded = true
                        }
                    }
                }
        }
        .environmentObject(viewModel)
        .padding(EdgeInsets(top: 15, leading: 0, bottom: 5, trailing: 3))
        .onAppear{
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


//struct NewListeningView: View {
//    @ObservedObject var viewModel: ListeningViewModel
//    @State private var showDevices = false
//    @State private var isControlBarExpanded = false
//    @State private var initialLoad = true  // 초기 로드 상태를 추적
//    @State private var isInPersonMeeting = false  // Toggle state
//    
//    var body: some View {
//        VStack(alignment: .trailing, spacing: 15) {
//            // Conditional positioning: Toggle shows in first position only when device list is visible
//            if showDevices && isControlBarExpanded {
//                // Toggle view in first position when device list is showing
//                InPersonMeetingToggleView(
//                    isInPersonMeeting: $isInPersonMeeting,
//                    textColor: .borderColor,
//                    fontSize: 13,
//                    fontWeight: .light
//                )
//            }
//            
//            // Position where either device list shows OR toggle shows (when device list is hidden)
//            if showDevices && isControlBarExpanded {
//                // Device list visible - shows in its normal position
//                ListeningDeviceListView()
//                    .transition(.opacity.combined(with: .scale))
//            } else {
//                // Device list hidden - toggle takes this position instead
//                VStack {
//                    InPersonMeetingToggleView(
//                        isInPersonMeeting: $isInPersonMeeting,
//                        textColor: .borderColor,
//                        fontSize: 13,
//                        fontWeight: .light
//                    )
//                    
//                    // Device list still rendered for logic but hidden
//                    ListeningDeviceListView()
//                        .opacity(0)
//                        .frame(height: 0)
//                        .clipped()
//                }
//            }
//            
//            ListeningDeviceView()
//                .onTapGesture {
//                    withAnimation { showDevices.toggle() }
//                }
//                // Optionally, also control visibility of DeviceView using opacity
//                .opacity(isControlBarExpanded ? 1 : 0)
//                .animation(.easeInOut, value: isControlBarExpanded)
//            
//            // ListeningControlBar updates the binding based on hover.
//            ListeningControlBar(isExpanded: $isControlBarExpanded)
//                .onHover { hovering in
//                    guard !initialLoad else { return }
//                    withAnimation {
//                        if !isControlBarExpanded && hovering {
//                            showDevices = false
//                            isControlBarExpanded = true
//                        }
//                    }
//                }
//        }
//        .environmentObject(viewModel)
//        .padding(EdgeInsets(top: 15, leading: 0, bottom: 5, trailing: 3))
//        .onAppear{
//            isControlBarExpanded = true
//            viewModel.isRecording = true
//            _ = SleepUtility.preventSleep()
//            
//            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                withAnimation {
//                    initialLoad = false
//                    isControlBarExpanded = false
//                }
//            }
//        }
//        .onDisappear {
//            SleepUtility.allowSleep()
//            print("listening View disappeared")
//        }
//        .onHover { hovering in
//            // ControlBar가 확장된 상태에서는 전체 영역에 호버 효과 적용
//            if isControlBarExpanded {
//                withAnimation {
//                    isControlBarExpanded = hovering
//                    if !isControlBarExpanded {
//                        showDevices = false
//                    }
//                }
//            }
//        }
//        .background(.clear)
//    }
//}

//struct NewListeningView: View {
//    @ObservedObject var viewModel: ListeningViewModel
//    @State private var showDevices = false
//    @State private var isControlBarExpanded = false
//    @State private var initialLoad = true  // 초기 로드 상태를 추적
//    @State private var isInPersonMeeting = false  // Toggle state
//    
//    var body: some View {
//        VStack(alignment: .trailing, spacing: 15) {
//            // Conditional positioning: Toggle shows in first position only when device list is visible
//            if showDevices && isControlBarExpanded {
//                // Toggle view in first position when device list is showing
//                HStack {
//                     Text("Mark as in-person meeting")
//                         .foregroundColor(.borderColor)
//                         .fontWeight(.light)
//                         .font(.system(size: 13))
//                     
//                     Spacer()
//                     
//                     Toggle("", isOn: $isInPersonMeeting)
//                        .toggleStyle(SwitchToggleStyle(tint: .accentColor))
//                         .labelsHidden()
//                         .overlay(
//                             RoundedRectangle(cornerRadius: 16)
//                                .stroke(Color.buttonWhiteColor.opacity(0.3), lineWidth: 3.0)
//                         )
//                 }
//                 .padding(.horizontal, 5)
//                 .padding(.vertical, 8)
//                 .cornerRadius(8)
//                 .onChange(of: isInPersonMeeting) { oldValue, newValue in
//                     // Execute your action here
//                     print("Toggle changed from \(oldValue) to \(newValue)")
//                     
//                     // Example actions:
//                     if newValue {
//                         // When toggle is turned ON
//                         print("Meeting marked as in-person")
//                         ListeningStatusService.shared.sendListeningEvent(["isInPersonMeeting": isInPersonMeeting])
//                     } else {
//                         // When toggle is turned OFF
//                         print("Meeting marked as virtual")
//                         ListeningStatusService.shared.sendListeningEvent(["isInPersonMeeting": isInPersonMeeting])
//                     }
//                 }
//            }
//            
//            // Position where either device list shows OR toggle shows (when device list is hidden)
//            if showDevices && isControlBarExpanded {
//                // Device list visible - shows in its normal position
//                ListeningDeviceListView()
//                    .transition(.opacity.combined(with: .scale))
//            } else {
//                // Device list hidden - toggle takes this position instead
//                VStack {
//                    HStack {
//                         Text("Mark as in-person meeting")
//                             .foregroundColor(.buttonWhiteColor)
//                             .font(.system(size: 14))
//                         
//                         Spacer()
//                         
//                         Toggle("", isOn: $isInPersonMeeting)
//                            .toggleStyle(SwitchToggleStyle(tint: .accentColor))
//                             .labelsHidden()
//                             .overlay(
//                                 RoundedRectangle(cornerRadius: 16)
//                                    .stroke(Color.buttonWhiteColor.opacity(0.3), lineWidth: 3.0)
//                             )
//                     }
//                     .padding(.horizontal, 5)
//                     .padding(.vertical, 8)
//                     .cornerRadius(8)
//                     .opacity(isControlBarExpanded ? 1 : 0)
//                     .onChange(of: isInPersonMeeting) { oldValue, newValue in
//                         // Execute your action here
//                         print("Toggle changed from \(oldValue) to \(newValue)")
//                         
//                         // Example actions:
//                         if newValue {
//                             // When toggle is turned ON
//                             print("Meeting marked as in-person")
//                             ListeningStatusService.shared.sendListeningEvent(["isInPersonMeeting": isInPersonMeeting])
//                         } else {
//                             // When toggle is turned OFF
//                             print("Meeting marked as virtual")
//                             ListeningStatusService.shared.sendListeningEvent(["isInPersonMeeting": isInPersonMeeting])
//                         }
//                     }
//                    
//                    // Device list still rendered for logic but hidden
//                    ListeningDeviceListView()
//                        .opacity(0)
//                        .frame(height: 0)
//                        .clipped()
//                }
//            }
//            
//            ListeningDeviceView()
//                .onTapGesture {
//                    withAnimation { showDevices.toggle() }
//                }
//            // Optionally, also control visibility of DeviceView using opacity
//                .opacity(isControlBarExpanded ? 1 : 0)
//                .animation(.easeInOut, value: isControlBarExpanded)
//            
//            // ListeningControlBar updates the binding based on hover.
//            ListeningControlBar(isExpanded: $isControlBarExpanded)
//                .onHover { hovering in
//                    guard !initialLoad else { return }
//                    withAnimation {
//                        if !isControlBarExpanded && hovering {
//                            showDevices = false
//                            isControlBarExpanded = true
//                        }
//                    }
//                }
//        }
//        .environmentObject(viewModel)
//        .padding(EdgeInsets(top: 15, leading: 0, bottom: 5, trailing: 3))
//        .onAppear{
//            isControlBarExpanded = true
//            viewModel.isRecording = true
//            _ = SleepUtility.preventSleep()
//            
//            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                withAnimation {
//                    initialLoad = false
//                    isControlBarExpanded = false
//                }
//            }
//        }
//        .onDisappear {
//            SleepUtility.allowSleep()
//            print("listening View disappeared")
//        }
//        .onHover { hovering in
//            // ControlBar가 확장된 상태에서는 전체 영역에 호버 효과 적용
//            if isControlBarExpanded {
//                withAnimation {
//                    isControlBarExpanded = hovering
//                    if !isControlBarExpanded {
//                        showDevices = false
//                    }
//                }
//            }
//        }
//        .background(.clear)
//    }
//}
