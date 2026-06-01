#!/usr/bin/env python3
"""Static Apple HIG/Product audit for Hive.

This intentionally checks implementation boundaries, not broad opinions:
- supplied Apple PDFs are present and extractable
- platform integrations requested by the product are represented in source
- known user-visible debug/material violations are absent from app sources
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Sources"
APPLE_DOCS = [
    Path("/Users/arpituppal/Downloads/APPLE DESIGN DOC.pdf"),
    Path("/Users/arpituppal/Downloads/APPLE COMPONENTS DOC.pdf"),
    Path("/Users/arpituppal/Downloads/APPLE EFFICIENCY DOC.pdf"),
    Path("/Users/arpituppal/Downloads/APPLE INPUT DOC.pdf"),
    Path("/Users/arpituppal/Downloads/APPLE PATTERNS DOC.pdf"),
]
APPLE_DOC_REQUIRED_TERMS = {
    "APPLE DESIGN DOC.pdf": [
        "Designing for iOS",
        "Designing for iPadOS",
        "Designing for macOS",
        "Accessibility",
        "Privacy",
        "Typography",
        "Liquid Glass",
    ],
    "APPLE COMPONENTS DOC.pdf": [
        "Buttons",
        "Collections",
        "Menus",
        "Navigation",
        "Search",
        "Text fields",
        "Toolbars",
    ],
    "APPLE EFFICIENCY DOC.pdf": [
        "App Shortcuts",
        "Controls",
        "Live Activities",
        "Siri",
        "Spotlight",
        "Widgets",
    ],
    "APPLE INPUT DOC.pdf": [
        "Apple Pencil",
        "Drag and drop",
        "Keyboard",
        "Pointer",
        "Siri",
        "Shortcuts",
    ],
    "APPLE PATTERNS DOC.pdf": [
        "Drag and drop",
        "File management",
        "Privacy",
        "Search",
        "Settings",
    ],
}


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def source_files() -> list[Path]:
    return sorted(SOURCES.rglob("*.swift"))


def ui_source_files() -> list[Path]:
    roots = [
        SOURCES / "HiveApp",
        SOURCES / "HiveMacApp",
        SOURCES / "HiveMobileApp",
        SOURCES / "HiveUI",
        SOURCES / "HiveWatchApp",
        SOURCES / "HiveWidgets",
    ]
    files: list[Path] = []
    for root in roots:
        if root.exists():
            files.extend(root.rglob("*.swift"))
    return sorted(files)


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def check_pdf_docs(errors: list[str]) -> None:
    try:
        from pypdf import PdfReader
    except Exception as exc:  # pragma: no cover - depends on local environment
        errors.append(f"pypdf is unavailable, so Apple PDF extraction cannot be verified: {exc}")
        return

    for doc in APPLE_DOCS:
        if not doc.exists():
            errors.append(f"Missing supplied Apple design document: {doc}")
            continue
        reader = PdfReader(str(doc))
        if not reader.pages:
            errors.append(f"Apple design document has no readable pages: {doc}")
            continue
        sample = "\n".join((page.extract_text() or "") for page in reader.pages[:3])
        if len(sample.strip()) < 200:
            errors.append(f"Apple design document text extraction is too sparse: {doc}")
            continue
        full_text = sample
        if doc.name in APPLE_DOC_REQUIRED_TERMS:
            full_text = "\n".join((page.extract_text() or "") for page in reader.pages)
        lower_text = full_text.lower()
        for term in APPLE_DOC_REQUIRED_TERMS.get(doc.name, []):
            if term.lower() not in lower_text:
                errors.append(f"Apple design document `{doc.name}` is missing expected principle area: {term}")


def check_required_implementation_anchors(errors: list[str]) -> None:
    corpus = "\n".join(read_text(path) for path in source_files())
    required = {
        "macOS native split navigation": "NavigationSplitView",
        "macOS Settings scene": "Settings {",
        "system App Shortcuts exposure": "AppShortcutsProvider",
        "WidgetKit timeline provider": "TimelineProvider",
        "watchOS Digital Crown navigation": "digitalCrownRotation",
        "Sign in with Apple credential validation": "getCredentialState",
        "Google sign-in web authentication": "ASWebAuthenticationSession",
        "Keychain-backed cloud key storage": "SecItemAdd",
        "Foundation Models availability": "SystemLanguageModel.default",
        "Foundation Models guided generation": "@Generable",
        "speech input permission path": "SFSpeechRecognizer",
    }
    for label, needle in required.items():
        if needle not in corpus:
            errors.append(f"Missing implementation anchor for {label}: {needle}")


def check_forbidden_ui_patterns(errors: list[str]) -> None:
    forbidden_patterns = {
        "custom translucent material in app UI": re.compile(r"\.(regularMaterial|ultraThinMaterial|thinMaterial)\b"),
        "raw SwiftUI glass modifier outside current solid Hive language": re.compile(r"\.glassEffect\b"),
        "hard-coded white/gray color in app UI": re.compile(r"\bColor\.(white|gray|black)\b"),
        "hard-coded non-Hive accent color in app UI": re.compile(r"\bColor\.(red|orange|yellow|green|blue|purple|teal|pink|indigo|mint|cyan|brown)\b"),
        "raw border modifier in app UI": re.compile(r"\.border\s*\("),
        "raw SF Symbol call outside HiveSymbol wrapper": re.compile(r"\b(Image\s*\(\s*systemName:|systemImage:)"),
        "tiny fixed system font in app UI": re.compile(r"\.font\s*\(\s*\.system\s*\(\s*size:\s*(?:[0-9]|1[0-2])(?:\.0)?\b"),
    }
    for path in ui_source_files():
        text = read_text(path)
        for label, pattern in forbidden_patterns.items():
            match = pattern.search(text)
            if match:
                line = text[: match.start()].count("\n") + 1
                errors.append(f"{label}: {rel(path)}:{line}")


def check_user_visible_debug_language(errors: list[str]) -> None:
    forbidden_strings = [
        "STORED LOCALLY",
        "capture_kind:",
        "capture_kind",
        "Related ConceptsHive",
        "KnownInformation",
        "page capture 1780131485",
        "No pages selected",
        "Apple Intelligence",
        "Coming soon",
    ]
    for path in ui_source_files():
        text = read_text(path)
        for needle in forbidden_strings:
            index = text.find(needle)
            if index != -1:
                line = text[:index].count("\n") + 1
                errors.append(f"user-visible debug or misleading language `{needle}`: {rel(path)}:{line}")


def main() -> int:
    errors: list[str] = []
    check_pdf_docs(errors)
    check_required_implementation_anchors(errors)
    check_forbidden_ui_patterns(errors)
    check_user_visible_debug_language(errors)

    if errors:
        print("Hive Apple HIG static audit failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Hive Apple HIG static audit passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
