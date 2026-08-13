#!/usr/bin/env python3
"""Restructure WebChromeHandler.swift:

1. Move the ~55 bridge DTO structs (MARK "Bridge DTOs" through the line before
   MARK "WebChromeBridge") into WebChromeHandler+DTOs.swift.
2. Carve the CDP agent-tool registration block (MARK "Agent Tools" inside
   `register(with:)` through the method's closing brace) out of the 800-line
   `register` method into `static func registerAgentTools(with:bridge:)` in
   WebChromeHandler+AgentTools.swift, leaving a one-line call site.
3. Promote `authorize`/`httpURL` from private static to internal so the moved
   agent-tools method can call them cross-file.

Verifies every `bridge.register("` in the carved block is `hive.agent.*` so no
unrelated registration is moved.

Usage: python3 scripts/split_webchrome_handler.py
"""

import os
import re
import sys
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from split_swift_type import lex  # reuse the proven string-aware lexer

SRC = "Sources/Hive/WebChromeHandler.swift"
OUT_DIR = "Sources/Hive"
BACKUP = "/tmp/WebChromeHandler.swift.pre-split.bak"

DTO_IMPORTS = "import Foundation\nimport AppKit\nimport CefKit\nimport HiveCore\n"
AGENT_IMPORTS = "import Foundation\nimport AppKit\nimport CefKit\n"


def main():
    raw = open(SRC).read()
    text = raw.rstrip("\n")
    info = lex(text)
    lines = text.split("\n")

    # ---- locate key line indices ----
    def find(regex, start=0):
        for j in range(start, len(lines)):
            if re.search(regex, lines[j]):
                return j
        return None

    dto_mark = find(r"// MARK: - Bridge DTOs")
    bridge_mark = find(r"// MARK: - WebChromeBridge")
    if dto_mark is None or bridge_mark is None or bridge_mark < dto_mark:
        raise SystemExit("could not find DTO/bridge MARK boundaries")

    register_mark = find(r"static func register\(with state: BrowserState\)", bridge_mark)
    if register_mark is None:
        raise SystemExit("register(with:) not found")

    # ---- find the register method's closing brace via the lexer ----
    depth = 0
    reg_start = None
    reg_end = None
    for j in range(register_mark, len(lines)):
        if depth == 0 and "static func register(with state: BrowserState)" in lines[j]:
            reg_start = j
        depth += info[j][1]
        # The register method closes when local brace depth returns to 0
        # (it is a direct member of the enum, whose `{` predates reg_start).
        if depth == 0 and reg_start is not None and j > reg_start:
            reg_end = j
            break
    if reg_start is None:
        raise SystemExit("register method start not found")

    agent_mark = find(r"// MARK: Agent Tools", reg_start)
    if agent_mark is None or agent_mark > reg_end:
        raise SystemExit("Agent Tools MARK not found inside register(with:)")

    # ---- verify the carved block is exclusively hive.agent.* registrations ----
    for j in range(agent_mark, reg_end):
        m = re.search(r'bridge\.register\("([^"]+)"', lines[j])
        if m and not m.group(1).startswith("hive.agent."):
            raise SystemExit(
                "non-agent registration in carve block at line %d: %s" % (j + 1, m.group(1)))

    # ---- assemble the agent-tools method ----
    agent_block = lines[agent_mark:reg_end]  # MARK comment .. last register statement (excl. method close)
    agent_body = "\n".join(agent_block)
    agent_method = (
        "    /// Registers the CDP-driven agent tool bridge (`hive.agent.*`) — the\n"
        "    /// Astro-aligned browser-automation surface for AI-driven browsing.\n"
        "    /// Called from `register(with:)`. Every handler is token-gated via\n"
        "    /// `Self.authorize` and runs its CDP work through `state.cdpClient`.\n"
        "    static func registerAgentTools(with state: BrowserState, bridge: CefBridge) {\n"
        + agent_body + "\n"
        "    }\n"
    )

    call_site = "        registerAgentTools(with: state, bridge: bridge)\n"

    # ---- rebuild register(with:) ----
    new_register = lines[reg_start:agent_mark] + [call_site] + ["    }"]
    promote_map = {
        "private static func authorize(": "static func authorize(",
        "private static func httpURL(": "static func httpURL(",
    }
    new_main_lines = (
        lines[:dto_mark]
        + lines[bridge_mark:reg_start]
        + new_register
        + lines[reg_end + 1:]
    )
    new_main = []
    for l in new_main_lines:
        for k, v in promote_map.items():
            if k in l:
                l = l.replace(k, v)
                break
        new_main.append(l)

    shutil.copy(SRC, BACKUP)

    # ---- write main file ----
    with open(SRC, "w") as f:
        f.write("\n".join(new_main) + "\n")

    # ---- write DTOs file ----
    dto_block = lines[dto_mark:bridge_mark]
    dto_out = (
        "//\n"
        "//  WebChromeHandler+DTOs.swift\n"
        "//  Hive\n"
        "//\n"
        "//  Carved out of WebChromeHandler.swift by scripts/split_webchrome_handler.py.\n"
        "//  Pure file split — the JS<->Swift bridge request/response payload types.\n"
        "//\n"
        "\n"
        "%s\n"
        "\n"
        "%s\n"
    ) % (DTO_IMPORTS, "\n".join(dto_block))
    with open(OUT_DIR + "/WebChromeHandler+DTOs.swift", "w") as f:
        f.write(dto_out)

    # ---- write AgentTools file ----
    agent_out = (
        "//\n"
        "//  WebChromeHandler+AgentTools.swift\n"
        "//  Hive\n"
        "//\n"
        "//  Carved out of WebChromeHandler.swift by scripts/split_webchrome_handler.py.\n"
        "//  CDP-driven browser-automation bridge (`hive.agent.*`) extracted from the\n"
        "//  formerly 800-line `WebChromeBridge.register(with:)` method.\n"
        "//\n"
        "\n"
        "%s\n"
        "\n"
        "// MARK: - WebChromeBridge + AgentTools\n"
        "\n"
        "@MainActor\n"
        "extension WebChromeBridge {\n"
        "\n"
        "%s\n"
        "}\n"
    ) % (AGENT_IMPORTS, agent_method)
    with open(OUT_DIR + "/WebChromeHandler+AgentTools.swift", "w") as f:
        f.write(agent_out)

    print("DONE")
    print("  DTOs:  lines %d..%d -> WebChromeHandler+DTOs.swift" % (dto_mark + 1, bridge_mark))
    print("  Agent: lines %d..%d -> registerAgentTools() in WebChromeHandler+AgentTools.swift"
          % (agent_mark + 1, reg_end + 1))
    print("  Main:  %d lines (was %d); backup at %s" % (len(new_main), len(lines), BACKUP))


if __name__ == "__main__":
    main()
