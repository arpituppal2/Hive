import { assert, uiClick } from '../lib/util.mjs';

export const meta = { id: '02', name: 'new-tab', timeoutMs: 90_000 };

export async function run(ctx) {
  const before = await ctx.pollTabs(() => true, { timeoutMs: 10000, label: 'tabs.list to respond' });
  const beforeIds = new Set(before.tabs.map((t) => t.id));

  const click = await ctx.eval(uiClick('[data-testid=new-tab-btn]'));
  assert(click?.ok, `could not click [data-testid=new-tab-btn]: ${click?.error ?? JSON.stringify(click)}. Selector mismatch between CHROME-SPEC and chrome implementation?`);

  const after = await ctx.pollTabs(
    (data) => data.tabs.length > before.tabs.length && data.tabs,
    { timeoutMs: 10000, label: `tabs.list length to increase beyond ${before.tabs.length}` },
  );

  const created = after.tabs.find((t) => !beforeIds.has(t.id));
  assert(created, `tabs.list grew to ${after.tabs.length} but no new tab id appeared (before ids: ${[...beforeIds].join(',')})`);

  const active = await ctx.pollTabs(
    (data) => data.activeId === created.id && data,
    { timeoutMs: 5000, label: `newly created tab ${created.id} to become activeId` },
  );
  assert(active.activeId === created.id, `expected new tab ${created.id} active, activeId=${active.activeId}`);

  await ctx.shot('new-tab-active');
}
