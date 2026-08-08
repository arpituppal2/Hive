// AUTO-GENERATED from Sources/Hive/WebChrome/* — do not edit by hand.
// Regenerate with: python3 Scripts/embed_webchrome.py
// The web chrome ships as Swift constants because the CEF bundler does not
// copy SwiftPM resources into the .app (same pattern as CefBridge.javascriptShim).
import Foundation

enum WebChromeAssets {
    static let indexHTML = #"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Hive</title>
<script>window.__HIVE_TOKEN = "__HIVE_TOKEN__";</script>
<script>
(function () {
  if (window.cefSwift && window.cefSwift.invoke) { return; }
  window.cefSwift = {
    _listeners: {},
    invoke: function (name, params) {
      return fetch('cefswift://bridge/' + encodeURIComponent(name), {
        method: 'POST',
        body: params === undefined ? '' : JSON.stringify(params)
      }).then(function (response) {
        return response.text().then(function (text) {
          if (!response.ok) {
            throw new Error('cefSwift.invoke(' + name + ') failed (' + response.status + '): ' + text);
          }
          var contentType = response.headers.get('Content-Type') || '';
          if (contentType.indexOf('application/json') !== -1 && text.length) {
            return JSON.parse(text);
          }
          return text;
        });
      });
    },
    on: function (name, fn) {
      (this._listeners[name] = this._listeners[name] || []).push(fn);
      var self = this;
      return function () {
        self._listeners[name] = (self._listeners[name] || []).filter(function (f) { return f !== fn; });
      };
    },
    off: function (name, fn) {
      if (!this._listeners[name]) { return; }
      if (fn === undefined) { this._listeners[name] = []; return; }
      this._listeners[name] = this._listeners[name].filter(function (f) { return f !== fn; });
    },
    _emit: function (name, data) {
      (this._listeners[name] || []).forEach(function (fn) {
        try { fn(data); } catch (e) { console.error(e); }
      });
    }
  };
})();
</script>
<link rel="stylesheet" href="/tokens.css">
<link rel="stylesheet" href="/styles.css">
</head>
<body>
<div class="ambient" aria-hidden="true"></div>

<!-- CHROME SHELL (hive://start?chrome=1) -->
<div id="chrome" class="chrome chrome--sidebar" hidden>
  <header class="toolbar">
    <div class="toolbar__row" id="toolbarRow">
      <button class="navbtn" id="btnBack" title="Back (⌘[)" tabindex="-1" aria-label="Back">
        <svg viewBox="0 0 24 24" fill="none"><path d="M15 5l-7 7 7 7" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>
      </button>
      <button class="navbtn" id="btnForward" title="Forward (⌘])" tabindex="-1" aria-label="Forward">
        <svg viewBox="0 0 24 24" fill="none"><path d="M9 5l7 7-7 7" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>
      </button>
      <button class="navbtn" id="btnReload" title="Reload (⌘R)" tabindex="-1" aria-label="Reload">
        <svg viewBox="0 0 24 24" fill="none" class="ic-reload"><path d="M20 12a8 8 0 1 1-2.34-5.66M20 4v4h-4" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>
      </button>

      <form class="addressbar" id="addressbarForm" autocomplete="off">
        <span class="addressbar__lock" id="addrLock" aria-hidden="true">
          <svg viewBox="0 0 24 24" fill="none"><rect x="5" y="10.5" width="14" height="9.5" rx="2" stroke="currentColor" stroke-width="1.8"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5" stroke="currentColor" stroke-width="1.8"/></svg>
        </span>
        <input id="addrInput" type="text" spellcheck="false" autocomplete="off" placeholder="Search or enter address" aria-label="Address bar">
        <div class="addressbar__progress" id="addrProgress"></div>
        <div class="addressbar__suggest" id="suggestBox" hidden></div>
      </form>

      <button class="navbtn" id="btnBookmark" title="Bookmark this page (⌘D)" tabindex="-1" aria-label="Bookmark">
        <svg viewBox="0 0 24 24" fill="none"><path d="M6 4h12v16l-6-4.5L6 20V4Z" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/></svg>
      </button>
      <button class="navbtn" id="btnDownloads" title="Downloads (⌘⇧J)" tabindex="-1" aria-label="Downloads">
        <svg viewBox="0 0 24 24" fill="none"><path d="M12 4v11m0 0-4.5-4.5M12 15l4.5-4.5M5 19h14" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
      </button>
      <button class="navbtn" id="btnSettings" title="Settings (⌘,)" tabindex="-1" aria-label="Settings">
        <svg viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="3.2" stroke="currentColor" stroke-width="1.8"/><path d="M12 2.8v2.4M12 18.8v2.4M2.8 12h2.4M18.8 12h2.4M5.5 5.5l1.7 1.7M16.8 16.8l1.7 1.7M18.5 5.5l-1.7 1.7M7.2 16.8l-1.7 1.7" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
      </button>
      <button class="navbtn" id="btnCouncil" title="Ask AI Council" tabindex="-1" aria-label="AI Council">
        <svg viewBox="0 0 24 24" fill="none"><path d="M12 4a4 4 0 0 1 4 4v2h2a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-6a2 2 0 0 1 2-2h2V8a4 4 0 0 1 4-4Zm0 2a2 2 0 0 0-2 2v2h4V8a2 2 0 0 0-2-2Zm-4 12h8v-2H8v2Zm0-4h3v-2H8v2Zm5 0h3v-2h-3v2Z" fill="currentColor"/></svg>
      </button>
    </div>
    <div class="bookmarksbar" id="bookmarksBar" hidden>
      <span class="bookmarksbar__label">Bookmarks</span>
      <div class="bookmarksbar__list" id="bookmarksList"></div>
    </div>
  </header>

  <div class="tabregion">
    <div class="tablist" id="tabList" role="tablist"></div>
  </div>

  <button class="newtabbtn" id="btnNewTab" aria-label="New Tab (⌘T)">
    <svg viewBox="0 0 24 24" fill="none"><path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>
    <span>New Tab</span>
  </button>

  <footer class="workspacerow" id="workspaceRow"></footer>

  <!-- Persistent agent dock (Comet-style): ask Hive anything, ⌘J -->
  <div class="agentdock" id="agentDock" hidden>
    <div class="agentdock__row">
      <svg class="agentdock__glyph" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path d="M12 4a4 4 0 0 1 4 4v2h2a2 2 0 0 1 2 2v6a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2v-6a2 2 0 0 1 2-2h2V8a4 4 0 0 1 4-4Zm0 2a2 2 0 0 0-2 2v2h4V8a2 2 0 0 0-2-2Z" fill="currentColor"/>
      </svg>
      <input id="agentAsk" class="agentdock__input" type="text" autocomplete="off" spellcheck="false" placeholder="Ask Hive anything…" aria-label="Ask Hive">
      <button class="agentdock__send" id="agentSend" title="Run (⏎)" aria-label="Send to Hive">
        <svg viewBox="0 0 24 24" fill="none"><path d="M4 12 20 4l-4 16-4-6-8 2Z" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/></svg>
      </button>
    </div>
  </div>

  <div id="aiPanel" class="ai-panel" hidden></div>

  <aside class="panel" id="panel" hidden>
    <div class="panel__head">
      <span class="panel__title" id="panelTitle">Panel</span>
      <button class="panel__close" id="btnPanelClose" title="Close panel (Esc)" aria-label="Close panel">
        <svg viewBox="0 0 24 24" fill="none"><path d="M6 6l12 12M18 6L6 18" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>
      </button>
    </div>
    <div class="panel__body" id="panelBody"></div>
  </aside>

  <div class="palette-backdrop" id="paletteBackdrop" hidden>
    <div class="palette" id="palette" role="dialog" aria-label="Command palette">
      <input id="paletteInput" class="palette__input" placeholder="Type a command or search tabs…" autocomplete="off" spellcheck="false">
      <div class="palette__list" id="paletteList"></div>
    </div>
  </div>

  <div class="ctxmenu" id="ctxMenu" hidden></div>
</div>

<!-- START PAGE (hive://start) -->
<main class="stage" id="stage" hidden>
  <div class="brand">
    <div class="brand__mark" aria-hidden="true">
      <svg viewBox="0 0 32 32" fill="none">
        <path d="M16 2.5 27.5 9v14L16 29.5 4.5 23V9L16 2.5Z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>
        <path d="M16 2.5v27M4.5 9l23 14M27.5 9l-23 14" stroke="currentColor" stroke-width="0.7" stroke-linejoin="round" opacity="0.45"/>
      </svg>
    </div>
    <h1 class="brand__name">Hive</h1>
  </div>

  <form class="stage__search" id="stageSearchForm" autocomplete="off">
    <input id="stageQuery" class="stage__query" type="text" placeholder="Search the web or enter an address…" spellcheck="false" autocomplete="off">
    <div class="stage__suggest" id="stageSuggest" hidden></div>
  </form>

  <section class="briefcard" id="briefCard" hidden>
    <div class="briefcard__glyph" aria-hidden="true">
      <svg viewBox="0 0 24 24" fill="none"><path d="M6 4h12v16l-6-4.5L6 20V4Z" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/></svg>
    </div>
    <div class="briefcard__text">
      <span class="briefcard__eyebrow">Every morning, made for you</span>
      <span class="briefcard__title">Open the Hive Morning Brief</span>
      <span class="briefcard__hint">Tabs, history, and top sources — assembled locally from your browsing.</span>
    </div>
    <button class="briefcard__cta" id="btnOpenBrief">Read brief</button>
  </section>

  <section class="topsites" id="topSitesSection" hidden>
    <h2 class="sectionlabel">Top Sites</h2>
    <div class="topsites__grid" id="topsitesGrid"></div>
  </section>

  <section class="recent" id="recentSection" hidden>
    <h2 class="sectionlabel">Recently Visited</h2>
    <div class="recent__list" id="recentList"></div>
  </section>

  <section class="spaces" id="spacesSection" hidden>
    <h2 class="sectionlabel">Spaces</h2>
    <div class="spaces__row" id="spacesRow"></div>
  </section>

  <div class="stage__hint" id="escHint">Press Esc to focus the page · ⌘K for commands · Brief in the palette</div>
</main>

<script src="/app.js"></script>
</body>
</html>
"""#
    static let stylesCSS = #"""
/* ============================================================
   Hive Web Chrome — Design System
   ------------------------------------------------------------
   Principles (researched from Arc / Zen / Polar / Comet / Brave):
   1. The chrome is scenery, not decoration. Recessive, quiet,
      frosted; the page is the star.
   2. ONE accent (Arc violet #8E5FEB) used sparingly — active
      state, focus, selection. Never rainbow.
   3. Surfaces: translucent washes + hairline borders instead of
      heavy borders. Frosted glass via backdrop-filter.
   4. Type: 13px tab titles, tight tracking, system stack.
   5. Radius: 8px tabs, 12-16px cards, 9999px pills.
   6. Shadows are rare and soft (0 8px 32px rgba(0,0,0,.08) cap).
   7. Motion: springy but short (160-260ms), no garish loops.
   ============================================================ */

:root {
  /* spacing: 4px base unit (Arc scale) */
  --s1: 4px; --s2: 8px; --s3: 12px; --s4: 16px;
  --s5: 20px; --s6: 24px; --s8: 32px; --s10: 40px;

  /* radii */
  --r-sm: 8px;
  --r-md: 12px;
  --r-lg: 16px;
  --r-pill: 9999px;

  /* type */
  --font: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Inter", system-ui, "Segoe UI", sans-serif;
  --mono: ui-monospace, "SF Mono", "Berkeley Mono", Menlo, monospace;

  /* motion */
  --spring: cubic-bezier(0.22, 1, 0.36, 1);
  --spring-soft: cubic-bezier(0.3, 0.8, 0.4, 1);
  --dur: 180ms;

  /* one accent — Hive honey (approved U1 token decision) */
  --accent: #F97316;
  --accent-hover: #FB923C;
  --accent-soft: rgba(249, 115, 22, 0.16);
  --accent-ink: #FFFFFF;

  /* ambient theme bloom (Arc: gradient warmth as atmosphere) */
  --bloom-a: rgba(249, 115, 22, 0.16);
  --bloom-b: rgba(240, 132, 90, 0.10);
}

/* ---------- dark (default) ---------- */
body[data-theme="dark"], body:not([data-theme]) {
  --bg: #17171B;
  --bg-elev: #1D1D22;
  --surface: rgba(255, 255, 255, 0.045);
  --surface-hover: rgba(255, 255, 255, 0.075);
  --surface-active: rgba(255, 255, 255, 0.11);
  --hairline: rgba(255, 255, 255, 0.07);
  --hairline-strong: rgba(255, 255, 255, 0.13);
  --text: #EDEDF1;
  --text-muted: rgba(237, 237, 241, 0.56);
  --text-faint: rgba(237, 237, 241, 0.34);
  --glass: rgba(26, 26, 31, 0.82);
  --glass-border: rgba(255, 255, 255, 0.09);
  --shadow-1: 0 2px 8px rgba(0, 0, 0, 0.22);
  --shadow-2: 0 8px 32px rgba(0, 0, 0, 0.30);
  --shadow-3: 0 16px 48px rgba(0, 0, 0, 0.40);
  --accent-ink: #F4F1FF;
  color-scheme: dark;
}

/* ---------- light ---------- */
body[data-theme="light"] {
  --bg: #FAFAF8;
  --bg-elev: #F3F2EC;
  --surface: rgba(20, 20, 25, 0.035);
  --surface-hover: rgba(20, 20, 25, 0.055);
  --surface-active: rgba(20, 20, 25, 0.09);
  --hairline: rgba(20, 20, 25, 0.08);
  --hairline-strong: rgba(20, 20, 25, 0.16);
  --text: #1C1C20;
  --text-muted: rgba(28, 28, 32, 0.56);
  --text-faint: rgba(28, 28, 32, 0.35);
  --glass: rgba(252, 251, 248, 0.85);
  --glass-border: rgba(20, 20, 25, 0.10);
  --shadow-1: 0 2px 8px rgba(20, 20, 25, 0.08);
  --shadow-2: 0 8px 32px rgba(20, 20, 25, 0.14);
  --shadow-3: 0 16px 48px rgba(20, 20, 25, 0.20);
  --accent: #7A4ED4;
  --accent-hover: #8E63E3;
  --accent-soft: rgba(122, 78, 212, 0.14);
  --accent-ink: #FFFFFF;
  --bloom-a: rgba(122, 78, 212, 0.10);
  --bloom-b: rgba(240, 132, 90, 0.06);
  color-scheme: light;
}

/* ============ BASE ============ */

* { box-sizing: border-box; margin: 0; padding: 0; }

html, body {
  height: 100%;
  overflow: hidden;
  font-family: var(--font);
  font-size: 14px;
  line-height: 1.45;
  background: var(--bg);
  color: var(--text);
  -webkit-font-smoothing: antialiased;
  text-rendering: optimizeLegibility;
}

body { display: flex; }

::selection { background: var(--accent-soft); }

button {
  font: inherit;
  color: inherit;
  background: none;
  border: none;
  cursor: pointer;
  -webkit-tap-highlight-color: transparent;
}
input { font: inherit; color: inherit; }
input::placeholder { color: var(--text-faint); }

svg { display: block; }

.no-motion * { animation: none !important; transition: none !important; }

/* thin, quiet scrollbars */
::-webkit-scrollbar { width: 8px; height: 8px; }
::-webkit-scrollbar-thumb {
  background: var(--surface-active);
  border-radius: 9999px;
  border: 2px solid transparent;
  background-clip: content-box;
}
::-webkit-scrollbar-track { background: transparent; }

/* ============ AMBIENT ============ */

.ambient {
  position: fixed;
  inset: 0;
  z-index: 0;
  pointer-events: none;
  overflow: hidden;
}
/* Arc-style: a single soft bloom, upper-left, as atmosphere */
.glow {
  position: absolute;
  border-radius: 50%;
  filter: blur(90px);
  opacity: 1;
}
.glow--indigo {
  width: 620px; height: 620px;
  left: -260px; top: -260px;
  background: radial-gradient(circle, var(--bloom-a) 0%, transparent 65%);
}
.glow--gold {
  width: 420px; height: 420px;
  right: -180px; top: -180px;
  background: radial-gradient(circle, var(--bloom-b) 0%, transparent 65%);
}

/* ============ CHROME SHELL LAYOUT ============ */

#chrome {
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  height: 100%;
  width: 100%;
  background: var(--bg);
  overflow: hidden;
}

/* ambient bloom across the whole sidebar surface, behind content */
#chrome::before {
  content: "";
  position: absolute;
  inset: 0;
  z-index: 0;
  pointer-events: none;
  background:
    radial-gradient(480px 340px at -60px -120px, var(--bloom-a) 0%, transparent 60%),
    radial-gradient(320px 260px at 110% -40px, var(--bloom-b) 0%, transparent 60%);
}
#chrome > * { position: relative; z-index: 1; }

/* ---------- toolbar ---------- */

.toolbar {
  display: flex;
  flex-direction: column;
  gap: var(--s2);
  padding: var(--s3) var(--s2) var(--s2);
  -webkit-user-select: none;
  user-select: none;
}

.toolbar__row {
  display: flex;
  align-items: center;
  gap: var(--s1);
  padding: 0 var(--s1);
}

.navbtn {
  display: grid;
  place-items: center;
  width: 30px;
  height: 30px;
  flex: none;
  border-radius: var(--r-sm);
  color: var(--text-muted);
  transition: background var(--dur) var(--spring-soft), color var(--dur) var(--spring-soft), transform 120ms var(--spring);
}
.navbtn:hover { background: var(--surface-hover); color: var(--text); }
.navbtn:active { background: var(--surface-active); transform: scale(0.94); }
.navbtn[data-disabled="true"] { opacity: 0.3; pointer-events: none; }
.navbtn svg { width: 16px; height: 16px; }

.ic-reload { transition: transform 360ms var(--spring); }
.navbtn.reloading .ic-reload { animation: spin 700ms linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

/* ---------- address bar ---------- */

.addressbar {
  position: relative;
  display: flex;
  align-items: center;
  flex: 1;
  min-width: 0;
  height: 30px;
  margin: 0 var(--s1);
  padding: 0 var(--s2);
  gap: var(--s2);
  background: var(--surface);
  border: 1px solid transparent;
  border-radius: var(--r-sm);
  color: var(--text-muted);
  transition: background var(--dur) var(--spring-soft), border-color var(--dur) var(--spring-soft), box-shadow var(--dur) var(--spring-soft);
}
.addressbar:focus-within {
  background: var(--bg-elev);
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-soft);
}
.addressbar:focus-within .addressbar__lock[data-secure="true"] { color: var(--accent); }

.addressbar__lock {
  display: grid;
  place-items: center;
  flex: none;
  color: var(--text-faint);
}
.addressbar__lock svg { width: 13px; height: 13px; }
.addressbar__lock[data-secure="true"] { color: var(--accent); }

#addrInput {
  flex: 1;
  min-width: 0;
  border: none;
  outline: none;
  background: transparent;
  font-size: 13px;
  letter-spacing: -0.005em;
  color: var(--text);
}
#addrInput::selection { background: var(--accent-soft); }

.addressbar__progress {
  position: absolute;
  left: var(--s2); right: var(--s2);
  bottom: -1px;
  height: 2px;
  border-radius: 9999px;
  background: var(--accent);
  transform: scaleX(0);
  transform-origin: left;
  opacity: 0;
}
.addressbar__progress.loading {
  opacity: 1;
  animation: progress 2.4s var(--spring) forwards;
}
@keyframes progress {
  0% { transform: scaleX(0); }
  70% { transform: scaleX(0.62); }
  100% { transform: scaleX(0.62); }
}

/* ---------- address suggestions ---------- */

.addressbar__suggest {
  position: absolute;
  top: calc(100% + 6px);
  left: 0;
  right: 0;
  z-index: 60;
  max-height: 320px;
  overflow-y: auto;
  padding: var(--s1);
  background: var(--glass);
  border: 1px solid var(--glass-border);
  border-radius: var(--r-md);
  box-shadow: var(--shadow-2);
  backdrop-filter: blur(24px) saturate(1.4);
  -webkit-backdrop-filter: blur(24px) saturate(1.4);
  animation: drop-in 160ms var(--spring);
}
@keyframes drop-in {
  from { opacity: 0; transform: translateY(-4px) scale(0.98); }
  to { opacity: 1; transform: translateY(0) scale(1); }
}

.sugg {
  display: flex;
  align-items: center;
  gap: var(--s2);
  padding: 7px var(--s2);
  border-radius: var(--r-sm);
  cursor: pointer;
  transition: background 120ms var(--spring-soft);
}
.sugg:hover, .sugg[data-active="true"] { background: var(--surface-hover); }

.sugg__icon { color: var(--text-muted); flex: none; display: grid; place-items: center; }
.sugg__icon svg { width: 14px; height: 14px; }

.sugg__tile {
  display: grid;
  place-items: center;
  width: 24px; height: 24px;
  flex: none;
  border-radius: var(--r-sm);
  font-size: 12px;
  font-weight: 600;
  color: #FFFFFF;
}
.sugg__tile img { width: 16px; height: 16px; border-radius: 3px; }

.sugg__text {
  flex: 1;
  min-width: 0;
  font-size: 13px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.sugg__url {
  font-size: 12px;
  color: var(--text-faint);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 45%;
}

/* ---------- bookmarks bar ---------- */

.bookmarksbar {
  display: flex;
  align-items: center;
  gap: var(--s2);
  padding: var(--s1) var(--s3);
  border-top: 1px solid var(--hairline);
}
.bookmarksbar__label {
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-faint);
}
.bookmarksbar__list {
  display: flex;
  align-items: center;
  gap: var(--s1);
  flex: 1;
  min-width: 0;
  overflow-x: auto;
}
.bmchip {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 3px 10px;
  border-radius: var(--r-pill);
  font-size: 12px;
  white-space: nowrap;
  color: var(--text-muted);
  background: var(--surface);
  transition: background var(--dur) var(--spring-soft), color var(--dur) var(--spring-soft);
}
.bmchip:hover { background: var(--surface-hover); color: var(--text); }
.bmchip img { width: 14px; height: 14px; border-radius: 3px; }

/* ---------- tab region ---------- */

.tabregion {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  overflow-x: hidden;
  padding: var(--s1) var(--s2) var(--s3);
}

.tablist {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.tabgroup {
  padding: var(--s3) var(--s2) var(--s1);
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-faint);
}

/* collapsible tab groups (color-led, Arc-style) */
.groupheader {
  display: flex;
  align-items: center;
  gap: var(--s1);
  margin: var(--s1) var(--s2) var(--s1) calc(var(--s2) * -1);
  padding: 4px var(--s2);
  height: 28px;
  border-radius: var(--r-sm);
  font-size: 12px;
  font-weight: 500;
  color: var(--text-muted);
  cursor: pointer;
  transition: background 130ms var(--spring-soft), color 130ms var(--spring-soft);
}
.groupheader:hover { background: var(--surface-hover); color: var(--text); }
.groupheader__color {
  width: 10px; height: 10px;
  flex: none;
  border-radius: 4px;
}
.groupheader__name {
  flex: 1;
  min-width: 0;
  border: none;
  outline: none;
  font-size: 12px;
  font-weight: 500;
  background: transparent;
  color: inherit;
  margin: 0;
  -webkit-user-select: text;
  user-select: text;
}
.groupheader__name:focus { color: var(--text); }
.groupheader__count {
  font-size: 10px;
  font-variant-numeric: tabular-nums;
  color: var(--text-faint);
}
.groupheader__toggle {
  display: grid;
  place-items: center;
  width: 22px; height: 22px;
  border-radius: 6px;
  color: var(--text-faint);
  transition: background 130ms var(--spring-soft), color 130ms var(--spring-soft);
}
.groupheader:hover .groupheader__toggle { color: var(--text); }
.groupheader__toggle:hover { background: var(--surface-hover); }

/* the tab itself — Arc recipe: transparent at rest, wash on hover,
   frosted-white pill when active. */
.tab {
  display: flex;
  align-items: center;
  gap: var(--s2);
  height: 34px;
  padding: 0 var(--s2);
  border-radius: var(--r-sm);
  cursor: pointer;
  -webkit-user-select: none;
  user-select: none;
  position: relative;
  transition: background 130ms var(--spring-soft), transform 200ms var(--spring);
  animation: tab-in 220ms var(--spring);
}
@keyframes tab-in {
  from { opacity: 0; transform: translateY(6px); }
  to { opacity: 1; transform: translateY(0); }
}
.tab:hover { background: var(--surface-hover); }
.tab:active { transform: scale(0.985); }

/* active: frosted, tinted wash, soft shadow — Arc "glass heavy" */
.tab[data-active="true"] {
  background: var(--glass);
  box-shadow: var(--shadow-1);
  color: var(--text);
}
.tab[data-active="true"]::before {
  content: "";
  position: absolute;
  left: -var(--s2);
  left: calc(-1 * var(--s2) + 6px);
  top: 50%;
  transform: translateY(-50%);
  width: 3px;
  height: 16px;
  border-radius: 9999px;
  background: var(--accent);
}
.tab[data-active="true"] .tab__title { color: var(--text); }

.tab__fav {
  display: grid;
  place-items: center;
  width: 20px; height: 20px;
  flex: none;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
  color: #fff;
  overflow: hidden;
}
.tab__fav img { width: 16px; height: 16px; border-radius: 3px; }

.tab__title {
  flex: 1;
  min-width: 0;
  font-size: 13px;
  font-weight: 500;
  letter-spacing: -0.005em;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  color: var(--text-muted);
  transition: color 130ms var(--spring-soft);
}

.tab__pin { flex: none; color: var(--accent); display: grid; place-items: center; }
.tab__pin svg { width: 11px; height: 11px; }

.tab__close {
  display: grid;
  place-items: center;
  width: 20px; height: 20px;
  flex: none;
  border-radius: 6px;
  color: var(--text-faint);
  opacity: 0;
  transition: opacity 120ms var(--spring-soft), background 120ms var(--spring-soft), color 120ms var(--spring-soft);
}
.tab:hover .tab__close, .tab[data-active="true"] .tab__close { opacity: 1; }
.tab__close:hover { background: var(--surface-active); color: var(--text); }
.tab__close svg { width: 12px; height: 12px; }

.tab.dragging { opacity: 0.45; }
.tab.drag-over-top { box-shadow: inset 0 2px 0 var(--accent); }
.tab.drag-over-bottom { box-shadow: inset 0 -2px 0 var(--accent); }

/* ---------- new tab button ---------- */

.newtabbtn {
  display: flex;
  align-items: center;
  gap: var(--s2);
  margin: 0 var(--s2) var(--s2);
  padding: 0 var(--s3);
  height: 34px;
  border-radius: var(--r-sm);
  color: var(--text-muted);
  font-size: 13px;
  font-weight: 500;
  transition: background var(--dur) var(--spring-soft), color var(--dur) var(--spring-soft);
  -webkit-user-select: none;
  user-select: none;
}
.newtabbtn svg { width: 15px; height: 15px; }
.newtabbtn:hover { background: var(--surface-hover); color: var(--text); }
.newtabbtn:active { background: var(--surface-active); }

/* ---------- workspace row ---------- */

.workspacerow {
  display: flex;
  align-items: center;
  gap: var(--s1);
  padding: var(--s2);
  border-top: 1px solid var(--hairline);
}

.workspace {
  display: flex;
  align-items: center;
  gap: var(--s2);
  padding: 6px var(--s3);
  border-radius: var(--r-pill);
  font-size: 12px;
  font-weight: 500;
  color: var(--text-muted);
  background: transparent;
  border: 1px solid transparent;
  transition: background var(--dur) var(--spring-soft), color var(--dur) var(--spring-soft), border-color var(--dur) var(--spring-soft);
  -webkit-user-select: none;
  user-select: none;
  max-width: 100%;
  min-width: 0;
}
.workspace:hover { background: var(--surface-hover); color: var(--text); }
.workspace[data-active="true"] {
  background: var(--accent-soft);
  border-color: var(--accent-soft);
  color: var(--accent);
}
.workspace__name {
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.workspace__count {
  font-size: 10px;
  font-weight: 600;
  color: var(--text-faint);
  background: var(--surface-active);
  border-radius: var(--r-pill);
  padding: 1px 6px;
}
.workspace__dot {
  width: 8px; height: 8px;
  flex: none;
  border-radius: 50%;
  background: var(--text-faint);
}
.workspace[data-active="true"] .workspace__dot { background: var(--accent); }

/* ---------- panel ---------- */

.panel {
  position: absolute;
  top: var(--s2);
  bottom: var(--s2);
  right: var(--s2);
  width: min(320px, calc(100% - 16px));
  z-index: 50;
  display: flex;
  flex-direction: column;
  background: var(--glass);
  border: 1px solid var(--glass-border);
  border-radius: var(--r-lg);
  box-shadow: var(--shadow-2);
  backdrop-filter: blur(28px) saturate(1.5);
  -webkit-backdrop-filter: blur(28px) saturate(1.5);
  overflow: hidden;
  animation: panel-in 220ms var(--spring);
}
@keyframes panel-in {
  from { opacity: 0; transform: translateX(12px) scale(0.98); }
  to { opacity: 1; transform: translateX(0) scale(1); }
}

.panel__head {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--s3) var(--s4);
  border-bottom: 1px solid var(--hairline);
}
.panel__title {
  font-size: 14px;
  font-weight: 600;
  letter-spacing: -0.01em;
}
.panel__close {
  display: grid;
  place-items: center;
  width: 26px; height: 26px;
  border-radius: var(--r-sm);
  color: var(--text-muted);
  transition: background var(--dur) var(--spring-soft), color var(--dur) var(--spring-soft);
}
.panel__close:hover { background: var(--surface-hover); color: var(--text); }
.panel__close svg { width: 14px; height: 14px; }

.panel__body {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: var(--s3) var(--s4) var(--s4);
  display: flex;
  flex-direction: column;
  gap: var(--s2);
}

.panel-section {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-faint);
  margin: var(--s2) 0 var(--s1);
}

/* settings rows */
.setting {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--s4);
  padding: var(--s2) 0;
}
.setting__label {
  font-size: 13px;
  font-weight: 500;
}
.setting__hint {
  font-size: 12px;
  color: var(--text-muted);
  margin-top: 2px;
}

/* segmented control — pill track, sliding thumb feel */
.seg {
  display: flex;
  gap: 2px;
  padding: 2px;
  background: var(--surface-active);
  border-radius: var(--r-pill);
  flex: none;
}
.seg__item {
  padding: 4px 14px;
  border-radius: var(--r-pill);
  font-size: 12px;
  font-weight: 500;
  color: var(--text-muted);
  transition: background 160ms var(--spring-soft), color 160ms var(--spring-soft);
  white-space: nowrap;
}
.seg__item:hover { color: var(--text); }
.seg__item[data-active="true"] {
  background: var(--glass);
  color: var(--text);
  box-shadow: var(--shadow-1);
}

/* toggle switch */
.toggle {
  position: relative;
  width: 38px;
  height: 22px;
  flex: none;
  border-radius: var(--r-pill);
  background: var(--surface-active);
  border: 1px solid var(--hairline);
  transition: background 180ms var(--spring-soft);
}
.toggle::after {
  content: "";
  position: absolute;
  top: 2px; left: 2px;
  width: 16px; height: 16px;
  border-radius: 50%;
  background: var(--text-muted);
  transition: transform 200ms var(--spring), background 180ms var(--spring-soft);
}
.toggle[data-on="true"] { background: var(--accent); border-color: var(--accent); }
.toggle[data-on="true"]::after {
  transform: translateX(16px);
  background: #fff;
}

/* ---------- command palette ---------- */

.palette-backdrop {
  position: fixed;
  inset: 0;
  z-index: 100;
  display: grid;
  place-items: start center;
  padding-top: 12vh;
  background: rgba(0, 0, 0, 0.30);
  backdrop-filter: blur(2px);
  -webkit-backdrop-filter: blur(2px);
  animation: fade-in 150ms var(--spring-soft);
}
@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

.palette {
  width: min(560px, calc(100vw - 48px));
  background: var(--glass);
  border: 1px solid var(--glass-border);
  border-radius: var(--r-lg);
  box-shadow: var(--shadow-3);
  backdrop-filter: blur(32px) saturate(1.5);
  -webkit-backdrop-filter: blur(32px) saturate(1.5);
  overflow: hidden;
  animation: palette-in 200ms var(--spring);
}
@keyframes palette-in {
  from { opacity: 0; transform: translateY(-8px) scale(0.97); }
  to { opacity: 1; transform: translateY(0) scale(1); }
}

.palette__input {
  width: 100%;
  padding: var(--s4);
  font-size: 15px;
  border: none;
  outline: none;
  background: transparent;
  color: var(--text);
  border-bottom: 1px solid var(--hairline);
}
.palette__input::placeholder { color: var(--text-faint); }

.palette__list {
  max-height: 320px;
  overflow-y: auto;
  padding: var(--s1);
}
.palette__item {
  display: flex;
  align-items: center;
  gap: var(--s3);
  padding: 8px var(--s3);
  border-radius: var(--r-sm);
  font-size: 13px;
  cursor: pointer;
  transition: background 120ms var(--spring-soft);
}
.palette__item:hover, .palette__item[data-active="true"] { background: var(--surface-hover); }
.palette__empty {
  padding: var(--s4);
  font-size: 13px;
  color: var(--text-muted);
  text-align: center;
}

/* ---------- context menu ---------- */

.ctxmenu {
  position: fixed;
  z-index: 120;
  min-width: 180px;
  padding: var(--s1);
  background: var(--glass);
  border: 1px solid var(--glass-border);
  border-radius: var(--r-md);
  box-shadow: var(--shadow-2);
  backdrop-filter: blur(28px) saturate(1.5);
  -webkit-backdrop-filter: blur(28px) saturate(1.5);
  animation: ctx-in 140ms var(--spring);
}
@keyframes ctx-in {
  from { opacity: 0; transform: scale(0.96) translateY(-4px); }
  to { opacity: 1; transform: scale(1) translateY(0); }
}
.ctxmenu__item {
  display: flex;
  align-items: center;
  gap: var(--s2);
  width: 100%;
  padding: 7px var(--s3);
  border-radius: var(--r-sm);
  font-size: 13px;
  text-align: left;
  color: var(--text);
  transition: background 100ms var(--spring-soft);
}
.ctxmenu__item:hover { background: var(--surface-hover); }
.ctxmenu__item--danger { color: #E5484D; }
.ctxmenu__item--danger:hover { background: rgba(229, 72, 77, 0.12); }
.ctxmenu__sep {
  height: 1px;
  margin: var(--s1) var(--s2);
  background: var(--hairline);
}

/* ============ CHROME --STRIP (horizontal mode) ============ */

.chrome--strip {
  /* toolbar row on top, tabs in a horizontal strip */
}
.chrome--strip .toolbar {
  flex-direction: column;
  padding: var(--s2) var(--s3);
}
.chrome--strip .toolbar__row {
  justify-content: center;
}
.chrome--strip .tabregion {
  overflow-x: auto;
  overflow-y: hidden;
  padding: 0 var(--s3) var(--s2);
}
.chrome--strip .tablist {
  flex-direction: row;
  gap: var(--s1);
}
.chrome--strip .tabgroup {
  display: none;
}
.chrome--strip .tab {
  width: 200px;
  height: 30px;
  flex: none;
  animation: none;
}
.chrome--strip .tab[data-active="true"]::before {
  left: var(--s2);
  right: var(--s2);
  top: auto;
  bottom: -2px;
  left: 50%;
  transform: translateX(-50%);
  width: 24px;
  height: 3px;
}
.chrome--strip .tab__title { font-size: 12px; }
.chrome--strip .newtabbtn {
  display: none;
}
.chrome--strip .workspacerow {
  border-top: none;
  justify-content: center;
  padding: 0 var(--s3) var(--s2);
}
.chrome--strip .workspace__name { display: none; }
.chrome--strip .workspace__count { display: none; }
.chrome--strip .workspace {
  padding: 5px 8px;
}
.chrome--strip .bookmarksbar { display: none; }

/* ============ START PAGE (per-tab content) ============ */

.stage {
  position: relative;
  z-index: 1;
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: var(--s8);
  padding: var(--s8) var(--s6) var(--s10);
  overflow-y: auto;
  min-width: 0;
}

.brand {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--s2);
  animation: rise-in 500ms var(--spring);
}
@keyframes rise-in {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}
.brand__mark { color: var(--accent); }
.brand__mark svg { width: 40px; height: 40px; }
.brand__name {
  font-size: 24px;
  font-weight: 700;
  letter-spacing: -0.02em;
}

.stage__search {
  position: relative;
  width: min(560px, 100%);
  animation: rise-in 500ms var(--spring) 60ms backwards;
}
.stage__query {
  width: 100%;
  height: 44px;
  padding: 0 var(--s5);
  font-size: 14px;
  background: var(--bg-elev);
  border: 1px solid var(--hairline);
  border-radius: var(--r-md);
  outline: none;
  color: var(--text);
  transition: border-color var(--dur) var(--spring-soft), box-shadow var(--dur) var(--spring-soft);
}
.stage__query:focus {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px var(--accent-soft);
}
.stage__suggest {
  position: absolute;
  top: calc(100% + 6px);
  left: 0; right: 0;
  z-index: 50;
  padding: var(--s1);
  background: var(--glass);
  border: 1px solid var(--glass-border);
  border-radius: var(--r-md);
  box-shadow: var(--shadow-2);
  backdrop-filter: blur(24px) saturate(1.4);
  -webkit-backdrop-filter: blur(24px) saturate(1.4);
  animation: drop-in 160ms var(--spring);
}

.sectionlabel {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--text-faint);
  margin-bottom: var(--s4);
}

/* Morning Brief entry card — honey accent, editorial quietness */
.briefcard {
  width: min(560px, 100%);
  display: flex;
  align-items: center;
  gap: var(--s4);
  padding: var(--s5) var(--s6);
  border-radius: var(--r-lg);
  background: linear-gradient(135deg, rgba(249, 115, 22, 0.13), rgba(249, 115, 22, 0.04) 55%, transparent);
  border: 1px solid rgba(249, 115, 22, 0.28);
  animation: rise-in 500ms var(--spring) 100ms backwards;
  transition: border-color var(--dur) var(--spring-soft), transform var(--dur) var(--spring-soft);
}
.briefcard:hover {
  border-color: rgba(249, 115, 22, 0.5);
  transform: translateY(-1px);
}
.briefcard__glyph {
  display: grid;
  place-items: center;
  width: 44px;
  height: 44px;
  border-radius: var(--r-md);
  background: rgba(249, 115, 22, 0.16);
  color: var(--accent);
  flex-shrink: 0;
}
.briefcard__glyph svg { width: 22px; height: 22px; }
.briefcard__text { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
.briefcard__eyebrow {
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--accent);
}
.briefcard__title {
  font-size: 15px;
  font-weight: 600;
  color: var(--text);
  letter-spacing: var(--tracking-tight);
}
.briefcard__hint {
  font-size: 12px;
  color: var(--text-muted);
  line-height: 1.45;
}
.briefcard__cta {
  margin-left: auto;
  flex-shrink: 0;
  padding: var(--s2) var(--s4);
  border-radius: var(--r-pill);
  background: var(--accent);
  color: var(--accent-ink);
  font-size: 13px;
  font-weight: 600;
  border: none;
  cursor: pointer;
  transition: background var(--dur) var(--spring-soft), transform var(--dur) var(--spring-soft);
}
.briefcard__cta:hover { background: var(--accent-hover); transform: translateY(-1px); }

.topsites,
.recent,
.spaces {
  width: min(560px, 100%);
  animation: rise-in 500ms var(--spring) 140ms backwards;
}

.topsites__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(88px, 1fr));
  gap: var(--s2);
}
.topsite {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: var(--s2);
  padding: var(--s3) var(--s2);
  border-radius: var(--r-md);
  cursor: pointer;
  transition: background var(--dur) var(--spring-soft);
}
.topsite:hover { background: var(--surface-hover); }
.topsite__icon {
  display: grid;
  place-items: center;
  width: 44px; height: 44px;
  border-radius: var(--r-md);
  color: #fff;
  font-size: 18px;
  font-weight: 600;
  overflow: hidden;
  box-shadow: var(--shadow-1);
}
.topsite__icon img { width: 22px; height: 22px; border-radius: 5px; }
.topsite__label {
  font-size: 12px;
  color: var(--text-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 100%;
}

.recent__list {
  display: flex;
  flex-direction: column;
  gap: 2px;
}
.le {
  display: flex;
  align-items: center;
  gap: var(--s3);
  padding: 7px var(--s2);
  border-radius: var(--r-sm);
  cursor: pointer;
  transition: background var(--dur) var(--spring-soft);
}
.le:hover { background: var(--surface-hover); }
.le__tile {
  display: grid;
  place-items: center;
  width: 26px; height: 26px;
  flex: none;
  border-radius: var(--r-sm);
  font-size: 12px;
  font-weight: 600;
  color: #fff;
  overflow: hidden;
}
.le__tile img { width: 18px; height: 18px; border-radius: 4px; }
.le__body { flex: 1; min-width: 0; }
.le__title {
  font-size: 13px;
  font-weight: 500;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.le__meta {
  font-size: 12px;
  color: var(--text-faint);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}
.le__state {
  font-size: 11px;
  color: var(--text-faint);
  font-variant-numeric: tabular-nums;
}
.le__bar {
  width: 60px;
  height: 4px;
  border-radius: 9999px;
  background: var(--surface-active);
  overflow: hidden;
  flex: none;
}
.le__bar i {
  display: block;
  height: 100%;
  border-radius: 9999px;
  background: var(--accent);
}
.le__time { flex: none; font-size: 11px; color: var(--text-faint); font-variant-numeric: tabular-nums; }

.spaces__row {
  display: flex;
  gap: var(--s2);
  flex-wrap: wrap;
}

.stage__hint {
  font-size: 12px;
  color: var(--text-faint);
  animation: rise-in 500ms var(--spring) 260ms backwards;
}

/* ============ STRIP MODE: START PAGE ============ */

.chrome--strip .stage {
  padding-top: var(--s6);
  gap: var(--s6);
}

/* ============ HORIZONTAL STRIP — toolbar icons centered row ============ */

.chrome--strip .toolbar__row {
  gap: var(--s2);
}

/* ============ RESPONSIVE ============ */

@media (max-width: 640px) {
  .chrome--strip .tab { width: 150px; }
  .panel { width: min(280px, calc(100% - 16px)); }
  .palette { width: calc(100vw - 32px); }
}

/* ============ AI PANEL (council verdict + deep research) ============ */

/* Persistent agent dock — Comet-style ask box, honey accent */
.agentdock {
  padding: var(--s2) var(--s3) 0;
  border-top: 1px solid var(--hairline);
  animation: drop-in 160ms var(--spring);
}
.agentdock__row {
  display: flex;
  align-items: center;
  gap: var(--s2);
  padding: 4px 4px 4px var(--s3);
  border-radius: var(--r-md);
  background: var(--surface-hover-subtle);
  border: 1px solid var(--hairline);
  transition: border-color var(--dur) var(--spring-soft), box-shadow var(--dur) var(--spring-soft);
}
.agentdock__row:focus-within {
  border-color: rgba(249, 115, 22, 0.45);
  box-shadow: 0 0 0 3px rgba(249, 115, 22, 0.12);
  background: var(--surface-hover);
}
.agentdock__glyph {
  width: 14px;
  height: 14px;
  color: var(--accent);
  flex-shrink: 0;
  opacity: 0.85;
}
.agentdock__input {
  flex: 1;
  min-width: 0;
  background: none;
  border: none;
  outline: none;
  color: var(--text);
  font-size: 12px;
  font-family: var(--font);
  letter-spacing: var(--tracking-tight);
  padding: 3px 0;
}
.agentdock__input::placeholder { color: var(--text-faint); }
.agentdock__send {
  flex-shrink: 0;
  display: grid;
  place-items: center;
  width: 24px;
  height: 24px;
  border: none;
  border-radius: var(--r-sm);
  background: var(--accent);
  color: var(--accent-ink);
  cursor: pointer;
  transition: background var(--dur) var(--spring-soft), transform var(--dur) var(--spring-soft);
}
.agentdock__send svg { width: 12px; height: 12px; }
.agentdock__send:hover { background: var(--accent-hover); transform: translateY(-1px); }

/* AI panel — 5-state honest rendering (loading / partial / degraded / success / empty) */
.ai-panel {
  padding: var(--s2) var(--s3);
  border-top: 1px solid var(--hairline);
  font-size: 11px;
  line-height: 1.45;
  color: var(--text-muted);
  transition: background var(--dur) var(--spring-soft);
}

/* Empty-state hero (dock open, nothing running) */
.ai-panel--hero {
  padding: var(--s4) var(--s3) var(--s3);
  display: flex;
  flex-direction: column;
  gap: 3px;
  animation: rise-in 260ms var(--spring) backwards;
}
.ai-panel__hero-title {
  font-size: 12.5px;
  font-weight: 650;
  color: var(--text);
  letter-spacing: var(--tracking-tight);
}
.ai-panel__hero-hint {
  font-size: 10.5px;
  color: var(--text-faint);
}
.ai-panel__hero-shortcuts {
  margin-top: 2px;
  font-size: 9.5px;
  color: var(--text-faint);
  font-family: var(--mono);
}
.ai-panel__kbd {
  display: inline-block;
  padding: 0 4px;
  border: 1px solid var(--hairline-strong);
  border-radius: 4px;
  background: var(--surface-hover-subtle);
  color: var(--text-secondary);
  font-size: 9px;
  line-height: 1.5;
}

.ai-panel__header {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 4px;
}

.ai-panel__icon {
  flex-shrink: 0;
  opacity: 0.7;
}

.ai-panel__label {
  font-weight: 600;
  font-size: 10.5px;
  color: var(--text);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.ai-panel__pct {
  margin-left: auto;
  font-variant-numeric: tabular-nums;
  font-size: 10px;
  color: var(--accent-3);
  font-weight: 600;
}

.ai-panel__models {
  margin-left: auto;
  font-size: 9px;
  color: var(--text-faint);
  text-transform: uppercase;
}

.ai-panel__tag {
  font-size: 8px;
  font-weight: 700;
  padding: 1px 5px;
  border-radius: var(--r-sm);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.ai-panel__tag--warn {
  background: rgba(245, 158, 11, 0.15);
  color: #f59e0b;
}

.ai-panel__bar {
  height: 3px;
  background: var(--surface-hover);
  border-radius: 2px;
  overflow: hidden;
  margin-top: 4px;
}

.ai-panel__bar i {
  display: block;
  height: 100%;
  background: var(--accent-3);
  border-radius: 2px;
  transition: width 0.4s ease;
}

.ai-panel__body {
  font-size: 11px;
  color: var(--text-muted);
  line-height: 1.5;
  max-height: 80px;
  overflow: hidden;
  display: -webkit-box;
  -webkit-line-clamp: 4;
  -webkit-box-orient: vertical;
  /* AI output renders in JetBrains Mono per the U1 token decision */
  font-family: var(--mono);
  font-size: 10.5px;
}

.ai-panel__reasoning {
  font-size: 10px;
  color: var(--text-faint);
  font-style: italic;
  margin-top: 2px;
  line-height: 1.4;
  max-height: 36px;
  overflow: hidden;
  font-family: var(--mono);
  font-size: 9.5px;
}

.ai-panel__body--sm {
  font-family: var(--mono);
  font-size: 10.5px;
}

.ai-panel__meta {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
  margin-top: 4px;
  font-size: 9px;
}

.ai-panel__agree {
  color: #22c55e;
}

.ai-panel__disagree {
  color: #f59e0b;
}

.ai-panel__dismiss {
  margin-left: auto;
  background: none;
  border: none;
  color: var(--text-faint);
  cursor: pointer;
  padding: 2px;
  border-radius: var(--r-sm);
  line-height: 1;
  opacity: 0.5;
  transition: opacity var(--dur) var(--spring-soft), color var(--dur) var(--spring-soft);
}

.ai-panel__dismiss:hover {
  opacity: 1;
  color: var(--text);
  background: var(--surface-hover);
}

.ai-panel__live-row {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 3px 0;
  font-size: 10px;
}

.ai-panel__live-text {
  flex: 1;
  color: var(--text-muted);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.ai-panel__live-pct {
  flex-shrink: 0;
  font-variant-numeric: tabular-nums;
  font-size: 9px;
  color: var(--text-faint);
}

.ai-panel__tag--ok {
  color: var(--accent-3, #34d399);
  background: color-mix(in srgb, var(--accent-3, #34d399) 12%, transparent);
}
"""#
    static let tokensCSS = #"""
/* ============================================================
   Hive Design Tokens — tokens.css
   ------------------------------------------------------------
   Extracted from Polar's AgentApp design system (verbatim values,
   licensed for use) and adapted to Hive's dark-first identity.

   Structure (mirrors Polar):
   · cn-*        neutral scale as RGB triplets (alpha-composable)
   · --color-*   semantic colors (text, surface, border, status)
   · --font-*    type ramp (system UI + JetBrains Mono for AI)
   · shadows     Polar's dark elevation recipe
   · motion      short springy transitions

   Hive signature: honey-orange accent (#F97316 family). Amber is
   reserved for AI affordances only; honey is the brand accent.
   ============================================================ */

:root {
  color-scheme: dark;

  /* ---------- Neutral scale (dark-first) ---------- */
  /* Polar cn-* values, dark variant — RGB triplets so every
     consumer can alpha-composite: rgb(var(--cn-300) / .5) */
  --cn-50:   245 244 243;   /* brightest text on dark */
  --cn-75:   214 213 212;
  --cn-100:  180 179 178;
  --cn-150:  150 149 148;
  --cn-200:  118 117 116;
  --cn-300:  88 87 86;
  --cn-400:  66 65 64;
  --cn-500:  54 53 52;
  --cn-600:  46 45 44;      /* card / field */
  --cn-700:  40 39 38;      /* raised surface */
  --cn-800:  35 34 33;      /* canvas */
  --cn-900:  30 29 28;      /* app background */
  --cn-1000: 25 24 23;      /* deepest wells */

  /* ---------- Semantic colors ---------- */
  --color-app: var(--cn-900);
  --color-canvas: var(--cn-800);
  --color-canvas-raised: var(--cn-700);
  --color-card: var(--cn-600);
  --color-field: var(--cn-600);
  --color-input: var(--cn-600);
  --color-input-border: var(--cn-300);

  --color-text-primary: var(--cn-50);
  --color-text-secondary: var(--cn-100);
  --color-text-tertiary: var(--cn-150);
  --color-text-muted: var(--cn-200);
  --color-text-disabled: var(--cn-300);
  --color-placeholder: var(--cn-200);

  --color-border-subtle: rgb(var(--cn-400));
  --color-border-strong: rgb(var(--cn-300));
  --color-border-active: rgb(249 115 22);           /* honey */
  --color-hairline: rgba(255, 255, 255, 0.07);
  --color-hairline-strong: rgba(255, 255, 255, 0.13);

  --color-surface-hover: rgba(255, 255, 255, 0.08);
  --color-surface-hover-subtle: rgba(255, 255, 255, 0.04);

  /* ---------- Accent (Hive signature: honey) ---------- */
  --color-accent: 249 115 22;       /* #F97316 */
  --color-accent-hover: 251 146 60; /* #FB923C */
  --color-accent-soft: rgb(249 115 22 / 0.16);
  --color-accent-ink: 255 255 255;

  /* AI-only semantics — amber stays in the AI lane */
  --color-ai: 245 158 11;           /* #F59E0B */

  /* ---------- Status ---------- */
  --color-error: 248 113 113;
  --color-error-bg: rgba(239, 68, 68, 0.15);
  --color-error-border: rgba(248, 113, 113, 0.3);
  --color-success: 52 211 153;
  --color-success-bg: rgba(16, 185, 129, 0.15);
  --color-info: 34 211 238;
  --color-info-bg: rgba(8, 145, 178, 0.12);
  --color-warning: 251 191 36;
  --color-warning-bg: rgba(245, 158, 11, 0.14);

  /* ---------- Type ---------- */
  --font-ui: -apple-system, BlinkMacSystemFont, "SF Pro Text",
             "Inter", system-ui, "Segoe UI", sans-serif;
  --font-mono: "JetBrains Mono", ui-monospace, "SF Mono",
               "Berkeley Mono", Menlo, monospace;
  --font-display: "SF Pro Display", var(--font-ui);

  /* Sizes: 11px tab titles → 34px display */
  --text-2xs: 11px;
  --text-xs: 12px;
  --text-sm: 13px;
  --text-md: 14px;
  --text-lg: 16px;
  --text-xl: 20px;
  --text-2xl: 26px;
  --text-display: 34px;

  --tracking-tight: -0.01em;
  --tracking-display: -0.02em;

  /* ---------- Spacing (4px base) ---------- */
  --s1: 4px; --s2: 8px; --s3: 12px; --s4: 16px;
  --s5: 20px; --s6: 24px; --s8: 32px; --s10: 40px; --s12: 48px;

  /* ---------- Radii ---------- */
  --r-tab: 8px;
  --r-sm: 6px;
  --r-md: 10px;
  --r-lg: 14px;
  --r-card: 16px;
  --r-pill: 9999px;

  /* ---------- Elevation (Polar dark recipe) ---------- */
  --shadow-card: inset 0 1px 0 rgba(255, 255, 255, 0.04),
                 0 1px 2px rgba(0, 0, 0, 0.3);
  --shadow-raised: inset 0 1px 0 rgba(255, 255, 255, 0.05),
                   0 4px 12px rgba(0, 0, 0, 0.3);
  --shadow-elevated: inset 0 1px 0 rgba(255, 255, 255, 0.05),
                     0 8px 24px rgba(0, 0, 0, 0.4);
  --shadow-overlay: inset 0 1px 0 rgba(255, 255, 255, 0.06),
                    0 16px 48px rgba(0, 0, 0, 0.55);
  --shadow-accent: 0 0 0 1px rgb(var(--color-accent) / 0.35),
                   0 4px 20px rgb(var(--color-accent) / 0.25);

  /* ---------- Motion ---------- */
  --spring: cubic-bezier(0.22, 1, 0.36, 1);
  --spring-soft: cubic-bezier(0.3, 0.8, 0.4, 1);
  --dur: 180ms;
  --dur-slow: 260ms;

  /* ---------- Chrome geometry ---------- */
  --chrome-sidebar-w: 264px;
  --chrome-strip-h: 52px;
  --tab-h: 36px;

  /* ---------- Ambient bloom (Arc-style atmosphere) ---------- */
  --bloom-a: rgb(var(--color-accent) / 0.14);
  --bloom-b: rgb(240 132 90 / 0.08);
}

/* ---------- Scrollbars: thin, owned, quiet ---------- */
* {
  scrollbar-width: thin;
  scrollbar-color: rgb(var(--cn-400)) transparent;
}
*::-webkit-scrollbar { width: 8px; height: 8px; }
*::-webkit-scrollbar-track { background: transparent; }
*::-webkit-scrollbar-thumb {
  background: rgb(var(--cn-400));
  border-radius: 9999px;
  border: 2px solid transparent;
  background-clip: content-box;
}
*::-webkit-scrollbar-thumb:hover { background-color: rgb(var(--cn-300)); }

/* ---------- Focus rings (keyboard parity) ---------- */
:focus-visible {
  outline: 2px solid rgb(var(--color-accent) / 0.7);
  outline-offset: 2px;
  border-radius: 4px;
}
"""#
    static let appJS = #"""
/* ==========================================================================
   Hive Web Chrome — full browser UI logic
   Pure vanilla JS. Talks to the native host only through
   window.cefSwift.invoke(). Two modes:
     ?chrome=1  → the chrome shell (tabs, toolbar, panels)
     (none)     → the start page (content of a fresh tab)
   ========================================================================== */

(function () {
  'use strict';

  var IS_CHROME = location.search.indexOf('chrome=1') !== -1;
  var hasBridge = !!(window.cefSwift && window.cefSwift.invoke);

  function api(name, params) {
    var p = params || {};
    p.token = window.__HIVE_TOKEN || '';
    if (!hasBridge) return Promise.resolve(null);
    try { return Promise.resolve(window.cefSwift.invoke(name, p)); }
    catch (e) { return Promise.resolve(null); }
  }

  /* ---------------- theme + prefs (localStorage, per profile) ---------------- */

  var prefs = { theme: 'system', density: 'comfortable', bookmarksBar: true, animations: true };
  try {
    var saved = JSON.parse(localStorage.getItem('hive.prefs') || '{}');
    for (var k in saved) if (k in prefs) prefs[k] = saved[k];
  } catch (e) {}

  function savePrefs() { try { localStorage.setItem('hive.prefs', JSON.stringify(prefs)); } catch (e) {} }

  var mq = window.matchMedia ? window.matchMedia('(prefers-color-scheme: light)') : null;
  function applyTheme() {
    var light = prefs.theme === 'light' || (prefs.theme === 'system' && mq && mq.matches);
    document.body.dataset.theme = light ? 'light' : 'dark';
    if (prefs.animations) document.body.classList.remove('no-motion');
    else document.body.classList.add('no-motion');
  }
  applyTheme();
  if (mq) mq.addEventListener('change', applyTheme);

  /* ---------------- density + focus mode ---------------- */

  var densityStyle = document.createElement('style');
  densityStyle.textContent =
    'body[data-density="compact"] .tab { height: 28px; }' +
    'body[data-density="compact"] .newtabbtn,' +
    'body[data-density="compact"] .navbtn,' +
    'body[data-density="compact"] .addressbar { transform: scale(0.96); }' +
    'body[data-density="compact"] .le { padding-top: 5px; padding-bottom: 5px; }' +
    'body[data-compact="true"] #chrome { display: none !important; }' +
    'body[data-compact="true"] .stage { width: 100vw; max-width: 100vw; margin: 0 auto; }' +
    'body[data-compact="true"] .palette-backdrop, body[data-compact="true"] .ctxmenu { z-index: 9999; }' +
    '.le__remove { border: none; background: transparent; color: var(--text-faint);' +
    ' font-size: 15px; line-height: 1; width: 22px; height: 22px; border-radius: var(--r-sm);' +
    ' cursor: pointer; flex: none; transition: background var(--dur) var(--spring-soft), color var(--dur) var(--spring-soft); }' +
    '.le__remove:hover { background: var(--surface-active); color: var(--text); }' +
    '.le__clear { width: 100%; margin-top: var(--s2); padding: 8px var(--s3);' +
    ' border: 1px solid var(--hairline); border-radius: var(--r-sm); background: transparent;' +
    ' color: var(--text-muted); font-size: 12px; cursor: pointer; transition: background var(--dur) var(--spring-soft); }' +
    '.le__clear:hover { background: var(--surface-hover); color: var(--text); }';
  document.head.appendChild(densityStyle);

  function applyDensity() {
    if (prefs.density === 'compact') document.body.dataset.density = 'compact';
    else delete document.body.dataset.density;
    if (chromeEl) chromeEl.classList.toggle('density--compact', prefs.density === 'compact');
  }

  function setCompactMode(on) {
    if (on) document.body.dataset.compact = 'true';
    else delete document.body.dataset.compact;
    if (chromeEl) chromeEl.hidden = on || !IS_CHROME;
  }

  function toggleCompactMode() {
    var on = !document.body.dataset.compact;
    setCompactMode(on);
    api('hive.toggleCompact', { on: on }).then(function (res) {
      if (res !== null) refresh();
    });
  }

  /* ---------------- state ---------------- */

  var state = {
    tabs: [], activeTabID: null, spaces: [], accentHex: '#6366F1',
    topSites: [], recent: [], history: [], bookmarks: [], downloads: [],
    layout: 'vertical', isPrivateBrowsing: false, isSplitActive: false,
    isChromePanelOpen: null, chromeMode: 'sidebar', chromeDimension: 270,
    councilVerdict: null, isCouncilConvening: false, councilLiveResponses: [], deepResearchStep: null,
    agentTask: null
  };

  var lastTabsJSON = '';

  function apply(data) {
    if (!data) return;
    for (var k in data) if (k in state) state[k] = data[k];
    document.body.dataset.mode = state.layout;
    if (IS_CHROME) {
      chromeEl.classList.remove('chrome--sidebar', 'chrome--strip');
      chromeEl.classList.add('chrome--' + (state.chromeMode === 'sidebar' ? 'sidebar' : 'strip'));
    }
    applyTheme();
    applyDensity();
    var activeTab = state.tabs.find(function (t) { return t.id === state.activeTabID; });
    var tabLoading = !!(activeTab && activeTab.loading);
    $('btnReload').classList.toggle('reloading', tabLoading);
    var addrProgress = $('addrProgress');
    if (addrProgress) addrProgress.classList.toggle('loading', tabLoading);
    renderTabs();
    renderToolbar();
    renderWorkspaces();
    renderAIPanel();
    renderPanel();
    renderBookmarksBar();
    renderStartPage();
  }

  function refresh() { api('hive.getStartData').then(apply); }

  /* ---------------- DOM helpers ---------------- */

  var $ = function (id) { return document.getElementById(id); };
  function el(tag, cls, html) {
    var n = document.createElement(tag);
    if (cls) n.className = cls;
    if (html !== undefined) n.innerHTML = html;
    return n;
  }
  function svg(paths, size) {
    return '<svg viewBox="0 0 24 24" fill="none" style="width:' + (size || 15) +
      'px;height:' + (size || 15) + 'px"><path d="' + paths + '" stroke="currentColor" ' +
      'stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>';
  }
  var ICONS = {
    close: 'M6 6l12 12M18 6L6 18',
    search: 'M10.5 3a7.5 7.5 0 1 0 4.8 13.3L20 21l1.5-1.5-4.7-4.7A7.5 7.5 0 0 0 10.5 3Zm0 2a5.5 5.5 0 1 1 0 11 5.5 5.5 0 0 1 0-11Z',
    globe: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18Zm-9 9h18M12 3c2.5 2.6 3.8 5.7 3.8 9S14.5 18.4 12 21m0-18C9.5 5.6 8.2 8.7 8.2 12s1.3 6.4 3.8 9',
    clock: 'M12 5a7 7 0 1 0 0 14 7 7 0 0 0 0-14Zm0 3v4.5l3 1.8',
    bookmark: 'M6 4h12v16l-6-4.5L6 20V4Z',
    download: 'M12 4v11m0 0-4.5-4.5M12 15l4.5-4.5M5 19h14',
    history: 'M12 4a8 8 0 1 0 0 16 8 8 0 0 0 0-16Zm0 4v4.5l3 1.8',
    settings: 'M12 8.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7Zm7.2 3.5c0-.5 0-1-.1-1.4l2-1.5-2-3.5-2.4 1a7.8 7.8 0 0 0-2.4-1.4L14 2.5h-4l-.3 2.6c-.9.3-1.7.8-2.4 1.4l-2.4-1-2 3.5 2 1.5c0 .5-.1 1-.1 1.4s.1 1 .1 1.4l-2 1.5 2 3.5 2.4-1c.7.6 1.5 1.1 2.4 1.4l.3 2.6h4l.3-2.6c.9-.3 1.7-.8 2.4-1.4l2.4 1 2-3.5-2-1.5c0-.4.1-.9.1-1.4Z',
    panel: 'M4 4h16v16H4V4Zm2 2v12h12V6H6Z',
    pin: 'M12 4l5 5-2 1.5V14l2 1.5V18H7v-2.5L9 14v-3.5L7 9l5-5Z',
    window: 'M4 4h16v16H4V4Zm2 2v12h12V6H6Zm3 3h6v6H9V9Z',
    private: 'M12 6.5c3.8 0 7.1 1.7 9.5 5.5-2.4 3.8-5.7 5.5-9.5 5.5S4.9 15.8 2.5 12C4.9 8.2 8.2 6.5 12 6.5Zm0 3a2 2 0 1 0 0 4 2 2 0 0 0 0-4Z',
    focus: 'M5 12h14',
    chevronDown: 'M6 9l6 6 6-6',
    chevronRight: 'M9 6l6 6-6 6'
  };

  /* ================= CHROME SHELL ================= */

  var chromeEl = $('chrome');

  function tabTile(tab, size) {
    var host = tab.host || '';
    var letter = (host || '?').charAt(0).toUpperCase();
    var hue = Math.abs(hash(host || tab.id)) % 360;
    var tile = el('span', 'sugg__tile');
    tile.style.background = 'hsl(' + hue + ',32%,48%)';
    tile.textContent = letter;
    if (tab.faviconURL) {
      var img = new Image();
      img.onload = function () { tile.textContent = ''; tile.appendChild(img); };
      img.alt = '';
      img.src = tab.faviconURL;
    }
    return tile;
  }
  function hash(s) {
    var h = 0;
    for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
    return Math.abs(h);
  }

  // Muted letter tile reused by history/bookmark/recent rows (mirrors tabTile styling)
  function tileHTML(host, title, hue) {
    return '<span class="le__tile" style="background:hsl(' + hue + ',32%,48%)">' +
      esc((title || host || '?').charAt(0).toUpperCase()) + '</span>';
  }

  /* ---------- tab list ---------- */

  var groupMap = {};

  function refreshGroupMap() {
    groupMap = {};
    (state.tabGroups || []).forEach(function (g) { groupMap[g.id] = g; });
  }

  function groupedTabs() {
    var ess = [], pinned = [], normal = [];
    state.tabs.forEach(function (t) {
      if (t.isEssential) ess.push(t);
      else if (t.isPinned) pinned.push(t);
      else normal.push(t);
    });
    return [['Essential', ess], ['Pinned', pinned], ['', normal]].filter(function (g) { return g[1].length; });
  }

  function renderTabs() {
    refreshGroupMap();
    var list = $('tabList');
    var groups = groupedTabs();
    var html = '';
    groups.forEach(function (g) {
      if (g[0] === 'Essential' || g[0] === 'Pinned') {
        if (g[0]) html += '<div class="tabgroup">' + g[0] + '</div>';
        g[1].forEach(function (t) { html += tabHTML(t); });
      } else {
        var runs = runsFrom(g[1]);
        runs.forEach(function (r) {
          if (r.group) {
            html += groupHeaderHTML(r.group);
            if (!r.group.isCollapsed) {
              r.tabs.forEach(function (t) { html += tabHTML(t, r.group.colorHex); });
            }
          } else {
            r.tabs.forEach(function (t) { html += tabHTML(t); });
          }
        });
      }
    });
    var json = JSON.stringify(state.tabs.map(function (t) { return t.id; }));
    var changed = json !== lastTabsJSON;
    lastTabsJSON = json;
    list.innerHTML = html;
    upgradeTabFavicons();
    if (changed) {
      var active = list.querySelector('.tab[data-active="true"]');
      if (active && state.layout === 'sidebar') active.scrollIntoView({ block: 'nearest' });
    }
  }

  function tabHTML(t, groupColor) {
    var host = t.host || '';
    var hue = Math.abs(hash(host || t.id)) % 360;
    var active = t.id === state.activeTabID;
    var groupStripe = groupColor ? ' style="border-left:3px solid ' + sanitizeHex(groupColor) + '"' : '';
    return '<div class="tab" data-id="' + t.id + '" data-active="' + active + '" ' + groupStripe +
      'draggable="true" role="tab" aria-selected="' + active + '" title="' + esc(t.title) + '">' +
      '<span class="tab__fav" data-host="' + esc(host || '') + '" style="background:hsl(' + hue + ',32%,48%)">' +
      esc((host || '?').charAt(0).toUpperCase()) + '</span>' +
      (t.isPinned ? '<span class="tab__pin">' + svg(ICONS.pin, 11) + '</span>' : '') +
      '<span class="tab__title">' + esc(t.title || 'New Tab') + '</span>' +
      '<span class="tab__close" data-close="' + t.id + '" title="Close tab (⌘W)">' +
      svg(ICONS.close, 12) + '</span></div>';
  }

  function sanitizeHex(h) {
    return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(h || '') ? h : '#8E5FEB';
  }

  function groupHeaderHTML(g) {
    return '<div class="groupheader" data-gid="' + g.id + '" draggable="false">' +
      '<span class="groupheader__color" style="background:' + sanitizeHex(g.colorHex) + '"></span>' +
      '<input class="groupheader__name" data-edit="true" type="text" value="' + esc(g.name) + '" />' +
      '<span class="groupheader__count" title="' + (g.tabIDs ? g.tabIDs.length : 0) + ' tabs">' +
      (g.tabIDs ? g.tabIDs.length : 0) + '</span>' +
      '<span class="groupheader__toggle" data-toggle="' + g.id + '" title="Expand / collapse group">' +
      svg(g.isCollapsed ? ICONS.chevronRight : ICONS.chevronDown, 12) + '</span></div>';
  }

  function runsFrom(normal) {
    var out = [];
    var pending = [];
    normal.forEach(function (t) {
      if (t.groupID && groupMap[t.groupID]) {
        if (pending.length) { out.push({ group: null, tabs: pending }); pending = []; }
        var existing = out[out.length - 1];
        if (existing && existing.group && existing.group.id === groupMap[t.groupID].id) {
          existing.tabs.push(t);
        } else {
          out.push({ group: groupMap[t.groupID], tabs: [t] });
        }
      } else {
        pending.push(t);
      }
    });
    if (pending.length) out.push({ group: null, tabs: pending });
    return out;
  }

  // Upgrade favicon monograms to real favicons when available (premium detail:
  // crisp site icon over the tinted letter tile; letter stays as fallback).
  function upgradeTabFavicons() {
    document.querySelectorAll('.tab__fav').forEach(function (tile) {
      if (tile.dataset.upgraded) return;
      var id = tile.closest('.tab') ? tile.closest('.tab').dataset.id : null;
      if (!id) return;
      var tab = state.tabs.find(function (t) { return t.id === id; });
      if (!tab || !tab.faviconURL) return;
      tile.dataset.upgraded = '1';
      var img = new Image();
      img.onload = function () {
        tile.textContent = '';
        tile.appendChild(img);
        tile.style.background = 'transparent';
      };
      img.alt = '';
      img.src = tab.faviconURL;
    });
  }

  function esc(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) {
      return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }

  // Event delegation: clicks, context menu, drag reorder
  $('tabList').addEventListener('click', function (e) {
    var close = e.target.closest('[data-close]');
    if (close) {
      e.stopPropagation();
      animateCloseTab(close.dataset.close);
      return;
    }
    var toggle = e.target.closest('[data-toggle]');
    if (toggle) {
      api('hive.toggleTabGroup', { id: toggle.dataset.toggle });
      return;
    }
    var tab = e.target.closest('.tab');
    if (tab) api('hive.selectTab', { id: tab.dataset.id });
  });

  // Rename a group when its inline input commits.
  $('tabList').addEventListener('blur', function (e, detail) {
    if (e.target && e.target.classList && e.target.classList.contains('groupheader__name')) {
      finishGroupRename(e.target);
    }
  }, true);
  $('tabList').addEventListener('keydown', function (e) {
    if (e.target && e.target.classList && e.target.classList.contains('groupheader__name')) {
      if (e.key === 'Enter') { e.preventDefault(); finishGroupRename(e.target); }
      else if (e.key === 'Escape') {
        e.preventDefault();
        // revert the input to the last known name
        var g = groupMap[e.target.closest('.groupheader').dataset.gid];
        if (g) e.target.value = g.name;
      }
    }
  });
  function finishGroupRename(input) {
    var name = input.value.trim();
    if (!name) return;
    var g = groupMap[input.closest('.groupheader').dataset.gid];
    if (!g || name === g.name) return;
    api('hive.renameTabGroup', { id: g.id, name: name, colorHex: g.colorHex });
  }

  $('tabList').addEventListener('contextmenu', function (e) {
    var tab = e.target.closest('.tab');
    if (!tab) return;
    e.preventDefault();
    showCtxMenu(e.clientX, e.clientY, tab.dataset.id);
  });

  function animateCloseTab(id) {
    var node = $('tabList').querySelector('.tab[data-id="' + id + '"]');
    if (node) {
      node.classList.add('anim-out');
      setTimeout(function () { api('hive.closeTab', { id: id }); }, 140);
    } else {
      api('hive.closeTab', { id: id });
    }
  }

  // Drag-and-drop reorder
  var dragID = null;
  $('tabList').addEventListener('dragstart', function (e) {
    var tab = e.target.closest('.tab');
    if (!tab) return;
    dragID = tab.dataset.id;
    tab.classList.add('dragging');
    e.dataTransfer.effectAllowed = 'move';
    try { e.dataTransfer.setData('text/plain', dragID); } catch (err) {}
  });
  $('tabList').addEventListener('dragend', function (e) {
    var tab = e.target.closest('.tab');
    if (tab) tab.classList.remove('dragging');
    dragID = null;
  });
  $('tabList').addEventListener('dragover', function (e) {
    e.preventDefault();
    var tab = e.target.closest('.tab');
    if (!tab || !dragID || tab.dataset.id === dragID) return;
    var rect = tab.getBoundingClientRect();
    var before = e.clientY < rect.top + rect.height / 2;
    var cls = before ? 'drag-over-top' : 'drag-over-bottom';
    Array.prototype.forEach.call(this.querySelectorAll('.tab'), function (t) {
      t.classList.remove('drag-over-top', 'drag-over-bottom');
    });
    tab.classList.add(cls);
  });
  $('tabList').addEventListener('drop', function (e) {
    e.preventDefault();
    var tab = e.target.closest('.tab');
    if (!tab || !dragID) return;
    var all = Array.prototype.slice.call(this.querySelectorAll('.tab'));
    var from = all.indexOf(this.querySelector('.tab[data-id="' + dragID + '"]'));
    var to = all.indexOf(tab);
    var rect = tab.getBoundingClientRect();
    var before = e.clientY < rect.top + rect.height / 2;
    var target = before ? to : to + 1;
    if (from < to && before) target = to - 1;
    api('hive.reorderTab', { from: dragID, to: target });
  });

  /* ---------- toolbar ---------- */

  var addrInput = $('addrInput');
  var suggestBox = $('suggestBox');

  function renderToolbar() {
    var active = state.tabs.find(function (t) { return t.id === state.activeTabID; });
    $('btnBack').dataset.disabled = active && active.canGoBack ? 'false' : 'true';
    $('btnForward').dataset.disabled = active && active.canGoForward ? 'false' : 'true';
    if (active) {
      if (active.url === null || active.url === 'hive://start' || active.url.indexOf('hive://start') === 0) {
        addrInput.value = '';
        $('addrLock').dataset.secure = 'false';
      } else {
        addrInput.value = active.url;
        $('addrLock').dataset.secure = active.url.indexOf('https://') === 0 ? 'true' : 'false';
      }
    }
    $('btnBookmark').dataset.active = active && active.isBookmarked ? 'true' : 'false';
    $('btnBookmark').style.color = active && active.isBookmarked ? 'var(--accent-3)' : '';
  }

  var addrTimer = null;
  function onAddrInput() {
    clearTimeout(addrTimer);
    var q = addrInput.value.trim();
    if (!q) { hideSuggest(); return; }
    addrTimer = setTimeout(function () {
      api('hive.suggest', { text: q }).then(function (res) {
        if (!res || !res.suggestions || !res.suggestions.length) { hideSuggest(); return; }
        renderSuggest(res.suggestions);
      });
    }, 120);
  }

  var suggIndex = -1;
  function renderSuggest(items) {
    suggIndex = -1;
    suggestBox.innerHTML = '';
    items.forEach(function (s) {
      var row = el('div', 'sugg', null);
      var isURL = s.kind === 'url' || s.kind === 'history';
      row.innerHTML = (isURL
        ? '<span class="sugg__icon">' + svg(ICONS.globe, 14) + '</span>'
        : '<span class="sugg__icon">' + svg(ICONS.search, 14) + '</span>') +
        '<span class="sugg__text">' + esc(s.text) + '</span>' +
        (s.url ? '<span class="sugg__url">' + esc(s.url) + '</span>' : '');
      row.addEventListener('click', function () {
        if (s.tabID) api('hive.selectTab', { id: s.tabID });
        else api('hive.navigate', { url: s.url || s.text });
        hideSuggest();
      });
      suggestBox.appendChild(row);
    });
    suggestBox.hidden = false;
  }

  function hideSuggest() { suggestBox.hidden = true; suggIndex = -1; }

  // Grow the chrome frame while the address bar is focused (sidebar mode).
  addrInput.addEventListener('focus', function () {
    if (state.chromeMode === 'sidebar') api('hive.setChromeDimension', { dimension: 560 });
    else api('hive.setChromeDimension', { dimension: 420 });
  });
  addrInput.addEventListener('blur', function () {
    setTimeout(function () {
      if (!state.isChromePanelOpen) api('hive.setChromeDimension', { dimension: 270 });
    }, 120);
  });
  addrInput.addEventListener('input', onAddrInput);
  addrInput.addEventListener('keydown', function (e) {
    var items = suggestBox.querySelectorAll('.sugg');
    if (e.key === 'ArrowDown' && items.length) {
      e.preventDefault();
      suggIndex = (suggIndex + 1) % items.length;
      markSugg(items);
    } else if (e.key === 'ArrowUp' && items.length) {
      e.preventDefault();
      suggIndex = (suggIndex - 1 + items.length) % items.length;
      markSugg(items);
    } else if (e.key === 'Escape') {
      hideSuggest();
      addrInput.blur();
    } else if (e.key === 'Enter') {
      e.preventDefault();
      var chosen = suggIndex >= 0 && items[suggIndex];
      if (chosen) {
        var s = chosen.__sugg;
        if (s.tabID) api('hive.selectTab', { id: s.tabID });
        else api('hive.navigate', { url: s.url || s.text });
      } else {
        api('hive.submit', { text: addrInput.value });
      }
      hideSuggest();
    }
  });
  function markSugg(items) {
    Array.prototype.forEach.call(items, function (n, i) {
      n.dataset.active = i === suggIndex ? 'true' : 'false';
    });
  }

  $('btnBack').addEventListener('click', function () { api('hive.back'); });
  $('btnForward').addEventListener('click', function () { api('hive.forward'); });
  $('btnReload').addEventListener('click', function () {
    this.classList.add('reloading');
    api('hive.reload');
  });
  $('btnBookmark').addEventListener('click', function () { api('hive.toggleBookmark'); });
  $('btnSettings').addEventListener('click', function () { openPanel('settings'); });
  $('btnDownloads').addEventListener('click', function () { openPanel('downloads'); });
  /* ---------- persistent agent dock (Comet-style) ---------- */

  function agentDockOpen() {
    var dock = $('agentDock');
    if (!dock.hidden) { dock.hidden = true; return; }
    dock.hidden = false;
    var input = $('agentAsk');
    input.focus();
    renderAIPanel(); // show the empty-state hero when dock opens
  }

  function agentAsk(text) {
    var q = (text || '').trim();
    if (!q) return;
    $('agentDock').hidden = true;
    api('hive.agent.run', { text: q }).then(function () { refresh(); });
  }

  $('agentSend').addEventListener('click', function () {
    agentAsk($('agentAsk').value);
    $('agentAsk').value = '';
  });
  $('agentAsk').addEventListener('keydown', function (e) {
    if (e.key === 'Enter') {
      e.preventDefault();
      agentAsk($('agentAsk').value);
      $('agentAsk').value = '';
    } else if (e.key === 'Escape') {
      $('agentDock').hidden = true;
      $('agentAsk').value = '';
    }
  });
  $('agentDock').addEventListener('keydown', function (e) {
    if (e.key === 'Escape') $('agentDock').hidden = true;
  });

  $('btnCouncil').addEventListener('click', function () {
    var active = state.tabs.find(function (t) { return t.id === state.activeTabID; });
    var question = active ? 'Summarize: ' + (active.title || active.host || 'this page') : 'What can you help me with?';
    api('hive.agent.run', { text: question }).then(function () { refresh(); });
  });
  $('btnNewTab').addEventListener('click', function () { api('hive.newTab'); });

  $('btnPanelClose').addEventListener('click', function () { closePanel(); });

  /* ---------- workspaces ---------- */

  function renderWorkspaces() {
    var row = $('workspaceRow');
    row.innerHTML = '';
    state.spaces.forEach(function (ws) {
      var w = el('div', 'workspace', null);
      w.dataset.id = ws.id;
      w.dataset.active = ws.id === currentWorkspaceID() ? 'true' : 'false';
      var hue = Math.abs(hash(ws.colorHex || ws.id)) % 360;
      w.innerHTML = '<span class="workspace__dot" style="background:' + ws.colorHex + '"></span>' +
        '<span>' + esc(ws.name) + '</span><span class="workspace__count">' + ws.tabCount + '</span>';
      w.addEventListener('click', function () { api('hive.switchWorkspace', { id: ws.id }); });
      row.appendChild(w);
    });
  }

  var lastWorkspaceID = null;
  function currentWorkspaceID() {
    if (!state.tabs.length) return null;
    if (lastWorkspaceID) return lastWorkspaceID;
    var active = state.tabs.find(function (t) { return t.id === state.activeTabID; });
    return active ? active.workspaceID : state.tabs[0].workspaceID;
  }

  /* ---------- AI panel ---------- */

  function renderAIPanel() {
    if (!IS_CHROME) return;
    var container = document.getElementById('aiPanel');
    if (!container) return;

    var research = state.deepResearchStep;
    var council = state.councilVerdict;
    var agent = state.agentTask;
    var dockOpen = !$('agentDock').hidden;
    var html = '';

    // Empty state — the dock is the hero when nothing is running. Shows the
    // 5 AI states are honest: no fabricated activity, just an invitation.
    var busy = state.isCouncilConvening || (research && !research.isComplete) ||
      (agent && agent.phase !== 'idle' && agent.phase !== 'done');
    if (dockOpen && !busy && !council) {
      html += '<div class="ai-panel ai-panel--hero">' +
        '<div class="ai-panel__hero-title">Ask Hive anything</div>' +
        '<div class="ai-panel__hero-hint">Summarize the page · Deep research · Take a browser action</div>' +
        '<div class="ai-panel__hero-shortcuts">' +
        '<span class="ai-panel__kbd">⌘A</span> ask · ' +
        '<span class="ai-panel__kbd">⏎</span> run · ' +
        '<span class="ai-panel__kbd">esc</span> close' +
        '</div>' +
        '</div>';
    }

    // Council convening — show live responses as they arrive
    if (state.isCouncilConvening) {
      var live = state.councilLiveResponses || [];
      html += '<div class="ai-panel">' +
        '<div class="ai-panel__header">' +
        '<span class="ai-panel__icon">' + svg(ICONS.settings, 13) + '</span>' +
        '<span class="ai-panel__label">Council deliberating…</span>' +
        '<span class="ai-panel__pct">' + live.length + ' responded</span>' +
        '</div>';
      for (var i = 0; i < live.length; i++) {
        var r = live[i];
        var badge = r.status === 'success'
          ? '<span class="ai-panel__tag ai-panel__tag--ok">' + esc(r.provider) + '</span>'
          : '<span class="ai-panel__tag ai-panel__tag--warn">' + esc(r.provider) + ' ' + esc(r.status) + '</span>';
        html += '<div class="ai-panel__live-row">' +
          badge +
          '<span class="ai-panel__live-text">' + esc(r.answer.slice(0, 120)) + '</span>' +
          '<span class="ai-panel__live-pct">' + Math.round(r.confidence * 100) + '%</span>' +
          '</div>';
      }
      html += '</div>';
    }

    // Deep research progress bar (shown while research is running)
    if (research && !research.isComplete) {
      html += '<div class="ai-panel">' +
        '<div class="ai-panel__header">' +
        '<span class="ai-panel__icon">' + svg(ICONS.search, 13) + '</span>' +
        '<span class="ai-panel__label">' + esc(research.label) + '</span>' +
        '<span class="ai-panel__pct">' + Math.round(research.progress * 100) + '%</span>' +
        '</div>' +
        '<div class="ai-panel__bar"><i style="width:' + Math.round(research.progress * 100) + '%"></i></div>' +
        '</div>';
    }

    // Council verdict (shown when complete)
    if (council) {
      var degradedTag = council.isDegraded
        ? '<span class="ai-panel__tag ai-panel__tag--warn">Degraded</span>' : '';
      var confPct = Math.round(council.confidence * 100);
      html += '<div class="ai-panel">' +
        '<div class="ai-panel__header">' +
        '<span class="ai-panel__icon">' + svg(ICONS.settings, 13) + '</span>' +
        '<span class="ai-panel__label">Council: ' + confPct + '%</span>' +
        '<span class="ai-panel__models">' + esc(council.activeProviders.join(', ')) + '</span>' +
        degradedTag +
        '<button class="ai-panel__dismiss" onclick="hiveDismissVerdict()" title="Dismiss verdict" aria-label="Dismiss">' +
        svg(ICONS.close, 10) + '</button>' +
        '</div>' +
        '<div class="ai-panel__body">' + esc(council.answer) + '</div>';
      if (council.reasoning) {
        html += '<div class="ai-panel__reasoning">' + esc(council.reasoning) + '</div>';
      }
      if (council.agreements.length || council.disagreements.length) {
        html += '<div class="ai-panel__meta">';
        if (council.agreements.length) {
          html += '<span class="ai-panel__agree">' +
            esc(council.agreements.slice(0, 3).join(', ')) + '</span>';
        }
        if (council.disagreements.length) {
          html += '<span class="ai-panel__disagree">' +
            esc(council.disagreements.slice(0, 3).join(', ')) + '</span>';
        }
        html += '</div>';
      }
      html += '</div>';
    }

    // Agent pipeline — show progress, phase, and action results
    if (agent && agent.phase !== 'idle' && agent.phase !== 'done') {
      var phaseLabel = { council: 'Council', researching: 'Research', acting: 'Browser' }[agent.phase] || agent.phase;
      html += '<div class="ai-panel ai-panel--agent">' +
        '<div class="ai-panel__header">' +
        '<span class="ai-panel__icon">' + svg(ICONS.search, 13) + '</span>' +
        '<span class="ai-panel__label">Agent: ' + esc(phaseLabel) + '</span>' +
        '<span class="ai-panel__pct">' + Math.round(agent.stepProgress * 100) + '%</span>' +
        '<button class="ai-panel__dismiss" onclick="hiveCancelAgent()" title="Cancel" aria-label="Cancel agent">' +
        svg(ICONS.close, 10) + '</button>' +
        '</div>' +
        '<div class="ai-panel__body ai-panel__body--sm">' + esc(agent.stepLabel) + '</div>' +
        '<div class="ai-panel__bar"><i style="width:' + Math.round(agent.stepProgress * 100) + '%"></i></div>';
      // Show action results
      if (agent.actions && agent.actions.length) {
        html += '<div class="ai-panel__actions">';
        for (var i = 0; i < agent.actions.length; i++) {
          var a = agent.actions[i];
          var icon = a.success ? svg(ICONS.check, 10) : svg(ICONS.close, 10);
          var cls = a.success ? 'ai-panel__action--ok' : 'ai-panel__action--fail';
          html += '<div class="ai-panel__action ' + cls + '">' + icon + ' ' + esc(a.label) + '</div>';
        }
        html += '</div>';
      }
      html += '</div>';
    }

    container.innerHTML = html;
    container.hidden = !html;
  }


  function hiveDismissVerdict() {
    state.councilVerdict = null;
    state.deepResearchStep = null;
    state.agentTask = null;
    api('hive.dismissCouncilVerdict').then(function () { refresh(); });
    renderAIPanel();
  }

  function hiveCancelAgent() {
    api('hive.agent.cancel').then(function () { refresh(); });
  }

  /* ---------- panels ---------- */

  function openPanel(name) {
    state.isChromePanelOpen = name;
    api('hive.setPanel', { panel: name });
    var panel = $('panel');
    var titles = { settings: 'Settings', history: 'History', bookmarks: 'Bookmarks', downloads: 'Downloads' };
    $('panelTitle').textContent = titles[name] || 'Panel';
    panel.hidden = false;
    requestAnimationFrame(function () { panel.classList.add('panel--open'); });
    renderPanel();
  }
  function closePanel() {
    state.isChromePanelOpen = null;
    api('hive.setPanel', { panel: '' });
    var panel = $('panel');
    panel.classList.remove('panel--open');
    setTimeout(function () { panel.hidden = true; }, 250);
  }

  function renderPanel() {
    var name = state.isChromePanelOpen;
    var body = $('panelBody');
    if (!name) return;
    if (name === 'settings') body.innerHTML = settingsHTML();
    else if (name === 'history')
      body.innerHTML = listHTML(state.history, 'le', historyRow, 'No browsing history yet') +
        (state.history.length ? '<button class="le__clear" data-clear-history>Clear history</button>' : '');
    else if (name === 'bookmarks') body.innerHTML = bookmarksHTML();
    else if (name === 'downloads') body.innerHTML = listHTML(state.downloads, 'le', downloadRow, 'No downloads yet');
    wirePanelEvents(body, name);
  }

  function listHTML(items, cls, rowFn, emptyText) {
    if (!items.length) {
      return '<div class="palette__empty">' + (emptyText || 'Nothing here yet.') + '</div>';
    }
    return items.map(rowFn).join('');
  }

  function historyRow(item) {
    var hue = Math.abs(hash(item.host || item.url || '')) % 360;
    return '<div class="le" data-url="' + esc(item.url) + '" title="' + esc(item.url) + '">' +
      tileHTML(item.host, item.title, hue) +
      '<span class="le__body"><span class="le__title">' + esc(item.title) + '</span>' +
      '<span class="le__meta">' + esc(item.url) + '</span></span>' +
      '<span class="le__time">' + esc(item.timeLabel) + '</span></div>';
  }
  function bookmarkRow(bm) {
    var hue = Math.abs(hash(bm.host || bm.title || '')) % 360;
    return '<div class="le" data-url="' + esc(bm.url) + '" title="' + esc(bm.url) + '">' +
      tileHTML(bm.host, bm.title, hue) +
      '<span class="le__body"><span class="le__title">' + esc(bm.title) + '</span>' +
      '<span class="le__meta">' + esc(bm.url) + '</span></span>' +
      '<button class="le__remove" data-remove="' + esc(bm.id) + '" title="Remove bookmark" aria-label="Remove bookmark">×</button></div>';
  }
  function downloadRow(dl) {
    var pct = 0;
    if (typeof dl.totalBytes === 'number' && dl.totalBytes > 0) {
      pct = Math.min(100, Math.round(((dl.receivedBytes || 0) / dl.totalBytes) * 100));
    } else if (dl.progress) {
      pct = Math.min(100, Math.round(dl.progress * 100));
    }
    var st = String(dl.state || 'downloading');
    var label = st === 'inProgress' || st === 'downloading' ? 'Downloading'
      : st ? st.charAt(0).toUpperCase() + st.slice(1) : 'Downloading';
    var inFlight = st === 'downloading' || st === 'inProgress' || st === 'paused';
    var bar = inFlight ? '<span class="le__bar"><i style="width:' + pct + '%"></i></span>' : '';
    return '<div class="le" data-url="' + esc(dl.url) + '" data-dl-id="' + esc(dl.id) +
      '" data-dl-state="' + esc(st) + '" title="' + esc(dl.url) + '">' +
      '<span class="le__tile">' + svg(ICONS.download, 14) + '</span>' +
      '<span class="le__body"><span class="le__title">' + esc(dl.title || dl.name || 'Download') + '</span>' +
      '<span class="le__meta">' + esc(dl.url) + '</span>' +
      '<span class="le__state">' + esc(label) + (inFlight ? ' · ' + pct + '%' : '') + '</span>' + bar +
      '</span></div>';
  }

  function bookmarksHTML() {
    var header = '<div class="setting"><div><div class="setting__label">Open bookmarks bar</div>' +
      '<div class="setting__hint">Show a bookmark row under the toolbar</div></div>' +
      '<span class="toggle" data-toggle="bookmarksBar" data-on="' + (prefs.bookmarksBar ? 'true' : 'false') + '"></span></div>';
    return header + listHTML(state.bookmarks, 'le', bookmarkRow, 'No bookmarks yet — press ⌘D on any page');
  }

  function settingsHTML() {
    var seg = function (name, options, current) {
      var html = '<div class="seg">';
      options.forEach(function (o) {
        html += '<span class="seg__item" data-seg="' + name + '" data-val="' + o.v + '"' +
          (o.v === current ? ' data-active="true"' : '') + '>' + esc(o.label) + '</span>';
      });
      return html + '</div>';
    };
    var toggle = function (name, on, label, hint) {
      return '<div class="setting"><div><div class="setting__label">' + label + '</div>' +
        (hint ? '<div class="setting__hint">' + hint + '</div>' : '') + '</div>' +
        '<span class="toggle" data-toggle="' + name + '" data-on="' + (on ? 'true' : 'false') + '"></span></div>';
    };
    return '<div class="panel-section"><h3>Layout</h3>' +
      '<div class="setting"><div><div class="setting__label">Tab layout</div>' +
      '<div class="setting__hint">Vertical sidebar (Arc/Zen) or horizontal strip (Chrome/Brave)</div></div>' +
      seg('layout', [{ v: 'vertical', label: 'Vertical' }, { v: 'horizontal', label: 'Horizontal' }], state.layout) + '</div>' +
      '<div class="setting"><div><div class="setting__label">Density</div></div>' +
      seg('density', [{ v: 'comfortable', label: 'Comfortable' }, { v: 'compact', label: 'Compact' }], prefs.density) + '</div>' +
      toggle('bookmarksBar', prefs.bookmarksBar, 'Show bookmarks bar');
    '</div>' +
      '<div class="panel-section"><h3>Appearance</h3>' +
      '<div class="setting"><div><div class="setting__label">Theme</div></div>' +
      seg('theme', [{ v: 'system', label: 'System' }, { v: 'light', label: 'Light' }, { v: 'dark', label: 'Dark' }], prefs.theme) + '</div>' +
      toggle('animations', prefs.animations, 'Animations', 'Transitions, glows, and spring motion') +
      '</div>' +
      '<div class="panel-section"><h3>About</h3>' +
      '<div class="setting"><div><div class="setting__label">Hive Browser</div>' +
      '<div class="setting__hint">Chromium 148 · CEF · web chrome shell</div></div></div></div>';
  }

  function wirePanelEvents(body, name) {
    body.querySelectorAll('[data-seg]').forEach(function (item) {
      item.addEventListener('click', function () {
        var key = item.dataset.seg;
        var val = item.dataset.val;
        if (key === 'layout') api('hive.setLayout', { mode: val });
        else if (key === 'theme') { prefs.theme = val; savePrefs(); applyTheme(); }
        else if (key === 'density') { prefs.density = val; savePrefs(); applyDensity(); }
        renderPanel();
      });
    });
    body.querySelectorAll('[data-toggle]').forEach(function (t) {
      t.addEventListener('click', function () {
        var key = t.dataset.toggle;
        var on = t.dataset.on !== 'true';
        if (key === 'bookmarksBar') { prefs.bookmarksBar = on; savePrefs(); renderBookmarksBar(); }
        else if (key === 'animations') { prefs.animations = on; savePrefs(); applyTheme(); }
        t.dataset.on = on ? 'true' : 'false';
      });
    });
    body.querySelectorAll('.le[data-url]').forEach(function (row) {
      row.addEventListener('click', function () {
        if (row.dataset.dlId !== undefined) {
          if (row.dataset.dlState === 'completed') api('hive.openDownload', { id: row.dataset.dlId });
          return;
        }
        api('hive.navigate', { url: row.dataset.url });
        if (name === 'history') closePanel();
      });
    });
    body.querySelectorAll('[data-remove]').forEach(function (btn) {
      btn.addEventListener('click', function (e) {
        e.stopPropagation();
        api('hive.removeBookmark', { id: btn.dataset.remove }).then(function (res) {
          if (res !== null) refresh();
        });
      });
    });
    var clearBtn = body.querySelector('[data-clear-history]');
    if (clearBtn) clearBtn.addEventListener('click', function () {
      api('hive.clearHistory').then(function (res) {
        if (res !== null) refresh();
      });
    });
  }

  /* ---------- bookmarks bar ---------- */

  function renderBookmarksBar() {
    var bar = $('bookmarksBar');
    if (state.layout !== 'horizontal' || !prefs.bookmarksBar || !state.bookmarks.length) {
      bar.hidden = true;
      return;
    }
    bar.hidden = false;
    var list = $('bookmarksList');
    list.innerHTML = '';
    state.bookmarks.slice(0, 24).forEach(function (bm) {
      var chip = el('span', 'bmchip', null);
      chip.textContent = bm.title;
      chip.title = bm.url;
      chip.addEventListener('click', function () { api('hive.navigate', { url: bm.url }); });
      list.appendChild(chip);
    });
  }

  /* ---------- context menu ---------- */

  var ctx = $('ctxMenu');
  function showCtxMenu(x, y, id) {
    var t = state.tabs.find(function (x) { return x.id === id; });
    if (!t) return;
    var items = [
      { label: t.isPinned ? 'Unpin tab' : 'Pin tab', action: function () { api('hive.pinTab', { id: id }); } },
      { label: 'Duplicate tab', action: function () { api('hive.duplicateTab', { id: id }); } },
      { label: 'Close other tabs', action: function () { api('hive.closeOtherTabs', { id: id }); } }
    ];
    if (!t.isPinned && !t.isEssential) {
      items.push({ sep: true });
      items.push({ label: 'Close tab', danger: true, action: function () { animateCloseTab(id); } });
    }
    items.push({ sep: true });
    items.push({ label: 'Reopen closed tab', action: function () { api('hive.reopenClosedTab'); } });
    ctx.innerHTML = '';
    items.forEach(function (item) {
      if (item.sep) { ctx.appendChild(el('div', 'ctxmenu__sep')); return; }
      var b = el('button', 'ctxmenu__item' + (item.danger ? ' ctxmenu__item--danger' : ''));
      b.textContent = item.label;
      b.addEventListener('click', function () { ctx.hidden = true; item.action(); });
      ctx.appendChild(b);
    });
    ctx.hidden = false;
    var w = ctx.offsetWidth, h = ctx.offsetHeight;
    ctx.style.left = Math.min(x, window.innerWidth - w - 8) + 'px';
    ctx.style.top = Math.min(y, window.innerHeight - h - 8) + 'px';
  }
  document.addEventListener('click', function (e) {
    if (ctx.hidden) return;
    if (!ctx.contains(e.target)) ctx.hidden = true;
  });

  /* ---------- command palette ---------- */

  function openPalette() {
    $('paletteBackdrop').hidden = false;
    var input = $('paletteInput');
    input.value = '';
    input.focus();
    renderPalette('');
  }
  function closePalette() { $('paletteBackdrop').hidden = true; }

  function paletteActions(q) {
    var actions = [
      { icon: ICONS.globe, label: 'Morning Brief', run: function () { navigate('hive://brief/'); } },
      { icon: ICONS.globe, label: 'New Tab', run: function () { api('hive.newTab'); } },
      { icon: ICONS.panel, label: state.layout === 'vertical' ? 'Switch to Horizontal tabs' : 'Switch to Vertical tabs',
        run: function () { api('hive.setLayout', { mode: state.layout === 'vertical' ? 'horizontal' : 'vertical' }); } },
      { icon: ICONS.settings, label: 'Settings', run: function () { openPanel('settings'); } },
      { icon: ICONS.history, label: 'History', run: function () { openPanel('history'); } },
      { icon: ICONS.bookmark, label: 'Bookmarks', run: function () { openPanel('bookmarks'); } },
      { icon: ICONS.download, label: 'Downloads', run: function () { openPanel('downloads'); } },
      { icon: ICONS.panel, label: 'Split View: toggle side-by-side',
        run: function () { api('hive.toggleSplit').then(function (res) { if (res !== null) refresh(); }); } },
      { icon: ICONS.clock, label: 'Reopen last closed tab (⌘⇧T)',
        run: function () { api('hive.reopenClosedTab').then(function (res) { if (res !== null) refresh(); }); } },
      { icon: ICONS.window, label: 'New Window (⌘N)', run: function () { api('hive.newWindow'); } },
      { icon: ICONS.private, label: 'New Private Tab (⇧⌘N)', run: function () { api('hive.newPrivateTab'); } },
            { icon: ICONS.search, label: 'Ask Hive…', run: function () { agentDockOpen(); } },
      { icon: ICONS.search, label: 'Ask AI Council', run: function () {
        var active = state.tabs.find(function (t) { return t.id === state.activeTabID; });
        var q = active ? 'Summarize: ' + (active.title || active.host || 'this page') : 'What can you help me with?';
        api('hive.agent.run', { text: q }).then(function () { refresh(); });
      } },
      { icon: ICONS.search, label: 'Deep Research', run: function () {
        var active = state.tabs.find(function (t) { return t.id === state.activeTabID; });
        var q = active ? 'Research: ' + (active.title || active.host || 'this page') : 'Research: ';
        $('agentAsk').value = q;
        agentDockOpen();
        var input = $('agentAsk');
        input.setSelectionRange(q.length, q.length);
      } },

      { icon: ICONS.focus, label: 'Focus Mode: hide chrome', run: toggleCompactMode },
      { icon: ICONS.bookmark, label: (prefs.bookmarksBar ? 'Hide' : 'Show') + ' bookmarks bar',
        run: function () { prefs.bookmarksBar = !prefs.bookmarksBar; savePrefs(); renderBookmarksBar(); } }
    ];
    return actions.filter(function (a) {
      return !q || a.label.toLowerCase().indexOf(q) !== -1;
    });
  }

  function renderPalette(q) {
    var list = $('paletteList');
    q = q.toLowerCase();
    list.innerHTML = '';
    var rows = [];
    paletteActions(q).forEach(function (a, i) {
      var row = el('div', 'palette__item', null);
      row.innerHTML = '<span class="sugg__icon">' + svg(a.icon, 15) + '</span><span>' + esc(a.label) + '</span>';
      row.dataset.index = i;
      row.addEventListener('click', function () { closePalette(); a.run(); });
      list.appendChild(row);
      rows.push(row);
    });
    // Tab switches
    state.tabs.forEach(function (t) {
      if (!q) return;
      var title = (t.title || '').toLowerCase();
      var url = (t.url || '').toLowerCase();
      if (title.indexOf(q) === -1 && url.indexOf(q) === -1) return;
      var row = el('div', 'palette__item', null);
      row.innerHTML = '<span class="sugg__icon">' + svg(ICONS.globe, 15) + '</span><span>' + esc(t.title) +
        '</span><span class="le__meta" style="margin-left:auto">' + esc(t.host || '') + '</span>';
      row.addEventListener('click', function () { closePalette(); api('hive.selectTab', { id: t.id }); });
      list.appendChild(row);
    });
    if (!list.children.length) {
      list.appendChild(el('div', 'palette__empty', 'No matches.'));
    }
  }

  var palIndex = -1;
  var palInput = $('paletteInput');
  palInput.addEventListener('input', function () { palIndex = -1; renderPalette(palInput.value); });
  palInput.addEventListener('keydown', function (e) {
    var items = $('paletteList').querySelectorAll('.palette__item');
    if (e.key === 'ArrowDown' && items.length) {
      e.preventDefault();
      palIndex = (palIndex + 1) % items.length;
    } else if (e.key === 'ArrowUp' && items.length) {
      e.preventDefault();
      palIndex = (palIndex - 1 + items.length) % items.length;
    } else if (e.key === 'Enter' && items.length) {
      e.preventDefault();
      var idx = palIndex < 0 ? 0 : palIndex;
      items[idx].click();
    } else if (e.key === 'Escape') {
      closePalette();
    }
    Array.prototype.forEach.call(items, function (n, i) {
      n.dataset.active = i === palIndex ? 'true' : 'false';
    });
  });
  $('paletteBackdrop').addEventListener('click', function (e) {
    if (e.target === this) closePalette();
  });

  /* ---------- keyboard shortcuts ---------- */

  document.addEventListener('keydown', function (e) {
    var meta = e.metaKey || e.ctrlKey;
    if (e.key === 'Escape') {
      if (state.isChromePanelOpen) closePanel();
      else if (!$('paletteBackdrop').hidden) closePalette();
      else if (document.body.dataset.compact) setCompactMode(false);
      else if (!suggestBox.hidden) hideSuggest();
      else if (document.activeElement === addrInput) addrInput.blur();
      return;
    }
    if (meta && e.key.toLowerCase() === 'a') { e.preventDefault(); agentDockOpen(); return; }
    if (meta && e.key.toLowerCase() === 'k') { e.preventDefault(); openPalette(); return; }
    if (meta && e.key.toLowerCase() === 'n' && e.shiftKey) { e.preventDefault(); api('hive.newPrivateTab'); return; }
    if (meta && e.key.toLowerCase() === 'n') { e.preventDefault(); api('hive.newWindow'); return; }
    if (meta && e.key.toLowerCase() === 's' && e.shiftKey) { e.preventDefault(); api('hive.toggleSplit'); return; }
    if (meta && e.key.toLowerCase() === 't' && e.shiftKey) { e.preventDefault(); api('hive.reopenClosedTab'); return; }
    if (meta && e.key === ',') { e.preventDefault(); openPanel('settings'); return; }
    if (meta && e.key.toLowerCase() === 'l') { e.preventDefault(); addrInput.focus(); addrInput.select(); return; }
    if (meta && e.key.toLowerCase() === 't') { e.preventDefault(); api('hive.newTab'); return; }
    if (meta && e.key.toLowerCase() === 'w') {
      e.preventDefault();
      if (state.activeTabID) animateCloseTab(state.activeTabID);
      return;
    }
    if (meta && e.key === '[') { api('hive.back'); return; }
    if (meta && e.key === ']') { api('hive.forward'); return; }
    if (meta && e.key.toLowerCase() === 'r') { api('hive.reload'); return; }
    if (meta && e.key.toLowerCase() === 'd') { e.preventDefault(); api('hive.toggleBookmark'); return; }
    if (meta && e.key.toLowerCase() === 'y') { e.preventDefault(); openPanel('history'); return; }
    if (meta && e.key.toLowerCase() === 'j') { e.preventDefault(); openPanel('downloads'); return; }
    if (meta && e.key.toLowerCase() === 'b') { e.preventDefault(); openPanel('bookmarks'); return; }
    if (meta && !e.shiftKey && /^[1-9]$/.test(e.key)) {
      e.preventDefault();
      var idx = parseInt(e.key, 10) - 1;
      var vis = state.tabs.filter(function (t) { return !t.isPinned && !t.isEssential; });
      if (vis[idx]) api('hive.selectTab', { id: vis[idx].id });
      return;
    }
    if (e.key === '/' && document.activeElement !== addrInput) {
      e.preventDefault();
      openPalette();
    }
  });

  /* ================= START PAGE ================= */

  var stage = $('stage');
  var stageQuery = $('stageQuery');

  function renderStartPage() {
    if (IS_CHROME) return;
    $('btnOpenBrief').addEventListener('click', function () { navigate('hive://brief'); });
    $('briefCard').hidden = false;
    var grid = $('topsitesGrid');
    grid.innerHTML = '';
    state.topSites.forEach(function (site) {
      var hue = Math.abs(hash(site.host)) % 360;
      var tile = el('div', 'topsite', null);
      tile.innerHTML = '<span class="topsite__icon" style="background:hsl(' + hue + ',32%,48%)">' + esc(site.host.charAt(0).toUpperCase()) + '</span>' +
        '<span class="topsite__label">' + esc(site.host) + '</span>';
      tile.addEventListener('click', function () { api('hive.navigate', { url: site.url }); });
      grid.appendChild(tile);
    });
    $('topSitesSection').hidden = !state.topSites.length;

    var recent = $('recentList');
    recent.innerHTML = '';
    state.recent.forEach(function (item) {
      var hue = Math.abs(hash(item.host)) % 360;
      var row = el('div', 'le', null);
      row.innerHTML = tileHTML(item.host, item.title, hue) +
        '<span class="le__body"><span class="le__title">' + esc(item.title) + '</span>' +
        '<span class="le__meta">' + esc(item.url) + '</span></span>' +
        '<span class="le__time">' + esc(item.timeLabel) + '</span>';
      row.addEventListener('click', function () { api('hive.navigate', { url: item.url }); });
      recent.appendChild(row);
    });
    $('recentSection').hidden = !state.recent.length;

    var spaces = $('spacesRow');
    spaces.innerHTML = '';
    state.spaces.forEach(function (ws) {
      var s = el('div', 'workspace', null);
      s.dataset.active = ws.tabCount > 0 ? 'true' : 'false';
      s.innerHTML = '<span class="workspace__dot" style="background:' + ws.colorHex + '"></span>' +
        '<span>' + esc(ws.name) + '</span><span class="workspace__count">' + ws.tabCount + '</span>';
      s.addEventListener('click', function () { api('hive.switchWorkspace', { id: ws.id }); });
      spaces.appendChild(s);
    });
    $('spacesSection').hidden = !state.spaces.length;
  }

  var stageSuggest = $('stageSuggest');
  var stageTimer = null;
  stageQuery.addEventListener('input', function () {
    clearTimeout(stageTimer);
    var q = stageQuery.value.trim();
    if (!q) { stageSuggest.hidden = true; return; }
    stageTimer = setTimeout(function () {
      api('hive.suggest', { text: q }).then(function (res) {
        if (!res || !res.suggestions || !res.suggestions.length) { stageSuggest.hidden = true; return; }
        stageSuggest.innerHTML = '';
        res.suggestions.forEach(function (s) {
          var row = el('div', 'sugg', null);
          row.innerHTML = '<span class="sugg__icon">' + svg(ICONS.search, 14) + '</span>' +
            '<span class="sugg__text">' + esc(s.text) + '</span>' +
            (s.url ? '<span class="sugg__url">' + esc(s.url) + '</span>' : '');
          row.addEventListener('click', function () {
            api(s.tabID ? 'hive.selectTab' : 'hive.navigate', s.tabID ? { id: s.tabID } : { url: s.url || s.text });
            stageSuggest.hidden = true;
          });
          stageSuggest.appendChild(row);
        });
        stageSuggest.hidden = false;
      });
    }, 120);
  });
  stageQuery.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') { stageQuery.blur(); }
    if (e.key === 'Enter') {
      e.preventDefault();
      api('hive.submit', { text: stageQuery.value });
    }
  });
  document.addEventListener('keydown', function (e) {
    if (IS_CHROME) return;
    if (e.key === 'Escape' && document.activeElement === stageQuery) {
      stageQuery.blur();
    }
  });

  $('stageSearchForm').addEventListener('submit', function (e) { e.preventDefault(); });

  /* ================= boot ================= */

  function boot() {
    if (IS_CHROME) {
      chromeEl.hidden = false;
      stage.hidden = true;
      addrInput.focus({ preventScroll: true });
    } else {
      stage.hidden = false;
      chromeEl.hidden = true;
      stageQuery.focus({ preventScroll: true });
    }
    applyDensity();
    if (hasBridge && window.cefSwift.on) {
      window.cefSwift.on('hive.stateChanged', function (data) {
        if (typeof data === 'string') { try { data = JSON.parse(data); } catch (e) { return; } }
        apply(data);
        if (IS_CHROME && data && data.layout) {
          chromeEl.classList.remove('chrome--sidebar', 'chrome--strip');
          chromeEl.classList.add('chrome--' + (data.layout === 'vertical' ? 'sidebar' : 'strip'));
        }
      });
    }
    refresh();
  }

  boot();
})();
"""#
    static let briefHTML = #"""
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>The Hive Brief</title>
  <link rel="stylesheet" href="style.css">
  <!-- Loaded only when the cliaMorningBriefLookingAheadEnabled flag is on; missing-file 404 is harmless. -->
  <link rel="stylesheet" href="looking-ahead.css">
  <!-- Loaded only when the contextBuilderMorningBriefFeedbackEnabled flag is on; missing-file 404 is harmless. -->
  <link rel="stylesheet" href="feedback.css">

</head>
<body>

  <div class="page">

    <div class="brief-scale">

    <!-- Hive hexagon mark -->
    <div class="greeting">
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 17 16" fill="none">
        <path d="M8.5 1 15.5 4.75V11.25L8.5 15 1.5 11.25V4.75L8.5 1Z" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round"/>
        <path d="M8.5 1v14M1.5 4.75l14 6.5M15.5 4.75l-14 6.5" stroke="currentColor" stroke-width="0.6" stroke-linejoin="round" opacity="0.5"/>
      </svg>
    </div>

    <!-- Hero: painting frame with "The [Day] Brief" -->
    <header class="hero">
      <div class="hero-edge hero-date" id="heroDate"></div>
      <div class="hero-edge hero-time" id="heroTime"></div>

      <div class="painting-frame" id="paintingFrame">
        <img class="painting-img" id="paintingImg" alt="">
        <div class="painting-overlay">
          <span class="hero-the">The</span>
          <h1 class="hero-day" id="heroDay">Monday Brief</h1>
        </div>
      </div>

      <div class="hero-sub">
        <p class="brief-blurb" id="briefBlurb"></p>
        <p class="painting-caption" id="paintingCaption"></p>
      </div>
    </header>

    <!-- Content: sections rendered from JSON by app.js -->
    <main class="content" id="briefContent"></main>

    <!-- Footer. The credit prose's source list is appended by app.js when
         `data.footer.sources` is present (gated by `clia-morning-brief-footer-sources`).
         The "Made for you by Hive" prefix, "With love from HIVE" line, halftone,
         and scroll-reveal are always present. -->
    <footer class="brief-footer" aria-label="Page footer">
      <div class="brief-footer__fade" aria-hidden="true"></div>
      <div class="brief-footer__halftone" aria-hidden="true"></div>
      <div class="brief-footer__inner">
        <p class="brief-footer__credit" id="briefFooterCredit" hidden>
          <span class="brief-footer__muted">Made for you by</span>
          <span class="brief-footer__brand">
            <svg class="brief-footer__icon brief-footer__icon--hive" width="19" height="18" viewBox="0 0 17 16" fill="none" aria-hidden="true">
              <path d="M8.5 1 15.5 4.75V11.25L8.5 15 1.5 11.25V4.75L8.5 1Z" stroke="currentColor" stroke-width="1.3" stroke-linejoin="round"/>
              <path d="M8.5 1v14M1.5 4.75l14 6.5M15.5 4.75l-14 6.5" stroke="currentColor" stroke-width="0.6" stroke-linejoin="round" opacity="0.5"/>
            </svg>
            <span>Hive</span>
          </span>
          <span class="brief-footer__credit-trailing" id="briefFooterCreditTrailing">.</span>
        </p>
        <p class="brief-footer__love">
          <span>With love from</span>
          <span class="brief-footer__circles" aria-label="Hive">
            <span class="brief-footer__circle">H</span>
            <span class="brief-footer__circle">I</span>
            <span class="brief-footer__circle">V</span>
            <span class="brief-footer__circle">E</span>
          </span>
        </p>
      </div>
    </footer>

    </div>

  </div>

  <!-- ============================================================
       HTML Templates (cloned by app.js — not rendered directly)
       ============================================================ -->

  <template id="section-template">
    <section class="brief-section">
      <h2 class="section-title"></h2>
      <div class="section-body"></div>
    </section>
  </template>

  <template id="push-forward-template">
    <div class="push-shell">
      <div class="push-body">
        <h3 class="push-topic"></h3>
        <p class="push-text"></p>
      </div>
      <a class="push-badge" href="#">
        <div class="push-star">
          <span class="push-star-text">Let's<br>do it <span class="star-arrow">&rarr;</span></span>
        </div>
      </a>
    </div>
  </template>

  <template id="proactive-work-template">
    <div class="proactive-shell">
      <div class="proactive-body">
        <h3 class="proactive-title"></h3>
        <p class="proactive-reasoning"></p>
      </div>
    </div>
  </template>

  <template id="todo-item-template">
    <article class="todo-item">
      <span class="todo-rank rank-number" aria-hidden="true"></span>
      <div class="todo-item-surface">
        <label class="todo-checkbox">
          <input type="checkbox">
          <span class="todo-check"></span>
        </label>
        <div class="todo-content">
          <div class="todo-head">
            <h3 class="todo-label"></h3>
          </div>
          <div class="todo-meta">
            <span class="todo-flag" hidden>Time-sensitive</span>
          </div>
          <p class="todo-context"></p>
          <div class="todo-actions">
            <a class="todo-dia-btn todo-chat-prompt" href="#" hidden>
              <span class="todo-dia-btn-expand">
                <svg class="todo-dia-btn-icon" width="16" height="14" viewBox="0 0 16 14" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true"><path fill="currentColor" d="M0.823639 6.625H0.198639H0.823639ZM14.8236 6.625H15.4486V6.625H14.8236ZM5.31583 12.292L5.48822 11.6912C5.39879 11.6656 5.30476 11.6602 5.21299 11.6755L5.31583 12.292ZM0.919342 13.0254L1.02209 13.6419L1.02218 13.6419L0.919342 13.0254ZM0.674225 12.6338L0.165564 12.2706L0.165373 12.2709L0.674225 12.6338ZM2.23184 10.4521L2.7405 10.8153C2.9114 10.576 2.89229 10.2498 2.69462 10.0321L2.23184 10.4521ZM0.823639 6.625H1.44864C1.44864 4.79108 2.22642 3.46361 3.38879 2.58212C4.56963 1.68664 6.17648 1.23328 7.81709 1.25047C9.45743 1.26766 11.0696 1.75475 12.2563 2.66295C13.4267 3.55874 14.1986 4.87161 14.1986 6.625H14.8236H15.4486C15.4486 4.45206 14.4705 2.78352 13.016 1.67031C11.5777 0.569508 9.68984 0.0200216 7.83019 0.000538468C5.9708 -0.0189418 4.07764 0.490951 2.63348 1.58613C1.17085 2.69531 0.198639 4.38592 0.198639 6.625H0.823639ZM14.8236 6.625H14.1986C14.1986 8.79258 13.0143 10.3083 11.3207 11.1738C9.60408 12.0511 7.39119 12.2373 5.48822 11.6912L5.31583 12.292L5.14344 12.8927C7.33493 13.5216 9.87594 13.316 11.8896 12.2869C13.9263 11.246 15.4486 9.3407 15.4486 6.625H14.8236ZM5.31583 12.292L5.21299 11.6755L0.816504 12.4089L0.919342 13.0254L1.02218 13.6419L5.41866 12.9085L5.31583 12.292ZM0.919342 13.0254L0.816592 12.4089C1.14339 12.3544 1.37854 12.7226 1.18308 12.9967L0.674225 12.6338L0.165373 12.2709C-0.288578 12.9074 0.25604 13.7696 1.02209 13.6419L0.919342 13.0254ZM0.674225 12.6338L1.18289 12.997L2.7405 10.8153L2.23184 10.4521L1.72318 10.089L0.165565 12.2706L0.674225 12.6338ZM2.23184 10.4521L2.69462 10.0321C1.9339 9.19403 1.44864 8.07188 1.44864 6.625H0.823639H0.198639C0.198639 8.37631 0.795428 9.79962 1.76907 10.8722L2.23184 10.4521Z"/></svg>
                <span class="todo-dia-btn-label-wrap"><span class="todo-dia-btn-label"></span></span>
              </span>
              <svg class="todo-dia-btn-arrow" width="18" height="18" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                <path d="M5 12h14M13 6l6 6-6 6" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </a>
          </div>
        </div>
      </div>
    </article>
  </template>

  <template id="todo-all-done-template">
    <div class="todo-all-done" aria-live="polite" hidden>
      <article class="todo-item todo-item--completion">
        <div class="todo-item-surface todo-all-done-surface">
          <div class="todo-all-done__card">
            <button type="button" class="todo-all-done__close" aria-label="Back to to-dos">
              <svg width="12" height="12" viewBox="0 0 12 12" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                <path d="M2 2l8 8M10 2L2 10" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/>
              </svg>
            </button>
            <div class="todo-all-done__stage">
              <div class="todo-confetti" aria-hidden="true"></div>
              <div class="todo-all-done__badge" aria-hidden="true">
                <span class="todo-all-done__star"></span>
                <svg class="todo-all-done__check" width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                  <path d="M5 10.5L8.25 13.75L15 6.75" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
              </div>
            </div>
            <div class="todo-all-done__content">
              <h3 class="todo-all-done__title">You completed all your to-dos!</h3>
              <p class="todo-all-done__desc">Nice work. The day is yours.</p>
            </div>
          </div>
        </div>
      </article>
    </div>
  </template>

  <template id="item-template">
    <article class="item">
      <span class="item-num"></span>
      <div class="item-body">
        <div class="item-head">
          <h3 class="item-title"><span class="item-tag tag-outline"></span></h3>
        </div>
        <div class="item-text">
          <p></p>
        </div>
        <ul class="item-bullets"></ul>
      </div>
    </article>
  </template>

  <template id="task-item-template">
    <article class="item task-item">
      <div class="item-body task-body">
        <div class="item-head">
          <h3 class="item-title task-title"></h3>
        </div>
        <div class="item-text">
          <p class="task-desc"></p>
        </div>
      </div>
    </article>
  </template>

  <template id="schedule-item-template">
    <div class="schedule-item">
      <span class="schedule-time"></span>
      <span class="schedule-event"></span>
    </div>
  </template>

  <template id="schedule-card-template">
    <div class="schedule-card">
      <div class="schedule-list"></div>
      <div class="schedule-divider"></div>
      <div class="schedule-right">
        <div class="schedule-summary">
          <div class="summary-panel summary-panel--detail summary-panel--visible" data-role="detail">
            <div class="detail-content" data-role="detail-content"></div>
            <button class="prep-badge" type="button">
              <div class="prep-star">
                <span class="prep-text">Prep me <span class="star-arrow">&rarr;</span></span>
              </div>
            </button>
          </div>
          <div class="summary-panel summary-panel--people" data-role="people"></div>
        </div>
      </div>
    </div>
  </template>

  <template id="people-entry-template">
    <div class="people-entry">
      <div class="people-entry-avatar-wrap"></div>
      <div class="people-entry-content">
        <div class="people-entry-name"></div>
        <div class="people-entry-blurb"></div>
        <div class="people-entry-social"></div>
      </div>
    </div>
  </template>

  <!-- ============================================================
       Source Icons (cloned into source-ref citations by app.js)
       ============================================================ -->

  <template id="source-icon-template">
    <a class="source-icon" target="_blank" rel="noopener">
      <span class="source-tip"></span>
    </a>
  </template>

  <template id="slack-icon">
    <svg viewBox="0 0 127 127" xmlns="http://www.w3.org/2000/svg">
      <path d="M27.2 80c0 7.3-5.9 13.2-13.2 13.2C6.7 93.2.8 87.3.8 80c0-7.3 5.9-13.2 13.2-13.2h13.2V80zm6.6 0c0-7.3 5.9-13.2 13.2-13.2 7.3 0 13.2 5.9 13.2 13.2v33c0 7.3-5.9 13.2-13.2 13.2-7.3 0-13.2-5.9-13.2-13.2V80z" fill="#E01E5A"/>
      <path d="M47 27c-7.3 0-13.2-5.9-13.2-13.2C33.8 6.5 39.7.6 47 .6c7.3 0 13.2 5.9 13.2 13.2V27H47zm0 6.7c7.3 0 13.2 5.9 13.2 13.2 0 7.3-5.9 13.2-13.2 13.2H13.9C6.6 60.1.7 54.2.7 46.9c0-7.3 5.9-13.2 13.2-13.2H47z" fill="#36C5F0"/>
      <path d="M99.9 46.9c0-7.3 5.9-13.2 13.2-13.2 7.3 0 13.2 5.9 13.2 13.2 0 7.3-5.9 13.2-13.2 13.2H99.9V46.9zm-6.6 0c0 7.3-5.9 13.2-13.2 13.2-7.3 0-13.2-5.9-13.2-13.2V13.8C66.9 6.5 72.8.6 80.1.6c7.3 0 13.2 5.9 13.2 13.2v33.1z" fill="#2EB67D"/>
      <path d="M80.1 99.8c7.3 0 13.2 5.9 13.2 13.2 0 7.3-5.9 13.2-13.2 13.2-7.3 0-13.2-5.9-13.2-13.2V99.8h13.2zm0-6.6c-7.3 0-13.2-5.9-13.2-13.2 0-7.3 5.9-13.2 13.2-13.2h33.1c7.3 0 13.2 5.9 13.2 13.2 0 7.3-5.9 13.2-13.2 13.2H80.1z" fill="#ECB22E"/>
    </svg>
  </template>

  <template id="confluence-icon">
    <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
      <path d="M0.870217 17.6049C0.621998 18.0097 0.343228 18.4794 0.106465 18.8537C0.00459268 19.0258 -0.0256744 19.2311 0.0221688 19.4253C0.0700121 19.6195 0.192147 19.7872 0.362322 19.8924L5.32671 22.9474C5.41298 23.0006 5.50899 23.0362 5.60914 23.052C5.70929 23.0677 5.81158 23.0634 5.91004 23.0393C6.0085 23.0151 6.10116 22.9715 6.18262 22.9112C6.26408 22.8508 6.33271 22.7749 6.38451 22.6877C6.58309 22.3555 6.83894 21.924 7.11771 21.4619C9.08437 18.2159 11.0625 18.6131 14.6292 20.3163L19.5516 22.6572C19.6439 22.7011 19.744 22.726 19.8461 22.7305C19.9482 22.7351 20.0502 22.719 20.146 22.6834C20.2418 22.6478 20.3294 22.5933 20.4038 22.5232C20.4781 22.4531 20.5377 22.3688 20.5788 22.2753L22.9427 16.929C23.0229 16.7455 23.0279 16.5378 22.9565 16.3506C22.885 16.1635 22.7429 16.0119 22.5608 15.9285C21.5221 15.4397 19.4561 14.4659 17.5964 13.5685C10.9059 10.3187 5.21979 10.5288 0.870217 17.6049Z" fill="url(#paint0_linear_confluence)"/>
      <path d="M23.1298 5.47273C23.378 5.06795 23.6568 4.59824 23.8935 4.224C23.9954 4.05185 24.0257 3.8466 23.9778 3.65237C23.93 3.45814 23.8079 3.29044 23.6377 3.1853L18.6733 0.130286C18.5864 0.0717489 18.4884 0.031722 18.3853 0.0126956C18.2823 -0.00633083 18.1764 -0.00394961 18.0743 0.019691C17.9722 0.0433317 17.8761 0.087726 17.7919 0.150112C17.7077 0.212498 17.6373 0.291542 17.5849 0.382324C17.3864 0.714557 17.1305 1.14608 16.8517 1.60815C14.8851 4.8541 12.907 4.45694 9.34023 2.75378L4.43312 0.424331C4.34085 0.380411 4.2407 0.355455 4.1386 0.350944C4.03651 0.346432 3.93454 0.362456 3.83875 0.398065C3.74296 0.433675 3.6553 0.488146 3.58094 0.558253C3.50658 0.62836 3.44705 0.712676 3.40588 0.806207L1.04206 6.15247C0.961789 6.33601 0.956835 6.54373 1.02827 6.73088C1.0997 6.91802 1.24179 7.06962 1.42394 7.15299C2.46264 7.64179 4.52859 8.61558 6.38833 9.51299C13.0941 12.7589 18.7802 12.5413 23.1298 5.47273Z" fill="url(#paint1_linear_confluence)"/>
      <defs>
        <linearGradient id="paint0_linear_confluence" x1="22.809" y1="24.5245" x2="7.78981" y2="15.8941" gradientUnits="userSpaceOnUse">
          <stop offset="0.18" stop-color="#0052CC"/>
          <stop offset="1" stop-color="#2684FF"/>
        </linearGradient>
        <linearGradient id="paint1_linear_confluence" x1="1.19099" y1="-1.45068" x2="16.214" y2="7.18354" gradientUnits="userSpaceOnUse">
          <stop offset="0.18" stop-color="#0052CC"/>
          <stop offset="1" stop-color="#2684FF"/>
        </linearGradient>
      </defs>
    </svg>
  </template>

  <template id="jira-icon">
    <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
      <path d="M22.9972 0H11.4318C11.4318 2.79206 13.7716 5.06468 16.6462 5.06468H18.7855V7.04508C18.7855 9.83711 21.1254 12.1098 24 12.1098V0.973977C24 0.422059 23.5655 0 22.9972 0Z" fill="#2684FF"/>
      <path d="M17.2814 5.58398H5.71585C5.71585 8.37605 8.05569 10.6486 10.9304 10.6486H13.0696V12.6615C13.0696 15.4536 15.4095 17.7263 18.2842 17.7263V6.55792C18.2842 6.0385 17.8496 5.58398 17.2814 5.58398Z" fill="url(#paint0_linear_jira)"/>
      <path d="M11.5655 11.2012H0C0 13.9932 2.33984 16.2658 5.21451 16.2658H7.35379V18.2462C7.35379 21.0383 9.69362 23.3109 12.5683 23.3109V12.1751C12.5683 11.6232 12.1004 11.2012 11.5655 11.2012Z" fill="url(#paint1_linear_jira)"/>
      <defs>
        <linearGradient id="paint0_linear_jira" x1="18.0381" y1="5.612" x2="13.2685" y2="10.6761" gradientUnits="userSpaceOnUse">
          <stop offset="0.176" stop-color="#0052CC"/>
          <stop offset="1" stop-color="#2684FF"/>
        </linearGradient>
        <linearGradient id="paint1_linear_jira" x1="12.6437" y1="11.2385" x2="7.1196" y2="16.7723" gradientUnits="userSpaceOnUse">
          <stop offset="0.176" stop-color="#0052CC"/>
          <stop offset="1" stop-color="#2684FF"/>
        </linearGradient>
      </defs>
    </svg>
  </template>

  <template id="loom-icon">
    <svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg" fill="none" stroke="#625DF5" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
      <circle cx="12" cy="12" r="10"></circle>
      <polygon points="10,8 16,12 10,16" fill="#625DF5" stroke="none"></polygon>
    </svg>
  </template>

  <template id="notion-icon">
    <svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
      <path fill-rule="evenodd" clip-rule="evenodd" d="M61.35 0.227l-55.333 4.087C1.553 4.7 0 7.617 0 11.113v60.66c0 2.723 0.967 5.053 3.3 8.167l13.007 16.913c2.137 2.723 4.08 3.307 8.16 3.113l64.257 -3.89c5.433 -0.387 6.99 -2.917 6.99 -7.193V20.64c0 -2.21 -0.873 -2.847 -3.443 -4.733L74.167 3.143c-4.273 -3.107 -6.02 -3.5 -12.817 -2.917zM25.92 19.523c-5.247 0.353 -6.437 0.433 -9.417 -1.99L8.927 11.507c-0.77 -0.78 -0.383 -1.753 1.557 -1.947l53.193 -3.887c4.467 -0.39 6.793 1.167 8.54 2.527l9.123 6.61c0.39 0.197 1.36 1.36 0.193 1.36l-54.933 3.307 -0.68 0.047zM19.803 88.3V30.367c0 -2.53 0.777 -3.697 3.103 -3.893L86 22.78c2.14 -0.193 3.107 1.167 3.107 3.693v57.547c0 2.53 -0.39 4.67 -3.883 4.863l-60.377 3.5c-3.493 0.193 -5.043 -0.97 -5.043 -4.083zm59.6 -54.827c0.387 1.75 0 3.5 -1.75 3.7l-2.91 0.577v42.773c-2.527 1.36 -4.853 2.137 -6.797 2.137 -3.107 0 -3.883 -0.973 -6.21 -3.887l-19.03 -29.94v28.967l6.02 1.363s0 3.5 -4.857 3.5l-13.39 0.777c-0.39 -0.78 0 -2.723 1.357 -3.11l3.497 -0.97v-38.3L30.48 40.667c-0.39 -1.75 0.58 -4.277 3.3 -4.473l14.367 -0.967 19.8 30.327v-26.83l-5.047 -0.58c-0.39 -2.143 1.163 -3.7 3.103 -3.89l13.4 -0.78z" fill="currentColor"/>
    </svg>
  </template>

  <template id="gmail-icon">
    <svg viewBox="52 42 88 66" xmlns="http://www.w3.org/2000/svg">
      <path fill="#4285f4" d="M58 108h14V74L52 59v43c0 3.32 2.69 6 6 6"/>
      <path fill="#34a853" d="M120 108h14c3.32 0 6-2.69 6-6V59l-20 15"/>
      <path fill="#fbbc04" d="M120 48v26l20-15v-8c0-7.42-8.47-11.65-14.4-7.2"/>
      <path fill="#ea4335" d="M72 74V48l24 18 24-18v26L96 92"/>
      <path fill="#c5221f" d="M52 51v8l20 15V48l-5.6-4.2c-5.94-4.45-14.4-.22-14.4 7.2"/>
    </svg>
  </template>

  <template id="gcal-icon">
    <svg viewBox="0 0 200 200" xmlns="http://www.w3.org/2000/svg">
      <g transform="translate(3.75 3.75)">
        <path fill="#FFFFFF" d="M148.882,43.618l-47.368-5.263l-57.895,5.263L38.355,96.25l5.263,52.632l52.632,6.579l52.632-6.579l5.263-53.947L148.882,43.618z"/>
        <path fill="#1A73E8" d="M65.211,125.276c-3.934-2.658-6.658-6.539-8.145-11.671l9.132-3.763c0.829,3.158,2.276,5.605,4.342,7.342c2.053,1.737,4.553,2.592,7.474,2.592c2.987,0,5.553-0.908,7.697-2.724s3.224-4.132,3.224-6.934c0-2.868-1.132-5.211-3.395-7.026s-5.105-2.724-8.5-2.724h-5.276v-9.039H76.5c2.921,0,5.382-0.789,7.382-2.368c2-1.579,3-3.737,3-6.487c0-2.447-0.895-4.395-2.684-5.855s-4.053-2.197-6.803-2.197c-2.684,0-4.816,0.711-6.395,2.145s-2.724,3.197-3.447,5.276l-9.039-3.763c1.197-3.395,3.395-6.395,6.618-8.987c3.224-2.592,7.342-3.895,12.342-3.895c3.697,0,7.026,0.711,9.974,2.145c2.947,1.434,5.263,3.421,6.934,5.947c1.671,2.539,2.5,5.382,2.5,8.539c0,3.224-0.776,5.947-2.329,8.184c-1.553,2.237-3.461,3.947-5.724,5.145v0.539c2.987,1.25,5.421,3.158,7.342,5.724c1.908,2.566,2.868,5.632,2.868,9.211s-0.908,6.776-2.724,9.579c-1.816,2.803-4.329,5.013-7.513,6.618c-3.197,1.605-6.789,2.421-10.776,2.421C73.408,129.263,69.145,127.934,65.211,125.276z"/>
        <path fill="#1A73E8" d="M121.25,79.961l-9.974,7.25l-5.013-7.605l17.987-12.974h6.895v61.197h-9.895L121.25,79.961z"/>
        <path fill="#EA4335" d="M148.882,196.25l47.368-47.368l-23.684-10.526l-23.684,10.526l-10.526,23.684L148.882,196.25z"/>
        <path fill="#34A853" d="M33.092,172.566l10.526,23.684h105.263v-47.368H43.618L33.092,172.566z"/>
        <path fill="#4285F4" d="M12.039-3.75C3.316-3.75-3.75,3.316-3.75,12.039v136.842l23.684,10.526l23.684-10.526V43.618h105.263l10.526-23.684L148.882-3.75H12.039z"/>
        <path fill="#188038" d="M-3.75,148.882v31.579c0,8.724,7.066,15.789,15.789,15.789h31.579v-47.368H-3.75z"/>
        <path fill="#FBBC04" d="M148.882,43.618v105.263h47.368V43.618l-23.684-10.526L148.882,43.618z"/>
        <path fill="#1967D2" d="M196.25,43.618V12.039c0-8.724-7.066-15.789-15.789-15.789h-31.579v47.368H196.25z"/>
      </g>
    </svg>
  </template>

  <template id="gdrive-icon">
    <svg viewBox="0 0 87.3 78" xmlns="http://www.w3.org/2000/svg">
      <path d="m6.6 66.85 3.85 6.65c.8 1.4 1.95 2.5 3.3 3.3l13.75-23.8h-27.5c0 1.55.4 3.1 1.2 4.5z" fill="#0066da"/>
      <path d="m43.65 25-13.75-23.8c-1.35.8-2.5 1.9-3.3 3.3l-25.4 44a9.06 9.06 0 0 0 -1.2 4.5h27.5z" fill="#00ac47"/>
      <path d="m73.55 76.8c1.35-.8 2.5-1.9 3.3-3.3l1.6-2.75 7.65-13.25c.8-1.4 1.2-2.95 1.2-4.5h-27.502l5.852 11.5z" fill="#ea4335"/>
      <path d="m43.65 25 13.75-23.8c-1.35-.8-2.9-1.2-4.5-1.2h-18.5c-1.6 0-3.15.45-4.5 1.2z" fill="#00832d"/>
      <path d="m59.8 53h-32.3l-13.75 23.8c1.35.8 2.9 1.2 4.5 1.2h50.8c1.6 0 3.15-.45 4.5-1.2z" fill="#2684fc"/>
      <path d="m73.4 26.5-12.7-22c-.8-1.4-1.95-2.5-3.3-3.3l-13.75 23.8 16.15 28h27.45c0-1.55-.4-3.1-1.2-4.5z" fill="#ffba00"/>
    </svg>
  </template>

  <template id="linkedin-icon">
    <svg viewBox="0 0 72 72" xmlns="http://www.w3.org/2000/svg">
      <g fill="none" fill-rule="evenodd">
        <path fill="#007EBB" d="M8,72 L64,72 C68.418278,72 72,68.418278 72,64 L72,8 C72,3.581722 68.418278,-8.11624501e-16 64,0 L8,0 C3.581722,8.11624501e-16 -5.41083001e-16,3.581722 0,8 L0,64 C5.41083001e-16,68.418278 3.581722,72 8,72 Z"/>
        <path fill="#FFF" d="M62,62 L51.315625,62 L51.315625,43.8021149 C51.315625,38.8127542 49.4197917,36.0245323 45.4707031,36.0245323 C41.1746094,36.0245323 38.9300781,38.9261103 38.9300781,43.8021149 L38.9300781,62 L28.6333333,62 L28.6333333,27.3333333 L38.9300781,27.3333333 L38.9300781,32.0029283 C38.9300781,32.0029283 42.0260417,26.2742151 49.3825521,26.2742151 C56.7356771,26.2742151 62,30.7644705 62,40.051212 L62,62 Z M16.349349,22.7940133 C12.8420573,22.7940133 10,19.9296567 10,16.3970067 C10,12.8643566 12.8420573,10 16.349349,10 C19.8566406,10 22.6970052,12.8643566 22.6970052,16.3970067 C22.6970052,19.9296567 19.8566406,22.7940133 16.349349,22.7940133 Z M11.0325521,62 L21.769401,62 L21.769401,27.3333333 L11.0325521,27.3333333 L11.0325521,62 Z"/>
      </g>
    </svg>
  </template>

  <template id="github-icon">
    <svg viewBox="0 0 1024 1024" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path fill-rule="evenodd" clip-rule="evenodd" d="M8 0C3.58 0 0 3.58 0 8C0 11.54 2.29 14.53 5.47 15.59C5.87 15.66 6.02 15.42 6.02 15.21C6.02 15.02 6.01 14.39 6.01 13.72C4 14.09 3.48 13.23 3.32 12.78C3.23 12.55 2.84 11.84 2.5 11.65C2.22 11.5 1.82 11.13 2.49 11.12C3.12 11.11 3.57 11.7 3.72 11.94C4.44 13.15 5.59 12.81 6.05 12.6C6.12 12.08 6.33 11.73 6.56 11.53C4.78 11.33 2.92 10.64 2.92 7.58C2.92 6.71 3.23 5.99 3.74 5.43C3.66 5.23 3.38 4.41 3.82 3.31C3.82 3.31 4.49 3.1 6.02 4.13C6.66 3.95 7.34 3.86 8.02 3.86C8.7 3.86 9.38 3.95 10.02 4.13C11.55 3.09 12.22 3.31 12.22 3.31C12.66 4.41 12.38 5.23 12.3 5.43C12.81 5.99 13.12 6.7 13.12 7.58C13.12 10.65 11.25 11.33 9.47 11.53C9.76 11.78 10.01 12.26 10.01 13.01C10.01 14.08 10 14.94 10 15.21C10 15.42 10.15 15.67 10.55 15.59C13.71 14.53 16 11.53 16 8C16 3.58 12.42 0 8 0Z" transform="scale(64)" fill="currentColor"/>
    </svg>
  </template>

  <template id="linear-icon">
    <svg viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
      <path fill="currentColor" d="M1.22541 61.5228c-.2225-.9485.90748-1.5459 1.59638-.857L39.3342 97.1782c.6889.6889.0915 1.8189-.857 1.5964C20.0515 94.4522 5.54779 79.9485 1.22541 61.5228ZM.00189135 46.8891c-.01764375.2833.08887215.5599.28957165.7606L52.3503 99.7085c.2007.2007.4773.3075.7606.2896 2.3692-.1476 4.6938-.46 6.9624-.9259.7645-.157 1.0301-1.0963.4782-1.6481L2.57595 39.4485c-.55186-.5519-1.49117-.2863-1.648174.4782-.465915 2.2686-.77832 4.5932-.92588465 6.9624ZM4.21093 29.7054c-.16649.3738-.08169.8106.20765 1.1l64.77602 64.776c.2894.2894.7262.3742 1.1.2077 1.7861-.7956 3.5171-1.6927 5.1855-2.684.5521-.328.6373-1.0867.1832-1.5407L8.43566 24.3367c-.45409-.4541-1.21271-.3689-1.54074.1832-.99132 1.6684-1.88843 3.3994-2.68399 5.1855ZM12.6587 18.074c-.3701-.3701-.393-.9637-.0443-1.3541C21.7795 6.45931 35.1114 0 49.9519 0 77.5927 0 100 22.4073 100 50.0481c0 14.8405-6.4593 28.1724-16.7199 37.3375-.3903.3487-.984.3258-1.3542-.0443L12.6587 18.074Z"/>
    </svg>
  </template>

  <template id="amplitude-icon">
    <svg viewBox="0 0 1518 1580" xmlns="http://www.w3.org/2000/svg">
      <path fill="#1e61f0" d="m685.5 389.6q8 17.2 15 34.8q7 17.6 13 35.6q6 18 10.9 36.3c18.7 58.4 38.6 130.8 60 215.3c-80.9-1.3-162.6-2.3-241.9-3.1l-40.1-0.6c45.3-184.4 100.6-324.3 141-357.3q1.2-0.9 2.5-1.6q1.3-0.6 2.7-1.1q1.4-0.5 2.9-0.8q1.4-0.3 2.9-0.3q2.2 0.1 4.2 0.8q2.1 0.7 4 1.8q1.9 1.2 3.4 2.8q1.5 1.5 2.7 3.4q8.9 16.8 16.8 34z"/>
      <path fill="#1e61f0" fill-rule="evenodd" d="m1517.3 789.8c0 436.1-339.7 789.7-758.7 789.7c-418.9 0-758.6-353.5-758.6-789.7c0-436.2 339.7-789.8 758.6-789.8c419 0 758.7 353.6 758.7 789.8zm-205.5 5.6c2.2-3.3 4-6.8 5.2-10.6c1.2-3.7 2-7.6 2.1-11.5c0.2-3.9-0.1-7.9-1-11.7c-0.9-3.8-2.2-7.5-4.1-10.9c-1.9-3.4-4.2-6.5-7-9.2c-2.7-2.8-5.9-5.1-9.3-7c-3.4-1.9-7-3.3-10.8-4.1h-1.7q-0.8-0.1-1.6-0.2q-0.7-0.1-1.5-0.2q-0.7 0-1.5-0.1q-0.8 0-1.5 0l-5.4-0.5c-127-9.6-257.7-13.4-380.4-16l-0.2-0.9c-59.7-233.1-134.2-471.4-234.7-471.4c-93.7 0.3-178.3 157.1-251.1 465.4c-51.4-0.6-98.5-1.3-142.8-2.1h-6.8q-2-0.1-4.1-0.1q-2 0.1-4 0.2q-2.1 0-4.1 0.2q-2.1 0.2-4.1 0.4c-12.4 2.8-23.4 9.8-31.2 19.7c-7.9 10-12 22.4-11.8 35.1c0.2 12.7 4.8 24.9 12.9 34.6c8.2 9.7 19.4 16.3 31.9 18.7l0.5 0.6h139.4c-13 61.7-24.3 122.7-33.8 181.5l-4.2 25.8v1.3c0 3.8 0.6 7.7 1.8 11.3c1.1 3.7 2.9 7.1 5.2 10.2c2.2 3.1 5 5.9 8.1 8.1c3.1 2.3 6.5 4 10.2 5.2c3.6 1 7.4 1.5 11.2 1.3c3.8-0.2 7.5-1 11-2.4c3.5-1.3 6.8-3.3 9.6-5.8c2.9-2.4 5.4-5.3 7.3-8.6l1.1 0.9l68.6-228.7h330.7c25.2 99.4 51.5 202.1 86.1 298.4c18.6 51.5 61.9 172.1 134.4 172.7h0.8c112.2 0 155.9-188.6 184.8-313.5c6.3-26.9 11.6-50.1 16.7-67.1l2-7.1q0.2-0.6 0.4-1.2q0.1-0.7 0.2-1.3q0.1-0.7 0.1-1.3q0.1-0.7 0.1-1.3c0-2.1-0.4-4.1-1.1-6c-0.7-2-1.7-3.7-3-5.3c-1.3-1.6-2.8-3-4.6-4c-1.7-1.1-3.6-1.8-5.6-2.2c-2-0.4-4-0.4-6 0c-1.9 0.4-3.8 1.1-5.6 2.1c-1.7 1-3.2 2.3-4.5 3.8c-1.3 1.6-2.3 3.3-3 5.2l-2.4 7c-9.6 27.4-18.3 53.4-26.2 76.4l-0.6 1.8c-48.5 143.1-70.6 208.4-114.1 208.4h-2.9c-55.5 0-107.8-235.3-127.5-323.9c-3.5-15.3-6.6-29.4-9.6-41.8h359.6q2.4 0 4.8-0.3q2.4-0.3 4.8-0.9q2.3-0.6 4.6-1.5q2.3-0.9 4.4-2.1q0.2-0.1 0.4-0.2q0.2-0.1 0.4-0.3q0.3-0.1 0.5-0.2q0.2-0.1 0.4-0.3l1.8-1.1l0.8-0.6c0.9-0.6 1.7-1.3 2.5-1.9l0.2-0.2c3-2.6 5.6-5.5 7.8-8.7z"/>
    </svg>
  </template>

  <!-- ============================================================
       BRIEF DATA
       This JSON blob is the ONLY thing the LLM produces.
       Everything else (HTML, CSS, JS, fonts, paintings) is static.
       ============================================================ -->
  <script id="brief-data" type="application/json">
  __HIVE_BRIEF_JSON__
  </script>



  <!-- Loaded before app.js so renderBrief() can call window.renderLookingAhead.
       File only present when the cliaMorningBriefLookingAheadEnabled flag is on. -->
  <script src="looking-ahead.js"></script>
  <!-- Loaded before app.js so init() can call window.renderBriefFeedback.
       File only present when the contextBuilderMorningBriefFeedbackEnabled flag is on. -->
  <script src="feedback.js"></script>
  <script src="app.js"></script>
</body>
</html>
"""#
    static let briefCSS = #"""
/* ============================================================
   Morning Brief Template — v2 base with latest visual refresh.
   Sections remain aligned with clia-brief spec.yaml structure.
   ============================================================ */

/* ── Exposure Font ────────────────────────────────────── */

@font-face {
  font-family: 'Exposure VAR';
  src: url('fonts/Exposure-400.woff2') format('woff2');
  font-weight: 400;
  font-style: normal;
  font-display: swap;
}

@font-face {
  font-family: 'Exposure VAR';
  src: url('fonts/Exposure-500.woff2') format('woff2');
  font-weight: 500;
  font-style: normal;
  font-display: swap;
}

@font-face {
  font-family: 'Exposure VAR';
  src: url('fonts/Exposure-550.woff2') format('woff2');
  font-weight: 550;
  font-style: normal;
  font-display: swap;
}

@font-face {
  font-family: 'Exposure VAR';
  src: url('fonts/Exposure-550-Italic.woff2') format('woff2');
  font-weight: 550;
  font-style: italic;
  font-display: swap;
}

@font-face {
  font-family: 'Exposure VAR';
  src: url('fonts/Exposure-600.woff2') format('woff2');
  font-weight: 600;
  font-style: normal;
  font-display: swap;
}


/* ── Custom Properties ─────────────────────────────────── */

:root {
  --page-bg: #F7F7F7;
  --yellow: #FFE500;
  --text: #000;
  --text-body: rgba(60, 60, 67, 0.6);
  --text-muted: rgba(0, 0, 0, 0.3);
  --content-max: 1160px;
  --page-pad: clamp(16px, 6vw, 90px);
  --content-pad: clamp(20px, 5vw, 60px);
  --font-display: 'Exposure VAR', Georgia, 'Times New Roman', serif;
  --font-body: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'SF Pro Display', 'Segoe UI', sans-serif;
  --font-mono: 'SF Mono', 'Fira Code', 'Fira Mono', 'Roboto Mono', 'Courier New', monospace;

  /* One column width for hero + body. Default painting = 1160×600; wide+short eases display
     aspect only — rail width always uses 1160/600 so column width stays stable. */
  --painting-aspect-w: 1160;
  --painting-aspect-h: 600;
  --painting-aspect-h-rail: 600;
  --available-by-width: calc(100vw - 2 * var(--page-pad));
  /* Primary line from 1000vh; floor line matches at 800vh and eases more gently 800→600. */
  --painting-max-height: clamp(
    300px,
    max(
      min(600px, calc(600px + (100vh - 1000px) * 6 / 11)),
      calc(440px + (100vh - 600px) * 14 / 55)
    ),
    600px
  );
  --painting-inner-width: min(
    var(--content-max),
    calc(
      var(--painting-max-height) * var(--painting-aspect-w) / var(--painting-aspect-h-rail)
    ),
    max(0px, calc(var(--available-by-width) - 2 * var(--content-pad)))
  );
  --brief-rail-width: calc(var(--painting-inner-width) + 2 * var(--content-pad));

  /* Space from hero subcopy (blurb + caption) to first body section: full 48px until 720px
     height, then eases down toward 600px. */
  --content-pad-after-hero: clamp(
    24px,
    calc(48px + (100vh - 720px) * 0.15),
    48px
  );

  /* Dia mark: 25.5×24 at 800px+ viewport height → 16×16 at 600px (linear in between). */
  --greeting-logo-w: clamp(
    16px,
    calc(25.5px + (100vh - 800px) * 0.0475),
    25.5px
  );
  --greeting-logo-h: clamp(
    16px,
    calc(24px + (100vh - 800px) * 0.04),
    24px
  );
}

@supports (height: 1dvh) {
  :root {
    --painting-max-height: clamp(
      300px,
      max(
        min(600px, calc(600px + (100dvh - 1000px) * 6 / 11)),
        calc(440px + (100dvh - 600px) * 14 / 55)
      ),
      600px
    );
    --content-pad-after-hero: clamp(
      24px,
      calc(48px + (100dvh - 720px) * 0.15),
      48px
    );
    --greeting-logo-w: clamp(
      16px,
      calc(25.5px + (100dvh - 800px) * 0.0475),
      25.5px
    );
    --greeting-logo-h: clamp(
      16px,
      calc(24px + (100dvh - 800px) * 0.04),
      24px
    );
  }
}


/* ── Reset & Base ─────────────────────────────────────── */

*, *::before, *::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

html {
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-rendering: optimizeLegibility;
}

body {
  font-family: var(--font-body);
  font-size: 16px;
  line-height: 1.6;
  color: var(--text);
  background: var(--page-bg);
  overflow-x: hidden;
  text-wrap: pretty;
}

u {
  text-decoration-thickness: 1px;
  text-underline-offset: 2px;
}

strong {
  font-weight: 600;
}


/* ── Page Container ───────────────────────────────────── */

.page {
  position: relative;
  min-height: 100vh;
  padding-left: var(--page-pad);
  padding-right: var(--page-pad);
}


/* ── Brief column (hero + main share one width = painting inner + pads) ── */

.brief-scale {
  width: min(100%, var(--brief-rail-width));
  max-width: 100%;
  margin-inline: auto;
  container-type: inline-size;
  container-name: brief;
}


/* ── Greeting ─────────────────────────────────────────── */

.greeting {
  text-align: center;
  font-family: var(--font-body);
  font-size: 14px;
  font-weight: 400;
  letter-spacing: 0.35em;
  color: var(--text);
  padding: 28px 24px 0;
}

.greeting svg {
  display: inline-block;
  vertical-align: middle;
  width: var(--greeting-logo-w, 25.5px);
  height: var(--greeting-logo-h, 24px);
}


/* ── Hero ─────────────────────────────────────────────── */

.hero {
  position: relative;
  width: 100%;
  margin: 0;
  padding: 24px var(--content-pad) 0;
}


/* ── Hero Edge Labels (Date + Time) ───────────────────── */

.hero-edge {
  position: absolute;
  z-index: 3;
  font-family: var(--font-display);
  font-style: italic;
  font-size: clamp(1.25rem, 5cqw, 4.5rem);
  color: var(--text);
  line-height: 1;
  white-space: nowrap;
  writing-mode: vertical-lr;
}

.hero-date {
  left: clamp(-3.75rem, -5cqw, 0px);
  top: 50%;
  transform: rotate(180deg) translateY(50%);
}

.hero-time {
  right: clamp(-3.75rem, -5cqw, 0px);
  top: 50%;
  transform: translateY(-50%);
  font-feature-settings: "onum", "tnum", "zero";
}


/* ── Painting Frame ───────────────────────────────────── */

.painting-frame {
  position: relative;
  width: 100%;
  aspect-ratio: var(--painting-aspect-w) / var(--painting-aspect-h);
  overflow: hidden;
  background: #e0ddd8;
}

.painting-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  opacity: 0;
  transition: opacity 1.2s ease;
}

.painting-img.loaded {
  opacity: 1;
}

.painting-overlay {
  position: absolute;
  inset: 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  pointer-events: none;
}

.hero-the {
  display: block;
  font-family: var(--font-display);
  font-style: italic;
  font-weight: 500;
  /* Tracks .brief-scale width (cqw) so it shrinks/grows with the rail. */
  font-size: clamp(1.65rem, 6cqw, 4.85rem);
  color: var(--yellow);
  line-height: 1;
  text-shadow:
    0 2px 20px rgba(0, 0, 0, 0.3),
    0 0 60px rgba(0, 0, 0, 0.15);
  margin-bottom: 0em;
}

.hero-day {
  font-family: var(--font-display);
  font-weight: 550;
  font-size: clamp(2.1rem, 10.5cqw, 8.25rem);
  color: var(--yellow);
  line-height: 0.95;
  letter-spacing: -0.01em;
  text-shadow:
    0 2px 30px rgba(0, 0, 0, 0.35),
    0 0 80px rgba(0, 0, 0, 0.2);
  white-space: nowrap;
}


/* ── Painting Caption ─────────────────────────────────── */

.painting-caption {
  font-family: var(--font-mono);
  font-size: clamp(8px, calc(6px + 0.45cqw), 10px);
  font-weight: 400;
  letter-spacing: 0.02em;
  color: rgba(0, 0, 0, 0.5);
  text-align: right;
  line-height: 1.5;
  margin: 0;
  opacity: 0;
  transition: opacity 0.8s ease 0.3s;
}

.painting-caption.visible {
  opacity: 1;
}


/* ── Hero Sub (blurb + caption row) ──────────────────── */

.hero-sub {
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  column-gap: 1.5rem;
  align-items: baseline;
  padding-top: 10px;
}

.brief-blurb {
  grid-column: 1 / 8;
  font-family: var(--font-display);
  font-style: italic;
  font-weight: 400;
  font-size: clamp(0.8rem, calc(0.6rem + 0.65cqw), 1rem);
  line-height: 1.5;
  text-wrap: pretty;
  color: var(--text-body);
  margin: 0;
}

.hero-sub .painting-caption {
  grid-column: 8 / -1;
}


/* ── Content Area ─────────────────────────────────────── */

.content {
  width: 100%;
  max-width: calc(var(--content-max) + var(--content-pad) * 2);
  margin: 0 auto;
  padding: var(--content-pad-after-hero) var(--content-pad) clamp(48px, 12cqw, 120px);
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  column-gap: 1.5rem;
  row-gap: clamp(32px, 7cqw, 64px);
  font-size: clamp(14px, calc(8px + 0.95cqw), 18px);
}


/* ── Brief Sections ───────────────────────────────────── */

/* Each container at `grid-column: 1 / -1` re-declares the outer 12-column
   track + gap so child `grid-column` placements resolve to identical
   x-positions across all nested containers. */
.brief-section {
  grid-column: 1 / -1;
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  column-gap: 1.5rem;
  row-gap: 20px;
}


/* ── Boxed Section ───────────────────────────────────── */

.brief-section--boxed {
  background: rgba(0, 0, 0, 0.025);
  border-radius: 12px;
  padding: clamp(20px, 3vw, 32px);
}

.push-section.brief-section--boxed,
.proactive-section.brief-section--boxed {
  position: relative;
  padding-left: 0;
  padding-right: 0;
}


/* ── Push Section ────────────────────────────────────── */

.push-section {
  position: relative;
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  column-gap: 1.5rem;
  row-gap: 0;
}

.push-section .push-title {
  grid-column: 1 / 6;
  grid-row: 1;
  align-self: start;
  padding-top: 0.05em;
  padding-left: clamp(20px, 3vw, 32px);
}

.push-section .section-body {
  grid-column: 1 / -1;
  display: contents;
}

.push-shell {
  display: contents;
}

.push-body {
  grid-column: 6 / -1;
  grid-row: 1;
  padding-right: clamp(20px, 3vw, 32px);
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.push-topic {
  font-size: 1.1em;
  font-weight: 600;
  line-height: 1.5;
}

.push-text {
  font-size: 0.95em;
  line-height: 1.7;
  color: var(--text-body);
  min-height: calc(3 * 1.7em);
  min-height: calc(3lh);
}

.push-badge {
  position: absolute;
  bottom: -20px;
  left: 24px;
  display: block;
  transform: rotate(-5deg);
  transition: transform 0.3s ease 0.15s, filter 0.3s ease 0.15s;
  text-decoration: none;
  z-index: 1;
}

.push-badge:hover {
  transform: rotate(-12deg);
  transition: transform 0.2s ease, filter 0.2s ease;
  filter: drop-shadow(0 2px 1px rgba(0, 0, 0, 0.10));
}

.push-star,
.prep-star {
  position: relative;
  overflow: hidden;
}

.push-star {
  width: 7.5rem;
  height: 7.5rem;
  background: var(--yellow);
  clip-path: polygon(
    50% 0%, 60.9% 9.4%, 75% 6.7%, 79.7% 20.3%,
    93.3% 25%, 90.6% 39.1%, 100% 50%, 90.6% 60.9%,
    93.3% 75%, 79.7% 79.7%, 75% 93.3%, 60.9% 90.6%,
    50% 100%, 39.1% 90.6%, 25% 93.3%, 20.3% 79.7%,
    6.7% 75%, 9.4% 60.9%, 0% 50%, 9.4% 39.1%,
    6.7% 25%, 20.3% 20.3%, 25% 6.7%, 39.1% 9.4%
  );
  display: flex;
  align-items: center;
  justify-content: center;
}

.push-star::before,
.prep-star::before {
  content: '';
  position: absolute;
  top: -20%;
  left: -120%;
  width: 110%;
  height: 140%;
  background: linear-gradient(
    105deg,
    transparent 20%,
    rgba(255, 255, 255, 0.1) 30%,
    rgba(255, 200, 220, 0.2) 38%,
    rgba(200, 220, 255, 0.25) 46%,
    rgba(220, 255, 220, 0.2) 54%,
    rgba(255, 240, 200, 0.15) 62%,
    rgba(255, 255, 255, 0.1) 70%,
    transparent 80%
  );
  transform: skewX(-15deg);
  opacity: 0;
  transition: opacity 0.2s ease;
  pointer-events: none;
  z-index: 1;
}

.push-badge:hover .push-star::before,
.prep-badge:hover .prep-star::before {
  opacity: 1;
  animation: prismatic-shine 0.6s ease-out forwards;
}

@keyframes prismatic-shine {
  0% { left: -120%; }
  100% { left: 140%; }
}

.push-star-text {
  font-family: var(--font-display);
  font-style: italic;
  font-size: 1.3em;
  color: #000;
  transform: rotate(-5deg);
  text-align: center;
  line-height: 1.2;
  margin-top: -0.125rem;
}

.star-arrow {
  font-family: "SF Pro", -apple-system, system-ui, sans-serif;
  font-style: normal;
  font-size: 0.8em;
  opacity: 0.6;
  transition: opacity 0.2s ease;
}

.push-badge:hover .star-arrow,
.prep-badge:hover .star-arrow {
  opacity: 1;
}

/* Floating tooltips for push / prep starbursts (positioned in app.js) */
.star-tooltip-popover {
  position: fixed;
  z-index: 10000;
  max-width: min(300px, calc(100vw - 24px));
  padding: 10px 14px;
  border-radius: 10px;
  font-family: var(--font-body);
  text-align: left;
  background: #fffefb;
  color: var(--text);
  border: 1px solid rgba(0, 0, 0, 0.07);
  box-shadow:
    0 12px 40px rgba(0, 0, 0, 0.07),
    0 2px 8px rgba(0, 0, 0, 0.04);
  opacity: 0;
  pointer-events: none;
  transform: translateY(6px) scale(0.9);
  transform-origin: center bottom;
  transition:
    opacity 0.22s ease,
    transform 0.22s cubic-bezier(0.22, 1, 0.36, 1);
}

.star-tooltip-popover--visible {
  opacity: 1;
  transform: translateY(0) scale(1);
}

.star-tooltip-popover--below {
  transform-origin: center top;
}

.star-tooltip-popover__head {
  display: flex;
  align-items: center;
  gap: 5px;
  margin: 0 0 6px;
}

.star-tooltip-popover__icon {
  flex-shrink: 0;
  display: flex;
  align-items: center;
}

.star-tooltip-popover__icon svg {
  display: block;
  width: 16px;
  height: 14px;
  opacity: 0.88;
}

.star-tooltip-popover__head-text {
  flex: 1;
  min-width: 0;
  font-family: var(--font-display);
  font-style: normal;
  font-weight: 550;
  font-size: 14px;
  line-height: 1.35;
  color: var(--text);
}

.star-tooltip-popover__body {
  margin: 0;
}

.star-tooltip-popover__body-msg {
  font-weight: 400;
  font-size: 12px;
  line-height: 1.45;
  word-wrap: break-word;
  color: var(--text-body);
}

.star-tooltip-popover__body--prompt .star-tooltip-popover__body-msg {
  font-style: italic;
  padding-left: 0.35em;
}

.star-tooltip-popover__body--prompt .star-tooltip-popover__body-msg::before {
  content: "\201C";
  float: left;
  font-style: normal;
  margin-left: -0.42em;
  margin-right: 0.1em;
  line-height: 1.45;
}

.star-tooltip-popover__body--prompt .star-tooltip-popover__body-msg::after {
  content: "\201D";
  font-style: normal;
}

.star-tooltip-popover__body[hidden] {
  display: none;
}


/* ── Proactive Work Section ──────────────────────────── */

.proactive-section {
  position: relative;
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  column-gap: 1.5rem;
  row-gap: 0;
}

.proactive-section .section-title {
  grid-column: 1 / 6;
  grid-row: 1;
  align-self: start;
  padding-top: 0.05em;
  padding-left: clamp(20px, 3vw, 32px);
}

.proactive-section .section-body {
  grid-column: 1 / -1;
  display: contents;
}

.proactive-shell {
  display: contents;
}

.proactive-body {
  grid-column: 6 / -1;
  grid-row: 1;
  padding-right: clamp(20px, 3vw, 32px);
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.proactive-title {
  font-size: 1.1em;
  font-weight: 600;
  line-height: 1.5;
}

.proactive-reasoning {
  font-size: 0.95em;
  line-height: 1.7;
  color: var(--text-body);
}

/* ── Inline Section (title in left column) ────────────── */

.brief-section--inline {
  row-gap: 0;
}

/* Title sits on its own row above the list (consistent with the Projects
   section), so the left-rail ranked numbers never overlap the heading. */
.brief-section--inline .section-title {
  grid-column: 1 / -1;
  align-self: start;
}

.brief-section--inline .section-body {
  grid-column: 1 / -1;
  margin-top: 0.4em;
}


/* ── Section Title ────────────────────────────────────── */

.section-title {
  grid-column: 1 / -1;
  font-family: var(--font-display);
  font-style: italic;
  font-weight: 400;
  font-size: 1.47em;
  color: var(--text);
  opacity: 0.85;
  /* Align with the content column's left indent (`.item-num`, `.schedule-list`,
     `.push-title`). Reset to 0 in the single-column mobile layout. */
  padding-left: clamp(20px, 3vw, 32px);
}


/* ── Schedule Card ────────────────────────────────────── */

.schedule-card {
  grid-column: 1 / -1;
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  column-gap: 1.5rem;
  align-items: start;
}

.schedule-list {
  grid-column: 1 / 6;
  display: flex;
  flex-direction: column;
  gap: 0;
  padding-left: clamp(20px, 3vw, 32px);
}

.schedule-item {
  display: flex;
  align-items: baseline;
  gap: 12px;
  font-size: 1.07em;
  line-height: 2.4;
  padding: 0 8px;
  margin: 0 -8px;
  border-radius: 6px;
  transition: background 0.15s ease;
}

.schedule-item[data-index] {
  cursor: default;
}

.schedule-item[data-index]:hover,
.schedule-item--active {
  background: rgba(0, 0, 0, 0.04);
}

.schedule-item[data-index]:hover .schedule-time,
.schedule-item--active .schedule-time {
  color: var(--text-body);
}

.schedule-item--break {
  opacity: 0.5;
}

.schedule-item--break:hover {
  opacity: 0.75;
}

.schedule-time {
  font-family: var(--font-mono);
  font-weight: 400;
  font-size: 0.9em;
  color: var(--text-muted);
  min-width: 4em;
  letter-spacing: -0.01em;
}

.schedule-event {
  font-weight: 600;
}

.schedule-divider {
  display: none;
}

.schedule-right {
  grid-column: 6 / -1;
  display: flex;
  flex-direction: column;
  gap: 24px;
}

.schedule-summary {
  position: relative;
  font-size: 1em;
  line-height: 1.8;
  min-height: 170px;
  display: grid;
}

.schedule-summary strong {
  display: block;
  font-size: 1.15em;
  font-weight: 700;
  line-height: 1.4;
  margin-bottom: 6px;
}

.schedule-summary p:not(:first-child) {
  color: var(--text-body);
}

.summary-panel {
  grid-column: 1;
  grid-row: 1;
  display: flex;
  flex-direction: column;
  gap: 12px;
  opacity: 0;
  transition: opacity 0.2s ease;
}

/* Detail panel pins to the top of the grid cell so the prep-me button hangs
   off the meeting card rather than the (much taller) lineup. */
.summary-panel--detail {
  align-self: start;
}

.summary-panel--visible {
  opacity: 1;
  pointer-events: auto;
}

.summary-panel:not(.summary-panel--visible) {
  pointer-events: none;
}

.brief-section--schedule > .section-title:not(.lineup-title) {
  grid-column: 1 / 6;
}

.lineup-title {
  grid-column: 6 / -1;
  grid-row: 1;
  padding-left: 0;
  margin: 0;
  transition: opacity 0.2s ease;
}

.lineup-title--faded {
  opacity: 0;
}

.people-list {
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.people-entry {
  display: flex;
  align-items: flex-start;
  gap: 12px;
}

.people-entry-avatar-wrap {
  flex-shrink: 0;
  width: 36px;
  height: 36px;
  border-radius: 50%;
  overflow: hidden;
  background: rgba(0, 0, 0, 0.05);
}

.people-entry-avatar {
  width: 100%;
  height: 100%;
  object-fit: cover;
  display: block;
}

.people-entry-avatar-placeholder {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75em;
  font-weight: 600;
  color: var(--text-muted);
}

.people-entry-content {
  flex: 1;
  min-width: 0;
  font-size: 0.92em;
  line-height: 1.45;
}

.people-entry-name {
  font-weight: 700;
  color: var(--text-body);
  margin-bottom: 2px;
}

.people-entry-blurb {
  color: var(--text-muted);
}

.people-entry-social {
  margin-top: 4px;
  font-size: 0.85em;
  color: var(--text-muted);
}

.people-entry-social-link {
  color: var(--text-body);
  text-decoration: none;
  border-bottom: 1px dotted rgba(0, 0, 0, 0.25);
  transition: opacity 0.15s ease;
}

.people-entry-social-link:hover {
  opacity: 0.7;
}

.people-entry-social-sep {
  opacity: 0.4;
}


/* ── Prep Badge ───────────────────────────────────────── */

.prep-badge {
  position: relative;
  align-self: flex-end;
  transform: rotate(5deg);
  border: 0;
  padding: 0;
  background: transparent;
  filter: drop-shadow(0 1px 3px rgba(0, 0, 0, 0.1));
  transition: transform 0.3s ease 0.15s, opacity 0.2s ease, filter 0.3s ease 0.15s;
  cursor: pointer;
}

.prep-badge.hidden {
  opacity: 0;
  pointer-events: none;
}

.prep-badge:hover {
  transform: rotate(12deg);
  transition: transform 0.2s ease, opacity 0.2s ease, filter 0.2s ease;
  filter: drop-shadow(0 2px 1.5px rgba(0, 0, 0, 0.10));
}

.prep-star {
  width: 120px;
  height: 120px;
  background: var(--yellow);
  clip-path: polygon(
    50% 0%, 60.9% 9.4%, 75% 6.7%, 79.7% 20.3%,
    93.3% 25%, 90.6% 39.1%, 100% 50%, 90.6% 60.9%,
    93.3% 75%, 79.7% 79.7%, 75% 93.3%, 60.9% 90.6%,
    50% 100%, 39.1% 90.6%, 25% 93.3%, 20.3% 79.7%,
    6.7% 75%, 9.4% 60.9%, 0% 50%, 9.4% 39.1%,
    6.7% 25%, 20.3% 20.3%, 25% 6.7%, 39.1% 9.4%
  );
  display: flex;
  align-items: center;
  justify-content: center;
}

.prep-text {
  font-family: var(--font-display);
  font-style: italic;
  font-size: 1.2em;
  color: var(--text);
  transform: rotate(5deg);
  margin-top: -2px;
}


/* ── To-Do Items ──────────────────────────────────────── */

.todo-item {
  grid-column: 1 / -1;
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  column-gap: 1.5rem;
  align-items: start;
}

.todo-checkbox {
  grid-column: 5 / 6;
  justify-self: end;
  position: relative;
  cursor: pointer;
  padding-top: 4px;
  overflow: visible;
}

.todo-checkbox input {
  position: absolute;
  opacity: 0;
  width: 0;
  height: 0;
}

.todo-check {
  display: block;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  border: 1.5px solid rgba(0, 0, 0, 0.25);
  transition: border-color 0.2s ease, background 0.2s ease, transform 0.15s ease;
  position: relative;
}

.todo-check::after {
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  width: 100%;
  height: 100%;
  border-radius: 50%;
  transform: translate(-50%, -50%) scale(1);
  background: radial-gradient(circle, rgba(0, 0, 0, 0.15) 0%, transparent 70%);
  opacity: 0;
  pointer-events: none;
}

.todo-checkbox:active .todo-check {
  transform: scale(1.3);
  transition: transform 0.1s ease;
}

.todo-checkbox input:checked ~ .todo-check {
  border-color: var(--text);
  background: var(--text);
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 14 14' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M3.5 7.5L6 10L10.5 4.5' stroke='white' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
  background-size: 14px;
  background-position: center;
  background-repeat: no-repeat;
  animation: check-bounce 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
}

.todo-checkbox input:checked ~ .todo-check::after {
  animation: check-glow 0.6s ease-out forwards;
}

@keyframes check-bounce {
  0% { transform: scale(1.3); }
  40% { transform: scale(0.85); }
  70% { transform: scale(1.08); }
  100% { transform: scale(1); }
}

@keyframes check-glow {
  0% { opacity: 1; transform: translate(-50%, -50%) scale(1); }
  100% { opacity: 0; transform: translate(-50%, -50%) scale(3.5); }
}

.todo-checkbox input:checked ~ .todo-check + .todo-content,
.todo-checkbox input:checked ~ .todo-check {
  opacity: 0.4;
}

.todo-item:has(input:checked) .todo-content {
  opacity: 0.4;
  transition: opacity 0.3s ease 0.05s;
}

.todo-item:has(input:checked) .todo-label {
  text-decoration: line-through;
}

.todo-checkbox:hover .todo-check {
  border-color: rgba(0, 0, 0, 0.5);
}

.todo-content {
  grid-column: 6 / -1;
  display: flex;
  flex-direction: column;
  gap: 4px;
  transition: opacity 0.3s ease;
}

.todo-label {
  font-size: 1.1em;
  font-weight: 600;
  line-height: 1.5;
}

.todo-label a {
  color: var(--text);
  text-decoration: none;
  border-bottom: 1px solid transparent;
  transition: border-color 0.2s ease;
}

.todo-label a:hover {
  border-bottom-color: var(--text-muted);
}


.todo-context {
  font-size: 1em;
  line-height: 1.8;
  color: var(--text-body);
}


/* ── Source Icons ─────────────────────────────────────── */

.source-icon {
  display: inline-flex;
  position: relative;
  width: 24px;
  height: 24px;
  vertical-align: middle;
  margin: 0 2px;
  cursor: pointer;
  color: var(--text);
  text-decoration: none;
  border-bottom: none;
}

.source-icon img,
.source-icon svg {
  width: 100%;
  height: 100%;
  transform: rotate(var(--tilt, 0deg));
  transition: transform 0.4s ease, opacity 0.3s ease;
}

.source-icon:hover img,
.source-icon:hover svg {
  transform: rotate(var(--hover-tilt, 8deg));
  opacity: 0.7;
}

.source-icon:active img,
.source-icon:active svg {
  transform: rotate(var(--hover-tilt, 4deg));
  opacity: 0.5;
}

.source-icon .source-tip {
  position: absolute;
  bottom: calc(100% + 8px);
  left: 50%;
  transform: translateX(-50%);
  font-family: var(--font-body);
  font-size: 12px;
  font-weight: 500;
  font-style: normal;
  color: #fff;
  background: var(--text);
  padding: 5px 10px;
  border-radius: 6px;
  white-space: nowrap;
  opacity: 0;
  pointer-events: none;
  transition: opacity 0.2s ease;
}

.source-icon:hover .source-tip {
  opacity: 1;
}


/* ── Avatars ─────────────────────────────────────────── */

.avatar-img {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  object-fit: cover;
  vertical-align: middle;
  margin-left: -6px;
  border: 1.5px solid var(--page-bg);
}

.avatar-img:first-of-type {
  margin-left: 4px;
}


/* ── Source References ────────────────────────────────── */

.source-ref {
  display: inline;
  padding: 4px 5px;
  margin: -4px -5px;
  transition: background 0.2s ease;
  cursor: pointer;
}

.source-ref:hover {
  background: rgba(0, 0, 0, 0.04);
}

.source-ref:hover .source-icon img,
.source-ref:hover .source-icon svg {
  transform: rotate(var(--hover-tilt, 8deg));
}

.source-ref:hover .source-icon .source-tip {
  opacity: 1;
  transition-delay: 1s;
}

.source-ref .source-icon {
  margin-left: 2px;
}

.source-ref .source-tail {
  white-space: nowrap;
}


/* ── Section Body ─────────────────────────────────────── */

.section-body {
  grid-column: 1 / -1;
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  column-gap: 1.5rem;
  row-gap: clamp(28px, 4cqw, 40px);
}


/* ── Items ────────────────────────────────────────────── */

.item {
  grid-column: 1 / -1;
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  column-gap: 1.5rem;
  align-items: baseline;
}

.item-num {
  font-family: var(--font-mono);
  font-size: 0.9em;
  font-weight: 400;
  color: var(--text-muted);
  flex-shrink: 0;
  letter-spacing: -0.01em;
  padding-left: clamp(20px, 3vw, 32px);
}

.item-body {
  grid-column: 6 / -1;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.item-head {
  display: flex;
  align-items: baseline;
  gap: 12px;
}

.item-title {
  font-size: 1.1em;
  font-weight: 600;
  line-height: 1.5;
}

.item-title a {
  color: var(--text);
  text-decoration: none;
  border-bottom: 1px solid transparent;
  transition: border-color 0.2s ease;
}

.item-title a:hover {
  border-bottom-color: var(--text-muted);
}


/* ── Item Tags ─────────────────────────────────────────── */

.item-tag {
  font-family: var(--font-display);
  font-style: italic;
  font-weight: 400;
  font-size: 0.85em;
  color: var(--text-muted);
  white-space: nowrap;
  margin-left: 8px;
  line-height: 1;
}


/* ── Item Text ────────────────────────────────────────── */

.item-text {
  padding-top: 4px;
}

.item-text p {
  font-size: 1em;
  line-height: 1.8;
  color: var(--text-body);
}


/* ── Item Action ──────────────────────────────────────── */

.item-action {
  display: flex;
  gap: 14px;
  padding-left: clamp(0px, calc(3vw - 3px), 20px);
  padding-top: 0;
}

.action-arrow {
  font-size: 1.47em;
  line-height: 1.5;
  color: var(--text-muted);
  flex-shrink: 0;
  font-weight: 300;
}

.item-action p {
  font-size: 1em;
  line-height: 1.8;
  color: var(--text-body);
}

.item-action--dark p {
  color: var(--text);
}


/* ── Item Bullets ─────────────────────────────────────── */

.item-bullets {
  list-style: none;
  margin: 0.25rem 0 0;
  padding: 0;
}

.item-bullets li {
  position: relative;
  font-size: 1em;
  line-height: 1.8;
  color: var(--text);
  padding-left: 1.6rem;
}

.item-bullets li::before {
  content: '\2022';
  position: absolute;
  left: 0;
  color: var(--text);
  font-size: 1.4em;
  line-height: 1.3;
}

/* ── Brief intro (purpose + privacy) ─────────────────────
   Quiet training-data framing header; the full privacy detail hides behind a <details> disclosure. */

.brief-intro {
  /* Full-row span in the 12-col content grid. Required because the intro is a direct grid child —
     a grid child with no column span auto-places into a single 1/12 track. */
  grid-column: 1 / -1;
  margin-bottom: 2.5rem;
  padding-bottom: 1.5rem;
  border-bottom: 1px solid rgba(0, 0, 0, 0.08);
}

.brief-intro-eyebrow {
  font-family: var(--font-body);
  font-size: 0.7em;
  font-weight: 600;
  letter-spacing: 0.09em;
  text-transform: uppercase;
  color: var(--text-muted);
  margin-bottom: 0.6rem;
}

/* The lines under the eyebrow share ONE body style — a body-sized line with a bold lead — so the
   block reads as a calm paragraph group. The "especially need" line adds a yellow spine to mark the
   single actionable ask; otherwise differentiation comes from the bold lead phrase alone. */
.brief-intro-mission,
.brief-intro-need,
.brief-intro-privacy {
  font-size: 0.95em;
  line-height: 1.6;
  color: var(--text-body);
  margin: 0 0 0.6rem;
}

.brief-intro-need {
  border-left: 2px solid var(--yellow);
  padding-left: 0.7rem;
}

.brief-intro-mission strong,
.brief-intro-need strong,
.brief-intro-privacy strong {
  color: var(--text);
  font-weight: 600;
}

.brief-intro-privacy summary {
  cursor: pointer;
  list-style: none;
  /* Darkens the whole line to --text on hover so the disclosure reads as clickable. */
  transition: color 0.15s ease;
}

.brief-intro-privacy summary:hover {
  color: var(--text);
}

.brief-intro-privacy summary::-webkit-details-marker {
  display: none;
}

/* No explicit color: the caret inherits the summary's color, so the hover darken above applies to
   it too. Sized well above the body text so it clearly reads as a disclosure caret. */
.brief-intro-privacy summary::before {
  content: "▸";
  display: inline-block;
  margin-right: 0.45rem;
  font-size: 1.5em;
  line-height: 1;
  vertical-align: -0.06em;
  transition: transform 0.15s ease;
}

.brief-intro-privacy[open] summary::before {
  transform: rotate(90deg);
}

.brief-intro-privacy-detail {
  margin: 0.5rem 0 0 1.1rem;
  color: var(--text-body);
}


/* ── Section note ────────────────────────────────────────
   A prominent instruction callout under a section header: what the section is + how we want the
   reader to rate it. Boxed with a yellow accent spine so it reads as an actionable ask, not a
   footnote — this is where we tell people how to give the training-data feedback we need. */

.section-note {
  /* Full-row span in the enclosing `.brief-section` 12-col grid, matching its title/body. Required
     because a grid child with no column span auto-places into a single 1/12 column. */
  grid-column: 1 / -1;
  margin: 0.3rem 0 1.4rem;
  padding: 0.9rem 1.15rem;
  background: rgba(0, 0, 0, 0.03);
  border-left: 3px solid var(--yellow);
  border-radius: 8px;
}

.section-note-eyebrow {
  font-family: var(--font-body);
  font-size: 0.7em;
  font-weight: 600;
  letter-spacing: 0.09em;
  text-transform: uppercase;
  color: var(--text-body);
  margin-bottom: 0.4rem;
}

.section-note-body {
  font-size: 0.92em;
  line-height: 1.6;
  color: var(--text-body);
}

.section-note-body strong {
  color: var(--text);
  font-weight: 600;
}


/* ── Item Source ──────────────────────────────────────── */

.item-source {
  padding-top: 2px;
  font-size: 0.75em;
  color: var(--text-muted);
}

.item-source a {
  color: var(--text-muted);
  text-decoration: none;
  border-bottom: 1px solid rgba(0,0,0,0.12);
  transition: color 0.15s ease;
}

.item-source a:hover {
  color: var(--text-body);
}


/* ── Refresh Button ───────────────────────────────────── */

.refresh-wrap {
  position: fixed;
  bottom: 24px;
  right: 24px;
  z-index: 100;
  display: flex;
  align-items: center;
  gap: 8px;
}

.refresh-tooltip {
  font-family: var(--font-body);
  font-size: 13px;
  font-weight: 500;
  color: var(--text);
  background: rgba(255, 255, 255, 0.92);
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.12);
  padding: 8px 14px;
  border-radius: 10px;
  white-space: nowrap;
  opacity: 0;
  transform: translateX(8px);
  transition: opacity 0.4s ease, transform 0.4s ease;
  pointer-events: none;
}

.refresh-tooltip.visible {
  opacity: 1;
  transform: translateX(0);
}

.refresh-btn {
  position: relative;
  width: 48px;
  height: 48px;
  border-radius: 50%;
  border: none;
  background: rgba(255, 255, 255, 0.92);
  color: var(--text);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 2px 12px rgba(0, 0, 0, 0.12);
  transition: transform 0.3s ease, box-shadow 0.2s ease;
}

.refresh-btn:hover {
  transform: scale(1.08);
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.18);
}

.refresh-btn:active {
  transform: scale(0.95);
}

.refresh-btn.spinning svg {
  animation: spin 0.6s ease;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}


/* ── Responsive: Tablet ──────────────────────────────── */

@media (max-width: 1160px) {
  html {
    font-size: clamp(13px, 1.5vw, 16px);
  }

  .item-body,
  .todo-content,
  .schedule-right {
    grid-column: 5 / -1;
  }

  .todo-checkbox {
    grid-column: 4 / 5;
  }

  .schedule-list {
    grid-column: 1 / 5;
    padding-left: 0;
  }

  .brief-section--schedule > .section-title:not(.lineup-title) {
    grid-column: 1 / 5;
  }

  .lineup-title {
    grid-column: 5 / -1;
  }

  .brief-section--inline .section-title {
    grid-column: 1 / 5;
  }

  .push-section .push-title {
    grid-column: 1 / 5;
  }

  .push-body {
    grid-column: 5 / -1;
  }

  .proactive-section .section-title {
    grid-column: 1 / 5;
  }

  .proactive-body {
    grid-column: 5 / -1;
  }
}

/* Tablet range only (not mobile): sit the push starburst slightly lower under the card. */
@media (min-width: 769px) and (max-width: 1160px) {
  .push-badge {
    bottom: calc(-1.25rem - 1.25rem);
  }
}

/* Wide but not tall: slightly smaller root rem; painting display eases toward ~2.5:1. */
@media (min-width: 1161px) and (max-height: 920px) {
  html {
    font-size: clamp(14px, calc(13px + 0.0035 * 100vh), 16px);
  }

  :root {
    /* 1160/600 (~1.93:1) at 920px height → 1160/(1160/2.5) (= 2.5:1) by 600px height. */
    --painting-aspect-h: clamp(
      calc(1160 / 2.5),
      calc(
        600 + (920px - 100vh) * (1160 / 2.5 - 600) / 320 / 1px
      ),
      600
    );
  }
}

@supports (height: 1dvh) {
  @media (min-width: 1161px) and (max-height: 920px) {
    html {
      font-size: clamp(14px, calc(13px + 0.0035 * 100dvh), 16px);
    }

    :root {
      --painting-aspect-h: clamp(
        calc(1160 / 2.5),
        calc(
          600 + (920px - 100dvh) * (1160 / 2.5 - 600) / 320 / 1px
        ),
        600
      );
    }
  }
}

@media (max-width: 900px) {
  .hero-sub {
    grid-template-columns: 1fr;
    gap: 0.4rem;
    padding-top: 8px;
  }

  .hero-sub .painting-caption {
    grid-column: 1 / -1;
    order: -1;
  }

  .brief-blurb {
    grid-column: 1 / -1;
    font-size: 1.35em;
    margin-top: 1em;
  }
}


/* ── Responsive: Small Tablet / Large Phone ───────────── */

@media (max-width: 768px) {
  :root {
    --painting-aspect-w: 6;
    --painting-aspect-h: 4;
    --painting-aspect-h-rail: 4;
  }

  .greeting {
    padding-top: 32px;
  }

  .hero {
    padding-top: 24px;
  }

  .hero-edge {
    font-size: 2rem;
  }

  .item-body,
  .todo-content {
    grid-column: 2 / -1;
  }

  .todo-checkbox {
    grid-column: 1 / 2;
    justify-self: start;
  }

  /* Flatten the schedule's wrappers into the section grid so we can use
     `order` to interleave each heading with its content — without this,
     "Your day" and "The lineup" would both render above the schedule-card
     and look detached from the meetings/people they label. */
  .brief-section--schedule .section-body,
  .brief-section--schedule .schedule-card {
    display: contents;
  }

  .brief-section--schedule > .section-title:not(.lineup-title) { order: 1; }
  .brief-section--schedule .schedule-list { order: 2; }
  .brief-section--schedule .schedule-divider { order: 3; }
  .brief-section--schedule .lineup-title { order: 4; }
  .brief-section--schedule .schedule-right { order: 5; }

  .schedule-list,
  .schedule-right {
    grid-column: 1 / -1;
    margin-left: 0;
    margin-right: 0;
    max-width: 100%;
  }

  .schedule-list {
    min-width: unset;
    padding-left: 0;
  }

  .brief-section--schedule > .section-title:not(.lineup-title),
  .lineup-title {
    grid-column: 1 / -1;
  }

  .lineup-title {
    grid-row: auto;
  }

  .schedule-divider {
    display: block;
    grid-column: 1 / -1;
    width: 100%;
    height: 1px;
    /* Section row-gap already provides spacing on each side of the divider
       in the flattened layout, so keep the divider's own margins at 0. */
    margin: 0;
    background: rgba(0, 0, 0, 0.08);
  }

  .prep-badge {
    position: absolute;
    top: -10px;
    right: -10px;
  }

  .prep-star {
    width: 90px;
    height: 90px;
  }

  .prep-text {
    font-size: 1em;
  }

  .brief-section--boxed {
    padding: clamp(20px, 3vw, 32px);
  }

  .push-section.brief-section--boxed,
  .proactive-section.brief-section--boxed {
    padding: clamp(20px, 3vw, 32px);
  }

  .brief-section--inline {
    row-gap: 20px;
  }

  .section-title {
    padding-left: 0;
  }

  .brief-section--inline .section-title {
    grid-column: 1 / -1;
    grid-row: auto;
  }

  .brief-section--inline .section-body {
    grid-row: auto;
  }

  .item-num {
    padding-left: 0;
  }

  .push-section {
    grid-template-columns: 1fr;
    row-gap: 12px;
    padding-left: clamp(20px, 3vw, 32px);
    padding-right: clamp(20px, 3vw, 32px);
  }

  .push-section .push-title {
    grid-column: 1 / -1;
    grid-row: auto;
    padding-left: 0;
  }

  .push-body {
    grid-column: 1 / -1;
    grid-row: auto;
    padding-right: 0;
  }

  .push-badge {
    bottom: auto;
    top: -16px;
    right: 16px;
    left: auto;
  }

  .proactive-section {
    grid-template-columns: 1fr;
    row-gap: 12px;
    padding-left: clamp(20px, 3vw, 32px);
    padding-right: clamp(20px, 3vw, 32px);
  }

  .proactive-section .section-title {
    grid-column: 1 / -1;
    grid-row: auto;
    padding-left: 0;
  }

  .proactive-body {
    grid-column: 1 / -1;
    grid-row: auto;
    padding-right: 0;
  }

  .item-head {
    flex-wrap: wrap;
    gap: 10px;
  }
}


/* Short viewports: less vertical space above/below the Dia mark and before the hero */
@media (max-height: 899px) {
  .greeting {
    padding-top: clamp(14px, 3vh, 26px);
    padding-bottom: clamp(0px, 0.35vh, 4px);
    padding-left: clamp(16px, 5vw, 24px);
    padding-right: clamp(16px, 5vw, 24px);
  }

  .hero {
    padding-top: clamp(6px, 1.25vh, 14px);
  }
}

@supports (height: 1dvh) {
  @media (max-height: 899px) {
    .greeting {
      padding-top: clamp(14px, 3dvh, 26px);
      padding-bottom: clamp(0px, 0.35dvh, 4px);
    }

    .hero {
      padding-top: clamp(6px, 1.25dvh, 14px);
    }
  }
}


/* ── Responsive: Phone ────────────────────────────────── */

@media (max-width: 480px) {
  .hero-the {
    font-size: 2rem;
  }

  .hero-day {
    font-size: 2.8rem;
    white-space: normal;
    text-align: center;
  }

  .hero-edge {
    font-size: 1.5rem;
  }

  .hero-sub {
    grid-template-columns: 1fr;
    gap: 0.5rem;
  }

  .brief-blurb,
  .hero-sub .painting-caption {
    grid-column: 1 / -1;
    text-align: left;
  }
}


/* ── Dark Mode ───────────────────────────────────────── */

@media (prefers-color-scheme: dark) {
  :root {
    --page-bg: #111111;
    --yellow: #FFE500;
    --text: #F0F0F0;
    --text-body: rgba(235, 225, 210, 0.6);
    --text-muted: rgba(255, 255, 255, 0.3);
  }

  .painting-frame {
    background: #2a2826;
  }

  .painting-caption {
    color: rgba(255, 255, 255, 0.4);
  }

  .hero-the {
    text-shadow:
      0 2px 20px rgba(0, 0, 0, 0.6),
      0 0 60px rgba(0, 0, 0, 0.35);
  }

  .hero-day {
    text-shadow:
      0 2px 30px rgba(0, 0, 0, 0.6),
      0 0 80px rgba(0, 0, 0, 0.4);
  }

  .schedule-item[data-index]:hover,
  .schedule-item--active {
    background: rgba(255, 255, 255, 0.06);
  }

  .todo-check {
    border-color: rgba(255, 255, 255, 0.25);
  }

  .todo-check::after {
    background: radial-gradient(circle, rgba(255, 255, 255, 0.2) 0%, transparent 70%);
  }

  .todo-checkbox input:checked ~ .todo-check {
    border-color: var(--text);
    background: var(--text);
    background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 14 14' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M3.5 7.5L6 10L10.5 4.5' stroke='%23111111' stroke-width='1.5' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
  }

  .todo-checkbox:hover .todo-check {
    border-color: rgba(255, 255, 255, 0.5);
  }

  .source-ref:hover {
    background: rgba(255, 255, 255, 0.06);
  }

  .source-icon .source-tip {
    color: #111;
    background: var(--text);
  }

  .star-tooltip-popover {
    background: #2a2826;
    color: #f8f6f3;
    border-color: rgba(255, 255, 255, 0.1);
    box-shadow:
      0 14px 48px rgba(0, 0, 0, 0.45),
      0 2px 12px rgba(0, 0, 0, 0.25);
  }

  .star-tooltip-popover__head-text {
    color: #faf8f5;
  }

  .star-tooltip-popover__body-msg {
    color: rgba(248, 246, 243, 0.72);
  }

  .star-tooltip-popover__icon svg {
    filter: brightness(0) invert(1);
    opacity: 0.88;
  }

  .schedule-divider {
    background: rgba(255, 255, 255, 0.08);
  }

  .people-entry-social-link {
    border-bottom-color: rgba(255, 255, 255, 0.25);
  }

  .prep-text,
  .push-star-text {
    color: #000;
  }

  .brief-section--boxed {
    background: rgba(255, 255, 255, 0.05);
  }

  .section-note {
    background: rgba(255, 255, 255, 0.05);
  }
}

/* Short viewports: image attribution over the painting, bottom-right, solid white. */
@media (max-height: 799px) {
  .hero {
    display: grid;
    grid-template-columns: repeat(12, minmax(0, 1fr));
    column-gap: 1.5rem;
    row-gap: clamp(9px, 1.625vh, 16px);
    align-items: start;
  }

  .hero-sub {
    display: contents;
  }

  .painting-frame {
    grid-column: 1 / -1;
    grid-row: 1;
    z-index: 1;
  }

  .brief-blurb {
    grid-column: 1 / -1;
    grid-row: 2;
    margin-top: 0;
    order: 0;
  }

  .hero-sub .painting-caption,
  .painting-caption {
    grid-column: 1 / -1;
    grid-row: 1;
    align-self: end;
    justify-self: end;
    z-index: 4;
    /* Up to ~45% of hero width — % resolves against the full-width grid area, not the blurb below. */
    width: 45%;
    min-width: 0;
    box-sizing: border-box;
    margin: 0 0 clamp(6px, 1.2vh, 14px);
    padding-right: clamp(4px, 1.2cqw, 10px);
    text-align: right;
    overflow-wrap: break-word;
    color: #fff;
    text-shadow:
      0 0.5px 1px rgba(0, 0, 0, 0.28),
      0 1px 5px rgba(0, 0, 0, 0.18);
    transition: opacity 0.22s ease, text-shadow 0.22s ease;
    order: 0;
  }

  .hero-sub .painting-caption.visible,
  .painting-caption.visible {
    opacity: 0.55;
  }

  .hero-sub .painting-caption.visible:hover,
  .painting-caption.visible:hover {
    opacity: 1;
    text-shadow:
      0 1px 2px rgba(0, 0, 0, 0.55),
      0 0 12px rgba(0, 0, 0, 0.28);
  }
}

/* ============================================================
   Ported from christine-sandbox/morningbrief/daily-brief-style.css (commit
   ce33f21). Three groups:
     1. To-do sticky-hover + Dia CTA pill
     2. All-done popover + confetti + multi-stage sequence
     3. Page footer (halftone fade-mask + prose credit + HIVE circles)
   ============================================================ */

:root {
  --text-on-yellow: #000;
}

/* ── 1. To-do sticky-hover surface + CTA pill ───────────── */

/* Anchors the absolutely-positioned `.todo-all-done` overlay so it covers the
   list of to-dos when all are checked. */
.brief-section--inline .section-body {
  position: relative;
}

/* Wraps the checkbox + content with the hover/active highlight (::before).
   The 8-track grid mirrors outer cols 5–12 so .todo-content's text edge
   lands on outer col 6, aligning with .item-body. The checkbox sits at
   the left of its track (with a small padding-left) so it stays close to
   the highlight's left edge — matching the tight original look. */
.todo-item-surface {
  grid-column: 5 / -1;
  display: grid;
  grid-template-columns: repeat(8, minmax(0, 1fr));
  column-gap: 1.5rem;
  align-items: start;
  position: relative;
  isolation: isolate;
}

.todo-item-surface::before {
  content: '';
  position: absolute;
  top: -10px;
  bottom: -10px;
  left: 0;
  right: 0;
  border-radius: 12px;
  background: rgba(0, 0, 0, 0.024);
  opacity: 0;
  transition: opacity 0.18s ease;
  z-index: 0;
  pointer-events: none;
}

.todo-item.is-active:not(:has(input:checked)) .todo-item-surface::before {
  opacity: 1;
}

.todo-item:has(input:checked) .todo-item-surface::before {
  opacity: 0;
}

.todo-item-surface > .todo-checkbox,
.todo-item-surface > .todo-content {
  position: relative;
  z-index: 1;
}

.todo-item-surface > .todo-checkbox {
  grid-column: 1;
  justify-self: start;
  padding-left: 12px;
}

.todo-item-surface > .todo-content {
  grid-column: 2 / -1;
  min-width: 0;
}

/* Track the .item-body breakpoint shifts so .todo-content stays aligned
   with it: each breakpoint widens the surface by one outer column and
   grows the internal track count to match. */
@media (max-width: 1160px) {
  .todo-item-surface {
    grid-column: 4 / -1;
    grid-template-columns: repeat(9, minmax(0, 1fr));
  }
}

@media (max-width: 768px) {
  .todo-item-surface {
    grid-column: 1 / -1;
    grid-template-columns: repeat(12, minmax(0, 1fr));
  }

  /* Surface now spans the full content area, so align the checkbox flush
     with col 1 (matching .item-num in the updates section, which drops its
     padding at this breakpoint). */
  .todo-item-surface > .todo-checkbox {
    padding-left: 0;
  }
}

.todo-head {
  position: relative;
}

.todo-head .todo-label {
  display: block;
  min-width: 0;
  padding-right: 2.25rem;
  position: relative;
  z-index: 0;
}

.todo-actions {
  z-index: 1;
  position: absolute;
  bottom: 0;
  right: 8px;
  height: 2.375rem;
  display: flex;
  align-items: center;
  justify-content: flex-end;
  pointer-events: none;
  max-width: calc(100% - 8px);
}

.todo-dia-btn {
  position: relative;
  display: inline-flex;
  align-items: center;
  justify-content: flex-end;
  flex-shrink: 0;
  gap: 0;
  box-sizing: border-box;
  width: fit-content;
  max-width: 100%;
  height: 2.375rem;
  padding: 0;
  font-family: var(--font-body);
  font-size: 0.875rem;
  font-weight: 600;
  line-height: 1.125rem;
  color: var(--text);
  text-decoration: none;
  white-space: nowrap;
  background: transparent;
  border-radius: 999px;
  border: none;
  cursor: pointer;
  overflow: hidden;
  box-shadow: none;
  pointer-events: none;
  transition:
    gap 0.24s ease-out,
    padding 0.24s ease-out,
    background 0.22s ease-out,
    box-shadow 0.22s ease-out;
}

.todo-item.is-active .todo-dia-btn {
  gap: 7px;
  padding: 0 0.6rem 0 calc(0.65rem + 4px);
  background: var(--yellow);
  color: var(--text-on-yellow);
  box-shadow: 0 1px 0 rgba(0, 0, 0, 0.06);
  pointer-events: auto;
}

.todo-dia-btn-expand {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  min-width: 0;
  max-width: 0;
  overflow: hidden;
  transition: max-width 0.24s ease-out;
}

.todo-item.is-active .todo-dia-btn-expand {
  max-width: 24rem;
}

.todo-dia-btn-label-wrap {
  display: block;
  overflow: hidden;
  flex-shrink: 0;
  margin-right: -2em;
}

.todo-item.is-active .todo-dia-btn-label-wrap {
  margin-right: 0;
}

.todo-dia-btn-label {
  display: inline-block;
  white-space: nowrap;
}

.todo-dia-btn-icon,
.todo-dia-btn-label {
  color: var(--text-on-yellow);
  opacity: 0;
  transition: opacity 0.08s ease-out;
}

.todo-item.is-active .todo-dia-btn-icon,
.todo-item.is-active .todo-dia-btn-label {
  opacity: 1;
  transition: opacity 0.16s ease-out 0.1s;
}

.todo-dia-btn-arrow {
  flex-shrink: 0;
  display: block;
  width: 18px;
  height: 18px;
  color: var(--text-muted);
  transition: color 0.06s ease-out;
}

.todo-item.is-active .todo-dia-btn-arrow {
  color: var(--text-on-yellow);
  transition: color 0.16s ease-out;
}

.todo-dia-btn::before {
  content: '';
  position: absolute;
  top: -20%;
  left: -120%;
  width: 110%;
  height: 140%;
  pointer-events: none;
  background: linear-gradient(
    105deg,
    transparent 20%,
    rgba(255, 255, 255, 0.1) 30%,
    rgba(255, 200, 220, 0.2) 38%,
    rgba(200, 220, 255, 0.25) 46%,
    rgba(220, 255, 220, 0.2) 54%,
    rgba(255, 240, 200, 0.15) 62%,
    rgba(255, 255, 255, 0.1) 70%,
    transparent 80%
  );
  transform: skewX(-15deg);
  opacity: 0;
  transition: opacity 0.2s ease;
  z-index: 0;
}

.todo-dia-btn-expand,
.todo-dia-btn-arrow {
  position: relative;
  z-index: 1;
}

.todo-item.is-active .todo-dia-btn:hover {
  background: color-mix(in srgb, var(--yellow) 94%, #000);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.todo-dia-btn:hover::before {
  opacity: 1;
  animation: prismatic-shine 0.6s ease-out forwards;
}

.todo-dia-btn:not(:hover)::before {
  animation: none;
  left: -120%;
  opacity: 0;
}

.todo-item.is-active .todo-dia-btn:active {
  box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.1);
}

.todo-dia-btn-icon {
  flex-shrink: 0;
  display: block;
  width: 16px;
  height: 14px;
  shape-rendering: geometricPrecision;
}

.todo-dia-btn:focus-visible {
  outline: 2px solid rgba(0, 0, 0, 0.35);
  outline-offset: 2px;
}

@keyframes prismatic-shine {
  0%   { left: -120%; }
  100% { left: 140%; }
}

@media screen and (max-width: 540px) {
  .todo-head .todo-label {
    padding-right: 2.25rem;
  }
  .todo-dia-btn-label-wrap,
  .todo-dia-btn-label {
    display: none;
  }
  .todo-item.is-active .todo-dia-btn {
    padding: 0 0.35rem 0 calc(0.4rem + 4px);
    gap: 7px;
  }
  .todo-item.is-active .todo-dia-btn-expand {
    max-width: 2.5rem;
  }
}

@media (prefers-reduced-motion: reduce) {
  .todo-item-surface::before,
  .todo-dia-btn,
  .todo-dia-btn-expand,
  .todo-dia-btn-icon,
  .todo-dia-btn-label,
  .todo-dia-btn-label-wrap,
  .todo-dia-btn-arrow {
    transition: none;
  }
}

/* ── 2. All-done popover + confetti + multi-stage sequence ── */

/* To-dos can span two sections ("Top to-dos" + "For later"). When everything is
   checked off, the celebration overlays the first section and the rest collapse
   away, so the all-done state reads as one celebration like the standard brief. */
.brief-section--inline.is-todos-done-collapsed {
  display: none;
}

/* When the popover takes over, blur each to-do directly (no `.todo-list`
   wrapper to target, by design — we kept the section-body flat). */
.brief-section--inline.is-all-done .todo-item:not(.todo-item--completion) {
  pointer-events: none;
  filter: blur(6px);
  opacity: 0.3;
  transition: filter 0.28s ease, opacity 0.28s ease;
}

.todo-all-done.is-popover-visible > .todo-item {
  animation: todo-popover-scale-in 0.2s cubic-bezier(0.34, 1.28, 0.64, 1) both;
}

@keyframes todo-popover-scale-in {
  from { opacity: 0; transform: scale(0.94); }
  to   { opacity: 1; transform: scale(1); }
}

/* The popover is appended as a sibling of the `.todo-item`s in
   `.section-body`. While hidden it's `display: none` so it takes no space.
   When visible it absolutely overlays the section-body — the blurred items
   underneath provide the height; the card centers over them. */
.todo-all-done {
  display: none;
  pointer-events: none;
}

.brief-section--inline.is-all-done .todo-all-done.is-popover-visible {
  display: flex;
  position: absolute;
  inset: 0;
  align-items: center;
  justify-content: center;
  z-index: 2;
}

.todo-all-done > .todo-item {
  width: min(100%, 38rem);
  max-width: 100%;
  pointer-events: auto;
}

/* The completion card doesn't have the checkbox + content split — override
   the surface's grid tracks so the card fills the full width instead of
   being squeezed into col 2. */
.todo-all-done-surface.todo-item-surface {
  display: block;
  width: 100%;
  z-index: 1;
}

.todo-all-done-surface.todo-item-surface::before {
  top: 0;
  opacity: 1;
  background: #f1f1f1;
  transition: opacity 0.35s ease;
}

.todo-all-done.is-sequence-active .todo-all-done__close {
  opacity: 0;
  animation: todo-fade-in 0.35s ease forwards;
  animation-delay: 0.15s;
}

.todo-all-done-surface .todo-all-done__card {
  grid-column: 1 / -1;
  position: relative;
  z-index: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-start;
  width: 100%;
  padding: 2rem 2.25rem;
  border-radius: 12px;
  background: #f1f1f1;
  box-sizing: border-box;
  overflow: visible;
}

.todo-all-done__close {
  position: absolute;
  top: 0.75rem;
  right: 0.75rem;
  z-index: 3;
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1.75rem;
  height: 1.75rem;
  padding: 0;
  border: 0;
  border-radius: 6px;
  background: transparent;
  color: rgba(60, 60, 67, 0.55);
  cursor: pointer;
  transition: color 0.12s ease, background-color 0.12s ease;
}

.todo-all-done__close:hover {
  color: rgba(60, 60, 67, 0.85);
  background: rgba(0, 0, 0, 0.05);
}

.todo-all-done__close:focus-visible {
  outline: 2px solid rgba(0, 0, 0, 0.35);
  outline-offset: 2px;
}

.todo-all-done__stage {
  position: relative;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  width: 100%;
}

.todo-all-done__content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1.5rem;
  width: 100%;
  margin-top: 1.5rem;
}

.todo-all-done__badge {
  position: relative;
  z-index: 1;
  width: 3.325rem;
  height: 3.325rem;
  display: grid;
  place-items: center;
  flex-shrink: 0;
  opacity: 1;
  transform: scale(1) rotate(0deg);
}

.todo-all-done__star {
  position: absolute;
  inset: 0;
  background: var(--yellow);
  border: 2px solid #f1f1f1;
  box-sizing: border-box;
  clip-path: polygon(
    50% 0%, 60.9% 9.4%, 75% 6.7%, 79.7% 20.3%,
    93.3% 25%, 90.6% 39.1%, 100% 50%, 90.6% 60.9%,
    93.3% 75%, 79.7% 79.7%, 75% 93.3%, 60.9% 90.6%,
    50% 100%, 39.1% 90.6%, 25% 93.3%, 20.3% 79.7%,
    6.7% 75%, 9.4% 60.9%, 0% 50%, 9.4% 39.1%,
    6.7% 25%, 20.3% 20.3%, 25% 6.7%, 39.1% 9.4%
  );
}

.todo-all-done__check {
  position: relative;
  z-index: 1;
  color: var(--text-on-yellow);
}

.todo-all-done__title {
  margin: 0;
  width: 100%;
  font-family: var(--font-display);
  font-style: italic;
  font-weight: 400;
  font-size: 1.47em;
  line-height: 1.2;
  color: var(--text);
  text-align: center;
  text-wrap: balance;
}

.todo-all-done__desc {
  margin: 0;
  width: 100%;
  max-width: 38.75rem;
  font-family: var(--font-body);
  font-size: 1em;
  line-height: 1.7;
  color: var(--text-body);
  text-align: center;
  text-wrap: pretty;
}

@keyframes todo-fade-in {
  to { opacity: 1; }
}

.todo-all-done.is-popover-visible:not(.is-sequence-active) .todo-all-done__badge,
.todo-all-done.is-sequence-done .todo-all-done__badge {
  opacity: 1;
  transform: scale(1) rotate(0deg);
}

.todo-all-done.is-sequence-active .todo-all-done__badge {
  opacity: 0;
  transform: scale(0.72) rotate(-10deg);
  animation: todo-badge-pop 0.32s cubic-bezier(0.34, 1.28, 0.64, 1) forwards;
  animation-delay: 0.2s;
}

.todo-all-done.is-sequence-active .todo-all-done__title,
.todo-all-done.is-sequence-active .todo-all-done__desc {
  opacity: 0;
  transform: translateY(14px);
}

.todo-all-done.is-sequence-active .todo-all-done__title {
  animation: todo-content-in 0.48s ease forwards;
  animation-delay: 0.5s;
}

.todo-all-done.is-sequence-active .todo-all-done__desc {
  animation: todo-content-in 0.48s ease forwards;
  animation-delay: 0.62s;
}

@keyframes todo-badge-pop {
  0%   { opacity: 0; transform: scale(0.72) rotate(-10deg); }
  72%  { opacity: 1; transform: scale(1.05) rotate(2deg);  }
  100% { opacity: 1; transform: scale(1)    rotate(0deg);  }
}

@keyframes todo-content-in {
  to { opacity: 1; transform: translateY(0); }
}

.todo-all-done__stage .todo-confetti {
  position: absolute;
  inset: -40% -20%;
  overflow: visible;
  pointer-events: none;
  z-index: 0;
}

.todo-confetti-piece {
  position: absolute;
  left: 50%;
  top: 50%;
  width: var(--size, 7px);
  height: var(--size, 7px);
  margin-left: calc(var(--size, 7px) / -2);
  margin-top: calc(var(--size, 7px) / -2);
  background: var(--color, var(--yellow));
  border-radius: 1px;
  opacity: 0;
  transform: translate(-50%, -50%) rotate(0deg) scale(1);
  animation: todo-confetti-burst 1.85s cubic-bezier(0.22, 0.61, 0.36, 1) forwards;
}

.todo-confetti-piece--rect {
  border-radius: 0;
  width: calc(var(--size, 7px) * 0.55);
}

.todo-confetti-piece--dot {
  border-radius: 50%;
}

@keyframes todo-confetti-burst {
  0%   { opacity: 1; transform: translate(-50%, -50%) rotate(0deg) scale(1); }
  100% { opacity: 0; transform: translate(calc(-50% + var(--tx)), calc(-50% + var(--ty))) rotate(var(--rot)) scale(0.65); }
}

@media (prefers-reduced-motion: reduce) {
  .brief-section--inline.is-all-done .todo-list {
    transition: none;
  }
  .todo-all-done.is-popover-visible > .todo-item {
    animation: none;
    opacity: 1;
    transform: none;
  }
  .todo-all-done.is-sequence-active .todo-all-done__close,
  .todo-all-done.is-sequence-active .todo-all-done__badge,
  .todo-all-done.is-sequence-active .todo-all-done__title,
  .todo-all-done.is-sequence-active .todo-all-done__desc {
    animation: none;
    opacity: 1;
    transform: none;
  }
  .todo-confetti-piece {
    animation: none;
    display: none;
  }
}

/* ── 3. Page footer (halftone, prose credit, HIVE circles) ── */

.brief-footer {
  position: relative;
  width: 100%;
  min-height: 315px;
  margin-top: clamp(12px, 2vw, 24px);
  /* The halftone's densest point is masked to the footer's bottom edge, so the
     footer must reach the very bottom of the page — no bottom margin. Bottom
     breathing room lives in padding-bottom instead, which the halftone fills. */
  margin-bottom: 0;
  padding: clamp(72px, 12vw, 120px) var(--content-pad) clamp(108px, 15vw, 160px);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: flex-end;
  overflow: hidden;
  isolation: isolate;
  opacity: 0;
  transform: translateY(18px);
  transition: opacity 0.55s ease, transform 0.55s ease;
}

.brief-footer.is-visible {
  opacity: 1;
  transform: translateY(0);
}

.brief-footer:not(.is-visible) {
  pointer-events: none;
}

.brief-footer__fade {
  position: absolute;
  top: clamp(48px, 8vw, 96px);
  left: 50%;
  transform: translateX(-50%);
  width: min(938px, 82%);
  height: 168px;
  background: var(--page-bg);
  filter: blur(100px);
  pointer-events: none;
  z-index: 0;
}

.brief-footer__halftone {
  position: absolute;
  inset: 0;
  background-color: var(--page-bg);
  background-image: radial-gradient(circle, rgba(0, 0, 0, 0.14) 0.65px, transparent 0.65px);
  background-size: 5px 5px;
  mask-image:
    radial-gradient(ellipse 90% 70% at 50% 100%, #000 15%, transparent 72%),
    linear-gradient(to top, #000 0%, transparent 55%);
  -webkit-mask-image:
    radial-gradient(ellipse 90% 70% at 50% 100%, #000 15%, transparent 72%),
    linear-gradient(to top, #000 0%, transparent 55%);
  mask-composite: intersect;
  -webkit-mask-composite: source-in;
  pointer-events: none;
  z-index: 1;
}

.brief-footer__inner {
  position: relative;
  z-index: 2;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 24px;
  max-width: var(--content-max);
  width: 100%;
  text-align: center;
}

.brief-footer__credit {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 4.5px;
  font-family: var(--font-display);
  font-size: clamp(1.125rem, 1.6vw, 1.5rem);
  font-weight: 550;
  line-height: 32px;
  letter-spacing: -0.01em;
}

.brief-footer__muted {
  color: rgba(0, 0, 0, 0.5);
  font-weight: 550;
}

.brief-footer__emph {
  font-style: italic;
}

.brief-footer__brand {
  display: inline-flex;
  align-items: center;
  gap: 4.5px;
  color: rgba(0, 0, 0, 0.85);
}

.brief-footer__icon--dia {
  width: 19px;
  height: 18px;
  flex-shrink: 0;
  color: rgba(0, 0, 0, 0.85);
}

.brief-footer__source.source-ref {
  display: inline-flex;
  align-items: center;
  gap: 4.5px;
  color: rgba(0, 0, 0, 0.85);
  text-decoration: none;
  white-space: nowrap;
  cursor: pointer;
  padding: 0;
  margin: 0 0 0 3px;
  transition: opacity 0.2s ease;
}

.brief-footer__source.source-ref:hover {
  background: transparent;
  opacity: 0.6;
}

.brief-footer__source .source-icon {
  width: 21px;
  height: 21px;
  margin: 0;
  vertical-align: middle;
}

.brief-footer__source .source-icon svg,
.brief-footer__source .source-icon img {
  width: 100%;
  height: 100%;
  opacity: 1;
}

.brief-footer__love {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: center;
  gap: 4px;
  font-family: var(--font-display);
  font-size: 15px;
  line-height: 19px;
  color: #8c8c8c;
}

.brief-footer__circles {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  cursor: default;
}

.brief-footer__circle {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 19px;
  height: 19px;
  border: 0.5px solid #8c8c8c;
  border-radius: 50%;
  font-size: 12px;
  line-height: 1;
  color: #8c8c8c;
  transform: translateY(0);
}

@keyframes brief-footer-circle-wave {
  0%   { transform: translateY(0); }
  38%  { transform: translateY(-7px); }
  58%  { transform: translateY(1px); }
  78%  { transform: translateY(-2px); }
  100% { transform: translateY(0); }
}

.brief-footer__circles:hover .brief-footer__circle {
  animation-name: brief-footer-circle-wave;
  animation-duration: 0.82s;
  animation-timing-function: cubic-bezier(0.34, 1.45, 0.56, 1);
  animation-iteration-count: 1;
  animation-fill-mode: backwards;
}

.brief-footer__circles:hover .brief-footer__circle:nth-child(1) { animation-delay: 0s; }
.brief-footer__circles:hover .brief-footer__circle:nth-child(2) { animation-delay: 0.11s; }
.brief-footer__circles:hover .brief-footer__circle:nth-child(3) { animation-delay: 0.22s; }
.brief-footer__circles:hover .brief-footer__circle:nth-child(4) { animation-delay: 0.33s; }

@media (prefers-reduced-motion: reduce) {
  .brief-footer {
    opacity: 1;
    transform: none;
    transition: none;
  }
  .brief-footer__circles:hover .brief-footer__circle {
    animation: none;
  }
}

@media (prefers-color-scheme: dark) {
  /* Sticky-hover surface highlight: invert the black-overlay tint to a
     white-overlay tint so it reads on the dark page bg. */
  .todo-item-surface::before {
    background: rgba(255, 255, 255, 0.05);
  }

  /* Focus ring on the active Dia CTA pill — the yellow stays bright in dark
     mode, but the outline ring needs to flip from black to white to be visible
     against the dark page surround. */
  .todo-dia-btn:focus-visible {
    outline-color: rgba(255, 255, 255, 0.4);
  }

  /* Completion popover card. The card/star/surface::before all share the
     same neutral surface color in light mode (#f1f1f1) — they have to keep
     sharing in dark mode so the star outline still "carves out" against the
     card behind it. */
  .todo-all-done-surface.todo-item-surface::before,
  .todo-all-done-surface .todo-all-done__card {
    background: #1a1a1a;
  }

  .todo-all-done__star {
    border-color: #1a1a1a;
  }

  .todo-all-done__close {
    color: rgba(235, 225, 210, 0.55);
  }

  .todo-all-done__close:hover {
    color: rgba(235, 225, 210, 0.9);
    background: rgba(255, 255, 255, 0.06);
  }

  .todo-all-done__close:focus-visible {
    outline-color: rgba(255, 255, 255, 0.4);
  }

  /* Footer: halftone dots invert (dark dots on a light page → light dots on
     a dark page). The fade and the dot color must both swap; mid-gray love /
     circles stay legible on both. */
  .brief-footer__halftone {
    background-color: var(--page-bg);
    background-image: radial-gradient(circle, rgba(255, 255, 255, 0.1) 0.65px, transparent 0.65px);
  }

  .brief-footer__muted {
    color: rgba(255, 255, 255, 0.45);
  }

  .brief-footer__brand,
  .brief-footer__source.source-ref,
  .brief-footer__icon--dia {
    color: rgba(255, 255, 255, 0.85);
  }
}

@media print {
  .todo-actions {
    display: none;
  }
}

/* ============================================================
   Context Builder additions: ranked to-dos + Tasks section
   ============================================================ */

:root {
  /* Time cue for to-do flags (DUE TODAY / TIME-SENSITIVE). Deliberately a calm,
     muted slate rather than alarm-red — the uppercase label already carries the
     emphasis, so the color stays informational, not urgent. */
  --urgent: #6B6B76;
}

/* ── Shared ranked number ─────────────────────────────── */

.todo-item,
.item.task-item {
  position: relative;
}

.rank-number {
  position: absolute;
  left: clamp(20px, 3vw, 32px);
  top: 0;
  font-family: var(--font-mono);
  font-size: 1.5em;
  font-weight: 400;
  line-height: 1.4;
  color: var(--text-muted);
  letter-spacing: -0.02em;
  z-index: 1;
}

/* ── To-do meta row ───────────────────────────────────── */

.todo-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
  margin-top: 1px;
}

.todo-flag {
  font-family: var(--font-body);
  font-size: 0.68em;
  font-weight: 650;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--urgent);
}

/* ── Tasks section ────────────────────────────────────── */

.task-title {
  font-family: var(--font-display);
  font-size: 1.55em;
  font-weight: 500;
  line-height: 1.2;
}

.task-desc {
  margin-top: 2px;
}
"""#
    static let briefFeedbackCSS = #"""
/* ============================================================
   Morning Brief — in-brief quality feedback layer.
   Loaded only when the contextBuilderMorningBriefFeedbackEnabled flag is on.
   Quiet by default so the brief still reads like a brief; affordances
   brighten on hover/focus and selected states are unmistakable.
   ============================================================ */

:root {
  --fb-line: rgba(0, 0, 0, 0.12);
  --fb-correct: #1f8f4e;
  --fb-incorrect: #d23b3b;
}

/* ── Grading focus ─────────────────────────────────────── */

.fb-optional-boundary {
  grid-column: 1 / -1;
  margin-block: clamp(4px, 1cqw, 12px) clamp(-6px, -1cqw, 0px);
}

.fb-optional-boundary__card {
  display: grid;
  grid-template-columns: minmax(24px, 1fr) auto minmax(24px, 1fr);
  column-gap: clamp(12px, 2cqw, 24px);
  row-gap: 9px;
  align-items: center;
  padding-block: 2px;
  font-family: var(--font-body);
}

.fb-optional-boundary__card::before,
.fb-optional-boundary__card::after {
  content: "";
  grid-row: 1;
  height: 1px;
  background: rgba(0, 0, 0, 0.14);
}

.fb-optional-boundary__card::before {
  grid-column: 1;
}

.fb-optional-boundary__card::after {
  grid-column: 3;
}

.fb-optional-boundary__eyebrow {
  grid-column: 2;
  grid-row: 1;
  margin: 0;
  font-family: var(--font-display);
  font-size: clamp(15px, calc(12px + 0.4cqw), 18px);
  font-style: italic;
  font-weight: 550;
  line-height: 1;
  letter-spacing: 0.01em;
  color: rgba(0, 0, 0, 0.66);
  white-space: nowrap;
}

.fb-optional-boundary__message {
  grid-column: 1 / -1;
  grid-row: 2;
  max-width: 90ch;
  margin: 0 auto;
  font-size: clamp(11px, calc(9px + 0.35cqw), 13px);
  font-weight: 400;
  line-height: 1.45;
  color: var(--text-body);
  text-align: center;
  text-wrap: pretty;
}

.fb-section--optional .section-title {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 10px;
}

.fb-optional-badge {
  display: inline-flex;
  align-items: center;
  padding: 0;
  font-family: var(--font-body);
  font-size: 10px;
  font-style: normal;
  font-weight: 500;
  line-height: 1;
  letter-spacing: 0.01em;
  color: var(--text-muted);
}

/* ── Per-item controls ──────────────────────────────────── */

/* app.js drops an empty slot in each item's content column; feedback.js fills
   it. The slot is a block so the controls sit on their own line under the
   item, including inside flex content columns. */
.fb-controls-slot {
  display: block;
}

.fb-item-controls {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: clamp(10px, 1.4vw, 18px);
  margin: 8px 0 2px;
  padding: 2px 0;
  font-family: var(--font-body);
  opacity: 0.5;
  transition: opacity 0.15s ease;
}

.fb-item-controls:hover,
.fb-item-controls:focus-within {
  opacity: 1;
}

.fb-control {
  display: inline-flex;
  align-items: center;
  gap: 6px;
}

.fb-control-label {
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  color: var(--text-muted);
}

/* ── Toggle group + buttons ─────────────────────────────── */

.fb-toggle-group {
  display: inline-flex;
  gap: 3px;
}

.fb-toggle {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 5px;
  min-width: 24px;
  height: 24px;
  padding: 0 7px;
  margin: 0;
  font: inherit;
  font-size: 12px;
  line-height: 1;
  color: var(--text-body);
  background: transparent;
  border: 1px solid var(--fb-line);
  border-radius: 7px;
  cursor: pointer;
  transition: background 0.12s ease, color 0.12s ease, border-color 0.12s ease;
}

.fb-toggle:hover {
  background: rgba(0, 0, 0, 0.05);
}

.fb-toggle:focus-visible {
  outline: 2px solid var(--text);
  outline-offset: 1px;
}

.fb-toggle-glyph {
  font-size: 13px;
}

.fb-toggle-text {
  font-size: 12px;
  font-weight: 500;
}

/* Selected states — clearly filled, semantic per question. */
.fb-toggle[aria-pressed="true"] {
  background: var(--text);
  color: #fff;
  border-color: transparent;
}

.fb-correct .fb-toggle[data-value="true"][aria-pressed="true"] {
  background: var(--fb-correct);
  color: #fff;
}

.fb-correct .fb-toggle[data-value="false"][aria-pressed="true"] {
  background: var(--fb-incorrect);
  color: #fff;
}

.fb-useful .fb-toggle[aria-pressed="true"] {
  background: var(--yellow);
  color: #000;
}

/* ── Section completeness ───────────────────────────────── */

/* Sits at the end of the section, aligned to the content column (outer col 6),
   matching the body text rather than the left rank rail. */
.fb-completeness {
  grid-column: 6 / -1;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 12px;
  margin-top: 4px;
  padding-top: 16px;
  border-top: 1px solid var(--fb-line);
  font-family: var(--font-body);
}

.fb-completeness-q {
  margin: 0;
  font-size: 13px;
  font-weight: 600;
  color: var(--text);
}

.fb-complete .fb-toggle[data-value="true"][aria-pressed="true"] {
  background: var(--fb-correct);
  color: #fff;
}

.fb-missing-note,
.fb-correct-note {
  flex-basis: 100%;
  margin-top: 4px;
  padding: 8px 10px;
  font: inherit;
  font-size: 13px;
  color: var(--text);
  background: rgba(255, 255, 255, 0.6);
  border: 1px solid var(--fb-line);
  border-radius: 8px;
  resize: vertical;
}

.fb-missing-note[hidden],
.fb-correct-note[hidden] {
  display: none;
}

.fb-missing-note:focus-visible,
.fb-correct-note:focus-visible {
  outline: 2px solid var(--text);
  outline-offset: 1px;
}

.fb-missing-note.is-invalid,
.fb-correct-note.is-invalid {
  border-color: var(--fb-incorrect);
  background: rgba(210, 59, 59, 0.08);
}

.fb-missing-note.is-invalid:focus-visible,
.fb-correct-note.is-invalid:focus-visible {
  outline-color: var(--fb-incorrect);
}

/* ── Fixed submit pill ──────────────────────────────────── */
/* Hidden until the reader rates anything; then it slides up from the bottom
   of the viewport. Floats above the brief, centered, never in the page flow. */

.fb-submit-fixed {
  position: fixed;
  left: 50%;
  bottom: clamp(18px, 4vh, 36px);
  z-index: 1000;
  display: inline-flex;
  align-items: center;
  gap: 9px;
  padding: 11px 22px;
  font-family: var(--font-body);
  font-size: 14px;
  font-weight: 600;
  color: #000;
  background: var(--yellow);
  border: none;
  border-radius: 999px;
  box-shadow:
    0 8px 28px rgba(0, 0, 0, 0.18),
    0 2px 6px rgba(0, 0, 0, 0.12);
  cursor: pointer;
  opacity: 0;
  visibility: hidden;
  pointer-events: none;
  transform: translateX(-50%) translateY(10px);
  transition:
    opacity 0.24s ease,
    transform 0.24s ease,
    visibility 0.24s,
    background 0.2s ease;
}

.fb-submit-fixed.is-visible {
  opacity: 1;
  visibility: visible;
  pointer-events: auto;
  transform: translateX(-50%) translateY(0);
}

.fb-submit-fixed:hover {
  filter: brightness(0.96);
}

.fb-submit-fixed:focus-visible {
  outline: 2px solid var(--text);
  outline-offset: 3px;
}

/* The running count of things rated, tucked in a soft chip. */
.fb-submit-fixed__count:not(:empty) {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 18px;
  height: 18px;
  padding: 0 5px;
  font-size: 11px;
  font-weight: 700;
  color: var(--text);
  background: rgba(0, 0, 0, 0.12);
  border-radius: 999px;
}

.fb-submit-fixed.is-done {
  background: var(--fb-correct);
  color: #fff;
}

/* ── Submit celebration ───────────────────────────────── */

.fb-celebration {
  position: fixed;
  inset: 0;
  z-index: 1200;
  display: grid;
  place-items: center;
  padding: 24px;
  pointer-events: none;
  background: radial-gradient(circle at center, rgba(255, 229, 0, 0.22), rgba(255, 255, 255, 0) 58%);
  animation: fb-celebration-fade 3.2s ease both;
}

.fb-celebration__card {
  position: relative;
  z-index: 1;
  width: min(390px, calc(100vw - 48px));
  padding: 34px 30px 30px;
  text-align: center;
  color: #111;
  background: var(--yellow);
  border: 2px solid #111;
  border-radius: 24px;
  box-shadow:
    0 26px 70px rgba(0, 0, 0, 0.24),
    8px 9px 0 rgba(17, 17, 17, 0.9);
  animation: fb-celebration-card 3.2s cubic-bezier(0.18, 0.89, 0.32, 1.24) both;
}

.fb-celebration__mark {
  display: grid;
  place-items: center;
  width: 48px;
  height: 48px;
  margin: 0 auto 16px;
  font-size: 24px;
  color: var(--yellow);
  background: #111;
  border-radius: 50%;
  box-shadow: 0 0 0 7px rgba(17, 17, 17, 0.1);
}

.fb-celebration__eyebrow {
  margin: 0 0 8px;
  font-family: var(--font-mono);
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.12em;
  text-transform: uppercase;
}

.fb-celebration__title {
  margin: 0;
  font-family: var(--font-display);
  font-size: clamp(30px, 8vw, 48px);
  font-style: italic;
  font-weight: 500;
  line-height: 0.98;
  letter-spacing: -0.02em;
}

.fb-celebration__message {
  max-width: 30ch;
  margin: 16px auto 0;
  font-family: var(--font-body);
  font-size: 15px;
  font-weight: 550;
  line-height: 1.45;
}

.fb-celebration__confetti-field {
  position: absolute;
  inset: 0;
  overflow: hidden;
}

.fb-celebration__confetti {
  position: absolute;
  top: 50%;
  left: 50%;
  width: 9px;
  height: 18px;
  background: var(--fb-color);
  border: 1px solid rgba(0, 0, 0, 0.18);
  opacity: 0;
  animation: fb-confetti-burst 1.55s cubic-bezier(0.18, 0.75, 0.3, 1) var(--fb-delay) both;
}

.fb-celebration__confetti.is-round {
  width: 12px;
  height: 12px;
  border-radius: 50%;
}

@keyframes fb-celebration-fade {
  0%, 100% { opacity: 0; }
  8%, 78% { opacity: 1; }
}

@keyframes fb-celebration-card {
  0% { opacity: 0; transform: translateY(28px) scale(0.7) rotate(-5deg); }
  10% { opacity: 1; }
  18% { transform: translateY(0) scale(1.06) rotate(1.5deg); }
  25%, 76% { opacity: 1; transform: translateY(0) scale(1) rotate(0); }
  100% { opacity: 0; transform: translateY(-18px) scale(0.96) rotate(1deg); }
}

@keyframes fb-confetti-burst {
  0% { opacity: 0; transform: translate(-50%, -50%) scale(0.2) rotate(0); }
  12%, 75% { opacity: 1; }
  100% {
    opacity: 0;
    transform: translate(calc(-50% + var(--fb-x)), calc(-50% + var(--fb-y))) scale(1) rotate(var(--fb-r));
  }
}

@media (prefers-reduced-motion: reduce) {
  .fb-item-controls,
  .fb-toggle,
  .fb-submit-fixed {
    transition: none;
  }

  .fb-celebration {
    animation: fb-celebration-fade 2.4s linear both;
  }

  .fb-celebration__card {
    animation: none;
  }

  .fb-celebration__confetti-field {
    display: none;
  }
}

/* ── Freeform feedback widget (bottom-left) ──────────────── */

.fb-preview {
  position: fixed;
  left: clamp(16px, 3vw, 32px);
  bottom: clamp(16px, 4vh, 32px);
  z-index: 1000;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 10px;
}

.fb-preview-fab {
  align-self: flex-start;
  padding: 11px 22px;
  font-family: var(--font-body);
  font-size: 14px;
  font-weight: 600;
  color: #000;
  background: var(--yellow);
  border: none;
  border-radius: 999px;
  box-shadow:
    0 8px 28px rgba(0, 0, 0, 0.18),
    0 2px 6px rgba(0, 0, 0, 0.12);
  cursor: pointer;
}

.fb-preview-fab:hover {
  filter: brightness(0.96);
}

.fb-preview-fab:focus-visible {
  outline: 2px solid var(--text);
  outline-offset: 3px;
}

/* An explicit `display` would otherwise override the `hidden` attribute's `display: none`. */
.fb-preview-form[hidden] {
  display: none;
}

.fb-preview-form {
  display: flex;
  flex-direction: column;
  gap: 9px;
  width: min(340px, 80vw);
  padding: 14px;
  background: var(--bg, #fff);
  border: 1px solid var(--fb-line);
  border-radius: 14px;
  box-shadow:
    0 8px 28px rgba(0, 0, 0, 0.18),
    0 2px 6px rgba(0, 0, 0, 0.12);
}

.fb-preview-note {
  width: 100%;
  resize: vertical;
  padding: 9px 10px;
  font-family: var(--font-body);
  font-size: 13px;
  color: var(--text-body);
  background: transparent;
  border: 1px solid var(--fb-line);
  border-radius: 9px;
  box-sizing: border-box;
}

.fb-preview-note:focus-visible {
  outline: 2px solid var(--text);
  outline-offset: 1px;
}

.fb-preview-send {
  align-self: flex-start;
  padding: 8px 18px;
  font-family: var(--font-body);
  font-size: 13px;
  font-weight: 600;
  color: #000;
  background: var(--yellow);
  border: none;
  border-radius: 999px;
  cursor: pointer;
}

.fb-preview-send:hover {
  filter: brightness(0.96);
}

.fb-preview-status:not(:empty) {
  margin: 0;
  font-family: var(--font-body);
  font-size: 12px;
  color: var(--text-muted);
}
"""#
    static let briefLookingAheadCSS = #"""
/* ============================================================
   Morning Brief — Looking Ahead section.
   Loaded only when the looking-ahead feature flag is on.
   ============================================================ */

/* Local tokens layered on top of style.css. Kept here so the file is
   self-contained when style.css doesn't ship the same names yet. */
:root {
  --looking-ahead-bleed: clamp(20px, 3vw, 40px);
}


/* ── Section + card layout ───────────────────────────── */

.looking-ahead-section {
  row-gap: 0;
  margin-top: clamp(56px, calc(8.4vw - 14px), 84px);
}

.looking-ahead-card {
  position: relative;
  isolation: isolate;
  grid-column: 1 / -1;
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  align-items: start;
  column-gap: 1.5rem;
  row-gap: clamp(20px, 3vw, 28px);
  padding-top: clamp(24px, 3vw, 36px);
  padding-bottom: clamp(14px, 2vw, 22px);
}

.looking-ahead-card::before {
  content: '';
  position: absolute;
  z-index: -1;
  top: 0;
  bottom: 0;
  left: calc(-1 * var(--looking-ahead-bleed));
  right: calc(-1 * var(--looking-ahead-bleed));
  border-radius: 15px;
  background: rgba(255, 255, 255, 0.5);
  box-shadow:
    0.5px 0.5px 0.5px rgba(0, 0, 0, 0.08),
    0 0 3px rgba(0, 0, 0, 0.06);
}


/* ── Intro column (title + lead + toast) ─────────────── */

.looking-ahead-card .looking-ahead-intro.section-title-group {
  grid-column: 1 / 5;
  grid-row: 1;
  align-self: start;
  position: relative;
  z-index: 3;
  display: flex;
  flex-direction: column;
  gap: 0.65em;
  max-width: 26ch;
  pointer-events: none;
}

.looking-ahead-title.section-title {
  /* Other section titles inherit `.section-title`'s clamp(20px, 3vw, 32px)
     left inset, but the looking-ahead card's intro column starts flush with
     column 1 — keeping the inset would push the title right of the lead
     paragraph below it. Zero it out so the title lines up with the lead. */
  padding-left: 0;
  opacity: 1;
}

.looking-ahead-lead {
  font-size: 1em;
  line-height: 1.7;
  color: var(--text-body);
  text-wrap: pretty;
}

@media screen and (min-width: 901px) {
  .looking-ahead-lead {
    padding-right: 16px;
  }
}

/* ── "Saved." toast ───────────────────────────────────── */

.looking-ahead-toast {
  display: inline-flex;
  align-items: center;
  gap: 0.35em;
  width: max-content;
  max-width: none;
  flex-shrink: 0;
  align-self: flex-start;
  margin: 0;
  padding: 0.4em 0.55em;
  font-size: 0.75em;
  line-height: 1.25;
  white-space: nowrap;
  color: rgba(40, 40, 45, 0.78);
  background: color-mix(in srgb, var(--yellow) 32%, #fff);
  border: none;
  border-radius: 8px;
  opacity: 0;
  visibility: hidden;
  transition:
    opacity 0.28s ease,
    visibility 0.28s ease;
}

.looking-ahead-toast[hidden] {
  display: none;
}

.looking-ahead-toast--visible {
  opacity: 1;
  visibility: visible;
}

.looking-ahead-toast__check {
  flex-shrink: 0;
  width: 0.85em;
  height: 0.85em;
  background: transparent;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 14 14' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M3.5 7.5L6 10L10.5 4.5' stroke='%231a1a1a' stroke-width='1.75' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
  background-size: contain;
  background-position: center;
  background-repeat: no-repeat;
}

@media (prefers-reduced-motion: reduce) {
  .looking-ahead-toast {
    transition: none;
  }
}


/* ── Stack column (prompt + textarea) ────────────────── */

.looking-ahead-stack {
  grid-column: 1 / -1;
  grid-row: 1;
  position: relative;
  z-index: 1;
  display: grid;
  grid-template-columns: repeat(12, minmax(0, 1fr));
  column-gap: 1.5rem;
  align-self: start;
  row-gap: clamp(20px, 3vw, 28px);
  min-width: 0;
}

.looking-ahead-prompt {
  grid-column: 6 / -1;
  grid-row: 1;
  margin: 0;
  font-family: var(--font-display);
  font-style: italic;
  font-weight: 400;
  font-size: 0.85em;
  line-height: 1.4;
  color: var(--text-muted);
}


/* ── Field shell (shared between custom + simple variants) ── */

.looking-ahead-custom-wrap {
  --looking-ahead-field-pad-x: 0.75rem;
  --looking-ahead-field-pad-y: 0.625rem;
  --looking-ahead-field-bg: #ffffff;
  --looking-ahead-field-bg-hover: #fbfbfb;
  display: flex;
  align-items: center;
  min-width: 0;
  min-height: 2.75em;
  padding: 0 var(--looking-ahead-field-pad-x);
  border-radius: 12px;
  background: var(--looking-ahead-field-bg);
  border: 0.5px solid rgba(0, 0, 0, 0.08);
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
  transition:
    background 0.2s ease,
    border-color 0.2s ease,
    box-shadow 0.2s ease;
}

.looking-ahead-custom-wrap.is-multiline {
  align-items: flex-start;
  padding-top: var(--looking-ahead-field-pad-y);
  padding-bottom: var(--looking-ahead-field-pad-y);
}

.looking-ahead-custom-wrap:not(:focus-within):hover {
  background: var(--looking-ahead-field-bg-hover);
}

.looking-ahead-custom-wrap:focus-within {
  background: var(--looking-ahead-field-bg-hover);
  border-color: rgba(0, 0, 0, 0.1);
}

.looking-ahead-custom-input {
  display: block;
  flex: 1 1 auto;
  width: 100%;
  min-width: 0;
  margin: 0;
  padding: 0;
  border: none;
  background: transparent;
  font-family: var(--font-body);
  font-size: 1em;
  font-weight: 400;
  line-height: 1.7;
  color: var(--text-body);
  resize: none;
  overflow: hidden;
  white-space: nowrap;
}

.looking-ahead-custom-wrap.is-multiline .looking-ahead-custom-input {
  white-space: pre-wrap;
}

.looking-ahead-custom-input::placeholder {
  font-weight: 400;
  color: rgba(60, 60, 67, 0.6);
  transition: opacity 0.2s ease, color 0.2s ease;
}

.looking-ahead-custom-wrap:focus-within .looking-ahead-custom-input,
.looking-ahead-custom-input:focus {
  color: var(--text-body);
}

.looking-ahead-custom-wrap:focus-within .looking-ahead-custom-input::placeholder {
  opacity: 1;
  color: rgba(60, 60, 67, 0.6);
}

.looking-ahead-custom-input:focus {
  outline: none;
}


/* ── Simple variant (textarea-only) ──────────────────── */

.looking-ahead-section--simple .looking-ahead-prompt {
  grid-column: 6 / -1;
  grid-row: 1;
  align-self: start;
  padding-top: 0.48em;
}

.looking-ahead-section--simple .looking-ahead-intent {
  grid-column: 6 / -1;
  grid-row: 2;
  min-width: 0;
  pointer-events: auto;
  margin-bottom: 10px;
}

.looking-ahead-section--simple .looking-ahead-intent-wrap {
  margin: 0 10px 0 0;
  min-height: calc(1.7em * 5 + var(--looking-ahead-field-pad-y) * 2);
  align-items: flex-start;
  padding-top: var(--looking-ahead-field-pad-y);
  padding-bottom: var(--looking-ahead-field-pad-y);
  background: var(--looking-ahead-field-bg);
}

.looking-ahead-section--simple .looking-ahead-intent-wrap:not(:focus-within):hover,
.looking-ahead-section--simple .looking-ahead-intent-wrap:focus-within {
  background: var(--looking-ahead-field-bg);
}

.looking-ahead-section--simple .looking-ahead-intent-wrap:focus-within {
  border-color: rgba(0, 0, 0, 0.2);
}

.looking-ahead-section--simple .looking-ahead-intent-input::placeholder {
  color: rgba(60, 60, 67, 0.48);
}

.looking-ahead-section--simple .looking-ahead-intent-wrap:focus-within .looking-ahead-intent-input,
.looking-ahead-section--simple .looking-ahead-intent-input:focus {
  color: var(--text);
}

.looking-ahead-section--simple .looking-ahead-intent-wrap:focus-within .looking-ahead-intent-input::placeholder {
  opacity: 0.35;
  color: rgba(60, 60, 67, 0.45);
}

.looking-ahead-section--simple .looking-ahead-intent-input {
  min-height: calc(1.7em * 5);
  color: var(--text);
  white-space: pre-wrap;
  resize: none;
  overflow: hidden;
}

.looking-ahead-section--simple .looking-ahead-intent-wrap.is-multiline .looking-ahead-intent-input {
  overflow: auto;
}

@media screen and (min-width: 901px) {
  .looking-ahead-section--simple .looking-ahead-stack {
    row-gap: clamp(10px, 1.5vw, 16px);
  }

  .looking-ahead-section--simple .looking-ahead-prompt {
    font-size: 0.95em;
    line-height: 1.45;
  }
}


/* ── Responsive: Tablet ──────────────────────────────── */

@media screen and (max-width: 1160px) {
  .looking-ahead-card .looking-ahead-intro.section-title-group {
    grid-column: 1 / 5;
    grid-row: 1;
    max-width: 22ch;
  }

  .looking-ahead-lead {
    font-size: 0.95em;
    line-height: 1.65;
  }

  .looking-ahead-prompt {
    grid-column: 5 / -1;
  }

  .looking-ahead-section--simple .looking-ahead-prompt,
  .looking-ahead-section--simple .looking-ahead-intent {
    grid-column: 5 / -1;
  }
}

@media screen and (min-width: 901px) and (max-width: 1100px) {
  .looking-ahead-card .looking-ahead-intro.section-title-group {
    max-width: 32ch;
  }

  .looking-ahead-lead {
    font-size: 0.88em;
    line-height: 1.65;
    padding-right: 28px;
    max-width: none;
  }

  .looking-ahead-toast {
    align-items: flex-start;
    width: auto;
    max-width: 17ch;
    white-space: normal;
    text-wrap: pretty;
  }

  .looking-ahead-toast__check {
    margin-top: 0.12em;
  }
}


/* ── Responsive: Single column ────────────────────────── */

@media screen and (max-width: 900px) {
  .looking-ahead-card {
    row-gap: 20px;
  }

  .looking-ahead-card .looking-ahead-intro.section-title-group {
    grid-column: 1 / -1;
    grid-row: auto;
    max-width: none;
    width: 100%;
  }

  .looking-ahead-lead {
    max-width: none;
    width: 100%;
    padding-right: 0;
  }

  .looking-ahead-stack {
    grid-column: 1 / -1;
    grid-row: auto;
  }

  .looking-ahead-prompt {
    grid-column: 1 / -1;
    grid-row: auto;
  }

  .looking-ahead-section--simple .looking-ahead-prompt,
  .looking-ahead-section--simple .looking-ahead-intent {
    grid-column: 1 / -1;
    grid-row: auto;
  }

  .looking-ahead-section--simple .looking-ahead-prompt {
    text-align: left;
    justify-self: stretch;
    width: 100%;
    max-width: none;
    padding-top: 0;
  }

  .looking-ahead-section--simple .looking-ahead-stack {
    justify-items: stretch;
  }

  .looking-ahead-section--simple .looking-ahead-intent {
    margin-left: -9px;
    margin-right: -9px;
    margin-bottom: 0;
  }

  .looking-ahead-section--simple .looking-ahead-intent-wrap {
    margin-right: 0;
  }

  .looking-ahead-card .looking-ahead-intro .looking-ahead-toast {
    position: absolute;
    top: 0;
    right: 0;
    left: auto;
    z-index: 4;
    margin: 0;
    pointer-events: none;
  }
}


/* ── Dark mode ──────────────────────────────────────────── */

@media (prefers-color-scheme: dark) {
  :root {
    --placeholder: rgba(235, 225, 210, 0.52);
    --placeholder-muted: rgba(235, 225, 210, 0.4);
    --surface-raised: #1a1a1a;
    --surface-hover: #1e1e1e;
  }

  .looking-ahead-card::before {
    background: rgba(255, 255, 255, 0.08);
    box-shadow:
      0.5px 0.5px 0.5px rgba(0, 0, 0, 0.2),
      0 0 3px rgba(0, 0, 0, 0.15);
  }

  .looking-ahead-custom-wrap {
    --looking-ahead-field-bg: var(--surface-raised);
    --looking-ahead-field-bg-hover: var(--surface-hover);
    background: var(--looking-ahead-field-bg);
    border-color: rgba(255, 255, 255, 0.12);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.25);
  }

  .looking-ahead-custom-wrap:focus-within {
    border-color: rgba(255, 255, 255, 0.16);
  }

  .looking-ahead-section--simple .looking-ahead-intent-wrap:not(:focus-within):hover,
  .looking-ahead-section--simple .looking-ahead-intent-wrap:focus-within {
    background: var(--looking-ahead-field-bg);
  }

  .looking-ahead-section--simple .looking-ahead-intent-wrap:focus-within {
    border-color: rgba(255, 255, 255, 0.28);
  }

  .looking-ahead-section--simple .looking-ahead-intent-wrap:focus-within .looking-ahead-intent-input,
  .looking-ahead-section--simple .looking-ahead-intent-input:focus {
    color: var(--text);
  }

  .looking-ahead-section--simple .looking-ahead-intent-input::placeholder {
    color: var(--placeholder-muted);
  }

  .looking-ahead-section--simple .looking-ahead-intent-wrap:focus-within .looking-ahead-intent-input::placeholder {
    opacity: 0.35;
    color: var(--placeholder-muted);
  }

  .looking-ahead-custom-input::placeholder {
    color: var(--placeholder);
  }

  .looking-ahead-custom-wrap:focus-within .looking-ahead-custom-input,
  .looking-ahead-custom-input:focus {
    color: var(--text-body);
  }

  .looking-ahead-custom-wrap:focus-within .looking-ahead-custom-input::placeholder {
    opacity: 1;
    color: var(--placeholder);
  }

  .looking-ahead-toast {
    color: rgba(235, 225, 210, 0.82);
    background: color-mix(in srgb, var(--yellow) 22%, #2a2a28);
  }

  .looking-ahead-toast__check {
    background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 14 14' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M3.5 7.5L6 10L10.5 4.5' stroke='%23ebe1d2' stroke-width='1.75' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");
  }

}
"""#
    static let briefAppJS = #"""
// ============================================================
// Morning Brief Template — app.js
// Renders all sections from JSON data in #brief-data by cloning
// HTML <template> elements. No manual DOM construction needed —
// designers can edit the templates directly in index.html.
// ============================================================

function getSourceFromUrl(url) {
    try {
        const host = new URL(url).hostname;
        if (host === "slack.com" || host.endsWith(".slack.com")) return { iconId: "slack-icon", name: "Slack" };
        if (host === "notion.com" || host.endsWith(".notion.com") || host === "notion.so" || host.endsWith(".notion.so")) return { iconId: "notion-icon", name: "Notion" };
        if (host === "confluence.com" || host.endsWith(".confluence.com") || host === "confluence.io" || host.endsWith(".confluence.io")) return { iconId: "confluence-icon", name: "Confluence" };
        if (host === "jira.com" || host.endsWith(".jira.com")) return { iconId: "jira-icon", name: "Jira" };
        if (host === "loom.com" || host.endsWith(".loom.com")) return { iconId: "loom-icon", name: "Loom" };
        if (host === "mail.google.com") return { iconId: "gmail-icon", name: "Gmail" };
        if (host === "calendar.google.com") return { iconId: "gcal-icon", name: "Google Calendar" };
        if (host === "drive.google.com" || host === "docs.google.com" || host === "sheets.google.com" || host === "slides.google.com" || host === "forms.google.com") return { iconId: "gdrive-icon", name: "Google Drive" };
        if (host === "linkedin.com" || host.endsWith(".linkedin.com")) return { iconId: "linkedin-icon", name: "LinkedIn" };
        if (host === "github.com" || host.endsWith(".github.com")) return { iconId: "github-icon", name: "GitHub" };
        if (host === "linear.app" || host.endsWith(".linear.app")) return { iconId: "linear-icon", name: "Linear" };
        if (host === "amplitude.com" || host.endsWith(".amplitude.com")) return { iconId: "amplitude-icon", name: "Amplitude" };
        const path = new URL(url).pathname;
        if ((host === "atlassian.net" || host.endsWith(".atlassian.net")) && path.startsWith("/wiki")) return { iconId: "confluence-icon", name: "Confluence" };
        if (host === "atlassian.net" || host.endsWith(".atlassian.net")) return { iconId: "jira-icon", name: "Jira" };
    } catch {}
    return null;
}

// ── Load data and render ────────────────────────────────

const data = JSON.parse(document.getElementById("brief-data").textContent);
const briefDate = new Date(
    (data.header && data.header.date_time) || Date.now(),
);
const dateKey = briefDate.toDateString().replace(/\W+/g, "-").toLowerCase();

document.addEventListener("DOMContentLoaded", init);

// Painting filename is fixed at the destination by the harness, so the page
// statically references this URL — the agent's JSON cannot influence which
// file is loaded.
const PAINTING_URL = "paintings/painting.jpg";

function init() {
    feedbackEnabled = typeof window.renderBriefFeedback === "function";
    renderBrief();
    setDateTime();
    if (data.painting) {
        applyPainting(data.painting.caption);
    }
    initCaptionScrollFade();
    initStarBadgeTooltips();
    initTodoStickyHover();
    initTodoCompletionClose();
    renderFooterSources(data.footer && data.footer.sources);
    initFooterReveal();
    if (isAllTodosDone()) {
        syncTodoCompletionState({ celebrate: false });
    }
    // Feedback layer — only registered when feedback.js was shipped into the
    // artifact (gated by contextBuilderMorningBriefFeedbackEnabled). Runs last so it can
    // walk every rendered section/item.
    if (typeof window.renderBriefFeedback === "function") {
        window.renderBriefFeedback(data);
    }
}

// ── Template Cloning ────────────────────────────────────

function clone(id) {
    return document
        .getElementById(id)
        .content.firstElementChild.cloneNode(true);
}

// ── Brief Renderer ──────────────────────────────────────

function renderBrief() {
    const content = document.getElementById("briefContent");

    // Blurb below painting
    if (data.header && data.header.greeting) {
        const blurb = document.getElementById("briefBlurb");
        if (blurb) setText(blurb, data.header.greeting);
    }

    // 0. What-this-is intro — the brief's purpose + a privacy note.
    // Framing scaffolding, not agent data; kept scannable and quiet so daily readers glance past it.
    renderIntro(content);

    // 1a. Proactive Work (Hive already started this for you)
    if (data.proactive_work) {
        const proSection = clone("section-template");
        proSection.classList.add("brief-section--boxed", "proactive-section");
        setText(proSection.querySelector(".section-title"), "Started for you in a new tab");

        const proFragment = document.createDocumentFragment();
        const proCard = clone("proactive-work-template");
        if (data.proactive_work.title) {
            setText(proCard.querySelector(".proactive-title"), data.proactive_work.title);
        } else {
            proCard.querySelector(".proactive-title").remove();
        }
        setText(proCard.querySelector(".proactive-reasoning"), data.proactive_work.reasoning);

        while (proCard.firstChild) {
            proFragment.appendChild(proCard.firstChild);
        }
        proSection.querySelector(".section-body").appendChild(proFragment);
        content.appendChild(proSection);
    }

    // 1b. UCB to-dos
    const todos = Array.isArray(data.top_todos) ? data.top_todos.slice(0, 10) : [];
    // Stamp each to-do's position in the combined list before splitting into
    // sections — a stable per-item identity for saved checkbox state, unique across
    // both sections (the list is already in the order the ranker chose).
    todos.forEach((todo, i) => { if (todo && typeof todo === "object") todo._briefIndex = i; });
    const nowItems = todos.filter((todo) => todoTier(todo) !== "later");
    const laterItems = todos.filter((todo) => todoTier(todo) === "later");
    renderSection(content, "Top to-dos", nowItems, buildTodoItem, {
        inline: true,
        sectionId: "todos",
        // The training-data ask references rating + text boxes, which only exist when feedback.js
        // shipped (contextBuilderMorningBriefFeedbackEnabled). With feedback off there's nothing to
        // rate or type into, so drop the ask rather than point at controls that aren't there.
        note: feedbackEnabled
            ? {
                eyebrow: "How to rate this",
                body: "Rate each item below — or edit the phrasing and timing to your **ideal**. Your adjustments teach Hive how to brief you better.",
            }
            : null,
    });
    renderSection(content, "For later", laterItems, buildTodoItem, {
        inline: true,
        sectionId: "todos",
    });

    // 2. High-value work Hive can help move forward
    renderSection(content, "Suggested tasks", data.tasks, buildTaskItem, { sectionId: "task_suggestions" });
}

function renderSection(container, title, items, buildFn, opts = {}) {
    if (!Array.isArray(items) || items.length === 0) return;
    const { inline = false, sectionId = null, feedbackMeta = null, contentSelector = null, note = null } = opts;
    const section = clone("section-template");
    if (inline) section.classList.add("brief-section--inline");
    setText(section.querySelector(".section-title"), title);
    const body = section.querySelector(".section-body");
    // Optional boxed instruction callout (eyebrow + rich body) telling the reader how to rate this
    // section. Styled by .section-note.
    if (note) {
        const noteEl = document.createElement("div");
        noteEl.className = "section-note";
        const noteEyebrow = document.createElement("div");
        noteEyebrow.className = "section-note-eyebrow";
        noteEyebrow.textContent = note.eyebrow;
        noteEl.appendChild(noteEyebrow);
        const noteBody = document.createElement("p");
        noteBody.className = "section-note-body";
        setRichText(noteBody, note.body);
        noteEl.appendChild(noteBody);
        section.querySelector(".section-title").insertAdjacentElement("afterend", noteEl);
    }
    if (sectionId && feedbackEnabled) section.dataset.fbSectionId = sectionId;
    items.forEach((item, i) => {
        const el = buildFn(item, i);
        // Simple item sections tag generically here. `contentSelector` keeps the feedback slot in
        // the content column.
        if (feedbackEnabled && feedbackMeta && contentSelector && el) {
            const target = el.querySelector(contentSelector);
            if (target) target.appendChild(makeFeedbackSlot(el, feedbackMeta(item, i)));
        }
        body.appendChild(el);
    });
    container.appendChild(section);
}

// ── Intro banner (purpose + privacy) ────────────────────
// Static (not agent-generated) framing for the daily brief; the full privacy note sits
// behind a <details> disclosure so returning readers can glance past it.
function renderIntro(container) {
    const section = document.createElement("section");
    section.className = "brief-intro";

    const eyebrow = document.createElement("div");
    eyebrow.className = "brief-intro-eyebrow";
    eyebrow.textContent = "Your daily Hive brief";
    section.appendChild(eyebrow);

    const mission = document.createElement("p");
    mission.className = "brief-intro-mission";
    setRichText(mission, "Hive assembles this brief from **your** browsing — the tabs, history, and sources you actually spend time with — so every morning starts with what matters to you, not a feed.");
    section.appendChild(mission);

    // The "especially need" line asks for input (ratings + free-text ideals), which only render
    // when feedback.js shipped. Omit it when feedback is off so we don't ask for unavailable input.
    if (feedbackEnabled) {
        const need = document.createElement("p");
        need.className = "brief-intro-need";
        setRichText(need, "**This week we especially need:** your ideal to-dos, in your own words.");
        section.appendChild(need);
    }

    const privacy = document.createElement("details");
    privacy.className = "brief-intro-privacy";
    const summary = document.createElement("summary");
    setRichText(summary, "Your brief is assembled locally from your Hive history and tabs.");
    privacy.appendChild(summary);
    const detail = document.createElement("p");
    detail.className = "brief-intro-privacy-detail";
    detail.textContent = "Nothing is uploaded: the brief is generated on your Mac from local browsing data and never leaves the device. Clear your Hive history and the brief resets with it.";
    privacy.appendChild(detail);
    section.appendChild(privacy);

    container.appendChild(section);
}

// ── Feedback tagging ────────────────────────────────────
//
// The in-brief feedback layer (feedback.js, when shipped) is generic: it walks
// `[data-fb-section-id]` sections and every `[data-fb-uid]` (rate-able item) within them.
// Each rate-able item drops a `.fb-controls-slot` inside its content column (via
// `makeFeedbackSlot`); feedback.js fills each slot by uid, so placement lives with the item
// that knows its own layout. New surfaces get covered just by doing the same.
//
// `blockKey` is the authoritative UCB op key the eval-intake join anchors to — the key the agent
// copied from each block's `[blockKey=…]` marker. Many rendered rows can share one (a project's
// next steps all carry the project's key); a keyless row stays rate-able but is dropped at export.
// We never re-derive a key from the title, since a recomputed slug can't join back to the op log.
//
// Set once at init() from whether feedback.js shipped; gates all tagging so the
// brief is byte-for-byte unchanged when the flag is off.
let feedbackEnabled = false;

// Monotonic per-render id pairing each rendered row with its own slot. This, not `blockKey`, is the
// pairing key: rows can share a blockKey (a project's next steps), and pairing by it would collapse
// their controls onto one slot.
let feedbackUid = 0;

// Stamp the feedback attributes on `itemEl` and return a slot to drop wherever
// the item's controls should render (its content column). feedback.js pairs the
// slot to the item by the unique `data-fb-uid`.
function makeFeedbackSlot(itemEl, meta) {
    tagFeedbackItem(itemEl, meta);
    const uid = String(feedbackUid++);
    itemEl.dataset.fbUid = uid;
    const slot = document.createElement("span");
    slot.className = "fb-controls-slot";
    slot.dataset.fbSlot = uid;
    return slot;
}

function displayRank(item, index) {
    const parsed = Number(item.rank);
    return Number.isFinite(parsed) ? parsed : index + 1;
}

function todoTier(item) {
    const tier = String((item && item.tier) || "").trim().toLowerCase();
    // Focus lane emits now/later; the default ranker emits primary/secondary/watch.
    // "later" and "watch" sink to the For-later section; everything else stays in Top to-dos.
    return tier === "later" || tier === "watch" ? "later" : "now";
}

function tagFeedbackItem(el, meta) {
    if (!el || !meta) return;
    // Authoritative UCB op key the eval-intake join anchors to; unset for a keyless item, which
    // export drops rather than join on a non-key. The slot's `data-fb-uid` is the rate-able marker.
    if (meta.blockKey != null) el.dataset.fbBlockKey = meta.blockKey;
    el.dataset.fbType = meta.type;
    if (meta.rank != null) el.dataset.fbRank = String(meta.rank);
    // Snapshot of what the brief said for this item (the anchor a confirmation carries so a verifier
    // row needn't resolve the op). Source-derived from `meta.text`, not the DOM, so template
    // scaffolding — e.g. a project's static "Next steps" label — stays out of it. One line.
    if (meta.text != null) {
        const snapshot = String(meta.text).replace(/\s+/g, " ").trim();
        if (snapshot) el.dataset.fbText = snapshot;
    }
}

// The brief-rendered text for a rate-able item, composed from the source fields its builder paints
// (title/body/description) and joined with an em dash; empty parts dropped.
function feedbackSnapshotText(parts) {
    return parts.filter((part) => typeof part === "string" && part.trim()).join(" — ");
}

function todoFeedbackMeta(item, index) {
    return {
        type: "todo",
        blockKey: item.block_key,
        rank: displayRank(item, index),
        text: feedbackSnapshotText([item.title]),
    };
}

// ── Safety Helpers ───────────────────────────────────────

function isSafeUrl(url) {
    try {
        const parsed = new URL(url);
        if (parsed.protocol === "https:" || parsed.protocol === "http:") return true;
        // dia-report: is a first-party deep-link scheme; only the `chat` host is safe for
        // LLM-provided URLs. Privileged hosts — notably `connect`, which starts app-connection
        // OAuth — must originate only from first-party UI (the Connect Apps pills, which build the
        // URL in connect-apps.js and bypass this check), never from brief content the model emits.
        if (parsed.protocol === "dia-report:") return parsed.host === "chat";
        return false;
    } catch {
        return false;
    }
}

function buildChatDeepLink(prompt) {
    if (!prompt) return "#";
    const params = new URLSearchParams({ q: prompt });
    return "dia-report://chat?" + params.toString();
}

/** Always set text content, never innerHTML. */
function setText(el, value) {
    el.textContent = value ?? "";
}

/**
 * Render limited inline emphasis — `**bold**` and `*italic*` — as real <strong>/<em>
 * nodes (never innerHTML). Used for scannable to-do/next-step text. Unmatched markers
 * render as literal characters.
 */
function setRichText(el, value) {
    if (!el) return;
    el.textContent = "";
    const parts = String(value ?? "").split(/(\*\*[^*]+\*\*|\*[^*]+\*)/g);
    parts.forEach((part) => {
        if (!part) return;
        if (part.length > 4 && part.startsWith("**") && part.endsWith("**")) {
            const strong = document.createElement("strong");
            strong.textContent = part.slice(2, -2);
            el.appendChild(strong);
        } else if (part.length > 2 && part.startsWith("*") && part.endsWith("*")) {
            const em = document.createElement("em");
            em.textContent = part.slice(1, -1);
            el.appendChild(em);
        } else {
            el.appendChild(document.createTextNode(part));
        }
    });
}

// ── Build an item (New Updates / On Your Radar) ─────────

function buildItem(item, index) {
    const el = clone("item-template");

    setText(el.querySelector(".item-num"), String(index + 1).padStart(2, "0"));

    const title = el.querySelector(".item-title");
    const tag = el.querySelector(".item-tag");

    // Insert title text/link before the inline tag span
    if (item.source_url && isSafeUrl(item.source_url)) {
        const a = document.createElement("a");
        a.href = item.source_url;
        a.target = "_blank";
        a.rel = "noopener";
        setText(a, item.title);
        title.insertBefore(a, tag);
    } else {
        title.insertBefore(document.createTextNode(item.title), tag);
    }

    if (item.label) {
        setText(tag, item.label);
        if (item.label_style === "active") {
            tag.className = "item-tag tag-active";
        }
    } else {
        tag.remove();
    }

    const bodyP = el.querySelector(".item-text p");
    setText(bodyP, item.body);
    if (item.source_url && isSafeUrl(item.source_url)) {
        const icon = buildSourceIcon(item.source_url);
        if (icon) {
            bodyP.appendChild(document.createTextNode(" "));
            bodyP.appendChild(icon);
        }
    }
    appendAvatars(bodyP, item.avatar_urls);

    // Bullets (optional)
    const bullets = el.querySelector(".item-bullets");
    if (item.bullets && item.bullets.length) {
        item.bullets.forEach((b) => {
            const li = document.createElement("li");
            setText(li, b);
            bullets.appendChild(li);
        });
    } else {
        bullets.remove();
    }

    return el;
}

// ── Build a to-do item ──────────────────────────────────

function buildTodoItem(item, index) {
    const el = clone("todo-item-template");
    // Rank from the UCB ranker (coerce numeric strings); fall back to document order.
    const rank = displayRank(item, index);
    // Key saved state by the item's stable position in the combined list, not its
    // rank — an identity, not a priority, and unique across both to-do sections.
    const position = item && item._briefIndex != null ? item._briefIndex : index;
    const key = "brief-" + dateKey + "-todo-" + position;
    setText(el.querySelector(".todo-rank"), String(rank).padStart(2, "0"));

    if (item.time_sensitive) {
        el.classList.add("todo-item--time-sensitive");
        const flag = el.querySelector(".todo-flag");
        if (flag) {
            setText(flag, item.due_label ? item.due_label : "Time-sensitive");
            flag.hidden = false;
        }
    }

    const input = el.querySelector('input[type="checkbox"]');
    input.checked = localStorage.getItem(key) === "1";
    input.addEventListener("change", () => {
        localStorage.setItem(key, input.checked ? "1" : "0");
        playPop(input.checked);
        if (!input.checked) {
            // Re-opening a to-do dismisses any sticky completion state.
            todoCompletionDismissed = false;
        }
        syncTodoCompletionState({ celebrate: input.checked && isAllTodosDone() });
    });

    const label = el.querySelector(".todo-label");
    if (item.source_url && isSafeUrl(item.source_url)) {
        const a = document.createElement("a");
        a.href = item.source_url;
        a.target = "_blank";
        a.rel = "noopener";
        setText(a, item.title);
        label.appendChild(a);
    } else {
        setText(label, item.title);
    }
    if (item.source_url && isSafeUrl(item.source_url)) {
        const icon = buildSourceIcon(item.source_url);
        if (icon) {
            label.appendChild(document.createTextNode(" "));
            label.appendChild(icon);
        }
    }
    appendAvatars(label, item.avatar_urls);

    setRichText(el.querySelector(".todo-context"), item.body);

    // CTA pill. The agent only emits `cta_label` + `cta_prompt` when the
    // `clia-morning-brief-todos-ctas` flag is on (see spec.yaml). If absent,
    // we leave the pill `hidden` so the layout stays untouched.
    const cta = el.querySelector(".todo-dia-btn");
    if (typeof item.cta_prompt === "string" && typeof item.cta_label === "string" && item.cta_prompt && item.cta_label) {
        wireTodoCta(cta, item);
    } else if (cta) {
        cta.remove();
    }

    if (feedbackEnabled) {
        el.querySelector(".todo-content").appendChild(makeFeedbackSlot(el, todoFeedbackMeta(item, index)));
    }

    return el;
}

function wireTodoCta(cta, item) {
    const label = (item.cta_label || "").trim();
    const prompt = (item.cta_prompt || "").trim();
    if (!label || !prompt) { cta.remove(); return; }

    const deepLink = buildChatDeepLink(prompt);
    cta.href = isSafeUrl(deepLink) ? deepLink : "#";
    cta.hidden = false;
    cta.dataset.chatMessage = prompt;
    setText(cta.querySelector(".todo-dia-btn-label"), label);
    cta.setAttribute("aria-label", `${label} with Hive in Chat`);

    // Feeds the shared #star-tooltip-popover (initStarBadgeTooltips reads these
    // data-* attrs) so the to-do CTA tooltip reads consistently across the brief.
    cta.dataset.tooltipHeadline = "Start a chat about this";
    cta.dataset.tooltipBody = prompt;
    cta.dataset.tooltipBodyPresentation = "prompt";
}

// ── Build a task item ──────────────────────────────────

function buildTaskItem(item) {
    const el = clone("task-item-template");
    const taskKey = item.block_key;

    const title = el.querySelector(".task-title");
    if (item.source_url && isSafeUrl(item.source_url)) {
        const link = document.createElement("a");
        link.href = item.source_url;
        link.target = "_blank";
        link.rel = "noopener";
        setText(link, item.title || "");
        title.appendChild(link);
        const icon = buildSourceIcon(item.source_url);
        if (icon) {
            title.appendChild(document.createTextNode(" "));
            title.appendChild(icon);
        }
    } else {
        setText(title, item.title || "");
    }

    const desc = el.querySelector(".task-desc");
    if (item.description) {
        setText(desc, item.description);
    } else {
        desc.remove();
    }

    if (feedbackEnabled) {
        const slot = makeFeedbackSlot(el, {
            type: "task",
            blockKey: taskKey,
            rank: null,
            text: feedbackSnapshotText([item.title, item.description]),
        });
        el.querySelector(".item-text").insertAdjacentElement("afterend", slot);
    }

    return el;
}

// ── Avatars ──────────────────────────────────────────────

function appendAvatars(parentEl, urls) {
    if (!Array.isArray(urls) || urls.length === 0) return;
    const safe = urls.filter(isSafeUrl).slice(0, 3);
    if (safe.length === 0) return;

    safe.forEach((url) => {
        const img = document.createElement("img");
        img.className = "avatar-img";
        img.alt = "";
        img.loading = "lazy";
        img.onerror = () => { img.style.display = "none"; };
        img.src = url;
        parentEl.appendChild(img);
    });
}

// ── Source Icons ─────────────────────────────────────────

function buildSourceIcon(sourceUrl) {
    const source = getSourceFromUrl(sourceUrl);
    if (!source) return null;

    const iconTemplate = document.getElementById(source.iconId);
    if (!iconTemplate) return null;

    const el = clone("source-icon-template");
    el.href = isSafeUrl(sourceUrl) ? sourceUrl : "#";
    el.prepend(iconTemplate.content.firstElementChild.cloneNode(true));
    setText(el.querySelector(".source-tip"), "Open in " + source.name);

    // Random tilt for visual variety
    const tilt = (Math.random() * 3 - 1.5).toFixed(1);
    const hoverTilt = (Math.random() * 20 - 10).toFixed(0);
    el.style.setProperty("--tilt", tilt + "deg");
    el.style.setProperty("--hover-tilt", hoverTilt + "deg");

    return el;
}

// ── Helpers ──────────────────────────────────────────────


// ── DateTime (derived from header.date_time, set once) ──

function setDateTime() {
    const days = [
        "Sunday",
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
    ];
    const months = [
        "JAN",
        "FEB",
        "MAR",
        "APR",
        "MAY",
        "JUN",
        "JUL",
        "AUG",
        "SEP",
        "OCT",
        "NOV",
        "DEC",
    ];

    const dayEl = document.getElementById("heroDay");
    if (dayEl) setText(dayEl, days[briefDate.getDay()] + " Brief");

    const dateEl = document.getElementById("heroDate");
    if (dateEl) {
        const dd = String(briefDate.getDate()).padStart(2, "0");
        setText(dateEl, dd + " " + months[briefDate.getMonth()] + " " + briefDate.getFullYear());
    }

    const timeEl = document.getElementById("heroTime");
    if (timeEl) {
        const h = briefDate.getHours();
        const m = String(briefDate.getMinutes()).padStart(2, "0");
        const ampm = h >= 12 ? "PM" : "AM";
        const h12 = String(h % 12 || 12).padStart(2, "0");
        setText(timeEl, h12 + ":" + m + " " + ampm);
    }
}

// ── Painting ────────────────────────────────────────────

function applyPainting(captionText) {
    const img = document.getElementById("paintingImg");
    const caption = document.getElementById("paintingCaption");
    if (!img || !caption) return;

    img.classList.remove("loaded");
    caption.classList.remove("visible");

    const loader = new Image();
    loader.onload = () => {
        img.src = PAINTING_URL;
        requestAnimationFrame(() => img.classList.add("loaded"));
        setText(caption, captionText);
        caption.classList.add("visible");
    };
    loader.onerror = () => {
        console.warn("Image failed to load:", PAINTING_URL);
    };
    loader.src = PAINTING_URL;
}

function initCaptionScrollFade() {
    const caption = document.getElementById("paintingCaption");
    if (!caption) return;
    const fadeStart = 40;
    const fadeEnd = 200;

    window.addEventListener(
        "scroll",
        () => {
            const y = window.scrollY;
            if (y <= fadeStart) caption.style.opacity = "";
            else if (y >= fadeEnd) caption.style.opacity = "0";
            else
                caption.style.opacity = String(
                    1 - (y - fadeStart) / (fadeEnd - fadeStart),
                );
        },
        { passive: true },
    );
}

// ── Schedule Hover ──────────────────────────────────────

// ── Star badge tooltips ─────────────────────────────────
// One #star-tooltip-popover for all .push-badge / .prep-badge (replaces per-badge
// .star-tip + title=). Copy comes from data-tooltip-* on the anchor; badges must
// not use title= or the browser tooltip would duplicate this UI.

const STAR_TOOLTIP_CHAT_PATH_D =
    "M0.823639 6.625H0.198639H0.823639ZM14.8236 6.625H15.4486V6.625H14.8236ZM5.31583 12.292L5.48822 11.6912C5.39879 11.6656 5.30476 11.6602 5.21299 11.6755L5.31583 12.292ZM0.919342 13.0254L1.02209 13.6419L1.02218 13.6419L0.919342 13.0254ZM0.674225 12.6338L0.165564 12.2706L0.165373 12.2709L0.674225 12.6338ZM2.23184 10.4521L2.7405 10.8153C2.9114 10.576 2.89229 10.2498 2.69462 10.0321L2.23184 10.4521ZM0.823639 6.625H1.44864C1.44864 4.79108 2.22642 3.46361 3.38879 2.58212C4.56963 1.68664 6.17648 1.23328 7.81709 1.25047C9.45743 1.26766 11.0696 1.75475 12.2563 2.66295C13.4267 3.55874 14.1986 4.87161 14.1986 6.625H14.8236H15.4486C15.4486 4.45206 14.4705 2.78352 13.016 1.67031C11.5777 0.569508 9.68984 0.0200216 7.83019 0.000538468C5.9708 -0.0189418 4.07764 0.490951 2.63348 1.58613C1.17085 2.69531 0.198639 4.38592 0.198639 6.625H0.823639ZM14.8236 6.625H14.1986C14.1986 8.79258 13.0143 10.3083 11.3207 11.1738C9.60408 12.0511 7.39119 12.2373 5.48822 11.6912L5.31583 12.292L5.14344 12.8927C7.33493 13.5216 9.87594 13.316 11.8896 12.2869C13.9263 11.246 15.4486 9.3407 15.4486 6.625H14.8236ZM5.31583 12.292L5.21299 11.6755L0.816504 12.4089L0.919342 13.0254L1.02218 13.6419L5.41866 12.9085L5.31583 12.292ZM0.919342 13.0254L0.816592 12.4089C1.14339 12.3544 1.37854 12.7226 1.18308 12.9967L0.674225 12.6338L0.165373 12.2709C-0.288578 12.9074 0.25604 13.7696 1.02209 13.6419L0.919342 13.0254ZM0.674225 12.6338L1.18289 12.997L2.7405 10.8153L2.23184 10.4521L1.72318 10.089L0.165565 12.2706L0.674225 12.6338ZM2.23184 10.4521L2.69462 10.0321C1.9339 9.19403 1.44864 8.07188 1.44864 6.625H0.823639H0.198639C0.198639 8.37631 0.795428 9.79962 1.76907 10.8722L2.23184 10.4521Z";

function createStarTooltipChatIconSvg() {
    const svgNS = "http://www.w3.org/2000/svg";
    const svg = document.createElementNS(svgNS, "svg");
    svg.setAttribute("width", "16");
    svg.setAttribute("height", "14");
    svg.setAttribute("viewBox", "0 0 16 14");
    svg.setAttribute("fill", "none");
    const path = document.createElementNS(svgNS, "path");
    path.setAttribute("opacity", "0.88");
    path.setAttribute("d", STAR_TOOLTIP_CHAT_PATH_D);
    path.setAttribute("fill", "#1a1a1a");
    svg.appendChild(path);
    return svg;
}

function positionStarTooltip(anchor, popover) {
    const rect = anchor.getBoundingClientRect();
    const margin = 10;
    const gap = 0;
    const pw = popover.offsetWidth;
    const ph = popover.offsetHeight;
    let left = rect.left + rect.width / 2 - pw / 2;
    left = Math.max(margin, Math.min(left, window.innerWidth - pw - margin));
    let top = rect.top - gap - ph;
    popover.classList.remove("star-tooltip-popover--below");
    if (top < margin) {
        top = rect.bottom + gap;
        popover.classList.add("star-tooltip-popover--below");
    }
    popover.style.left = `${Math.round(left)}px`;
    popover.style.top = `${Math.round(top)}px`;
}

function initStarBadgeTooltips() {
    let popover = document.getElementById("star-tooltip-popover");
    if (!popover) {
        popover = document.createElement("div");
        popover.id = "star-tooltip-popover";
        popover.className = "star-tooltip-popover";
        popover.setAttribute("role", "tooltip");
        popover.setAttribute("aria-hidden", "true");
        const head = document.createElement("div");
        head.className = "star-tooltip-popover__head";
        const iconWrap = document.createElement("span");
        iconWrap.className = "star-tooltip-popover__icon";
        iconWrap.setAttribute("aria-hidden", "true");
        iconWrap.appendChild(createStarTooltipChatIconSvg());
        const headText = document.createElement("span");
        headText.className = "star-tooltip-popover__head-text";
        head.appendChild(iconWrap);
        head.appendChild(headText);
        const body = document.createElement("div");
        body.className = "star-tooltip-popover__body";
        const bodyMsg = document.createElement("div");
        bodyMsg.className = "star-tooltip-popover__body-msg";
        body.appendChild(bodyMsg);
        popover.appendChild(head);
        popover.appendChild(body);
        document.body.appendChild(popover);
    }

    const headTextEl = popover.querySelector(".star-tooltip-popover__head-text");
    const bodyWrap = popover.querySelector(".star-tooltip-popover__body");
    const bodyMsgEl = popover.querySelector(".star-tooltip-popover__body-msg");

    let showTimer = null;
    let activeAnchor = null;

    function hide() {
        clearTimeout(showTimer);
        showTimer = null;
        if (activeAnchor) {
            activeAnchor.removeAttribute("aria-describedby");
        }
        popover.setAttribute("aria-hidden", "true");
        popover.classList.remove("star-tooltip-popover--visible");
        activeAnchor = null;
    }

    function show(anchor) {
        if (anchor.classList.contains("hidden")) return;
        const headline = anchor.dataset.tooltipHeadline || "";
        const body = anchor.dataset.tooltipBody || "";
        if (!headline && !body) return;

        if (activeAnchor && activeAnchor !== anchor) {
            activeAnchor.removeAttribute("aria-describedby");
        }

        if (headTextEl) setText(headTextEl, headline);

        if (!bodyWrap) return;

        if (bodyMsgEl) {
            const asPrompt =
                anchor.dataset.tooltipBodyPresentation === "prompt";
            if (!body) {
                bodyWrap.setAttribute("hidden", "");
            } else {
                bodyWrap.removeAttribute("hidden");
                if (asPrompt) {
                    bodyWrap.classList.add("star-tooltip-popover__body--prompt");
                } else {
                    bodyWrap.classList.remove(
                        "star-tooltip-popover__body--prompt",
                    );
                }
                setText(bodyMsgEl, body);
            }
        } else {
            setText(bodyWrap, body);
            if (body) bodyWrap.removeAttribute("hidden");
            else bodyWrap.setAttribute("hidden", "");
        }

        popover.classList.add("star-tooltip-popover--visible");
        anchor.setAttribute("aria-describedby", "star-tooltip-popover");
        popover.setAttribute("aria-hidden", "false");
        activeAnchor = anchor;

        // Popover size is wrong until after first paint; second pass fixes placement.
        requestAnimationFrame(() => {
            positionStarTooltip(anchor, popover);
            requestAnimationFrame(() => positionStarTooltip(anchor, popover));
        });
    }

    function scheduleShow(anchor) {
        clearTimeout(showTimer);
        showTimer = setTimeout(() => show(anchor), 450);
    }

    function bind(anchor) {
        if (!anchor || anchor.dataset.starTooltipBound === "1") return;
        anchor.dataset.starTooltipBound = "1";

        anchor.addEventListener("mouseenter", () => scheduleShow(anchor));
        anchor.addEventListener("mouseleave", hide);

        anchor.addEventListener("focusin", () => scheduleShow(anchor));
        anchor.addEventListener("focusout", (e) => {
            if (!e.relatedTarget || !anchor.contains(e.relatedTarget)) {
                hide();
            }
        });
    }

    document.querySelectorAll(".push-badge, .prep-badge, .todo-dia-btn.todo-chat-prompt").forEach(bind);

    function reflowIfActive() {
        if (activeAnchor) positionStarTooltip(activeAnchor, popover);
    }
    window.addEventListener("scroll", reflowIfActive, true);
    window.addEventListener("resize", reflowIfActive);
}

// ── To-Do Check Sound + Completion Fanfare (WebAudio, self-contained) ──
//
// Ported from christine-sandbox/morningbrief/daily-brief-alt-app.js
// (commit ce33f21). Two synthesized sounds — playPop for individual checkbox
// toggles (rising blip on check, falling blip on uncheck), and a 4-note
// arpeggio fanfare + shimmer sweep for the all-done celebration. No audio
// assets shipped: the artifact stays self-contained.

function playPop(checked) {
    try {
        const ctx = new (window.AudioContext || window.webkitAudioContext)();
        const t = ctx.currentTime;
        const gain = ctx.createGain();
        gain.connect(ctx.destination);

        const osc = ctx.createOscillator();
        osc.type = "sine";
        if (checked) {
            osc.frequency.setValueAtTime(400, t);
            osc.frequency.exponentialRampToValueAtTime(800, t + 0.025);
            osc.frequency.exponentialRampToValueAtTime(600, t + 0.05);
            gain.gain.setValueAtTime(0.12, t);
            gain.gain.exponentialRampToValueAtTime(0.001, t + 0.06);
            osc.connect(gain);
            osc.start(t);
            osc.stop(t + 0.06);
        } else {
            osc.frequency.setValueAtTime(600, t);
            osc.frequency.exponentialRampToValueAtTime(350, t + 0.04);
            gain.gain.setValueAtTime(0.07, t);
            gain.gain.exponentialRampToValueAtTime(0.001, t + 0.05);
            osc.connect(gain);
            osc.start(t);
            osc.stop(t + 0.05);
        }
        setTimeout(() => ctx.close(), 200);
    } catch (e) { /* Web Audio unavailable */ }
}

function playCompletionFanfare() {
    try {
        const ctx = new (window.AudioContext || window.webkitAudioContext)();
        const t = ctx.currentTime;
        const master = ctx.createGain();
        master.gain.setValueAtTime(0.18, t);
        master.gain.exponentialRampToValueAtTime(0.001, t + 0.85);
        master.connect(ctx.destination);

        const notes = [
            { freq: 523.25, type: "sine",     at: 0,    dur: 0.28 },
            { freq: 659.25, type: "sine",     at: 0.09, dur: 0.28 },
            { freq: 783.99, type: "sine",     at: 0.18, dur: 0.28 },
            { freq: 1046.5, type: "triangle", at: 0.28, dur: 0.42 },
        ];

        notes.forEach(({ freq, type, at, dur }) => {
            const osc = ctx.createOscillator();
            const g = ctx.createGain();
            osc.type = type;
            osc.frequency.value = freq;
            const start = t + at;
            g.gain.setValueAtTime(0, start);
            g.gain.linearRampToValueAtTime(type === "triangle" ? 0.55 : 0.4, start + 0.02);
            g.gain.exponentialRampToValueAtTime(0.001, start + dur);
            osc.connect(g);
            g.connect(master);
            osc.start(start);
            osc.stop(start + dur + 0.02);
        });

        const shimmer = ctx.createOscillator();
        const sg = ctx.createGain();
        shimmer.type = "sine";
        shimmer.frequency.setValueAtTime(1318, t + 0.32);
        shimmer.frequency.exponentialRampToValueAtTime(2093, t + 0.58);
        sg.gain.setValueAtTime(0.12, t + 0.32);
        sg.gain.exponentialRampToValueAtTime(0.001, t + 0.62);
        shimmer.connect(sg);
        sg.connect(master);
        shimmer.start(t + 0.32);
        shimmer.stop(t + 0.64);

        setTimeout(() => ctx.close(), 900);
    } catch (e) { /* Web Audio unavailable */ }
}

// ── To-Do Active State (hover-only) ─────────────────────
//
// One to-do at a time has `.is-active` — and only while the mouse (or
// keyboard focus) is actually on it. Leaving the list clears the active
// state; there is no default-active item on page load.

let _activeTodoItem = null;

function initTodoStickyHover() {
    // To-dos can render across more than one section ("Top to-dos" + "For later"),
    // so wire each. `setActiveTodoItem` is global, so hovering an item in either
    // section highlights it and clears the other.
    findTodosSections().forEach((section) => {
        const items = section.querySelectorAll(".todo-item");
        if (!items.length) return;

        items.forEach((item) => {
            item.addEventListener("mouseenter", () => setActiveTodoItem(item));
            item.addEventListener("focusin",    () => setActiveTodoItem(item));
        });

        // Clear on `mouseleave` of the section so transitions between two items
        // don't flicker (mouseleave doesn't fire on item-to-item transitions
        // within the section). Same idea for focus: only clear when focus
        // genuinely leaves the section, not when it moves between items.
        section.addEventListener("mouseleave", () => setActiveTodoItem(null));
        section.addEventListener("focusout", (e) => {
            if (!e.relatedTarget || !section.contains(e.relatedTarget)) {
                setActiveTodoItem(null);
            }
        });
    });
}

function setActiveTodoItem(item) {
    if (item === _activeTodoItem) return;
    _activeTodoItem?.classList.remove("is-active");
    _activeTodoItem = item;
    _activeTodoItem?.classList.add("is-active");
}

// ── To-Do Completion Popover (multi-stage sequence) ─────
//
// When every checkbox in the to-dos section is checked:
//   1. The list collapses (section gets `.is-all-done`)
//   2. After popoverRevealDelay, the completion card appears with
//      `.is-popover-visible`
//   3. With `.is-sequence-active`: badge pops in, fanfare plays, confetti
//      bursts, then content fades up in cascade
//   4. State settles to `.is-sequence-done` (final visible state)
//
// On uncheck or close-button click, everything reverses to the list view.

const COMPLETION_SEQUENCE = {
    popoverRevealDelay: 280,
    fanfareDelay:       220,
    confettiDelay:      520,
    sequenceEnd:       1900,
};

let completionSequenceTimers = [];
let todoCompletionWasAllDone = false;
let todoCompletionDismissed = false;
let _allDoneEl = null;

function clearCompletionSequenceTimers() {
    completionSequenceTimers.forEach(clearTimeout);
    completionSequenceTimers = [];
}

function findTodosSection() {
    const sections = document.querySelectorAll(".brief-section--inline");
    for (const s of sections) {
        if (s.querySelector(".todo-item")) return s;
    }
    return null;
}

// Every inline section that holds to-dos, in render order. To-dos can span two
// sections ("Top to-dos" + "For later"); completion + hover treat them as one set.
function findTodosSections() {
    return [...document.querySelectorAll(".brief-section--inline")].filter((s) => s.querySelector(".todo-item"));
}

// When the whole to-do set is done, the celebration overlays the first section;
// any later sections collapse away so the all-done state reads as one celebration,
// like the single-list standard brief.
function setSecondaryTodoSectionsCollapsed(collapsed) {
    findTodosSections().slice(1).forEach((s) => s.classList.toggle("is-todos-done-collapsed", collapsed));
}

function getTodoCheckboxes() {
    return [...document.querySelectorAll('.brief-section--inline .todo-item input[type="checkbox"]')];
}

function isAllTodosDone() {
    const boxes = getTodoCheckboxes();
    return boxes.length > 0 && boxes.every((cb) => cb.checked);
}

function ensureAllDoneEl(section) {
    if (_allDoneEl && _allDoneEl.isConnected) return _allDoneEl;
    _allDoneEl = clone("todo-all-done-template");
    section.querySelector(".section-body").appendChild(_allDoneEl);

    // Close button: dismiss the completion popover (sticky until uncheck or
    // refresh — same as Christine's prototype).
    _allDoneEl.querySelector(".todo-all-done__close")?.addEventListener("click", dismissTodoCompletion);

    return _allDoneEl;
}

function syncTodoCompletionState({ celebrate = false } = {}) {
    const section = findTodosSection();
    if (!section) return;

    const allDone = isAllTodosDone();
    const showCompletion = allDone && !todoCompletionDismissed;
    const wasShowingCompletion = todoCompletionWasAllDone;
    const isFirstCelebrate = showCompletion && celebrate && !wasShowingCompletion;

    // Collapse any secondary to-do sections so the celebration reads as one.
    setSecondaryTodoSectionsCollapsed(showCompletion);

    if (!showCompletion) {
        stopCompletion(section);
        return;
    }

    const doneEl = ensureAllDoneEl(section);
    const confettiEl = doneEl.querySelector(".todo-confetti");

    if (isFirstCelebrate) {
        clearCompletionSequenceTimers();
        doneEl.hidden = true;
        doneEl.classList.remove("is-sequence-active", "is-sequence-done", "is-popover-visible");
        section.classList.add("is-all-done");

        const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
        if (reduced) {
            revealCompletionPopover(doneEl, confettiEl);
        } else {
            completionSequenceTimers.push(
                setTimeout(
                    () => revealCompletionPopover(doneEl, confettiEl),
                    COMPLETION_SEQUENCE.popoverRevealDelay
                )
            );
        }
    } else {
        // Restoring the popover state on page load when all-done was already
        // true — no animation, no sound. Skip straight to is-sequence-done.
        section.classList.add("is-all-done");
        doneEl.hidden = false;
        doneEl.classList.add("is-popover-visible");
        if (!doneEl.classList.contains("is-sequence-active")) {
            doneEl.classList.add("is-sequence-done");
        }
    }

    todoCompletionWasAllDone = true;
}

function stopCompletion(section) {
    clearCompletionSequenceTimers();
    if (_allDoneEl) {
        _allDoneEl.querySelector(".todo-confetti")?.replaceChildren();
        _allDoneEl.hidden = true;
        _allDoneEl.classList.remove("is-sequence-active", "is-sequence-done", "is-popover-visible");
    }
    section.classList.remove("is-all-done");
    todoCompletionWasAllDone = false;
}

function revealCompletionPopover(doneEl, confettiEl) {
    if (!doneEl) return;
    doneEl.hidden = false;
    void doneEl.offsetWidth;
    doneEl.classList.add("is-popover-visible");
    runCompletionSequence(doneEl, confettiEl);
}

function runCompletionSequence(doneEl, confettiEl) {
    if (!doneEl) return;
    doneEl.classList.remove("is-sequence-done");

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduced) {
        playCompletionFanfare();
        launchTodoConfetti(confettiEl);
        doneEl.classList.add("is-sequence-done");
        return;
    }

    void doneEl.offsetWidth;
    doneEl.classList.add("is-sequence-active");

    completionSequenceTimers.push(
        setTimeout(() => playCompletionFanfare(), COMPLETION_SEQUENCE.fanfareDelay)
    );
    completionSequenceTimers.push(
        setTimeout(() => launchTodoConfetti(confettiEl), COMPLETION_SEQUENCE.confettiDelay)
    );
    completionSequenceTimers.push(
        setTimeout(() => {
            doneEl.classList.remove("is-sequence-active");
            doneEl.classList.add("is-sequence-done");
        }, COMPLETION_SEQUENCE.sequenceEnd)
    );
}

const TODO_CONFETTI_COLORS = ["#FFE500", "#FFF066", "#FFD000", "#FFEB3B", "#FFF4A3"];

function launchTodoConfetti(container) {
    if (!container || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    container.replaceChildren();
    const count = 48;
    for (let i = 0; i < count; i += 1) {
        const piece = document.createElement("span");
        const isDot = Math.random() > 0.45;
        piece.className = "todo-confetti-piece" + (isDot ? " todo-confetti-piece--dot" : " todo-confetti-piece--rect");
        const size = 5 + Math.random() * 6;
        const angle = Math.random() * Math.PI * 2;
        const distance = 70 + Math.random() * 150;
        piece.style.setProperty("--size", `${size}px`);
        piece.style.setProperty("--tx", `${Math.cos(angle) * distance}px`);
        piece.style.setProperty("--ty", `${Math.sin(angle) * distance - 20}px`);
        piece.style.setProperty("--rot", `${Math.random() * 540 - 270}deg`);
        piece.style.setProperty("--color", TODO_CONFETTI_COLORS[i % TODO_CONFETTI_COLORS.length]);
        piece.style.animationDelay = `${Math.random() * 0.12}s`;
        container.appendChild(piece);
    }
}

function dismissTodoCompletion() {
    todoCompletionDismissed = true;
    syncTodoCompletionState();
}

function initTodoCompletionClose() {
    // No-op: the close button is wired per-instance in `ensureAllDoneEl`.
    // Kept for symmetry with the other init* functions.
}

// ── Footer ──────────────────────────────────────────────
//
// The static footer (HIVE + "Made for you by Hive") is rendered in
// index.html. When the agent emits `data.footer.sources` (gated by
// `clia-morning-brief-footer-sources`), we splice an inline source list
// into the credit prose: "Made for you by Hive using your X, Y, and Z."
//
// Scroll-reveal: footer fades up the first time it enters the viewport.

function renderFooterSources(sources) {
    const credit  = document.getElementById("briefFooterCredit");
    const trailing = document.getElementById("briefFooterCreditTrailing");
    if (!credit || !trailing) return;
    if (!Array.isArray(sources) || sources.length === 0) return;

    const safe = sources.filter((s) => s && typeof s.url === "string" && isSafeUrl(s.url) && s.name).slice(0, 6);
    if (safe.length === 0) return;

    // Only reveal the "Made for you by Hive using your X, Y, Z." line when we
    // have real sources to credit. Without sources the line is meaningless,
    // so the footer collapses to just the Hive love badge.
    credit.hidden = false;

    // Build: "using your <chip1>, <chip2>, and <chipN>." — inline into the
    // credit paragraph just before the trailing period.
    const frag = document.createDocumentFragment();
    const usingYour = document.createElement("span");
    usingYour.className = "brief-footer__muted";
    usingYour.appendChild(document.createTextNode("using "));
    const em = document.createElement("em");
    em.className = "brief-footer__emph";
    setText(em, "your");
    usingYour.appendChild(em);
    frag.appendChild(usingYour);

    safe.forEach((s, i) => {
        if (i > 0) {
            const sep = document.createElement("span");
            sep.className = "brief-footer__muted";
            const isLast = i === safe.length - 1;
            setText(sep, isLast && safe.length > 2 ? ", and "
                       : isLast                      ? " and "
                       :                               ", ");
            frag.appendChild(sep);
        }
        frag.appendChild(buildFooterSourceChip(s));
    });

    // Insert before the trailing period.
    credit.insertBefore(frag, trailing);
}

function buildFooterSourceChip(source) {
    const a = document.createElement("a");
    a.className = "brief-footer__source source-ref";
    a.href = isSafeUrl(source.url) ? source.url : "#";
    a.target = "_blank";
    a.rel = "noopener";

    // Optional kind modifier so existing brand-specific tweaks pick up.
    const sourceInfo = getSourceFromUrl(source.url);
    if (sourceInfo) {
        a.classList.add("brief-footer__source--" + sourceInfo.iconId.replace("-icon", ""));
    }

    // Random tilt for visual variety, matching the source-icon pattern.
    const tilt      = (Math.random() * 3 - 1.5).toFixed(1);
    const hoverTilt = (Math.random() * 20 - 10).toFixed(0);
    a.style.setProperty("--tilt", tilt + "deg");
    a.style.setProperty("--hover-tilt", hoverTilt + "deg");

    // Source-icon SVG (cloned from the existing icon templates).
    const iconWrap = document.createElement("span");
    iconWrap.className = "source-icon";
    if (sourceInfo) {
        const tmpl = document.getElementById(sourceInfo.iconId);
        if (tmpl) iconWrap.appendChild(tmpl.content.firstElementChild.cloneNode(true));
    }
    a.appendChild(iconWrap);

    const name = document.createTextNode(" " + (source.name || ""));
    a.appendChild(name);
    return a;
}

function initFooterReveal() {
    const footer = document.querySelector(".brief-footer");
    if (!footer) return;
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
        footer.classList.add("is-visible");
        return;
    }
    const observer = new IntersectionObserver(
        ([entry]) => {
            if (!entry.isIntersecting) return;
            footer.classList.add("is-visible");
            observer.disconnect();
        },
        { threshold: 0.12, rootMargin: "0px 0px -8% 0px" }
    );
    observer.observe(footer);
}
"""#
    static let briefFeedbackJS = #"""
// ============================================================
// Morning Brief — in-brief quality feedback layer.
// Loaded only when `contextBuilderMorningBriefFeedbackEnabled` is on (the file isn't
// copied into the artifact otherwise). Registers a renderer that `app.js`
// calls at the end of `init()`, after every section is in the DOM.
//
// The form is generic: it walks `[data-fb-section-id]` sections and every
// `[data-fb-uid]` (rate-able item) within them (stamped by app.js), injects two quick taps
// per item — "is everything fully correct?" and "did you care?" — plus a "what's wrong?" note
// revealed on an incorrect mark, a per-section "did we miss anything?" question,
// and one Submit action.
//
// Submit groups the three quality signals — utility (per item), correctness
// (per item), coverage (per section) — into positive+rated count pairs per section, where the
// rated count is the denominator so Segment can report each as a percentage
// without losing sample size. It hands them to Swift in a
// `dia-artifact-interaction://ucb-mb-feedback?…` navigation (intercepted by
// ArtifactWebContentController), which fires one `ucb_morning_brief_feedback_submitted`
// Segment event per section — all sharing the brief id, so they roll back up to a brief-level
// total. The note rides the URL rather than a shared `window` queue because page scripts and
// the native-injected drain run in separate JS worlds. The full per-item payload
// (`assemblePayload`) remains the stable contract for a future depot sink; the
// justified corrections/omissions plus note-free confirmations (positive marks) also ride
// this navigation as a base64 `detail` param (`assembleEvalIntake`), which Swift routes into
// the Context Builder eval queue.
// ============================================================

(function () {
    "use strict";

    const SCHEMA_VERSION = 2;
    const PRIMARY_FEEDBACK_SECTION_ID = "todos";

    // Utility ("did you care?") is deliberately the lowest-friction input we can
    // get away with: one binary tap, distinct from correctness. Centralized here
    // so swapping to a small numeric scale later only touches this object and
    // `buildUtilityControl` — never payload assembly, which always reads
    // `entry.useful`.
    const UTILITY_INPUT = {
        mode: "binary",
        options: [
            { value: true, label: "Worth showing", glyph: "👍", aria: "Worth showing" },
            { value: false, label: "Not worth showing", glyph: "👎", aria: "Not worth showing" },
        ],
    };

    const CORRECTNESS_OPTIONS = [
        { value: true, label: "Fully correct", glyph: "✓", aria: "Mark fully correct" },
        { value: false, label: "Not fully correct", glyph: "✗", aria: "Mark not fully correct" },
    ];

    const COMPLETENESS_OPTIONS = [
        { value: true, label: "Looks complete", aria: "This section looks complete" },
        { value: false, label: "Something's missing", aria: "Something is missing from this section" },
    ];

    // Lanes whose completeness prompts render adjacently name themselves; others fall
    // back to the generic ask in buildCompletenessControl.
    const COMPLETENESS_QUESTIONS = {
        task_suggestions: "Did we miss any tasks?",
    };

    // ── DOM helpers ─────────────────────────────────────────

    function el(tag, className) {
        const node = document.createElement(tag);
        if (className) node.className = className;
        return node;
    }

    function numOr0(value) {
        return typeof value === "number" && Number.isFinite(value) ? value : 0;
    }

    function clearRequiredNoteError(note) {
        note.classList.remove("is-invalid");
        note.removeAttribute("aria-invalid");
    }

    // ── Toggle group ────────────────────────────────────────
    //
    // A small set of mutually exclusive buttons. Clicking the pressed button
    // again clears the selection back to `null` (unrated), so the payload can
    // distinguish "not rated" from "rated false". `aria-pressed` carries the
    // selected state for assistive tech and for the visible styling.

    function buildToggleGroup({ className, ariaLabel, options, showText, onChange }) {
        const group = el("span", "fb-toggle-group" + (className ? " " + className : ""));
        group.setAttribute("role", "group");
        group.setAttribute("aria-label", ariaLabel);

        const buttons = [];
        options.forEach((opt) => {
            const btn = el("button", "fb-toggle");
            btn.type = "button";
            btn.dataset.value = String(opt.value);
            btn.setAttribute("aria-pressed", "false");
            btn.setAttribute("aria-label", opt.aria || opt.label);
            if (!showText) btn.title = opt.label;

            if (opt.glyph) {
                const glyph = el("span", "fb-toggle-glyph");
                glyph.setAttribute("aria-hidden", "true");
                glyph.textContent = opt.glyph;
                btn.appendChild(glyph);
            }
            if (showText) {
                const text = el("span", "fb-toggle-text");
                text.textContent = opt.label;
                btn.appendChild(text);
            }

            btn.addEventListener("click", () => {
                const wasPressed = btn.getAttribute("aria-pressed") === "true";
                const next = wasPressed ? null : opt.value;
                buttons.forEach((b) => b.setAttribute("aria-pressed", "false"));
                if (!wasPressed) btn.setAttribute("aria-pressed", "true");
                onChange(next);
            });

            buttons.push(btn);
            group.appendChild(btn);
        });

        return group;
    }

    function labelledControl(text, controlEl) {
        const wrap = el("span", "fb-control");
        const label = el("span", "fb-control-label");
        label.textContent = text;
        wrap.appendChild(label);
        wrap.appendChild(controlEl);
        return wrap;
    }

    function buildUtilityControl(entry, onActivity) {
        // Only the binary mode is live; the config drives both render and read.
        return buildToggleGroup({
            className: "fb-useful",
            ariaLabel: "Did you care that we showed you this?",
            options: UTILITY_INPUT.options,
            onChange: (value) => {
                entry.useful = value;
                onActivity();
            },
        });
    }

    // ── Per-item controls ───────────────────────────────────

    function buildItemControls(entry, onActivity) {
        const controls = el("span", "fb-item-controls");
        controls.setAttribute("aria-label", "Rate this item");

        // Justification for an incorrect mark, revealed only on ✗ (mirrors the per-section
        // "what's missing?" note).
        const note = el("textarea", "fb-correct-note");
        note.rows = 2;
        note.placeholder = "What's wrong?";
        note.autocomplete = "off";
        note.required = true;
        note.setAttribute("aria-label", "What's wrong?");
        note.setAttribute("aria-required", "true");
        note.hidden = true;
        entry.correctnessNoteField = note;
        note.addEventListener("input", () => {
            entry.correctnessNote = note.value.trim() || null;
            if (entry.correctnessNote) clearRequiredNoteError(note);
            onActivity();
        });

        controls.appendChild(
            labelledControl(
                "Fully correct?",
                buildToggleGroup({
                    className: "fb-correct",
                    ariaLabel: "Is everything in this item fully correct?",
                    options: CORRECTNESS_OPTIONS,
                    onChange: (value) => {
                        entry.correct = value;
                        // The note only makes sense for an incorrect mark; cleared if flipped back.
                        note.hidden = value !== false;
                        if (value !== false) {
                            note.value = "";
                            entry.correctnessNote = null;
                            clearRequiredNoteError(note);
                        }
                        onActivity();
                    },
                }),
            ),
        );

        controls.appendChild(labelledControl("Useful?", buildUtilityControl(entry, onActivity)));

        controls.appendChild(note);
        return controls;
    }

    // ── Per-section completeness ────────────────────────────

    function buildCompletenessControl(completeness, onActivity, questionText) {
        const wrap = el("div", "fb-completeness");

        const question = el("p", "fb-completeness-q");
        question.textContent = questionText || "Did we miss anything?";
        wrap.appendChild(question);

        const note = el("textarea", "fb-missing-note");
        note.rows = 2;
        note.placeholder = "What's missing?";
        note.autocomplete = "off";
        note.required = true;
        note.setAttribute("aria-label", "What's missing?");
        note.setAttribute("aria-required", "true");
        note.hidden = true;
        completeness.missingNoteField = note;
        note.addEventListener("input", () => {
            completeness.missingNote = note.value.trim() || null;
            if (completeness.missingNote) clearRequiredNoteError(note);
            onActivity();
        });

        const group = buildToggleGroup({
            className: "fb-complete",
            ariaLabel: "Section completeness",
            options: COMPLETENESS_OPTIONS,
            showText: true,
            onChange: (value) => {
                completeness.complete = value;
                // The note only makes sense when something is missing and is cleared if the user flips back.
                note.hidden = value !== false;
                if (value !== false) {
                    note.value = "";
                    completeness.missingNote = null;
                    clearRequiredNoteError(note);
                }
                onActivity();
            },
        });

        wrap.appendChild(group);
        wrap.appendChild(note);
        return wrap;
    }

    // ── Submit (fixed pill, revealed once anything is rated) ────

    // Counts the signals the user has given, so the pill only appears after a
    // real interaction and can show how much is queued.
    function countFeedback(model) {
        let n = 0;
        model.sections.forEach((section) => {
            if (section.completeness.complete !== null || section.completeness.missingNote) n += 1;
            section.items.forEach((item) => {
                if (item.correct !== null || item.useful !== null) n += 1;
            });
        });
        return n;
    }

    function missingRequiredNoteFields(model) {
        const fields = [];
        model.sections.forEach((section) => {
            section.items.forEach((item) => {
                if (item.correct === false && !item.correctnessNote) fields.push(item.correctnessNoteField);
            });
            if (section.completeness.complete === false && !section.completeness.missingNote) {
                fields.push(section.completeness.missingNoteField);
            }
        });
        return fields;
    }

    function validateRequiredNotes(model) {
        const fields = missingRequiredNoteFields(model);
        fields.forEach((field) => {
            field.classList.add("is-invalid");
            field.setAttribute("aria-invalid", "true");
        });
        const first = fields[0];
        if (!first) return true;
        first.focus({ preventScroll: true });
        first.scrollIntoView({ behavior: "smooth", block: "center" });
        return false;
    }

    function showGradingCelebration() {
        const celebration = el("div", "fb-celebration");
        celebration.setAttribute("role", "status");
        celebration.setAttribute("aria-live", "polite");

        const confettiField = el("div", "fb-celebration__confetti-field");
        confettiField.setAttribute("aria-hidden", "true");
        const colors = ["#ffe500", "#ff5c5c", "#4f7cff", "#2fb66d", "#ffffff"];
        for (let index = 0; index < 28; index += 1) {
            const confetti = el("span", "fb-celebration__confetti" + (index % 4 === 0 ? " is-round" : ""));
            const angle = (index / 28) * Math.PI * 2;
            const distance = 150 + (index % 5) * 24;
            confetti.style.setProperty("--fb-x", Math.cos(angle) * distance + "px");
            confetti.style.setProperty("--fb-y", Math.sin(angle) * distance + "px");
            confetti.style.setProperty("--fb-r", 180 + (index % 7) * 55 + "deg");
            confetti.style.setProperty("--fb-delay", (index % 6) * 0.035 + "s");
            confetti.style.setProperty("--fb-color", colors[index % colors.length]);
            confettiField.appendChild(confetti);
        }

        const card = el("div", "fb-celebration__card");
        const mark = el("span", "fb-celebration__mark");
        mark.setAttribute("aria-hidden", "true");
        mark.textContent = "✦";
        const eyebrow = el("p", "fb-celebration__eyebrow");
        eyebrow.textContent = "Grade received";
        const title = el("p", "fb-celebration__title");
        title.textContent = "Thank you for grading!";
        const message = el("p", "fb-celebration__message");
        message.textContent = "You just made tomorrow's brief a little sharper.";
        card.append(mark, eyebrow, title, message);
        celebration.append(confettiField, card);
        document.body.appendChild(celebration);
        setTimeout(() => celebration.remove(), 3200);
    }

    function createFixedSubmit(model, data) {
        const button = el("button", "fb-submit-fixed");
        button.type = "button";
        button.setAttribute("aria-hidden", "true");

        const label = el("span", "fb-submit-fixed__label");
        label.textContent = "Submit feedback";
        const count = el("span", "fb-submit-fixed__count");
        count.setAttribute("aria-hidden", "true");
        button.append(label, count);

        let done = false;
        button.addEventListener("click", () => {
            if (done) return;
            if (!validateRequiredNotes(model)) return;
            done = true;
            submitToSegment(model, data);
            showGradingCelebration();
            button.classList.add("is-done");
            label.textContent = "Thank you! ✦";
            count.textContent = "";
            setTimeout(() => button.classList.remove("is-visible"), 2400);
        });

        return {
            el: button,
            sync() {
                if (done) return;
                const n = countFeedback(model);
                button.classList.toggle("is-visible", n > 0);
                button.setAttribute("aria-hidden", n > 0 ? "false" : "true");
                count.textContent = n > 0 ? String(n) : "";
            },
        };
    }

    // ── Payload assembly ────────────────────────────────────

    function mergeTokens(target, byModel) {
        if (!byModel || typeof byModel !== "object") return;
        Object.keys(byModel).forEach((family) => {
            const usage = byModel[family] || {};
            const totals = target[family] || {
                inputTokens: 0,
                outputTokens: 0,
                cacheCreationTokens: 0,
                cacheReadTokens: 0,
            };
            totals.inputTokens += numOr0(usage.input_tokens);
            totals.outputTokens += numOr0(usage.output_tokens);
            totals.cacheCreationTokens += numOr0(usage.cache_create);
            totals.cacheReadTokens += numOr0(usage.cache_read);
            target[family] = totals;
        });
    }

    // Maps the brief JSON's snake_case `production` block to the camelCase payload
    // contract. `tokensByModel` is the whole-pipeline total: the brief run plus the
    // upstream UCB sessions (folded in once the client passes them through).
    function buildProductionBlock(production) {
        const out = { latencyMs: null, tokensByModel: {} };
        if (!production || typeof production !== "object") return out;
        if (typeof production.latency_ms === "number") out.latencyMs = production.latency_ms;
        mergeTokens(out.tokensByModel, production.tokens_by_model);
        mergeTokens(out.tokensByModel, production.upstream_tokens_by_model);
        return out;
    }

    // One positive+rated count-pair row per rated section. `rated` is the denominator
    // (items/sections the user actually rated), so a 1/1 stays distinguishable from a 50/60
    // once expressed as a percentage. A section with nothing rated emits no row; summing a
    // submission's rows (joined on briefId) recovers the brief-level total.
    function aggregateMetricsBySection(model) {
        return model.sections
            .map((section) => {
                const agg = {
                    sectionId: section.sectionId,
                    utilityPositive: 0,
                    utilityRated: 0,
                    correctnessCorrect: 0,
                    correctnessRated: 0,
                    coverageComplete: 0,
                    coverageRated: 0,
                };
                if (section.completeness.complete !== null) {
                    agg.coverageRated += 1;
                    if (section.completeness.complete === true) agg.coverageComplete += 1;
                }
                section.items.forEach((item) => {
                    if (item.useful !== null) {
                        agg.utilityRated += 1;
                        if (item.useful === true) agg.utilityPositive += 1;
                    }
                    if (item.correct !== null) {
                        agg.correctnessRated += 1;
                        if (item.correct === true) agg.correctnessCorrect += 1;
                    }
                });
                return agg;
            })
            .filter((agg) => agg.utilityRated > 0 || agg.correctnessRated > 0 || agg.coverageRated > 0);
    }

    // Hand the per-section signals to Swift in the navigation URL itself. A shared `window` queue
    // can't be used: page scripts and the native-injected drain run in separate JS worlds and
    // don't share globals, so a queued event never round-trips. The sections ride as one JSON
    // param in a single navigation (repeated `window.location` assignments would clobber each
    // other); Swift fires one `ucb_morning_brief_feedback_submitted` event per section, all
    // sharing the same briefId so they roll back up.
    function submitToSegment(model, data) {
        const sections = aggregateMetricsBySection(model);
        if (sections.length === 0) return;
        const params = new URLSearchParams({ sections: JSON.stringify(sections) });
        if (data.feedback_artifact_sha) params.set("briefId", data.feedback_artifact_sha);
        // The eval signals ride the same navigation as the metrics — a second `window.location`
        // assignment would clobber the first. Swift decodes `detail` into the Context Builder
        // eval-intake queue, consumed only when a runner exists.
        const intake = assembleEvalIntake(model, data);
        if (intake.corrections.length > 0 || intake.omissions.length > 0 || intake.confirmations.length > 0) {
            params.set("detail", utf8ToBase64(JSON.stringify(intake)));
        }
        window.location.href = "dia-artifact-interaction://ucb-mb-feedback?" + params.toString();
    }

    // Encode a JS string as base64 of its UTF-8 bytes; `btoa` alone mangles non-ASCII notes.
    function utf8ToBase64(str) {
        const bytes = new TextEncoder().encode(str);
        let binary = "";
        for (let i = 0; i < bytes.length; i += 1) binary += String.fromCharCode(bytes[i]);
        return btoa(binary);
    }

    // The eval-intake payload: the signals worth turning into Context Builder synthesis eval
    // cases. A per-item ✗ with a "what's wrong?" note is a correction (keyed by the item's UCB
    // block key); a per-section "something's missing" with a note is an omission (keyed by
    // section/lane). A per-item positive mark (✓ correct or 👍 worth showing) is a confirmation —
    // note-free and high-volume, the retention signal a cheaper distilled model must not regress.
    // Both quality bits ride along so triage can tell a hard retention target (correct + useful)
    // from a correct-but-unwanted op. An empty payload (no corrections, omissions, or
    // confirmations) means there is nothing to triage.
    function assembleEvalIntake(model, data) {
        const corrections = [];
        const omissions = [];
        const confirmations = [];
        model.sections.forEach((section) => {
            const missing = (section.completeness.missingNote || "").trim();
            if (section.completeness.complete === false && missing) {
                omissions.push({ sectionId: section.sectionId, note: missing });
            }
            section.items.forEach((item) => {
                // An incorrect item is a correction (note-gated) and never a confirmation, even
                // if also marked useful — wrong content can't be a retention target.
                if (item.correct === false) {
                    const note = (item.correctnessNote || "").trim();
                    // A keyless row has no op to anchor to — render it on the brief, but never export it.
                    if (note && item.blockKey) {
                        corrections.push({
                            blockKey: item.blockKey,
                            type: item.type,
                            displayedRank: item.displayedRank,
                            note: note,
                            text: item.text || null,
                        });
                    }
                    return;
                }
                // A positive mark (✓ correct or 👍 worth showing) is a confirmation. Carry both bits
                // raw — downstream weighs correct+useful (a must-generate target) against a
                // correct-but-unwanted op. `correct` is true|null here; `useful` is true|false|null.
                if ((item.correct === true || item.useful === true) && item.blockKey) {
                    confirmations.push({
                        blockKey: item.blockKey,
                        type: item.type,
                        displayedRank: item.displayedRank,
                        correct: item.correct,
                        useful: item.useful,
                        text: item.text || null,
                    });
                }
            });
        });
        return {
            schemaVersion: SCHEMA_VERSION,
            briefId: data.feedback_artifact_sha || null,
            generatedAt: (data.header && data.header.date_time) || null,
            corrections: corrections,
            omissions: omissions,
            confirmations: confirmations,
        };
    }

    function assemblePayload(model, data) {
        const header = data.header || {};
        return {
            schemaVersion: SCHEMA_VERSION,
            submittedAt: new Date().toISOString(),
            brief: {
                briefId: data.feedback_artifact_sha || null,
                userId: data.user_id || null,
                generatedAt: header.date_time || null,
            },
            production: buildProductionBlock(data.production),
            sections: model.sections.map((section) => ({
                sectionId: section.sectionId,
                completeness: {
                    complete: section.completeness.complete,
                    missingNote: section.completeness.missingNote,
                },
                // `correctnessNote` is intentionally absent: this depot block carries the
                // metric signals only; justified notes route solely through assembleEvalIntake.
                items: section.items.map((item) => ({
                    blockKey: item.blockKey,
                    type: item.type,
                    displayedRank: item.displayedRank,
                    correct: item.correct,
                    useful: item.useful,
                })),
            })),
        };
    }

    // ── Freeform feedback (Context Builder) ────
    //
    // A standalone bottom-left affordance, independent of the per-item quality
    // form: a freeform note is handed to Swift via a
    // `dia-artifact-interaction://ucb-feedback?text=…` navigation (intercepted by
    // ArtifactWebContentController), carrying the note as a query param. Swift routes
    // it into the Context Builder feedback lane, which always applies the change to the
    // live op log (the brief has no inspector to show a dry-run preview). The result
    // surfaces in the inspector's Feedback tab. No-ops unless the internal-tool flag is
    // on (no runner).

    function sendFeedback(text) {
        // Carry the note in the navigation URL itself rather than a shared `window` queue: page
        // scripts and the native-injected drain run in separate JS worlds, so a queued value never
        // round-trips. Swift reads the text straight off the intercepted navigation.
        window.location.href = "dia-artifact-interaction://ucb-feedback?text=" + encodeURIComponent(text);
    }

    function renderFeedbackPreviewButton() {
        if (document.querySelector(".fb-preview")) return;

        const root = el("div", "fb-preview");

        // Collapsed state: a single prompt button. Pressing it swaps the button out for the input
        // in place; sending (or pressing Enter) swaps back and leaves a confirmation line.
        const fab = el("button", "fb-preview-fab");
        fab.type = "button";
        fab.textContent = "Feedback?";

        const form = el("div", "fb-preview-form");
        form.hidden = true;

        const note = el("textarea", "fb-preview-note");
        note.rows = 3;
        note.placeholder = "Correct, update, or reframe the understanding of your context…";
        note.setAttribute("aria-label", "Feedback for the Context Builder");

        const send = el("button", "fb-preview-send");
        send.type = "button";
        send.textContent = "Send";

        const status = el("p", "fb-preview-status");
        status.setAttribute("aria-live", "polite");

        form.append(note, send);
        root.append(fab, form, status);

        // Collapse back to the FAB without sending. Listeners that only matter while the form
        // is open are bound on show and torn down here so a collapsed widget is inert.
        function collapseForm() {
            form.hidden = true;
            fab.hidden = false;
            document.removeEventListener("keydown", onDocKeydown, true);
            document.removeEventListener("pointerdown", onDocPointerDown, true);
        }

        function onDocKeydown(event) {
            if (event.key === "Escape") {
                event.preventDefault();
                collapseForm();
            }
        }

        function onDocPointerDown(event) {
            if (!root.contains(event.target)) collapseForm();
        }

        function showForm() {
            status.textContent = "";
            fab.hidden = true;
            form.hidden = false;
            note.focus();
            document.addEventListener("keydown", onDocKeydown, true);
            document.addEventListener("pointerdown", onDocPointerDown, true);
        }

        function submit() {
            const text = note.value.trim();
            if (!text) {
                note.focus();
                return;
            }
            sendFeedback(text);
            note.value = "";
            collapseForm();
            status.textContent = "Sent — open the Context Builder dashboard to see the changes.";
        }

        fab.addEventListener("click", showForm);
        send.addEventListener("click", submit);
        // Enter submits; Shift+Enter keeps the newline for multi-line notes.
        note.addEventListener("keydown", (event) => {
            if (event.key === "Enter" && !event.shiftKey) {
                event.preventDefault();
                submit();
            }
        });

        document.body.appendChild(root);
    }

    // ── Render ──────────────────────────────────────────────

    function slotForUid(uid) {
        return uid ? document.querySelector('[data-fb-slot="' + uid + '"]') : null;
    }

    function markOptionalFeedbackSections(sectionEls) {
        const sections = Array.from(sectionEls);
        if (!sections.some(
            (sectionEl) => sectionEl.dataset.fbSectionId === PRIMARY_FEEDBACK_SECTION_ID,
        )) return;

        const optionalSections = sections.filter(
            (sectionEl) => sectionEl.dataset.fbSectionId !== PRIMARY_FEEDBACK_SECTION_ID,
        );
        if (!optionalSections.length) return;

        optionalSections.forEach((sectionEl) => {
            sectionEl.classList.add("fb-section--optional");
            const title = sectionEl.querySelector(".section-title");
            if (!title || title.querySelector(".fb-optional-badge")) return;
            const badge = el("span", "fb-optional-badge");
            badge.textContent = "Optional to grade";
            title.appendChild(badge);
        });

        const boundary = el("aside", "fb-optional-boundary");
        boundary.setAttribute("role", "note");
        const card = el("div", "fb-optional-boundary__card");
        const eyebrow = el("p", "fb-optional-boundary__eyebrow");
        eyebrow.textContent = "Optional from here on";
        const message = el("p", "fb-optional-boundary__message");
        message.textContent =
            "Top to-dos and For later are the focus. Everything below is optional to grade.";
        card.append(eyebrow, message);
        boundary.appendChild(card);
        optionalSections[0].insertAdjacentElement("beforebegin", boundary);
    }

    function renderBriefFeedback(data) {
        const sectionEls = document.querySelectorAll("[data-fb-section-id]");
        if (!sectionEls.length) return;

        markOptionalFeedbackSections(sectionEls);
        const model = { sections: [] };
        const submit = createFixedSubmit(model, data);
        const onActivity = () => submit.sync();
        // One section id can span multiple DOM blocks (to-dos render as "Top to-dos"
        // + "For later", both tagged "todos"). Merge them into a single model entry
        // per id, so the payload has one section per topic (no orphan entry with a
        // null completeness) and the "did we miss anything?" control renders once.
        const modelsById = new Map();
        // The completeness control anchors to each id's LAST DOM block, so for the
        // split to-dos it sits under "For later" — after the full list. Document
        // order means the last write per id wins.
        const lastElById = new Map();
        sectionEls.forEach((el) => lastElById.set(el.dataset.fbSectionId, el));

        sectionEls.forEach((sectionEl) => {
            const sectionId = sectionEl.dataset.fbSectionId;
            let sectionModel = modelsById.get(sectionId);
            const isNewModel = !sectionModel;
            if (isNewModel) {
                sectionModel = { sectionId, completeness: { complete: null, missingNote: null }, items: [] };
                modelsById.set(sectionId, sectionModel);
                model.sections.push(sectionModel);
            }

            sectionEl.querySelectorAll("[data-fb-uid]").forEach((itemEl) => {
                // The nearest tagged ancestor owns the item when a renderer nests sections.
                if (itemEl.closest("[data-fb-section-id]") !== sectionEl) return;
                const rank = Number(itemEl.dataset.fbRank);
                const entry = {
                    // Authoritative UCB op key; null for a keyless item, which assembleEvalIntake drops.
                    blockKey: itemEl.dataset.fbBlockKey || null,
                    type: itemEl.dataset.fbType,
                    displayedRank: Number.isFinite(rank) ? rank : null,
                    correct: null,
                    useful: null,
                    correctnessNote: null,
                    // Brief-rendered snapshot app.js stamps on `data-fb-text`: the anchor a
                    // confirmation carries so a verifier row needn't resolve the op from its key.
                    text: itemEl.dataset.fbText || null,
                };
                sectionModel.items.push(entry);
                const controls = buildItemControls(entry, onActivity);
                // app.js dropped a slot in the item's content column, paired by a
                // unique uid; fall back to a sibling if a brief predates slots.
                const slot = slotForUid(itemEl.dataset.fbUid);
                if (slot) slot.appendChild(controls);
                else itemEl.insertAdjacentElement("afterend", controls);
            });

            // Render the completeness control once per id, in its last DOM block.
            if (sectionEl === lastElById.get(sectionId)) {
                const body = sectionEl.querySelector(".section-body") || sectionEl;
                // Named sections can provide a more specific coverage question.
                body.appendChild(
                    buildCompletenessControl(
                        sectionModel.completeness,
                        onActivity,
                        COMPLETENESS_QUESTIONS[sectionId],
                    ),
                );
            }
        });

        document.body.appendChild(submit.el);
    }

    // Register on window in the browser; guarded so the module can also be
    // imported in Node/Bun (no `window`) to unit-test the pure functions below.
    if (typeof window !== "undefined") {
        window.renderBriefFeedback = renderBriefFeedback;
        // The freeform feedback button stands alone — it doesn't wait for app.js's
        // per-item render pass, so init it directly once the DOM is ready.
        if (document.readyState === "loading") {
            document.addEventListener("DOMContentLoaded", renderFeedbackPreviewButton);
        } else {
            renderFeedbackPreviewButton();
        }
    }

    // Exposed so tests exercise the *shipped* payload logic, not a copy.
    if (typeof module !== "undefined" && module.exports) {
        module.exports = {
            buildProductionBlock,
            assemblePayload,
            aggregateMetricsBySection,
            assembleEvalIntake,
            missingRequiredNoteFields,
            SCHEMA_VERSION,
        };
    }
})();
"""#
    static let briefLookingAheadJS = #"""
// ============================================================
// Morning Brief — Looking Ahead section.
// Loaded only when `cliaMorningBriefLookingAheadEnabled` is on
// (the file isn't copied into the artifact otherwise). Registers
// a renderer that `app.js` calls at the end of `renderBrief()`.
//
// Two-column card: an LLM-generated intro blurb from
// `looking_ahead_blurb` in the brief JSON (with a static fallback
// when the field is missing) on the left, and a "What do you want
// to see in tomorrow's brief?" textarea on the right. The textarea contents
// persist to localStorage on every input event so the next morning's
// brief can read them back and inject them as feedback. A brief
// "Saved." toast confirms after the user pauses typing.
// ============================================================

(function () {
    const STORAGE_KEY = "brief-looking-ahead";
    /// Milliseconds of input quiescence before the "Saved." toast appears.
    const TOAST_DEBOUNCE_MS = 700;
    /// How long the toast stays visible before fading out.
    const TOAST_VISIBLE_MS = 2200;
    /// Matches the CSS opacity/visibility transition on `.looking-ahead-toast`.
    const TOAST_FADE_MS = 280;

    /// Plain-text fallback blurb used when the agent didn't emit
    /// `looking_ahead_blurb` (older briefs, parse failures, etc.).
    /// Deliberately generic — no day name, no calendar specifics — so the
    /// fallback never asserts anything that turns out to be wrong about
    /// tomorrow. The spec.yaml example is what teaches the LLM the content
    /// shape; this is just a safe seat-filler.
    const FALLBACK_BLURB = "Looking ahead to your next brief.";

    function persistChoice(value) {
        if (value && value.length > 0) {
            localStorage.setItem(STORAGE_KEY, value);
        } else {
            localStorage.removeItem(STORAGE_KEY);
        }
    }

    function buildIntro(blurb) {
        const intro = document.createElement("div");
        intro.className = "looking-ahead-intro section-title-group";

        const title = document.createElement("h2");
        title.id = "lookingAheadTitle";
        title.className = "section-title looking-ahead-title";
        title.textContent = "Looking ahead";
        intro.appendChild(title);

        const lead = document.createElement("p");
        lead.className = "looking-ahead-lead";
        // Plain text — the agent emits `looking_ahead_blurb` as a single
        // string per the spec.yaml prompt. `textContent` keeps it safe even
        // if the model slips in markup; the previous in-prose meeting
        // tooltip is gone since the schema is now plain text.
        lead.textContent = blurb;
        intro.appendChild(lead);

        const toast = document.createElement("p");
        toast.id = "lookingAheadToast";
        toast.className = "looking-ahead-toast";
        toast.setAttribute("aria-live", "polite");
        toast.hidden = true;

        const check = document.createElement("span");
        check.className = "looking-ahead-toast__check";
        check.setAttribute("aria-hidden", "true");
        toast.appendChild(check);
        toast.append(" Saved. Dia will remember this tomorrow.");
        intro.appendChild(toast);

        return { intro, toast };
    }

    function buildStack(initialValue) {
        const stack = document.createElement("div");
        stack.className = "looking-ahead-stack";

        const prompt = document.createElement("p");
        prompt.id = "lookingAheadPrompt";
        prompt.className = "looking-ahead-prompt";
        prompt.textContent = "What do you want to see in tomorrow's brief?";
        stack.appendChild(prompt);

        const intent = document.createElement("div");
        intent.className = "looking-ahead-intent";

        const wrap = document.createElement("div");
        wrap.className = "looking-ahead-custom-wrap looking-ahead-intent-wrap";

        const textarea = document.createElement("textarea");
        textarea.id = "lookingAheadIntent";
        textarea.className = "looking-ahead-custom-input looking-ahead-intent-input";
        textarea.rows = 5;
        textarea.placeholder =
            "E.g. a recap of open PRs, prep for your 2pm, or what you missed in Slack…";
        textarea.autocomplete = "off";
        textarea.setAttribute("aria-labelledby", "lookingAheadPrompt");
        textarea.value = initialValue;

        wrap.appendChild(textarea);
        intent.appendChild(wrap);
        stack.appendChild(intent);

        return { stack, wrap, textarea };
    }

    function makeToastController(toast) {
        let fadeTimer = null;
        let hideTimer = null;

        function clearTimers() {
            if (fadeTimer) clearTimeout(fadeTimer);
            if (hideTimer) clearTimeout(hideTimer);
            fadeTimer = null;
            hideTimer = null;
        }

        return function show() {
            clearTimers();
            toast.hidden = false;
            // Force a reflow so the browser registers the `hidden -> visible`
            // transition starting state before we add the visible class.
            void toast.offsetWidth;
            toast.classList.add("looking-ahead-toast--visible");
            fadeTimer = setTimeout(() => {
                toast.classList.remove("looking-ahead-toast--visible");
                hideTimer = setTimeout(() => {
                    toast.hidden = true;
                }, TOAST_FADE_MS);
            }, TOAST_VISIBLE_MS);
        };
    }

    function syncMultilineState(wrap, textarea) {
        const isMultiline =
            textarea.value.includes("\n") ||
            textarea.scrollHeight > textarea.clientHeight + 1;
        wrap.classList.toggle("is-multiline", isMultiline);
    }

    window.renderLookingAhead = function renderLookingAhead(container, data) {
        if (!container) return;

        const stored = localStorage.getItem(STORAGE_KEY) || "";
        // `looking_ahead_blurb` is gated by `cliaMorningBriefLookingAheadEnabled`
        // on the prompt side, so older briefs (or any flag-off render path
        // that still loaded this script somehow) won't have the field. Fall
        // back to a static line rather than rendering an empty paragraph.
        const blurb =
            typeof data?.looking_ahead_blurb === "string" && data.looking_ahead_blurb.trim().length > 0
                ? data.looking_ahead_blurb
                : FALLBACK_BLURB;

        const section = document.createElement("section");
        section.className =
            "brief-section looking-ahead-section looking-ahead-section--simple";
        section.setAttribute("aria-labelledby", "lookingAheadTitle");

        const card = document.createElement("div");
        card.className = "looking-ahead-card";

        const { intro, toast } = buildIntro(blurb);
        const { stack, wrap, textarea } = buildStack(stored);

        card.appendChild(intro);
        card.appendChild(stack);
        section.appendChild(card);
        container.appendChild(section);

        const showToast = makeToastController(toast);
        let toastTimer = null;

        textarea.addEventListener("input", () => {
            persistChoice(textarea.value.trim());
            syncMultilineState(wrap, textarea);
            if (toastTimer) clearTimeout(toastTimer);
            toastTimer = setTimeout(() => {
                if (textarea.value.trim().length > 0) showToast();
            }, TOAST_DEBOUNCE_MS);
        });

        syncMultilineState(wrap, textarea);
    };
})();
"""#

    // Base64-encoded fonts (decoded lazily at serve time).
    static let fontBase64: [String: String] = [
        "Exposure-400.woff2": "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",
        "Exposure-500.woff2": "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",
        "Exposure-550.woff2": "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",
        "Exposure-550-Italic.woff2": "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",
        "Exposure-600.woff2": "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",
    ]

    /// MIME type for a web chrome path served over hive://.
    static func mimeType(forPath path: String) -> String {
        switch path {
        case "/index.html", "/": return "text/html"
        case "/styles.css", "/tokens.css": return "text/css"
        case "/app.js": return "application/javascript"
        case "/brief", "/brief/", "/brief/index.html": return "text/html"
        case "/brief/style.css", "/brief/feedback.css", "/brief/looking-ahead.css": return "text/css"
        case "/brief/app.js", "/brief/feedback.js", "/brief/looking-ahead.js": return "application/javascript"
        default:
            if path.hasPrefix("/brief/fonts/") { return "font/woff2" }
            return "application/octet-stream"
        }
    }
}
