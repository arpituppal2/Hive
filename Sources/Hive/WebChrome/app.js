'use strict';

/* ── bridge ─────────────────────────────────────────────────────────── */

async function rpc(method, payload = {}) {
  try {
    const call = window.hive && window.hive.call;
    if (!call) return null;
    const res = await call.call(window.hive, method, payload);
    if (res && res.ok) return res.data;
    console.warn(`hive ${method} failed`, res && res.err);
    return null;
  } catch (err) {
    console.warn(`hive ${method} threw`, err);
    return null;
  }
}

/* ── state ──────────────────────────────────────────────────────────── */

const state = {
  tabs: [],
  activeId: null,
  settings: { railCollapsed: false, tabOrientation: 'vertical', askPanelOpen: false },
  bookmarks: new Set(),
  capture: 'idle',
  lastFailedCapture: null,
  lastQuestion: '',
  ask: { phase: 'empty', askId: null, text: '', citations: [], dropped: [] },
  cursor: 0,
  autoRail: false,
};

const KIND_ICON = { history: 'clock', capture: 'doc', bookmark: 'star', url: 'globe' };

/* ── dom ────────────────────────────────────────────────────────────── */

const el = {};

function cacheDom() {
  for (const id of [
    'chrome-sidebar', 'chrome-toolbar', 'new-tab-btn', 'rail-toggle',
    'tab-slot-side', 'tab-slot-bar',
    'omnibox-shell', 'omnibox-box', 'omnibox', 'bookmark-btn', 'nav-progress', 'omnibox-suggestions',
    'capture-btn', 'ask-toggle', 'ask-panel', 'ask-close', 'ask-body',
    'ask-empty', 'ask-stream', 'ask-answer', 'ask-dropped', 'ask-citations',
    'ask-refused', 'ask-refused-msg', 'ask-refused-note', 'ask-refused-capture',
    'ask-error', 'ask-retry', 'ask-form', 'ask-input', 'ask-send', 'ask-stop', 'ask-capture-page',
    'back-btn', 'fwd-btn', 'reload-btn', 'scrim', 'toast',
  ]) el[id] = document.getElementById(id);
}

let tabList, pinnedRow, unpinnedRow;

function buildStaticDom() {
  tabList = document.createElement('div');
  tabList.id = 'tab-list';
  tabList.setAttribute('data-testid', 'tab-list');
  tabList.setAttribute('role', 'tablist');

  pinnedRow = document.createElement('div');
  pinnedRow.className = 'pinned-row';
  pinnedRow.hidden = true;

  unpinnedRow = document.createElement('div');
  unpinnedRow.className = 'unpinned';

  tabList.append(pinnedRow, unpinnedRow);
  el['tab-slot-side'].append(tabList);

  el['omnibox-suggestions'].addEventListener('mousedown', (e) => e.preventDefault());
}

function $(sel, root = document) {
  return root.querySelector(sel);
}

/* ── utils ──────────────────────────────────────────────────────────── */

function hostOf(url) {
  try {
    return new URL(url).hostname.replace(/^www\./, '');
  } catch {
    return '';
  }
}

function activeTab() {
  return state.tabs.find((t) => t.id === state.activeId) || null;
}

/* ── layout / settings ──────────────────────────────────────────────── */

async function refreshSettings() {
  const d = await rpc('settings.get', {});
  if (d && d.settings) {
    for (const k of ['railCollapsed', 'tabOrientation', 'askPanelOpen']) {
      if (k in d.settings && d.settings[k] != null) state.settings[k] = d.settings[k];
    }
  }
  applyLayout();
}

async function setSetting(key, value) {
  state.settings[key] = value;
  applyLayout();
  await rpc('settings.set', { patch: { [key]: value } });
}

function applyLayout() {
  const s = state.settings;
  const horiz = s.tabOrientation === 'horizontal';
  const rail = horiz || s.railCollapsed || state.autoRail;
  const b = document.body;
  b.dataset.orientation = horiz ? 'horizontal' : 'vertical';
  b.dataset.rail = rail ? 'true' : 'false';
  b.classList.toggle('ask-open', !!s.askPanelOpen);
  el['ask-panel'].setAttribute('aria-hidden', s.askPanelOpen ? 'false' : 'true');
  el['ask-toggle'].setAttribute('aria-pressed', String(!!s.askPanelOpen));

  const rt = el['rail-toggle'];
  rt.disabled = horiz;
  rt.setAttribute('aria-expanded', String(!rail));
  rt.setAttribute('aria-label', rail ? 'Expand sidebar' : 'Collapse sidebar');
  $('.lbl', rt).textContent = rail ? 'Expand' : 'Collapse';

  const side = horiz || rail;
  el['chrome-sidebar'].setAttribute('aria-expanded', String(!side));
  moveTabList(horiz);
}

function moveTabList(horiz) {
  (horiz ? el['tab-slot-bar'] : el['tab-slot-side']).append(tabList);
}

async function toggleRail() {
  if (state.settings.tabOrientation === 'horizontal') return;
  const railNow = document.body.dataset.rail === 'true';
  await setSetting('railCollapsed', !railNow);
}

async function toggleAsk(force) {
  const next = force != null ? !!force : !state.settings.askPanelOpen;
  await setSetting('askPanelOpen', next);
  if (next) {
    renderAsk();
    el['ask-input'].focus();
  }
}

/* ── tabs ───────────────────────────────────────────────────────────── */

async function refreshTabs() {
  const d = await rpc('tabs.list', {});
  if (!d) return;
  state.tabs = Array.isArray(d.tabs) ? d.tabs : [];
  state.activeId = d.activeId != null
    ? d.activeId
    : (state.tabs.find((t) => t.active) || {}).id ?? null;
  renderTabs();
  syncOmniboxValue();
  syncBookmarkButton();
}

function initialOf(tab) {
  const h = hostOf(tab.url || '');
  const c = ((h || tab.title || '?').trim()[0]) || '?';
  return c.toUpperCase();
}

function buildTabItem(tab) {
  const item = document.createElement('div');
  item.className = 'tab-item';
  item._tid = tab.id;
  item.setAttribute('role', 'tab');
  item.setAttribute('data-testid', 'tab-item');
  item.setAttribute('data-tab-id', String(tab.id));
  item.setAttribute('data-title', tab.title || '');
  const active = tab.id === state.activeId;
  item.dataset.active = active ? 'true' : 'false';
  item.setAttribute('aria-selected', active ? 'true' : 'false');
  item.tabIndex = active ? 0 : -1;
  item.title = tab.title || tab.url || '';

  const fav = document.createElement('span');
  fav.className = 'fav';
  fav.setAttribute('aria-hidden', 'true');
  fav.textContent = initialOf(tab);
  item.append(fav);

  if (!tab.pinned) {
    const title = document.createElement('span');
    title.className = 'tab-title';
    title.textContent = tab.title || tab.url || 'Untitled';
    item.append(title);

    const close = document.createElement('button');
    close.type = 'button';
    close.className = 'close-tab';
    close.setAttribute('data-testid', 'close-tab');
    close.setAttribute('aria-label', `Close ${tab.title || 'tab'}`);
    close.innerHTML = '<svg class="ic" aria-hidden="true"><use href="#i-close"/></svg>';
    close.addEventListener('click', (e) => {
      e.stopPropagation();
      closeTab(tab.id);
    });
    item.append(close);
  } else {
    item.classList.add('pin');
    item.title = `Pinned — ${tab.title || tab.url || ''}`;
  }

  item.addEventListener('click', () => selectTab(tab.id));
  item.addEventListener('auxclick', (e) => {
    if (e.button === 1) {
      e.preventDefault();
      closeTab(tab.id);
    }
  });
  return item;
}

function renderTabs() {
  const pins = [];
  const rest = [];
  for (const t of state.tabs) (t.pinned ? pins : rest).push(buildTabItem(t));
  pinnedRow.replaceChildren(...pins);
  pinnedRow.hidden = pins.length === 0;
  unpinnedRow.replaceChildren(...rest);
  const active = tabList.querySelector('.tab-item[data-active="true"]');
  if (active) active.scrollIntoView({ block: 'nearest', inline: 'nearest' });
}

async function selectTab(id) {
  await rpc('tabs.select', { id });
  refreshTabs();
}

async function closeTab(id) {
  await rpc('tabs.close', { id });
  refreshTabs();
}

async function createTab() {
  await rpc('tabs.create', {});
  refreshTabs();
}

async function cycleTab(dir) {
  if (!state.tabs.length) return;
  const i = state.tabs.findIndex((t) => t.id === state.activeId);
  const next = state.tabs[(i + dir + state.tabs.length) % state.tabs.length];
  if (next) selectTab(next.id);
}

function selectNthTab(n) {
  const t = state.tabs[n - 1];
  if (t) selectTab(t.id);
}

/* ── omnibox ────────────────────────────────────────────────────────── */

const omni = { open: false, items: [], hl: -1 };

function omniOpen() {
  if (omni.open) return;
  omni.open = true;
  el['omnibox-box'].classList.add('focused');
  el['omnibox'].setAttribute('aria-expanded', 'true');
  el['omnibox-suggestions'].hidden = false;
  if (!omni.items.length) omniSuggest(el['omnibox'].value);
}

function omniClose() {
  if (!omni.open) return;
  omni.open = false;
  omni.hl = -1;
  el['omnibox-box'].classList.remove('focused');
  el['omnibox'].setAttribute('aria-expanded', 'false');
  el['omnibox-suggestions'].hidden = true;
}

let omniDebounce = null;

function onOmniInput() {
  clearTimeout(omniDebounce);
  omniDebounce = setTimeout(() => omniSuggest(el['omnibox'].value), 80);
}

async function omniSuggest(query) {
  const d = await rpc('omnibox.suggest', { query });
  if (!omni.open) return;
  omni.items = (d && d.suggestions) || [];
  omni.hl = -1;
  renderSuggestions();
}

function renderSuggestions() {
  const box = el['omnibox-suggestions'];
  box.replaceChildren();
  if (!omni.items.length) {
    const empty = document.createElement('div');
    empty.className = 'suggestion s-empty';
    empty.setAttribute('data-kind', 'none');
    empty.textContent = 'No matches - Enter to search';
    box.append(empty);
    return;
  }
  omni.items.forEach((s, i) => {
    const row = document.createElement('div');
    row.className = 'suggestion';
    row.id = `sug-${i}`;
    row.setAttribute('role', 'option');
    row.setAttribute('aria-selected', 'false');
    row.setAttribute('data-testid', 'suggestion-item');
    row.setAttribute('data-kind', s.kind || 'url');
    row.innerHTML = `<svg class="ic kind" aria-hidden="true"><use href="#i-${KIND_ICON[s.kind] || 'globe'}"/></svg>`;
    const t = document.createElement('span');
    t.className = 's-title';
    t.textContent = s.title || s.url || '';
    const h = document.createElement('span');
    h.className = 's-host';
    h.textContent = hostOf(s.url || '');
    row.append(t, h);
    row.addEventListener('click', () => omniPick(i));
    box.append(row);
  });
  highlightSuggestion();
}

function highlightSuggestion() {
  const rows = el['omnibox-suggestions'].children;
  for (let i = 0; i < rows.length; i++) {
    rows[i].classList.toggle('hl', i === omni.hl);
    rows[i].setAttribute('aria-selected', i === omni.hl ? 'true' : 'false');
  }
  el['omnibox'].setAttribute('aria-activedescendant', omni.hl >= 0 ? `sug-${omni.hl}` : '');
}

function omniMove(dir) {
  const n = omni.items.length;
  if (!n) return;
  omni.hl = Math.max(-1, Math.min(n - 1, omni.hl + dir));
  highlightSuggestion();
}

function omniPick(i) {
  const s = omni.items[i];
  if (!s || !s.url) return;
  omniClose();
  el['omnibox'].blur();
  rpc('nav.go', { url: s.url });
}

function omniSubmitCurrent() {
  const text = el['omnibox'].value.trim();
  const picked = omni.hl >= 0 ? omni.items[omni.hl] : null;
  omniClose();
  el['omnibox'].blur();
  if (picked && picked.url) rpc('nav.go', { url: picked.url });
  else if (text) rpc('omnibox.submit', { text });
}

function syncOmniboxValue() {
  const input = el['omnibox'];
  if (document.activeElement === input) return;
  const t = activeTab();
  input.value = (t && t.url) || '';
}

function setNavLoading(on) {
  el['nav-progress'].hidden = !on;
}

/* ── navigation / capture / bookmark ────────────────────────────────── */

let captureTimer = null;

function setCaptureState(next) {
  state.capture = next;
  const b = el['capture-btn'];
  b.dataset.state = next;
  $('.ic-idle', b).hidden = !(next === 'idle' || next === 'failed');
  $('.spinner', b).hidden = next !== 'running';
  $('.ic-ok', b).hidden = next !== 'success';
  $('.ic-fail', b).hidden = next !== 'failed';
  $('.tool-lbl', b).textContent = next === 'running' ? 'Capturing...' : 'Capture';
  b.disabled = next === 'running';
}

async function requestCapture() {
  if (state.capture === 'running') return;
  clearTimeout(captureTimer);
  setCaptureState('running');
  const d = await rpc('capture.request', {});
  if (!d) setCaptureState('idle');
}

async function rawSaveFailedCapture() {
  const f = state.lastFailedCapture || {};
  setCaptureState('idle');
  await rpc('capture.rawSave', { url: f.url || '', title: f.title || '', text: '' });
}

async function refreshBookmarks() {
  const d = await rpc('bookmark.list', {});
  const list = (d && d.bookmarks) || [];
  state.bookmarks = new Set(
    list.map((b) => (typeof b === 'string' ? b : b && b.url)).filter(Boolean),
  );
  syncBookmarkButton();
}

function syncBookmarkButton() {
  const t = activeTab();
  const marked = !!(t && t.url && state.bookmarks.has(t.url));
  el['bookmark-btn'].dataset.bookmarked = marked ? 'true' : 'false';
  el['bookmark-btn'].setAttribute('aria-pressed', String(marked));
  el['bookmark-btn'].classList.toggle('on', marked);
}

async function toggleBookmark() {
  const t = activeTab();
  if (!t || !t.url) return;
  if (state.bookmarks.has(t.url)) {
    await rpc('bookmark.remove', { url: t.url });
    state.bookmarks.delete(t.url);
  } else {
    await rpc('bookmark.add', { url: t.url, title: t.title || '' });
    state.bookmarks.add(t.url);
  }
  syncBookmarkButton();
}

/* ── ask panel ──────────────────────────────────────────────────────── */

function renderAsk() {
  const a = state.ask;
  el['ask-empty'].hidden = a.phase !== 'empty';
  el['ask-stream'].hidden = !(a.phase === 'streaming' || a.phase === 'done');
  el['ask-refused'].hidden = a.phase !== 'refused';
  el['ask-error'].hidden = a.phase !== 'error';
  const streaming = a.phase === 'streaming';
  el['ask-stop'].hidden = !streaming;
  el['ask-send'].hidden = streaming;
}

function scrollAskBottom() {
  el['ask-body'].scrollTop = el['ask-body'].scrollHeight;
}

async function submitAsk(question) {
  if (state.ask.phase === 'streaming') return;
  const q = (question || '').trim();
  if (!q) return;
  state.lastQuestion = q;
  state.ask = { phase: 'streaming', askId: null, text: '', citations: [], dropped: [] };
  el['ask-answer'].replaceChildren();
  el['ask-dropped'].hidden = true;
  el['ask-citations'].hidden = true;
  renderAsk();
  scrollAskBottom();
  const d = await rpc('ask.request', { question: q });
  if (!d || d.askId == null) {
    state.ask.phase = 'error';
    renderAsk();
    return;
  }
  if (state.ask.phase === 'streaming' && state.ask.askId == null) state.ask.askId = d.askId;
}

function adoptAsk(id) {
  const a = state.ask;
  if (a.phase !== 'streaming') return false;
  if (a.askId == null) {
    a.askId = id;
    return true;
  }
  return a.askId === id;
}

function citationChip(n, cite) {
  const b = document.createElement('button');
  b.type = 'button';
  b.className = 'citation-chip';
  b.setAttribute('data-testid', 'citation-chip');
  b.setAttribute('data-span-id', cite.spanId != null ? String(cite.spanId) : '');
  if (cite.captureId != null) b.setAttribute('data-capture-id', String(cite.captureId));
  b.textContent = `[${n}]`;
  if (cite.quote) b.title = cite.quote;
  b.addEventListener('click', () => {
    rpc('reader.open', { spanId: cite.spanId, captureId: cite.captureId });
  });
  return b;
}

function formatAnswer(text, cites) {
  const frag = document.createDocumentFragment();
  const re = /\[(\d+)\]/g;
  let last = 0;
  let m;
  while ((m = re.exec(text))) {
    if (m.index > last) frag.append(text.slice(last, m.index));
    const n = Number(m[1]);
    const c = cites[n - 1];
    frag.append(c ? citationChip(n, c) : document.createTextNode(m[0]));
    last = m.index + m[0].length;
  }
  if (last < text.length) frag.append(text.slice(last));
  return frag;
}

function renderAnswerFinal() {
  const a = state.ask;
  el['ask-answer'].replaceChildren(formatAnswer(a.text, a.citations));

  const used = new Set();
  const re = /\[(\d+)\]/g;
  let m;
  while ((m = re.exec(a.text))) used.add(Number(m[1]));

  const row = el['ask-citations'];
  row.replaceChildren();
  a.citations.forEach((c, idx) => {
    if (!used.has(idx + 1)) row.append(citationChip(idx + 1, c));
  });
  row.hidden = row.childElementCount === 0;

  const w = el['ask-dropped'];
  w.replaceChildren();
  w.hidden = a.dropped.length === 0;
  if (a.dropped.length) {
    const label = document.createElement('div');
    label.className = 'dropped-label';
    label.textContent = 'removed an unsupported claim';
    w.append(label);
    for (const c of a.dropped) {
      const t = typeof c === 'string' ? c : (c && (c.text || c.quote || c.claim)) || '';
      if (!t) continue;
      const d = document.createElement('div');
      d.className = 'dropped-item';
      d.textContent = t;
      w.append(d);
    }
  }
  scrollAskBottom();
}

function showRefusal(p) {
  const empty = p.flavor === 'empty-corpus';
  el['ask-refused-msg'].textContent =
    p.message || (empty ? 'Nothing captured yet.' : "Answers aren't ready yet.");
  el['ask-refused-note'].hidden = empty;
  el['ask-refused-capture'].hidden = !empty;
  state.ask.phase = 'refused';
  renderAsk();
}

async function cancelAsk() {
  const a = state.ask;
  if (a.phase !== 'streaming') return;
  const id = a.askId;
  a.phase = 'done';
  a.askId = null;
  renderAsk();
  if (id != null) await rpc('ask.cancel', { askId: id });
}

/* ── toast ──────────────────────────────────────────────────────────── */

let toastTimer = null;

function hideToast() {
  clearTimeout(toastTimer);
  el['toast'].classList.remove('show');
}

function showToast(message, { tone = 'info', buttons = [] } = {}) {
  const t = el['toast'];
  t.replaceChildren();
  const msg = document.createElement('span');
  msg.className = `toast-msg${tone === 'danger' ? ' danger' : ''}`;
  msg.textContent = message;
  t.append(msg);
  for (const b of buttons) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = `toast-btn${b.primary ? ' primary' : ''}`;
    btn.textContent = b.label;
    btn.addEventListener('click', () => {
      hideToast();
      if (b.onClick) b.onClick();
    });
    t.append(btn);
  }
  t.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(hideToast, buttons.length ? 12000 : 4000);
}

/* ── events polling + dispatch ──────────────────────────────────────── */

function handleEvent(ev) {
  const p = ev.payload || {};
  switch (ev.type) {
    case 'state.changed':
      if ('loading' in p) setNavLoading(!!p.loading);
      refreshTabs();
      refreshSettings();
      break;
    case 'nav.started':
      setNavLoading(true);
      break;
    case 'nav.finished':
      setNavLoading(false);
      break;
    case 'capture.captured':
      clearTimeout(captureTimer);
      setCaptureState('success');
      captureTimer = setTimeout(() => setCaptureState('idle'), 1500);
      break;
    case 'capture.failed': {
      const t = activeTab();
      state.lastFailedCapture = { url: (t && t.url) || '', title: (t && t.title) || '' };
      setCaptureState('failed');
      showToast("Couldn't extract this page", {
        tone: 'danger',
        buttons: [
          { label: 'Save visible text', primary: true, onClick: rawSaveFailedCapture },
          { label: 'Dismiss' },
        ],
      });
      break;
    }
    case 'ask.chunk':
      if (adoptAsk(p.askId)) {
        state.ask.text += p.delta || '';
        el['ask-answer'].textContent = state.ask.text;
        scrollAskBottom();
      }
      break;
    case 'ask.done':
      if (adoptAsk(p.askId)) {
        state.ask.text = p.answer != null ? p.answer : state.ask.text;
        state.ask.citations = Array.isArray(p.citations) ? p.citations : [];
        state.ask.dropped = Array.isArray(p.droppedClaims) ? p.droppedClaims : [];
        state.ask.phase = 'done';
        state.ask.askId = null;
        renderAsk();
        renderAnswerFinal();
      }
      break;
    case 'ask.refused':
      if (adoptAsk(p.askId)) {
        state.ask.askId = null;
        showRefusal(p);
      }
      break;
    default:
      break;
  }
}

let pollTimer = null;
let pollBusy = false;

function schedulePoll(delay = 100) {
  clearTimeout(pollTimer);
  pollTimer = setTimeout(pollEvents, delay);
}

async function pollEvents() {
  clearTimeout(pollTimer);
  if (pollBusy) {
    schedulePoll();
    return;
  }
  pollBusy = true;
  try {
    if (document.visibilityState === 'visible') {
      const d = await rpc('events.get', { cursor: state.cursor });
      if (d && Array.isArray(d.events)) {
        if (typeof d.cursor === 'number') state.cursor = d.cursor;
        for (const ev of d.events) handleEvent(ev);
      }
    }
  } finally {
    pollBusy = false;
  }
  schedulePoll();
}

/* ── keyboard shortcuts ─────────────────────────────────────────────── */

function onKeyDown(e) {
  const k = typeof e.key === 'string' ? e.key.toLowerCase() : '';

  if (e.metaKey && e.shiftKey && k === 'b') {
    e.preventDefault();
    toggleRail();
    return;
  }
  if (e.ctrlKey && e.key === 'Tab') {
    e.preventDefault();
    cycleTab(1);
    return;
  }
  if (e.key === 'Escape') {
    if (omni.open) {
      omniClose();
      return;
    }
    if (state.settings.askPanelOpen) {
      toggleAsk(false);
      return;
    }
  }
  if (!(e.metaKey || e.ctrlKey) || e.altKey) return;

  switch (k) {
    case 't':
      e.preventDefault();
      createTab();
      break;
    case 'w':
      e.preventDefault();
      if (state.activeId != null) closeTab(state.activeId);
      break;
    case 'l':
      e.preventDefault();
      el['omnibox'].focus();
      el['omnibox'].select();
      break;
    case 'r':
      e.preventDefault();
      rpc('nav.reload', {});
      break;
    case '[':
      e.preventDefault();
      rpc('nav.back', {});
      break;
    case ']':
      e.preventDefault();
      rpc('nav.forward', {});
      break;
    case 'd':
      e.preventDefault();
      toggleBookmark();
      break;
    case 'e':
      e.preventDefault();
      requestCapture();
      break;
    case 'k':
      e.preventDefault();
      toggleAsk();
      break;
    default:
      if (/^[1-9]$/.test(k)) {
        e.preventDefault();
        selectNthTab(Number(k));
      }
      break;
  }
}

/* ── wiring + boot ──────────────────────────────────────────────────── */

function wireEvents() {
  el['new-tab-btn'].addEventListener('click', createTab);
  el['rail-toggle'].addEventListener('click', toggleRail);
  el['back-btn'].addEventListener('click', () => rpc('nav.back', {}));
  el['fwd-btn'].addEventListener('click', () => rpc('nav.forward', {}));
  el['reload-btn'].addEventListener('click', () => rpc('nav.reload', {}));
  el['capture-btn'].addEventListener('click', requestCapture);
  el['bookmark-btn'].addEventListener('click', toggleBookmark);
  el['ask-toggle'].addEventListener('click', () => toggleAsk());
  el['ask-close'].addEventListener('click', () => toggleAsk(false));
  el['ask-capture-page'].addEventListener('click', requestCapture);
  el['ask-refused-capture'].addEventListener('click', requestCapture);
  el['ask-retry'].addEventListener('click', () => submitAsk(state.lastQuestion));
  el['ask-stop'].addEventListener('click', cancelAsk);
  el['scrim'].addEventListener('click', () => toggleAsk(false));

  el['ask-form'].addEventListener('submit', (e) => {
    e.preventDefault();
    submitAsk(el['ask-input'].value);
    el['ask-input'].value = '';
  });

  el['omnibox'].addEventListener('focus', () => {
    omniOpen();
    el['omnibox'].select();
  });
  el['omnibox'].addEventListener('input', onOmniInput);
  el['omnibox'].addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      omniOpen();
      omniMove(1);
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      omniMove(-1);
    } else if (e.key === 'Enter') {
      e.preventDefault();
      omniSubmitCurrent();
    } else if (e.key === 'Escape') {
      e.preventDefault();
      e.stopPropagation();
      omniClose();
    }
  });

  document.addEventListener('pointerdown', (e) => {
    if (omni.open && !el['omnibox-shell'].contains(e.target)) omniClose();
  });

  tabList.addEventListener('click', (e) => {
    const item = e.target.closest('.tab-item');
    if (item) selectTab(item._tid);
  });
  tabList.addEventListener('keydown', (e) => {
    const horiz = document.body.dataset.orientation === 'horizontal';
    const nextKey = horiz ? 'ArrowRight' : 'ArrowDown';
    const prevKey = horiz ? 'ArrowLeft' : 'ArrowUp';
    const items = [...tabList.querySelectorAll('.tab-item')];
    if (!items.length) return;
    const idx = items.indexOf(document.activeElement);
    if ((e.key === 'Enter' || e.key === ' ') && idx >= 0) {
      e.preventDefault();
      selectTab(items[idx]._tid);
      return;
    }
    let target = -1;
    if (e.key === nextKey) target = idx < 0 ? 0 : Math.min(idx + 1, items.length - 1);
    else if (e.key === prevKey) target = idx < 0 ? items.length - 1 : Math.max(idx - 1, 0);
    else if (e.key === 'Home') target = 0;
    else if (e.key === 'End') target = items.length - 1;
    if (target >= 0) {
      e.preventDefault();
      items[target].focus();
    }
  });

  document.addEventListener('keydown', onKeyDown);

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') schedulePoll(0);
  });

  const mqRail = matchMedia('(max-width: 899px)');
  const applyMq = () => {
    state.autoRail = mqRail.matches;
    applyLayout();
  };
  if (mqRail.addEventListener) mqRail.addEventListener('change', applyMq);
  applyMq();
}

async function boot() {
  cacheDom();
  buildStaticDom();
  wireEvents();
  setCaptureState('idle');
  renderAsk();
  applyLayout();
  await Promise.all([refreshSettings(), refreshTabs()]);
  refreshBookmarks();
  schedulePoll(0);
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', boot);
} else {
  boot();
}

/* ==========================================================================
   Start page (?pane=start) — NTP rendered inside tab content
   ========================================================================== */
(function () {
  'use strict';
  var PANE = document.body.dataset.pane;
  if (PANE !== 'start') return;

  function esc(s){var d=document.createElement('div');d.textContent=s==null?'':String(s);return d.innerHTML;}

  function renderStart() {
    var hole = document.getElementById('content-hole');
    if (!hole) return;
    hole.innerHTML = '<div id="start-page"><h1>Hive</h1>' +
      '<p class="sub">Your browser remembers what you read.</p>' +
      '<div class="card"><h3>Recently captured</h3><div id="sp-captures">' +
      '<p class="warm-empty">Nothing captured yet &mdash; press Cmd+E on any page to capture it, then ask about it with Cmd+K.</p></div></div>' +
      '<div class="card"><h3>Bookmarks</h3><div id="sp-bookmarks"><p class="warm-empty">No bookmarks yet. Cmd+D bookmarks the page you&rsquo;re reading.</p></div></div></div>';
    Promise.all([
      window.hive && window.hive.call('session.restore', {}),
      window.hive && window.hive.call('captures.recent', { limit: 8 }),
      window.hive && window.hive.call('bookmark.list', {})
    ]).then(function (rs) {
      var caps = rs[0] && rs[0].ok ? (rs[0].data.captures || []) : [];
      if (caps.length) {
        var lis = caps.map(function (c) {
          var host = ''; try { host = new URL(c.url).hostname.replace(/^www\./,''); } catch(e){}
          return '<li><a href="#" data-url="' + esc(c.url) + '">' + esc(c.title || c.url) +
                 '</a><span class="host">' + esc(host) + '</span></li>';
        }).join('');
        var box = document.getElementById('sp-captures');
        if (box) box.innerHTML = '<ul>' + lis + '</ul>';
      }
      var bms = rs[1] && rs[1].ok ? (rs[1].data.bookmarks || []) : [];
      if (bms.length) {
        var blis = bms.map(function (b) {
          return '<li><a href="#" data-url="' + esc(b.url) + '">' + esc(b.title || b.url) + '</a><span class="host"></span></li>';
        }).join('');
        var bb = document.getElementById('sp-bookmarks');
        if (bb) bb.innerHTML = '<ul>' + blis + '</ul>';
      }
      hole.addEventListener('click', function (e) {
        var a = e.target.closest && e.target.closest('a[data-url]');
        if (a) { e.preventDefault(); window.hive && window.hive.call('nav.go', { url: a.getAttribute('data-url') }); }
      });
    });
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', function(){ setTimeout(renderStart, 30); });
  else setTimeout(renderStart, 30);
})();
