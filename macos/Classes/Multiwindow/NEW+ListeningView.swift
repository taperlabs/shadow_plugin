import SwiftUI

struct NewListeningView: View {
    @ObservedObject var viewModel: ListeningViewModel
    @State private var showDevices = false
    @State private var showCaptureTargets = false
    @State private var isControlBarExpanded = false
    @State private var initialLoad = true  // 초기 로드 상태를 추적
    @State private var isInPersonMeeting = false  // Toggle state
    
    // [추가 1] 예약된 작업을 저장해둘 변수
    @State private var autoCollapseTask: DispatchWorkItem?
    
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
                if showCaptureTargets && isControlBarExpanded {
                    SelectCaptureTargetListView()
                    //                        .transition(.opacity.combined(with: .scale))

                    Divider()
                }

                SelectCaptureTargetView()
                    .contentShape(Rectangle())  // Makes entire frame tappable
                    .onTapGesture {
                        withAnimation { showCaptureTargets.toggle() }
                    }
                //                        .padding(.bottom, 5)
                //                        .animation(.easeInOut, value: isControlBarExpanded)
                Divider()
                
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
                    // [수정 3] 호버가 시작되면 예약된 '접기' 작업을 취소함
                    if hovering {
                        autoCollapseTask?.cancel()
                        autoCollapseTask = nil
                        
                        // 사용자가 개입했으므로 초기 로드 상태 해제
                        if initialLoad {
                            initialLoad = false
                        }
                    }
                    
                    guard !initialLoad else { return }
                    
                    withAnimation {
                        // 기존 로직 유지
                        if !isControlBarExpanded && hovering {
                            showDevices = false
                            showCaptureTargets = false
                            isControlBarExpanded = true
                        }
                    }
                }
            //                .onHover { hovering in
            //                    guard !initialLoad else { return }
            //                    withAnimation {
            //                        if !isControlBarExpanded && hovering {
            //                            showDevices = false
            //                            showCaptureTargets = false
            //                            isControlBarExpanded = true
            //                        }
            //                    }
            //                }
        }
        .environmentObject(viewModel)
        .padding(EdgeInsets(top: 15, leading: 0, bottom: 5, trailing: 3))
        .onAppear {
            isControlBarExpanded = true
            viewModel.isRecording = true
            _ = SleepUtility.preventSleep()
            
            // [수정 2] 취소 가능한 WorkItem 생성
            let task = DispatchWorkItem {
                withAnimation {
                    initialLoad = false
                    isControlBarExpanded = false
                }
            }
            
            // 변수에 저장해두기 (나중에 취소하려고)
            self.autoCollapseTask = task
            
            // 예약 실행
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: task)
        }
        .onDisappear {
            // 뷰가 사라질 때도 혹시 남아있는 작업이 있다면 취소
            autoCollapseTask?.cancel()
            autoCollapseTask = nil
            SleepUtility.allowSleep()
            print("listening View disappeared")
        }
        .onHover { hovering in
            // [수정 4] 전체 뷰에 대한 호버 처리에서도 취소 로직 적용
            if hovering {
                autoCollapseTask?.cancel()
                autoCollapseTask = nil
                if initialLoad { initialLoad = false }
            }
            
            if isControlBarExpanded {
                withAnimation {
                    isControlBarExpanded = hovering
                    if !isControlBarExpanded {
                        showDevices = false
                    }
                }
            }
        }
        //        .onAppear {
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
        //            if isControlBarExpanded {
        //                withAnimation {
        //                    isControlBarExpanded = hovering
        //                    if !isControlBarExpanded {
        //                        showDevices = false
        //                    }
        //                }
        //            }
        //        }
        .background(.clear)
    }
}
