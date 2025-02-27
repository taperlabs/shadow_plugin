import SwiftUI

struct NewListeningView: View {
    @ObservedObject var viewModel: ListeningViewModel
    @State private var showDevices = false
    @State private var isControlBarExpanded = false
    @State private var initialLoad = true  // 초기 로드 상태를 추적
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 15) {
            // Use opacity to avoid layout shifts.
            ListeningDeviceListView()
                .opacity((showDevices && isControlBarExpanded) ? 1 : 0)
                .animation(.easeInOut, value: showDevices && isControlBarExpanded)
            
            ListeningDeviceView()
                .onTapGesture {
                    withAnimation { showDevices.toggle() }
                }
            // Optionally, also control visibility of DeviceView using opacity
                .opacity(isControlBarExpanded ? 1 : 0)
                .animation(.easeInOut, value: isControlBarExpanded)
            
            // ListeningControlBar updates the binding based on hover.
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
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation {
                    initialLoad = false
                    isControlBarExpanded = false
                }
            }
        }
        .onDisappear {
            print("listening View disappeared")
        }
        .onHover { hovering in
            // ControlBar가 확장된 상태에서는 전체 영역에 호버 효과 적용
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
