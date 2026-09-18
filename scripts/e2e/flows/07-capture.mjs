import { assert, fixtureFileUrl, uiClick } from '../lib/util.mjs';

export const meta = { id: '07', name: 'capture', timeoutMs: 90_000 };

export async function run(ctx) {
  const fileUrl = fixtureFileUrl('page.html');

  let navResult = await ctx.eval(`window.hive.call('nav.go', { url: ${JSON.stringify(fileUrl)} })`);
  let path = 'nav.go';
  if (navResult?.ok !== true) {
    const submit = await ctx.eval(`window.hive.call('omnibox.submit', { text: ${JSON.stringify(fileUrl)} })`);
    path = 'omnibox.submit';
    if (submit?.ok !== true || submit?.data?.action !== 'navigate') {
      const contentTarget = await ctx.pickContentTarget();
      assert(contentTarget, `no tab content target found to navigate directly (nav.go rejected file:// with ${JSON.stringify(navResult)})`);
      const session = await ctx.connectTo(contentTarget);
      await session.send('Page.navigate', { url: fileUrl });
      path = 'direct CDP Page.navigate (app-level nav whitelist rejected file://)';
      await ctx.detachExtra();
    }
  }

  try {
    await ctx.pollContentTarget((t) => t.url.startsWith('file://'), {
      timeoutMs: 10000,
      label: `a tab content target whose url becomes the fixture file:// URL`,
    });
  } catch (err) {
    throw new Error(`${err.message}. Navigation path used: ${path}. If nav.go rejected file:// (${JSON.stringify(navResult)}), BRIDGE-SPEC's http/https whitelist conflicts with the e2e plan — flag to spec owner.`);
  }
  await ctx.shot('fixture-loaded');

  const click = await ctx.eval(uiClick('[data-testid=capture-btn]'));
  assert(click?.ok, `capture button click failed: ${click?.error ?? JSON.stringify(click)}`);

  const outcome = await ctx.poll(
    async () => {
      const state = await ctx.eval(`(() => {
        const btn = document.querySelector('[data-testid=capture-btn]');
        const toast = document.querySelector('[data-testid=capture-toast]');
        return {
          btnState: btn ? (btn.getAttribute('data-state') ?? btn.dataset.state ?? '') : 'MISSING',
          toastText: toast ? (toast.textContent || '').trim().slice(0, 80) : null,
        };
      })()`);
      if (!state) return false;
      if (state.btnState === 'success') return { kind: 'success-dom', state };
      return false;
    },
    { timeoutMs: 10000, intervalMs: 400, label: `[data-testid=capture-btn] data-state="success" (or capture success UI) within 10s` },
  ).catch(async (err) => {
    const failed = await ctx.eval(`(() => {
      const btn = document.querySelector('[data-testid=capture-btn]');
      const toast = document.querySelector('[data-testid=capture-toast],[role=alert]');
      return { btnState: btn?.dataset.state ?? btn?.getAttribute('data-state') ?? null, toast: toast?.textContent?.trim().slice(0, 120) ?? null };
    })()`);
    throw new Error(
      `${err.message}. Last observed capture UI state: ${JSON.stringify(failed)}. ` +
        `If this is {btnState:"failed"}, Readability extraction returned empty on the fixture (see capture.failed event per BRIDGE-SPEC).`,
    );
  });

  await ctx.shot('captured');
  console.log(`    [07] capture ok via ${path}: ${JSON.stringify(outcome.state)}`);
}
