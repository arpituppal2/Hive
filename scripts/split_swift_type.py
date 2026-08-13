#!/usr/bin/env python3
"""Generalized Swift-type splitter: carve a large type's body into extension
files grouped by `// MARK:` section.

Same machinery as scripts/split_browser_state.py (string-aware lexer with
brace/paren/bracket depth tracking), parametrized for any type in any file:
stored properties, nested types, `init`/`deinit` stay in the main declaration
(extensions cannot declare stored properties); methods and computed properties
move into `@MainActor extension <Type> { ... }` files. `private`/`private(set)`
are promoted to internal so the cross-file extensions compile.

Usage:
  python3 scripts/split_swift_type.py --file <path> --type <decl-regex> \
      --map "SectionSubstring=FileSuffix,Other=OtherSuffix" [--dry-run]

Example:
  python3 scripts/split_swift_type.py \
      --file Sources/Hive/GeminiSidePanel.swift \
      --type '^struct GeminiSidePanel\b' \
      --map 'Header=Header,Context Scope=Context,Message List=Messages,Empty State=Messages,Model Footer=Footer,Council Verdict=Council,Deep Research=Research,Input Area=Input,Heads Up=Input,Context Before Send=Input,Tab Reference Pills=Input,Autocomplete=Autocomplete,Voice turn=Voice'

Unmatched sections go to a "<Type>+Core.swift" file. The main file keeps the
type declaration, stored properties, `body`, nested types, and all other
top-level types/helpers in the same file.
"""

import re
import sys
import shutil
import collections

CONT = set("([,=:.+-*&|</\\")
ATTR_ONLY = re.compile(r"^\s*@[A-Za-z_]\w*(\s*\([^)]*\))?\s*$")
MARK_RE = re.compile(r"^\s*// MARK:\s*(.*)$")


def lex(text):
    """Return per-line [has_code, brace_delta, paren_delta, bracket_delta,
    saw_open_brace, last_code_char, mode_at_end]."""
    n = len(text)
    mode = 0
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
        return "stay"
    if re.match(r"^func\b|^subscript\b", stripped):
        return "move"
    if re.match(r"^(let|var)\b", stripped):
        return "stay" if is_stored_property(text) else "move"
    return "unknown"


def is_stored_property(text):
    br = text.find("{")
    pre = text[:br] if br != -1 else text
    if pre.find("=") != -1:
        return True
    if br == -1:
        return True
    after = text[br + 1:]
    inner = re.sub(r"^\s*(?://[^\n]*\n\s*)*", "", after)
    if re.match(r"^(willSet|didSet)\b", inner):
        return True
    return False


def promote_access(t):
    t = re.sub(r"private\(set\)", "", t)
    t = re.sub(
        r"\bprivate\s+(?=(?:nonisolated\s+)?(?:static\s+)?(?:func|var|let|struct|enum|class|final|typealias|subscript|init|deinit|override)\b)",
        "", t)
    return t


def collect_imports(lines, type_idx):
    out = []
    for l in lines[:type_idx]:
        s = l.strip()
        if s.startswith("import "):
            out.append(s)
    return "\n".join(out) if out else "import Foundation\n"


def parse(text, type_re, section_map):
    info = lex(text)
    lines = text.split("\n")
    typ = None
    for j, l in enumerate(lines):
        if re.search(type_re, l):
            typ = j
            break
    if typ is None:
        raise SystemExit("type declaration not found: %s" % type_re)

    depth = 0
    body_start = None
    for j in range(typ, len(lines)):
        depth += info[j][1]
        if depth == 1:
            body_start = j
            break
    if body_start is None:
        raise SystemExit("type body start not found")

    members = []
    cur = None
    comments = []
    section = None
    type_end = None
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
                type_end = j
                break
            cur = {"start": j, "lines": [j], "comments": list(comments), "section": section, "saw_brace": False}
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
    if type_end is None:
        raise SystemExit("type end not found")
    if depth + info[type_end][1] != 0:
        raise SystemExit("braces unbalanced at end: depth=%d" % depth)
    if paren != 0 or bracket != 0:
        raise SystemExit("unbalanced paren/bracket at type end")

    for m in members:
        m["kind"] = classify_member(m, lines)
        m["file"] = map_section(m["section"], section_map)
        src = [lines[i] for i in m["comments"]] + [lines[i] for i in m["lines"]]
        m["text"] = promote_access("\n".join(src))

    return lines, typ, body_start, type_end, members, comments, info


def map_section(section, section_map):
    if not section:
        return "Core"
    low = section.lower()
    for sub, suffix in section_map:
        if sub in low:
            return suffix
    return "Core"


def main():
    args = sys.argv[1:]
    dry = "--dry-run" in args
    def val(flag):
        for i, a in enumerate(args):
            if a == flag and i + 1 < len(args):
                return args[i + 1]
        return None
    path = val("--file")
    type_re = val("--type")
    map_spec = val("--map") or ""
    if not path or not type_re:
        raise SystemExit("usage: --file <path> --type <regex> [--map ...] [--dry-run]")
    section_map = []
    for pair in map_spec.split(","):
        if "=" in pair:
            k, v = pair.split("=", 1)
            section_map.append((k.strip().lower(), v.strip()))

    raw = open(path).read()
    text = raw.rstrip("\n")
    lines, typ, body_start, type_end, members, trailing, info = parse(text, type_re, section_map)
    imports = collect_imports(lines, typ)
    type_name = re.search(r"\b(\w+)\b\s*(?::|<|\{)", lines[typ]) or None
    base = type_name.group(1) if type_name else "Split"
    out_dir = path.rsplit("/", 1)[0]

    stats = collections.Counter(m["kind"] for m in members)
    file_stats = collections.Counter(m["file"] for m in members if m["kind"] == "move")

    if stats["move"] == 0 and not dry:
        raise SystemExit("no movable members found — already split; aborting so the tool is safe to re-run")

    print("type %s @ line %d: members=%d stay=%d move=%d unknown=%d"
          % (base, typ + 1, len(members), stats["stay"], stats["move"], stats["unknown"]))

    bad = 0
    for m in members:
        decl = m.get("decl") or ""
        if m["kind"] == "unknown" or decl.startswith(("{", "->", ")", "}")):
            bad += 1
            print("L%-5d %-6s %-48s -> %s  <-- CHECK :: %s"
                  % (m["start"] + 1, m["kind"], (m["section"] or "(none)")[:48], m["file"], decl[:60]))
    print("suspicious: %d" % bad)
    for name, count in sorted(file_stats.items()):
        print("  %s+%s.swift (%d members)" % (base, name, count))

    if dry:
        print("(dry run — nothing written)")
        return

    shutil.copy(path, "/tmp/%s.pre-split.bak" % base)
    stay = [m["text"] for m in members if m["kind"] == "stay"]
    main_parts = ["\n".join(lines[0:body_start + 1])]
    if stay:
        main_parts.append("\n".join(stay))
    if trailing:
        main_parts.append("\n".join(lines[i] for i in trailing))
    main_parts.append("\n".join(lines[type_end:]))
    with open(path, "w") as f:
        f.write("\n".join(main_parts) + "\n")

    files = collections.OrderedDict()
    for m in members:
        if m["kind"] == "move":
            files.setdefault(m["file"], []).append(m)
    for name, ms in files.items():
        secs = []
        for m in ms:
            if m["section"] and m["section"] not in secs:
                secs.append(m["section"])
        body = "\n\n".join(m["text"] for m in ms)
        out = (
            "//\n"
            "//  %s+%s.swift\n"
            "//  Hive\n"
            "//\n"
            "//  Carved out of %s by scripts/split_swift_type.py.\n"
            "//  Pure extension split, no behavior change. Access was widened from\n"
            "//  `private`/`private(set)` to internal so the cross-file extensions\n"
            "//  compile; this app target has no external API surface.\n"
            "//\n"
            "//  Sections: %s\n"
            "//\n"
            "\n"
            "%s\n"
            "\n"
            "// MARK: - %s + %s\n"
            "\n"
            "@MainActor\n"
            "extension %s {\n"
            "\n"
            "%s\n"
            "}\n"
        ) % (base, name, path.rsplit("/", 1)[-1], " | ".join(secs), imports, base, name, base, body)
        with open("%s/%s+%s.swift" % (out_dir, base, name), "w") as f:
            f.write(out)

    # Post-carve guard: a top-level `private`/`fileprivate` type left in the
    # main file but referenced by a carved member will NOT compile across
    # files (cross-file extensions cannot see it). This bit three times
    # (GeminiProviderOption, SheetListItem, SettingsSidebarRow) — warn loudly
    # instead of waiting for the Swift build to fail.
    main_text = "\n".join(main_parts)
    carved_text = "\n".join(m["text"] for ms in files.values() for m in ms)
    for m in re.finditer(
        r"^(?:(?:@[A-Za-z_]\w*(?:\s*\([^)]*\))?\s*)*)(?:private|fileprivate)\s+"
        r"(?:final\s+)?(?:struct|enum|class|actor)\s+([A-Za-z_]\w*)",
        main_text,
        re.MULTILINE,
    ):
        tname = m.group(1)
        if re.search(r"\b" + re.escape(tname) + r"\b", carved_text):
            print(
                "WARNING: top-level private type '%s' is referenced by carved "
                "members — promote it to internal in %s or the build will fail."
                % (tname, path)
            )

    print("SPLIT DONE — %s is now %d lines (type %s); backup in /tmp/%s.pre-split.bak"
          % (path, len("\n".join(main_parts).split("\n")), base, base))


if __name__ == "__main__":
    main()
