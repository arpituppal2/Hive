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
<title>New Tab — Hive</title>
<!-- Session token injected by HiveSchemeHandler at serve time. Every bridge
     call must present it; arbitrary web pages never see it. -->
<script>window.__HIVE_TOKEN = "__HIVE_TOKEN__";</script>
<link rel="stylesheet" href="/styles.css">
</head>
<body>
  <!-- Frosted canvas glow, hand-drawn: no native chrome anywhere -->
  <div class="ambient" aria-hidden="true">
    <div class="glow glow--amber"></div>
    <div class="glow glow--gold"></div>
  </div>

  <main class="stage">
    <!-- Wordmark: Hive, not "macOS" -->
    <div class="brand">
      <div class="brand__mark" aria-hidden="true">
        <svg viewBox="0 0 32 32" fill="none">
          <path d="M16 2.5 27.5 9v14L16 29.5 4.5 23V9L16 2.5Z" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/>
          <path d="M16 2.5v27M4.5 9l23 14M27.5 9l-23 14" stroke="currentColor" stroke-width="0.7" stroke-linejoin="round" opacity="0.45"/>
        </svg>
      </div>
      <h1 class="brand__name">Hive</h1>
    </div>

    <!-- The command bar: the heart of the page. Typing anywhere focuses it. -->
    <section class="command">
      <div class="command__field">
        <svg class="command__icon" viewBox="0 0 20 20" fill="none" aria-hidden="true">
          <circle cx="9" cy="9" r="5.5" stroke="currentColor" stroke-width="1.4"/>
          <path d="m13.5 13.5 3 3" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/>
        </svg>
        <input id="query" type="text" placeholder="Search or enter an address" autocomplete="off" spellcheck="false">
        <kbd class="command__hint" id="escHint">esc</kbd>
      </div>
      <div class="suggestions" id="suggestions" hidden></div>
    </section>

    <!-- Top sites — real data from actual browsing history, never hardcoded -->
    <section class="topsites" id="topsites">
      <div class="section-head">
        <span>Top Sites</span>
      </div>
      <div class="topsites__grid" id="topsitesGrid"></div>
    </section>

    <!-- Continue browsing — recent history -->
    <section class="recent" id="recent">
      <div class="section-head">
        <span>Continue Browsing</span>
      </div>
      <div class="recent__list" id="recentList"></div>
    </section>

    <!-- Workspaces -->
    <section class="spaces" id="spaces">
      <div class="section-head">
        <span>Spaces</span>
      </div>
      <div class="spaces__row" id="spacesRow"></div>
    </section>

    <footer class="foot">
      <button class="foot__btn" data-action="settings" title="Settings">
        <svg viewBox="0 0 18 18" fill="none"><circle cx="9" cy="9" r="2.6" stroke="currentColor" stroke-width="1.3"/><path d="M9 1.5v2M9 14.5v2M1.5 9h2M14.5 9h2M3.7 3.7l1.4 1.4M12.9 12.9l1.4 1.4M14.3 3.7l-1.4 1.4M5.1 12.9l-1.4 1.4" stroke="currentColor" stroke-width="1.1" stroke-linecap="round"/></svg>
        <span>Settings</span>
      </button>
      <button class="foot__btn" data-action="history" title="History">
        <svg viewBox="0 0 18 18" fill="none"><path d="M9 3.5A5.5 5.5 0 1 0 14.5 9" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/><path d="M9 5.5V9l2.2 2.2" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/></svg>
        <span>History</span>
      </button>
      <button class="foot__btn" data-action="bookmarks" title="Bookmarks">
        <svg viewBox="0 0 18 18" fill="none"><path d="M4.5 2.5h9v13l-4.5-3-4.5 3v-13Z" stroke="currentColor" stroke-width="1.3" stroke-linejoin="round"/></svg>
        <span>Bookmarks</span>
      </button>
      <button class="foot__btn" data-action="downloads" title="Downloads">
        <svg viewBox="0 0 18 18" fill="none"><path d="M9 2.5v9M5.5 8.5 9 12l3.5-3.5" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/><path d="M2.5 14.5h13" stroke="currentColor" stroke-width="1.3" stroke-linecap="round"/></svg>
        <span>Downloads</span>
      </button>
      <button class="foot__btn" data-action="commands" title="Command Palette">
        <svg viewBox="0 0 18 18" fill="none"><rect x="3" y="3" width="4.4" height="4.4" rx="1" stroke="currentColor" stroke-width="1.2"/><rect x="10.6" y="3" width="4.4" height="4.4" rx="1" stroke="currentColor" stroke-width="1.2"/><rect x="3" y="10.6" width="4.4" height="4.4" rx="1" stroke="currentColor" stroke-width="1.2"/><path d="M10.6 12.8h4.4M12.8 10.6v4.4" stroke="currentColor" stroke-width="1.2" stroke-linecap="round"/></svg>
        <span>Commands</span>
      </button>
    </footer>

    <p class="status" id="status" hidden></p>
  </main>

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
  <script src="/app.js"></script>
</body>
</html>
"""#
    static let stylesCSS = #"""
/* ==========================================================================
   Hive Web Chrome — design system
   Hand-drawn. No native widgets. No UI frameworks. Just CSS.
   Warm near-black canvas, hairline borders, frosted floating surfaces,
   warm amber accent. Tight, dense, efficient.
   ========================================================================== */

/* ---------- Tokens ---------- */
:root {
  --canvas: #0b0c0e;
  --surface-1: #121316;
  --surface-2: #17181c;
  --surface-3: #1c1d22;
  --hairline: rgba(255, 255, 255, 0.07);
  --hairline-strong: rgba(255, 255, 255, 0.12);
  --text-1: rgba(255, 255, 255, 0.92);
  --text-2: rgba(255, 255, 255, 0.55);
  --text-3: rgba(255, 255, 255, 0.32);
  --accent: #f5a623;          /* Hive amber */
  --accent-soft: rgba(245, 166, 35, 0.14);
  --accent-glow: rgba(245, 166, 35, 0.28);
  --gold: #d97706;
  --gold-soft: rgba(245, 158, 11, 0.10);
  --danger: #f87171;
  --radius-sm: 6px;
  --radius-md: 10px;
  --radius-lg: 16px;
  --ease: cubic-bezier(0.25, 0.1, 0.25, 1);
  --spring: cubic-bezier(0.34, 1.3, 0.42, 1);
  --font: -apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI",
          "Inter", "Helvetica Neue", Arial, sans-serif;
  --mono: "SF Mono", ui-monospace, "JetBrains Mono", Menlo, monospace;
}

/* Light mode — warm paper tones matching HiveBrand light palette. */
@media (prefers-color-scheme: light) {
  :root {
    --canvas: #f7f3ec;
    --surface-1: #efe9df;
    --surface-2: #e7dfd3;
    --surface-3: #ded5c7;
    --hairline: rgba(0, 0, 0, 0.08);
    --hairline-strong: rgba(0, 0, 0, 0.13);
    --text-1: rgba(0, 0, 0, 0.88);
    --text-2: rgba(0, 0, 0, 0.55);
    --text-3: rgba(0, 0, 0, 0.35);
    --accent: #5558e6;
    --accent-soft: rgba(85, 88, 230, 0.10);
    --accent-glow: rgba(85, 88, 230, 0.18);
    --gold: #d97706;
    --gold-soft: rgba(217, 119, 6, 0.08);
    --danger: #dc2626;
  }
}

/* Light mode — component-level overrides for surfaces that embed
   raw rgba() instead of relying solely on token-level variables. */
@media (prefers-color-scheme: light) {
  /* Command bar — flip from white-tint to black-tint gradient. */
  .command__field {
    background: linear-gradient(180deg, rgba(0,0,0,0.025), rgba(0,0,0,0.005));
    box-shadow:
      0 1px 0 rgba(255,255,255,0.6) inset,
      0 2px 12px rgba(0,0,0,0.06);
  }
  .command__field:focus-within {
    box-shadow:
      0 1px 0 rgba(255,255,255,0.8) inset,
      0 0 0 1px var(--accent-soft),
      0 0 28px var(--accent-glow),
      0 2px 16px rgba(0,0,0,0.08);
  }

  /* Suggestions — dark shadow on light background. */
  .suggestions {
    background: rgba(255, 255, 255, 0.82);
    box-shadow: 0 8px 32px rgba(0,0,0,0.10), 0 2px 6px rgba(0,0,0,0.06);
  }

  /* Top site tiles — subtle dark shadow. */
  .topsite__tile {
    box-shadow: 0 2px 8px rgba(0,0,0,0.06);
  }
  .topsite:hover .topsite__tile {
    box-shadow: 0 4px 14px rgba(0,0,0,0.10), 0 0 0 1px var(--accent-soft);
  }

  /* Ambient glow — dimmed for light canvas. */
  .glow--amber {
    background: radial-gradient(circle, rgba(245, 166, 35, 0.22) 0%, transparent 65%);
  }
  .glow--gold {
    background: radial-gradient(circle, rgba(217, 119, 6, 0.06) 0%, transparent 60%);
  }

  /* Scrollbar — dark thumb on light canvas. */
  ::-webkit-scrollbar-thumb {
    background: rgba(0, 0, 0, 0.15);
    border-color: var(--canvas);
  }
  ::-webkit-scrollbar-thumb:hover { background: rgba(0, 0, 0, 0.25); }

  /* Brand mark glow — gentler in light. */
  .brand__mark {
    filter: drop-shadow(0 0 12px var(--accent-glow));
  }
}

/* ---------- Reset ---------- */
*, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
html, body { height: 100%; }
body {
  background: var(--canvas);
  color: var(--text-1);
  font-family: var(--font);
  font-size: 14px;
  line-height: 1.45;
  -webkit-font-smoothing: antialiased;
  text-rendering: optimizeLegibility;
  overflow: hidden;
  user-select: none;
}
button { font-family: inherit; color: inherit; background: none; border: none; cursor: pointer; }
input { font-family: inherit; color: inherit; border: none; outline: none; background: none; }
::-webkit-scrollbar { width: 10px; height: 10px; }
::-webkit-scrollbar-thumb { background: var(--hairline-strong); border-radius: 5px; border: 2px solid var(--canvas); }
::-webkit-scrollbar-thumb:hover { background: rgba(255, 255, 255, 0.2); }
::-webkit-scrollbar-track { background: transparent; }

/* ---------- Ambient glow ---------- */
.ambient { position: fixed; inset: 0; z-index: 0; overflow: hidden; pointer-events: none; }
.glow { position: absolute; border-radius: 50%; filter: blur(90px); opacity: 0.5; }
.glow--amber {
  width: 620px; height: 620px; top: -260px; left: 50%;
  transform: translateX(-50%);
  background: radial-gradient(circle, rgba(245, 166, 35, 0.30) 0%, transparent 65%);
}
.glow--gold {
  width: 480px; height: 480px; bottom: -240px; right: -120px;
  background: radial-gradient(circle, rgba(245, 158, 11, 0.10) 0%, transparent 60%);
}

/* ---------- Stage ---------- */
.stage {
  position: relative;
  z-index: 1;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 72px 48px 40px;
  overflow-y: auto;
}

/* ---------- Brand ---------- */
.brand { display: flex; align-items: center; gap: 12px; margin-bottom: 40px; }
.brand__mark {
  width: 40px; height: 40px;
  color: var(--accent);
  filter: drop-shadow(0 0 18px var(--accent-glow));
  animation: breathe 4s var(--ease) infinite;
}
.brand__mark svg { width: 100%; height: 100%; }
.brand__name {
  font-size: 26px;
  font-weight: 650;
  letter-spacing: -0.02em;
  color: var(--text-1);
}
@keyframes breathe {
  0%, 100% { transform: scale(1); opacity: 1; }
  50% { transform: scale(1.035); opacity: 0.92; }
}

/* ---------- Command bar ---------- */
.command {
  width: 100%;
  max-width: 640px;
  margin-bottom: 44px;
}
.command__field {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 0 18px;
  height: 52px;
  border-radius: var(--radius-lg);
  background: linear-gradient(180deg, rgba(255,255,255,0.045), rgba(255,255,255,0.02));
  border: 1px solid var(--hairline-strong);
  box-shadow:
    0 1px 0 rgba(255,255,255,0.04) inset,
    0 8px 32px rgba(0,0,0,0.45);
  backdrop-filter: blur(20px) saturate(1.4);
  -webkit-backdrop-filter: blur(20px) saturate(1.4);
  transition: border-color 0.18s var(--ease), box-shadow 0.18s var(--ease), transform 0.18s var(--spring);
}
.command__field:focus-within {
  border-color: var(--accent);
  box-shadow:
    0 1px 0 rgba(255,255,255,0.06) inset,
    0 0 0 1px var(--accent-soft),
    0 0 28px var(--accent-glow),
    0 8px 32px rgba(0,0,0,0.5);
  transform: translateY(-1px);
}
.command__icon { width: 18px; height: 18px; color: var(--text-3); flex-shrink: 0; transition: color 0.18s var(--ease); }
.command__field:focus-within .command__icon { color: var(--accent); }
.command__field input {
  flex: 1;
  height: 100%;
  font-size: 16px;
  font-weight: 450;
  letter-spacing: -0.005em;
  color: var(--text-1);
}
.command__field input::placeholder { color: var(--text-3); }
.command__hint {
  font-family: var(--mono);
  font-size: 10.5px;
  color: var(--text-3);
  border: 1px solid var(--hairline);
  border-radius: 5px;
  padding: 2px 6px;
  opacity: 0;
  transition: opacity 0.15s var(--ease);
}
.command__field:focus-within .command__hint { opacity: 1; }

/* ---------- Suggestions ---------- */
.suggestions {
  margin-top: 10px;
  border-radius: var(--radius-md);
  background: color-mix(in srgb, var(--surface-2) 88%, transparent);
  border: 1px solid var(--hairline);
  backdrop-filter: blur(24px) saturate(1.5);
  -webkit-backdrop-filter: blur(24px) saturate(1.5);
  box-shadow: 0 12px 40px rgba(0,0,0,0.5);
  overflow: hidden;
  animation: drop 0.16s var(--spring);
}
@keyframes drop {
  from { opacity: 0; transform: translateY(-4px) scale(0.985); }
  to   { opacity: 1; transform: translateY(0) scale(1); }
}
.suggestion {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 14px;
  cursor: pointer;
  border-left: 2px solid transparent;
  transition: background 0.12s var(--ease), border-color 0.12s var(--ease);
}
.suggestion:hover, .suggestion.suggestion--active {
  background: var(--accent-soft);
  border-left-color: var(--accent);
}
.suggestion__icon {
  width: 26px; height: 26px;
  flex-shrink: 0;
  border-radius: 7px;
  display: flex; align-items: center; justify-content: center;
  background: var(--surface-3);
  border: 1px solid var(--hairline);
  color: var(--text-2);
}
.suggestion__icon img { width: 16px; height: 16px; border-radius: 3px; }
.suggestion__body { flex: 1; min-width: 0; }
.suggestion__title {
  font-size: 13.5px;
  font-weight: 500;
  color: var(--text-1);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.suggestion__url {
  font-size: 11.5px;
  color: var(--text-3);
  font-family: var(--mono);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.suggestion__kind {
  font-size: 10px;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
  color: var(--text-3);
  border: 1px solid var(--hairline);
  border-radius: 4px;
  padding: 2px 6px;
  flex-shrink: 0;
}

/* ---------- Sections ---------- */
.section-head {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 14px;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.08em;
  text-transform: uppercase;
  color: var(--text-3);
}
.section-head::after {
  content: "";
  flex: 1;
  height: 1px;
  background: var(--hairline);
}

/* ---------- Top sites ---------- */
.topsites, .recent, .spaces {
  width: 100%;
  max-width: 640px;
  margin-bottom: 34px;
  opacity: 0;
  transform: translateY(10px);
  animation: rise 0.4s var(--ease) forwards;
}
.recent { animation-delay: 0.06s; }
.spaces { animation-delay: 0.12s; }
@keyframes rise {
  to { opacity: 1; transform: translateY(0); }
}
.topsites__grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(88px, 1fr));
  gap: 8px;
}
.topsite {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 16px 8px 12px;
  border-radius: var(--radius-md);
  border: 1px solid transparent;
  transition: background 0.14s var(--ease), border-color 0.14s var(--ease), transform 0.14s var(--spring);
}
.topsite:hover {
  background: var(--surface-1);
  border-color: var(--hairline);
  transform: translateY(-2px);
}
.topsite__tile {
  width: 46px; height: 46px;
  border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  background: linear-gradient(180deg, var(--surface-3), var(--surface-2));
  border: 1px solid var(--hairline);
  box-shadow: 0 2px 8px rgba(0,0,0,0.3);
  overflow: hidden;
  transition: box-shadow 0.14s var(--ease);
}
.topsite:hover .topsite__tile { box-shadow: 0 4px 14px rgba(0,0,0,0.4), 0 0 0 1px var(--accent-soft); }
.topsite__tile img { width: 26px; height: 26px; border-radius: 6px; }
.topsite__tile span {
  font-size: 19px; font-weight: 600; color: var(--text-2);
}
.topsite__label {
  font-size: 11.5px;
  color: var(--text-2);
  max-width: 100%;
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
  transition: color 0.14s var(--ease);
}
.topsite:hover .topsite__label { color: var(--text-1); }

/* ---------- Continue browsing ---------- */
.recent__list { display: flex; flex-direction: column; gap: 2px; }
.recent__item {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 9px 12px;
  border-radius: var(--radius-md);
  border: 1px solid transparent;
  cursor: pointer;
  transition: background 0.13s var(--ease), border-color 0.13s var(--ease);
}
.recent__item:hover {
  background: var(--surface-1);
  border-color: var(--hairline);
}
.recent__fav {
  width: 30px; height: 30px;
  flex-shrink: 0;
  border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  background: var(--surface-2);
  border: 1px solid var(--hairline);
}
.recent__fav img { width: 18px; height: 18px; border-radius: 4px; }
.recent__body { flex: 1; min-width: 0; }
.recent__title {
  font-size: 13.5px;
  font-weight: 500;
  color: var(--text-1);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.recent__url {
  font-size: 11.5px;
  color: var(--text-3);
  font-family: var(--mono);
  white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
}
.recent__time {
  font-size: 11px;
  color: var(--text-3);
  flex-shrink: 0;
  font-variant-numeric: tabular-nums;
}

/* ---------- Spaces ---------- */
.spaces__row { display: flex; flex-wrap: wrap; gap: 10px; }
.space {
  display: flex;
  align-items: center;
  gap: 9px;
  padding: 9px 14px 9px 10px;
  border-radius: var(--radius-md);
  background: var(--surface-1);
  border: 1px solid var(--hairline);
  cursor: pointer;
  transition: background 0.14s var(--ease), border-color 0.14s var(--ease), transform 0.14s var(--spring);
}
.space:hover {
  background: var(--surface-2);
  border-color: var(--hairline-strong);
  transform: translateY(-1px);
}
.space__dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
.space__name { font-size: 13px; font-weight: 500; color: var(--text-1); }
.space__count {
  font-size: 11px;
  color: var(--text-3);
  font-variant-numeric: tabular-nums;
}

/* ---------- Footer ---------- */
.foot {
  display: flex;
  gap: 4px;
  margin-top: auto;
  padding-top: 32px;
}
.foot__btn {
  display: flex;
  align-items: center;
  gap: 7px;
  padding: 7px 12px;
  border-radius: 8px;
  font-size: 12.5px;
  font-weight: 500;
  color: var(--text-2);
  transition: background 0.13s var(--ease), color 0.13s var(--ease), transform 0.13s var(--spring);
}
.foot__btn svg { width: 15px; height: 15px; }
.foot__btn:hover {
  background: var(--surface-2);
  color: var(--text-1);
  transform: translateY(-1px);
}
.foot__btn:active { transform: translateY(0) scale(0.97); }

/* ---------- Status ---------- */
.status {
  margin-top: 12px;
  font-size: 11.5px;
  color: var(--text-3);
  font-family: var(--mono);
  text-align: center;
}
.status--error { color: var(--danger); }

/* ---------- Empty state ---------- */
.empty {
  padding: 22px;
  text-align: center;
  font-size: 12.5px;
  color: var(--text-3);
  border: 1px dashed var(--hairline-strong);
  border-radius: var(--radius-md);
}

/* ---------- Reduced motion ---------- */
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after { animation: none !important; transition: none !important; }
}
"""#
    static let appJS = #"""
/* ==========================================================================
   Hive Web Chrome — start page logic
   Talks to the native host exclusively through window.cefSwift.invoke().
   Renders real data (history-derived top sites, workspaces). Zero hardcoding.
   ========================================================================== */

(function () {
  'use strict';

  var el = {
    query: document.getElementById('query'),
    suggestions: document.getElementById('suggestions'),
    topsitesGrid: document.getElementById('topsitesGrid'),
    recentList: document.getElementById('recentList'),
    spacesRow: document.getElementById('spacesRow'),
    status: document.getElementById('status'),
    escHint: document.getElementById('escHint')
  };

  var state = {
    topSites: [],
    recent: [],
    spaces: [],
    accentHex: '#F5A623',
    suggestions: [],
    activeSuggestion: -1
  };

  var hasBridge = !!(window.cefSwift && window.cefSwift.invoke);

  function bridge(name, params) {
    var p = params || {};
    // Every bridge call carries the session token injected at serve time, so
    // arbitrary pages (which never receive it) cannot invoke privileged
    // functions or read browsing data.
    p.token = window.__HIVE_TOKEN || '';
    return window.cefSwift.invoke(name, p);
  }

  /* ---------- Rendering ---------- */

  function faviconImage(url, fallback) {
    if (!url) return null;
    var img = document.createElement('img');
    img.src = url;
    img.alt = '';
    img.draggable = false;
    img.onerror = function () {
      img.replaceWith(fallback);
    };
    return img;
  }

  function letterTile(host) {
    var span = document.createElement('span');
    span.textContent = (host || '?').charAt(0).toUpperCase();
    return span;
  }

  function renderTopSites() {
    el.topsitesGrid.innerHTML = '';
    if (!state.topSites.length) {
      var empty = document.createElement('div');
      empty.className = 'empty';
      empty.textContent = 'Sites you visit will appear here.';
      el.topsitesGrid.appendChild(empty);
      return;
    }
    state.topSites.forEach(function (site) {
      var tile = document.createElement('button');
      tile.className = 'topsite';
      tile.title = site.url;

      var tileBox = document.createElement('div');
      tileBox.className = 'topsite__tile';
      var img = faviconImage(site.faviconURL, letterTile(site.host));
      if (img) { tileBox.appendChild(img); } else { tileBox.appendChild(letterTile(site.host)); }

      var label = document.createElement('div');
      label.className = 'topsite__label';
      label.textContent = site.host;

      tile.appendChild(tileBox);
      tile.appendChild(label);
      tile.addEventListener('click', function () {
        if (hasBridge) { bridge('hive.navigate', { url: site.url }); }
      });
      el.topsitesGrid.appendChild(tile);
    });
  }

  function renderRecent() {
    el.recentList.innerHTML = '';
    if (!state.recent.length) {
      var empty = document.createElement('div');
      empty.className = 'empty';
      empty.textContent = 'Nothing to continue yet.';
      el.recentList.appendChild(empty);
      return;
    }
    state.recent.forEach(function (item) {
      var row = document.createElement('button');
      row.className = 'recent__item';
      row.title = item.url;

      var fav = document.createElement('div');
      fav.className = 'recent__fav';
      var img = faviconImage(item.faviconURL, letterTile(item.host));
      if (img) { fav.appendChild(img); } else { fav.appendChild(letterTile(item.host)); }

      var body = document.createElement('div');
      body.className = 'recent__body';
      var title = document.createElement('div');
      title.className = 'recent__title';
      title.textContent = item.title || item.host || item.url;
      var url = document.createElement('div');
      url.className = 'recent__url';
      url.textContent = item.url;
      body.appendChild(title);
      body.appendChild(url);

      var time = document.createElement('div');
      time.className = 'recent__time';
      time.textContent = item.timeLabel || '';

      row.appendChild(fav);
      row.appendChild(body);
      row.appendChild(time);
      row.addEventListener('click', function () {
        if (hasBridge) { bridge('hive.navigate', { url: item.url }); }
      });
      el.recentList.appendChild(row);
    });
  }

  function renderSpaces() {
    el.spacesRow.innerHTML = '';
    state.spaces.forEach(function (space) {
      var chip = document.createElement('button');
      chip.className = 'space';

      var dot = document.createElement('span');
      dot.className = 'space__dot';
      dot.style.background = space.colorHex || state.accentHex;

      var name = document.createElement('span');
      name.className = 'space__name';
      name.textContent = space.name;

      var count = document.createElement('span');
      count.className = 'space__count';
      count.textContent = space.tabCount + ' tab' + (space.tabCount === 1 ? '' : 's');

      chip.appendChild(dot);
      chip.appendChild(name);
      chip.appendChild(count);
      chip.addEventListener('click', function () {
        if (hasBridge) { bridge('hive.switchWorkspace', { id: space.id }); }
      });
      el.spacesRow.appendChild(chip);
    });
  }

  function setStatus(text, isError) {
    if (!text) { el.status.hidden = true; return; }
    el.status.hidden = false;
    el.status.textContent = text;
    el.status.classList.toggle('status--error', !!isError);
  }

  /* ---------- Suggestions ---------- */

  function renderSuggestions() {
    el.suggestions.innerHTML = '';
    if (!state.suggestions.length) {
      el.suggestions.hidden = true;
      return;
    }
    state.suggestions.forEach(function (s, i) {
      var row = document.createElement('button');
      row.className = 'suggestion' + (i === state.activeSuggestion ? ' suggestion--active' : '');
      row.addEventListener('mousemove', function () {
        state.activeSuggestion = i;
        refreshSuggestionHighlight();
      });

      var icon = document.createElement('div');
      icon.className = 'suggestion__icon';
      if (s.kind === 'tab') {
        icon.textContent = '⇥';
      } else if (s.kind === 'bookmark') {
        icon.textContent = '★';
      } else {
        icon.textContent = s.kind === 'search' ? '⌕' : '↗';
      }

      var body = document.createElement('div');
      body.className = 'suggestion__body';
      var title = document.createElement('div');
      title.className = 'suggestion__title';
      title.textContent = s.text;
      var url = document.createElement('div');
      url.className = 'suggestion__url';
      url.textContent = s.url || '';
      body.appendChild(title);
      body.appendChild(url);

      var kind = document.createElement('span');
      kind.className = 'suggestion__kind';
      kind.textContent = s.kind;

      row.appendChild(icon);
      row.appendChild(body);
      row.appendChild(kind);
      row.addEventListener('click', function () { activateSuggestion(i); });
      el.suggestions.appendChild(row);
    });
    el.suggestions.hidden = false;
  }

  function refreshSuggestionHighlight() {
    Array.prototype.forEach.call(el.suggestions.children, function (child, i) {
      child.classList.toggle('suggestion--active', i === state.activeSuggestion);
    });
  }

  function activateSuggestion(i) {
    var s = state.suggestions[i];
    if (!s || !hasBridge) { return; }
    if (s.kind === 'tab' && s.tabID) {
      bridge('hive.selectTab', { id: s.tabID });
    } else if (s.url) {
      bridge('hive.navigate', { url: s.url });
    } else {
      submitQuery(el.query.value);
    }
  }

  function submitQuery(text) {
    if (!hasBridge) { return; }
    bridge('hive.submit', { text: text });
  }

  /* ---------- Bridge events ---------- */

  function refreshData() {
    if (!hasBridge) { return; }
    bridge('hive.getStartData', {})
      .then(function (data) {
        state.topSites = data.topSites || [];
        state.recent = data.recent || [];
        state.spaces = data.spaces || [];
        state.accentHex = data.accentHex || '#F5A623';
        document.documentElement.style.setProperty('--accent', state.accentHex);
        renderTopSites();
        renderRecent();
        renderSpaces();
      })
      .catch(function (err) {
        setStatus('Bridge error: ' + err.message, true);
      });
  }

  var refreshTimer = null;
  function scheduleRefresh() {
    if (refreshTimer) { clearTimeout(refreshTimer); }
    refreshTimer = setTimeout(refreshData, 120);
  }

  /* ---------- Input ---------- */

  function handleQueryInput() {
    var q = el.query.value;
    state.activeSuggestion = -1;
    if (q.trim().length < 2 || !hasBridge) {
      state.suggestions = [];
      renderSuggestions();
      return;
    }
    bridge('hive.suggest', { query: q })
      .then(function (data) {
        // Guard against stale responses when typing quickly.
        if (el.query.value !== q) { return; }
        state.suggestions = data.suggestions || [];
        state.activeSuggestion = state.suggestions.length ? 0 : -1;
        renderSuggestions();
      })
      .catch(function () {
        state.suggestions = [];
        renderSuggestions();
      });
  }

  el.query.addEventListener('input', handleQueryInput);
  el.query.addEventListener('keydown', function (e) {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (state.suggestions.length) {
        state.activeSuggestion = (state.activeSuggestion + 1) % state.suggestions.length;
        refreshSuggestionHighlight();
      }
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (state.suggestions.length) {
        state.activeSuggestion =
          (state.activeSuggestion - 1 + state.suggestions.length) % state.suggestions.length;
        refreshSuggestionHighlight();
      }
    } else if (e.key === 'Enter') {
      e.preventDefault();
      if (state.activeSuggestion >= 0 && state.suggestions.length) {
        activateSuggestion(state.activeSuggestion);
      } else {
        submitQuery(el.query.value);
      }
    } else if (e.key === 'Escape') {
      e.preventDefault();
      if (!el.suggestions.hidden) {
        state.suggestions = [];
        renderSuggestions();
      } else if (el.query.value) {
        el.query.value = '';
      } else {
        el.query.blur();
      }
    }
  });

  // Type anywhere → focus the command bar.
  document.addEventListener('keydown', function (e) {
    var target = e.target;
    var isTyping = target && (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA');
    if (isTyping || e.metaKey || e.ctrlKey || e.altKey) { return; }
    if (e.key.length === 1 && /^[\x20-\x7E]$/.test(e.key)) {
      el.query.focus();
    }
  });

  // Footer actions → native host.
  document.querySelectorAll('.foot__btn').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var action = btn.dataset.action;
      if (hasBridge) { bridge('hive.action', { action: action }); }
    });
  });

  // Bridge events: hive.stateChanged → refresh quietly.
  if (window.cefSwift && window.cefSwift.on) {
    window.cefSwift.on('hive.stateChanged', scheduleRefresh);
  }

  /* ---------- Init ---------- */

  if (!hasBridge) {
    setStatus('Running without the Hive bridge — data unavailable.', true);
  } else {
    refreshData();
  }
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
