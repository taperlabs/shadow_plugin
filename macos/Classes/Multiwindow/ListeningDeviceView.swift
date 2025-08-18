import SwiftUI

struct ListeningDeviceView: View {
    @EnvironmentObject var viewModel: ListeningViewModel
    private let dummyText: String = "Macbook Default Microphone"
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .foregroundStyle(.white)
//                .frame(maxHeight: .infinity)
            Text(viewModel.defaultInputDeviceName)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
//        .padding()
//        .frame(width: 240, height: 40, alignment: .leading)
//        .background(Color.accentColor)
//        .background(Color.accentColor.clipShape(RoundedRectangle(cornerRadius: 8)))
//        .overlay(
//            RoundedRectangle(cornerRadius: 8)
//                .strokeBorder(Color.borderColor, lineWidth: 1)
//        )
    }
}
