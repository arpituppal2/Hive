export const CDP_HOST = '127.0.0.1';
export const CDP_PORT = Number(process.env.HIVE_CDP_PORT ?? 9223);
export const CDP_HTTP = `http://${CDP_HOST}:${CDP_PORT}`;

export async function httpGet(path) {
  const res = await fetch(`${CDP_HTTP}${path}`);
  if (!res.ok) throw new Error(`GET ${path} -> HTTP ${res.status}`);
  return res.json();
}

export async function cdpVersion(timeoutMs = 3000) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(`${CDP_HTTP}/json/version`, { signal: ctrl.signal });
    if (!res.ok) throw new Error(`/json/version -> HTTP ${res.status}`);
    return await res.json();
  } finally {
    clearTimeout(t);
  }
}

export async function getTargets() {
  return httpGet('/json/list');
}

export async function activateTarget(targetId) {
  for (const method of ['PUT', 'GET']) {
    try {
      const res = await fetch(`${CDP_HTTP}/json/activate/${targetId}`, { method });
      if (res.ok) return true;
    } catch {}
  }
  return false;
}

export async function openViaHttp(url) {
  for (const method of ['PUT', 'GET']) {
    try {
      const res = await fetch(`${CDP_HTTP}/json/new?${encodeURIComponent(url)}`, { method });
      if (res.ok) return await res.json();
    } catch {}
  }
  return null;
}

export class CdpSession {
  constructor(ws, label = 'cdp') {
    this.ws = ws;
    this.label = label;
    this.closed = false;
    this.nextId = 1;
    this.pending = new Map();
    this.listeners = new Map();
    ws.addEventListener('message', (ev) => this.#onMessage(ev));
    ws.addEventListener('close', () => this.#onClose());
    ws.addEventListener('error', () => this.#onClose());
  }

  #onMessage(ev) {
    let msg;
    try {
      msg = JSON.parse(typeof ev.data === 'string' ? ev.data : ev.data.toString());
    } catch {
      return;
    }
    if (msg.id !== undefined) {
      const p = this.pending.get(msg.id);
      if (!p) return;
      this.pending.delete(msg.id);
      if (msg.error) p.reject(new Error(`${p.method} failed: ${msg.error.message} (code ${msg.error.code})`));
      else p.resolve(msg.result);
      return;
    }
    const subs = this.listeners.get(msg.method);
    if (subs) for (const fn of [...subs]) fn(msg.params);
  }

  #onClose() {
    if (this.closed) return;
    this.closed = true;
    for (const p of this.pending.values()) p.reject(new Error(`${p.method} aborted: WebSocket closed`));
    this.pending.clear();
    for (const fn of this.closeHandlers) fn();
  }

  closeHandlers = [];

  onClose(fn) {
    this.closeHandlers.push(fn);
  }

  send(method, params = {}) {
    if (this.closed || this.ws.readyState !== 1) {
      return Promise.reject(new Error(`CDP session "${this.label}" is closed (cannot send ${method})`));
    }
    const id = this.nextId++;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject, method });
      try {
        this.ws.send(JSON.stringify({ id, method, params }));
      } catch (err) {
        this.pending.delete(id);
        reject(new Error(`ws.send(${method}) threw: ${err.message}`));
      }
    });
  }

  on(method, fn) {
    if (!this.listeners.has(method)) this.listeners.set(method, []);
    this.listeners.get(method).push(fn);
    return () => {
      const subs = this.listeners.get(method);
      const i = subs.indexOf(fn);
      if (i >= 0) subs.splice(i, 1);
    };
  }

  async once(method, { timeoutMs = 10000, predicate = () => true } = {}) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        off();
        reject(new Error(`timed out after ${timeoutMs}ms waiting for CDP event ${method}`));
      }, timeoutMs);
      const off = this.on(method, (params) => {
        if (!predicate(params)) return;
        clearTimeout(timer);
        off();
        resolve(params);
      });
    });
  }

  async close() {
    this.closed = true;
    try {
      this.ws.close();
    } catch {}
  }
}

export async function connect(wsUrl, label = 'target') {
  if (typeof WebSocket === 'undefined') {
    throw new Error(
      'global WebSocket unavailable in this Node build; expected Node >=22. ' +
        'Refusing to run without it (see scripts/e2e/README note in run.mjs).',
    );
  }
  const ws = new WebSocket(wsUrl);
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`WebSocket connect timed out: ${wsUrl}`)), 10000);
    ws.addEventListener('open', () => {
      clearTimeout(timer);
      resolve();
    }, { once: true });
    ws.addEventListener('error', () => {
      clearTimeout(timer);
      reject(new Error(`WebSocket connect failed: ${wsUrl}`));
    }, { once: true });
  });
  const session = new CdpSession(ws, label);
  await session.send('Runtime.enable');
  await session.send('Page.enable');
  return session;
}

function formatException(details) {
  const d = details.exceptionDetails ?? details;
  const text = d.text ?? 'Unhandled exception in page';
  const desc = d.exception?.description ?? d.exception?.value ?? '';
  return `${text}${desc ? `: ${desc}` : ''}`;
}

export async function evalOn(session, expression) {
  let result;
  try {
    result = await session.send('Runtime.evaluate', {
      expression,
      returnByValue: true,
      awaitPromise: true,
      userGesture: true,
    });
  } catch (err) {
    throw new Error(`Runtime.evaluate transport error: ${err.message}`);
  }
  if (result.exceptionDetails) {
    throw new Error(`Page evaluation failed: ${formatException(result)}`);
  }
  return result.result?.value;
}
