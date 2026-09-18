import { assert } from '../lib/util.mjs';

export const meta = { id: '06', name: 'bookmark', timeoutMs: 90_000 };

const URL_UNDER_TEST = 'https://example.com';

export async function run(ctx) {
  let tabsData = await ctx.eval(`window.hive.call('tabs.list', {})`);
  assert(tabsData?.ok === true, `tabs.list failed: ${JSON.stringify(tabsData)}`);
  const active = tabsData.data.tabs.find((t) => t.id === tabsData.data.activeId);
  if (!active?.url.startsWith('http')) {
    const nav = await ctx.eval(`window.hive.call('nav.go', { url: ${JSON.stringify(URL_UNDER_TEST)} })`);
    assert(nav?.ok === true, `no http tab to bookmark and nav.go(${URL_UNDER_TEST}) failed: ${JSON.stringify(nav)}`);
    await ctx.pollTabs(
      (data) => data.tabs.some((t) => t.url.includes('example.com')),
      { timeoutMs: 15000, label: `${URL_UNDER_TEST} to load before bookmarking` },
    );
    tabsData = await ctx.eval(`window.hive.call('tabs.list', {})`);
  }
  const targetUrl = tabsData.data.tabs.find((t) => t.id === tabsData.data.activeId)?.url ?? URL_UNDER_TEST;

  const click = await ctx.eval(`(() => {
    const el = document.querySelector('[data-testid=bookmark-btn]');
    if (!el) return { ok: false, error: 'selector not found: [data-testid=bookmark-btn] (Cmd+D path not used by suite)' };
    el.click();
    return { ok: true };
  })()`);
  assert(click?.ok, `bookmark button click failed: ${click?.error ?? JSON.stringify(click)}`);

  const btnState = await ctx.poll(
    async () => {
      const state = await ctx.eval(`(() => {
        const el = document.querySelector('[data-testid=bookmark-btn]');
        if (!el) return null;
        return { bookmarked: el.getAttribute('data-bookmarked') ?? el.dataset.bookmarked ?? null };
      })()`);
      return state?.bookmarked === 'true' || state?.bookmarked === true ? state : false;
    },
    { timeoutMs: 10000, label: `[data-testid=bookmark-btn] data-bookmarked="true" after click` },
  );
  await ctx.shot('bookmarked');

  const listContains = async () => {
    const r = await ctx.eval(`window.hive.call('bookmark.list', {})`);
    assert(r?.ok === true, `bookmark.list RPC failed: ${JSON.stringify(r)}`);
    return r.data.bookmarks.some((b) => b.url === targetUrl || targetUrl.includes(b.url));
  };
  assert(await listContains(), `bookmark.add UI clicked but bookmark.list does not contain ${targetUrl}`);

  await new Promise((r) => setTimeout(r, 500));
  assert(await listContains(), `bookmark for ${targetUrl} disappeared on refetch — persistence broken`);
}
