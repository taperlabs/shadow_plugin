import SwiftUI

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var isActive: Bool
    var cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = isActive ? .active : .inactive
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = cornerRadius
        visualEffectView.layer?.masksToBounds = true
        return visualEffectView
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = isActive ? .active : .inactive
        nsView.layer?.cornerRadius = cornerRadius
    }
}
