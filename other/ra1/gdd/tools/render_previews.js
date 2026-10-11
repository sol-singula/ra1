// Screenshot every composed preview HTML page to JPEG with headless Chromium.
// Usage: node render_previews.js <htmlDir> <outDir> [chromiumPath]
const fs = require('fs');
const path = require('path');
const puppeteer = require(process.env.PUPPETEER_MODULE || 'puppeteer');

(async () => {
  const [htmlDir, outDir, exe] = process.argv.slice(2);
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await puppeteer.launch({
    executablePath: exe || process.env.CHROMIUM_PATH,
    args: ['--no-sandbox', '--disable-gpu', '--allow-file-access-from-files', '--font-render-hinting=none'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1920, height: 1080, deviceScaleFactor: 1 });
  const files = fs.readdirSync(htmlDir).filter((f) => f.endsWith('.html')).sort();
  for (const f of files) {
    await page.goto('file://' + path.resolve(htmlDir, f), { waitUntil: 'load' });
    await page.evaluate(async () => { await document.fonts.ready; });
    const out = path.join(outDir, f.replace('.html', '.jpg'));
    await page.screenshot({ path: out, type: 'jpeg', quality: 86 });
    console.log('rendered', out);
  }
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
