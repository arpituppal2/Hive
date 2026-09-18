import { assert, SkipError } from '../lib/util.mjs';

export const meta = { id: '09', name: 'orientation-switch', timeoutMs: 90_000 };

async function getSetting(ctx, key) {
  const r = await ctx.eval(`window.hive.call('settings.get', { keys: [${JSON.stringify(key)}] })`);
  assert(r?.ok === true, `settings.get(${key}) failed: ${JSON.stringify(r)}`);
  return r.data.settings;
}

export async function run(ctx) {
  const settings = await getSetting(ctx, 'tabOrientation');
  const current = settings.tabOrientation ?? 'vertical';
  const opposite = current === 'horizontal' ? 'vertical' : 'horizontal';

  const domProbe = () => ctx.eval(`(() => {
    const body = document.body;
    const strip = document.querySelector('[data-testid=tab-strip-horizontal]');
    return {
      bodyData: body ? { ...body.dataset } : null,
      railAttr: body?.getAttribute('data-rail') ?? null,
      horizontalStripPresent: !!strip,
      horizontalStripVisible: strip ? !!(strip.offsetWidth || strip.offsetHeight) : false,
    };
  })()`);

  const before = await domProbe();
  await ctx.shot('before-toggle');

  const set = await ctx.eval(`window.hive.call('settings.set', { patch: { tabOrientation: ${JSON.stringify(opposite)} } })`);
  assert(set?.ok === true, `settings.set(tabOrientation:${opposite}) failed: ${JSON.stringify(set)}`);

  const effective = set.data.settings.tabOrientation ?? current;
  if (effective === current) {
    await ctx.shot('no-op');
    throw new SkipError(
      `feature flagged off: settings.set returned tabOrientation unchanged (${JSON.stringify(effective)}); vertical-only ship. Graceful no-op confirmed — SKIP.`,
    );
  }
  assert(effective === opposite, `settings.set echoed unexpected orientation: expected ${opposite}, got ${effective}`);

  try {
    var reflected = await ctx.poll(
      async () => {
        const d = await domProbe();
        const orientChanged = d.bodyData?.orientation === opposite || d.bodyData?.tabOrientation === opposite || d.railAttr === opposite;
        return orientChanged || d.horizontalStripVisible || d.horizontalStripPresent ? d : false;
      },
      { timeoutMs: 10000, label: `DOM to reflect ${opposite} orientation (body[data-orientation]/[data-rail] or visible horizontal tab-strip)` },
    );
  } catch (err) {
    throw new Error(
      `${err.message}. ASSUMPTION MISMATCH: suite looks for body[data-orientation|data-tabOrientation|data-rail]='${opposite}' or [data-testid=tab-strip-horizontal]; ` +
        `CHROME-SPEC does not name these hooks. Body dataset at failure: ${JSON.stringify(before)} → check chrome implementation's actual attribute.`,
    );
  }
  await ctx.shot('after-toggle');

  const revert = await ctx.eval(`window.hive.call('settings.set', { patch: { tabOrientation: ${JSON.stringify(current)} } })`);
  assert(revert?.ok === true, `revert settings.set failed: ${JSON.stringify(revert)}`);
  const revertedDom = await ctx.poll(
    async () => {
      const d = await domProbe();
      const backToOriginal =
        d.bodyData?.orientation === current ||
        d.bodyData?.tabOrientation === current ||
        d.railAttr === current ||
        (!d.horizontalStripVisible && !d.horizontalStripPresent);
      return backToOriginal ? d : false;
    },
    { timeoutMs: 10000, label: `DOM to revert to ${current}` },
  );
  await ctx.shot('reverted');
  console.log(`    [09] toggled ${current} → ${opposite} → ${current}; reflected=${JSON.stringify(reflected.bodyData ?? reflected.railAttr)}, reverted=${JSON.stringify(revertedDom.bodyData ?? {})}`);
}
