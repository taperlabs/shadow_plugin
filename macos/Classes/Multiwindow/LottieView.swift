import AppKit
import Lottie
import SwiftUI

extension NSColor {
    func getRGBComponents() -> (CGFloat, CGFloat, CGFloat) {
        guard let convertedColor = usingColorSpace(.sRGB) else { return (0, 0, 0) }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        convertedColor.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return (red, green, blue)
    }
}

public struct LottieView: NSViewRepresentable {

    public init(
        lottieFile: String,
        loopMode: LottieLoopMode = .loop,
        autostart: Bool = true,
        contentMode: LottieContentMode = .scaleAspectFit,
        stickColors: [Int: Color] = [:],
        onTap: (() -> Void)? = nil
    ) {
        self.lottieFile = lottieFile
        self.loopMode = loopMode
        self.autostart = autostart
        self.contentMode = contentMode
        self.stickColors = stickColors
        self.onTap = onTap
    }

    let lottieFile: String
    let loopMode: LottieLoopMode
    let autostart: Bool
    let contentMode: LottieContentMode
    let stickColors: [Int: Color]  // Empty dictionary means use original colors
    let onTap: (() -> Void)?  // Add this parameter

    public class Coordinator: NSObject {
        var animationView: LottieAnimationView?

        init(_ animationView: LottieAnimationView?) {
            self.animationView = animationView
        }
    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(nil)
    }

    // This function creates the NSView and sets up the Lottie animation
    public func makeNSView(context: Context) -> NSView {
        let containerView = NSView()

        // Load the Lottie animation
        let animationView = LottieAnimationView()
        context.coordinator.animationView = animationView
       

        guard let animation = LottieAnimation.filepath(lottieFile) else {
            print("Lottie animation \(lottieFile) not found.")
            return containerView
        }

        animationView.animation = animation
        
        // Only apply colors to sticks that are specified in stickColors
        for (stickNumber, color) in stickColors {
            let nsColor = NSColor(color)
            let (red, green, blue) = nsColor.getRGBComponents()
            let colorProvider = ColorValueProvider(LottieColor(r: Double(red), g: Double(green), b: Double(blue), a: 1))
            
            let keypath = AnimationKeypath(keypath: "\(stickNumber).사각형 1.칠 1.Color")
            animationView.setValueProvider(colorProvider, keypath: keypath)
        }
        
        animationView.contentMode = contentMode
        animationView.loopMode = loopMode
        animationView.backgroundBehavior = .continuePlaying

        // Autoplay if enabled
        if autostart {
            animationView.play()
        }


        // Add Lottie animation view to the container
        containerView.addSubview(animationView)

        return containerView
    }

    public func updateNSView(_ nsView: NSView, context: Context) {
        guard let animationView = context.coordinator.animationView else { return }

        // Update the size of the Lottie animation to match SwiftUI's frame
        animationView.frame = nsView.bounds
        animationView.autoresizingMask = [.width, .height] // Ensure it resizes with the NSView
    }
}


