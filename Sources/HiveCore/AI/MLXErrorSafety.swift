import Foundation
#if canImport(MLX)
import MLX
#endif

/// Guards the process against mlx-c's default error handler.
///
/// mlx-c installs an error handler that, on ANY error, prints the message and
/// calls `exit(-1)` — killing the whole process. That is a fatal design for a
/// browser: if `default.metallib` can't be located in the app bundle (a known
/// SwiftPM resource-bundle edge case), the first GPU-backed inference tears
/// down the entire application instead of failing gracefully.
///
/// `install()` replaces that handler with one that logs the message and
/// returns. The C layer then surfaces the failure as a normal error/return
/// code, which the MLX runtime converts into a thrown Swift error and the
/// Dispatcher falls back from honestly (Mock/BYOK) — never a hard exit.
public enum MLXErrorSafety {
    /// Install the non-exiting handler once per process. Safe to call from app
    /// startup and from the runtime; the C handler is installed a single time
    /// and the call is idempotent thereafter.
    public static func install() {
        #if canImport(MLX)
        _ = installOnce
        #endif
    }

    #if canImport(MLX)
    private static let installOnce: Void = {
        // `setErrorHandler` is deprecated in favour of the scoped
        // `withError`/`withErrorHandler` APIs, but those only apply within a
        // block. This is the only public API that sets a process-wide handler,
        // and a browser must never let a library error hard-kill the process.
        MLX.setErrorHandler({ message, _ in
            let text = message.map { String(cString: $0) } ?? "unknown MLX error"
            // Log for diagnostics; never terminate the process.
            Foundation.NSLog("MLX error (non-fatal): %@", text)
        }, data: nil, dtor: nil)
    }()
    #endif
}
