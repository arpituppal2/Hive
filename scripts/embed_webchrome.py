#!/usr/bin/env python3
"""Embed the Hive web chrome (real HTML/CSS/JS) into Swift string constants.

The CEF bundler does not copy SwiftPM resources into the .app, so we ship the
web chrome exactly the way CefSwift ships its JS bridge shim: the real files
live on disk (editable, iterable) and a generated Swift file inlines them as
raw string literals. Run this after editing any file in WebChrome/:

    python3 Scripts/embed_webchrome.py

The generated file is checked in; the app never reads from the source tree.
"""
import base64
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WEB = ROOT / "Sources" / "Hive" / "WebChrome"
OUT = ROOT / "Sources" / "Hive" / "WebChromeAssets.swift"

# name, relative path, mime type
FILES = [
    ("indexHTML", "index.html", "text/html"),
    ("stylesCSS", "styles.css", "text/css"),
    ("tokensCSS", "tokens.css", "text/css"),
    ("appJS", "app.js", "application/javascript"),
    # The Morning Brief (ported from the Dia bundle, license-cleared).
    ("briefHTML", "brief/index.html", "text/html"),
    ("briefCSS", "brief/style.css", "text/css"),
    ("briefFeedbackCSS", "brief/feedback.css", "text/css"),
    ("briefLookingAheadCSS", "brief/looking-ahead.css", "text/css"),
    ("briefAppJS", "brief/app.js", "application/javascript"),
    ("briefFeedbackJS", "brief/feedback.js", "application/javascript"),
    ("briefLookingAheadJS", "brief/looking-ahead.js", "application/javascript"),
    # Polar AgentApp (copied from Polar bundle, legally authorized).
    # HTML and CSS embed as text (always clean printable ASCII/UTF-8).
    ("polarIndex", "polar/index.html", "text/html"),
    ("polarCSS", "polar/assets/index-BY6JzNer.css", "text/css"),
]

# Polar JS assets — Vite-bundled minified files that contain binary data
# (ZIP headers, null bytes, base64-embedded fonts/images).  These are
# base64-encoded at embed time and decoded at serve time, stored as
# "{name}Base64" in WebChromeAssets.
BINARY_FILES = [
    ("polarAppJS", "polar/assets/index-QWD3Wno1.js", "application/javascript"),
    ("polarAgentSurfaceJS", "polar/assets/agentSurface-TavgROI7.js", "application/javascript"),
    ("polarCommandPanelJS", "polar/assets/CommandPanelPage-CQPc9sFE.js", "application/javascript"),
    ("polarModalJS", "polar/assets/ModalAgentAppPage-DT0g5KTd.js", "application/javascript"),
    ("polarWindowJS", "polar/assets/WindowAgentAppPage-CzJKotYB.js", "application/javascript"),
    ("polarDocxJS", "polar/assets/docx-preview-ChFBTZoq.js", "application/javascript"),
    ("polarHighlightedBodyJS", "polar/assets/highlighted-body-OFNGDK62-BsqO-kRD.js", "application/javascript"),
    ("polarMermaidJS", "polar/assets/mermaid-GHXKKRXX-D0lw7t8a.js", "application/javascript"),
    ("polarReferralCardJS", "polar/assets/ReferralCardPreviewPage-CDEMiD_U.js", "application/javascript"),
    ("polarReferralMilestoneJS", "polar/assets/ReferralMilestoneCard-DwOWE_LT.js", "application/javascript"),
    ("polarXlsxJS", "polar/assets/xlsx-CkFp8p6R.js", "application/javascript"),
    ("polarInvitePNG", "polar/assets/invite-envelope-n37wvGqS.png", "image/png"),
]

# Fonts and binary assets: (display name, relative path from WebChrome/, mime hint).
FONTS = [
    ("Exposure-400.woff2", "brief/fonts/Exposure-400.woff2", "font/woff2"),
    ("Exposure-500.woff2", "brief/fonts/Exposure-500.woff2", "font/woff2"),
    ("Exposure-550.woff2", "brief/fonts/Exposure-550.woff2", "font/woff2"),
    ("Exposure-550-Italic.woff2", "brief/fonts/Exposure-550-Italic.woff2", "font/woff2"),
    ("Exposure-600.woff2", "brief/fonts/Exposure-600.woff2", "font/woff2"),
    # Polar KaTeX fonts — embed so the AgentApp renders LaTeX math offline.
    ("polar/KaTeX_AMS-Regular-BQhdFMY1.woff2", "polar/assets/KaTeX_AMS-Regular-BQhdFMY1.woff2", "font/woff2"),
    ("polar/KaTeX_AMS-Regular-DMm9YOAa.woff", "polar/assets/KaTeX_AMS-Regular-DMm9YOAa.woff", "font/woff"),
    ("polar/KaTeX_AMS-Regular-DRggAlZN.ttf", "polar/assets/KaTeX_AMS-Regular-DRggAlZN.ttf", "font/ttf"),
    ("polar/KaTeX_Caligraphic-Bold-ATXxdsX0.ttf", "polar/assets/KaTeX_Caligraphic-Bold-ATXxdsX0.ttf", "font/ttf"),
    ("polar/KaTeX_Caligraphic-Bold-BEiXGLvX.woff", "polar/assets/KaTeX_Caligraphic-Bold-BEiXGLvX.woff", "font/woff"),
    ("polar/KaTeX_Caligraphic-Bold-Dq_IR9rO.woff2", "polar/assets/KaTeX_Caligraphic-Bold-Dq_IR9rO.woff2", "font/woff2"),
    ("polar/KaTeX_Caligraphic-Regular-CTRA-rTL.woff", "polar/assets/KaTeX_Caligraphic-Regular-CTRA-rTL.woff", "font/woff"),
    ("polar/KaTeX_Caligraphic-Regular-Di6jR-x-.woff2", "polar/assets/KaTeX_Caligraphic-Regular-Di6jR-x-.woff2", "font/woff2"),
    ("polar/KaTeX_Caligraphic-Regular-wX97UBjC.ttf", "polar/assets/KaTeX_Caligraphic-Regular-wX97UBjC.ttf", "font/ttf"),
    ("polar/KaTeX_Fraktur-Bold-BdnERNNW.ttf", "polar/assets/KaTeX_Fraktur-Bold-BdnERNNW.ttf", "font/ttf"),
    ("polar/KaTeX_Fraktur-Bold-BsDP51OF.woff", "polar/assets/KaTeX_Fraktur-Bold-BsDP51OF.woff", "font/woff"),
    ("polar/KaTeX_Fraktur-Bold-CL6g_b3V.woff2", "polar/assets/KaTeX_Fraktur-Bold-CL6g_b3V.woff2", "font/woff2"),
    ("polar/KaTeX_Fraktur-Regular-CB_wures.ttf", "polar/assets/KaTeX_Fraktur-Regular-CB_wures.ttf", "font/ttf"),
    ("polar/KaTeX_Fraktur-Regular-CTYiF6lA.woff2", "polar/assets/KaTeX_Fraktur-Regular-CTYiF6lA.woff2", "font/woff2"),
    ("polar/KaTeX_Fraktur-Regular-Dxdc4cR9.woff", "polar/assets/KaTeX_Fraktur-Regular-Dxdc4cR9.woff", "font/woff"),
    ("polar/KaTeX_Main-Bold-Cx986IdX.woff2", "polar/assets/KaTeX_Main-Bold-Cx986IdX.woff2", "font/woff2"),
    ("polar/KaTeX_Main-Bold-Jm3AIy58.woff", "polar/assets/KaTeX_Main-Bold-Jm3AIy58.woff", "font/woff"),
    ("polar/KaTeX_Main-Bold-waoOVXN0.ttf", "polar/assets/KaTeX_Main-Bold-waoOVXN0.ttf", "font/ttf"),
    ("polar/KaTeX_Main-BoldItalic-DxDJ3AOS.woff2", "polar/assets/KaTeX_Main-BoldItalic-DxDJ3AOS.woff2", "font/woff2"),
    ("polar/KaTeX_Main-BoldItalic-DzxPMmG6.ttf", "polar/assets/KaTeX_Main-BoldItalic-DzxPMmG6.ttf", "font/ttf"),
    ("polar/KaTeX_Main-BoldItalic-SpSLRI95.woff", "polar/assets/KaTeX_Main-BoldItalic-SpSLRI95.woff", "font/woff"),
    ("polar/KaTeX_Main-Italic-3WenGoN9.ttf", "polar/assets/KaTeX_Main-Italic-3WenGoN9.ttf", "font/ttf"),
    ("polar/KaTeX_Main-Italic-BMLOBm91.woff", "polar/assets/KaTeX_Main-Italic-BMLOBm91.woff", "font/woff"),
    ("polar/KaTeX_Main-Italic-NWA7e6Wa.woff2", "polar/assets/KaTeX_Main-Italic-NWA7e6Wa.woff2", "font/woff2"),
    ("polar/KaTeX_Main-Regular-B22Nviop.woff2", "polar/assets/KaTeX_Main-Regular-B22Nviop.woff2", "font/woff2"),
    ("polar/KaTeX_Main-Regular-Dr94JaBh.woff", "polar/assets/KaTeX_Main-Regular-Dr94JaBh.woff", "font/woff"),
    ("polar/KaTeX_Main-Regular-ypZvNtVU.ttf", "polar/assets/KaTeX_Main-Regular-ypZvNtVU.ttf", "font/ttf"),
    ("polar/KaTeX_Math-BoldItalic-B3XSjfu4.ttf", "polar/assets/KaTeX_Math-BoldItalic-B3XSjfu4.ttf", "font/ttf"),
    ("polar/KaTeX_Math-BoldItalic-CZnvNsCZ.woff2", "polar/assets/KaTeX_Math-BoldItalic-CZnvNsCZ.woff2", "font/woff2"),
    ("polar/KaTeX_Math-BoldItalic-iY-2wyZ7.woff", "polar/assets/KaTeX_Math-BoldItalic-iY-2wyZ7.woff", "font/woff"),
    ("polar/KaTeX_Math-Italic-DA0__PXp.woff", "polar/assets/KaTeX_Math-Italic-DA0__PXp.woff", "font/woff"),
    ("polar/KaTeX_Math-Italic-flOr_0UB.ttf", "polar/assets/KaTeX_Math-Italic-flOr_0UB.ttf", "font/ttf"),
    ("polar/KaTeX_Math-Italic-t53AETM-.woff2", "polar/assets/KaTeX_Math-Italic-t53AETM-.woff2", "font/woff2"),
    ("polar/KaTeX_SansSerif-Bold-CFMepnvq.ttf", "polar/assets/KaTeX_SansSerif-Bold-CFMepnvq.ttf", "font/ttf"),
    ("polar/KaTeX_SansSerif-Bold-D1sUS0GD.woff2", "polar/assets/KaTeX_SansSerif-Bold-D1sUS0GD.woff2", "font/woff2"),
    ("polar/KaTeX_SansSerif-Bold-DbIhKOiC.woff", "polar/assets/KaTeX_SansSerif-Bold-DbIhKOiC.woff", "font/woff"),
    ("polar/KaTeX_SansSerif-Italic-C3H0VqGB.woff2", "polar/assets/KaTeX_SansSerif-Italic-C3H0VqGB.woff2", "font/woff2"),
    ("polar/KaTeX_SansSerif-Italic-DN2j7dab.woff", "polar/assets/KaTeX_SansSerif-Italic-DN2j7dab.woff", "font/woff"),
    ("polar/KaTeX_SansSerif-Italic-YYjJ1zSn.ttf", "polar/assets/KaTeX_SansSerif-Italic-YYjJ1zSn.ttf", "font/ttf"),
    ("polar/KaTeX_SansSerif-Regular-BNo7hRIc.ttf", "polar/assets/KaTeX_SansSerif-Regular-BNo7hRIc.ttf", "font/ttf"),
    ("polar/KaTeX_SansSerif-Regular-CS6fqUqJ.woff", "polar/assets/KaTeX_SansSerif-Regular-CS6fqUqJ.woff", "font/woff"),
    ("polar/KaTeX_SansSerif-Regular-DDBCnlJ7.woff2", "polar/assets/KaTeX_SansSerif-Regular-DDBCnlJ7.woff2", "font/woff2"),
    ("polar/KaTeX_Script-Regular-C5JkGWo-.ttf", "polar/assets/KaTeX_Script-Regular-C5JkGWo-.ttf", "font/ttf"),
    ("polar/KaTeX_Script-Regular-D3wIWfF6.woff2", "polar/assets/KaTeX_Script-Regular-D3wIWfF6.woff2", "font/woff2"),
    ("polar/KaTeX_Script-Regular-D5yQViql.woff", "polar/assets/KaTeX_Script-Regular-D5yQViql.woff", "font/woff"),
    ("polar/KaTeX_Size1-Regular-C195tn64.woff", "polar/assets/KaTeX_Size1-Regular-C195tn64.woff", "font/woff"),
    ("polar/KaTeX_Size1-Regular-Dbsnue_I.ttf", "polar/assets/KaTeX_Size1-Regular-Dbsnue_I.ttf", "font/ttf"),
    ("polar/KaTeX_Size1-Regular-mCD8mA8B.woff2", "polar/assets/KaTeX_Size1-Regular-mCD8mA8B.woff2", "font/woff2"),
    ("polar/KaTeX_Size2-Regular-B7gKUWhC.ttf", "polar/assets/KaTeX_Size2-Regular-B7gKUWhC.ttf", "font/ttf"),
    ("polar/KaTeX_Size2-Regular-Dy4dx90m.woff2", "polar/assets/KaTeX_Size2-Regular-Dy4dx90m.woff2", "font/woff2"),
    ("polar/KaTeX_Size2-Regular-oD1tc_U0.woff", "polar/assets/KaTeX_Size2-Regular-oD1tc_U0.woff", "font/woff"),
    ("polar/KaTeX_Size3-Regular-CTq5MqoE.woff", "polar/assets/KaTeX_Size3-Regular-CTq5MqoE.woff", "font/woff"),
    ("polar/KaTeX_Size3-Regular-DgpXs0kz.ttf", "polar/assets/KaTeX_Size3-Regular-DgpXs0kz.ttf", "font/ttf"),
    ("polar/KaTeX_Size4-Regular-BF-4gkZK.woff", "polar/assets/KaTeX_Size4-Regular-BF-4gkZK.woff", "font/woff"),
    ("polar/KaTeX_Size4-Regular-Dl5lxZxV.woff2", "polar/assets/KaTeX_Size4-Regular-Dl5lxZxV.woff2", "font/woff2"),
    ("polar/KaTeX_Size4-Regular-DWFBv043.ttf", "polar/assets/KaTeX_Size4-Regular-DWFBv043.ttf", "font/ttf"),
    ("polar/KaTeX_Typewriter-Regular-C0xS9mPB.woff", "polar/assets/KaTeX_Typewriter-Regular-C0xS9mPB.woff", "font/woff"),
    ("polar/KaTeX_Typewriter-Regular-CO6r4hn1.woff2", "polar/assets/KaTeX_Typewriter-Regular-CO6r4hn1.woff2", "font/woff2"),
    ("polar/KaTeX_Typewriter-Regular-D3Ib7_Hf.ttf", "polar/assets/KaTeX_Typewriter-Regular-D3Ib7_Hf.ttf", "font/ttf"),
]


def swift_literal(text: str) -> str:
    content = text.rstrip("\n")
    if '"""#' in content:
        raise ValueError(
            f"Web chrome file contains the raw-literal terminator '\"\"\"#' "
            f"— rename it or split the file."
        )
    return '#"""\n' + content + '\n"""#'


def binary_to_b64(path: pathlib.Path) -> str:
    return base64.b64encode(path.read_bytes()).decode("ascii")


def to_swift_ident(name: str) -> str:
    """Python-safe name → valid Swift identifier (camelCase)."""
    return name


def main() -> int:
    # --- Text assets (HTML, CSS, verified-clean JS) ---
    text_entries = []
    for name, filename, mime in FILES:
        path = WEB / filename
        if not path.exists():
            print(f"error: missing {path}", file=sys.stderr)
            return 1
        text_entries.append((name, path.read_text(), mime))

    # --- Binary assets (polar JS + PNG — may contain null bytes etc.) ---
    binary_entries = []
    for name, filename, mime in BINARY_FILES:
        path = WEB / filename
        if not path.exists():
            print(f"error: missing {path}", file=sys.stderr)
            return 1
        encoded = binary_to_b64(path)
        binary_entries.append((name, encoded, mime))

    # --- Fonts (always binary) ---
    font_entries = []
    for font_name, font_path, font_mime in FONTS:
        path = WEB / font_path
        if not path.exists():
            print(f"error: missing {path}", file=sys.stderr)
            return 1
        encoded = binary_to_b64(path)
        font_entries.append((font_name, encoded, font_mime))

    lines = [
        "// AUTO-GENERATED from Sources/Hive/WebChrome/* — do not edit by hand.",
        "// Regenerate with: python3 Scripts/embed_webchrome.py",
        "// The web chrome ships as Swift constants because the CEF bundler does not",
        "// copy SwiftPM resources into the .app (same pattern as CefBridge.javascriptShim).",
        "import Foundation",
        "",
        "enum WebChromeAssets {",
    ]

    # Text assets
    for name, content, mime in text_entries:
        lines.append(f"    static let {name} = {swift_literal(content)}")

    lines.append("")
    lines.append("    // MARK: Polar binary assets (base64-encoded JS + PNG bundles)")
    for name, encoded, mime in binary_entries:
        lines.append(f'    static let {name}Base64 = "{encoded}"')

    lines.append("")
    lines.append("    // MARK: Fonts (base64-encoded)")
    lines.append("    // Each entry: display-name → (base64, mime-type)")
    lines.append("    static let fontBase64: [String: (data: String, mime: String)] = [")
    for font_name, encoded, font_mime in font_entries:
        lines.append(f'        "{font_name}": ("{encoded}", "{font_mime}"),')
    lines.append("    ]")

    lines.append("")
    lines.append("    /// MIME type for a web chrome path served over hive://.")
    lines.append("    static func mimeType(forPath path: String) -> String {")
    lines.append("        switch path {")
    lines.append('        case "/index.html", "/": return "text/html"')
    lines.append('        case "/styles.css", "/tokens.css": return "text/css"')
    lines.append('        case "/app.js": return "application/javascript"')
    lines.append("        default:")
    lines.append('            if path.hasPrefix("/brief/") { return "text/html" }')
    lines.append("            return \"application/octet-stream\"")
    lines.append("        }")
    lines.append("    }")

    lines.append("")
    lines.append("    /// MIME for a Morning Brief asset (host-form hive://brief/... —")
    lines.append("    /// handler routes by host; the embed keeps text assets for dev parity).")
    lines.append("    static func briefMimeType(forPath path: String) -> String {")
    lines.append("        switch path {")
    lines.append('        case "/", "/index.html": return "text/html"')
    lines.append('        case "/style.css", "/feedback.css", "/looking-ahead.css": return "text/css"')
    lines.append('        case "/app.js", "/feedback.js", "/looking-ahead.js": return "application/javascript"')
    lines.append("        default:")
    lines.append('            if path.hasPrefix("/fonts/") { return "font/woff2" }')
    lines.append("            return \"application/octet-stream\"")
    lines.append("        }")
    lines.append("    }")

    lines.append("")
    lines.append("    /// MIME for a Polar AgentApp asset (served at hive://polar/...).")
    lines.append("    static func polarMimeType(_ path: String) -> String {")
    lines.append("        let ext = (path as NSString).pathExtension.lowercased()")
    lines.append("        switch ext {")
    lines.append('        case "html": return "text/html"')
    lines.append('        case "css": return "text/css"')
    lines.append('        case "js": return "application/javascript"')
    lines.append('        case "woff2": return "font/woff2"')
    lines.append('        case "ttf": return "font/ttf"')
    lines.append('        case "woff": return "font/woff"')
    lines.append('        case "png": return "image/png"')
    lines.append('        case "svg": return "image/svg+xml"')
    lines.append("        default: return \"application/octet-stream\"")
    lines.append("        }")
    lines.append("    }")
    lines.append("}")
    lines.append("")

    OUT.write_text("\n".join(lines))
    print(f"wrote {OUT} ({len(text_entries)} text, {len(binary_entries)} binary, {len(font_entries)} fonts)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
