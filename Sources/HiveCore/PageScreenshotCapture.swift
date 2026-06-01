import Foundation

#if os(macOS)
import CoreGraphics

public struct PageScreenshotCaptureResult: Sendable {
    public var imageURL: URL?
    public var markdownURL: URL
    public var windowTitle: String
    public var appName: String
    public var pageURL: URL?

    public init(imageURL: URL?, markdownURL: URL, windowTitle: String, appName: String, pageURL: URL? = nil) {
        self.imageURL = imageURL
        self.markdownURL = markdownURL
        self.windowTitle = windowTitle
        self.appName = appName
        self.pageURL = pageURL
    }
}

public struct PageScreenshotCapture: Sendable {
    public init() {}

    public func captureCurrentPage(command: String, paths: HivePaths, now: Date = Date()) throws -> PageScreenshotCaptureResult {
        try FileManager.default.createDirectory(at: paths.vaultRawAssets, withIntermediateDirectories: true)
        let window = frontmostContentWindow()
        let base = "page-capture-\(Int(now.timeIntervalSince1970))"
        let imageURL = try window.flatMap { try capture(window: $0, to: paths.vaultRawAssets.appendingPathComponent("\(base).png")) }
        let markdownURL = paths.vaultRawAssets.appendingPathComponent("\(base).md")
        let appName = window?.ownerName ?? "Current page"
        let title = SourcePresentationModel.cleanTitle(window?.windowName ?? "Page capture")
        let pageURL = browserURL(for: appName)
        let commandLine = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageLine = imageURL.map { "![Captured page](flower-field/assets/\($0.lastPathComponent))" } ?? "_Screenshot permission was unavailable; Hive captured the command context only._"
        let urlFrontmatter = pageURL.map { #"source_url: "\#($0.absoluteString.replacingOccurrences(of: "\"", with: "\\\""))""# } ?? #"source_url: """#
        let urlBody = pageURL.map { "\nSource URL: \($0.absoluteString)\n" } ?? ""
        let markdown = """
        ---
        capture_kind: "current-page-screenshot"
        captured_at: "\(ISO8601DateFormatter().string(from: now))"
        capture_command: "\(commandLine.replacingOccurrences(of: "\"", with: "\\\""))"
        capture_app: "\(appName.replacingOccurrences(of: "\"", with: "\\\""))"
        \(urlFrontmatter)
        attachment_folder: "flower-field/assets"
        ---

        # \(title)

        \(commandLine.isEmpty ? "Capture this page as Field evidence for Hive." : commandLine)
        \(urlBody)

        \(imageLine)
        """
        try markdown.write(to: markdownURL, atomically: true, encoding: .utf8)
        return PageScreenshotCaptureResult(imageURL: imageURL, markdownURL: markdownURL, windowTitle: title, appName: appName, pageURL: pageURL)
    }

    private func frontmostContentWindow() -> WindowCandidate? {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        return info.compactMap(WindowCandidate.init(dictionary:))
            .first { candidate in
                candidate.layer == 0
                    && candidate.area > 80_000
                    && !candidate.ownerName.localizedCaseInsensitiveContains("Hive")
                    && !candidate.ownerName.localizedCaseInsensitiveContains("Icon Composer")
            }
    }

    private func capture(window: WindowCandidate, to target: URL) throws -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-l", String(window.windowID), target.path]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0 && FileManager.default.fileExists(atPath: target.path) ? target : nil
    }

    private func browserURL(for appName: String) -> URL? {
        let normalized = appName.lowercased()
        let script: String
        if normalized.contains("safari") {
            script = #"tell application "\#(escapedAppleScriptString(appName))" to return URL of front document"#
        } else if ["chrome", "chromium", "arc", "brave", "edge", "comet"].contains(where: normalized.contains) {
            script = #"tell application "\#(escapedAppleScriptString(appName))" to return URL of active tab of front window"#
        } else {
            return nil
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let value = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return URL(string: value)
        } catch {
            return nil
        }
    }

    private func escapedAppleScriptString(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private struct WindowCandidate {
        var windowID: Int
        var ownerName: String
        var windowName: String
        var layer: Int
        var area: Double

        init?(dictionary: [String: Any]) {
            guard let windowID = dictionary[kCGWindowNumber as String] as? Int,
                  let ownerName = dictionary[kCGWindowOwnerName as String] as? String,
                  let bounds = dictionary[kCGWindowBounds as String] as? [String: Any] else {
                return nil
            }
            let width = bounds["Width"] as? Double ?? 0
            let height = bounds["Height"] as? Double ?? 0
            self.windowID = windowID
            self.ownerName = ownerName
            self.windowName = dictionary[kCGWindowName as String] as? String ?? ownerName
            self.layer = dictionary[kCGWindowLayer as String] as? Int ?? 0
            self.area = width * height
        }
    }
}
#endif
