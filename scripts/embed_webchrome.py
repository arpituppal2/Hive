#!/usr/bin/env python3
"""Embed the Hive web chrome (real HTML/CSS/JS) into Swift string constants.

The CEF bundler does not copy SwiftPM resources into the .app, so we ship the
web chrome exactly the way CefSwift ships its JS bridge shim: the real files
live on disk (editable, iterable) and a generated Swift file inlines them as
raw string literals. Run this after editing any file in WebChrome/:

    python3 Scripts/embed_webchrome.py

The generated file is checked in; the app never reads from the source tree.
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WEB = ROOT / "Sources" / "Hive" / "WebChrome"
OUT = ROOT / "Sources" / "Hive" / "WebChromeAssets.swift"

FILES = [
    ("indexHTML", "index.html", "text/html"),
    ("stylesCSS", "styles.css", "text/css"),
    ("appJS", "app.js", "application/javascript"),
]


def swift_literal(text: str) -> str:
    # Swift raw multiline string: #""" + newline + content + newline + """#.
    # The newline after the opening delimiter and before the closing delimiter
    # are NOT part of the string, so content is preserved byte-for-byte — and
    # because it is a RAW literal, backslashes need no escaping (doubling them
    # would corrupt regexes and \\n sequences in JS/CSS).
    content = text.rstrip("\n")
    # The sequence """# terminates the raw literal. Fail loudly instead of
    # silently producing broken Swift if a future web file ever contains it.
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
    lines.append("    /// MIME type for a web chrome path served over hive://.")
    lines.append("    static func mimeType(forPath path: String) -> String {")
    lines.append("        switch path {")
    lines.append('        case "/index.html", "/": return "text/html"')
    lines.append('        case "/styles.css": return "text/css"')
    lines.append('        case "/app.js": return "application/javascript"')
    lines.append("        default: return \"application/octet-stream\"")
    lines.append("        }")
    lines.append("    }")
    lines.append("}")
    lines.append("")

    OUT.write_text("\n".join(lines))
    print(f"wrote {OUT} ({len(entries)} assets)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
