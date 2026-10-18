// Renders gameplay snapshots (JSON from session.luau) to PNG with headless Chromium + three.js.
// Usage: node render.js <jsonDir> <outDir> --modules <node_modules dir> [--chromium <path>] [--textures <dir>]
// --textures: the PBR texture sets from tools/gameplay/fetch_textures.py (without them, materials are flat).
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
    .replace('TERRAINJS', 'file://' + path.join(__dirname, 'terrain.js'))
    .replace('TEXDIRVALUE', opt('--textures', null) ? 'file://' + path.resolve(opt('--textures')) : '')
    .replace('RENDERER', 'file://' + path.join(__dirname, 'renderer.js'));
  const pagePath = path.join(outDir, '_page.html');
  fs.writeFileSync(pagePath, html);
  const browser = await puppeteer.launch({
    executablePath: opt('--chromium', undefined),
    protocolTimeout: 1800000, // a whole valley of terrain takes a while in software GL
    args: ['--no-sandbox', '--allow-file-access-from-files', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
  });
  const names = JSON.parse(fs.readFileSync(path.join(jsonDir, 'index.json'), 'utf8'));
  const voxelFiles = {};
  for (const name of names) {
    const page = await browser.newPage();
    page.setDefaultTimeout(1800000);
    page.on('pageerror', (e) => console.error(name, 'page error:', e.message));
    page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') console.error(name, m.type() + ':', m.text().slice(0, 400)); });
    const snap = JSON.parse(fs.readFileSync(path.join(jsonDir, name + '.json'), 'utf8'));
    // the terrain's voxels are written once, next to the shots (Capture.save)
    if (snap.terrain && snap.terrain.voxels && snap.terrain.voxels.file) {
      const file = snap.terrain.voxels.file;
      voxelFiles[file] = voxelFiles[file] || JSON.parse(fs.readFileSync(path.join(jsonDir, file), 'utf8'));
      snap.terrain.voxels = voxelFiles[file];
    }
    const vp = snap.viewport || { w: 1920, h: 1080, dpr: 1 };
    await page.setViewport({ width: vp.w, height: vp.h, deviceScaleFactor: vp.dpr || 1 });
    await page.goto('file://' + pagePath, { waitUntil: 'load' });
    await page.evaluate((s) => window.renderSnapshot(s), snap);
    await page.screenshot({ path: path.join(outDir, name + '.png') });
    if (snap.cinematic) {
      // a depth pass for tools/gameplay/thumbs_post.py (depth blur)
      await page.evaluate(() => window.renderDepth());
      await page.screenshot({ path: path.join(outDir, name + '_depth.png') });
    }
    await page.close();
    console.log('rendered', name);
  }
  fs.unlinkSync(pagePath);
  await browser.close();
})().catch((e) => { console.error(e); process.exit(1); });
