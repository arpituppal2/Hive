import { spawn } from 'node:child_process';
import { setTimeout as delay } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';
import { CDP_HTTP, cdpVersion } from './cdp.mjs';

export const sleep = (ms) => delay(ms);

export class SkipError extends Error {
  constructor(message) {
    super(message);
    this.name = 'SkipError';
    this.skipped = true;
  }
}

export function assert(condition, message) {
  if (!condition) throw new Error(message);
}

export function assertEquals(actual, expected, label) {
  if (actual !== expected) {
    throw new Error(`${label}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

export async function poll(fn, { timeoutMs = 10000, intervalMs = 250, label = 'condition', giveUpLastValue = false } = {}) {
  const started = Date.now();
  let lastValue;
  let lastError;
  while (Date.now() - started < timeoutMs) {
    try {
      lastValue = await fn();
      if (lastValue) return lastValue;
    } catch (err) {
      lastError = err;
    }
    await sleep(Math.min(intervalMs, 500));
  }
  const detail = lastError ? ` (last error: ${lastError.message})` : giveUpLastValue && lastValue !== undefined ? ` (last value: ${JSON.stringify(lastValue)})` : '';
  throw new Error(`Timed out after ${timeoutMs}ms waiting for ${label}${detail}`);
}

export const DEFAULT_BIN = new URL('../../../dist/Hive.app/Contents/MacOS/Hive', import.meta.url).pathname;

export function resolveBinPath() {
  return process.env.HIVE_BIN ?? DEFAULT_BIN;
}

export function spawnApp(binPath) {
  const child = spawn(binPath, [], {
    env: { ...process.env, HIVE_DEBUG_CDP: '1' },
    stdio: ['ignore', 'ignore', 'pipe'],
  });
  let stderrTail = '';
  child.stderr.on('data', (chunk) => {
    stderrTail = (stderrTail + chunk.toString()).slice(-2000);
  });
  child.stderrTail = () => stderrTail;
  child.exited = new Promise((resolve) => child.once('exit', (code, sig) => resolve({ code, sig })));
  return child;
}

export async function waitForCdp(timeoutMs = 30000, intervalMs = 300) {
  const started = Date.now();
  let lastErr;
  while (Date.now() - started < timeoutMs) {
    try {
      return await cdpVersion(2000);
    } catch (err) {
      lastErr = err;
      await sleep(intervalMs);
    }
  }
  throw new Error(`CDP endpoint ${CDP_HTTP} did not come up within ${timeoutMs}ms (last error: ${lastErr?.message}). Is the app built with HIVE_DEBUG_CDP support?`);
}

export async function terminateApp(child, graceMs = 4000) {
  if (!child || child.exitCode !== null || child.signalCode !== null) return;
  child.kill('SIGTERM');
  const result = await Promise.race([child.exited, sleep(graceMs).then(() => null)]);
  if (!result) {
    child.kill('SIGKILL');
    await Promise.race([child.exited, sleep(2000)]);
  }
}

export async function probeUrl(url, timeoutMs = 5000) {
  try {
    const ctrl = new AbortController();
    const t = setTimeout(() => ctrl.abort(), timeoutMs);
    try {
      const res = await fetch(url, { signal: ctrl.signal, redirect: 'follow' });
      return res.ok || (res.status >= 300 && res.status < 400);
    } finally {
      clearTimeout(t);
    }
  } catch {
    return false;
  }
}

export function fixtureUrl(name) {
  return fileURLToPath(new URL(`../fixtures/${name}`, import.meta.url));
}

export function fixtureFileUrl(name) {
  const p = fixtureUrl(name);
  return 'file://' + p.split('/').map((seg) => encodeURIComponent(seg)).join('/');
}

export function uiClick(selector) {
  return `(() => {
    const el = document.querySelector(${JSON.stringify(selector)});
    if (!el) return { ok: false, error: 'selector not found: ${selector.replace(/'/g, "\\'")}' };
    el.click();
    return { ok: true };
  })()`;
}

export function uiSetOmnibox(value, { submit = false } = {}) {
  return `(() => {
    const el = document.querySelector('[data-testid=omnibox]') || document.querySelector('#omnibox');
    if (!el) return { ok: false, error: 'omnibox element not found ([data-testid=omnibox] or #omnibox)' };
    el.focus();
    el.value = ${JSON.stringify(value)};
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    if (submit) {
      el.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', keyCode: 13, which: 13, bubbles: true, cancelable: true }));
    }
    return { ok: true, value: el.value };
  })()`;
}

export function uiKeydown(key, { keyCode, target = '[data-testid=omnibox]' } = {}) {
  return `(() => {
    const el = document.querySelector(${JSON.stringify(target)}) || document.activeElement || document.body;
    el.dispatchEvent(new KeyboardEvent('keydown', { key: ${JSON.stringify(key)}, keyCode: ${keyCode ?? 0}, bubbles: true, cancelable: true }));
    return { ok: true };
  })()`;
}

export function uiQuery(selector, props = []) {
  const propList = props.map((p) => JSON.stringify(p)).join(',');
  return `(() => {
    const el = document.querySelector(${JSON.stringify(selector)});
    if (!el) return null;
    const out = { tag: el.tagName.toLowerCase(), text: (el.textContent || '').trim().slice(0, 200), attrs: {} };
    for (const p of [${propList}]) out.attrs[p] = el.getAttribute(p);
    out.dataset = { ...el.dataset };
    out.visible = !!(el.offsetWidth || el.offsetHeight || el.getClientRects().length);
    return out;
  })()`;
}

export function pad(str, width) {
  str = String(str ?? '');
  return str.length > width ? str.slice(0, width - 1) + '…' : str.padEnd(width);
}
