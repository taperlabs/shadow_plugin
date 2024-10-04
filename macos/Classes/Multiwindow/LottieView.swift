import AppKit
import Lottie
import SwiftUI

public struct LottieView: NSViewRepresentable {

    public init(
        lottieFile: String,
        loopMode: LottieLoopMode = .loop,
        autostart: Bool = true,
        contentMode: LottieContentMode = .scaleAspectFit
    ) {
        self.lottieFile = lottieFile
        self.loopMode = loopMode
        self.autostart = autostart
        self.contentMode = contentMode
    }

    let lottieFile: String
    let loopMode: LottieLoopMode
    let autostart: Bool
    let contentMode: LottieContentMode

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


