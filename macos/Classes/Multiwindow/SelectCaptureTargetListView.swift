import SwiftUI
import CoreAudio

// A view that represents a single capture target item (display or window).
struct SelectCaptureTargetItemView: View {
    let target: CaptureTarget
    let isSelected: Bool
    let screenshotService: ScreenshotCaptureService

    var body: some View {
        HStack(spacing: 8) {
            // Dynamic icon based on target type
            iconView
                .foregroundColor(isSelected ? .brandSecondaryColor : .fontColor)
                .frame(width: 16, height: 16)

            Text(target.name)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundColor(isSelected ? .brandSecondaryColor : .fontColor)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var iconView: some View {
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
    }
}

// A view that displays a list of capture targets (displays and windows) using a ForEach loop inside a ScrollView.
struct SelectCaptureTargetListView: View {
    @EnvironmentObject var viewModel: ListeningViewModel
    @State private var selectedTargetId: String?

    private var dynamicHeight: CGFloat {
        let count = viewModel.captureTargets.count
        // 항목이 하나면 40, 여러 개면 count * 40, 단 최대 150까지만
        let calculated = CGFloat(max(count, 1) * 40)
        return min(calculated, 120)
    }

    var body: some View {
        // Wrap your VStack inside a ScrollView for vertical scrolling.
        ScrollView {
            if viewModel.captureTargets.isEmpty {
                // Empty state
                Text("No capture targets available")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                ForEach(viewModel.captureTargets) { target in
                    SelectCaptureTargetItemView(
                        target: target,
                        isSelected: target.id == selectedTargetId,
                        screenshotService: viewModel.screenshotCaptureService
                    )
                    .onTapGesture {
                        selectedTargetId = target.id
                        viewModel.selectedCaptureTarget = target
                        print("Capture Target Selected: \(target.name)")

                        // Send selected target info to Flutter
                        ShadowPlugin.sendToFlutter(method: "onCaptureTargetSelected", data: target.asDictionary())
                    }
                    .frame(maxWidth: .infinity, maxHeight: 25, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 120)
        .onAppear {
            print("SelectCaptureTarget On Appear")

            // Fetch capture targets asynchronously
            Task {
                await viewModel.fetchCaptureTargets()
            }

            // Sync from ViewModel first (preserves selection across view lifecycle)
            if let currentTarget = viewModel.selectedCaptureTarget {
                selectedTargetId = currentTarget.id
            } else if selectedTargetId == nil {
                // Only set default if both are nil
                selectedTargetId = CaptureTarget.noCapture.id
                viewModel.selectedCaptureTarget = .noCapture
            }
        }
        .onDisappear {
            print("SelectCaptureTarget On Disappear")
        }
        .onReceive(viewModel.$selectedCaptureTarget) { newTarget in
            // Sync local state when ViewModel changes (e.g., from auto-reset)
            if let newTarget = newTarget {
                selectedTargetId = newTarget.id
            } else {
                selectedTargetId = nil
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
