// Renders gameplay snapshots (JSON from session.luau) to PNG with headless Chromium + three.js.
// Usage: node render.js <jsonDir> <outDir> --modules <node_modules dir> [--chromium <path>]
const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
const opt = (name, dflt) => { const i = args.indexOf(name); return i >= 0 ? args[i + 1] : dflt; };
const [jsonDir, outDir] = args;
const modules = path.resolve(opt('--modules', 'node_modules'));
const puppeteer = require(path.join(modules, 'puppeteer'));

(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const html = fs.readFileSync(path.join(__dirname, 'page.html'), 'utf8')
    .replaceAll('FONTDIR', 'file://' + path.join(modules, '@fontsource'))
    .replace('THREEJS', 'file://' + path.join(modules, 'three/build/three.min.js'))
    .replace('RENDERER', 'file://' + path.join(__dirname, 'renderer.js'));
  const pagePath = path.join(outDir, '_page.html');
  fs.writeFileSync(pagePath, html);
  const browser = await puppeteer.launch({
    executablePath: opt('--chromium', undefined),
    args: ['--no-sandbox', '--allow-file-access-from-files', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
  });
  const names = JSON.parse(fs.readFileSync(path.join(jsonDir, 'index.json'), 'utf8'));
  for (const name of names) {
    const page = await browser.newPage();
    page.on('pageerror', (e) => console.error(name, 'page error:', e.message));
    await page.setViewport({ width: 1920, height: 1080 });
    await page.goto('file://' + pagePath, { waitUntil: 'load' });
    const snap = JSON.parse(fs.readFileSync(path.join(jsonDir, name + '.json'), 'utf8'));
    await page.evaluate((s) => window.renderSnapshot(s), snap);
    await page.screenshot({ path: path.join(outDir, name + '.png') });
    await page.close();
    console.log('rendered', name);
  }
  fs.unlinkSync(pagePath);
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
