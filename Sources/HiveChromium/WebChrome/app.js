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
    accentHex: '#6366F1',
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
        state.accentHex = data.accentHex || '#6366F1';
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
