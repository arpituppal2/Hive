import { assert, uiSetOmnibox, uiKeydown, uiQuery } from '../lib/util.mjs';

export const meta = { id: '05', name: 'search', timeoutMs: 90_000 };

export async function run(ctx) {
  const set = await ctx.eval(uiSetOmnibox('captured pages about tide'));
  assert(set?.ok, `could not focus/type into omnibox: ${set?.error ?? JSON.stringify(set)}`);

  const containerSel = '[data-testid=omnibox-suggestions]';
  const suggestions = await ctx.poll(
    async () => {
      const count = await ctx.eval(`(() => {
        const c = document.querySelector('${containerSel}');
        if (!c) return -1;
        return c.children.length;
      })()`);
      return typeof count === 'number' && count > 0 ? count : false;
    },
    { timeoutMs: 10000, label: `omnibox-suggestions to render children after typing a query (container selector ${containerSel} missing => -1)` },
  );

  const kindsRaw = await ctx.eval(`(() => {
    const c = document.querySelector('${containerSel}');
    return [...c.children].slice(0, 6).map((row) => ({
      kind: row.getAttribute('kind') ?? row.getAttribute('data-kind') ?? null,
      text: (row.textContent || '').trim().slice(0, 60),
    }));
  })()`);
  assert(Array.isArray(kindsRaw) && kindsRaw.length >= 1, `suggestion rows unreadable: ${JSON.stringify(kindsRaw)}`);
  const missingKind = kindsRaw.filter((r) => !r.kind);
  if (missingKind.length === kindsRaw.length) {
    throw new Error(
      `expected suggestion rows to carry kind attrs ('history'|'capture'|'bookmark'|'url' per BRIDGE-SPEC omnibox.suggest), got none: ${JSON.stringify(kindsRaw)}`,
    );
  }
  await ctx.shot('suggestions-visible');

  await ctx.eval(uiKeydown('Escape', { keyCode: 27 }));
  const cleared = await ctx.poll(
    async () => {
      const state = await ctx.eval(`(() => {
        const c = document.querySelector('${containerSel}');
        if (!c) return { gone: true };
        const visible = !!(c.offsetWidth || c.offsetHeight || c.getClientRects().length);
        return { children: c.children.length, visible };
      })()`);
      return state.gone || !state.visible || state.children === 0 ? state : false;
    },
    { timeoutMs: 5000, label: `suggestions to clear/hide after Escape` },
  );

  await ctx.shot('after-escape');
  console.log(`    [05] saw ${suggestions} suggestion rows, kinds=${JSON.stringify(kindsRaw.map((k) => k.kind))}, cleared=${JSON.stringify(cleared)}`);
}
