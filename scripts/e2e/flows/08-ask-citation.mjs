import { assert, uiClick } from '../lib/util.mjs';

export const meta = { id: '08', name: 'ask-citation', timeoutMs: 120_000 };

export async function run(ctx) {
  const openPanel = await ctx.eval(uiClick('[data-testid=ask-toggle]'));
  assert(openPanel?.ok, `ask panel toggle click failed: ${openPanel?.error ?? JSON.stringify(openPanel)}`);

  await ctx.poll(
    async () => {
      const vis = await ctx.eval(`(() => {
        const p = document.querySelector('[data-testid=ask-panel]');
        if (!p) return false;
        return !!(p.offsetWidth || p.offsetHeight || p.getClientRects().length);
      })()`);
      return vis || false;
    },
    { timeoutMs: 10000, label: '[data-testid=ask-panel] to be visible after toggle' },
  );

  const typed = await ctx.eval(`(() => {
    const input = document.querySelector('[data-testid=ask-input]');
    if (!input) return { ok: false, error: 'selector not found: [data-testid=ask-input]' };
    input.focus();
    input.value = 'What is this page about?';
    input.dispatchEvent(new Event('input', { bubbles: true }));
    return { ok: true };
  })()`);
  assert(typed?.ok, `could not type question into ask input: ${typed?.error ?? JSON.stringify(typed)}`);

  const sent = await ctx.eval(uiClick('[data-testid=ask-send]'));
  assert(sent?.ok, `ask send button click failed: ${sent?.error ?? JSON.stringify(sent)}`);
  await ctx.shot('question-sent');

  const terminal = await ctx.poll(
    async () => {
      const snap = await ctx.eval(`(() => {
        const answer = document.querySelector('[data-testid=ask-answer]');
        const chips = document.querySelectorAll('[data-citation], [data-testid*=citation-chip]');
        const refusedEl = document.querySelector('[data-ask-refused], [data-flavor]');
        const streaming = !!document.querySelector('[data-streaming="true"], [data-state="streaming"]');
        return {
          answerText: answer ? (answer.textContent || '').trim() : null,
          done: answer ? (answer.getAttribute('data-done') ?? answer.dataset.done ?? null) : null,
          chipCount: chips.length,
          refusedFlavor: refusedEl ? (refusedEl.getAttribute('data-flavor') ?? refusedEl.textContent.trim().slice(0, 80)) : null,
          streaming,
        };
      })()`);
      if (!snap) return false;
      if (snap.refusedFlavor) return { kind: 'refused', snap };
      if ((snap.done === 'true' || snap.done === true) && snap.answerText) return { kind: 'done', snap };
      if (snap.chipCount > 0 && snap.answerText && !snap.streaming) return { kind: 'done-implied', snap };
      return false;
    },
    { timeoutMs: meta.timeoutMs - 15_000, intervalMs: 500, label: `ask terminal state (ask.done with citations OR ask.refused) within ${meta.timeoutMs - 15_000}ms` },
  ).catch((err) => {
    throw new Error(
      `${err.message}. Model cold load can take ~60s; also verify a capture exists in-session (flow 07 must run first). ` +
        `No ask.chunk-derived DOM growth or terminal marker appeared.`,
    );
  });

  await ctx.shot(`terminal-${terminal.kind}`);
  if (terminal.kind === 'refused') {
    console.log(`    [08] PASS via ask.refused: flavor=${JSON.stringify(terminal.snap.refusedFlavor)} — plumbing ok, provider declined`);
    assert(String(terminal.snap.refusedFlavor).length > 0, 'refused element present but flavor unreadable');
    return;
  }
  assert(terminal.snap.chipCount > 0, `ask.done observed but zero citation chips rendered (expected [1][2]-style chips per CHROME-SPEC): ${JSON.stringify(terminal.snap).slice(0, 300)}`);
  console.log(`    [08] PASS via ask.done: chips=${terminal.snap.chipCount}, answer=${JSON.stringify(terminal.snap.answerText.slice(0, 120))}`);
}
