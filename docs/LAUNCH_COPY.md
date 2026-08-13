# Hive Browser — Launch Copy

## Show HN Post

```
Show HN: Hive — A Chromium browser with on-device AI and a multi-model council

Hey HN,

I built Hive because I wanted a browser that thinks with me, not at me. Every existing option either shoves AI into a sidebar chatbot or sends every keystroke to a cloud model I don't control.

Hive is different:

- Chromium 148 via CefSwift — native SwiftUI chrome, not Electron
- On-device AI via Apple MLX — zero latency, your data stays on your machine
- Model Council — multiple models deliberate in parallel (MLX local, Tavily cloud, your own BYOK endpoint)
- Agentic browsing — CDP-powered, the browser navigates for you when you ask it to
- Deep Research — multi-step plan → search → read → synthesize with inline citations
- Rust adblock engine — Brave-level blocking with CNAME uncloaking and cosmetic filtering
- Zero telemetry. Zero tracking. Private browsing is ephemeral profiles, not just a theme.

Stack: Swift 6, CEF 148 (Chromium 148), MLX Swift, SQLite + FTS5 for Honeycomb memory, CloudKit for E2E encrypted sync.

1,912 tests / 184 suites pass. Builds as a native macOS ad-hoc DMG for local development; Developer ID signing and notarization are still required for a distributable release.

GitHub: https://github.com/arpituppal2/Hive
Download: https://github.com/arpituppal2/Hive/releases

What it doesn't do (yet): Windows/Linux builds, extension store integration, mobile. Those are on the roadmap.

I'd love feedback on the Model Council UX — does parallel model deliberation feel useful or noisy? And the agentic browsing flow — is CDP-based navigation intuitive or does it need more guardrails?

Thanks for checking it out.
```

## Product Hunt

### Tagline (60 chars max)
```
The browser that thinks with you — on-device AI, zero telemetry
```

### Short Description
```
Hive is a Chromium-based browser with on-device AI (Apple MLX), a multi-model council that deliberates in parallel, agentic browsing via CDP, and deep research with inline citations. Zero telemetry. Zero tracking. The launch snapshot passed 1,912 tests. Current builds are ad-hoc development artifacts until Developer ID signing and notarization are complete.
```

### Gallery Images
1. Hero — browser window with Model Council panel open
2. Deep Research — multi-step research with citations
3. Agentic Browsing — CDP-powered navigation
4. Workspaces — per-workspace cookie isolation
5. Settings — theme toggle, search engine picker, privacy controls

### Maker Comment
```
Hey Product Hunt! 👋

I'm Arpit, maker of Hive.

I built this because I was tired of browsers that either treat AI as an afterthought (sidebar chatbot bolted onto Chrome) or demand that every query hits a cloud model I don't control. Hive runs models on-device via Apple MLX and only reaches out to the cloud when you explicitly want it to.

The three things I'm most proud of:
1. Model Council — multiple AI models deliberate on your question simultaneously, then a chair model synthesizes the answer. You see the agreement/disagreement.
2. Agentic Browsing — the browser navigates for you. Ask "find me flights to Tokyo under $800" and it actually opens tabs, fills forms, extracts results.
3. Zero telemetry — we collect nothing. Not even anonymous usage stats. Your browsing is yours.

The launch snapshot was at 1,912 tests, with a local ad-hoc .dmg ready for development validation—not yet distribution-ready. I'd love feedback on the Model Council flow — does seeing multiple models disagree help or confuse?

Thanks for checking us out! 🚀
```

## Reddit r/browsers Post

```
Title: I got tired of AI chatbots bolted onto browsers, so I built a browser where AI is the engine, not an afterthought

Body:

After trying every "AI browser" out there (Arc, Dia, Sigma, Edge Copilot), I realized they all do the same thing: put a chatbot in a sidebar and call it AI.

I wanted something different — a browser where AI is integrated at the engine level:

- On-device inference via Apple MLX (your data never leaves your machine unless you want it to)
- A Model Council where multiple models deliberate in parallel and the chair model synthesizes
- Agentic browsing — the browser navigates for you when you ask it to
- Deep Research — multi-step research with real citations

It's built on Chromium 148 (via CefSwift), native SwiftUI chrome (not Electron), and has a Rust adblock engine at Brave-level blocking quality.

Open source (MIT): https://github.com/arpituppal2/Hive
Direct download: https://github.com/arpituppal2/Hive/releases

Zero telemetry. Zero tracking. The launch snapshot passed 1,912 tests. The current DMG is ad-hoc for local development; macOS only for now.

Would love feedback from this community — what makes you switch browsers? What would it take for you to try a new one?
```

## Key Messages (across all channels)

1. **On-device AI** — privacy-first, MLX on Apple Silicon, your data stays local
2. **Model Council** — parallel deliberation, not single-model echo chamber
3. **Agentic browsing** — CDP-powered, the browser acts, not just chats
4. **Zero telemetry** — we collect nothing, not even anonymous stats
5. **Open source** — MIT license, 1,912 tests in the launch snapshot, buildable from source (current DMGs are ad-hoc development artifacts)
6. **Honest about limits** — macOS only, no extensions store yet, no mobile

## Launch Day Checklist

- [ ] Post Show HN at 7am PT (Tuesday-Thursday best)
- [ ] Post Product Hunt at 12:01am PT
- [ ] Post r/browsers, r/macapps immediately after
- [ ] Monitor HN comments for first 2 hours — reply to every question
- [ ] Update GitHub Release notes with launch links
- [ ] Share on X/Twitter with demo GIF
