import SwiftUI

struct CustomSwitchToggleStyle: ToggleStyle {
    var tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label

            // 기준 사이즈
            let trackWidth: CGFloat = 26
            let trackHeight: CGFloat = 16
            let knobSize: CGFloat = 10
            let strokeLineWidth: CGFloat = 1.5
            let extraPadding: CGFloat = 2 // 노브와 트랙 내부 간격

            // 실제 노브가 이동할 수 있는 offset 계산
            // (트랙 내부 폭 / 2) - (노브 반지름) - (스트로크 내부 침범 보정) - extraPadding
            let halfInnerWidth = (trackWidth - strokeLineWidth) / 2
            let baseOffset = halfInnerWidth - (knobSize / 2)
            let effectiveOffset = baseOffset - extraPadding // 시각적 여유 추가

            ZStack {
                Capsule()
                    .fill(configuration.isOn ? tint : Color.newBgColor)
                    .frame(width: trackWidth, height: trackHeight)

                // 경계는 내부에만 그리게 (붙어 보이지 않게)
                Capsule()
                    .strokeBorder(Color.borderColor, lineWidth: strokeLineWidth)
                    .frame(width: trackWidth, height: trackHeight)

                Circle()
                    .fill(Color.borderColor)
                    .frame(width: knobSize, height: knobSize)
                    .offset(x: configuration.isOn ? effectiveOffset : -effectiveOffset)
                    .animation(.spring(), value: configuration.isOn)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
    }
}



struct InPersonMeetingToggleView: View {
    @Binding var isInPersonMeeting: Bool
    let textColor: Color
    let fontSize: CGFloat
    let fontWeight: Font.Weight?
    let opacity: Double
    
    init(
        isInPersonMeeting: Binding<Bool>,
        textColor: Color = .borderColor,
        fontSize: CGFloat = 13,
        fontWeight: Font.Weight? = nil,
        opacity: Double = 1.0
    ) {
        self._isInPersonMeeting = isInPersonMeeting
        self.textColor = textColor
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.opacity = opacity
    }
    
    var body: some View {
        HStack {
            Text("Mark as in-person meeting")
                .foregroundColor(textColor)
                .font(.system(size: fontSize, weight: fontWeight))
            
            Spacer()
                .frame(maxWidth: 23)
            
            Toggle("", isOn: $isInPersonMeeting)
                .toggleStyle(CustomSwitchToggleStyle(tint: Color.brandPrimaryColor))
                .labelsHidden()
        }
        .opacity(opacity)
        .onChange(of: isInPersonMeeting) { oldValue, newValue in
            print("Toggle changed from \(oldValue) to \(newValue)")
            if newValue {
                print("Meeting marked as in-person")
                ListeningStatusService.shared.sendListeningEvent(["isInPersonMeeting": isInPersonMeeting])
            } else {
                print("Meeting marked as virtual")
                ListeningStatusService.shared.sendListeningEvent(["isInPersonMeeting": isInPersonMeeting])
            }
        }
    }
}
