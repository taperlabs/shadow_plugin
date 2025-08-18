import SwiftUI
import CoreAudio

// A view that represents a single device item.
struct DeviceItemView: View {
    let device: AudioDevice
    let isSelected: Bool
    
    var body: some View {
        Text(device.name)
            .lineLimit(1)          // 한 줄로 제한
            .truncationMode(.tail) // 긴 텍스트는 끝에 ...
//            .padding(.horizontal, 12)  좌우 여백 추가
            .padding(.vertical, 4)    // 상하 여백
            .foregroundColor(isSelected ? .brandSecondaryColor : .fontColor)
    }
}

// A view that displays a list of device items using a ForEach loop inside a ScrollView.
struct ListeningDeviceListView: View {
    @EnvironmentObject var viewModel: ListeningViewModel
    @State private var selectedDeviceId: AudioDeviceID?
    
    private var dynamicHeight: CGFloat {
         let count = viewModel.inputDevices.count
         // 항목이 하나면 40, 여러 개면 count * 40, 단 최대 100까지만
         let calculated = CGFloat(max(count, 1) * 40)
         return min(calculated, 100)
     }
    
    var body: some View {
        // Wrap your VStack inside a ScrollView for vertical scrolling.
        ScrollView {
                ForEach(viewModel.inputDevices) { device in
                    DeviceItemView(
                        device: device,
                        isSelected: device.id == selectedDeviceId
                    )
                    .onTapGesture {
                        selectedDeviceId = device.id
                        viewModel.setDefaultAudioInputDevice(with: device.name)
                        print("device Selected \(device.name)")
                    }
                    .frame(maxWidth: .infinity, maxHeight: 25, alignment: .leading)

                }
//            .padding(EdgeInsets(top: 7, leading: 12, bottom: 5, trailing: 30))
        }
        .onAppear{
            viewModel.setAudioDeviceListener()
        }
        .onDisappear {
            viewModel.removeAudioDeviceListener()
        }
        .onReceive(viewModel.$defaultInputDevice) { newDeviceID in
            selectedDeviceId = newDeviceID
            print("Updated defaultInputDevice: \(viewModel.defaultInputDeviceName)")
        }
        .frame(maxWidth: .infinity, maxHeight: dynamicHeight)
        .fixedSize(horizontal: false, vertical: true)
//        .background(Color.newBgColor.clipShape(RoundedRectangle(cornerRadius: 8)))
        // 폭은 고정, 높이는 min~max 범위 내에서 자동으로
//        .frame(width: 240, height: dynamicHeight, alignment: .leading)
//        .overlay(
//            RoundedRectangle(cornerRadius: 8)
//                .strokeBorder(Color.borderColor, lineWidth: 1)
//        )
    }
}
