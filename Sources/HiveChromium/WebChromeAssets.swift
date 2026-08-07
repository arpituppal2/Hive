// AUTO-GENERATED from Sources/HiveChromium/WebChrome/* — do not edit by hand.
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
<!-- Session token injected by HiveSchemeHandler at serve time. Every bridge
     call must present it; arbitrary web pages never see it. -->
<script>window.__HIVE_TOKEN = "__HIVE_TOKEN__";</script>
<script>
// CefSwift bridge shim — embedded so it's present before any page code runs.
// (Mirrors CefBridge.javascriptShim; served from our own page per CefSwift docs.)
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
<link rel="stylesheet" href="/styles.css">
</head>
<body>
<div class="ambient" aria-hidden="true">
  <div class="glow glow--indigo"></div>
  <div class="glow glow--gold"></div>
</div>

<!-- =============================================================
     WEB CHROME SHELL  (hive://start?chrome=1)
     Renders the entire browser UI: toolbar, tabs, workspaces,
     panels, command palette. Pure HTML/CSS/JS — no SwiftUI chrome.
     ============================================================= -->
<div id="chrome" class="chrome chrome--sidebar" hidden>
  <!-- Toolbar: navigation, address bar, chrome actions -->
  <header class="toolbar">
    <div class="toolbar__row" id="toolbarRow">
      <div class="navbtn" id="btnBack" title="Back (⌘[)" tabindex="-1">
        <svg viewBox="0 0 24 24" fill="none"><path d="M15 5l-7 7 7 7" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>
      </div>
      <div class="navbtn" id="btnForward" title="Forward (⌘])" tabindex="-1">
        <svg viewBox="0 0 24 24" fill="none"><path d="M9 5l7 7-7 7" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>
      </div>
      <div class="navbtn" id="btnReload" title="Reload (⌘R)" tabindex="-1">
        <svg viewBox="0 0 24 24" fill="none" class="ic-reload"><path d="M20 12a8 8 0 1 1-2.34-5.66M20 4v4h-4" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>
      </div>

      <form class="addressbar" id="addressbarForm" autocomplete="off">
        <span class="addressbar__lock" id="addrLock">
          <svg viewBox="0 0 24 24" fill="none"><rect x="5" y="10.5" width="14" height="9.5" rx="2" stroke="currentColor" stroke-width="1.8"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5" stroke="currentColor" stroke-width="1.8"/></svg>
        </span>
        <input id="addrInput" type="text" spellcheck="false" autocomplete="off"
               placeholder="Search or enter address" aria-label="Address bar">
        <div class="addressbar__progress" id="addrProgress"></div>
        <div class="addressbar__suggest" id="suggestBox" hidden></div>
      </form>

      <div class="navbtn" id="btnBookmark" title="Bookmark this page (⌘D)" tabindex="-1">
        <svg viewBox="0 0 24 24" fill="none"><path d="M6 4h12v16l-6-4.5L6 20V4Z" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/></svg>
      </div>
      <div class="navbtn" id="btnDownloads" title="Downloads (⌘⇧J)" tabindex="-1">
        <svg viewBox="0 0 24 24" fill="none"><path d="M12 4v11m0 0-4.5-4.5M12 15l4.5-4.5M5 19h14" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>
      </div>
      <div class="navbtn" id="btnSettings" title="Settings (⌘,)" tabindex="-1">
        <svg viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="3.2" stroke="currentColor" stroke-width="1.8"/><path d="M12 2.8v2.4M12 18.8v2.4M2.8 12h2.4M18.8 12h2.4M5.5 5.5l1.7 1.7M16.8 16.8l1.7 1.7M18.5 5.5l-1.7 1.7M7.2 16.8l-1.7 1.7" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg>
      </div>
    </div>
    <div class="bookmarksbar" id="bookmarksBar" hidden>
      <span class="bookmarksbar__label">Bookmarks</span>
      <div class="bookmarksbar__list" id="bookmarksList"></div>
    </div>
  </header>

  <!-- Tab list (vertical: fills the sidebar; horizontal: strip row) -->
  <div class="tabregion">
    <div class="tablist" id="tabList" role="tablist"></div>
  </div>

  <!-- New tab button -->
  <button class="newtabbtn" id="btnNewTab">
    <svg viewBox="0 0 24 24" fill="none"><path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>
    <span>New Tab</span>
  </button>

  <!-- Workspace switcher -->
  <footer class="workspacerow" id="workspaceRow"></footer>

  <!-- Panel (settings / history / bookmarks / downloads) -->
  <aside class="panel" id="panel" hidden>
    <div class="panel__head">
      <span class="panel__title" id="panelTitle">Panel</span>
      <button class="panel__close" id="btnPanelClose" title="Close panel (Esc)">
        <svg viewBox="0 0 24 24" fill="none"><path d="M6 6l12 12M18 6L6 18" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>
      </button>
    </div>
    <div class="panel__body" id="panelBody"></div>
  </aside>

  <!-- Command palette -->
  <div class="palette-backdrop" id="paletteBackdrop" hidden>
    <div class="palette" id="palette" role="dialog" aria-label="Command palette">
      <input id="paletteInput" class="palette__input" placeholder="Type a command or search tabs…" autocomplete="off" spellcheck="false">
      <div class="palette__list" id="paletteList"></div>
    </div>
  </div>

  <!-- Context menu -->
  <div class="ctxmenu" id="ctxMenu" hidden></div>
</div>

<!-- =============================================================
     START PAGE  (hive://start — content of a fresh tab)
     ============================================================= -->
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
    <input id="stageQuery" class="stage__query" type="text"
           placeholder="Search the web or enter an address…" spellcheck="false" autocomplete="off">
    <div class="stage__suggest" id="stageSuggest" hidden></div>
  </form>

  <section class="topsites" id="topSitesSection" hidden>
    <h2 class="sectionlabel">Top Sites</h2>
    <div class="topsites__grid" id="topsitesGrid"></div>
  </section>

  <section class="recent" id="recentSection" hidden>
    <h2 class="sectionlabel">Recently Visited</h2>
    <div class="recent__list" id="recentList"></div>
  </section>

  <section class="spaces" id="spacesSection" hidden>
    <h2 class="sectionlabel">Workspaces</h2>
    <div class="spaces__row" id="spacesRow"></div>
  </section>

  <div class="stage__hint" id="escHint">Press Esc to focus the page · ⌘K for commands</div>
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

  /* one accent */
  --accent: #8E5FEB;
  --accent-hover: #A07BF0;
  --accent-soft: rgba(142, 95, 235, 0.16);
  --accent-ink: #FFFFFF;

  /* ambient theme bloom (Arc: gradient warmth as atmosphere) */
  --bloom-a: rgba(142, 95, 235, 0.20);
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
    isChromePanelOpen: null, chromeMode: 'sidebar', chromeDimension: 270
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
      '<span class="tab__fav" style="background:hsl(' + hue + ',32%,48%)">' +
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

    /// MIME type for a web chrome path served over hive://.
    static func mimeType(forPath path: String) -> String {
        switch path {
        case "/index.html", "/": return "text/html"
        case "/styles.css": return "text/css"
        case "/app.js": return "application/javascript"
        default: return "application/octet-stream"
        }
    }
}
