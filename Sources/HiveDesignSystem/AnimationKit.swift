import SwiftUI
#if os(macOS)
import AppKit
import QuartzCore
#endif

public enum AnimationKit {
    public static var reduceMotion: Bool {
        #if os(macOS)
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        return false
        #endif
    }

    public static var pageTransitionDuration: TimeInterval {
        reduceMotion ? 0.001 : 0.28
    }

    public static var crossDissolveDuration: TimeInterval {
        reduceMotion ? 0.001 : 0.12
    }

    public static var staggerDelay: TimeInterval {
        reduceMotion ? 0 : 0.016
    }

    public static func pageTransition(_ animation: Animation? = nil) -> Animation {
        if reduceMotion {
            return .linear(duration: 0.001)
        }
        return animation ?? HiveMotion.panel
    }

    #if os(macOS)
    @MainActor
    public static func fileAway(view: NSView, delay: CFTimeInterval) {
        guard !reduceMotion else {
            view.alphaValue = 0
            return
        }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = pageTransitionDuration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            ctx.allowsImplicitAnimation = true
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                view.animator().alphaValue = 0
                var frame = view.frame
                frame.origin.x -= 40
                view.animator().setFrameOrigin(frame.origin)
            }
        }
    }
    #endif
}

public struct HivePageTransitionModifier: ViewModifier {
    var isActive: Bool
    var edge: Edge

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public func body(content: Content) -> some View {
        content
            .opacity(isActive ? 1 : 0)
            .offset(x: offsetX, y: offsetY)
            .animation(AnimationKit.pageTransition(), value: isActive)
    }

    private var offsetX: CGFloat {
        guard !reduceMotion else { return 0 }
        switch edge {
        case .leading:
            return isActive ? 0 : -40
        case .trailing:
            return isActive ? 0 : 60
        default:
            return 0
        }
    }

    private var offsetY: CGFloat { 0 }
}

public extension View {
    func hivePageTransition(isActive: Bool, edge: Edge = .trailing) -> some View {
        modifier(HivePageTransitionModifier(isActive: isActive, edge: edge))
    }
}
