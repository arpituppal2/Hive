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
]

# Fonts are binary; ship them base64-encoded and decode at runtime.
FONTS = [
    "Exposure-400.woff2",
    "Exposure-500.woff2",
    "Exposure-550.woff2",
    "Exposure-550-Italic.woff2",
    "Exposure-600.woff2",
]


def swift_literal(text: str) -> str:
    content = text.rstrip("\n")
    if '"""#' in content:
        raise ValueError(
            f"Web chrome file contains the raw-literal terminator '\"\"\"#' "
            f"— rename it or split the file."
        )
    return '#"""\n' + content + '\n"""#'


def main() -> int:
    entries = []
    for name, filename, mime in FILES:
        path = WEB / filename
        if not path.exists():
            print(f"error: missing {path}", file=sys.stderr)
            return 1
        entries.append((name, path.read_text(), mime))

    font_entries = []
    for font_name in FONTS:
        path = WEB / "brief" / "fonts" / font_name
        if not path.exists():
            print(f"error: missing {path}", file=sys.stderr)
            return 1
        encoded = base64.b64encode(path.read_bytes()).decode("ascii")
        font_entries.append((font_name, encoded))

    lines = [
        "// AUTO-GENERATED from Sources/Hive/WebChrome/* — do not edit by hand.",
        "// Regenerate with: python3 Scripts/embed_webchrome.py",
        "// The web chrome ships as Swift constants because the CEF bundler does not",
        "// copy SwiftPM resources into the .app (same pattern as CefBridge.javascriptShim).",
        "import Foundation",
        "",
        "enum WebChromeAssets {",
    ]
    for name, content, mime in entries:
        lines.append(f"    static let {name} = {swift_literal(content)}")
    lines.append("")
    lines.append("    // Base64-encoded fonts (decoded lazily at serve time).")
    lines.append("    static let fontBase64: [String: String] = [")
    for font_name, encoded in font_entries:
        lines.append(f'        "{font_name}": "{encoded}",')
    lines.append("    ]")
    lines.append("")
    lines.append("    /// MIME type for a web chrome path served over hive://.")
    lines.append("    static func mimeType(forPath path: String) -> String {")
    lines.append("        switch path {")
    lines.append('        case "/index.html", "/": return "text/html"')
    lines.append('        case "/styles.css", "/tokens.css": return "text/css"')
    lines.append('        case "/app.js": return "application/javascript"')
    lines.append('        case "/brief", "/brief/", "/brief/index.html": return "text/html"')
    lines.append('        case "/brief/style.css", "/brief/feedback.css", "/brief/looking-ahead.css": return "text/css"')
    lines.append('        case "/brief/app.js", "/brief/feedback.js", "/brief/looking-ahead.js": return "application/javascript"')
    lines.append("        default:")
    lines.append('            if path.hasPrefix("/brief/fonts/") { return "font/woff2" }')
    lines.append("            return \"application/octet-stream\"")
    lines.append("        }")
    lines.append("    }")
    lines.append("}")
    lines.append("")

    OUT.write_text("\n".join(lines))
    print(f"wrote {OUT} ({len(entries)} text assets, {len(font_entries)} fonts)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
