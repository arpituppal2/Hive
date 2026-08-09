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
    tabs: [], activeTabID: null, spaces: [], accentHex: '#6366F1',
    topSites: [], recent: [], history: [], bookmarks: [], downloads: [],
    layout: 'vertical', isPrivateBrowsing: false, isSplitActive: false,
    isChromePanelOpen: null, chromeMode: 'sidebar', chromeDimension: 270,
    councilVerdict: null, isCouncilConvening: false, councilLiveResponses: [], deepResearchStep: null,
    agentTask: null, councilError: null, agentError: null, lastQuery: ''
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
    existing.style.left = (rect.right + 12) + 'px';
    existing.style.top = Math.min(rect.top, window.innerHeight - 260) + 'px';
    existing.dataset.visible = 'true';
  }

  function hideTabPeek() {
    var el = document.querySelector('.tab-peek');
    if (el) { delete el.dataset.visible; setTimeout(function () { if (el && !el.dataset.visible) el.remove(); }, 200); }
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
  // would fire navigate('hive://brief/') N times per click).
  $('btnOpenBrief').addEventListener('click', function () { navigate('hive://brief/'); });

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

  // ? key -> keyboard shortcuts overlay
  document.addEventListener('keydown', function(e){
    if (e.key === '?' && !e.ctrlKey && !e.metaKey && !e.altKey && document.activeElement && document.activeElement.tagName !== 'INPUT' && document.activeElement.tagName !== 'TEXTAREA') {
      e.preventDefault();
      var overlay = document.getElementById('shortcutsOverlay');
      if (overlay) overlay.hidden = !overlay.hidden;
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
