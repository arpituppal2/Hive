#!/usr/bin/env node

import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { connect, evalOn, getTargets } from './lib/cdp.mjs';
import {
  assert,
  pad,
  poll,
  resolveBinPath,
  sleep,
  spawnApp,
  terminateApp,
  waitForCdp,
} from './lib/util.mjs';

import * as flow01 from './flows/01-launch-restore.mjs';
import * as flow02 from './flows/02-new-tab.mjs';
import * as flow03 from './flows/03-navigate.mjs';
import * as flow04 from './flows/04-back-forward.mjs';
import * as flow05 from './flows/05-search.mjs';
import * as flow06 from './flows/06-bookmark.mjs';
import * as flow07 from './flows/07-capture.mjs';
import * as flow08 from './flows/08-ask-citation.mjs';
import * as flow09 from './flows/09-orientation-switch.mjs';

const FLOWS = [flow01, flow02, flow03, flow04, flow05, flow06, flow07, flow08, flow09];

const ROOT = fileURLToPath(new URL('../..', import.meta.url));
const ARTIFACTS = process.env.HIVE_E2E_ARTIFACTS ?? path.join(ROOT, 'artifacts', 'e2e');
const ATTACH = process.env.HIVE_ATTACH === '1';

const state = {
  child: null,
  session: null,
  extraSessions: [],
};

async function findChromeTarget({ timeoutMs = 20000 } = {}) {
  return poll(
    async () => {
      const targets = await getTargets();
      const chrome = targets.find((t) => t.type === 'page' && t.url.startsWith('hive://chrome'));
      if (!chrome) throw new Error(`no hive://chrome target; seen: ${JSON.stringify(targets.map((t) => `${t.type}:${t.url}`))}`);
      return chrome;
    },
    { timeoutMs, intervalMs: 500, label: 'hive://chrome target to appear' },
  );
}

async function attachChrome() {
  const target = await findChromeTarget();
  if (state.session) await state.session.close().catch(() => {});
  state.session = await connect(target.webSocketDebuggerUrl, 'chrome');
  return state.session;
}

async function startApp(binPath) {
  state.child = spawnApp(binPath);
  try {
    await waitForCdp(30000);
  } catch (err) {
    throw new Error(`${err.message}\nstderr tail: ${state.child.stderrTail() || '(empty)'}`);
  }
  await attachChrome();
}

async function quitApp() {
  if (state.session) {
    await state.session.close().catch(() => {});
    state.session = null;
  }
  for (const s of state.extraSessions.splice(0)) await s.close().catch(() => {});
  if (state.child) {
    await terminateApp(state.child);
    state.child = null;
  }
}

function flowDir(meta) {
  return path.join(ARTIFACTS, `${meta.id}-${meta.name}`);
}

async function shoot(meta, name) {
  const dir = flowDir(meta);
  await mkdir(dir, { recursive: true }).catch(() => {});
  const file = path.join(dir, `${name}.png`);
  try {
    const target = (await getTargets()).find((t) => t.url.startsWith('hive://chrome'));
    if (!target) throw new Error('hive://chrome target vanished');
    await fetch(`http://127.0.0.1:9223/json/activate/${target.id}`, { method: 'PUT' }).catch(() => {});
    await sleep(120);
    const session = state.session ?? (await attachChrome());
    const shot = await session.send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: false });
    await writeFile(file, Buffer.from(shot.data, 'base64'));
  } catch (err) {
    console.log(`    [${meta.id}] screenshot ${name} failed (non-fatal): ${err.message}`);
  }
  return file;
}

function makeCtx(meta) {
  return {
    meta,
    cdp: () => {
      assert(state.session && !state.session.closed, 'chrome CDP session is not attached');
      return state.session;
    },
    eval: async (expr) => {
      if (!state.session || state.session.closed) await attachChrome();
      return evalOn(state.session, expr);
    },
    shot: (name) => shoot(meta, name),
    tmpdir: ARTIFACTS,
    targets: () => getTargets(),
    pollTabs: async (predicate, opts = {}) =>
      poll(async () => {
        const r = await evalOn(state.session, `window.hive.call('tabs.list', {})`);
        if (r?.ok !== true) return false;
        return predicate(r.data) ? r.data : false;
      }, { intervalMs: 400, timeoutMs: 10000, label: 'tabs predicate', ...opts }),
    pollContentTarget: async (predicate, opts = {}) =>
      poll(async () => {
        const targets = await getTargets();
        const hit = targets.find((t) => t.type === 'page' && !t.url.startsWith('hive://') && predicate(t));
        return hit ? hit : false;
      }, { intervalMs: 400, timeoutMs: 15000, label: 'content target', ...opts }),
    pickContentTarget: async () => {
      const targets = await getTargets();
      return (
        targets.find((t) => t.type === 'page' && /^https?:/.test(t.url)) ??
        targets.find((t) => t.type === 'page' && t.url.startsWith('hive://start')) ??
        null
      );
    },
    connectTo: async (target) => {
      const s = await connect(target.webSocketDebuggerUrl, `extra:${target.id}`);
      state.extraSessions.push(s);
      return s;
    },
    detachExtra: async () => {
      for (const s of state.extraSessions.splice(0)) await s.close().catch(() => {});
    },
    quitApp,
    startApp: async () => startApp(resolveBinPath()),
  };
}

function withTimeout(runFn, timeoutMs, meta) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(
      () => reject(new Error(`flow ${meta.id}-${meta.name} exceeded its global timeout of ${timeoutMs / 1000}s`)),
      timeoutMs + 2000,
    );
  });
  return Promise.race([runFn(), timeout]).finally(() => clearTimeout(timer));
}

function printTable(rows) {
  console.log('\n=== E2E RESULTS ===');
  console.log(`${pad('FLOW', 8)}${pad('NAME', 20)}${pad('STATUS', 8)}${pad('TIME', 9)}NOTE`);
  console.log('-'.repeat(100));
  for (const r of rows) {
    console.log(`${pad(r.id, 8)}${pad(r.name, 20)}${pad(r.status, 8)}${pad(`${r.ms}ms`, 9)}${r.note.split('\n')[0].slice(0, 60)}`);
  }
  const failed = rows.filter((r) => r.status === 'FAIL');
  const skipped = rows.filter((r) => r.status === 'SKIP');
  console.log('-'.repeat(100));
  console.log(`${rows.filter((r) => r.status === 'PASS').length} pass / ${failed.length} fail / ${skipped.length} skip`);
  if (failed.length || skipped.length) {
    console.log('\nDetails:');
    for (const r of [...failed, ...skipped]) {
      console.log(`\n[${r.status}] ${r.id}-${r.name}: ${r.note}`);
    }
  }
}

async function main() {
  console.log(`Hive v2 e2e — node ${process.version}, artifacts → ${ARTIFACTS}`);

  if (typeof WebSocket === 'undefined') {
    console.error('FATAL: no global WebSocket in this Node build. Suite requires Node >= 22 (found none). Aborting.');
    process.exit(2);
  }

  const binPath = resolveBinPath();
  if (!ATTACH && !existsSync(binPath)) {
    console.error(
      `FATAL: app binary not found at ${binPath}. Build the app first or point HIVE_BIN at it. ` +
        `(Set HIVE_ATTACH=1 to attach to an already-running instance with HIVE_DEBUG_CDP=1 instead.)`,
    );
    process.exit(2);
  }

  mkdirSync(ARTIFACTS, { recursive: true });

  process.on('SIGINT', () => quitApp().finally(() => process.exit(130)));
  process.on('SIGTERM', () => quitApp().finally(() => process.exit(143)));

  try {
    if (ATTACH) {
      console.log('HIVE_ATTACH=1 — attaching to running instance');
      await waitForCdp(10000);
      await attachChrome();
    } else {
      console.log(`launching ${binPath} with HIVE_DEBUG_CDP=1`);
      await startApp(binPath);
    }
  } catch (err) {
    console.error(`FATAL: could not reach app CDP endpoint: ${err.message}`);
    await quitApp();
    process.exit(2);
  }

  const rows = [];
  for (const flow of FLOWS) {
    const { id, name, timeoutMs } = flow.meta;
    const ctx = makeCtx(flow.meta);
    const started = Date.now();
    process.stdout.write(`\n▶ ${id} ${name} …\n`);
    const row = { id, name, status: 'PASS', ms: 0, note: '' };
    try {
      await withTimeout(flow.run(ctx), timeoutMs, flow.meta);
      row.ms = Date.now() - started;
    } catch (err) {
      row.ms = Date.now() - started;
      row.note = err.message;
      row.status = err?.skipped ? 'SKIP' : 'FAIL';
      await shoot(flow.meta, `failure-${row.status.toLowerCase()}`).catch(() => {});
    }
    rows.push(row);
    console.log(`  → ${row.status} (${row.ms}ms)${row.note ? `\n     ${row.note.split('\n')[0]}` : ''}`);
  }

  printTable(rows);

  const failed = rows.some((r) => r.status === 'FAIL');
  writeFileSync(path.join(ARTIFACTS, 'results.json'), JSON.stringify(rows, null, 2));

  await quitApp();
  process.exit(failed ? 1 : 0);
}

main().catch(async (err) => {
  console.error(`FATAL: ${err.stack ?? err.message}`);
  await quitApp();
  process.exit(2);
});
