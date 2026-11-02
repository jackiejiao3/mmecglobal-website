/* Run with Playwright installed: node deployment/check-gallery.cjs
 * Optional: CHROMIUM_EXECUTABLE_PATH=/path/to/chromium
 * Uses a temporary localhost server; never sends forms or touches production.
 */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..');
const mime = { '.html': 'text/html', '.js': 'application/javascript', '.css': 'text/css',
    '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp', '.woff2': 'font/woff2' };
const server = http.createServer((request, response) => {
    const file = path.resolve(root, '.' + decodeURIComponent(new URL(request.url, 'http://localhost').pathname));
    if (!file.startsWith(root + path.sep)) { response.writeHead(403).end(); return; }
    try {
        const body = fs.readFileSync(file);
        response.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'application/octet-stream' });
        response.end(body);
    } catch (_) { response.writeHead(404).end(); }
});

async function main() {
    await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
    const base = 'http://127.0.0.1:' + server.address().port;
    let browser;
    try {
        browser = await chromium.launch({ headless: true,
            executablePath: process.env.CHROMIUM_EXECUTABLE_PATH || undefined,
            args: ['--no-sandbox', '--disable-gpu'] });
        const results = [];
        for (const mode of ['before', 'after']) {
            for (const width of [1440, 390]) {
                const context = await browser.newContext({ viewport: { width, height: 900 } });
                const page = await context.newPage();
                const errors = [], failed = [], requests = [];
                page.on('pageerror', error => errors.push(error.message));
                page.on('response', response => { if (response.status() >= 400) failed.push(response.url()); });
                page.on('request', request => requests.push(request.url()));
                if (mode === 'before') {
                    for (const file of ['gallery.html', 'js/custom.js']) {
                        const body = execFileSync('git', ['show', (process.env.BASE_REF || 'main') + ':' + file], { cwd: root });
                        await page.route('**/' + file, route => route.fulfill({ body,
                            contentType: mime[path.extname(file)] }));
                    }
                }
                await page.goto(base + '/gallery.html', { waitUntil: 'networkidle' });
                const metrics = await page.evaluate(() => ({
                    imageRequests: performance.getEntriesByType('resource').filter(r => r.initiatorType === 'img').length,
                    resourceBodyBytes: performance.getEntriesByType('resource').reduce((sum, r) => sum + r.encodedBodySize, 0),
                    horizontalOverflow: document.documentElement.scrollWidth > innerWidth
                }));
                if (mode === 'after') {
                    assert.equal(await page.locator('.loading-area').count(), 0);
                    assert.equal(metrics.horizontalOverflow, false);
                    assert(metrics.imageRequests < 80, 'Offscreen thumbnails must remain deferred');
                    assert(!requests.some(url => /%202\.(jpg|png)/i.test(url)), 'Full-size photos must wait for lightbox');
                    await page.locator('a[data-filter=".Fitting1"]').click();
                    await page.waitForFunction(() => jQuery('[data-gallery-grid]').data('isotope').filteredItems.length === 8);
                    await page.waitForTimeout(400);
                    const fitting = page.locator('.masonry-item.Fitting1').first().locator('img').first();
                    await fitting.scrollIntoViewIfNeeded();
                    await fitting.evaluate(image => image.decode());
                    await page.locator('a[data-filter=".Officeyard1"]').click();
                    const card = page.locator('.masonry-item.Officeyard1').first();
                    await card.scrollIntoViewIfNeeded();
                    await card.hover();
                    await page.waitForTimeout(800); // Original flip/overlay transition.
                    await card.locator('.mfp-link i').click();
                    await page.waitForSelector('.mfp-img');
                    assert((await page.locator('.mfp-img').getAttribute('src')).includes('mmne 2.jpg'));
                    await page.locator('.mfp-img').evaluate(image => image.decode());
                    await page.keyboard.press('Escape');
                    await page.locator('a[data-filter="*"]').click();
                    await page.waitForTimeout(400);
                    const last = page.locator('.masonry-item').last().locator('img').first();
                    await last.scrollIntoViewIfNeeded();
                    await last.evaluate(image => image.decode());
                    assert.deepEqual(errors, [], 'No JavaScript errors');
                    assert.deepEqual(failed, [], 'No failed Gallery resource responses');
                }
                results.push({ mode, width, ...metrics, errors, failed });
                await context.close();
            }
        }

        // A stalled first-row image must not block category selection or initial layout.
        const page = await browser.newPage();
        let releaseImage;
        const held = new Promise(resolve => { releaseImage = resolve; });
        await page.route('**/1officeyard-mmne-*.webp', async route => { await held; await route.continue(); });
        try {
            await page.goto(base + '/gallery.html', { waitUntil: 'domcontentloaded' });
            await page.waitForFunction(() => Boolean(jQuery('[data-gallery-grid]').data('isotope')));
            assert.equal(await page.evaluate(() => performance.getEntriesByType('navigation')[0].loadEventEnd), 0);
            await page.locator('a[data-filter=".Fitting1"]').click();
            await page.waitForFunction(() => jQuery('[data-gallery-grid]').data('isotope').filteredItems.length === 8);
        } finally { releaseImage(); }
        await page.waitForLoadState('load');
        await page.close();

        const staticPage = await browser.newPage({ javaScriptEnabled: false, viewport: { width: 390, height: 844 } });
        await staticPage.goto(base + '/gallery.html');
        assert.equal(await staticPage.locator('.loading-area').count(), 0);
        assert.equal(await staticPage.locator('.masonry-item').count(), 102);
        assert((await staticPage.locator('[data-gallery-grid]').boundingBox()).height > 0);
        await staticPage.close();
        console.log(JSON.stringify({ results, checks: ['desktop/mobile filtering, flip and original-image lightbox',
            'scroll loads last thumbnail', 'no full-size image prefetch before opening lightbox',
            'layout/filtering work while first image is stalled', 'content visible without JavaScript'] }, null, 2));
    } finally {
        if (browser) await browser.close();
        await new Promise(resolve => server.close(resolve));
    }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
