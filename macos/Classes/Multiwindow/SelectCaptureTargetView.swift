import SwiftUI

struct SelectCaptureTargetView: View {
    @EnvironmentObject var viewModel: ListeningViewModel

    var body: some View {
        HStack(spacing: 10) {
            iconView
                .foregroundStyle(Color.buttonWhiteColor)
                .frame(width: 16, height: 16)
            Text(viewModel.selectedCaptureTarget?.name ?? "No capture")
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(Color.buttonWhiteColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    } 

    @ViewBuilder
    private var iconView: some View {
        if let target = viewModel.selectedCaptureTarget {
            switch target {
            case .noCapture:
                Image(systemName: "xmark.circle")
            case .display:
                Image(systemName: "desktopcomputer")
            case .window:
                if let bundleID = target.bundleID,
                   let icon = ScreenshotCaptureService.getAppIcon(for: bundleID, size: 16) {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "app.fill")
                }
            }
        } else {
            Image(systemName: "xmark.circle")
        }
    }
}
