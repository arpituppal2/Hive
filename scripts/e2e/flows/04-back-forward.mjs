import { assert, probeUrl, SkipError } from '../lib/util.mjs';

export const meta = { id: '04', name: 'back-forward', timeoutMs: 90_000 };

const URL_A = 'https://example.com';
const URL_B = 'https://www.iana.org';

async function activeUrl(ctx) {
  const data = await ctx.eval(`window.hive.call('tabs.list', {})`);
  assert(data?.ok === true, `tabs.list failed: ${JSON.stringify(data)}`);
  return data.data.tabs.find((t) => t.id === data.data.activeId)?.url ?? '';
}

export async function run(ctx) {
  for (const u of [URL_A, URL_B]) {
    if (!(await probeUrl(u))) {
      throw new SkipError(
        `network unreachable: probe to ${u} failed — back/forward needs two distinct reachable pages. Skipping.`,
      );
    }
  }

  let nav = await ctx.eval(`window.hive.call('nav.go', { url: ${JSON.stringify(URL_A)} })`);
  assert(nav?.ok === true, `nav.go(${URL_A}) failed: ${JSON.stringify(nav)}`);
  await ctx.pollTabs((data) => data.tabs.some((t) => t.url.includes('example.com')), {
    timeoutMs: 15000,
    label: `${URL_A} to load`,
  });

  nav = await ctx.eval(`window.hive.call('nav.go', { url: ${JSON.stringify(URL_B)} })`);
  assert(nav?.ok === true, `nav.go(${URL_B}) failed: ${JSON.stringify(nav)}`);
  await ctx.pollTabs((data) => data.tabs.some((t) => t.url.includes('iana.org')), {
    timeoutMs: 15000,
    label: `${URL_B} to load`,
  });
  await ctx.shot('at-second-page');

  const backClick = await ctx.eval(`(() => {
    const el = document.querySelector('[data-testid=back-btn]');
    if (!el) return { ok: false, error: 'selector not found: [data-testid=back-btn]' };
    el.click();
    return { ok: true };
  })()`);
  assert(backClick?.ok, `back button click failed: ${backClick?.error ?? JSON.stringify(backClick)}`);
  await ctx.pollTabs(
    async () => (await activeUrl(ctx)).includes('example.com'),
    { timeoutMs: 10000, label: `active url to revert to ${URL_A} after back click` },
  );
  await ctx.shot('after-back');

  const fwdClick = await ctx.eval(`(() => {
    const el = document.querySelector('[data-testid=fwd-btn]');
    if (!el) return { ok: false, error: 'selector not found: [data-testid=fwd-btn]' };
    el.click();
    return { ok: true };
  })()`);
  assert(fwdClick?.ok, `forward button click failed: ${fwdClick?.error ?? JSON.stringify(fwdClick)}`);
  await ctx.pollTabs(
    async () => (await activeUrl(ctx)).includes('iana.org'),
    { timeoutMs: 10000, label: `active url to return to ${URL_B} after forward click` },
  );
  await ctx.shot('after-forward');
}
