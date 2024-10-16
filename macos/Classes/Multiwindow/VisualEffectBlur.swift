import SwiftUI

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var isActive: Bool
    var cornerRadius: CGFloat
    
    @Environment(\.colorScheme) var colorScheme  // Detect light/dark mode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = adjustedMaterial(for: colorScheme)
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = isActive ? .active : .inactive
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = cornerRadius
        visualEffectView.layer?.masksToBounds = true
        return visualEffectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = adjustedMaterial(for: colorScheme)
        nsView.blendingMode = blendingMode
        nsView.state = isActive ? .active : .inactive
        nsView.layer?.cornerRadius = cornerRadius
    }
    
    /// Adjust material based on light or dark mode
    private func adjustedMaterial(for colorScheme: ColorScheme) -> NSVisualEffectView.Material {
        print("colorScheme \(colorScheme)")
        
        switch colorScheme {
        case .dark:
            return .sidebar  // Keep .sidebar in dark mode
        case .light:
            return .dark  // You can use a different material if needed for light mode
        default:
            return .sidebar
        }
    }
}


//struct VisualEffectBlur: NSViewRepresentable {
//    var material: NSVisualEffectView.Material
//    var blendingMode: NSVisualEffectView.BlendingMode
//    var isActive: Bool
//    var cornerRadius: CGFloat
//
//    func makeNSView(context: Context) -> NSVisualEffectView {
//        let visualEffectView = NSVisualEffectView()
//        visualEffectView.material = material
//        visualEffectView.blendingMode = blendingMode
//        visualEffectView.state = isActive ? .active : .inactive
//        visualEffectView.wantsLayer = true
//        visualEffectView.layer?.cornerRadius = cornerRadius
//        visualEffectView.layer?.masksToBounds = true
//        return visualEffectView
//    }
//
//    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
//        nsView.material = material
//        nsView.blendingMode = blendingMode
//        nsView.state = isActive ? .active : .inactive
//        nsView.layer?.cornerRadius = cornerRadius
//    }
//}
