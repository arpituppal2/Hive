import SwiftUI
import AppKit
import HiveCore

// MARK: - ScreenshotOverlayView
//
// A fullscreen overlay that shows a captured page screenshot with a toolbar for
// Copy to Clipboard, Save to Downloads, Save to Honeycomb, Share, and Close.
// Dismissed via Esc key or the close button.
//
// Design: The screenshot is displayed at its natural resolution in the center of the
// screen (scaled down if larger than the window). A translucent scrim behind it provides
// visual focus. The toolbar sits at the bottom, floating above the scrim with a glass
// material effect — feels native, stays out of the way.

struct ScreenshotOverlayView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ChromeState.self) private var state
    @State private var isCopied = false
    @State private var isSaved = false
    @State private var image: NSImage?
    @State private var imageSize: CGSize = .zero

    var body: some View {
        ZStack {
            // Scrim — translucent backdrop that focuses attention on the screenshot.
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .transition(.opacity)

            if let image {
                VStack(spacing: HiveSpacing.s24) {
                    Spacer()

                    // Screenshot image — rendered at natural size, capped to 80% of
                    // each dimension, with rounded corners and a subtle shadow.
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(
                            maxWidth: min(imageSize.width, NSScreen.main?.frame.width ?? 1200) * 0.85,
                            maxHeight: min(imageSize.height, NSScreen.main?.frame.height ?? 900) * 0.75
                        )
                        .clipShape(RoundedRectangle(cornerRadius: HiveRadius.r12))
                        .shadow(color: .black.opacity(0.25), radius: 30, y: 8)
                        .scaleEffect(0.95)
                        .transition(.scale(scale: 0.92).combined(with: .opacity))
                        .accessibilityLabel("Captured screenshot")
                        .accessibilityAddTraits(.isImage)

                    // Toolbar — glass-like pill floating below the screenshot.
                    toolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                    Spacer()
                        .frame(height: HiveSpacing.s48)
                }
            } else {
                ProgressView("Capturing…")
                    .hiveType(.body)
                    .foregroundStyle(.white)
                    .transition(.opacity)
                    .accessibilityLabel("Capturing screenshot")
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: state.screenshotData) { _, _ in
            loadImage()
        }
        .background(
            // Esc key dismisses the overlay.
            Button("") { dismissScreenshot() }
                .keyboardShortcut(.escape, modifiers: [])
                .hidden()
        )
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel("Screenshot overlay")
        .accessibilityHint("Use the toolbar to copy, save, share, or close the screenshot")
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: HiveSpacing.s4) {
            toolButton(
                icon: isCopied ? "checkmark" : "doc.on.doc",
                label: isCopied ? "Copied" : "Copy",
                action: copyToClipboard
            )
            Divider()
                .frame(height: 20)
                .overlay(.white.opacity(0.2))

            toolButton(
                icon: isSaved ? "checkmark" : "arrow.down.doc",
                label: isSaved ? "Saved" : "Save",
                action: saveToDownloads
            )
            Divider()
                .frame(height: 20)
                .overlay(.white.opacity(0.2))

            toolButton(
                icon: "hexagon",
                label: "Save to Memory",
                action: saveToHoneycomb
            )
            Divider()
                .frame(height: 20)
                .overlay(.white.opacity(0.2))

            toolButton(
                icon: "square.and.arrow.up",
                label: "Share",
                action: share
            )
            Divider()
                .frame(height: 20)
                .overlay(.white.opacity(0.2))

            toolButton(
                icon: "xmark",
                label: "Close",
                action: dismissScreenshot
            )
        }
        .padding(.horizontal, HiveSpacing.s16)
        .padding(.vertical, HiveSpacing.s8)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r12)
                .fill(.ultraThinMaterial)
                .preferredColorScheme(.dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.r12)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 16, y: 6)
    }

    // MARK: - Tool button

    private func toolButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: HiveSpacing.s4) {
                Image(systemName: icon)
                    .font(HiveTypography.font(.sectionTitle))
                Text(label)
                    .hiveType(.caption2)
            }
            .foregroundStyle(.white.opacity(0.9))
            .frame(minWidth: 56)
            .padding(.horizontal, HiveSpacing.s8)
            .padding(.vertical, HiveSpacing.s4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .help(label)
    }

    // MARK: - Actions

    private func copyToClipboard() {
        guard let data = state.screenshotData else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(data, forType: .png)
        withAnimation(reduceMotion ? nil : .spring(response: 0.2)) { isCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { isCopied = false }
        }
    }

    private func saveToDownloads() {
        guard let data = state.screenshotData else { return }
        let filename = "Screenshot \(Date().formatted(date: .numeric, time: .shortened)).png"
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: ".")
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: tempURL)
            // Move to Downloads folder.
            if let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                let destURL = downloadsDir.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: destURL)
                try FileManager.default.moveItem(at: tempURL, to: destURL)
            }
        } catch {
            // Fall back to temp directory.
        }
        withAnimation(reduceMotion ? nil : .spring(response: 0.2)) { isSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { isSaved = false }
        }
    }

    private func saveToHoneycomb() {
        // Capture the screenshot as a Honeycomb Artifact for later retrieval.
        guard let data = state.screenshotData else { return }
        let fileName = "Screenshot \(Date().ISO8601Format()).png"
        // Persist the file to the app support directory for later retrieval.
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                    in: .userDomainMask).first
        let hiveDir = appSupport?.appendingPathComponent("Hive/Screenshots", isDirectory: true)
        if let dir = hiveDir {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let fileURL = dir.appendingPathComponent(fileName)
            try? data.write(to: fileURL)
        }
        // Also index in Honeycomb as an artifact.
        let fileURL = hiveDir?.appendingPathComponent(fileName)
        if let url = fileURL {
            Task {
                guard let honeycomb = state.honeycomb else { return }
                let meta = JSONValue.object([
                    "filename": .string(fileName),
                    "filePath": .string(url.path),
                    "dataSize": .int(data.count),
                    "mimeType": .string("image/png")
                ])
                let node = HoneycombStore.Node(
                    type: .artifact,
                    label: fileName,
                    metadata: meta,
                    contentHash: HoneycombStore.sha256(data.base64EncodedString()),
                    provenance: "screenshot-capture"
                )
                _ = try? await honeycomb.insertNode(node)
            }
        }
        dismissScreenshot()
    }

    private func share() {
        guard let data = state.screenshotData else { return }
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("share_temp.png")
        try? data.write(to: tempURL)
        let picker = NSSharingServicePicker(items: [tempURL])
        if let window = NSApp.keyWindow, let contentView = window.contentView {
            picker.show(relativeTo: .zero, of: contentView, preferredEdge: .maxY)
        }
    }

    private func dismissScreenshot() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.85)) {
            state.dismissScreenshot()
        }
    }

    private func loadImage() {
        guard let data = state.screenshotData else { return }
        if let nsImage = NSImage(data: data) {
            image = nsImage
            imageSize = nsImage.size
        }
    }
}
