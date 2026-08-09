#!/usr/bin/env python3
"""Split BrowserState.swift into per-domain @MainActor extension files.

Pure mechanical refactor. Rules enforced by the Swift language model:
  - Extensions cannot declare stored properties -> stored properties, nested
    types, `init` and `deinit` stay in the main BrowserState.swift file.
  - Methods, computed properties and subscripts move into
    `@MainActor extension BrowserState { ... }` files, grouped by their
    `// MARK:` section.
  - `private` / `private(set)` are promoted to internal so cross-file
    extensions compile (this is an app target with no external API surface).

The lexer is string-aware: multi-line string literals (the injected JS
probes contain `{ }` braces) and single-line strings are skipped while
counting braces/parens/brackets, so members are carved on real boundaries.
Multi-line signatures (params ending without a trailing comma) are handled
by tracking paren/bracket depth and whether the member has opened a brace
block yet.

Usage:
  python3 scripts/split_browser_state.py --dry-run   # show the plan only
  python3 scripts/split_browser_state.py             # perform the split
"""

import re
import sys
import shutil
import collections

SRC = "Sources/Hive/BrowserState.swift"
OUT_DIR = "Sources/Hive"
BACKUP = "/tmp/BrowserState.swift.pre-split.bak"

CONT = set("([,=:.+-*&|</\\")
ATTR_ONLY = re.compile(r"^\s*@[A-Za-z_]\w*(\s*\([^)]*\))?\s*$")
MARK_RE = re.compile(r"^\s*// MARK:\s*(.*)$")

# Ordered: more specific compound titles first.
SECTION_MAP = [
    ("tab hooks (downloads, history backfill)", "Navigation"),
    ("durable research handoff lifecycle", "Research"),
    ("deep research (multi-step research engine)", "Research"),
    ("knowledge memory actions", "Knowledge"),
    ("tab peek (arc-style live preview)", "Peek"),
    ("link hover peek (arc-style link preview)", "Peek"),
    ("media mini-player (arc-style auto player)", "Peek"),
    ("native context menu (chrome / edge / safari parity)", "ContextMenu"),
    ("tab hibernation", "Hibernation"),
    ("session persistence", "Persistence"),
    ("web chrome shell (the ui in web content)", "Chrome"),
    ("web chrome (hive://)", "Chrome"),
    ("compact mode (zen-style chrome auto-hide)", "Chrome"),
    ("floating url bar", "Chrome"),
    ("browser chrome state", "Chrome"),
    ("tab search (chrome / edge / safari parity)", "Chrome"),
    ("page zoom (chrome / edge / safari parity)", "Chrome"),
    ("fullscreen (safari / chrome parity)", "Chrome"),
    ("print (chrome / edge / safari parity)", "Chrome"),
    ("search engine", "Chrome"),
    ("layout", "Chrome"),
    ("top domains", "Chrome"),
    ("omnibox suggestions", "Chrome"),
    ("address bar", "Chrome"),
    ("command palette", "Chrome"),
    ("find in page", "Chrome"),
    ("split view", "Chrome"),
    ("ai infrastructure (swarm agent pipeline)", "AI"),
    ("model council (parallel multi-model ai dispatch)", "AI"),
    ("unified agent pipeline", "AI"),
    ("agent pipeline helpers", "AI"),
    ("summarize (comet / dia / edge)", "AI"),
    ("knowledge panel (honeycomb)", "Knowledge"),
    ("brief capture", "Brief"),
    ("morning brief", "Brief"),
    ("action approval (act)", "Approval"),
    ("session grants (swarm-005)", "Approval"),
    ("studio panel", "Studio"),
    ("sheets panel (sheet-002)", "Studio"),
    ("voice mode (comet)", "Voice"),
    ("profiles", "Workspaces"),
    ("workspaces", "Workspaces"),
    ("tab groups", "Workspaces"),
    ("group rename (window-level alert)", "Workspaces"),
    ("bookmarks", "Bookmarks"),
    ("history (safari / chrome / edge / arc)", "Library"),
    ("downloads (safari / chrome / edge)", "Library"),
    ("reader mode (safari / edge / arc / brave / zen)", "Reader"),
    ("reader mode", "Reader"),
    ("private browsing (safari / zen)", "Privacy"),
    ("privacy report (safari)", "Privacy"),
    ("passwords", "Privacy"),
    ("safe browsing", "Privacy"),
    ("translate", "Privacy"),
    ("gemini side panel", "Gemini"),
    ("extensions", "Extensions"),
    ("themes", "Setup"),
    ("derived", "Derived"),
    ("tab management", "Tabs"),
    ("navigation", "Navigation"),
    ("sync helpers (internal mutation for cloudkit extension)", "Core"),
    ("browserstate", "Core"),
]

IMPORTS = (
    "import SwiftUI\n"
    "import Observation\n"
    "import CefSwiftUI\n"
    "import CefKit\n"
    "import HiveCore\n"
    "import AppKit\n"
)


def lex(text):
    """Return per-line [has_code, brace_delta, paren_delta, bracket_delta,
    saw_open_brace, last_code_char, mode_at_end]."""
    n = len(text)
    mode = 0  # 0 code, 1 single-line string, 2 multi-line string
    out = []
    has_code = False
    delta = 0
    pdelta = 0
    bdelta = 0
    saw_open = False
    lastc = ""
    i = 0

    def flush():
        nonlocal has_code, delta, pdelta, bdelta, saw_open, lastc
        out.append([has_code, delta, pdelta, bdelta, saw_open, lastc, mode])
        has_code = False
        delta = 0
        pdelta = 0
        bdelta = 0
        saw_open = False
        lastc = ""

    while i < n:
        c = text[i]
        if c == "\n":
            flush()
            i += 1
            continue
        if mode == 0:
            if c == '"':
                if text.startswith('"""', i):
                    mode = 2
                    i += 3
                else:
                    mode = 1
                    i += 1
                has_code = True
                lastc = '"'
            elif c == "/" and text.startswith("//", i):
                while i < n and text[i] != "\n":
                    i += 1
            elif c == "/" and text.startswith("/*", i):
                j = text.find("*/", i + 2)
                i = (j + 2) if j != -1 else n
            elif c == "{":
                delta += 1
                saw_open = True
                has_code = True
                lastc = c
                i += 1
            elif c == "}":
                delta -= 1
                has_code = True
                lastc = c
                i += 1
            elif c == "(":
                pdelta += 1
                has_code = True
                lastc = c
                i += 1
            elif c == ")":
                pdelta -= 1
                has_code = True
                lastc = c
                i += 1
            elif c == "[":
                bdelta += 1
                has_code = True
                lastc = c
                i += 1
            elif c == "]":
                bdelta -= 1
                has_code = True
                lastc = c
                i += 1
            elif c in " \t\r":
                i += 1
            else:
                has_code = True
                lastc = c
                i += 1
        elif mode == 1:
            if c == "\\":
                i += 2
            elif c == '"':
                mode = 0
                i += 1
            else:
                i += 1
        else:  # mode == 2
            if c == "\\" and text.startswith('\\"""', i):
                i += 4
            elif text.startswith('"""', i):
                mode = 0
                i += 3
            else:
                i += 1
    flush()
    return out


def classify_member(member, lines):
    text = "\n".join(lines[i] for i in member["lines"])
    decl = None
    for ln in member["lines"]:
        s = lines[ln].strip()
        if not s or s.startswith("//") or ATTR_ONLY.match(s):
            continue
        decl = s
        break
    member["decl"] = decl
    if decl is None:
        return "unknown"
    body = decl
    while True:
        m = re.match(r"^@[A-Za-z_]\w*(\s*\([^)]*\))?\s*", body)
        if not m:
            break
        body = body[m.end():]
    if re.match(r"^(nonisolated\s+)?init\b", body):
        return "stay"
    if body.startswith("deinit"):
        return "stay"
    stripped = re.sub(
        r"^(nonisolated\s+|static\s+|override\s+|private\(set\)\s*|private\s+|fileprivate\s+)+",
        "", body)
    if re.match(r"^(final\s+)?class\b|^struct\b|^enum\b|^typealias\b", stripped):
        return "stay"  # nested types stay (extensions can nest them, but keep simple)
    if re.match(r"^func\b|^subscript\b", stripped):
        return "move"
    if re.match(r"^(let|var)\b", stripped):
        return "stay" if is_stored_property(text) else "move"
    return "unknown"


def is_stored_property(text):
    br = text.find("{")
    pre = text[:br] if br != -1 else text
    if pre.find("=") != -1:
        return True  # stored with initializer / closure / observers
    if br == -1:
        return True  # bare `var x: T` assigned later (init)
    after = text[br + 1:]
    inner = re.sub(r"^\s*(?://[^\n]*\n\s*)*", "", after)
    if re.match(r"^(willSet|didSet)\b", inner):
        return True  # stored property with observers
    return False  # computed property


def map_section(section):
    if not section:
        return "Core"
    low = section.lower()
    for sub, fname in SECTION_MAP:
        if sub in low:
            return fname
    return "Core"


def promote_access(t):
    t = re.sub(r"private\(set\)", "", t)
    t = re.sub(
        r"\bprivate\s+(?=(?:nonisolated\s+)?(?:static\s+)?(?:func|var|let|struct|enum|class|final|typealias|subscript|init|deinit|override)\b)",
        "", t)
    return t


def parse():
    raw = open(SRC).read()
    text = raw.rstrip("\n")
    info = lex(text)
    lines = text.split("\n")

    cls = None
    for j, l in enumerate(lines):
        if re.search(r"\bfinal class BrowserState\b", l):
            cls = j
            break
    if cls is None:
        raise SystemExit("class BrowserState not found")

    depth = 0
    body_start = None
    for j in range(cls, len(lines)):
        depth += info[j][1]
        if depth == 1:
            body_start = j
            break
    if body_start is None:
        raise SystemExit("class body start not found")

    members = []
    cur = None
    comments = []
    section = None
    class_end = None
    depth = 1
    paren = 0
    bracket = 0
    for j in range(body_start + 1, len(lines)):
        hc, delta, pdelta, bdelta, saw_open, lastc, mode_end = info[j]
        s = lines[j].strip()
        if cur is None and depth == 1:
            if not hc:
                m = MARK_RE.match(lines[j])
                if m and m.group(1).strip():
                    section = m.group(1).strip()
                comments.append(j)
                continue
            if s == "}":
                class_end = j
                break
            cur = {
                "start": j, "lines": [j], "comments": list(comments),
                "section": section, "saw_brace": False,
            }
            comments = []
        else:
            cur["lines"].append(j)
        if saw_open:
            cur["saw_brace"] = True
        depth += delta
        paren += pdelta
        bracket += bdelta
        if cur is not None and depth == 1:
            ends = False
            if not hc or mode_end == 2 or lastc in CONT or ATTR_ONLY.match(lines[j]):
                ends = False
            elif cur["saw_brace"]:
                ends = True
            else:
                ends = (paren == 0 and bracket == 0)
            if ends:
                cur["end"] = j
                members.append(cur)
                cur = None
    if class_end is None:
        raise SystemExit("class end not found")
    # The class-close line (delta -1) is consumed by the break above, so the
    # running depth still includes it — apply its delta before asserting.
    if depth + info[class_end][1] != 0:
        raise SystemExit("class braces unbalanced at end: depth=%d" % depth)
    if paren != 0 or bracket != 0:
        raise SystemExit("unbalanced paren/bracket at class end")

    for m in members:
        m["kind"] = classify_member(m, lines)
        m["file"] = map_section(m["section"])
        src = [lines[i] for i in m["comments"]] + [lines[i] for i in m["lines"]]
        m["text"] = promote_access("\n".join(src))

    return lines, body_start, class_end, members, comments, raw


def emit(lines, body_start, class_end, members, trailing_comments, raw):
    stay = [m["text"] for m in members if m["kind"] == "stay"]
    files = collections.OrderedDict()
    for m in members:
        if m["kind"] == "move":
            files.setdefault(m["file"], []).append(m)

    main_parts = ["\n".join(lines[0:body_start + 1])]
    if stay:
        main_parts.append("\n".join(stay))
    if trailing_comments:
        main_parts.append("\n".join(lines[i] for i in trailing_comments))
    main_parts.append("\n".join(lines[class_end:]))
    new_main = "\n".join(main_parts) + "\n"

    shutil.copy(SRC, BACKUP)
    with open(SRC, "w") as f:
        f.write(new_main)

    for name, ms in files.items():
        secs = []
        for m in ms:
            if m["section"] and m["section"] not in secs:
                secs.append(m["section"])
        body = "\n\n".join(m["text"] for m in ms)
        out = (
            "//\n"
            "//  BrowserState+%s.swift\n"
            "//  Hive\n"
            "//\n"
            "//  Carved out of BrowserState.swift by scripts/split_browser_state.py.\n"
            "//  Pure extension split, no behavior change. Access was widened from\n"
            "//  `private`/`private(set)` to internal so the cross-file extensions\n"
            "//  compile; this app target has no external API surface.\n"
            "//\n"
            "//  Sections: %s\n"
            "//\n"
            "\n"
            "%s\n"
            "\n"
            "// MARK: - BrowserState + %s\n"
            "\n"
            "@MainActor\n"
            "extension BrowserState {\n"
            "\n"
            "%s\n"
            "}\n"
        ) % (name, " | ".join(secs), IMPORTS, name, body)
        path = "%s/BrowserState+%s.swift" % (OUT_DIR, name)
        with open(path, "w") as f:
            f.write(out)

    return new_main


def main():
    dry = "--dry-run" in sys.argv
    lines, body_start, class_end, members, trailing, raw = parse()

    stats = collections.Counter(m["kind"] for m in members)
    file_stats = collections.Counter(m["file"] for m in members if m["kind"] == "move")

    if stats["move"] == 0 and not dry:
        raise SystemExit("no movable members found — BrowserState.swift is already split; aborting "
                         "so the tool is safe to re-run")

    print("members: %d  stay: %d  move: %d  unknown: %d"
          % (len(members), stats["stay"], stats["move"], stats["unknown"]))
    print("class body: lines %d..%d" % (body_start, class_end))

    bad = []
    for m in members:
        decl = m.get("decl") or ""
        suspicious = (decl.startswith("{") or decl.startswith("->") or decl.startswith(")")
                      or decl.startswith("}") or m["kind"] == "unknown")
        if suspicious:
            bad.append((m["start"] + 1, m["kind"], m["section"], m["file"], decl[:70]))
            print("L%-5d %-6s %-52s -> %s  <-- CHECK :: %s"
                  % (m["start"] + 1, m["kind"], (m["section"] or "(none)")[:52],
                     m["file"], decl[:70]))

    if bad:
        print("\nSUSPICIOUS MEMBERS (%d)" % len(bad))
    else:
        print("no suspicious members — classification clean")

    print("\nExtension files to write:")
    for name, count in sorted(file_stats.items()):
        print("  BrowserState+%s.swift  (%d members)" % (name, count))

    remaining = len("\n".join(
        ["\n".join(lines[0:body_start + 1])]
        + [m["text"] for m in members if m["kind"] == "stay"]
        + ["\n".join(lines[i] for i in trailing)]
        + ["\n".join(lines[class_end:])]
    ).split("\n"))
    print("  main BrowserState.swift shrinks to %d lines (from %d)" % (remaining, len(lines)))

    if not dry:
        emit(lines, body_start, class_end, members, trailing, raw)
        print("\nSPLIT DONE. Backup of original at %s" % BACKUP)
    else:
        print("\n(dry run — nothing written)")


if __name__ == "__main__":
    main()
