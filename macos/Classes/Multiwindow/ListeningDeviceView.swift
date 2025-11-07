import SwiftUI

struct ListeningDeviceView: View {
    @EnvironmentObject var viewModel: ListeningViewModel
    private let dummyText: String = "Macbook Default Microphone"
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .foregroundStyle(Color.buttonWhiteColor)
            Text(viewModel.defaultInputDeviceName)
                .foregroundStyle(Color.buttonWhiteColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
