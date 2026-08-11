# Hive Browser — Pre-Launch Checklist

> **Current local validation (2026-08-09):** 1,635 tests / 157 suites pass; HiveCore and Hive product builds pass; the current ad-hoc bundle, preflight, and 60-second smoke readiness checks pass. Developer ID signing, notarization, and clean-machine installation remain external release checks.
>
> The checked boxes in the launch-artifact section below preserve the historical v1.0.0 launch snapshot. They do not certify the current ad-hoc artifact for distribution; use `docs/RELEASE_PIPELINE.md` for the current release boundary.

## Historical v1.0.0 Launch Artifact Snapshot

## 48 Hours Before Launch

### 1. App Build & Distribution (historical snapshot)
- [x] Release .dmg built (ad-hoc signed, `dist/Hive.dmg`)
- [x] SHA-256 recorded: `3a5ccff0654c25132dda918f3d866293c5021efbacd1b906887191adbe644b36`
- [x] Sparkle appcast updated with correct file size + SHA
- [x] GitHub Release v1.0.0 with .dmg uploaded
- [ ] Developer ID signing (requires Apple Developer Program)
- [ ] Notarization stapling (post-Developer ID)
- [ ] Test clean-machine install: download .dmg, mount, drag to /Applications, launch

### 2. Landing Page & Web Assets (historical snapshot)
- [x] `web/index.html` — landing page with download CTA + waitlist link
- [x] `web/waitlist.html` — email capture waitlist (localStorage)
- [x] `web/privacy.html` — privacy policy
- [x] `web/terms.html` — terms of service
- [x] `web/appcast.xml` — Sparkle update feed
- [x] `web/favicon.png` — browser favicon
- [ ] Deploy to GitHub Pages (`arpituppal2.github.io/Hive`)
- [ ] Verify all links resolve (privacy, terms, download, waitlist)
- [ ] Add Open Graph / Twitter Card meta tags for social sharing

### 3. App Store Connect (future distribution gate)
- [ ] App name + subtitle (30 chars each) optimized for keywords
- [ ] Mac screenshots (2880x1800) showing dark + light mode
- [ ] Privacy Nutrition Label completed
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`) for all SDKs
- [ ] Review notes with demo credentials if gated
- [ ] Featuring Nomination submitted (2+ weeks lead time)

### 4. Press & Community Outreach (launch preparation)
- [x] `docs/LAUNCH_COPY.md` — Show HN, Product Hunt, Reddit copy ready
- [ ] Product Hunt launch scheduled (Tuesday-Thursday, 12:01 AM PST)
- [ ] Show HN post drafted + ready to submit (Monday-Thursday morning)
- [ ] Reddit r/macapps, r/browsers, r/mac posts prepared
- [ ] Press kit: icon (1024x1024), screenshots (dark/light), fact sheet
- [ ] Promo codes generated for reviewers
- [ ] Target 3-5 micro-influencers / Mac newsletter authors for early access

### 5. Community Seeding
- [ ] Discord server created with #announcements, #feedback, #bugs channels
- [ ] GitHub Discussions enabled on repo
- [ ] Twitter/X thread drafted announcing launch
- [ ] Mastodon post prepared for indie dev community
- [ ] Hacker News profile ready with launch context in bio

### 6. Last-Minute QA (historical snapshot plus open manual checks)
- [x] Full test suite: 1,621 tests / 155 suites PASS
- [x] Bundle + smoke test PASS
- [ ] Clean-machine test: fresh macOS user account, install .dmg, launch
- [ ] Test all keyboard shortcuts (Cmd+T, Cmd+W, Cmd+L, Cmd+K, Cmd+Q)
- [ ] Test window close behavior (app should stay running with no windows)
- [ ] Test multi-monitor: move between Retina + non-Retina displays
- [ ] Test dark mode / light mode toggle
- [ ] Test private browsing mode (ephemeral profile)
- [ ] Test hibernation: leave tabs idle, verify memory drops
- [ ] Test AI council with no API keys (should degrade gracefully)
- [ ] Test crash recovery: SIGKILL + relaunch, verify session restore

### 7. Final Checks (current release gates)
- [ ] Privacy policy URL loads in incognito (no broken links)
- [ ] No hardcoded local paths in release binary
- [ ] No secrets, API keys, or tokens in binary or repo
- [ ] THIRD_PARTY_NOTICES.md current
- [ ] CHANGELOG.md updated with v1.0.0 release notes
- [ ] Git tags: `git tag v1.0.0 && git push --tags`

## Post-Launch (Day 1-7)
- [ ] Monitor GitHub Issues + Discussions daily
- [ ] Respond to every Show HN + Product Hunt comment
- [ ] Ship 1-2 quick-fix patches for launch-day bugs
- [ ] Write "What we learned launching Hive" blog post
- [ ] Submit to Mac app directories (MacUpdate, AlternativeTo, Product Hunt collections)

---

**Last updated:** 2026-08-09
**Latest local tests:** 1,635 / 157 suites PASS
**Latest local build:** HiveCore + Hive product builds, ad-hoc bundle, preflight, and 60-second smoke readiness PASS; sync outbox latest-ledger regression coverage included
**Distribution:** Developer ID signing, notarization, and clean-machine install remain pending
