import SwiftUI
import WebKit
import HiveCore

// MARK: - ReaderModeView
//
// Renders an extracted article in a calm, readable surface (SPEC §25). The chrome is hidden
// so the user can focus on the text. A simple header shows the title, byline, and host, with
// a close button to exit reader mode. Supports Read Aloud (SPEC §25.3) via AVSpeechSynthesizer
// with sentence-level tracking and speed controls.

struct ReaderModeView: View {

    let artifact: ReaderArtifact
    let onClose: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("hive.reader.textScale") private var readerTextScale = 1.0
    @AppStorage("hive.reader.fontFamily") private var readerFontFamily = "system"
    @State private var showReadAloud = false
    @State private var showTypography = false
    @State private var readAloudManager = ReadAloudManager()

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, HiveSpacing.s24)
                .padding(.top, HiveSpacing.s16)
                .padding(.bottom, HiveSpacing.s8)

            // Read Aloud toolbar (slides in from top with spring)
            if showReadAloud {
                ReadAloudToolbarView(manager: readAloudManager)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.bottom, HiveSpacing.s8)
            }

            Divider().overlay(Color.hiveBorderSubtle)

            ReaderWebView(
                html: readerHTML,
                baseURL: artifact.url,
                textScale: readerTextScale,
                fontFamily: readerFontFamily,
                highlightRange: $readAloudManager.highlightedNSRange
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.hiveBackground)
        .onAppear {
            readAloudManager.load(article: stripHTML(artifact.contentHTML))
        }
        .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.92), value: showReadAloud)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                    Text(artifact.title.isEmpty ? "Reader Mode" : artifact.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.hiveInk)
                        .lineLimit(2)
                    if !artifact.byline.isEmpty {
                        Text(artifact.byline)
                            .hiveType(.bodySmall)
                            .foregroundStyle(.hiveGraphite)
                    }
                    if let host = artifact.url?.host {
                        Text(host)
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveGraphite)
                    }
                }
                Spacer()

                // Header action buttons
                HStack(spacing: HiveSpacing.s8) {
                    // Typography controls
                    Button {
                        showTypography.toggle()
                    } label: {
                        Text("Aa")
                            .font(HiveTypography.font(.brandSubtitle))
                            .foregroundStyle(showTypography ? Color.hiveAccent : .hiveGraphite)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderless)
                    .popover(isPresented: $showTypography, arrowEdge: .top) {
                        typographyPopover
                    }
                    .help("Reader appearance")
                    .accessibilityLabel("Reader appearance")
                    .accessibilityHint("Adjust text size and typeface")

                    // Read Aloud toggle
                    Button {
                        withAnimation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.92)) {
                            showReadAloud.toggle()
                            if !showReadAloud {
                                readAloudManager.stop()
                            }
                        }
                    } label: {
                        Image(systemName: showReadAloud ? "speaker.wave.2.fill" : "speaker.wave.2")
                            .foregroundStyle(showReadAloud ? Color.hiveAccent : .hiveGraphite)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.borderless)
                    .help(showReadAloud ? "Close read aloud" : "Read aloud")
                    .accessibilityLabel(showReadAloud ? "Close read aloud" : "Read aloud")

                    // Close reader mode
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundStyle(.hiveInk)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.hiveSurface))
                    }
                    .buttonStyle(.borderless)
                    .help("Close reader mode")
                    .accessibilityLabel("Close reader mode")
                }
            }
        }
    }

    // MARK: - Typography controls

    private var typographyPopover: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s16) {
            Text("Reader appearance")
                .hiveType(.chromeTitle)
                .foregroundStyle(.hiveInk)

            HStack {
                Label("Text size", systemImage: "textformat.size")
                    .hiveType(.bodySmall)
                    .foregroundStyle(.hiveGraphite)
                Spacer()
                Button {
                    readerTextScale = max(0.85, readerTextScale - 0.1)
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(readerTextScale <= 0.85)
                .accessibilityLabel("Decrease text size")

                Text("\(Int(readerTextScale * 100))%")
                    .hiveType(.bodySmall)
                    .monospacedDigit()
                    .foregroundStyle(.hiveInk)
                    .frame(width: 42)
                    .multilineTextAlignment(.center)

                Button {
                    readerTextScale = min(1.5, readerTextScale + 0.1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(readerTextScale >= 1.5)
                .accessibilityLabel("Increase text size")
            }

            Divider().overlay(Color.hiveBorderSubtle)

            Picker("Typeface", selection: $readerFontFamily) {
                Text("System").tag("system")
                Text("Serif").tag("serif")
                Text("Mono").tag("mono")
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .accessibilityLabel("Reader typeface")
        }
        .padding(HiveSpacing.s16)
        .frame(width: 220)
    }

    // MARK: - HTML-to-Text

    /// Strips HTML tags from contentHTML to produce plain text for AVSpeechSynthesizer.
    /// Preserves paragraph spacing for natural speech pauses.
    private func stripHTML(_ html: String) -> String {
        let noStyle = html.replacingOccurrences(
            of: "<style[^>]*>[\\s\\S]*?</style>",
            with: "",
            options: .regularExpression
        )
        let noScript = noStyle.replacingOccurrences(
            of: "<script[^>]*>[\\s\\S]*?</script>",
            with: "",
            options: .regularExpression
        )
        var text = noScript
        let blockTags = ["<br\\s*/?>", "<p>", "</p>", "<div>", "</div>", "<li>", "<h[1-6]>", "</h[1-6]>"]
        for tag in blockTags {
            text = text.replacingOccurrences(of: tag, with: "\n", options: .regularExpression)
        }
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        while text.contains("\n\n\n") {
            text = text.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Styled HTML document

    private var readerHTML: String {
        let title = artifact.title
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let bylineHTML = artifact.byline
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        let bylineTag = bylineHTML.isEmpty ? "" : "<p class=\"byline\">\(bylineHTML)</p>"
        let css = readerCSS
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>\(css)</style>
        </head>
        <body>
            <article>
                <h1>\(title)</h1>
                __BYLINE_TAG__
                <div class="content">\(artifact.contentHTML)</div>
            </article>
        </body>
        </html>
        """.replacingOccurrences(of: "__BYLINE_TAG__", with: bylineTag)
    }

    private var readerCSS: String {
        let bg = colorScheme == .dark ? "#1a1815" : "#faf8f5"
        let ink = colorScheme == .dark ? "#f2efe9" : "#1a1815"
        let muted = colorScheme == .dark ? "#a8a29e" : "#6b665f"
        let link = colorScheme == .dark ? "#f4a261" : "#d97706"
        return """
            :root {
                color-scheme: light dark;
                --reader-scale: 1;
                --reader-font: -apple-system, BlinkMacSystemFont, sans-serif;
            }
            body {
                font-family: var(--reader-font);
                font-size: calc(18px * var(--reader-scale));
                line-height: 1.7;
                color: \(ink);
                background: \(bg);
                margin: 0;
                padding: 0;
            }
            article { max-width: 720px; margin: 0 auto; padding: 24px 32px 80px; }
            h1 { font-size: 32px; line-height: 1.25; font-weight: 700; margin: 0 0 12px; }
            .byline { color: \(muted); font-size: 15px; margin: 0 0 28px; }
            p { margin: 0 0 18px; }
            img { max-width: 100%; height: auto; border-radius: 8px; margin: 18px 0; }
            figure { margin: 24px 0; }
            a { color: \(link); text-decoration: underline; }
            blockquote { border-left: 4px solid \(link); margin: 18px 0; padding-left: 18px; color: \(muted); }
            ul, ol { margin: 0 0 18px 20px; }
            li { margin-bottom: 6px; }
            h2, h3, h4 { margin-top: 32px; margin-bottom: 12px; }
            pre, code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; background: rgba(0,0,0,0.05); border-radius: 4px; }
            pre { padding: 14px; overflow-x: auto; }

            /* Read Aloud sentence highlight — CSS Highlight API */
            @supports (::highlight(speech-highlight)) {
                ::highlight(speech-highlight) {
                    background-color: \(link);
                    color: \(bg);
                    border-radius: 2px;
                }
            }
        """
    }
}

// MARK: - ReaderWebView

/// Renders the reader-mode HTML article with sentence-synced highlighting for Read Aloud.
/// Injects a JS highlighting engine at page load that maps plain-text NSRange offsets
/// back to DOM text nodes using the CSS Highlight API (CSS.highlights) with a
/// ::highlight(speech-highlight) pseudo-element — no DOM mutation, high performance.
///
/// When `highlightRange` changes (from ReadAloudManager), calls evaluateJavaScript
/// to update the active highlight via the pre-registered `window.highlightTextRange`.

private struct ReaderWebView: NSViewRepresentable {

    let html: String
    let baseURL: URL?
    let textScale: Double
    let fontFamily: String
    @Binding var highlightRange: NSRange

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var htmlLoaded = false
        var isLoadingHTML = false
        var lastSentRange: NSRange = .init(location: NSNotFound, length: 0)
        var pendingFirstHighlight: NSRange = .init(location: NSNotFound, length: 0)
        var pendingTextScale = 1.0
        var pendingFontFamily = "system"
        var lastAppliedTextScale: Double?
        var lastAppliedFontFamily: String?

        func updateTypography(textScale: Double, fontFamily: String) {
            pendingTextScale = textScale
            pendingFontFamily = fontFamily
            guard htmlLoaded, let wv = webView else { return }
            guard lastAppliedTextScale != textScale || lastAppliedFontFamily != fontFamily else { return }

            let cssFont: String
            switch fontFamily {
            case "serif": cssFont = "Georgia, Times New Roman, serif"
            case "mono": cssFont = "ui-monospace, SFMono-Regular, Menlo, monospace"
            default: cssFont = "-apple-system, BlinkMacSystemFont, sans-serif"
            }
            let clampedScale = min(max(textScale, 0.85), 1.5)
            let js = "document.documentElement.style.setProperty('--reader-scale', '\(clampedScale)'); document.documentElement.style.setProperty('--reader-font', '\(cssFont)');"
            wv.evaluateJavaScript(js, completionHandler: nil)
            lastAppliedTextScale = textScale
            lastAppliedFontFamily = fontFamily
        }

        func updateHighlight(_ range: NSRange) {
            guard htmlLoaded, let wv = webView else {
                // WebView/document not ready yet — save for after load.
                pendingFirstHighlight = range
                return
            }
            // Skip if range hasn't changed
            if range.location == lastSentRange.location && range.length == lastSentRange.length {
                return
            }
            lastSentRange = range

            if range.location == NSNotFound || range.length == 0 {
                wv.evaluateJavaScript("window.clearHighlight();", completionHandler: nil)
            } else {
                let js = "window.highlightTextRange(\(range.location), \(range.length));"
                wv.evaluateJavaScript(js, completionHandler: nil)
            }
        }

        // MARK: - WKNavigationDelegate

        nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                htmlLoaded = true
                isLoadingHTML = false
                // Apply typography after the document exists, preserving scroll position.
                lastAppliedTextScale = nil
                lastAppliedFontFamily = nil
                updateTypography(textScale: pendingTextScale, fontFamily: pendingFontFamily)
                // Fire any highlight that was queued before page load
                if pendingFirstHighlight.location != NSNotFound {
                    let pending = pendingFirstHighlight
                    pendingFirstHighlight = .init(location: NSNotFound, length: 0)
                    updateHighlight(pending)
                }
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                htmlLoaded = false
                isLoadingHTML = false
            }
        }

        nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                htmlLoaded = false
                isLoadingHTML = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let prefs = WKWebpagePreferences()
        // Enable JS so evaluateJavaScript and CSS Highlight API work
        prefs.allowsContentJavaScript = true

        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences = prefs

        // Inject the highlighting JS engine early
        let highlightJS = highlightJSEngine
        let script = WKUserScript(
            source: highlightJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(script)

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.isInspectable = false
        wv.navigationDelegate = context.coordinator
        context.coordinator.webView = wv
        return wv
    }

    func updateNSView(_ wv: WKWebView, context: Context) {
        // Only reload HTML if the content actually changed
        if !context.coordinator.htmlLoaded && !context.coordinator.isLoadingHTML {
            context.coordinator.isLoadingHTML = true
            wv.loadHTMLString(html, baseURL: baseURL)
        }
        context.coordinator.updateTypography(textScale: textScale, fontFamily: fontFamily)
        // Defer highlight update until HTML is actually rendered
        context.coordinator.updateHighlight(highlightRange)
    }

    // MARK: - JS Highlighting Engine
    //
    // Uses CSS Custom Highlight API (CSS.highlights) to highlight text ranges
    // without mutating the DOM. Walks text nodes via TreeWalker to map UTF-16
    // offsets from AVSpeechSynthesizer to exact DOM Range objects.

    private var highlightJSEngine: String {
        """
        (function() {
            "use strict";

            function walkTextNodes(root) {
                const walker = document.createTreeWalker(
                    root,
                    NodeFilter.SHOW_TEXT,
                    null,
                    false
                );
                const nodes = [];
                let offset = 0;
                let node;
                while ((node = walker.nextNode())) {
                    const len = node.nodeValue.length;
                    nodes.push({ node, start: offset, end: offset + len });
                    offset += len;
                }
                return nodes;
            }

            window.highlightTextRange = function(location, length) {
                // Clear previous first
                CSS.highlights.delete("speech-highlight");

                if (length === 0) return;

                const textNodes = walkTextNodes(document.body);
                const targetEnd = location + length;
                const range = document.createRange();
                let started = false;
                let ended = false;

                for (const item of textNodes) {
                    if (!started && location >= item.start && location <= item.end) {
                        range.setStart(item.node, Math.min(location - item.start, item.node.nodeValue.length));
                        started = true;
                    }
                    if (started && !ended && targetEnd >= item.start && targetEnd <= item.end) {
                        range.setEnd(item.node, Math.min(targetEnd - item.start, item.node.nodeValue.length));
                        ended = true;
                        break;
                    }
                }

                if (started && ended) {
                    try {
                        const highlight = new Highlight(range);
                        CSS.highlights.set("speech-highlight", highlight);
                        // Scroll active sentence into view
                        const rects = range.getClientRects();
                        if (rects.length > 0) {
                            const rect = rects[0];
                            const scrollY = window.scrollY;
                            const viewportMid = window.innerHeight / 2;
                            const rectMid = rect.top + rect.height / 2;
                            window.scrollTo({
                                top: scrollY + rectMid - viewportMid,
                                behavior: "smooth"
                            });
                        }
                    } catch(e) {
                        console.warn("Highlight failed:", e);
                    }
                }
            };

            window.clearHighlight = function() {
                CSS.highlights.delete("speech-highlight");
            };
        })();
        """
    }
}


