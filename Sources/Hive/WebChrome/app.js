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
  var PRIVATE_START = new URLSearchParams(location.search).get('private') === '1';
  var hasBridge = !!(window.cefSwift && window.cefSwift.invoke);

  function api(name, params) {
    var p = params || {};
    p.token = window.__HIVE_TOKEN || '';
    if (!hasBridge) return Promise.resolve(null);
    try {
      var promise = window.cefSwift.invoke(name, p);
      if (promise && typeof promise.then === 'function') {
        return promise.catch(function (err) {
          console.warn('[Hive] bridge call failed:', name, err);
          showToast('Something went wrong — try again', 'error');
          return null;
        });
      }
      return Promise.resolve(promise);
    }
    catch (e) {
      console.warn('[Hive] bridge call threw:', name, e);
      showToast('Something went wrong — try again', 'error');
      return Promise.resolve(null);
    }
  }

  // Start pages cannot safely mutate the globally-active browser tab through
  // the shared bridge. Navigate locally instead; the CEF tab owns this page.
  // The persistent chrome shell keeps using native bridge actions.
  function navigate(urlOrQuery) {
    var value = String(urlOrQuery || '').trim();
    if (!value) return;
    if (!IS_CHROME) {
      var isHTTP = value.indexOf('http://') === 0 || value.indexOf('https://') === 0;
      var url = isHTTP ? value :
        'https://www.google.com/search?q=' + encodeURIComponent(value);
      window.location.href = url;
      return;
    }
    api('hive.navigate', { url: value });
  }

  function submitAddress(value) {
    var text = String(value || '').trim();
    if (!text) return;
    if (!IS_CHROME) { navigate(text); return; }
    api('hive.submit', { text: text });
  }

  // Browser convention: plain click navigates the active tab; ⌘/⌃/middle
  // click opens the target in a new background tab (Chrome/Safari parity).
  function openURL(url, e) {
    var bg = e && (e.metaKey || e.ctrlKey || e.button === 1);
    if (bg) api('hive.newTabWithURL', { url: url, activate: false });
    else navigate(url);
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
    // Toolbar sun/moon glyph follows the active theme (native-menu parity).
    $('themeSun').hidden = light;
    $('themeMoon').hidden = !light;
    if (prefs.animations) document.body.classList.remove('no-motion');
    else document.body.classList.add('no-motion');
  }
  applyTheme();
  if (mq) mq.addEventListener('change', applyTheme);

  // Toolbar sun/moon button: cycles System → Light → Dark (native-menu parity).
  $('btnTheme').addEventListener('click', function () {
    var order = ['system', 'light', 'dark'];
    prefs.theme = order[(order.indexOf(prefs.theme) + 1) % order.length];
    savePrefs();
    applyTheme();
    showToast('Theme: ' + prefs.theme.charAt(0).toUpperCase() + prefs.theme.slice(1), 'info');
  });

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

  // M3 surface tint (spec §3): wash the toolbar with ~4% of the active
  // page's theme color. The color is computed NATIVELY (CORS-safe, from the
  // cached favicon via PageThemeColor) and rides the state broadcast as
  // pageTintHex; the web side only consumes it. Private/blank tabs clear it.
  function applyPageTint(activeTab) {
    var tint = state.pageTintHex;
    if (!tint || (state.isPrivateBrowsing)) tint = 'transparent';
    document.documentElement.style.setProperty('--page-tint-color', tint);
  }

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

  /* Zen compact-mode hover tracking — sets data-compact-active on sidebar/toolbar hover */
  (function () {
    var sidebar = document.getElementById('chrome');
    if (!sidebar) return;
    var keepTimer = null;
    var keepDuration = 150;
    sidebar.addEventListener('mouseenter', function () {
      if (keepTimer) clearTimeout(keepTimer);
      sidebar.dataset.compactActive = 'true';
    });
    sidebar.addEventListener('mouseleave', function () {
      keepTimer = setTimeout(function () {
        delete sidebar.dataset.compactActive;
      }, keepDuration);
    });
    var toolbar = document.querySelector('.toolbar');
    if (toolbar) {
      toolbar.addEventListener('mouseenter', function () { toolbar.dataset.compactActive = 'true'; });
      toolbar.addEventListener('mouseleave', function () {
        setTimeout(function () { delete toolbar.dataset.compactActive; }, 800);
      });
    }
  })();

  /* ---------------- state ---------------- */

  var state = {
    tabs: [], activeTabID: null, spaces: [], sessions: [], accentHex: '#F97316',
    topSites: [], recent: [], history: [], bookmarks: [], downloads: [],
    layout: 'vertical', isPrivateBrowsing: false, isSplitActive: false,
    isChromePanelOpen: null, chromeMode: 'sidebar', chromeDimension: 270,
    searchEngine: 'Google', httpsOnlyEnabled: false, adBlockEnabled: true, memorySaverEnabled: true,
    councilVerdict: null, isCouncilConvening: false, councilLiveResponses: [], deepResearchStep: null,
    agentTask: null, councilError: null, agentError: null, lastQuery: '', syncDiagnostic: null,
    sitePermissions: {}, siteCookies: 0, didCrash: false, crashedTabCount: 0, lastSessionTabs: null,
    findResults: null, readingList: [],    pendingPermission: null, pendingPassword: null, translateOffer: null,
    isFullscreen: false, savedCredentials: [], activeTabHost: ''
  };

  var lastTabsJSON = '';
  var lastActiveTabID = null;

  var lastSyncDiagnostic = null;

  function apply(data) {
    if (!data) return;
    for (var k in data) if (k in state) state[k] = data[k];
    if (IS_CHROME && data.syncDiagnostic && data.syncDiagnostic !== lastSyncDiagnostic) {
      lastSyncDiagnostic = data.syncDiagnostic;
      showToast(data.syncDiagnostic, 'error');
    } else if (data.syncDiagnostic == null) {
      lastSyncDiagnostic = null;
    }
    document.body.dataset.mode = state.layout;
    if (IS_CHROME) {
      chromeEl.classList.remove('chrome--sidebar', 'chrome--strip');
      chromeEl.classList.add('chrome--' + (state.chromeMode === 'sidebar' ? 'sidebar' : 'strip'));
    }
    applyTheme();
    applyDensity();
    var activeTab = state.tabs.find(function (t) { return t.id === state.activeTabID; });
    var tabLoading = !!(activeTab && activeTab.isLoading);
    applyPageTint(activeTab);
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
    updateTabScrollButtons();
  }

  function refresh() {
    api('hive.getStartData', { privateStart: PRIVATE_START, chromeShell: IS_CHROME }).then(apply);
  }

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
    volume: 'M4 9v6h4l5 4V5L8 9H4Zm11.5 0a4 4 0 0 1 0 6M18 6.5a7.5 7.5 0 0 1 0 11',
    play: 'M7 4.5v15l12-7.5-12-7.5Z',
    pause: 'M7 5h3.5v14H7V5Zm6.5 0H17v14h-3.5V5Z',
    folder: 'M3.5 6.5h6.2l2 2h8.8v9h-17v-11Z',
    eye: 'M12 5.5c4 0 7.4 2.3 9.5 6.5-2.1 4.2-5.5 6.5-9.5 6.5S4.6 16.2 2.5 12C4.6 7.8 8 5.5 12 5.5Zm0 3.5a3 3 0 1 0 0 6 3 3 0 0 0 0-6Z',
    volumeMuted: 'M4 9v6h4l5 4V5L8 9H4Zm14.5-1.5 3 3m0-3-3 3',
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
    reload: 'M20 12a8 8 0 1 1-2.34-5.66M20 4v4h-4',
    stop: 'M7 7h10v10H7z',
    print: 'M7 8V4h10v4m-10 4h10m2 0v6H5v-6h14m-2 4h.01',
    zoom: 'M12 6v12M6 12h12M21 21l-4.7-4.7',
    zoomOut: 'M6 12h12M21 21l-4.7-4.7',
    refresh: 'M12 3a9 9 0 1 0 9 9M12 3v5m0-5 3.5 3.5',
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
  // Tab entrance gating: ids seen in the previous render never re-animate
  // on state broadcasts (no re-pop of the strip); only genuinely new tabs
  // play tab-in. The maps are plain id sets for O(1) membership.
  var seenTabIDs = null;
  var renderPrevTabSeen = null;

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


  function showTabPeek(el, t) {
    var existing = document.querySelector('.tab-peek');
    if (!existing) {
      var div = document.createElement('div');
      div.className = 'tab-peek';
      div.innerHTML =
        '<div class="tab-peek__header">' +
        '<span class="tab-peek__favicon" style="background:hsl(' + (Math.abs(hash(t.host || t.id)) % 360) + ',32%,48%)">' +
        esc((t.host || '?').charAt(0).toUpperCase()) + '</span>' +
        '<span class="tab-peek__title">' + esc(t.title || t.host || 'New Tab') + '</span>' +
        '</div>' +
        '<div class="tab-peek__body">' + esc(t.host || '') + '</div>' +
        '<div class="tab-peek__actions">' +
        '<button class="tab-peek__action tab-peek__action--primary">Switch</button>' +
        '<button class="tab-peek__action">Close</button>' +
        '</div>';
      document.body.appendChild(div);
      existing = div;
    }
    var rect = el.getBoundingClientRect();
    var peekW = 320;
    var peekH = 240;
    var isStrip = document.body.dataset.mode === 'horizontal';
    var left = 0, top = 0;
    if (isStrip) {
      // Strip layout (tabs across the top): peek drops BELOW the tab,
      // clamped horizontally so it never leaves the window.
      left = Math.max(8, Math.min(rect.left, window.innerWidth - peekW - 8));
      top = Math.min(rect.bottom + 10, window.innerHeight - peekH - 8);
    } else {
      // Sidebar layout (tabs down the left): peek to the RIGHT of the tab,
      // flipping to the left when it would cross the window's right edge.
      left = (rect.right + 12 + peekW <= window.innerWidth - 8)
        ? rect.right + 12
        : Math.max(8, rect.left - peekW - 12);
      top = Math.min(rect.top, window.innerHeight - peekH - 8);
    }
    existing.style.left = left + 'px';
    existing.style.top = Math.max(8, top) + 'px';
    existing.dataset.visible = 'true';
    // Wire the peek's actions once (Switch / Close) — delegated so re-shows
    // of the same element keep working (Arc tab-hover preview parity).
    if (!existing.dataset.wired) {
      existing.dataset.wired = 'true';
      existing.querySelector('.tab-peek__action--primary').addEventListener('click', function () {
        if (existing._peekTabID) api('hive.selectTab', { id: existing._peekTabID });
        hideTabPeek();
      });
      existing.querySelector('.tab-peek__action:not(.tab-peek__action--primary)').addEventListener('click', function () {
        if (existing._peekTabID) api('hive.closeTab', { id: existing._peekTabID });
        hideTabPeek();
      });
    }
    existing._peekTabID = t.id;
  }

  function hideTabPeek() {
    var el = document.querySelector('.tab-peek');
    if (el) { delete el.dataset.visible; setTimeout(function () { if (el && !el.dataset.visible) el.remove(); }, 200); }
  }

  function renderTabs() {
    refreshGroupMap();
    var list = $('tabList');
    var groups = groupedTabs();
    // Snapshot the current id set for the fresh-tab diff, then expose it to
    // tabHTML as the "previous render" before building.
    var nextSeen = {};
    state.tabs.forEach(function (t) { nextSeen[t.id] = 1; });
    renderPrevTabSeen = seenTabIDs;
    seenTabIDs = nextSeen;
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
    // Zen/Arc tab peek: show floating preview on hover
    var peekTimer = null;
    list.querySelectorAll('.tab').forEach(function (el) {
      el.addEventListener('mouseenter', function () {
        var t = state.tabs.find(function (x) { return x.id === el.dataset.id; });
        if (!t) return;
        clearTimeout(peekTimer);
        peekTimer = setTimeout(function () {
          showTabPeek(el, t);
        }, 400);
      });
      el.addEventListener('mouseleave', function () {
        clearTimeout(peekTimer);
        hideTabPeek();
      });
    });

    upgradeTabFavicons();
    // Keep the active tab in view on both layouts: keyboard switching (⌘1-9,
    // arrows, workspace moves) changes the active id without changing the tab
    // set, so track both. block+inline nearest is a no-op for the axis that
    // isn't scrollable (Chrome parity).
    var activeChanged = lastActiveTabID !== state.activeTabID;
    lastActiveTabID = state.activeTabID;
    if (changed || activeChanged) {
      var active = list.querySelector('.tab[data-active="true"]');
      if (active) active.scrollIntoView({ block: 'nearest', inline: 'nearest' });
    }
  }

  function tabHTML(t, groupColor) {
    var host = t.host || '';
    var hue = Math.abs(hash(host || t.id)) % 360;
    var active = t.id === state.activeTabID;
    var groupStripe = groupColor ? ' style="border-left:3px solid ' + sanitizeHex(groupColor) + '"' : '';
    // Roving tabindex: only the active tab is in the Tab order; arrow keys
    // move focus and select (native-browser keyboard UX).
    var muted = !!t.isMuted;
    var playing = !!t.isMediaPlaying;
    // Chrome/Arc convention: a speaker badge appears on playing tabs; a muted
    // tab shows a crossed speaker and clicking either toggles renderer mute.
    var muteBadge = (playing || muted)
      ? '<span class="tab__mute' + (muted ? ' is-muted' : '') + '" data-mute="' + t.id + '" ' +
        'title="' + (muted ? 'Unmute tab' : 'Mute tab') + '" role="button" tabindex="-1">' +
        svg(muted ? ICONS.volumeMuted : ICONS.volume, 12) + '</span>'
      : '';
    // Chrome convention: while a tab is loading, the favicon slot shows a
    // spinner; it swaps to the letter-avatar (or real favicon) once the load
    // finishes and the shell broadcasts the fresh tab state.
    var favHTML = t.isLoading
      ? '<span class="tab__fav tab__fav--loading" aria-hidden="true"><i></i></span>'
      : '<span class="tab__fav" data-host="' + esc(host || '') + '" style="background:hsl(' + hue + ',32%,48%)">' +
        esc((host || '?').charAt(0).toUpperCase()) + '</span>';
    // Chrome/Arc convention: private tabs carry a dark incognito badge so
    // they're unmistakable in a mixed strip, even out of focus.
    var privateBadge = t.isPrivate
      ? '<span class="tab__private" title="Private tab">' + svg(ICONS.private, 10) + '</span>'
      : '';
    // Only a tab that didn't exist in the previous render gets the entrance
    // animation; a re-rendered existing tab updates in place, silently.
    var fresh = !(renderPrevTabSeen && renderPrevTabSeen[t.id]);
    return '<div class="tab' + (fresh ? ' tab--fresh' : '') + '" data-id="' + t.id + '" data-active="' + active + '"' +
      (t.url ? ' data-url="' + esc(t.url) + '"' : '') + ' ' + groupStripe +
      'draggable="true" role="tab" aria-selected="' + active + '" tabindex="' + (active ? 0 : -1) + '" title="' + esc(t.title) + '">' +
      favHTML +
      (t.isPinned ? '<span class="tab__pin">' + svg(ICONS.pin, 11) + '</span>' : '') +
      privateBadge +
      '<span class="tab__title">' + esc(t.title || 'New Tab') + '</span>' +
      muteBadge +
      '<span class="tab__close" data-close="' + t.id + '" title="Close tab (⌘W)">' +
      svg(ICONS.close, 12) + '</span></div>';
  }

  function sanitizeHex(h) {
    return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(h || '') ? h : '#F97316';
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
    var mute = e.target.closest('[data-mute]');
    if (mute) {
      e.stopPropagation();
      api('hive.toggleTabMute', { id: mute.dataset.mute });
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

  // Keyboard tab switching (Chrome parity): arrows move focus + select,
  // Home/End jump, Enter/Space selects the focused tab.
  $('tabList').addEventListener('keydown', function (e) {
    var t = e.target;
    if (!t || !t.classList || !t.classList.contains('tab')) return;
    var tabs = Array.prototype.slice.call(this.querySelectorAll('.tab'));
    var idx = tabs.indexOf(t);
    if (idx < 0) return;
    var next = null;
    if (e.key === 'ArrowDown' || e.key === 'ArrowRight') { e.preventDefault(); next = tabs[idx + 1] || tabs[0]; }
    else if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') { e.preventDefault(); next = tabs[idx - 1] || tabs[tabs.length - 1]; }
    else if (e.key === 'Home') { e.preventDefault(); next = tabs[0]; }
    else if (e.key === 'End') { e.preventDefault(); next = tabs[tabs.length - 1]; }
    else if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); api('hive.selectTab', { id: t.dataset.id }); return; }
    else return;
    if (next) { next.focus(); api('hive.selectTab', { id: next.dataset.id }); }
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
    if (tab) {
      e.preventDefault();
      showCtxMenu(e.clientX, e.clientY, tab.dataset.id);
      return;
    }
    var group = e.target.closest('.groupheader');
    if (group) {
      e.preventDefault();
      showGroupMenu(e.clientX, e.clientY, group);
      return;
    }
    // Right-click the empty strip background: quick actions (Chrome parity).
    e.preventDefault();
    showStripMenu(e.clientX, e.clientY);
  });

  function showStripMenu(x, y) {
    var items = [
      { label: 'New Tab (⌘T)', run: function () { api('hive.newTab'); } },
      { label: 'Reopen Closed Tab (⌘⇧T)', run: function () { api('hive.reopenClosedTab'); } },
      { sep: true },
      { label: 'Tab Search (⌘⇧A)', run: function () { openTabSearch(); } },
      { label: 'Session Manager', run: function () { openPanel('sessions'); } },
      { label: 'Bookmarks Bar', run: function () { prefs.bookmarksBar = !prefs.bookmarksBar; savePrefs(); renderBookmarksBar(); } }
    ];
    ctx.innerHTML = '';
    items.forEach(function (item) {
      if (item.sep) { ctx.appendChild(el('div', 'ctxmenu__sep')); return; }
      var b = el('button', 'ctxmenu__item');
      b.textContent = item.label;
      b.addEventListener('click', function () { ctx.hidden = true; item.run(); });
      ctx.appendChild(b);
    });
    showCtxAt(x, y);
  }

  // Tab-group header context menu (Chrome/Arc parity): rename (focuses the
  // inline input), recolor from the preset palette, or ungroup the whole
  // group. Reuses the shared ctxmenu element.
  var GROUP_COLORS = ['#6366F1', '#F97316', '#10B981', '#EF4444', '#F59E0B', '#8B5CF6', '#06B6D4', '#64748B'];
  function showGroupMenu(x, y, header) {
    var g = groupMap[header.dataset.gid];
    if (!g) return;
    ctx.innerHTML = '';
    var rename = el('button', 'ctxmenu__item');
    rename.textContent = 'Rename group';
    rename.addEventListener('click', function () {
      ctx.hidden = true;
      var input = header.querySelector('.groupheader__name');
      if (input) { input.focus(); input.select(); }
    });
    ctx.appendChild(rename);
    var swatchRow = el('div', 'ctxmenu__swatches');
    swatchRow.setAttribute('role', 'group');
    swatchRow.setAttribute('aria-label', 'Group color');
    GROUP_COLORS.forEach(function (hex) {
      var dot = el('button', 'ctxmenu__swatch' + (g.colorHex === hex ? ' is-active' : ''));
      dot.style.background = hex;
      dot.title = hex;
      dot.setAttribute('aria-label', 'Color ' + hex);
      dot.addEventListener('click', function () {
        ctx.hidden = true;
        api('hive.setTabGroupColor', { id: g.id, colorHex: hex }).then(function () { refresh(); });
      });
      swatchRow.appendChild(dot);
    });
    ctx.appendChild(swatchRow);
    var sep = el('div', 'ctxmenu__sep');
    ctx.appendChild(sep);
    var ungroup = el('button', 'ctxmenu__item ctxmenu__item--danger');
    ungroup.textContent = 'Ungroup';
    ungroup.addEventListener('click', function () {
      ctx.hidden = true;
      api('hive.deleteTabGroup', { id: g.id }).then(function () { refresh(); });
    });
    ctx.appendChild(ungroup);
    ctx.hidden = false;
    var w = ctx.offsetWidth, h = ctx.offsetHeight;
    ctx.style.left = Math.min(x, window.innerWidth - w - 8) + 'px';
    ctx.style.top = Math.min(y, window.innerHeight - h - 8) + 'px';
  }

  // Middle-click closes the tab (Chrome/Safari/Arc convention); middle-click
  // on empty strip space opens a new tab in the background (Chrome/Firefox).
  $('tabList').addEventListener('auxclick', function (e) {
    if (e.button !== 1) return;
    var tab = e.target.closest('.tab');
    if (tab) {
      e.preventDefault();
      animateCloseTab(tab.dataset.id);
    } else if (e.target === this || e.target.closest('.tabgroup, .groupheader')) {
      // closest() so middle-clicking a header's children (name/disclosure)
      // still counts as empty-strip space.
      e.preventDefault();
      api('hive.newTabBackground');
    }
  });

  // Double-click empty strip space opens a new tab (Chrome convention).
  $('tabList').addEventListener('dblclick', function (e) {
    if (e.target === this || e.target.classList.contains('tabgroup') ||
        e.target.classList.contains('groupheader')) {
      api('hive.newTab');
    }
  });

  function animateCloseTab(id) {
    var node = $('tabList').querySelector('.tab[data-id="' + id + '"]');
    function doClose() { api('hive.closeTab', { id: id }); }
    if (node) {
      node.classList.add('anim-out');
      setTimeout(doClose, 140);
    } else {
      doClose();
    }
    // Tab-closed undo toast (Chrome parity): an Undo button brings the tab
    // back via the native last-closed stack (⌘⇧T path). One toast at a time;
    // a fresh close replaces the previous toast's window.
    var region = toastRegion();
    var old = document.getElementById('hive-undo-toast');
    if (old) old.remove();
    var toast = document.createElement('div');
    toast.id = 'hive-undo-toast';
    toast.className = 'hive-toast hive-toast--info hive-undo';
    toast.setAttribute('role', 'status');
    toast.innerHTML = '<span class="hive-toast__msg">Tab closed</span>' +
      '<button class="hive-undo__btn">Undo</button>';
    toast.querySelector('.hive-undo__btn').addEventListener('click', function () {
      toast.remove();
      api('hive.reopenClosedTab').then(function () { refresh(); });
    });
    region.appendChild(toast);
    setTimeout(function () {
      if (toast.isConnected) toast.classList.add('hive-toast--leaving');
      setTimeout(function () { if (toast.isConnected) toast.remove(); }, 300);
    }, 6000);
  }

  // External drops: a URL (or text) dragged from a page or the Finder can be
  // dropped anywhere on the tab strip to open it in a new tab — and onto the
  // address bar to navigate the active tab. Internal tab drags keep the
  // reorder path; the two never collide because dragID is only set by
  // dragstart on a .tab.
  function externalURLFromDrop(e) {
    var types = e.dataTransfer ? (e.dataTransfer.types || []) : [];
    var url = '';
    try {
      if (types.indexOf('text/uri-list') !== -1) {
        url = (e.dataTransfer.getData('text/uri-list') || '').split('\n')[0].trim();
      } else if (types.indexOf('text/plain') !== -1) {
        url = (e.dataTransfer.getData('text/plain') || '').trim();
      }
    } catch (err) {}
    return url;
  }

  // Favicon URL that failed to load — treated as "no favicon" on every
  // subsequent render (reassigning the same errored src does not re-fire
  // onerror, so without this cache the broken img would show instead of the
  // lock glyph after the first failure).
  var failedFavicon = '';

  // Drag-and-drop reorder
  var dragID = null;
  $('tabList').addEventListener('dragstart', function (e) {
    var tab = e.target.closest('.tab');
    if (!tab) return;
    dragID = tab.dataset.id;
    tab.classList.add('dragging');
    e.dataTransfer.effectAllowed = 'move';
    try { e.dataTransfer.setData('text/plain', dragID); } catch (err) {}
    // Tab peek thumbnail — create a ghost image of the dragged tab
    var ghost = tab.cloneNode(true);
    ghost.style.position = 'absolute';
    ghost.style.top = '-9999px';
    ghost.style.opacity = '0.85';
    ghost.style.width = tab.offsetWidth + 'px';
    ghost.style.transform = 'scale(0.95)';
    document.body.appendChild(ghost);
    e.dataTransfer.setDragImage(ghost, ghost.offsetWidth / 2, ghost.offsetHeight / 2);
    requestAnimationFrame(function () { document.body.removeChild(ghost); });
  });
  $('tabList').addEventListener('dragend', function (e) {
    var tab = e.target.closest('.tab');
    if (tab) tab.classList.remove('dragging');
    dragID = null;
  });
  $('tabList').addEventListener('dragover', function (e) {
    e.preventDefault();
    var tab = e.target.closest('.tab');
    if (tab) {
      // Internal reorder over an existing tab.
      if (!dragID || tab.dataset.id === dragID) return;
      var rect = tab.getBoundingClientRect();
      var before = e.clientY < rect.top + rect.height / 2;
      var cls = before ? 'drag-over-top' : 'drag-over-bottom';
      Array.prototype.forEach.call(this.querySelectorAll('.tab'), function (t) {
        t.classList.remove('drag-over-top', 'drag-over-bottom');
      });
      tab.classList.add(cls);
    } else if (!dragID && externalURLFromDrop(e)) {
      // External link/text hovered over the strip → open-in-new-tab affordance.
      this.classList.add('drop-zone');
    }
  });
  $('tabList').addEventListener('dragleave', function (e) {
    this.classList.remove('drop-zone');
  });
  $('tabList').addEventListener('drop', function (e) {
    e.preventDefault();
    this.classList.remove('drop-zone');
    var tab = e.target.closest('.tab');
    if (dragID) {
      if (!tab) return;
      var all = Array.prototype.slice.call(this.querySelectorAll('.tab'));
      var from = all.indexOf(this.querySelector('.tab[data-id="' + dragID + '"]'));
      var to = all.indexOf(tab);
      var rect = tab.getBoundingClientRect();
      var before = e.clientY < rect.top + rect.height / 2;
      var target = before ? to : to + 1;
      if (from < to && before) target = to - 1;
      api('hive.reorderTab', { from: dragID, to: target });
      return;
    }
    var url = externalURLFromDrop(e);
    if (url) api('hive.newTabWithURL', { url: url });
  });

  // Horizontal strip scroll buttons (Chrome parity): pinned overlay chevrons
  // that appear only when the strip overflows, disabled at the scroll ends.
  var tabRegion = $('tabRegion');
  function updateTabScrollButtons() {
    if (!tabRegion) return;
    var hasOverflow = tabRegion.scrollWidth > tabRegion.clientWidth + 8;
    $('tabScrollLeft').hidden = !hasOverflow;
    $('tabScrollRight').hidden = !hasOverflow;
    if (hasOverflow) {
      $('tabScrollLeft').dataset.disabled = tabRegion.scrollLeft <= 2 ? 'true' : 'false';
      var maxLeft = tabRegion.scrollWidth - tabRegion.clientWidth - 2;
      $('tabScrollRight').dataset.disabled = tabRegion.scrollLeft >= maxLeft ? 'true' : 'false';
    }
  }
  if (tabRegion) {
    tabRegion.addEventListener('scroll', function () { updateTabScrollButtons(); }, { passive: true });
    window.addEventListener('resize', function () { updateTabScrollButtons(); });
    $('tabScrollLeft').addEventListener('click', function () {
      tabRegion.scrollBy({ left: -Math.max(200, tabRegion.clientWidth * 0.6), behavior: 'smooth' });
    });
    $('tabScrollRight').addEventListener('click', function () {
      tabRegion.scrollBy({ left: Math.max(200, tabRegion.clientWidth * 0.6), behavior: 'smooth' });
    });
    // Wheel over the tab region scrolls the strip (Chrome parity), unless the
    // region is scrolled to an end (then the event bubbles to the page).
    $('tabRegion').addEventListener('wheel', function (e) {
      if (document.body.dataset.mode !== 'horizontal') return;
      if (this.scrollWidth <= this.clientWidth) return;
      var atStart = this.scrollLeft <= 0 && e.deltaY < 0;
      var atEnd = this.scrollLeft + this.clientWidth >= this.scrollWidth - 1 && e.deltaY > 0;
      if (atStart || atEnd) return;
      e.preventDefault();
      this.scrollLeft += e.deltaY;
      updateTabScrollButtons();
    }, { passive: false });
  }

  // Drop a URL/text onto the address bar → navigate the active tab.
  var addressForm = $('addressbarForm');
  addressForm.addEventListener('dragover', function (e) {
    e.preventDefault();
    if (externalURLFromDrop(e)) addressForm.classList.add('drop-zone');
  });
  addressForm.addEventListener('dragleave', function () { addressForm.classList.remove('drop-zone'); });
  addressForm.addEventListener('drop', function (e) {
    e.preventDefault();
    addressForm.classList.remove('drop-zone');
    var url = externalURLFromDrop(e);
    if (url) navigate(url);
  });

  /* ---------- toolbar ---------- */

  var addrInput = $('addrInput');
  var suggestBox = $('suggestBox');

  function renderToolbar() {
    var active = state.tabs.find(function (t) { return t.id === state.activeTabID; });
    $('btnBack').dataset.disabled = active && active.canGoBack ? 'false' : 'true';
    $('btnForward').dataset.disabled = active && active.canGoForward ? 'false' : 'true';
    $('addrClear').hidden = !addrInput.value.trim();
    // Chrome/Arc convention: badge the downloads button while any download is
    // in flight (paused counts too — it needs attention). Completed or failed
    // downloads leave the panel badge until the panel is opened.
    var activeDls = (state.downloads || []).filter(function (d) {
      var s = String(d.state || '');
      return s === 'inProgress' || s === 'downloading' || s === 'paused';
    });
    var dlBtn = $('btnDownloads');
    var badge = dlBtn.querySelector('.navbtn__badge');
    if (activeDls.length) {
      if (!badge) {
        badge = document.createElement('span');
        badge.className = 'navbtn__badge';
        badge.setAttribute('aria-hidden', 'true');
        dlBtn.appendChild(badge);
      }
      badge.textContent = activeDls.length > 9 ? '9+' : String(activeDls.length);
    } else if (badge) {
      badge.remove();
    }
    if (active) {
      var fav = active.faviconURL || '';
      var addrFav = $('addrFav');
      if (active.url === null || active.url === 'hive://start' || active.url.indexOf('hive://start') === 0) {
        addrInput.value = '';
        $('addrLock').dataset.secure = 'false';
        $('addrLock').title = '';
        addrFav.hidden = true;
        $('addrLockGlyph').hidden = false;
      } else {
        addrInput.value = active.url;
        var isSecure = active.url.indexOf('https://') === 0;
        $('addrLock').dataset.secure = isSecure ? 'true' : 'false';
        $('addrLock').title = isSecure
          ? 'Connection is secure — click for site settings'
          : 'Connection is not secure — click for site settings';
        // Chrome omnibox convention: the page favicon leads the address bar;
        // the lock glyph only shows when no favicon is available or the
        // connection is not secure. The browser caches favicon fetches, so
        // re-assigning src each render is cheap.
        if (fav && fav !== failedFavicon) {
          addrFav.src = fav;
          addrFav.hidden = false;
          $('addrLockGlyph').hidden = isSecure;
          addrFav.onerror = function () { failedFavicon = fav; this.hidden = true; $('addrLockGlyph').hidden = false; };
        } else {
          addrFav.hidden = true;
          $('addrLockGlyph').hidden = false;
        }
      }
    }
    var isLoading = !!(active && active.isLoading);
    $('btnReload').title = isLoading ? 'Stop (Esc)' : 'Reload (⌘R)';
    $('btnBookmark').dataset.active = active && active.isBookmarked ? 'true' : 'false';
    $('btnBookmark').style.color = active && active.isBookmarked ? 'var(--accent-3)' : '';
    // Reader Mode is only meaningful on real web pages (Safari parity).
    var url = active && active.url ? String(active.url) : '';
    var isWebPage = url.indexOf('http://') === 0 || url.indexOf('https://') === 0;
    $('btnReader').hidden = !isWebPage;
    $('btnReader').dataset.active = active && active.isReaderMode ? 'true' : 'false';
    $('btnReader').title = active && active.isReaderMode ? 'Exit Reader Mode' : 'Reader Mode';
    // Live zoom indicator (Chrome/Arc parity): shown only when zoom ≠ 100%.
    var zoom = active && active.zoomPercent ? Math.round(active.zoomPercent) : 100;
    var zoomBtn = $('btnZoom');
    zoomBtn.hidden = zoom === 100;
    zoomBtn.textContent = zoom + '%';
    zoomBtn.title = 'Zoom ' + zoom + '% — click to reset (⌘0)';
    // Address bar loading progress bar (Chrome/Safari convention): a subtle
    // animated bar below the address bar that fills while the page loads.
    var progress = $('addrProgress');
    if (progress) {
      if (active && active.loadProgress !== undefined) {
        progress.style.transform = 'scaleX(' + Math.max(0.05, active.loadProgress || 0) + ')';
        progress.classList.toggle('loading', active.isLoading);
      } else {
        progress.style.transform = '';
        progress.classList.toggle('loading', !!isLoading);
      }
    }
  }

  var addrTimer = null;
  function onAddrInput() {
    clearTimeout(addrTimer);
    var q = addrInput.value.trim();
    if (!q) { hideSuggest(); return; }
    addrTimer = setTimeout(function () {
      api('hive.suggest', { text: q }).then(function (res) {
        if (!res || !res.suggestions || !res.suggestions.length) { hideSuggest(); return; }
        // Paste-and-go pins above native results while the field is untouched.
        // URL-ish text offers "Paste and go to …" (Chrome); anything else
        // offers "Paste and search for …" — same omnibox convention.
        var items = res.suggestions;
        if (pasteGoText && addrInput.value.trim() === pasteGoText) {
          var pasteGo = looksLikeURL(pasteGoText)
            ? { kind: 'url', text: 'Paste and go to ' + pasteGoText, url: pasteGoText }
            : { kind: 'search', text: 'Paste and search for "' + pasteGoText + '"', query: pasteGoText };
          items = [pasteGo].concat(items);
        }
        renderSuggest(items);
      });
    }, 120);
  }

  var suggIndex = -1;
  var suggestEntered = false;
  function renderSuggest(items) {
    suggIndex = -1;
    suggestBox.innerHTML = '';
    // Gate stagger animation: only animate on first reveal, not every keystroke
    if (!suggestEntered) {
      suggestBox.classList.add('suggest--entering');
      suggestEntered = true;
    }
    items.forEach(function (s) {
      var row = el('div', 'sugg', null);
      var isURL = s.kind === 'url' || s.kind === 'history';
      row.innerHTML = (isURL
        ? '<span class="sugg__icon">' + svg(ICONS.globe, 14) + '</span>'
        : '<span class="sugg__icon">' + svg(ICONS.search, 14) + '</span>') +
        '<span class="sugg__text">' + esc(s.text) + '</span>' +
        (s.url ? '<span class="sugg__url">' + esc(s.url) + '</span>' : '');
      row.__sugg = s;
      row.addEventListener('click', function (e) {
        if (s.tabID && IS_CHROME) api('hive.selectTab', { id: s.tabID });
        else openURL(s.url || s.query || s.text, e);
        hideSuggest();
      });
      suggestBox.appendChild(row);
    });
    suggestBox.hidden = false;
    // Spring-powered entrance
    if (window.HivePhysics && window.HivePhysics.animateSpring && !document.body.classList.contains('no-motion')) {
      suggestBox.style.transform = 'translateY(-8px)';
      suggestBox.style.opacity = '0';
      requestAnimationFrame(function () {
        window.HivePhysics.animateSpring(
          window.HivePhysics.SpringPresets.bounce, -8, 0, 280,
          function (val) {
            suggestBox.style.transform = 'translateY(' + val + 'px)';
            suggestBox.style.opacity = 1 - Math.min(Math.abs(val) / 8, 1);
          },
          function () {
            suggestBox.style.transform = '';
            suggestBox.style.opacity = '';
          }
        );
      });
    }
  }

  function hideSuggest() {
    suggestBox.hidden = true;
    suggIndex = -1;
    suggestBox.classList.remove('suggest--entering');
    suggestEntered = false;
  }

  // Grow the chrome frame while the address bar is focused (sidebar mode).
  addrInput.addEventListener('focus', function () {
    if (state.chromeMode === 'sidebar') api('hive.setChromeDimension', { dimension: 560 });
    else api('hive.setChromeDimension', { dimension: 420 });
    // Browser convention: focusing the URL bar selects the whole address so
    // typing replaces it (⌘L / click). A tick keeps the click's caret from
    // fighting the selection; a second click drops the selection for editing.
    var self = this;
    setTimeout(function () { self.select(); }, 0);
  });
  addrInput.addEventListener('blur', function () {
    // P2.4 parity with the native bar: the ⇧⏎ affordance only shows while focused.
    $('aiHint').hidden = true;
    setTimeout(function () {
      if (!state.isChromePanelOpen) api('hive.setChromeDimension', { dimension: 270 });
    }, 120);
  });
  addrInput.addEventListener('input', function () {
    // P2.4: show the ⇧⏎ Ask Hive affordance only while typing.
    $('aiHint').hidden = !addrInput.value.trim();
    $('addrClear').hidden = !addrInput.value.trim();
    // Editing after a paste clears the pinned paste-and-go row.
    if (pasteGoText && addrInput.value.trim() !== pasteGoText) pasteGoText = '';
    onAddrInput();
  });

  // Paste-and-go (Chrome omnibox convention): pasting into the address bar
  // pins a "Paste and go to …" / "Paste and search for …" suggestion above
  // the native results, committed with Enter or click. It stays pinned only
  // while the field is untouched.
  var pasteGoText = '';
  // URL heuristic (Chrome omnibox): explicit scheme, or a bare hostname with
  // at least one dot / localhost — anything else pastes as a search query.
  function looksLikeURL(t) {
    if (!t) return false;
    if (/^[a-z][a-z0-9+.-]*:\/\//i.test(t)) return true;
    if (/\s/.test(t)) return false;
    if (/^localhost(:\d+)?$/i.test(t)) return true;
    // Bare hostname: at least one dot, and the final label must start with a
    // letter (so version strings like "1.2.3" stay searches, matching Chrome).
    return /^[a-z0-9-]+(\.[a-z][a-z0-9-]*)+/i.test(t);
  }
  addrInput.addEventListener('paste', function (e) {
    var text = (e.clipboardData ? e.clipboardData.getData('text') : '') || '';
    text = text.trim();
    pasteGoText = (text && text.length <= 2048) ? text : '';
  });

  // Address-bar clear (✕) — browser convention for fast wipe + retype.
  $('addrClear').addEventListener('click', function () {
    addrInput.value = '';
    $('aiHint').hidden = true;
    $('addrClear').hidden = true;
    hideSuggest();
    addrInput.focus();
  });

  // Security lock → the per-site settings hub for the active page (Chrome
  // chrome://settings/content parity).
  $('addrLock').addEventListener('click', function () {
    // Chrome parity: lock click opens site info panel showing certificate,
    // cookies, and a link to full permissions control.
    var active = state.tabs.find(function (t) { return t.id === state.activeTabID; });
    if (active && (active.url.indexOf('http://') === 0 || active.url.indexOf('https://') === 0)) {
      openPanel('siteinfo');
    }
  });
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
      // stopPropagation: the two-stage behavior must not be cut short by the
      // document-level Esc chain (which would blur the field right after the
      // first Esc restores the URL).
      e.stopPropagation();
      // Two-stage Esc (Chrome omnibox): a first Esc closes the suggestion
      // list and restores the page URL; a second Esc blurs the field.
      if (!suggestBox.hidden) {
        hideSuggest();
        return;
      }
      var committedTab = state.tabs.find(function (x) { return x.id === state.activeTabID; });
      var committed = committedTab && committedTab.url &&
        (committedTab.url.indexOf('http://') === 0 || committedTab.url.indexOf('https://') === 0)
        ? committedTab.url : '';
      if (committed && addrInput.value !== committed) {
        addrInput.value = committed;
        onAddrInput();
        addrInput.select();
      } else {
        addrInput.blur();
      }
    } else if (e.key === 'Tab') {
      // Chrome omnibox convention: Tab completes the field with the
      // highlighted suggestion's URL (or the first suggestion when none is
      // highlighted), without committing the navigation.
      var tabRows = suggestBox.querySelectorAll('.sugg');
      if (tabRows.length) {
        e.preventDefault();
        var chosen = suggIndex >= 0 ? tabRows[suggIndex] : tabRows[0];
        var s = chosen.__sugg;
        if (s.url) {
          addrInput.value = s.url;
          onAddrInput();
          addrInput.select();
        }
      }
    } else if (e.key === 'Enter') {
      e.preventDefault();
      // P2.4 dual-mode URL bar: ⇧⏎ sends the text to the agent dock
      // instead of navigating/searching (Dia parity).
      if (e.shiftKey && !e.metaKey) {
        agentAsk(addrInput.value);
        addrInput.value = '';
        hideSuggest();
        return;
      }
      // Chrome omnibox conventions: ⌘⏎ appends .com, ⌘⇧⏎ appends .org, and
      // ⌥⌘⏎ appends .net — but ONLY when the input is a bare hostname (no
      // scheme, no dot, no spaces), exactly like Chrome. A chosen suggestion
      // always wins over the modifier.
      var tld = null;
      if (e.metaKey) {
        var bare = /^[a-z0-9-]+$/i.test(addrInput.value.trim());
        if (bare) tld = e.altKey ? '.net' : (e.shiftKey ? '.org' : '.com');
      }
      var chosen = suggIndex >= 0 && items[suggIndex];
      if (chosen) {
        var s = chosen.__sugg;
        if (s.tabID && IS_CHROME) api('hive.selectTab', { id: s.tabID });
        else navigate(s.url || s.query || s.text);
      } else if (tld) {
        submitAddress(addrInput.value.trim() + tld);
      } else {
        submitAddress(addrInput.value);
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

  // Back/forward long-press + right-click history menus (Chrome/Safari
  // convention): hold the button (~600ms) or right-click it to reveal the
  // recent committed entries; picking one jumps the active tab to it. A hold
  // that opened the menu suppresses the click that fires on release, so the
  // page never navigates on top of the menu.
  function navHistoryMenu(direction, anchor, atX, atY) {
    var tab = state.tabs.find(function (t) { return t.id === state.activeTabID; });
    var entries = direction === 'back'
      ? (tab && tab.backHistory) : (tab && tab.forwardHistory);
    if (!entries || !entries.length) return;
    ctx.innerHTML = '';
    entries.forEach(function (e) {
      var b = el('button', 'ctxmenu__item');
      b.textContent = e.title || e.url;
      b.title = e.url || '';
      b.addEventListener('click', function () {
        ctx.hidden = true;
        api('hive.navigate', { url: e.url });
      });
      ctx.appendChild(b);
    });
    ctx.hidden = false;
    var x = atX, y = atY;
    if (x === undefined) {
      var rect = anchor.getBoundingClientRect();
      x = rect.left;
      y = rect.bottom + 4;
    }
    var w = ctx.offsetWidth, h = ctx.offsetHeight;
    ctx.style.left = Math.min(x, window.innerWidth - w - 8) + 'px';
    ctx.style.top = Math.min(y, window.innerHeight - h - 8) + 'px';
  }
  [
    ['btnBack', 'back'],
    ['btnForward', 'forward']
  ].forEach(function (pair) {
    var btn = $(pair[0]);
    var holdTimer = null;
    btn.addEventListener('pointerdown', function (e) {
      if (e.button !== 0) return;
      clearTimeout(holdTimer);
      holdTimer = setTimeout(function () {
        navHistoryMenu(pair[1], btn);
        // One-shot DOCUMENT-level capture guard for the release-click that
        // follows this hold. Listeners on the button itself fire in target
        // phase in registration order (the navigate listener is registered
        // first), so a same-element guard would run too late. Document capture
        // runs before the target phase; the contains() gate lets a subsequent
        // context-menu item click (also a click event) navigate normally.
        document.addEventListener('click', function guard(e) {
          document.removeEventListener('click', guard, true);
          if (e.target && btn.contains(e.target)) {
            e.stopPropagation();
            e.preventDefault();
          }
        }, true);
      }, 600);
    });
    btn.addEventListener('pointerup', function () { clearTimeout(holdTimer); });
    btn.addEventListener('pointerleave', function () { clearTimeout(holdTimer); });
    btn.addEventListener('contextmenu', function (e) {
      e.preventDefault();
      navHistoryMenu(pair[1], btn, e.clientX, e.clientY);
    });
  });
  $('btnHome').addEventListener('click', function () { api('hive.goHome'); });
  // Reload ↔ Stop toggle (Chrome parity): while the page loads the button
  // shows a stop square; clicking it cancels the load.
  $('btnReload').addEventListener('click', function () {
    if (this.classList.contains('reloading')) {
      this.classList.remove('reloading');
      api('hive.stop');
    } else {
      this.classList.add('reloading');
      api('hive.reload');
    }
  });
  // Right-click Reload shows the page-actions reload menu (Chrome parity):
  // plain Reload vs Empty Cache and Hard Reload (⌥⌘R).
  $('btnReload').addEventListener('contextmenu', function (e) {
    e.preventDefault();
    var items = [
      { label: 'Reload (⌘R)', action: function () { api('hive.reload'); } },
      { label: 'Empty Cache and Hard Reload (⌥⌘R)', action: function () { api('hive.reloadIgnoringCache'); } }
    ];
    ctx.innerHTML = '';
    items.forEach(function (item) {
      var b = el('button', 'ctxmenu__item');
      b.textContent = item.label;
      b.addEventListener('click', function () { ctx.hidden = true; item.action(); });
      ctx.appendChild(b);
    });
    ctx.hidden = false;
    var w = ctx.offsetWidth, h = ctx.offsetHeight;
    ctx.style.left = Math.min(e.clientX, window.innerWidth - w - 8) + 'px';
    ctx.style.top = Math.min(e.clientY, window.innerHeight - h - 8) + 'px';
  });
  $('btnBookmark').addEventListener('click', function () {
    api('hive.toggleBookmark');
    // Spring-powered star burst — scales up then settles back
    var btn = $('btnBookmark');
    if (window.HivePhysics && window.HivePhysics.animateSpring && !document.body.classList.contains('no-motion')) {
      btn.style.transition = 'none';
      btn.style.transform = 'scale(0.5)';
      requestAnimationFrame(function () {
        window.HivePhysics.animateSpring(
          window.HivePhysics.SpringPresets.bounce, 0.5, 1, 360,
          function (val) { btn.style.transform = 'scale(' + val + ')'; },
          function () { btn.style.transform = ''; btn.style.transition = ''; }
        );
      });
    }
  });
  $('btnReader').addEventListener('click', function () {
    api('hive.toggleReaderMode').then(function () { refresh(); });
  });
  $('btnFullscreen').addEventListener('click', function () { api('hive.toggleFullscreen'); });
  $('btnZoom').addEventListener('click', function () {
    api('hive.resetZoom').then(function () { refresh(); });
  });
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
    state.lastQuery = q;
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

  // Wire static listeners once at init — never inside render functions
  // (renderStartPage re-runs on every refresh; stacking listeners there
  // would open the brief route more than once per click).
  $('btnOpenBrief').addEventListener('click', function () {
    if (IS_CHROME) api('hive.openBrief');
    else window.location.href = 'hive://brief/';
  });

  $('btnCouncil').addEventListener('click', function () {
    var active = state.tabs.find(function (t) { return t.id === state.activeTabID; });
    var question = active ? 'Summarize: ' + (active.title || active.host || 'this page') : 'What can you help me with?';
    api('hive.agent.run', { text: question }).then(function () { refresh(); });
  });
  // Chrome kebab (⋮): quick access to tab, window, page, and panel actions.
  function showChromeMenu(btn) {
    var items = [
      { label: 'New Tab (⌘T)', run: function () { api('hive.newTab'); } },
      { label: 'New Window (⌘N)', run: function () { api('hive.newWindow'); } },
      { label: 'New Private Tab (⇧⌘N)', run: function () { api('hive.newPrivateTab'); } },
      { label: 'Reopen Closed Tab (⌘⇧T)', run: function () { api('hive.reopenClosedTab'); } },
      { sep: true },
      { label: 'Tab Search (⌘⇧A)', run: function () { openTabSearch(); } },
      { label: 'Find in Page (⌘F)', run: function () { api('hive.openFindBar'); } },
      { label: 'Zoom In (⌘+)', run: function () { api('hive.zoomIn'); } },
      { label: 'Zoom Out (⌘−)', run: function () { api('hive.zoomOut'); } },
      { label: 'Reset Zoom (⌘0)', run: function () { api('hive.resetZoom'); } },
      { label: 'Reader Mode (⌘⇧R)', run: function () { api('hive.toggleReaderMode'); } },
      { label: 'Reload Ignoring Cache (⌥⌘R)', run: function () { api('hive.reloadIgnoringCache'); } },
      { label: 'Copy Current URL (⌘⇧C)', run: copyCurrentURL },
      { sep: true },
      { label: 'Sessions', run: function () { openPanel('sessions'); } },
      { label: 'Downloads (⌘⇧J)', run: function () { openPanel('downloads'); } },
      { label: 'History (⌘Y)', run: function () { openPanel('history'); } },
      { label: 'Bookmarks (⌘B)', run: function () { openPanel('bookmarks'); } },
      { sep: true },
      { label: 'Settings (⌘,)', run: function () { openPanel('settings'); } },
      { label: 'Print… (⌘P)', run: function () { api('hive.printPage'); } },
      { label: 'Fullscreen (⌃⌘F)', run: function () { api('hive.toggleFullscreen'); } },
      { label: 'Developer Tools', run: function () { api('hive.openDevTools', { id: state.activeTabID }); } }
    ];
    ctx.innerHTML = '';
    items.forEach(function (item) {
      if (item.sep) { ctx.appendChild(el('div', 'ctxmenu__sep')); return; }
      var b = el('button', 'ctxmenu__item');
      b.textContent = item.label;
      b.addEventListener('click', function () { ctx.hidden = true; item.run(); });
      ctx.appendChild(b);
    });
    var r = btn.getBoundingClientRect();
    showCtxAt(r.left, r.bottom + 4);
  }
  function copyCurrentURL() {
    var active = state.tabs.find(function (t) { return t.id === state.activeTabID; });
    var url = active && active.url ? active.url : '';
    if (url && url.indexOf('hive://') === 0) url = '';
    if (!url) { showToast('No page URL to copy', 'error'); return; }
    // Native bridge (NSPasteboard) — reliable in the cefswift:// context,
    // unlike navigator.clipboard which requires a secure context.
    api('hive.copyLink', { url: url }).then(function (ok) {
      showToast(ok ? 'Copied ' + url.slice(0, 48) : 'Could not copy URL', ok ? 'success' : 'error');
    });
  }
  $('btnMenu').addEventListener('click', function () { showChromeMenu(this); });
  $('btnNewTab').addEventListener('click', function () { api('hive.newTab'); });
  // Chrome convention: middle-click the + button opens a tab in the background.
  $('btnNewTab').addEventListener('auxclick', function (e) {
    if (e.button === 1) { e.preventDefault(); api('hive.newTabBackground'); }
  });

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
      // Keyboard-accessible workspace switcher (role + roving focus).
      w.setAttribute('role', 'button');
      w.tabIndex = -1;
      w.addEventListener('click', function () { api('hive.switchWorkspace', { id: ws.id }); });
      w.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          api('hive.switchWorkspace', { id: ws.id });
        } else if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
          e.preventDefault();
          var next = w.nextElementSibling;
          if (next) { next.tabIndex = 0; next.focus(); }
        } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
          e.preventDefault();
          var prev = w.previousElementSibling;
          if (prev) { prev.tabIndex = 0; prev.focus(); }
        }
      });
      w.addEventListener('focus', function () { w.tabIndex = 0; });
      w.addEventListener('blur', function () { w.tabIndex = -1; });
      // Middle-click switches workspace too (tab-strip convention).
      w.addEventListener('auxclick', function (e) {
        if (e.button !== 1) return;
        e.preventDefault();
        api('hive.switchWorkspace', { id: ws.id });
      });
      // DND drop target: drag a tab onto a workspace dot to move it
      w.addEventListener('dragover', function (e) {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
        w.classList.add('workspace--drop-target');
      });
      w.addEventListener('dragleave', function () { w.classList.remove('workspace--drop-target'); });
      w.addEventListener('drop', function (e) {
        e.preventDefault();
        w.classList.remove('workspace--drop-target');
        if (dragID) { api('hive.moveTabToWorkspace', { tabID: dragID, groupID: ws.id }); }
      });
      // Right-click a workspace chip for the workspace menu (switch / new /
      // delete — Chrome+Arc parity; delete is guarded natively to ≥1 space).
      w.addEventListener('contextmenu', function (e) {
        e.preventDefault();
        e.stopPropagation();
        showWorkspaceMenu(e.clientX, e.clientY, ws);
      });
      row.appendChild(w);
    });
    // Arc/Zen parity: a + affordance at the end of the space list creates a
    // new workspace instantly (default name + next preset color).
    var add = el('button', 'workspace workspace--add', null);
    add.type = 'button';
    add.innerHTML = '<svg viewBox="0 0 24 24" fill="none" style="width:12px;height:12px" aria-hidden="true"><path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>';
    add.title = 'New workspace';
    add.setAttribute('aria-label', 'New workspace');
    add.tabIndex = -1;
    add.addEventListener('click', function () {
      api('hive.createWorkspace', {
        name: 'Workspace ' + (state.spaces.length + 1),
        colorHex: ACCENT_PRESETS[state.spaces.length % ACCENT_PRESETS.length],
        iconName: 'circle.fill'
      }).then(function () { refresh(); });
    });
    row.appendChild(add);
  }
  function showWorkspaceMenu(x, y, ws) {
    var items = [
      { label: 'Switch to ' + ws.name, run: function () { api('hive.switchWorkspace', { id: ws.id }); } },
      { sep: true },
      { label: 'New workspace', run: function () {
        api('hive.createWorkspace', {
          name: 'Workspace ' + (state.spaces.length + 1),
          colorHex: ACCENT_PRESETS[state.spaces.length % ACCENT_PRESETS.length],
          iconName: 'circle.fill'
        }).then(function () { refresh(); });
      } },
      { label: 'Delete workspace', danger: true, run: function () {
        confirmAction('Delete "' + ws.name + '" and close its tabs?', function (ok) {
          if (ok) api('hive.deleteWorkspace', { id: ws.id }).then(function () { refresh(); });
        }, 'Delete');
      } }
    ];
    ctx.innerHTML = '';
    items.forEach(function (item) {
      if (item.sep) { ctx.appendChild(el('div', 'ctxmenu__sep')); return; }
      var b = el('button', 'ctxmenu__item' + (item.danger ? ' ctxmenu__item--danger' : ''));
      b.textContent = item.label;
      b.addEventListener('click', function () { ctx.hidden = true; item.run(); });
      ctx.appendChild(b);
    });
    showCtxAt(x, y);
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

    // Council convening — shimmer skeleton while waiting, then live responses
    if (state.isCouncilConvening) {
      var live = state.councilLiveResponses || [];
      if (!live.length) {
        // Loading state — Polar-style shimmer skeleton (U7 5-state sweep)
        html += '<div class="ai-panel">' +
          '<div class="ai-panel__header">' +
          '<span class="ai-panel__icon">' + svg(ICONS.settings, 13) + '</span>' +
          '<span class="ai-panel__label">Council deliberating…</span>' +
          '</div>' +
          '<div class="ai-panel__skeleton-row">' +
          '<div class="ai-panel__skeleton ai-panel__skeleton--sm"></div>' +
          '</div>' +
          '<div class="ai-panel__skeleton-row">' +
          '<div class="ai-panel__skeleton ai-panel__skeleton--md"></div>' +
          '</div>' +
          '<div class="ai-panel__skeleton-row">' +
          '<div class="ai-panel__skeleton ai-panel__skeleton--sm"></div>' +
          '</div>' +
          '</div>';
      } else {
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
    }

    // Error state — council or agent failure (U7 5-state sweep)
    if (state.councilError && !state.isCouncilConvening && !council) {
      html += '<div class="ai-panel ai-panel--error">' +
        '<div class="ai-panel__header">' +
        '<span class="ai-panel__icon">' + svg(ICONS.close, 13) + '</span>' +
        '<span class="ai-panel__label">Council failed</span>' +
        '</div>' +
        '<div class="ai-panel__error-body">' + esc(state.councilError.toString().slice(0, 200)) + '</div>' +
        '<button class="ai-panel__retry" onclick="hiveRetryCouncil()">' +
        svg(ICONS.clock, 10) + ' Retry</button>' +
        '</div>';
    }
    if (state.agentError && !state.isCouncilConvening && !council &&
        (!agent || agent.phase === 'idle' || agent.phase === 'done')) {
      html += '<div class="ai-panel ai-panel--error">' +
        '<div class="ai-panel__header">' +
        '<span class="ai-panel__icon">' + svg(ICONS.close, 13) + '</span>' +
        '<span class="ai-panel__label">Agent failed</span>' +
        '</div>' +
        '<div class="ai-panel__error-body">' + esc(state.agentError.toString().slice(0, 200)) + '</div>' +
        '<button class="ai-panel__retry" onclick="hiveDismissError()">' +
        svg(ICONS.close, 10) + ' Dismiss</button>' +
        '</div>';
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
    state.councilError = null;
    state.agentError = null;
    api('hive.dismissCouncilVerdict').then(function () { refresh(); });
    renderAIPanel();
  }

  function hiveCancelAgent() {
    api('hive.agent.cancel').then(function () { refresh(); });
  }

  function hiveRetryCouncil() {
    state.councilError = null;
    var q = state.lastQuery || 'Summarize this page';
    api('hive.agent.run', { text: q }).then(function () { refresh(); });
  }

  function hiveDismissError() {
    state.councilError = null;
    state.agentError = null;
    renderAIPanel();
  }

  /* ---------- panels ---------- */

  function openPanel(name) {
    state.isChromePanelOpen = name;
    api('hive.setPanel', { panel: name });
    var panel = $('panel');
    var titles = { settings: 'Settings', history: 'History', bookmarks: 'Bookmarks', downloads: 'Downloads', reading: 'Reading List', permissions: 'Site Permissions', siteinfo: 'Site Info', sessions: 'Sessions' };
    $('panelTitle').textContent = titles[name] || 'Panel';
    panel.hidden = false;
    // Spring physics entrance — slides in with overshoot
    panel.style.transform = 'translateX(60px)';
    panel.style.opacity = '0';
    requestAnimationFrame(function () {
      if (window.HivePhysics && window.HivePhysics.animateSpring) {
        window.HivePhysics.animateSpring(
          window.HivePhysics.SpringPresets.bounce, 60, 0, 380,
          function (val) {
            panel.style.transform = 'translateX(' + val + 'px)';
            panel.style.opacity = 1 - Math.min(val / 60, 1);
          },
          function () {
            panel.style.transform = '';
            panel.style.opacity = '';
            panel.classList.add('panel--open');
          }
        );
      } else {
        panel.classList.add('panel--open');
      }
    });
    renderPanel();
  }
  function closePanel() {
    state.isChromePanelOpen = null;
    api('hive.setPanel', { panel: '' });
    var panel = $('panel');
    if (window.HivePhysics && window.HivePhysics.animateSpring) {
      panel.classList.remove('panel--open');
      window.HivePhysics.animateSpring(
        window.HivePhysics.SpringPresets.snap, 0, 60, 220,
        function (val) {
          panel.style.transform = 'translateX(' + val + 'px)';
          panel.style.opacity = 1 - Math.min(val / 60, 1);
        },
        function () {
          panel.style.transform = '';
          panel.style.opacity = '';
          panel.hidden = true;
        }
      );
    } else {
      panel.classList.remove('panel--open');
      setTimeout(function () { panel.hidden = true; }, 250);
    }
  }

  function renderPanel() {
    var name = state.isChromePanelOpen;
    var body = $('panelBody');
    if (!name) return;
    if (name === 'settings') body.innerHTML = settingsHTML();
    else if (name === 'history')
      body.innerHTML = historyPanelHTML() +
        (state.history.length ? '<button class="le__clear" data-clear-history>Clear history</button>' : '');
    else if (name === 'bookmarks') body.innerHTML = bookmarksHTML();
    else if (name === 'downloads') body.innerHTML = downloadsPanelHTML() +
      (state.downloads.length ? '<button class="le__clear" data-clear-downloads>Clear finished downloads</button>' : '');
    else if (name === 'reading') body.innerHTML = readingListPanelHTML();
    else if (name === 'permissions') body.innerHTML = permissionsPanelHTML();
    else if (name === 'siteinfo') body.innerHTML = siteInfoPanelHTML();
    else if (name === 'sessions') {
      body.innerHTML = sessionsPanelHTML();
      api('hive.listSessions').then(function (res) {
        state.sessions = res || [];
        if (state.isChromePanelOpen === 'sessions') renderPanel();
      });
    }
    wirePanelEvents(body, name);
  }

  /* ---------- status bubble ---------- */
  // Chrome convention: hovering any chrome surface that leads somewhere shows
  // the destination URL in a small bottom-left bubble. It clears when the
  // pointer leaves a URL-bearing element, leaves the window, or blurs.
  var hiveStatus = null;
  function statusURL(url) {
    if (!hiveStatus) {
      hiveStatus = document.createElement('div');
      hiveStatus.id = 'hiveStatus';
      document.body.appendChild(hiveStatus);
    }
    hiveStatus.textContent = url || '';
    hiveStatus.hidden = !url;
  }
  document.addEventListener('pointerover', function (e) {
    var el = e.target && e.target.closest ? e.target.closest('[data-url], a[href]') : null;
    if (el) {
      var u = el.getAttribute('data-url') || el.getAttribute('href');
      if (u) { statusURL(u); return; }
    }
    statusURL('');
  });
  document.addEventListener('pointerleave', function () { statusURL(''); });
  window.addEventListener('blur', function () { statusURL(''); });

  function listHTML(items, cls, rowFn, emptyText) {
    if (!items.length) {
      return '<div class="palette__empty">' + (emptyText || 'Nothing here yet.') + '</div>';
    }
    return items.map(rowFn).join('');
  }

  // Chrome-history grouping: Today / Yesterday / This Week / Older headers
  // (dayLabel comes from the native snapshot, matching the native HistoryPanel).
  var historyQuery = '';
  var historySearchResults = null; // results from the native hive.searchHistory bridge
  var historySearchToken = 0;      // monotonic guard against stale async results
  function historyPanelHTML() {
    var listHTML_ = historyListHTML();
    if (!listHTML_) return '<div class="empty-state">' +
      '<div class="empty-state__icon">' + svg(ICONS.history, 26) + '</div>' +
      '<p class="empty-state__title">No browsing history yet</p>' +
      '<p class="empty-state__hint">Pages you visit will appear here. Press ⌘L to start exploring.</p></div>';
    return '<div class="panel-search">' +
      svg(ICONS.search, 13) +
      '<input id="historySearch" type="search" placeholder="Search history (⌘F)" value="' + esc(historyQuery) + '" aria-label="Search history">' +
      (historyQuery ? '<button class="panel-search__clear" id="historySearchClear" aria-label="Clear search">' + svg(ICONS.close, 11) + '</button>' : '') +
      '</div>' + listHTML_;
  }
  function historyListHTML() {
    if (!state.history.length && !historySearchResults) return '';
    var q = historyQuery.trim().toLowerCase();
    var items;
    if (!q) {
      items = state.history;
    } else if (historySearchResults) {
      // Native substring search — authoritative, with relative day/time labels.
      items = historySearchResults;
    } else {
      // Local filter while the native round-trip is in flight.
      items = state.history.filter(function (i) {
        return (i.title || '').toLowerCase().indexOf(q) >= 0 ||
          (i.url || '').toLowerCase().indexOf(q) >= 0 ||
          (i.host || '').toLowerCase().indexOf(q) >= 0;
      });
    }
    if (!items.length) return '<div class="palette__empty">No results for "' + esc(historyQuery) + '"</div>';
    var groups = [];
    var order = ['Today', 'Yesterday', 'This Week', 'Older'];
    items.forEach(function (item) {
      var key = item.dayLabel || 'Older';
      var g = groups[groups.length - 1];
      if (!g || g.key !== key) { g = { key: key, items: [] }; groups.push(g); }
      g.items.push(item);
    });
    groups.sort(function (a, b) { return order.indexOf(a.key) - order.indexOf(b.key); });
    return groups.map(function (g) {
      return '<div class="history-group"><div class="history-group__header">' + esc(g.key) +
        '</div>' + g.items.map(historyRow).join('') + '</div>';
    }).join('');
  }

  function historyRow(item) {
    var hue = Math.abs(hash(item.host || item.url || '')) % 360;
    return '<div class="le" data-url="' + esc(item.url) + '" data-history-id="' + esc(item.historyID || '') +
      '" title="' + esc(item.url) + '">' +
      tileHTML(item.host, item.title, hue) +
      '<span class="le__body"><span class="le__title">' + esc(item.title) + '</span>' +
      '<span class="le__meta">' + esc(item.url) + '</span></span>' +
      '<span class="le__time">' + esc(item.timeLabel) + '</span>' +
      (item.historyID ? '<button class="le__del" title="" aria-label="Delete entry">' + svg(ICONS.close, 10) + '</button>' : '') +
      '</div>';
  }
  function bookmarkRow(bm) {
    var hue = Math.abs(hash(bm.host || bm.title || '')) % 360;
    return '<div class="le" data-url="' + esc(bm.url) + '" data-bm-id="' + esc(bm.id) + '" title="' + esc(bm.url) + '">' +
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
    // Chrome parity: pause/resume/cancel controls on live rows (a paused row
    // may resume, an active row may pause or cancel, nothing terminal is
    // mutable). Actions refresh the panel through the native snapshot.
    var controls = '';
    if (st === 'completed' && dl.hasDestination) {
      controls = '<span class="le__actions">' +
        '<button class="le__act" data-dl-act="open-file" data-dl-id="' + esc(dl.id) + '" title="Open file">' + svg(ICONS.eye, 12) + '</button>' +
        '<button class="le__act" data-dl-act="reveal" data-dl-id="' + esc(dl.id) + '" title="Show in Finder">' + svg(ICONS.folder, 12) + '</button>' +
        '</span>';
    } else if (st === 'paused') {
      controls = '<span class="le__actions">' +
        '<button class="le__act" data-dl-act="resume" data-dl-id="' + esc(dl.id) + '" title="Resume download">' + svg(ICONS.play, 12) + '</button>' +
        '<button class="le__act le__act--danger" data-dl-act="cancel" data-dl-id="' + esc(dl.id) + '" title="Cancel download">' + svg(ICONS.close, 12) + '</button>' +
        '</span>';
    } else if (inFlight) {
      controls = '<span class="le__actions">' +
        '<button class="le__act" data-dl-act="pause" data-dl-id="' + esc(dl.id) + '" title="Pause download">' + svg(ICONS.pause, 12) + '</button>' +
        '<button class="le__act le__act--danger" data-dl-act="cancel" data-dl-id="' + esc(dl.id) + '" title="Cancel download">' + svg(ICONS.close, 12) + '</button>' +
        '</span>';
    }
    return '<div class="le" data-url="' + esc(dl.url) + '" data-dl-id="' + esc(dl.id) +
      '" data-dl-state="' + esc(st) + '" title="' + esc(dl.url) + '">' +
      '<span class="le__tile">' + svg(ICONS.download, 14) + '</span>' +
      '<span class="le__body"><span class="le__title">' + esc(dl.title || dl.name || 'Download') + '</span>' +
      '<span class="le__meta">' + esc(dl.url) + '</span>' +
      '<span class="le__state">' + esc(label) + (inFlight ? ' · ' + pct + '%' : '') + '</span>' + bar +
      '</span>' + controls + '</div>';
  }

  // Chrome downloads panel convention: Active / Completed / Failed sections
  // with headers rather than one undifferentiated list. The buckets match the
  // native state strings exactly (completed / cancelled / failed / paused /
  // inProgress / pending) so a canceled or failed file is never presented
  // under a "Completed" header.
  function sessionsPanelHTML() {
    var s = state.sessions || [];
    if (!s.length) return '<div class="empty-state">' +
      '<div class="empty-state__icon">' + svg(ICONS.clock, 26) + '</div>' +
      '<p class="empty-state__title">No saved sessions</p>' +
      '<p class="empty-state__hint">Sessions are captured automatically. Reopen any session here — even after quitting Hive.</p></div>' +
      '<button class="le__clear" data-save-session style="width:100%">Save current session</button>';
    return '<button class="le__clear" data-save-session style="width:100%;margin-bottom:10px">Save current session</button>' +
      '<div class="panel-section"><h3>Recent Sessions</h3>' +
      '<div class="panel-search">' + svg(ICONS.search, 13) +
      '<input id="sessionSearch" type="search" placeholder="Filter sessions" aria-label="Filter sessions"></div>' +
      '<div id="sessionsList">' + s.map(sessionRow).join('') + '</div></div>';
  }
  function sessionRow(sess) {
    var hue = Math.abs(hash(sess.title || 'Session')) % 360;
    var meta = (sess.windowCount || 1) + ' window' + ((sess.windowCount || 1) !== 1 ? 's' : '') +
      ' · ' + (sess.tabCount || 0) + ' tab' + ((sess.tabCount || 0) !== 1 ? 's' : '');
    return '<div class="le" data-session-id="' + esc(sess.id) + '" data-session-title="' + esc((sess.title || '').toLowerCase()) + '">' +
      tileHTML(sess.title || 'Session', sess.title || 'Session', hue) +
      '<span class="le__body"><span class="le__title">' + esc(sess.title || 'Untitled session') + '</span>' +
      '<span class="le__meta">' + meta + '</span></span>' +
      '<span class="le__time">' + esc(sess.lastActiveAt || '') + '</span>' +
      '<button class="le__restore" title="Restore session" aria-label="Restore session">' + svg(ICONS.reload, 12) + '</button>' +
      '<button class="le__del" title="Delete session" aria-label="Delete session">' + svg(ICONS.close, 10) + '</button></div>';
  }
  function downloadsPanelHTML() {
    if (!state.downloads.length) return '<div class="empty-state">' +
      '<div class="empty-state__icon">' + svg(ICONS.download, 26) + '</div>' +
      '<p class="empty-state__title">No downloads yet</p>' +
      '<p class="empty-state__hint">Files you save will appear here with progress and quick-open.</p></div>';
    var active = [], completed = [], failed = [];
    state.downloads.forEach(function (dl) {
      var st = String(dl.state || 'pending');
      if (st === 'completed') completed.push(dl);
      else if (st === 'cancelled' || st === 'failed') failed.push(dl);
      else active.push(dl);
    });
    var header = function (t) { return '<div class="history-group__header">' + t + '</div>'; };
    var html = '';
    if (active.length) html += header('Active') + active.map(downloadRow).join('');
    if (completed.length) html += header('Completed') + completed.map(downloadRow).join('');
    if (failed.length) html += header('Failed & Cancelled') + failed.map(downloadRow).join('');
    return html;
  }

  function readingListPanelHTML() {
    var items = state.readingList || [];
    if (!items.length) return '<div class="palette__empty">' +
      '<div class="empty-state__icon">' + svg(ICONS.bookmark, 24) + '</div>' +
      '<p>Your reading list is empty</p>' +
      '<p style="color:var(--text-muted)">Right-click any tab and choose "Add to Reading List" to save articles for later.</p></div>';
    return items.map(function (item) {
      return '<div class="le" data-url="' + esc(item.url) + '" title="' + esc(item.url) + '">' +
        tileHTML(item.host, item.title, Math.abs(hash(item.host || item.url || '')) % 360) +
        '<span class="le__body"><span class="le__title">' + esc(item.title || 'Untitled') + '</span>' +
        '<span class="le__meta">' + esc(item.url) + '</span></span>' +
        '<button class="le__remove" data-remove-reading="' + esc(item.id || item.url) + '" title="Remove from reading list" aria-label="Remove from reading list">×</button></div>';
    }).join('') +
      (items.length ? '<button class="le__clear" data-clear-reading>Clear reading list</button>' : '');
  }

  function permissionsPanelHTML() {
    var active = state.tabs.find(function (t) { return t.id === state.activeTabID; });
    var host = active ? (active.host || 'this site') : 'this site';
    var perms = state.sitePermissions || {};
    function toggleRow(key, label, desc) {
      var on = perms[key] === 'allow';
      return '<div class="setting"><div><div class="setting__label">' + esc(label) + '</div>' +
        '<div class="setting__hint">' + esc(desc) + ' for ' + esc(host) + '</div></div>' +
        '<span class="toggle" data-perm="' + key + '" data-on="' + (on ? 'true' : 'false') + '"></span></div>';
    }
    return '<div class="panel-section">Permissions for ' + esc(host) + '</div>' +
      '<p style="font-size:12px;color:var(--text-muted);margin-bottom:8px">Changes apply immediately and persist across visits.</p>' +
      toggleRow('camera', 'Camera', 'Allow access to your camera') +
      toggleRow('microphone', 'Microphone', 'Allow access to your microphone') +
      toggleRow('location', 'Location', 'Allow access to your location') +
      toggleRow('notifications', 'Notifications', 'Show desktop notifications') +
      toggleRow('popups', 'Pop-ups', 'Allow pop-up windows') +
      '<div class="panel-section" style="margin-top:12px">Danger Zone</div>' +
      '<button class="le__clear" data-clear-site-data style="margin-top:4px">Clear data for ' + esc(host) + '</button>';
  }

  function siteInfoPanelHTML() {
    var active = state.tabs.find(function (t) { return t.id === state.activeTabID; });
    if (!active || !active.url) return '<div class="palette__empty">No active page</div>';
    var isSecure = active.url.indexOf('https://') === 0;
    var host = active.host || '';
    var fav = active.faviconURL || '';
    return '<div style="display:flex;align-items:center;gap:10px;margin-bottom:12px">' +
      (fav
        ? '<img src="' + esc(fav) + '" style="width:32px;height:32px;border-radius:6px;flex:none" alt="">'
        : '<span class="le__tile" style="background:hsl(' + (Math.abs(hash(host)) % 360) + ',32%,48%);width:32px;height:32px;font-size:16px">' + esc(host.charAt(0).toUpperCase()) + '</span>') +
      '<div><div style="font-weight:600;font-size:14px">' + esc(host) + '</div>' +
      '<div style="font-size:12px;color:' + (isSecure ? '#22c55e' : '#ef4444') + '">' +
      (isSecure ? '🔒 Connection is secure' : '⚠️ Connection is not secure') + '</div></div></div>' +
      '<div style="display:flex;gap:6px;margin-top:4px">' +
      '<button class="le__clear" data-open-permissions style="flex:1">Site permissions</button>' +
      '<button class="le__clear" data-open-site-settings style="flex:1">Advanced settings</button></div>' +
      '<div class="panel-section" style="margin-top:12px">Cookies & Data</div>' +
      '<p style="font-size:12px;color:var(--text-muted)">' + (state.siteCookies || 0) + ' cookies in use</p>' +
      '<button class="le__clear" data-clear-site-data>Clear site data</button>';
  }

  function bookmarksHTML() {
    var header = '<div class="setting"><div><div class="setting__label">Open bookmarks bar</div>' +
      '<div class="setting__hint">Show a bookmark row under the toolbar</div></div>' +
      '<span class="toggle" data-toggle="bookmarksBar" data-on="' + (prefs.bookmarksBar ? 'true' : 'false') + '"></span></div>';
    return header + listHTML(state.bookmarks, 'le', bookmarkRow,
      '<div class="empty-state">' +
      '<div class="empty-state__icon">' + svg(ICONS.bookmark, 26) + '</div>' +
      '<p class="empty-state__title">No bookmarks yet</p>' +
      '<p class="empty-state__hint">Press ⌘D on any page to save it here.</p></div>');
  }

  var ACCENT_PRESETS = ['#F97316', '#F59E0B', '#22C55E', '#10B981', '#06B6D4', '#3B82F6', '#6366F1', '#8B5CF6', '#EC4899', '#EF4444'];
  function accentSwatches() {
    var cur = state.accentHex || '#F97316';
    var html = '<div class="accent-row" role="radiogroup" aria-label="Accent color">';
    ACCENT_PRESETS.forEach(function (hex) {
      html += '<button type="button" class="accent-swatch' + (hex === cur ? ' accent-swatch--active' : '') +
        '" data-accent="' + hex + '" style="background:' + hex + '" role="radio" aria-checked="' + (hex === cur ? 'true' : 'false') +
        '" aria-label="Accent ' + hex + '"></button>';
    });
    return html + '</div>';
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
    var engines = ['DuckDuckGo', 'Google', 'Bing', 'Brave Search', 'Startpage', 'Ecosia'];
    return '<div class="panel-section"><h3>Search Engine</h3>' +
      '<div class="setting"><div><div class="setting__label">Default search engine</div>' +
      '<div class="setting__hint">Used for address-bar and start-page searches</div></div></div>' +
      seg('engine', engines.map(function (e) { return { v: e, label: e }; }), state.searchEngine) +
      '</div>' +
      '<div class="panel-section"><h3>Layout</h3>' +
      '<div class="setting"><div><div class="setting__label">Tab layout</div>' +
      '<div class="setting__hint">Vertical sidebar (Arc/Zen) or horizontal strip (Chrome/Brave)</div></div>' +
      seg('layout', [{ v: 'vertical', label: 'Vertical' }, { v: 'horizontal', label: 'Horizontal' }], state.layout) + '</div>' +
      '<div class="setting"><div><div class="setting__label">Density</div></div>' +
      seg('density', [{ v: 'comfortable', label: 'Comfortable' }, { v: 'compact', label: 'Compact' }], prefs.density) + '</div>' +
      toggle('bookmarksBar', prefs.bookmarksBar, 'Show bookmarks bar') +
    '</div>' +
      '<div class="panel-section"><h3>Appearance</h3>' +
      '<div class="setting"><div><div class="setting__label">Theme</div></div>' +
      seg('theme', [{ v: 'system', label: 'System' }, { v: 'light', label: 'Light' }, { v: 'dark', label: 'Dark' }], prefs.theme) + '</div>' +
      '<div class="setting"><div><div class="setting__label">Accent color</div>' +
      '<div class="setting__hint">Recolors tabs, focus rings, and highlights across Hive</div></div></div>' +
      accentSwatches() +
      toggle('animations', prefs.animations, 'Animations', 'Transitions, glows, and spring motion') +
      '</div>' +
      '<div class="panel-section"><h3>Privacy</h3>' +
      toggle('httpsOnly', state.httpsOnlyEnabled, 'Always use secure connections',
        'Upgrade http to https where possible; plaintext pages show a warning banner') +
      toggle('adBlock', state.adBlockEnabled, 'Block ads & trackers',
        'Blocks known ad/tracker domains and hides ad elements after load (EasyList-based)') +
      '</div>' +
      '<div class="panel-section"><h3>Performance</h3>' +
      toggle('memorySaver', state.memorySaverEnabled, 'Memory Saver',
        'Frees memory from inactive tabs; inactive tabs reload when you switch back') +
      '</div>' +
      '<div class="panel-section"><h3>About</h3>' +
      '<div class="setting"><div><div class="setting__label">Hive Browser</div>' +
      '<div class="setting__hint">Chromium 148 · CEF · web chrome shell</div></div></div></div>';
  }

  function wirePanelEvents(body, name) {
    var hSearch = body.querySelector('#historySearch');
    if (hSearch) {
      hSearch.addEventListener('input', function () {
        historyQuery = hSearch.value;
        historySearchResults = null;
        renderPanel();
        var re = body.querySelector('#historySearch');
        if (re) re.focus();
        var q = historyQuery.trim();
        if (q) {
          var token = ++historySearchToken;
          api('hive.searchHistory', { query: q }).then(function (res) {
            if (token !== historySearchToken) return; // stale — a newer query is in flight
            historySearchResults = res || [];
            if (state.isChromePanelOpen === 'history') {
              renderPanel();
              var r2 = body.querySelector('#historySearch');
              if (r2) r2.focus();
            }
          });
        }
      });
      var hClear = body.querySelector('#historySearchClear');
      if (hClear) hClear.addEventListener('click', function () {
        historyQuery = '';
        historySearchResults = null;
        renderPanel();
        var re = body.querySelector('#historySearch');
        if (re) re.focus();
      });
    }
    body.querySelectorAll('[data-seg]').forEach(function (item) {
      item.addEventListener('click', function () {
        var key = item.dataset.seg;
        var val = item.dataset.val;
        if (key === 'layout') api('hive.setLayout', { mode: val });
        else if (key === 'engine') api('hive.setSearchEngine', { text: val });
        else if (key === 'theme') { prefs.theme = val; savePrefs(); applyTheme(); }
        else if (key === 'density') { prefs.density = val; savePrefs(); applyDensity(); }
        renderPanel();
      });
    });
    body.querySelectorAll('[data-accent]').forEach(function (sw) {
      sw.addEventListener('click', function () {
        var hex = sw.dataset.accent;
        api('hive.setAccent', { hex: hex });
        state.accentHex = hex;
        document.documentElement.style.setProperty('--accent', hex);
        body.querySelectorAll('.accent-swatch').forEach(function (s) {
          var on = s.dataset.accent === hex;
          s.classList.toggle('accent-swatch--active', on);
          s.setAttribute('aria-checked', on ? 'true' : 'false');
        });
      });
    });
    body.querySelectorAll('[data-toggle]').forEach(function (t) {
      t.addEventListener('click', function () {
        var key = t.dataset.toggle;
        var on = t.dataset.on !== 'true';
        if (key === 'bookmarksBar') { prefs.bookmarksBar = on; savePrefs(); renderBookmarksBar(); }
        else if (key === 'animations') { prefs.animations = on; savePrefs(); applyTheme(); }
        else if (key === 'httpsOnly') api('hive.setHTTPSOnly', { value: on }).then(function () { refresh(); });
        else if (key === 'adBlock' || key === 'memorySaver')
          api('hive.setBrowserPref', { key: key === 'adBlock' ? 'adBlock' : 'memorySaver', value: on }).then(function () { refresh(); });
        t.dataset.on = on ? 'true' : 'false';
      });
    });
    var sSearch = body.querySelector('#sessionSearch');
    if (sSearch) {
      sSearch.addEventListener('input', function () {
        var f = sSearch.value.trim().toLowerCase();
        body.querySelectorAll('#sessionsList .le').forEach(function (row) {
          row.hidden = !!(f && (row.dataset.sessionTitle || '').indexOf(f) === -1);
        });
      });
    }
    body.querySelectorAll('#sessionsList .le').forEach(function (row) {
      // Clicking a session row restores it (buttons handle their own actions).
      row.addEventListener('click', function (e) {
        if (e.target.closest('button')) return;
        api('hive.restoreSession', { id: row.dataset.sessionId });
      });
      var restoreBtn = row.querySelector('.le__restore');
      if (restoreBtn) restoreBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        api('hive.restoreSession', { id: row.dataset.sessionId });
      });
      var delBtn = row.querySelector('.le__del');
      if (delBtn) delBtn.addEventListener('click', function (e) {
        e.stopPropagation();
        api('hive.deleteSession', { id: row.dataset.sessionId }).then(function () {
          state.sessions = (state.sessions || []).filter(function (s) { return s.id !== row.dataset.sessionId; });
          renderPanel();
        });
      });
    });
    function panelRowOpen(row, e) {
      if (row.dataset.dlId !== undefined) {
        if (row.dataset.dlState === 'completed') api('hive.openDownload', { id: row.dataset.dlId });
        return;
      }
      // Chrome/Safari convention: middle-click or ⌘/⌃-click opens a
      // history/bookmark row in a new background tab, keeping the panel open.
      if (e && (e.metaKey || e.ctrlKey || e.button === 1)) {
        api('hive.newTabWithURL', { url: row.dataset.url, activate: false });
        return;
      }
      navigate(row.dataset.url);
      if (name === 'history') closePanel();
    }
    body.querySelectorAll('.le[data-url]').forEach(function (row) {
      row.addEventListener('click', function (e) { panelRowOpen(row, e); });
      // Arrow-key row navigation + Enter/Space to open (Chrome panel parity).
      row.setAttribute('tabindex', '0');
      row.addEventListener('keydown', function (e) {
        // Never steal activation from the row's own controls (bookmark ×,
        // download pause/cancel/reveal) — their buttons handle their keys.
        if (e.target !== row && (e.target.closest('button, input, [data-toggle]'))) return;
        if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
          e.preventDefault();
          var rows = Array.prototype.slice.call(body.querySelectorAll('.le[data-url]'));
          var i = rows.indexOf(row);
          var n = e.key === 'ArrowDown' ? rows[i + 1] || rows[0] : rows[i - 1] || rows[rows.length - 1];
          if (n) n.focus();
        } else if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          panelRowOpen(row, e);
        }
      });
      row.addEventListener('auxclick', function (e) {
        if (e.button !== 1) return;
        e.preventDefault();
        panelRowOpen(row, e);
      });
    });
    // History row hover ✕ (Chrome parity): deletes the entry without
    // opening the context menu. stopPropagation keeps the row's click
    // navigation (panelRowOpen) from firing.
    function deleteHistoryRow(hid) {
      if (!hid) return;
      api('hive.deleteHistoryItem', { id: hid }).then(function () { refresh(); });
    }
    body.querySelectorAll('.le[data-history-id] .le__del').forEach(function (btn) {
      btn.addEventListener('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        var row = btn.closest('.le');
        if (row) deleteHistoryRow(row.dataset.historyId);
      });
    });
    // History row context menu (Chrome parity, mirroring the native panel):
    // Open in New Tab / Copy URL / Delete Entry.
    body.querySelectorAll('.le[data-history-id]').forEach(function (row) {
      row.addEventListener('contextmenu', function (e) {
        e.preventDefault();
        var url = row.dataset.url;
        var hid = row.dataset.historyId;
        ctx.innerHTML = '';
        if (url.indexOf('http://') === 0 || url.indexOf('https://') === 0) {
          var open = el('button', 'ctxmenu__item');
          open.textContent = 'Open in New Tab';
          open.addEventListener('click', function () {
            ctx.hidden = true;
            api('hive.newTabWithURL', { url: url, activate: false }).then(function () { refresh(); });
          });
          ctx.appendChild(open);
          var copy = el('button', 'ctxmenu__item');
          copy.textContent = 'Copy URL';
          copy.addEventListener('click', function () {
            ctx.hidden = true;
            api('hive.copyLink', { url: url });
          });
          ctx.appendChild(copy);
        }
        if (hid) {
          ctx.appendChild(el('div', 'ctxmenu__sep'));
          var del = el('button', 'ctxmenu__item ctxmenu__item--danger');
          del.textContent = 'Delete Entry';
          del.addEventListener('click', function () {
            ctx.hidden = true;
            deleteHistoryRow(hid);
          });
          ctx.appendChild(del);
        }
        ctx.hidden = false;
        var w = ctx.offsetWidth, h = ctx.offsetHeight;
        ctx.style.left = Math.min(e.clientX, window.innerWidth - w - 8) + 'px';
        ctx.style.top = Math.min(e.clientY, window.innerHeight - h - 8) + 'px';
      });
    });
    // Downloads row context menu (Chrome parity): Open / Show in Finder /
    // Copy Link / Remove from list. Terminal rows only for Open/Reveal/
    // Remove; Copy Link works for any row with a source URL.
    body.querySelectorAll('.le[data-dl-id]').forEach(function (row) {
      row.addEventListener('contextmenu', function (e) {
        e.preventDefault();
        var id = row.dataset.dlId;
        var url = row.dataset.url;
        var st = row.dataset.dlState;
        // Native DTO state names: completed | cancelled | failed | paused |
        // inProgress | pending (cancelled double-l and failed match the
        // Swift projection exactly).
        var terminal = st === 'completed' || st === 'cancelled' || st === 'failed';
        ctx.innerHTML = '';
        if (terminal && st === 'completed') {
          var open = el('button', 'ctxmenu__item');
          open.textContent = 'Open';
          open.addEventListener('click', function () {
            ctx.hidden = true;
            api('hive.openDownloadFile', { id: id });
          });
          ctx.appendChild(open);
          var reveal = el('button', 'ctxmenu__item');
          reveal.textContent = 'Show in Finder';
          reveal.addEventListener('click', function () {
            ctx.hidden = true;
            api('hive.revealDownload', { id: id });
          });
          ctx.appendChild(reveal);
        }
        if (url && (url.indexOf('http://') === 0 || url.indexOf('https://') === 0)) {
          var copy = el('button', 'ctxmenu__item');
          copy.textContent = 'Copy Link';
          copy.addEventListener('click', function () {
            ctx.hidden = true;
            api('hive.copyLink', { url: url });
          });
          ctx.appendChild(copy);
        }
        if (terminal) {
          ctx.appendChild(el('div', 'ctxmenu__sep'));
          var del = el('button', 'ctxmenu__item ctxmenu__item--danger');
          del.textContent = 'Remove from List';
          del.addEventListener('click', function () {
            ctx.hidden = true;
            api('hive.removeDownload', { id: id }).then(function () { refresh(); });
          });
          ctx.appendChild(del);
        }
        ctx.hidden = false;
        var w = ctx.offsetWidth, h = ctx.offsetHeight;
        ctx.style.left = Math.min(e.clientX, window.innerWidth - w - 8) + 'px';
        ctx.style.top = Math.min(e.clientY, window.innerHeight - h - 8) + 'px';
      });
    });
    body.querySelectorAll('[data-dl-act]').forEach(function (btn) {
      btn.addEventListener('click', function (e) {
        e.stopPropagation();
        var id = btn.dataset.dlId;
        if (btn.dataset.dlAct === 'pause') api('hive.pauseDownload', { id: id });
        else if (btn.dataset.dlAct === 'resume') api('hive.resumeDownload', { id: id });
        else if (btn.dataset.dlAct === 'cancel') api('hive.cancelDownload', { id: id });
        else if (btn.dataset.dlAct === 'reveal') api('hive.revealDownload', { id: id });
        else if (btn.dataset.dlAct === 'open-file') api('hive.openDownloadFile', { id: id });
        setTimeout(refresh, 400);
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
    // Bookmark row context menu (Chrome parity): Open in New Tab / Copy URL.
    body.querySelectorAll('.le[data-bm-id]').forEach(function (row) {
      row.addEventListener('contextmenu', function (e) {
        e.preventDefault();
        var url = row.dataset.url;
        ctx.innerHTML = '';
        if (url.indexOf('http://') === 0 || url.indexOf('https://') === 0) {
          var open = el('button', 'ctxmenu__item');
          open.textContent = 'Open in New Tab';
          open.addEventListener('click', function () {
            ctx.hidden = true;
            api('hive.newTabWithURL', { url: url, activate: false });
          });
          ctx.appendChild(open);
          var copy = el('button', 'ctxmenu__item');
          copy.textContent = 'Copy URL';
          copy.addEventListener('click', function () {
            ctx.hidden = true;
            api('hive.copyLink', { url: url });
          });
          ctx.appendChild(copy);
        }
        ctx.hidden = false;
        var w = ctx.offsetWidth, h = ctx.offsetHeight;
        ctx.style.left = Math.min(e.clientX, window.innerWidth - w - 8) + 'px';
        ctx.style.top = Math.min(e.clientY, window.innerHeight - h - 8) + 'px';
      });
    });
    var clearBtn = body.querySelector('[data-clear-history]');
    if (clearBtn) clearBtn.addEventListener('click', function () {
      // Chrome convention: destructive wipe requires explicit confirmation.
      // In-page modal — window.confirm is a no-op in this CEF embed (the
      // browser client does not implement OnJSDialog).
      confirmAction('Clear all browsing history? This cannot be undone.', function (ok) {
        if (!ok) return;
        api('hive.clearHistory').then(function (res) {
          if (res !== null) refresh();
        });
      }, 'Clear');
    });
    var clearDlBtn = body.querySelector('[data-clear-downloads]');
    if (clearDlBtn) clearDlBtn.addEventListener('click', function () {
      api('hive.clearFinishedDownloads').then(function (res) {
        if (res !== null) refresh();
      });
    });
    // Reading list: remove individual items + clear all
    body.querySelectorAll('[data-remove-reading]').forEach(function (btn) {
      btn.addEventListener('click', function (e) {
        e.preventDefault();
        e.stopPropagation();
        api('hive.removeFromReadingList', { id: btn.dataset.removeReading }).then(function (res) {
          if (res !== null) refresh();
        });
      });
    });
    var clearReadingBtn = body.querySelector('[data-clear-reading]');
    if (clearReadingBtn) clearReadingBtn.addEventListener('click', function () {
      confirmAction('Clear your entire reading list? This cannot be undone.', function (ok) {
        if (!ok) return;
        api('hive.clearReadingList').then(function (res) {
          if (res !== null) refresh();
        });
      }, 'Clear');
    });
    // Permissions panel: toggle any permission on/off immediately.
    body.querySelectorAll('[data-perm]').forEach(function (t) {
      t.addEventListener('click', function () {
        var key = t.dataset.perm;
        var on = t.dataset.on !== 'true';
        api('hive.setSitePermission', { permission: key, value: on ? 'allow' : 'block' }).then(function () { refresh(); });
        t.dataset.on = on ? 'true' : 'false';
      });
    });
    // Clear site data for the current host (permissions panel + site info panel).
    var clearSiteBtn = body.querySelector('[data-clear-site-data]');
    if (clearSiteBtn) clearSiteBtn.addEventListener('click', function () {
      var active = state.tabs.find(function (t) { return t.id === state.activeTabID; });
      var host = active ? (active.host || 'this site') : 'this site';
      confirmAction('Clear all cookies, storage, and cached data for ' + host + '? This will sign you out.', function (ok) {
        if (!ok) return;
        api('hive.clearSiteData').then(function () { refresh(); showToast('Cleared data for ' + host, 'success'); });
      }, 'Clear Data');
    });
    // Site info: link to open permissions panel.
    var openPermsBtn = body.querySelector('[data-open-permissions]');
    if (openPermsBtn) openPermsBtn.addEventListener('click', function () {
      openPanel('permissions');
    });
    // Site info: native site settings hub (cookies, JS, autoplay, notifications).
    var siteSettingsBtn = body.querySelector('[data-open-site-settings]');
    if (siteSettingsBtn) siteSettingsBtn.addEventListener('click', function () {
      api('hive.openSiteSettings');
    });
    // Sessions: capture the current window as a snapshot, then reload the list.
    var saveSessionBtn = body.querySelector('[data-save-session]');
    if (saveSessionBtn) saveSessionBtn.addEventListener('click', function () {
      api('hive.snapshotSession').then(function () {
        api('hive.listSessions').then(function (res) {
          state.sessions = res || [];
          if (state.isChromePanelOpen === 'sessions') renderPanel();
        });
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
    // Overflow handling (Chrome bookmarks-bar convention): the first 12
    // bookmarks render as chips; the rest spill into a "»" menu so nothing
    // is silently unreachable. The cap keeps the bar from eating toolbar
    // width — the overflow menu is one click away.
    var visibleCount = Math.min(state.bookmarks.length, 12);
    state.bookmarks.slice(0, visibleCount).forEach(function (bm) {
      var chip = el('span', 'bmchip', null);
      chip.textContent = bm.title;
      chip.title = bm.url;
      chip.dataset.url = bm.url || '';
      // ⌘/⌃/middle-click opens the bookmark in a background tab (Chrome
      // bookmarks-bar convention), plain click navigates the active tab.
      chip.addEventListener('click', function (e) { openURL(bm.url, e); });
      chip.addEventListener('auxclick', function (e) { if (e.button === 1) { e.preventDefault(); api('hive.newTabWithURL', { url: bm.url, activate: false }); } });
      list.appendChild(chip);
    });
    var overflow = state.bookmarks.slice(visibleCount);
    if (overflow.length) {
      var more = el('button', 'bmchip bmchip--more', null);
      more.textContent = '»';
      more.title = 'More bookmarks (' + overflow.length + ')';
      more.setAttribute('aria-label', 'More bookmarks');
      more.setAttribute('aria-haspopup', 'menu');
      more.addEventListener('click', function (e) {
        e.stopPropagation();
        // Deliberately no event passed to openURL: the » button's click
        // event is captured here, and its modifiers must not leak into the
        // menu items' navigation (a ⌘-click on » must not make every item
        // open in the background). Menu items always navigate the active tab.
        var items = overflow.map(function (bm) {
          return {
            label: bm.title,
            url: bm.url,
            action: function () { openURL(bm.url); }
          };
        });
        ctx.innerHTML = '';
        items.forEach(function (item) {
          var b = el('button', 'ctxmenu__item');
          b.textContent = item.label;
          b.title = item.url || '';
          b.addEventListener('click', function () { ctx.hidden = true; item.action(); });
          ctx.appendChild(b);
        });
        ctx.hidden = false;
        var rect = more.getBoundingClientRect();
        var w = ctx.offsetWidth, h = ctx.offsetHeight;
        ctx.style.left = Math.min(rect.left, window.innerWidth - w - 8) + 'px';
        ctx.style.top = Math.min(rect.bottom + 4, window.innerHeight - h - 8) + 'px';
      });
      list.appendChild(more);
    }
  }

  /* ---------- context menu ---------- */

  var ctx = $('ctxMenu');
  // Shared context-menu positioning (clamped to the viewport, Chrome parity).
  function showCtxAt(x, y) {
    ctx.hidden = false;
    var w = ctx.offsetWidth, h = ctx.offsetHeight;
    ctx.style.left = Math.min(x, window.innerWidth - w - 8) + 'px';
    ctx.style.top = Math.min(y, window.innerHeight - h - 8) + 'px';
  }
  function copyTextToClipboard(text) {
    navigator.clipboard.writeText(text || '').then(function () {
      showToast('Copied to clipboard', 'success');
    }).catch(function () {});
  }
  function showCtxMenu(x, y, id) {
    var t = state.tabs.find(function (x) { return x.id === id; });
    if (!t) return;
    var tabURL = t.url || '';
    var items = [
      { label: 'New Tab', action: function () { api('hive.newTab'); } },
      { label: 'New Tab to Right', action: function () { api('hive.newTabBackground'); } }
    ];
    items.push({ sep: true });
    items.push({ label: 'Reload', action: function () { api('hive.reload'); } });
    items.push({ label: t.isMuted ? 'Unmute tab' : 'Mute tab', action: function () { api('hive.toggleTabMute', { id: id }); } });
    items.push({ label: t.isPinned ? 'Unpin tab' : 'Pin tab', action: function () { api('hive.pinTab', { id: id }); } });
    items.push({ label: t.isEssential ? 'Unmark as essential' : 'Mark as essential', action: function () { api('hive.toggleEssential', { id: id }); } });
    items.push({ label: 'Duplicate tab', action: function () { api('hive.duplicateTab', { id: id }); } });
    // Move to workspace submenu
    if (state.workspaces && state.workspaces.length > 1) {
      var curID = currentWorkspaceID();
      var currentWS = state.workspaces.find(function (w) { return w.id === curID; });
      state.workspaces.forEach(function (ws) {
        if (ws.id !== (currentWS ? currentWS.id : curID)) {
          items.push({ label: 'Move to » ' + esc(ws.name || 'Workspace'), action: function () { api('hive.moveTabToWorkspace', { tabID: id, workspaceID: ws.id }); } });
        }
      });
    }
    // Add to tab group (Chrome parity): move into an existing group, remove
    // from the current one, or create a new colored group from this tab.
    var tabGroups_ = state.tabGroups || [];
    if (t.groupID) {
      items.push({ label: 'Remove from group', action: function () {
        api('hive.moveTabToGroup', { tabID: id, groupID: '' }).then(function () { refresh(); });
      } });
    }
    tabGroups_.forEach(function (grp) {
      if (grp.id === t.groupID) return;
      items.push({ label: 'Add to group » ' + grp.name, action: function () {
        api('hive.moveTabToGroup', { tabID: id, groupID: grp.id }).then(function () { refresh(); });
      } });
    });
    items.push({ label: 'New group from this tab', action: function () {
      var base = (t.title || t.host || 'Group').slice(0, 28);
      var name = base, n = 2;
      while (tabGroups_.some(function (g) { return g.name === name; })) name = base + ' ' + n++;
      api('hive.createTabGroup', { name: name, colorHex: GROUP_COLORS[tabGroups_.length % GROUP_COLORS.length] }).then(function () {
        // createTabGroup drops the new id; wait for the state broadcast to surface it.
        var tries = 0;
        (function poll() {
          var g = (state.tabGroups || []).find(function (x) { return x.name === name; });
          if (g) api('hive.moveTabToGroup', { tabID: id, groupID: g.id }).then(function () { refresh(); });
          else if (++tries < 40) setTimeout(poll, 50);
        })();
      });
    } });
    // Add to reading list for http(s) pages
    if (tabURL.indexOf('http://') === 0 || tabURL.indexOf('https://') === 0) {
      items.push({ sep: true });
      items.push({ label: 'Copy Link', action: function () { api('hive.copyLink', { url: tabURL }); } });
      items.push({ label: 'Add to Reading List', action: function () { api('hive.addToReadingList', { url: tabURL }); } });
    }
    items.push({ sep: true });
    items.push({ label: 'View Page Source', action: function () { api('hive.viewSource', { id: id }); } });
    items.push({ label: 'Save Page As…', action: function () { api('hive.savePage', { id: id }); } });
    items.push({ label: 'Inspect Element', action: function () { api('hive.openDevTools', { id: id }); } });
    items.push({ sep: true });
    items.push({ label: 'Close other tabs', action: function () { api('hive.closeOtherTabs', { id: id }); } });
    if (!t.isPinned && !t.isEssential) {
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
    showCtxAt(x, y);
  }

  // Click-away or window blur dismisses the context menu (native-menu
  // convention); Escape closes it too (global keydown). The suggestion
  // dropdown follows the same convention: an outside mousedown or window blur
  // closes it, while clicking the address field itself keeps it open.
  document.addEventListener('mousedown', function (e) {
    if (!ctx.hidden && !ctx.contains(e.target)) ctx.hidden = true;
    if (!suggestBox.hidden && !suggestBox.contains(e.target) && !addrInput.contains(e.target)) hideSuggest();
  }, true);
  document.addEventListener('blur', function () {
    if (ctx && !ctx.hidden) ctx.hidden = true;
    if (!suggestBox.hidden) hideSuggest();
  }, true);
  document.addEventListener('click', function (e) {
    if (ctx.hidden) return;
    if (!ctx.contains(e.target)) ctx.hidden = true;
  });

  // Start-page top-site shortcut menu (Chrome NTP parity): open the tile in a
  // new background tab, or remove the host from the grid (persisted natively).
  function showTopSiteMenu(x, y, site) {
    var items = [
      { label: 'Open in new tab', action: function () { api('hive.newTabWithURL', { url: site.url, activate: false }); } },
      { label: 'Remove from top sites', action: function () {
        api('hive.hideTopSite', { text: site.host }).then(function () { refresh(); });
      } }
    ];
    ctx.innerHTML = '';
    items.forEach(function (item) {
      var b = el('button', 'ctxmenu__item');
      b.textContent = item.label;
      b.addEventListener('click', function () { ctx.hidden = true; item.action(); });
      ctx.appendChild(b);
    });
    showCtxAt(x, y);
  }

  /* ---------- command palette ---------- */

  function openPalette() {
    rememberFocus();
    $('paletteBackdrop').hidden = false;
    var input = $('paletteInput');
    input.value = '';
    input.focus();
    renderPalette('');
  }
  function closePalette() { $('paletteBackdrop').hidden = true; restoreFocus(); }

  function paletteActions(q) {
    var actions = [
      { icon: ICONS.globe, label: 'Morning Brief', run: function () {
        if (IS_CHROME) api('hive.openBrief');
        else window.location.href = 'hive://brief/';
      } },
      { icon: ICONS.search, label: 'Open Agent Workspace', run: function () {
        if (IS_CHROME) api('hive.openPolar');
        else window.location.href = 'hive://polar/';
      } },
      { icon: ICONS.globe, label: 'New Tab', run: function () { api('hive.newTab'); } },
      { icon: ICONS.panel, label: state.layout === 'vertical' ? 'Switch to Horizontal tabs' : 'Switch to Vertical tabs',
        run: function () { api('hive.setLayout', { mode: state.layout === 'vertical' ? 'horizontal' : 'vertical' }); showToast('Layout switched to ' + (state.layout === 'vertical' ? 'horizontal' : 'vertical') + ' tabs', 'success'); } },
      { icon: ICONS.settings, label: 'Settings', run: function () { openPanel('settings'); } },
      { icon: ICONS.history, label: 'History', run: function () { openPanel('history'); } },
      { icon: ICONS.clock, label: 'Sessions', run: function () { openPanel('sessions'); } },
      { icon: ICONS.panel, label: 'New Workspace', run: function () {
        var ws = state.workspaces || state.spaces || [];
        api('hive.createWorkspace', {
          name: 'Workspace ' + (ws.length + 1),
          colorHex: ACCENT_PRESETS[ws.length % ACCENT_PRESETS.length],
          iconName: 'circle.fill'
        }).then(function () { refresh(); });
      } },
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
        state.lastQuery = q;
        api('hive.agent.run', { text: q }).then(function () { refresh(); });
      } },
      { icon: ICONS.search, label: 'Deep Research', run: function () {
        var active = state.tabs.find(function (t) { return t.id === state.activeTabID; });
        var q = active ? 'Research: ' + (active.title || active.host || 'this page') : 'Research: ';
        state.lastQuery = q;
        $('agentAsk').value = q;
        agentDockOpen();
        var input = $('agentAsk');
        input.setSelectionRange(q.length, q.length);
      } },

      { icon: ICONS.focus, label: 'Focus Mode: hide chrome', run: toggleCompactMode },
      { icon: ICONS.bookmark, label: (prefs.bookmarksBar ? 'Hide' : 'Show') + ' bookmarks bar',
        run: function () { prefs.bookmarksBar = !prefs.bookmarksBar; savePrefs(); renderBookmarksBar(); } },
      { sep: true, label: 'Page Actions' },
      { icon: ICONS.reload, label: 'Reload (⌘R)', run: function () { api('hive.reload'); } },
      { icon: ICONS.reload, label: 'Reload Ignoring Cache (⌥⌘R)', run: function () { api('hive.reloadIgnoringCache'); } },
      { icon: ICONS.stop, label: 'Stop Loading (⌘.)', run: function () { api('hive.stop'); } },
      { icon: ICONS.search, label: 'Reader Mode', run: function () { api('hive.toggleReaderMode'); } },
      { icon: ICONS.private, label: 'Fullscreen (⌃⌘F)', run: function () { api('hive.toggleFullscreen'); } },
      { icon: ICONS.print, label: 'Print… (⌘P)', run: function () { api('hive.printPage'); } },
      { icon: ICONS.globe, label: 'View Page Source', run: function () { api('hive.viewSource'); } },
      { icon: ICONS.download, label: 'Save Page As…', run: function () { api('hive.savePage'); } },
      { icon: ICONS.zoom, label: 'Zoom In (⌘+)', run: function () { api('hive.zoomIn'); } },
      { icon: ICONS.zoomOut, label: 'Zoom Out (⌘-)', run: function () { api('hive.zoomOut'); } },
      { icon: ICONS.refresh, label: 'Reset Zoom (⌘0)', run: function () { api('hive.resetZoom'); } }
    ];
    var matched = actions.filter(function (a) {
      return !q || a.label.toLowerCase().indexOf(q) !== -1;
    });
    // Drop section headers (seps) that have no visible items under them.
    return matched.filter(function (a, i) {
      if (!a.sep) return true;
      return matched.slice(i + 1).some(function (b) { return !b.sep; });
    });
  }

  function renderPalette(q) {
    var list = $('paletteList');
    q = q.toLowerCase();
    list.innerHTML = '';
    var rows = [];
    var itemIndex = 0;
    paletteActions(q).forEach(function (a, i) {
      if (a.sep) {
        var s = el('div', 'palette__sep', null);
        s.textContent = a.label || '';
        list.appendChild(s);
        return;
      }
      var row = el('div', 'palette__item', null);
      row.innerHTML = '<span class="sugg__icon">' + svg(a.icon, 15) + '</span><span>' + esc(a.label) + '</span>';
      row.dataset.index = itemIndex++;
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

  // ? key -> keyboard shortcuts overlay (shadcn/Radix dialog semantics)
  document.addEventListener('keydown', function(e){
    if (e.key === '?' && !e.ctrlKey && !e.metaKey && !e.altKey && document.activeElement && document.activeElement.tagName !== 'INPUT' && document.activeElement.tagName !== 'TEXTAREA') {
      e.preventDefault();
      var overlay = document.getElementById('shortcutsOverlay');
      if (overlay) {
        if (overlay.hidden) { rememberFocus(); overlay.hidden = false; } else { overlay.hidden = true; restoreFocus(); }
      }
    }
  });

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
      // stopPropagation: the document-level Esc chain must not also run
      // (closing the palette with Esc must never fall through to the
      // exit-fullscreen branch or blur other fields).
      e.stopPropagation();
      closePalette();
    }
    Array.prototype.forEach.call(items, function (n, i) {
      n.dataset.active = i === palIndex ? 'true' : 'false';
    });
  });
  $('paletteBackdrop').addEventListener('click', function (e) {
    if (e.target === this) closePalette();
  });
  // Radix-style focus containment: Tab cycles inside the palette dialog.
  $('paletteBackdrop').addEventListener('keydown', function (e) { trapTab($('palette'), e); });

  /* ---------- keyboard shortcuts ---------- */

  document.addEventListener('keydown', function (e) {
    var meta = e.metaKey || e.ctrlKey;
    // Ctrl+Tab / Ctrl+Shift+Tab: cycle tabs (Chrome/Arc convention; ⌘⇥ is
    // reserved by the OS for app switching). Cycling skips pinned/essential
    // tabs, wraps around, and shows a transient toast for visual feedback.
    // ⌘⌥1-9 switches space (Arc/Chrome-profile convention, documented in the
    // shortcuts overlay). 9+ spaces wrap to the last slot; 0 is a no-op.
    if (meta && e.altKey && /^[1-9]$/.test(e.key) && (state.spaces || []).length > 1) {
      e.preventDefault();
      var idx = Math.min(parseInt(e.key, 10) - 1, state.spaces.length - 1);
      var ws = state.spaces[idx];
      if (ws) api('hive.switchWorkspace', { id: ws.id });
      return;
    }
    if (e.ctrlKey && !e.metaKey && !e.altKey && e.key === 'Tab') {
      e.preventDefault();
      var cycle = state.tabs.filter(function (t) { return !t.isPinned && !t.isEssential; });
      if (cycle.length > 1) {
        var cur = cycle.findIndex(function (t) { return t.id === state.activeTabID; });
        var next = e.shiftKey
          ? (cur <= 0 ? cycle.length - 1 : cur - 1)
          : (cur < 0 ? 0 : (cur + 1) % cycle.length);
        api('hive.selectTab', { id: cycle[next].id }).then(function () {
          var t = cycle[next];
          showToast((e.shiftKey ? 'Previous' : 'Next') + ' tab: ' + (t.title || t.host || 'New Tab'), 'info');
        });
      }
      return;
    }
    // ⌘P: print the active page (native print dialog, Safari/Chrome parity).
    if (meta && e.key.toLowerCase() === 'p') { e.preventDefault(); api('hive.printPage'); return; }
    // ⌘.: stop the current load (matches the native Stop menu item).
    if (meta && e.key === '.') { e.preventDefault(); api('hive.stop'); return; }
    // ⌘+/⌘-/⌘0: page zoom (Chrome/Safari parity). Ignored while typing in
    // the address bar (where ⌘+/- may mean something else) — same as Chrome.
    if (meta && (e.key === '=' || e.key === '+' || e.key === '-') &&
        !(document.activeElement && document.activeElement.tagName === 'INPUT')) {
      e.preventDefault();
      api(e.key === '-' ? 'hive.zoomOut' : 'hive.zoomIn').then(function () { refresh(); });
      return;
    }
    if (meta && e.key === '0' &&
        !(document.activeElement && document.activeElement.tagName === 'INPUT')) {
      e.preventDefault();
      api('hive.resetZoom').then(function () { refresh(); });
      return;
    }
    if (e.key === 'Escape') {
      // The final else only runs when NOTHING above consumed the Esc — so
      // closing a panel/palette/overlay with Esc can never also trigger it.
      if (state.isChromePanelOpen) closePanel();
      else if (!$('paletteBackdrop').hidden) closePalette();
      else if (!document.getElementById('shortcutsOverlay').hidden) { document.getElementById('shortcutsOverlay').hidden = true; restoreFocus(); }
      else if (!ctx.hidden) ctx.hidden = true;
      else if (document.body.dataset.compact) setCompactMode(false);
      else if (!suggestBox.hidden) hideSuggest();
      else if (document.activeElement === addrInput) addrInput.blur();
      // Last resort: leave fullscreen (Chrome/Safari convention). The bridge
      // no-ops when the window isn't actually fullscreen.
      else api('hive.exitFullscreen');
      return;
    }
    // ⌘⇧R toggles Reader Mode (Safari convention). Chrome's ⌘⇧R hard-reload
    // is relocated to ⌥⌘R (below) to avoid the clash.
    if (meta && e.shiftKey && e.key.toLowerCase() === 'r') { e.preventDefault(); api('hive.toggleReaderMode').then(function () { refresh(); }); return; }
    // ⌥⌘R hard-reloads, bypassing caches (Chrome's ⌘⇧R relocated here).
    if (meta && e.altKey && !e.shiftKey && e.key.toLowerCase() === 'r') { e.preventDefault(); api('hive.reloadIgnoringCache'); return; }
    // ⌘⇧C copies the active page URL (Chrome convention).
    if (meta && e.shiftKey && e.key.toLowerCase() === 'c') { e.preventDefault(); api('hive.copyPageURL'); return; }
    // ⌘A asks the agent (documented in the dock hero); ⌘⇧A is Tab Search
    // (native SwiftUI overlay, via bridge). They must not collide.
    if (meta && !e.shiftKey && e.key.toLowerCase() === 'a') { e.preventDefault(); agentDockOpen(); return; }
    if (meta && e.shiftKey && e.key.toLowerCase() === 'a') { e.preventDefault(); openTabSearch(); return; }
    // ⌃⌘F toggles fullscreen (Safari/Chrome convention); plain ⌘F is Find.
    if (e.ctrlKey && e.metaKey && e.key.toLowerCase() === 'f') {
      e.preventDefault();
      api('hive.toggleFullscreen');
      return;
    }
    if (meta && e.key.toLowerCase() === 'f') { e.preventDefault(); api('hive.openFindBar'); return; }
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
    // ⌘⇧H — Home (⌥⌘H is macOS's system "Hide Others", so Hive uses the
    // Safari-adjacent ⌘⇧H to avoid the collision).
    if (meta && e.shiftKey && e.key.toLowerCase() === 'h') { e.preventDefault(); api('hive.goHome'); return; }
    if (meta && !e.shiftKey && !e.altKey && e.key.toLowerCase() === 'r') { api('hive.reload'); return; }
    if (meta && e.key.toLowerCase() === 'd') { e.preventDefault(); api('hive.toggleBookmark'); return; }
    if (meta && e.key.toLowerCase() === 'y') { e.preventDefault(); openPanel('history'); return; }
    if (meta && e.key.toLowerCase() === 'j') { e.preventDefault(); openPanel('downloads'); return; }
    // ⌘⇧⌫ — Clear Browsing Data (Chrome parity; Backspace is the Mac delete key).
    if (meta && e.shiftKey && e.key === 'Backspace') { e.preventDefault(); api('hive.openClearData'); return; }
    if (meta && e.shiftKey && e.key.toLowerCase() === 'b') {
      // ⌘⇧B toggles the bookmarks bar (Chrome convention, overlay-documented).
      e.preventDefault();
      prefs.bookmarksBar = !prefs.bookmarksBar;
      savePrefs();
      renderBookmarksBar();
      showToast('Bookmarks bar ' + (prefs.bookmarksBar ? 'shown' : 'hidden'), 'info');
      return;
    }
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

  var startPageFirstRender = true;
  var startEnterUntil = 0;
  function renderStartPage() {
    if (IS_CHROME) return;
    // Session restore banner (Chrome parity): if the last session crashed
    // or was unexpectedly closed, offer to restore tabs.
    var crashed = state.didCrash || (state.crashedTabCount && state.crashedTabCount > 0);
    var restoreSection = $('restoreSection');
    if (crashed && restoreSection) {
      restoreSection.hidden = false;
      var count = state.crashedTabCount || (state.lastSessionTabs ? state.lastSessionTabs.length : 0);
      $('restoreCount').textContent = count;
      $('restoreBtn').onclick = function () {
        api('hive.restoreSession').then(function () { refresh(); });
      };
      $('restoreDismiss').onclick = function () {
        restoreSection.hidden = true;
        api('hive.dismissRestore');
      };
    } else if (restoreSection) {
      restoreSection.hidden = true;
    }
    // Entrance choreography: the first render adds .start--enter, and any
    // broadcast that lands inside the animation window is skipped entirely
    // so the staggered entrance always plays in full — a second startup
    // broadcast (loading-state flips, progress) must not truncate it or
    // re-pop the sections. After the window, renders rebuild statically.
    var now = Date.now();
    if (startPageFirstRender) {
      startPageFirstRender = false;
      startEnterUntil = now + 450;
      stage.classList.add('start--enter');
    } else if (now < startEnterUntil) {
      return;
    } else {
      stage.classList.remove('start--enter');
    }
    $('briefCard').hidden = false;
    var grid = $('topsitesGrid');
    grid.innerHTML = '';
    state.topSites.forEach(function (site) {
      var hue = Math.abs(hash(site.host)) % 360;
      var tile = el('div', 'topsite', null);
      tile.innerHTML = '<span class="topsite__icon" style="background:hsl(' + hue + ',32%,48%)">' + esc(site.host.charAt(0).toUpperCase()) + '</span>' +
        '<span class="topsite__label">' + esc(site.host) + '</span>';
      tile.addEventListener('click', function (e) { openURL(site.url, e); });
      tile.addEventListener('auxclick', function (e) {
        if (e.button === 1) { e.preventDefault(); openURL(site.url, e); }
      });
      // Chrome NTP: right-click a shortcut tile for Open in new tab / Remove,
      // and Enter opens the focused tile (keyboard accessibility).
      tile.setAttribute('data-url', site.url || '');
      tile.setAttribute('role', 'button');
      tile.tabIndex = 0;
      tile.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          openURL(site.url, e);
        }
      });
      tile.addEventListener('contextmenu', function (e) {
        e.preventDefault();
        showTopSiteMenu(e.clientX, e.clientY, site);
      });
      grid.appendChild(tile);
    });
    $('topSitesSection').hidden = !state.topSites.length;
    $('recentSection').hidden = !state.recent.length;
    // Recently Closed section (Chrome NTP parity): shows the last 6 closed
    // tabs with a "Reopen" action and a "Show full history" link.
    var closedSection = $('recentlyClosedSection');
    var closedList = $('recentlyClosedList');
    var closed = state.recentlyClosed || [];
    if (closedSection) {
      closedSection.hidden = !closed.length;
      if (closed.length) {
        closedList.innerHTML = '';
        closed.slice(0, 6).forEach(function (item) {
          var hue = Math.abs(hash(item.host || item.url || '')) % 360;
          var row = el('div', 'le', null);
          row.innerHTML = tileHTML(item.host, item.title, hue) +
            '<span class="le__body"><span class="le__title">' + esc(item.title || item.url) + '</span>' +
            '<span class="le__meta">' + esc(item.url || '') + '</span></span>' +
            '<button class="le__undo" title="Reopen tab" aria-label="Reopen tab">↩</button>';
          row.querySelector('.le__undo').addEventListener('click', function (e) {
            e.stopPropagation();
            api('hive.reopenClosedTab').then(function () { refresh(); });
          });
          row.addEventListener('click', function (e) { openURL(item.url, e); });
          closedList.appendChild(row);
        });
      }
    }
    // "See more" expands the recent list to the full start-data history
    // (Chrome NTP convention); the start page already carries state.history.
    $('recentMore').addEventListener('click', function () {
      if (state.recent.length >= (state.history || []).length) return;
      var recent = $('recentList');
      recent.innerHTML = '';
      (state.history || []).forEach(function (item) {
        var hue = Math.abs(hash(item.host || '')) % 360;
        var row = el('div', 'le', null);
        row.dataset.url = item.url || '';
        row.innerHTML = tileHTML(item.host, item.title, hue) +
          '<span class="le__body"><span class="le__title">' + esc(item.title) + '</span>' +
          '<span class="le__meta">' + esc(item.url) + '</span></span>' +
          '<span class="le__time">' + esc(item.timeLabel || '') + '</span>';
        row.addEventListener('click', function (e) { openURL(item.url, e); });
        row.addEventListener('auxclick', function (e) {
          if (e.button === 1) { e.preventDefault(); openURL(item.url, e); }
        });
        recent.appendChild(row);
      });
      this.hidden = true;
    });

    var recent = $('recentList');
    recent.innerHTML = '';
    state.recent.forEach(function (item) {
      var hue = Math.abs(hash(item.host)) % 360;
      var row = el('div', 'le', null);
      row.innerHTML = tileHTML(item.host, item.title, hue) +
        '<span class="le__body"><span class="le__title">' + esc(item.title) + '</span>' +
        '<span class="le__meta">' + esc(item.url) + '</span></span>' +
        '<span class="le__time">' + esc(item.timeLabel) + '</span>';
      row.addEventListener('click', function (e) { openURL(item.url, e); });
      row.addEventListener('auxclick', function (e) {
        if (e.button === 1) { e.preventDefault(); openURL(item.url, e); }
      });
      recent.appendChild(row);
    });

    var spaces = $('spacesRow');
    spaces.innerHTML = '';
    state.spaces.forEach(function (ws) {
      var s = el('div', 'workspace', null);
      s.dataset.active = ws.tabCount > 0 ? 'true' : 'false';
      s.innerHTML = '<span class="workspace__dot" style="background:' + ws.colorHex + '"></span>' +
        '<span>' + esc(ws.name) + '</span><span class="workspace__count">' + ws.tabCount + '</span>';
      s.addEventListener('click', function () { api('hive.switchWorkspace', { id: ws.id }); });
      s.addEventListener('auxclick', function (e) {
        if (e.button !== 1) return;
        e.preventDefault();
        api('hive.switchWorkspace', { id: ws.id });
      });
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
          row.addEventListener('click', function (e) {
            if (s.tabID && IS_CHROME) api('hive.selectTab', { id: s.tabID });
            else openURL(s.url || s.text, e);
            stageSuggest.hidden = true;
          });
          stageSuggest.appendChild(row);
        });
        stageSuggest.hidden = false;
      });
    }, 120);
  });
  var stageSuggIndex = -1;
  function markStageSugg() {
    Array.prototype.forEach.call(stageSuggest.querySelectorAll('.sugg'), function (n, i) {
      n.dataset.active = i === stageSuggIndex ? 'true' : 'false';
    });
  }
  stageQuery.addEventListener('keydown', function (e) {
    var rows = stageSuggest.querySelectorAll('.sugg');
    if (e.key === 'Escape') {
      stageSuggest.hidden = true;
      stageSuggIndex = -1;
      stageQuery.blur();
      return;
    }
    if (e.key === 'ArrowDown' && rows.length) {
      e.preventDefault();
      stageSuggIndex = (stageSuggIndex + 1) % rows.length;
      markStageSugg();
      return;
    }
    if (e.key === 'ArrowUp' && rows.length) {
      e.preventDefault();
      stageSuggIndex = (stageSuggIndex - 1 + rows.length) % rows.length;
      markStageSugg();
      return;
    }
    if (e.key === 'Enter') {
      e.preventDefault();
      var chosen = stageSuggIndex >= 0 ? rows[stageSuggIndex] : null;
      if (chosen) chosen.click();
      else submitAddress(stageQuery.value);
      stageSuggest.hidden = true;
      stageSuggIndex = -1;
    }
  });
  stageQuery.addEventListener('blur', function () {
    stageSuggIndex = -1;
  });
  document.addEventListener('keydown', function (e) {
    if (IS_CHROME) return;
    if (e.key === 'Escape' && document.activeElement === stageQuery) {
      stageQuery.blur();
    }
  });

  // Chrome NTP convention: start typing anywhere to search. A printable key
  // (with no modifier, not already in an input/textarea) focuses the stage
  // query and inserts the character.
  document.addEventListener('keydown', function (e) {
    if (IS_CHROME) return;
    if (e.metaKey || e.ctrlKey || e.altKey) return;
    // Never route keystrokes behind an open overlay (confirm modal, shortcuts
    // overlay, palette) into the search box.
    if (document.querySelector('.hive-confirm')) return;
    if (!document.getElementById('shortcutsOverlay').hidden) return;
    if (!$('paletteBackdrop').hidden) return;
    var el = document.activeElement;
    if (el && (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA')) return;
    if (e.key.length !== 1 || e.key === ' ') return;
    // '?' opens the shortcuts overlay — never route it into the search box.
    if (e.key === '?') return;
    e.preventDefault();
    stageQuery.focus();
    // Append when the box already has text (Chrome NTP behavior); replace when
    // it is empty.
    stageQuery.value = stageQuery.value ? stageQuery.value + e.key : e.key;
    stageQuery.dispatchEvent(new Event('input'));
  });

  $('stageSearchForm').addEventListener('submit', function (e) { e.preventDefault(); });

  /* ================= boot ================= */


  /* ══ Zen workspace swipe — ctrl+wheel cycles workspaces ══ */
  (function () {
    var swipeTimer = null;
    var SWIPE_COOLDOWN = 300;
    document.addEventListener('wheel', function (e) {
      if (!e.ctrlKey && !e.metaKey) return;
      if (swipeTimer) return;
      e.preventDefault();
      var dir = e.deltaY > 0 ? 1 : -1;
      var spaces = state.spaces || [];
      if (spaces.length < 2) return;
      var cur = state.activeTabID ? (state.tabs.find(function(t){return t.id===state.activeTabID;}) || {}).workspaceID : null;
      var idx = spaces.findIndex(function(s){return s.id===cur;});
      if (idx < 0) idx = 0;
      var nextIdx = (idx + dir + spaces.length) % spaces.length;
      var next = spaces[nextIdx];
      if (!next) return;
      document.body.dataset.workspaceSwitching = 'true';
      setTimeout(function(){ delete document.body.dataset.workspaceSwitching; }, 250);
      api('hive.switchWorkspace', { id: next.id });
      swipeTimer = setTimeout(function(){ swipeTimer = null; }, SWIPE_COOLDOWN);
    }, { passive: false });
  })();

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
        // Chrome/Arc convention: toast when a download completes, once per file
        // (compared against the previous snapshot's completed set).
        if (data && data.downloads && window.__lastCompletedDls) {
          (data.downloads || []).forEach(function (dl) {
            if ((dl.state === 'completed' || dl.state === 'complete') &&
                window.__lastCompletedDls.indexOf(dl.id) === -1) {
              showToast('Download complete: ' + (dl.name || 'file'), 'success');
            }
          });
        }
        window.__lastCompletedDls = (data && data.downloads || [])
          .filter(function (dl) { return dl.state === 'completed' || dl.state === 'complete'; })
          .map(function (dl) { return dl.id; });
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


/* ============================================================
   Comet-style Sidecar panel
   ============================================================ */
function toggleSidecar() {
  var el = $('sidecar');
  if (!el) {
    el = document.createElement('div');
    el.id = 'sidecar';
    el.className = 'sidecar';
    el.innerHTML = '<div class="sidecar-tabs"><button class="sidecar-tab active">Agent</button><button class="sidecar-tab">Context</button><button class="sidecar-tab">History</button></div><div class="sidecar-content"></div>';
    document.body.appendChild(el);
    // Click outside to close
    el.addEventListener('click', function (e) { e.stopPropagation(); });
    document.addEventListener('click', function closeSidecar(e) {
      if (!el.contains(e.target)) {
        el.classList.remove('open');
        document.removeEventListener('click', closeSidecar);
        setTimeout(function () { if (el.parentNode) el.parentNode.removeChild(el); }, 300);
      }
    });
  }
  requestAnimationFrame(function () { el.classList.toggle('open'); });
}

function addChainStep(text, kind) {
  var el = $('sidecar');
  if (!el) return;
  var content = el.querySelector('.sidecar-content');
  if (!content) return;
  var step = document.createElement('div');
  step.className = 'chain-step';
  step.innerHTML = '<span class="chain-step__status ' + (kind || 'think') + '"></span><span>' + text + '</span>';
  content.appendChild(step);
  content.scrollTop = content.scrollHeight;
}

function addReasoningChain(label, steps, kind) {
  var el = $('sidecar');
  if (!el) return;
  var content = el.querySelector('.sidecar-content');
  if (!content) return;
  var chain = document.createElement('details');
  chain.className = 'ai-reasoning-chain';
  chain.open = true;
  var icon = kind === 'done' ? '<svg class="chain-icon" viewBox="0 0 16 16"><circle cx="8" cy="8" r="7" fill="none" stroke="#22c55e" stroke-width="2"/><path d="M5 8l2 2 4-4" stroke="#22c55e" stroke-width="1.5" fill="none"/></svg>' : '<div class="chain-spinner chain-icon"></div>';
  chain.innerHTML = '<summary>' + icon + '<span>' + label + '</span></summary><div class="chain-body">' + steps.map(function (s) { return '<div class="tool-call">' + s + '</div>'; }).join('') + '</div>';
  content.appendChild(chain);
  content.scrollTop = content.scrollHeight;
}



// ============================================================
// Zen Compact Mode Mouse Tracker (from ZenCompactMode.mjs)
// Tracks mouse position relative to window for compact mode
// ============================================================

var HiveCompactMode = {
  _preference: false,
  _outsideWindowOffset: 250,
  _hoverDelay: 0,
  _flashTimeouts: {},

  get preference() {
    return document.documentElement.getAttribute('data-compact-mode') === 'true';
  },

  set preference(value) {
    document.documentElement.setAttribute('data-compact-mode', value);
    this._updateSidebarVisibility();
  },

  // Flash toolbar (briefly show) when a new tab opens
  flashToolbar(duration) {
    duration = duration || 800;
    var el = document.getElementById('toolbar');
    if (!el) return;
    clearTimeout(this._flashTimeouts.toolbar);
    el.setAttribute('data-compact-mode-active', 'true');
    this._flashTimeouts.toolbar = setTimeout(function () {
      el.removeAttribute('data-compact-mode-active');
    }, duration);
  },

  // Track mouse outside window — keep sidebar open if cursor is near
  _onMouseLeave(e) {
    if (!this.preference) return;
    var x = e.clientX, y = e.clientY;
    var w = window.innerWidth, h = window.innerHeight;
    if (x < 0 && Math.abs(x) < this._outsideWindowOffset) return; // near left edge
    if (x > w && (x - w) < this._outsideWindowOffset) return; // near right edge
    if (y < 0 && Math.abs(y) < this._outsideWindowOffset) return; // near top
    if (y > h && (y - h) < this._outsideWindowOffset) return; // near bottom
    this._collapseSidebar();
  },

  _collapseSidebar() {
    document.getElementById('sidebar')?.removeAttribute('data-user-show');
  },

  _updateSidebarVisibility() {
    var sidebar = document.getElementById('sidebar');
    if (!sidebar) return;
    if (this.preference) {
      sidebar.setAttribute('data-compact', 'true');
    } else {
      sidebar.removeAttribute('data-compact');
    }
  },

  toggle() {
    this.preference = !this.preference;
  },

  init() {
    document.addEventListener('mouseleave', this._onMouseLeave.bind(this));
    window.addEventListener('sizemodechange', function () {
      document.getElementById('sidebar')?.removeAttribute('data-user-show');
      document.getElementById('toolbar')?.removeAttribute('data-compact-mode-active');
    });
  }
};

// ============================================================
// Zen Pinned Tab Manager (from ZenPinnedTabManager.mjs)
// Reset pinned tabs to their stored URL on close/click
// ============================================================

var HivePinnedTabManager = {
  _pinnedUrlStore: {},
  _maxEssentials: 12,

  // Store the pinned URL for a tab
  setPinnedUrl(tabId, url) {
    this._pinnedUrlStore[tabId] = url;
  },

  // Reset a pinned tab to its stored URL
  resetPinnedTab(tabId) {
    var storedUrl = this._pinnedUrlStore[tabId];
    if (!storedUrl) return;
    var tab = state.tabs.find(function (t) { return t.id === tabId; });
    if (!tab) return;
    // Navigate via the registered omnibox bridge
    api('omnibox.navigate', { url: storedUrl });
  },

  // On pinned tab click: switch to it; if already active, reset to pinned URL
  onPinnedTabClick(tabId) {
    if (state.activeTabID === tabId) {
      this.resetPinnedTab(tabId);
    } else {
      selectTab(tabId);
    }
  },

  // Count essentials (pinned tabs shown as favicon-only)
  get essentialCount() {
    return state.tabs.filter(function (t) { return t.pinned; }).length;
  },

  get canAddEssential() {
    return this.essentialCount < this._maxEssentials;
  }
};

// ============================================================
// Edge Workspace Sync + Vivaldi Tab Tiling integration
// ============================================================

var HiveWorkspaces = {
  // Switch workspace and apply its layout
  switchTo(spaceId) {
    var idx = state.spaces.findIndex(function (s) { return s.id === spaceId; });
    if (idx < 0) return;
    api('switchToSpace', { spaceIndex: idx });
  },

  // Get workspace accent color
  getAccent(spaceName) {
    var accents = {
      personal: '#6366f1',
      work: '#3b82f6',
      research: '#f59e0b',
      creative: '#ec4899',
      finance: '#10b981'
    };
    return accents[spaceName.toLowerCase()] || accents.personal;
  }
};

// ============================================================
// Vivaldi Tab Tiling — arrange tabs in grid within a single view
// ============================================================

var HiveTabTiling = {
  // Tile currently selected tabs in a grid (uses split view)
  tileSelected(tabIds, layout) {
    layout = layout || 'horizontal';
    api('requestSplitView', { orientation: layout });
  },

  // Exit tiling, restore to individual tabs
  untiled() {
    api('mergeSplitView');
  },

  // Quick tile: tile active tab with the next tab
  quickTile() {
    var idx = state.tabs.findIndex(function (t) { return t.id === state.activeTabID; });
    if (idx < 0 || idx + 1 >= state.tabs.length) return;
    this.tileSelected([state.tabs[idx].id, state.tabs[idx + 1].id], 'horizontal');
  }
};

// ============================================================
// Vivaldi Quick Commands palette (F2-style)
// ============================================================

var HiveQuickCommands = {
  _visible: false,

  toggle() {
    this._visible = !this._visible;
    var el = document.getElementById('quick-commands');
    if (!el) return;
    el.hidden = !this._visible;
    if (this._visible) {
      var input = el.querySelector('input');
      if (input) { input.value = ''; input.focus(); }
    }
  },

  filter(query) {
    query = (query || '').toLowerCase();
    var items = document.querySelectorAll('#quick-commands .qc-item');
    items.forEach(function (item) {
      item.hidden = query && item.textContent.toLowerCase().indexOf(query) === -1;
    });
  }
};

/* ---------- Toasts (shadcn/Sonner-inspired) ---------- */
function toastRegion() {
  var el = document.getElementById('toastRegion');
  if (!el) {
    el = document.createElement('div');
    el.id = 'toastRegion';
    el.className = 'toast-region';
    el.setAttribute('aria-label', 'Notifications');
    document.body.appendChild(el);
  }
  return el;
}
// In-page confirmation modal (window.confirm is a no-op in this CEF embed —
// the browser client does not implement OnJSDialog). Used for destructive
// actions like clearing history. Returns via callback(true/false); Escape and
// backdrop-click cancel.
function confirmAction(message, cb, okLabel) {
  var existing = document.querySelector('.hive-confirm');
  if (existing) existing.remove();
  var wrap = document.createElement('div');
  wrap.className = 'hive-confirm';
  wrap.setAttribute('role', 'alertdialog');
  wrap.setAttribute('aria-modal', 'true');
  wrap.setAttribute('aria-label', 'Confirm');
  wrap.innerHTML = '<div class="hive-confirm__card">' +
    '<div class="hive-confirm__msg">' + esc(message) + '</div>' +
    '<div class="hive-confirm__actions">' +
    '<button class="hive-confirm__btn" data-confirm="cancel">Cancel</button>' +
    '<button class="hive-confirm__btn hive-confirm__btn--danger" data-confirm="ok">' + esc(okLabel || 'Confirm') + '</button>' +
    '</div></div>';
  function done(ok) {
    wrap.remove();
    document.removeEventListener('keydown', onKey, true);
    cb(ok);
  }
  function onKey(e) {
    if (e.key === 'Escape') {
      e.preventDefault();
      e.stopPropagation(); // never let the global Escape handler also fire
      done(false);
    }
  }
  wrap.addEventListener('mousedown', function (e) {
    if (e.target === wrap) done(false);
  });
  wrap.querySelector('[data-confirm="cancel"]').addEventListener('click', function () { done(false); });
  wrap.querySelector('[data-confirm="ok"]').addEventListener('click', function () { done(true); });
  document.addEventListener('keydown', onKey, true);
  document.body.appendChild(wrap);
  wrap.querySelector('[data-confirm="ok"]').focus();
}

function showToast(message, type) {
  var kind = type || 'info';
  var icons = { success: '✓', error: '✕', info: 'i' };
  var region = toastRegion();
  var toast = document.createElement('div');
  toast.className = 'hive-toast hive-toast--' + kind;
  toast.setAttribute('role', kind === 'error' ? 'alert' : 'status');
  toast.innerHTML = '<span class="hive-toast__icon" aria-hidden="true">' + (icons[kind] || 'i') + '</span><span class="hive-toast__msg"></span>';
  toast.querySelector('.hive-toast__msg').textContent = message;
  region.appendChild(toast);
  announce(message);
  setTimeout(function () {
    toast.classList.add('hive-toast--leaving');
    toast.addEventListener('animationend', function () { toast.remove(); }, { once: true });
    setTimeout(function () { if (toast.parentNode) toast.remove(); }, 300);
  }, 3200);
  return toast;
}
function announce(text) {
  // Single polite live region — re-fires on empty-set to re-trigger.
  var sr = document.getElementById('srAnnounce');
  if (!sr) return;
  sr.textContent = '';
  setTimeout(function () { sr.textContent = text; }, 20);
}

/* ---------- Dialog focus management (Radix dialog semantics) ---------- */
var _lastFocus = null;
function rememberFocus() { if (document.activeElement && document.activeElement !== document.body) _lastFocus = document.activeElement; }
function restoreFocus() { if (_lastFocus && _lastFocus.focus) { try { _lastFocus.focus(); } catch (e) {} } _lastFocus = null; }
function trapTab(container, e) {
  if (e.key !== 'Tab') return;
  var focusables = container.querySelectorAll('a[href], button, input, select, textarea, [tabindex]:not([tabindex="-1"])');
  if (!focusables.length) return;
  var first = focusables[0];
  var last = focusables[focusables.length - 1];
  if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
  else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
}

// Init compact mode on load
HiveCompactMode.init();

/* ==========================================================================
   HIVE ANIMATION ORCHESTRATION v2
   JS-driven animations that CSS alone cannot handle:
   - Ripple effect on click
   - IntersectionObserver for scroll-reveal
   - View Transitions API (page crossfade) where supported
   - Panel dismiss choreography
   - Workspace slide orchestration
   - Dynamic stagger delays
   ========================================================================== */

(function () {
  'use strict';

  /* ---------- RIPPLE EFFECT ---------- */

  function createRipple(e, el) {
    if (document.body.classList.contains('no-motion')) return;
    var ripple = document.createElement('span');
    ripple.className = 'ripple-effect';
    var rect = el.getBoundingClientRect();
    var size = Math.max(rect.width, rect.height);
    var x = e.clientX - rect.left - size / 2;
    var y = e.clientY - rect.top - size / 2;
    ripple.style.width = ripple.style.height = size + 'px';
    ripple.style.left = x + 'px';
    ripple.style.top = y + 'px';
    if (!el.classList.contains('ripple-container')) el.classList.add('ripple-container');
    el.appendChild(ripple);
    ripple.addEventListener('animationend', function () { ripple.remove(); });
  }

  // Attach ripples to all interactive surfaces
  document.addEventListener('click', function (e) {
    var target = e.target.closest([
      '.navbtn', '.newtabbtn', '.workspace', '.bmchip', '.topsite',
      '.le', '.seg__item', '.agentdock__send', '.briefcard__cta',
      '.palette__item', '.ctxmenu__item', '.hive-undo__btn',
      '.tab-peek__action'
    ].join(','));
    if (target && !e.defaultPrevented) createRipple(e, target);
  }, { passive: true });

  /* ---------- SCROLL-TRIGGERED REVEAL ---------- */

  if ('IntersectionObserver' in window && !document.body.classList.contains('no-motion')) {
    var revealObserver = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          revealObserver.unobserve(entry.target);
        }
      });
    }, { threshold: 0.1, rootMargin: '0px 0px -20px 0px' });

    // Observe reveal-on-scroll elements as they appear in the DOM
    var revealMutationObserver = new MutationObserver(function () {
      document.querySelectorAll('.reveal-on-scroll:not(.is-visible)').forEach(function (el) {
        revealObserver.observe(el);
      });
    });
    revealMutationObserver.observe(document.body, { childList: true, subtree: true });
    // Initial sweep
    document.querySelectorAll('.reveal-on-scroll:not(.is-visible)').forEach(function (el) {
      revealObserver.observe(el);
    });
  }

  /* ---------- PANEL DISMISS CHOREOGRAPHY ---------- */

  function dismissPanel(panelEl) {
    if (!panelEl) return;
    panelEl.classList.add('panel--closing');
    panelEl.addEventListener('animationend', function handler() {
      panelEl.removeEventListener('animationend', handler);
      panelEl.remove();
    });
  }

  // Expose to the global scope for native bridge calls
  window.HiveAnim = window.HiveAnim || {};
  window.HiveAnim.dismissPanel = dismissPanel;

  /* ---------- PALETTE DISMISS CHOREOGRAPHY ---------- */

  function dismissPalette(backdropEl) {
    if (!backdropEl) return;
    backdropEl.classList.add('palette-backdrop--closing');
    backdropEl.addEventListener('animationend', function handler() {
      backdropEl.removeEventListener('animationend', handler);
      backdropEl.remove();
    });
  }

  window.HiveAnim.dismissPalette = dismissPalette;

  /* ---------- VIEW TRANSITIONS API (page crossfade) ---------- */

  // Use the native View Transitions API when available (Chrome 111+)
  // for smooth crossfade between tab page loads.
  function transitionContent(callback) {
    if (document.body.classList.contains('no-motion')) {
      callback();
      return;
    }
    if (document.startViewTransition) {
      document.startViewTransition(function () {
        callback();
        return Promise.resolve();
      });
    } else {
      // Fallback: crossfade via class toggles on rAF for frame sync
      var content = document.getElementById('webviewContainer') || document.body;
      content.classList.add('crossfade-exit');
      var exitDur = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--dur-fast')) || 140;
      requestAnimationFrame(function () {
        requestAnimationFrame(function () {
          callback();
          content.classList.remove('crossfade-exit');
          content.classList.add('crossfade-enter');
          setTimeout(function () {
            content.classList.remove('crossfade-enter');
          }, exitDur);
        });
      });
    }
  }

  window.HiveAnim.transitionContent = transitionContent;

  /* ---------- DYNAMIC STAGGER FOR LISTS ---------- */

  function staggerChildren(containerSelector, childSelector, baseDelayMs, staggerMs) {
    if (document.body.classList.contains('no-motion')) return;
    var container = typeof containerSelector === 'string'
      ? document.querySelector(containerSelector) : containerSelector;
    if (!container) return;
    var children = container.querySelectorAll(childSelector);
    children.forEach(function (child, i) {
      child.style.animationDelay = (baseDelayMs + i * staggerMs) + 'ms';
    });
  }

  window.HiveAnim.staggerChildren = staggerChildren;

  /* ---------- BOOKMARK STAR POP ---------- */

  function animateBookmarkToggle(btnEl) {
    if (document.body.classList.contains('no-motion')) return;
    btnEl.classList.remove('ic-bookmark');
    void btnEl.offsetWidth; // force reflow
    btnEl.classList.add('ic-bookmark');
  }

  window.HiveAnim.animateBookmarkToggle = animateBookmarkToggle;

  /* ---------- ATTENTION BOUNCE (badge, counter) ---------- */

  function bounceElement(el) {
    if (document.body.classList.contains('no-motion')) return;
    el.style.animation = 'none';
    void el.offsetWidth;
    el.style.animation = 'attention-bounce 400ms var(--spring-bounce)';
    el.addEventListener('animationend', function handler() {
      el.removeEventListener('animationend', handler);
      el.style.animation = '';
    });
  }

  window.HiveAnim.bounceElement = bounceElement;

  /* ---------- TAB INSERTION SLIDE ---------- */

  // When a new tab is inserted at a specific position, animate the
  // surrounding tabs to make room before the DOM update.
  function prepareTabInsertion(insertIndex) {
    if (document.body.classList.contains('no-motion')) return;
    var tabs = document.querySelectorAll('.tab:not(.tab--fresh)');
    var target = tabs[insertIndex];
    if (!target) return;
    target.style.transition = 'transform 200ms var(--spring-smooth)';
    target.style.transform = 'translateY(38px)';
    requestAnimationFrame(function () {
      requestAnimationFrame(function () {
        target.style.transform = 'translateY(0)';
        setTimeout(function () {
          target.style.transition = '';
          target.style.transform = '';
        }, 200);
      });
    });
  }

  window.HiveAnim.prepareTabInsertion = prepareTabInsertion;

  /* ---------- WORKSPACE SWITCH SLIDE ---------- */

  function animateWorkspaceSwitch(direction) {
    if (document.body.classList.contains('no-motion')) return;
    var strip = document.getElementById('tabList');
    if (!strip) return;
    var enterAnim = direction === 'next' ? 'workspace-enter-right' : 'workspace-enter-left';
    var leaveAnim = direction === 'next' ? 'workspace-leave-left' : 'workspace-leave-right';
    strip.style.animation = leaveAnim + ' 180ms var(--spring-smooth) forwards';
    strip.addEventListener('animationend', function handler() {
      strip.removeEventListener('animationend', handler);
      strip.style.animation = enterAnim + ' 220ms var(--spring-bounce) backwards';
      strip.addEventListener('animationend', function handler2() {
        strip.removeEventListener('animationend', handler2);
        strip.style.animation = '';
      });
    });
  }

  window.HiveAnim.animateWorkspaceSwitch = animateWorkspaceSwitch;

  /* ---------- AGENT DOCK THINKING DOTS ---------- */

  function showThinkingDots(container) {
    if (!container) return;
    container.innerHTML = '';
    for (var i = 0; i < 3; i++) {
      var dot = document.createElement('span');
      dot.className = 'agent-dot-pulse';
      container.appendChild(dot);
    }
  }

  window.HiveAnim.showThinkingDots = showThinkingDots;

  /* ---------- CONTENT PUSH TRANSITION (back/forward) ---------- */

  function animateNavDirection(direction) {
    if (document.body.classList.contains('no-motion')) return;
    var content = document.getElementById('webviewContainer');
    if (!content) return;
    var anim = direction === 'forward'
      ? 'content-push-left 220ms var(--spring-smooth)'
      : 'content-push-right 220ms var(--spring-smooth)';
    content.style.animation = anim;
    content.addEventListener('animationend', function handler() {
      content.removeEventListener('animationend', handler);
      content.style.animation = '';
    });
  }

  window.HiveAnim.animateNavDirection = animateNavDirection;

  /* ---------- TOAST WITH SPRING ---------- */

  function showAnimatedToast(message, type) {
    return showToast(message, type); // already uses CSS animation
  }

  window.HiveAnim.showAnimatedToast = showAnimatedToast;

  /* ---------- ITEM FLY-OUT (download complete) ---------- */

  function flyItemToTarget(sourceEl, targetSelector) {
    if (document.body.classList.contains('no-motion')) return;
    var target = document.querySelector(targetSelector);
    if (!target || !sourceEl) return;
    var sourceRect = sourceEl.getBoundingClientRect();
    var targetRect = target.getBoundingClientRect();
    var clone = sourceEl.cloneNode(true);
    clone.style.position = 'fixed';
    clone.style.left = sourceRect.left + 'px';
    clone.style.top = sourceRect.top + 'px';
    clone.style.width = sourceRect.width + 'px';
    clone.style.height = sourceRect.height + 'px';
    clone.style.zIndex = '10000';
    clone.style.pointerEvents = 'none';
    clone.style.transition = 'all 400ms ' + getComputedStyle(document.documentElement).getPropertyValue('--spring-smooth').trim();
    document.body.appendChild(clone);
    requestAnimationFrame(function () {
      clone.style.left = targetRect.left + targetRect.width / 2 - sourceRect.width / 2 + 'px';
      clone.style.top = targetRect.top + targetRect.height / 2 - sourceRect.height / 2 + 'px';
      clone.style.transform = 'scale(0.4)';
      clone.style.opacity = '0';
    });
    clone.addEventListener('transitionend', function () { clone.remove(); });
  }

  window.HiveAnim.flyItemToTarget = flyItemToTarget;

  /* ---------- GROUP COLLAPSE MORPH ---------- */

  function morphGroupCollapse(headerEl, tabContainer) {
    if (document.body.classList.contains('no-motion')) return;
    if (!tabContainer) return;
    var height = tabContainer.scrollHeight;
    tabContainer.style.transition = 'max-height 250ms var(--spring-smooth), opacity 200ms var(--spring-smooth)';
    tabContainer.style.overflow = 'hidden';
    tabContainer.style.maxHeight = height + 'px';
    tabContainer.style.opacity = '1';
    requestAnimationFrame(function () {
      tabContainer.style.maxHeight = '0px';
      tabContainer.style.opacity = '0';
    });
    tabContainer.addEventListener('transitionend', function handler() {
      tabContainer.removeEventListener('transitionend', handler);
      tabContainer.style.display = 'none';
      tabContainer.style.transition = '';
      tabContainer.style.maxHeight = '';
      tabContainer.style.opacity = '';
      tabContainer.style.overflow = '';
    });
  }

  window.HiveAnim.morphGroupCollapse = morphGroupCollapse;

  /* ---------- FOCUS RING PULSE ON KEYBOARD NAV ---------- */

  // Amplify focus ring when user is keyboard-navigating (tab key pressed).
  // Mouse users get the standard ring; keyboard users get a pulse.
  var keyboardUser = false;
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Tab') {
      keyboardUser = true;
      document.body.classList.add('keyboard-user');
    }
  });
  document.addEventListener('mousedown', function () {
    keyboardUser = false;
    document.body.classList.remove('keyboard-user');
  });

})();

/* ==========================================================================
   HIVE PHYSICS ENGINE v1 — Real spring dynamics, particles, confetti, gestures
   --------------------------------------------------------------------------
   CSS spring curves (cubic-bezier) are approximations. This engine solves
   real mass-stiffness-damping ODEs via RK4 integration, driving animations
   at 60fps through requestAnimationFrame. Everything below runs on the
   compositor thread (transform/opacity only) — zero layout thrash.
   ========================================================================== */

(function () {
  'use strict';

  /* ========================================================================
     SPRING PHYSICS SOLVER
     ------------------------------------------------------------------------
     Real mass-stiffness-damping ODE solved with 4th-order Runge-Kutta.
     CSS cubic-bezier springs are approximations — this is the real thing.

     Presets tuned for Hive's material feel:
       - SNAP:    m=1, k=420, d=32   (sharp settle, no bounce)
       - BOUNCE:  m=1, k=180, d=12   (playful overshoot)
       - SMOOTH:  m=1, k=210, d=26   (Material-standard)
       - GENTLE:  m=1, k=120, d=28   (slow, calm)
     ======================================================================== */

  var SpringPresets = {
    snap:   { mass: 1, stiffness: 420, damping: 32 },
    bounce: { mass: 1, stiffness: 180, damping: 12 },
    smooth: { mass: 1, stiffness: 210, damping: 26 }
  };

  function SpringSolver(config) {
    this.m = config.mass || 1;
    this.k = config.stiffness || 210;
    this.c = config.damping || 26;
    this.v = 0;       // velocity
    this.x = 0;       // displacement from rest
    this.target = 0;
    this.restThreshold = 0.001;
    this.restVelocityThreshold = 0.001;
  }

  SpringSolver.prototype.setTarget = function (t) { this.target = t; };

  SpringSolver.prototype.step = function (dt) {
    // RK4 integration of: m*x'' + c*x' + k*(x-target) = 0
    var m = this.m, k = this.k, c = this.c;
    function f(x, v) {
      var displacement = x - this.target;
      return { dx: v, dv: (-c * v - k * displacement) / m };
    }
    var s = f.call(this, this.x, this.v);
    var k1x = s.dx * dt, k1v = s.dv * dt;
    var s2 = f.call(this, this.x + k1x * 0.5, this.v + k1v * 0.5);
    var k2x = s2.dx * dt, k2v = s2.dv * dt;
    var s3 = f.call(this, this.x + k2x * 0.5, this.v + k2v * 0.5);
    var k3x = s3.dx * dt, k3v = s3.dv * dt;
    var s4 = f.call(this, this.x + k3x, this.v + k3v);
    var k4x = s4.dx * dt, k4v = s4.dv * dt;
    this.x += (k1x + 2 * k2x + 2 * k3x + k4x) / 6;
    this.v += (k1v + 2 * k2v + 2 * k3v + k4v) / 6;
    return this.isAtRest();
  };

  SpringSolver.prototype.isAtRest = function () {
    return Math.abs(this.x - this.target) < this.restThreshold &&
           Math.abs(this.v) < this.restVelocityThreshold;
  };

  // Spring-driven value animator: calls onUpdate(value) every frame until settled
  function animateSpring(config, from, to, duration, onUpdate, onComplete) {
    if (document.body.classList.contains('no-motion')) {
      onUpdate(to); if (onComplete) onComplete(); return;
    }
    var solver = new SpringSolver(config);
    solver.x = from;
    solver.setTarget(to);
    var start = null;
    function tick(ts) {
      if (!start) start = ts;
      var elapsed = ts - start;
      var dt = Math.min(elapsed / 1000, 0.064); // cap at ~15fps equivalent for stability
      var done = solver.step(dt);
      onUpdate(solver.x);
      if (!done && elapsed < (duration || 2000)) {
        requestAnimationFrame(tick);
      } else {
        onUpdate(to);
        if (onComplete) onComplete();
      }
    }
    requestAnimationFrame(tick);
  }

  window.HivePhysics = {
    SpringSolver: SpringSolver,
    SpringPresets: SpringPresets,
    animateSpring: animateSpring
  };

  /* ========================================================================
     SWIPE-TO-CLOSE TABS (pointer events + spring physics)
     ------------------------------------------------------------------------
     Drag a tab horizontally > 60px to close it. Spring animation snaps it
     back if released early, or flings it off-screen with a dissolve.
     Works on both trackpad and touch.
     ======================================================================== */

  function attachSwipeToClose(containerSelector) {
    var container = document.querySelector(containerSelector);
    if (!container) return;

    var activeSwipe = null; // { el, startX, offsetX, startTime }
    var swipeThreshold = 60; // px to trigger close

    container.addEventListener('pointerdown', function (e) {
      var tab = e.target.closest('.tab');
      if (!tab || e.button !== 0) return;
      // Don't swipe if clicking close/mute/group controls
      if (e.target.closest('[data-close],[data-mute],[data-toggle],.groupheader__name,.groupheader__toggle')) return;

      activeSwipe = {
        el: tab,
        startX: e.clientX,
        offsetX: 0,
        startTime: Date.now(),
        pointerId: e.pointerId
      };
      tab.setPointerCapture(e.pointerId);
      tab.style.transition = 'none';
    });

    container.addEventListener('pointermove', function (e) {
      if (!activeSwipe || e.pointerId !== activeSwipe.pointerId) return;
      activeSwipe.offsetX = e.clientX - activeSwipe.startX;
      // Only respond to horizontal movement (ignore vertical scrolling)
      if (Math.abs(activeSwipe.offsetX) < 8 && Math.abs(e.clientY - activeSwipe.el.getBoundingClientRect().top) > 40) return;

      var resistance = 1 - Math.min(Math.abs(activeSwipe.offsetX) / 300, 0.7);
      var tx = activeSwipe.offsetX * resistance;
      var opacity = 1 - Math.min(Math.abs(activeSwipe.offsetX) / 200, 0.85);
      activeSwipe.el.style.transform = 'translateX(' + tx + 'px)';
      activeSwipe.el.style.opacity = opacity;
    });

    container.addEventListener('pointerup', function (e) {
      if (!activeSwipe) return;
      var el = activeSwipe.el;
      var offsetX = activeSwipe.offsetX;
      var velocity = offsetX / Math.max(Date.now() - activeSwipe.startTime, 1);
      activeSwipe = null;

      if (Math.abs(offsetX) > swipeThreshold || Math.abs(velocity) > 0.6) {
        // FLING OFF: animate to edge + dissolve, then close
        var outX = offsetX > 0 ? window.innerWidth : -window.innerWidth;
        animateSpring(
          SpringPresets.smooth,
          offsetX, outX, 350,
          function (val) {
            el.style.transform = 'translateX(' + val + 'px)';
            el.style.opacity = 1 - Math.min(Math.abs(val) / (window.innerWidth * 0.5), 1);
          },
          function () {
            var closeID = el.dataset.id;
            if (closeID) api('hive.closeTab', { id: closeID });
          }
        );
      } else {
        // SNAP BACK: spring to origin
        animateSpring(
          SpringPresets.bounce,
          offsetX, 0, 400,
          function (val) {
            el.style.transform = 'translateX(' + val + 'px)';
            el.style.opacity = 1;
          },
          function () {
            el.style.transform = '';
            el.style.opacity = '';
            el.style.transition = '';
          }
        );
      }
    });

    container.addEventListener('pointercancel', function () {
      if (activeSwipe) {
        activeSwipe.el.style.transform = '';
        activeSwipe.el.style.opacity = '';
        activeSwipe.el.style.transition = '';
        activeSwipe = null;
      }
    });
  }

  if (IS_CHROME) attachSwipeToClose('#tabList');

  window.HivePhysics.attachSwipeToClose = attachSwipeToClose;

  /* ========================================================================
     WEB ANIMATIONS API WRAPPER — fluid sequenced animations
     ------------------------------------------------------------------------
     CSS keyframes are rigid. The Web Animations API (Element.animate())
     gives us per-property springs, sequences, and timeline control.
     ======================================================================== */

  function animateElement(el, keyframes, options) {
    if (!el || document.body.classList.contains('no-motion')) {
      if (options && options.fill === 'forwards' && keyframes.length) {
        var last = keyframes[keyframes.length - 1];
        for (var prop in last) {
          if (prop !== 'offset' && prop !== 'easing' && prop !== 'composite') {
            el.style[prop] = last[prop];
          }
        }
      }
      if (options && options.onComplete) options.onComplete();
      return null;
    }
    try {
      var anim = el.animate(keyframes, {
        duration: options.duration || 300,
        easing: options.easing || 'cubic-bezier(0.22, 1, 0.36, 1)',
        fill: options.fill || 'none',
        delay: options.delay || 0,
        iterations: options.iterations || 1
      });
      if (options.onComplete) anim.onfinish = options.onComplete;
      return anim;
    } catch (e) {
      // Fallback: instant apply
      if (options.onComplete) options.onComplete();
      return null;
    }
  }

  // Sequenced animation: fires each step's animation in order, with optional stagger
  function animateSequence(steps, staggerMs) {
    if (document.body.classList.contains('no-motion')) {
      steps.forEach(function (s) { if (s.onComplete) s.onComplete(); });
      return;
    }
    var i = 0;
    function next() {
      if (i >= steps.length) return;
      var step = steps[i];
      i++;
      var anim = animateElement(step.el, step.keyframes, {
        duration: step.duration || 300,
        easing: step.easing,
        fill: step.fill || 'forwards'
      });
      var delay = staggerMs || 0;
      if (anim && anim.finished) {
        anim.finished.then(function () { setTimeout(next, delay); });
      } else {
        setTimeout(next, step.duration + delay);
      }
    }
    next();
  }

  // Number counter: animates a numeric value from A to B, calling onUpdate
  function countNumber(from, to, duration, onUpdate, onComplete) {
    if (document.body.classList.contains('no-motion')) {
      onUpdate(to); if (onComplete) onComplete(); return;
    }
    animateSpring(
      SpringPresets.smooth,
      from, to, duration,
      function (val) { onUpdate(Math.round(val)); },
      onComplete
    );
  }

  window.HivePhysics.animateElement = animateElement;
  window.HivePhysics.animateSequence = animateSequence;
  window.HivePhysics.countNumber = countNumber;

  /* ========================================================================
     OFFLINE DETECTION — Chrome dinosaur parity
     Shows a non-intrusive banner when the network drops; auto-dismisses
     when connectivity returns. Uses navigator.onLine + online/offline events.
     ======================================================================== */

  var offlineBanner = null;
  function showOfflineBanner() {
    if (offlineBanner) return;
    offlineBanner = document.createElement('div');
    offlineBanner.className = 'hive-toast hive-toast--error hive-offline';
    offlineBanner.setAttribute('role', 'alert');
    offlineBanner.innerHTML = '<span class="hive-toast__icon" aria-hidden="true">!</span>' +
      '<span class="hive-toast__msg">You are offline. Some features may be unavailable.</span>';
    var region = toastRegion();
    region.appendChild(offlineBanner);
  }
  function hideOfflineBanner() {
    if (!offlineBanner) return;
    offlineBanner.classList.add('hive-toast--leaving');
    offlineBanner.addEventListener('animationend', function () { if (offlineBanner) { offlineBanner.remove(); offlineBanner = null; } }, { once: true });
    setTimeout(function () { if (offlineBanner && offlineBanner.parentNode) { offlineBanner.remove(); offlineBanner = null; } }, 300);
    showToast('Back online', 'success');
  }
  window.addEventListener('online', hideOfflineBanner);
  window.addEventListener('offline', showOfflineBanner);
  if (!navigator.onLine) showOfflineBanner();

  /* ========================================================================
     PAGE VISIBILITY — battery-aware rendering
     Pauses ambient particles and reduces timer resolution when the tab
     is hidden. Resumes when visible again.
     ======================================================================== */

  document.addEventListener('visibilitychange', function () {
    if (document.hidden) {
      document.body.classList.add('page-hidden');
    } else {
      document.body.classList.remove('page-hidden');
      // Refresh state when user returns to the tab
      if (IS_CHROME) refresh();
    }
  });

  /* ========================================================================
     PASSWORD GENERATOR — Safari/Chrome parity
     When the user focuses a password field, offer a strong auto-generated
     password. The generated password is copied to the clipboard and filled.
     ======================================================================== */

  var GENERATED_PASSWORD = '';
  var passwordBubble = null;

  function generateStrongPassword() {
    var chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789!@#$%';
    var pw = '';
    for (var i = 0; i < 20; i++) pw += chars.charAt(Math.floor(Math.random() * chars.length));
    return pw;
  }

  function showPasswordBubble(input) {
    if (!input || input.type !== 'password' || document.body.classList.contains('no-motion')) return;
    removePasswordBubble();
    GENERATED_PASSWORD = generateStrongPassword();
    passwordBubble = document.createElement('div');
    passwordBubble.className = 'pw-bubble';
    passwordBubble.setAttribute('role', 'dialog');
    passwordBubble.setAttribute('aria-label', 'Strong password suggestion');
    passwordBubble.innerHTML =
      '<span class="pw-bubble__text">' + esc(GENERATED_PASSWORD) + '</span>' +
      '<button class="pw-bubble__use">Use strong password</button>' +
      '<button class="pw-bubble__dismiss" aria-label="Dismiss">' + svg(ICONS.close, 12) + '</button>';
    passwordBubble.querySelector('.pw-bubble__use').addEventListener('click', function () {
      input.value = GENERATED_PASSWORD;
      // Trigger input event so frameworks (React/Vue) detect the change
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
      removePasswordBubble();
      showToast('Strong password filled', 'success');
    });
    passwordBubble.querySelector('.pw-bubble__dismiss').addEventListener('click', removePasswordBubble);
    document.body.appendChild(passwordBubble);
    // Position below the input
    var rect = input.getBoundingClientRect();
    passwordBubble.style.left = Math.min(rect.left, window.innerWidth - 320) + 'px';
    passwordBubble.style.top = (rect.bottom + 6) + 'px';
    // Spring entrance
    if (window.HivePhysics && window.HivePhysics.animateSpring) {
      passwordBubble.style.transform = 'translateY(-6px) scale(0.95)';
      passwordBubble.style.opacity = '0';
      requestAnimationFrame(function () {
        window.HivePhysics.animateSpring(
          window.HivePhysics.SpringPresets.bounce, 0, 0, 220,
          function () {},
          function () {
            passwordBubble.style.transform = '';
            passwordBubble.style.opacity = '';
          }
        );
      });
    }
    // Auto-dismiss after 8 seconds
    var dismissTimer = setTimeout(removePasswordBubble, 8000);
    passwordBubble._dismissTimer = dismissTimer;
  }

  function removePasswordBubble() {
    if (!passwordBubble) return;
    if (passwordBubble._dismissTimer) clearTimeout(passwordBubble._dismissTimer);
    passwordBubble.classList.add('hive-toast--leaving');
    setTimeout(function () { if (passwordBubble && passwordBubble.parentNode) passwordBubble.remove(); passwordBubble = null; }, 200);
  }

  // Listen for password field focus anywhere in the page
  document.addEventListener('focusin', function (e) {
    if (e.target && e.target.type === 'password' && e.target.value === '') {
      showPasswordBubble(e.target);
    }
  });

  // Tab on password fields with empty value also triggers (keyboard-friendly)
  document.addEventListener('keyup', function (e) {
    if (e.key === 'Tab' && e.target && e.target.type === 'password' && e.target.value === '') {
      setTimeout(function () { showPasswordBubble(e.target); }, 100);
    }
  });

  // Auto-dismiss when the user starts typing a custom password
  document.addEventListener('input', function (e) {
    if (e.target && e.target.type === 'password' && passwordBubble) {
      removePasswordBubble();
    }
  });

  /* ========================================================================
     SELECTION CONTEXT MENU — Chrome/Safari parity
     Right-clicking selected text offers "Search Hive for …" instead of
     the default browser context menu. Falls through to the native menu
     when no text is selected (so link/input context menus still work).
     ======================================================================== */

  document.addEventListener('contextmenu', function (e) {
    // Don't interfere with tab/group/panel context menus — those call
    // preventDefault and show their own ctxmenu instance.
    if (e.defaultPrevented) return;
    // Chrome parity: right-click a link → link menu; right-click an image
    // → image menu; right-click selected text → selection menu; otherwise
    // fall through to the native menu. Inputs keep the native menu.
    if (e.target && (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA')) return;

    // --- Link context menu (Chrome parity) ---
    var link = e.target && e.target.closest ? e.target.closest('a[href]') : null;
    if (link) {
      e.preventDefault();
      var href = link.getAttribute('href') || '';
      var absHref = link.href || href;
      ctx.innerHTML = '';
      [
        { label: 'Open in New Tab', run: function () { api('hive.newTabWithURL', { url: absHref, activate: false }); } },
        { label: 'Open in New Window', run: function () { api('hive.newWindowWithURL', { url: absHref }); } },
        { sep: true },
        { label: 'Copy Link Address', run: function () { copyTextToClipboard(absHref); } },
        { label: 'Bookmark Link', run: function () { api('hive.addBookmark', { url: absHref, title: link.textContent || absHref }); } },
        { label: 'Save Link As…', run: function () { api('hive.downloadURL', { url: absHref }); } }
      ].forEach(function (item) {
        if (item.sep) { ctx.appendChild(el('div', 'ctxmenu__sep')); return; }
        var b = el('button', 'ctxmenu__item');
        b.textContent = item.label;
        b.addEventListener('click', function () { ctx.hidden = true; item.run(); });
        ctx.appendChild(b);
      });
      showCtxAt(e.clientX, e.clientY);
      return;
    }

    // --- Image context menu (Chrome parity) ---
    var img = e.target && e.target.closest ? e.target.closest('img[src]') : null;
    if (img && !link) {
      e.preventDefault();
      var src = img.getAttribute('src') || '';
      var absSrc = img.currentSrc || (img.src || src);
      ctx.innerHTML = '';
      [
        { label: 'Open Image in New Tab', run: function () { api('hive.newTabWithURL', { url: absSrc, activate: false }); } },
        { label: 'Copy Image Address', run: function () { copyTextToClipboard(absSrc); } },
        { sep: true },
        { label: 'Save Image As…', run: function () { api('hive.downloadURL', { url: absSrc }); } },
        { label: 'Search Google for Image', run: function () { navigate('https://www.google.com/searchbyimage?image_url=' + encodeURIComponent(absSrc)); } }
      ].forEach(function (item) {
        if (item.sep) { ctx.appendChild(el('div', 'ctxmenu__sep')); return; }
        var b = el('button', 'ctxmenu__item');
        b.textContent = item.label;
        b.addEventListener('click', function () { ctx.hidden = true; item.run(); });
        ctx.appendChild(b);
      });
      showCtxAt(e.clientX, e.clientY);
      return;
    }

    var sel = window.getSelection();
    var text = sel ? sel.toString().trim() : '';
    if (!text || text.length > 500) return; // ignore long selections
    e.preventDefault();
    ctx.innerHTML = '';
    var searchItem = el('button', 'ctxmenu__item');
    searchItem.innerHTML = svg(ICONS.search, 12) +
      ' Search Hive for "<strong>' + esc(text.length > 50 ? text.slice(0, 50) + '…' : text) + '</strong>"';
    searchItem.addEventListener('click', function () {
      ctx.hidden = true;
      var url = 'https://www.google.com/search?q=' + encodeURIComponent(text);
      navigate(url);
    });
    ctx.appendChild(searchItem);
    var copyItem = el('button', 'ctxmenu__item');
    copyItem.textContent = 'Copy';
    copyItem.addEventListener('click', function () {
      ctx.hidden = true;
      navigator.clipboard.writeText(text).catch(function () {});
      showToast('Copied', 'success');
    });
    ctx.appendChild(copyItem);
    ctx.hidden = false;
    var w = ctx.offsetWidth, h = ctx.offsetHeight;
    ctx.style.left = Math.min(e.clientX, window.innerWidth - w - 8) + 'px';
    ctx.style.top = Math.min(e.clientY, window.innerHeight - h - 8) + 'px';
  });

  /* ========================================================================
     FIND-IN-PAGE MATCH COUNT — Chrome/Safari parity
     Updates a badge next to the find bar showing "3 of 12" matches.
     The Swift side broadcasts find results as state.findResults.
     ======================================================================== */

  var findBadge = document.getElementById('findBadge');
  if (!findBadge) {
    findBadge = document.createElement('span');
    findBadge.id = 'findBadge';
    findBadge.className = 'find-badge';
    var findBarEl = document.getElementById('findBar');
    if (findBarEl) findBarEl.appendChild(findBadge);
  }

  // Find-in-page bar: show/hide, next/prev, keyboard nav
  var findBarEl = $('findBar');
  var findInput = $('findInput');
  var findCount = $('findCount');

  function showFindBar() {
    if (!findBarEl) return;
    findBarEl.hidden = false;
    var results = state.findResults;
    if (results && results.query) findInput.value = results.query;
    findInput.focus();
    findInput.select();
    updateFindCount();
  }

  function hideFindBar() {
    if (!findBarEl) return;
    findBarEl.hidden = true;
    api('hive.findInPageDone');
  }

  function findNext() {
    var q = findInput.value.trim();
    if (q) api('hive.findNext', { query: q, forward: true }).then(function () { updateFindCount(); });
  }

  function findPrev() {
    var q = findInput.value.trim();
    if (q) api('hive.findNext', { query: q, forward: false }).then(function () { updateFindCount(); });
  }

  function findInPage(query) {
    if (query) api('hive.findInPage', { query: query }).then(function () { updateFindCount(); });
  }

  function updateFindCount() {
    if (!findCount || !findBarEl || findBarEl.hidden) return;
    var results = state.findResults;
    if (results && results.total > 0) {
      findCount.textContent = (results.current || 0) + ' of ' + results.total;
      findCount.hidden = false;
      $('findNext').disabled = false;
      $('findPrev').disabled = false;
    } else {
      findCount.textContent = '0 of 0';
      findCount.hidden = true;
      $('findNext').disabled = true;
      $('findPrev').disabled = true;
    }
  }

  if (findInput) {
    findInput.addEventListener('input', function () {
      var q = this.value.trim();
      if (q) findInPage(q);
      else { api('hive.findInPageDone'); updateFindCount(); }
    });
    findInput.addEventListener('keydown', function (e) {
      if (e.key === 'Enter') {
        e.preventDefault();
        e.shiftKey ? findPrev() : findNext();
      } else if (e.key === 'Escape') {
        e.preventDefault();
        hideFindBar();
      }
    });
  }
  if ($('findNext')) $('findNext').addEventListener('click', findNext);
  if ($('findPrev')) $('findPrev').addEventListener('click', findPrev);
  if ($('findClose')) $('findClose').addEventListener('click', hideFindBar);

  /* ========================================================================
     PERMISSION REQUEST PROMPT — Chrome parity
     When a site requests camera/mic/location/notifications, the native host
     pushes a pending request via state.pendingPermission; this prompt offers
     Allow / Block / Dismiss. The decision routes back to the native host.
     ======================================================================== */
  function renderPermissionPrompt() {
    var req = state.pendingPermission;
    var existing = document.querySelector('.perm-prompt');
    if (existing) existing.remove();
    if (!req) return;
    var types = { camera: 'camera', microphone: 'microphone', location: 'location', notifications: 'notifications' };
    var label = types[req.type] || req.type || 'permission';
    var wrap = document.createElement('div');
    wrap.className = 'perm-prompt';
    wrap.setAttribute('role', 'dialog');
    wrap.setAttribute('aria-label', 'Permission request');
    wrap.innerHTML =
      '<div class="perm-prompt__card">' +
      '<div class="perm-prompt__icon">' + (req.type === 'camera' ? '📷' : req.type === 'microphone' ? '🎤' : req.type === 'location' ? '📍' : '🔔') + '</div>' +
      '<div class="perm-prompt__text">' +
      '<div class="perm-prompt__host">' + esc(req.host || '') + '</div>' +
      '<div class="perm-prompt__ask">Wants to use your ' + esc(label) + '</div>' +
      '</div>' +
      '<div class="perm-prompt__actions">' +
      '<button class="perm-prompt__btn perm-prompt__btn--ghost" data-perm="deny">Block</button>' +
      '<button class="perm-prompt__btn perm-prompt__btn--primary" data-perm="allow">Allow</button>' +
      '</div>' +
      '<button class="perm-prompt__x" data-perm="dismiss" aria-label="Dismiss">' + svg(ICONS.close, 10) + '</button>' +
      '</div>';
    wrap.querySelector('[data-perm="allow"]').addEventListener('click', function () {
      wrap.remove();
      api('hive.respondPermission', { type: req.type, response: 'allow' });
    });
    wrap.querySelector('[data-perm="deny"]').addEventListener('click', function () {
      wrap.remove();
      api('hive.respondPermission', { type: req.type, response: 'deny' });
    });
    wrap.querySelector('[data-perm="dismiss"]').addEventListener('click', function () {
      wrap.remove();
      api('hive.respondPermission', { type: req.type, response: 'dismiss' });
    });
    document.body.appendChild(wrap);
  }

  /* ========================================================================
     PASSWORD SAVE PROMPT — Chrome parity
     state.pendingPassword = { url, host, username, password } arrives after
     a form submit; the prompt offers Save / Never / Dismiss.
     ======================================================================== */
  function renderPasswordPrompt() {
    var req = state.pendingPassword;
    var existing = document.querySelector('.pw-save');
    if (existing) existing.remove();
    if (!req) return;
    var wrap = document.createElement('div');
    wrap.className = 'pw-save';
    wrap.setAttribute('role', 'dialog');
    wrap.setAttribute('aria-label', 'Save password');
    wrap.innerHTML =
      '<div class="pw-save__card">' +
      '<div class="pw-save__title">Save password for ' + esc(req.host || '') + '?</div>' +
      '<div class="pw-save__creds">' +
      '<span class="pw-save__user">' + esc(req.username || 'user') + '</span>' +
      '<span class="pw-save__dots">••••••••</span>' +
      '</div>' +
      '<div class="pw-save__actions">' +
      '<button class="pw-save__btn pw-save__btn--ghost" data-pw="never">Never</button>' +
      '<button class="pw-save__btn pw-save__btn--primary" data-pw="save">Save password</button>' +
      '</div>' +
      '<button class="perm-prompt__x" data-pw="dismiss" aria-label="Dismiss">' + svg(ICONS.close, 10) + '</button>' +
      '</div>';
    wrap.querySelector('[data-pw="save"]').addEventListener('click', function () {
      wrap.remove();
      api('hive.savePassword', { url: req.url, username: req.username, password: req.password });
    });
    wrap.querySelector('[data-pw="never"]').addEventListener('click', function () {
      wrap.remove();
      api('hive.neverSavePassword', { url: req.url });
    });
    wrap.querySelector('[data-pw="dismiss"]').addEventListener('click', function () { wrap.remove(); });
    document.body.appendChild(wrap);
  }

  /* ========================================================================
     TRANSLATE BAR — Chrome parity
     state.translateOffer = { from, to, url } arrives when the page language
     differs from the user's; offer one-click translation with dismiss.
     ======================================================================== */
  function renderTranslateBar() {
    var offer = state.translateOffer;
    var existing = document.querySelector('.translate-bar');
    if (existing) existing.remove();
    if (!offer) return;
    var bar = document.createElement('div');
    bar.className = 'translate-bar';
    bar.setAttribute('role', 'region');
    bar.setAttribute('aria-label', 'Translate page');
    bar.innerHTML =
      '<span class="translate-bar__icon">🌐</span>' +
      '<span class="translate-bar__msg">This page is in <strong>' + esc(offer.from || 'another language') + '</strong>. Translate to ' + esc(offer.to || 'English') + '?</span>' +
      '<button class="translate-bar__btn" data-t="go">Translate</button>' +
      '<button class="translate-bar__dismiss" data-t="dismiss" aria-label="Dismiss">' + svg(ICONS.close, 10) + '</button>';
    bar.querySelector('[data-t="go"]').addEventListener('click', function () {
      bar.remove();
      api('hive.translatePage', { url: offer.url, to: offer.to });
    });
    bar.querySelector('[data-t="dismiss"]').addEventListener('click', function () { bar.remove(); });
    document.body.appendChild(bar);
  }

  // Hook download shelf, find badge, permission/password/translate prompts
  // into the apply cycle (single post-apply hook).
  var _origApply = apply;
  apply = function (data) {
    _origApply(data);
    renderDownloadShelf();
    renderPermissionPrompt();
    renderPasswordPrompt();
    renderTranslateBar();
    maybeShowFullscreenHint();
    if (findBadge) {
      var results = state.findResults;
      if (results && results.total > 0) {
        findBadge.textContent = (results.current || 0) + ' of ' + results.total;
        findBadge.hidden = false;
      } else {
        findBadge.hidden = true;
      }
    }
  };

  /* ---------- Tab Search wiring (once at init, not per-open) ---------- */
  (function () {
    var tsInput = $('tabSearchInput');
    var tsOverlay = $('tabSearchOverlay');
    if (!tsInput || !tsOverlay) return;
    tsInput.addEventListener('input', function () {
      var q = tsInput.value.trim().toLowerCase();
      var results = $('tabSearchResults');
      var hits = state.tabs.filter(function (t) {
        if (!q) return true;
        return (t.title || '').toLowerCase().indexOf(q) >= 0 ||
          (t.host || '').toLowerCase().indexOf(q) >= 0 ||
          (t.url || '').toLowerCase().indexOf(q) >= 0;
      });
      results.innerHTML = hits.length
        ? hits.map(function (t) {
            return '<div class="tabsearch-hit" data-tabid="' + t.id + '">' +
              '<span class="le__tile" style="background:hsl(' + (Math.abs(hash(t.host || t.id)) % 360) + ',32%,48%);width:24px;height:24px;font-size:11px">' +
              esc((t.host || '?').charAt(0).toUpperCase()) + '</span>' +
              '<span class="tabsearch-hit__title">' + esc(t.title || 'New Tab') + '</span>' +
              '<span class="tabsearch-hit__url">' + esc(t.host || '') + '</span></div>';
          }).join('')
        : '<div style="padding:16px;text-align:center;color:var(--text-muted);font-size:13px">No tabs match</div>';
      results.querySelectorAll('.tabsearch-hit').forEach(function (hit) {
        hit.addEventListener('click', function () {
          api('hive.selectTab', { id: hit.dataset.tabid });
          tsOverlay.hidden = true;
        });
      });
    });
    tsInput.addEventListener('keydown', function (e) {
      if (e.key === 'Escape') { tsOverlay.hidden = true; }
      if (e.key === 'Enter') {
        var first = $('tabSearchResults').querySelector('.tabsearch-hit');
        if (first) { first.click(); tsOverlay.hidden = true; }
      }
    });
  })();

  function openTabSearch() {
    var overlay = $('tabSearchOverlay');
    var input = $('tabSearchInput');
    overlay.hidden = false;
    input.value = '';
    input.focus();
    input.dispatchEvent(new Event('input'));
  }

  /* ========================================================================
     AUTOFILL SUGGESTION CHIP — Chrome parity
     When the user focuses a username/password field on a real page and the
     native host has saved credentials for that host (state.savedCredentials),
     show a chip below the field offering one-click autofill.
     ======================================================================== */
  var autofillChipTimer = null;
  function maybeShowAutofillChip(target) {
    if (!target || !target.closest) return;
    // Only on real password/username fields inside forms.
    var isPass = target.type === 'password';
    var isUser = (target.type === 'text' || target.type === 'email' ||
      target.type === 'username' || target.autocomplete === 'username');
    if (!isPass && !isUser) return;
    if (!(state.savedCredentials && state.savedCredentials.length)) return;
    var host = state.activeTabHost || '';
    if (!host) return;
    var creds = state.savedCredentials.filter(function (c) {
      return !host || (c.host || '').indexOf(host) >= 0 || host.indexOf(c.host || '') >= 0;
    });
    if (!creds.length) return;
    var existing = document.querySelector('.autofill-chip');
    if (existing) existing.remove();
    var chip = document.createElement('div');
    chip.className = 'autofill-chip';
    chip.setAttribute('role', 'button');
    chip.tabIndex = -1;
    chip.innerHTML =
      '<span class="autofill-chip__key">🔑</span>' +
      '<span class="autofill-chip__label">Autofill as <strong>' + esc(creds[0].username || 'saved user') + '</strong></span>' +
      '<span class="autofill-chip__dismiss">' + svg(ICONS.close, 9) + '</span>';
    chip.addEventListener('click', function (e) {
      if (e.target.closest('.autofill-chip__dismiss')) {
        chip.remove();
        return;
      }
      api('hive.autofillCredentials', { host: host, username: creds[0].username }).then(function () {
        chip.remove();
        showToast('Autofilled credentials', 'success');
      });
    });
    // Position under the focused field, clamped to the viewport.
    var rect = target.getBoundingClientRect();
    chip.style.top = (rect.bottom + 6) + 'px';
    chip.style.left = Math.max(8, Math.min(rect.left, window.innerWidth - 240)) + 'px';
    document.body.appendChild(chip);
    target.addEventListener('blur', function onBlur() {
      setTimeout(function () {
        if (!document.activeElement || !document.activeElement.closest ||
            !document.activeElement.closest('.autofill-chip')) {
          chip.remove();
        }
      }, 150);
    }, { once: true });
  }
  // Page-mode focus listener: autofill chip only makes sense on real pages.
  if (!IS_CHROME) {
    document.addEventListener('focusin', function (e) {
      clearTimeout(autofillChipTimer);
      autofillChipTimer = setTimeout(function () { maybeShowAutofillChip(e.target); }, 250);
    });
  }

  /* ========================================================================
     FULLSCREEN EXIT HINT — Chrome/Safari parity
     While in fullscreen, show a transient "Press Esc to exit fullscreen"
     hint near the top of the screen, fading out after a few seconds.
     ======================================================================== */
  var fsHintShown = false;
  function maybeShowFullscreenHint() {
    if (!state.isFullscreen || fsHintShown) return;
    fsHintShown = true;
    var hint = document.createElement('div');
    hint.className = 'fs-hint';
    hint.textContent = 'Press Esc to exit fullscreen';
    hint.setAttribute('role', 'status');
    document.body.appendChild(hint);
    setTimeout(function () {
      hint.classList.add('fs-hint--out');
      setTimeout(function () { hint.remove(); }, 400);
    }, 3000);
    setTimeout(function () { fsHintShown = false; }, 8000);
  }

})();
