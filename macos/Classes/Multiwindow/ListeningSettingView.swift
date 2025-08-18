import SwiftUI

struct ListeningSettingView: View {
    @Binding var isControlBarExpanded: Bool
    let initialLoad: Bool
    
    @State private var showDevices = false
    @State private var isInPersonMeeting = false
    
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
                    .frame(width: 0, height: 0)
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
        }
        .padding(EdgeInsets(top: 15, leading: 15, bottom: 15, trailing: 15))
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.8))
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .opacity(isControlBarExpanded ? 1 : 0)
        .animation(.easeInOut, value: isControlBarExpanded)
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
}
