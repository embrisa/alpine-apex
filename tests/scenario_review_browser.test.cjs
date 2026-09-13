/* Isolated browser profile; accepts a generated review and an inspection folder. */
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const {pathToFileURL} = require('node:url');
(async () => {
  const review = path.resolve(process.argv[2]);
  const output = path.resolve(process.argv[3]);
  await fs.mkdir(output, {recursive: true});
  const browser = await chromium.launch({channel: 'msedge', headless: true});
  const context = await browser.newContext({viewport: {width: 1440, height: 1100}});
  try {
    const page = await context.newPage(), errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(pathToFileURL(review).href);
    const data = await page.locator('#evidence').evaluate(el => JSON.parse(el.textContent));
    const [start, end] = data.comparison.coverage.overlap;
    assert.equal(await page.locator('#timeline').inputValue(), String(start));
    if (data.comparison.first_divergence_tick === null) assert(await page.locator('#divergence').isDisabled());
    else {
      await page.locator('#divergence').click();
      assert.equal(await page.locator('#timeline').inputValue(), String(data.comparison.first_divergence_tick));
    }
    for (const side of ['before', 'after']) if (data[side].captures.length && !data[side].captures.some(f => f.missing)) {
      await page.locator(`#${side}-image`).evaluate(img => img.decode());
      assert(await page.locator(`#${side}-image`).evaluate(img => img.naturalWidth > 0));
      assert.match(await page.locator(`#${side}-frame`).textContent(), /Captured tick/);
    }
    await page.locator('#timeline').fill(String(start));
    await page.locator('#next').click();
    assert.equal(await page.locator('#timeline').inputValue(), String(Math.min(start + 1, end)));
    await page.locator('#previous').click();
    assert.equal(await page.locator('#timeline').inputValue(), String(start));
    for (const metric of data.comparison.metrics) {
      await page.locator('#metric').selectOption(metric);
      assert.match(await page.locator('#values').textContent(), /Before .*After .*Δ/);
    }
    const events = page.locator('#events button');
    if (await events.count()) {
      await events.first().click();
      assert.match(await page.locator('#clock').textContent(), /Tick/);
    }
    await page.locator('#timeline').fill(String(start));
    await page.locator('#play').click();
    if (end > start) await page.waitForFunction(s => Number(document.getElementById('timeline').value) > s, start);
    if ((await page.locator('#play').textContent()) === 'Pause') await page.locator('#play').click();
    await page.locator('#timeline').fill(String(Math.min(start + 40, end)));
    if (data.comparison.metrics.includes('speed_mps')) await page.locator('#metric').selectOption('speed_mps');
    await page.screenshot({path: path.join(output, 'review-wide.png'), fullPage: true});
    await page.setViewportSize({width: 720, height: 1000});
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1));
    await page.screenshot({path: path.join(output, 'review-narrow.png'), fullPage: true});
    assert.deepEqual(errors, []);
    const result = {passed: true, coverage: [start, end], metricControls: data.comparison.metrics.length, eventButtons: await events.count(), pageErrors: errors};
    await fs.writeFile(path.join(output, 'browser-validation.json'), JSON.stringify(result, null, 2));
    console.log(JSON.stringify(result));
  } finally { await context.close(); await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
