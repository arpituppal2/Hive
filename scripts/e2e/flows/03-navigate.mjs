import { assert, probeUrl, uiSetOmnibox, SkipError } from '../lib/util.mjs';

export const meta = { id: '03', name: 'navigate', timeoutMs: 90_000 };

const TARGET_URL = 'https://example.com';

export async function run(ctx) {
  const reachable = await probeUrl(TARGET_URL);
  if (!reachable) {
    throw new SkipError(
      `network unreachable: probe to ${TARGET_URL} failed; navigation flow requires live network. Skipping (warning) rather than failing.`,
    );
  }

  const set = await ctx.eval(uiSetOmnibox(TARGET_URL, { submit: true }));
  assert(set?.ok, `could not type into omnibox: ${set?.error ?? JSON.stringify(set)}`);

  await ctx.shot('omnibox-submitted');

  const contentTarget = await ctx.pollContentTarget(
    (t) => t.url.startsWith('http') && t.url.includes('example.com'),
    { timeoutMs: 15000, intervalMs: 500, label: `tab content target with url starting http and containing example.com (last seen targets: see artifacts)` },
  );
  assert(contentTarget.url.length > 0, `content target url empty: ${JSON.stringify(contentTarget)}`);

  const tabsData = await ctx.pollTabs(
    (data) => {
      const t = data.tabs.find((x) => x.url.includes('example.com'));
      return t && t.title && t.title.trim().length > 0 ? t : false;
    },
    { timeoutMs: 15000, label: 'tabs.list entry for example.com with non-empty title' },
  );

  await ctx.shot('navigated');
  console.log(`    [03] navigated: title=${JSON.stringify(tabsData.title)} url=${contentTarget.url}`);
}
