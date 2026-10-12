/* Draws one gameplay snapshot (tools/gameplay/Capture.luau) in the browser:
 * the 3D world with three.js, then billboards, proximity prompts and ScreenGuis as DOM overlays that follow
 * Roblox's layout rules (UDim2, AnchorPoint, UIListLayout, UIGridLayout, UIPadding, UICorner, UIStroke).
 * It is a stand-in for Roblox's renderer, so lighting and materials only approximate Studio. */
(function () {
  // page size in CSS pixels (a phone is rendered at its point size with a high device pixel ratio)
  let W = 1920, H = 1080, INSET = 58; // Roblox top bar inset for ScreenGuis (IgnoreGuiInset = false)
  THREE.ColorManagement.legacyMode = false; // hex colours are sRGB, like Roblox's Color3

  // ---------- 3D ----------
  // light grey noise (multiplied with the part colour) so concrete, grass and wood read as materials
  function noiseCanvas(spread, size, lines) {
    const c = document.createElement('canvas');
    c.width = c.height = size;
    const g = c.getContext('2d');
    const img = g.createImageData(size, size);
    for (let i = 0; i < img.data.length; i += 4) {
      const n = Math.max(0, Math.min(255, 228 + (Math.random() - 0.5) * spread));
      img.data[i] = img.data[i + 1] = img.data[i + 2] = n;
      img.data[i + 3] = 255;
    }
    g.putImageData(img, 0, 0);
    if (lines) {
      g.strokeStyle = 'rgba(60,40,20,0.28)';
      g.lineWidth = 2;
      for (let y = 0; y < size; y += size / lines) {
        g.beginPath(); g.moveTo(0, y); g.lineTo(size, y); g.stroke();
      }
    }
    return c;
  }
  const texCache = {};
  const TEXTURES = {
    Grass: [70, 0], Concrete: [36, 0], Asphalt: [55, 0], Marble: [14, 0], Wood: [26, 6], WoodPlanks: [20, 4],
  };
  function textureFor(mat) {
    const spec = TEXTURES[mat];
    if (!spec) return null;
    if (!texCache[mat]) texCache[mat] = noiseCanvas(spec[0], 128, spec[1]);
    return texCache[mat];
  }
  function material(p) {
    const color = new THREE.Color(p.c);
    const opts = { color, roughness: p.mat === 'Plastic' ? 0.42 : 0.55, metalness: 0.0 };
    if (p.mat === 'Metal') { opts.metalness = 0.35; opts.roughness = 0.35; }
    if (p.mat === 'Neon') return new THREE.MeshBasicMaterial({ color: color.clone().multiplyScalar(1.35) });
    const canvas = textureFor(p.mat);
    if (canvas) {
      const t = new THREE.CanvasTexture(canvas);
      t.wrapS = t.wrapT = THREE.RepeatWrapping;
      const big = Math.max(p.size[0], p.size[2]);
      t.repeat.set(Math.max(1, big / 10), Math.max(1, big / 10));
      opts.map = t;
    }
    if (p.t > 0) { opts.transparent = true; opts.opacity = 1 - p.t; }
    return new THREE.MeshStandardMaterial(opts);
  }
  // Roblox's stud surface: a grid of round bumps, one per stud, lit from the top left
  let studCanvas = null;
  function studTexture(sx, sz) {
    if (!studCanvas) {
      const n = 64, c = document.createElement('canvas');
      c.width = c.height = n;
      const g = c.getContext('2d');
      g.fillStyle = 'rgb(226,226,226)'; g.fillRect(0, 0, n, n);
      const r = n * 0.32;
      g.fillStyle = 'rgba(0,0,0,0.38)'; g.beginPath(); g.arc(n / 2 + 4, n / 2 + 5, r, 0, Math.PI * 2); g.fill();
      const grad = g.createRadialGradient(n / 2 - r * 0.35, n / 2 - r * 0.35, r * 0.1, n / 2, n / 2, r);
      grad.addColorStop(0, 'rgb(255,255,255)'); grad.addColorStop(0.7, 'rgb(240,240,240)'); grad.addColorStop(1, 'rgb(205,205,205)');
      g.fillStyle = grad; g.beginPath(); g.arc(n / 2, n / 2, r, 0, Math.PI * 2); g.fill();
      g.strokeStyle = 'rgba(0,0,0,0.2)'; g.lineWidth = 2; g.stroke();
      studCanvas = c;
    }
    const t = new THREE.CanvasTexture(studCanvas);
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.repeat.set(Math.max(1, Math.round(sx)), Math.max(1, Math.round(sz)));
    t.anisotropy = 8;
    return t;
  }

  function wedgeGeometry(x, y, z) {
    const a = x / 2, b = y / 2, c = z / 2;
    const v = [
      // bottom
      -a, -b, -c, a, -b, -c, a, -b, c, -a, -b, -c, a, -b, c, -a, -b, c,
      // back (vertical, +Z)
      -a, -b, c, a, -b, c, a, b, c, -a, -b, c, a, b, c, -a, b, c,
      // slope (front-bottom edge up to back-top edge)
      -a, -b, -c, -a, b, c, a, b, c, -a, -b, -c, a, b, c, a, -b, -c,
      // sides
      -a, -b, -c, -a, -b, c, -a, b, c,
      a, -b, -c, a, b, c, a, -b, c,
    ];
    const g = new THREE.BufferGeometry();
    g.setAttribute('position', new THREE.Float32BufferAttribute(v, 3));
    g.computeVertexNormals();
    return g;
  }
  function geometry(p) {
    const [x, y, z] = p.size;
    if (p.s === 'Ball') return new THREE.SphereGeometry(x / 2, 28, 20);
    if (p.s === 'Ellipsoid') { const g = new THREE.SphereGeometry(0.5, 28, 20); g.scale(x, y, z); return g; }
    if (p.s === 'Cylinder') {
      const g = new THREE.CylinderGeometry(Math.min(y, z) / 2, Math.min(y, z) / 2, x, 28);
      g.rotateZ(Math.PI / 2); // Roblox cylinders run along X
      return g;
    }
    if (p.s === 'Wedge') return wedgeGeometry(x, y, z);
    return new THREE.BoxGeometry(x, y, z);
  }
  // face of a box in three.js material order (+X, -X, +Y, -Y, +Z, -Z) and its width/height in studs
  const FACES = { Right: [0, 2, 1], Left: [1, 2, 1], Top: [2, 0, 2], Bottom: [3, 0, 2], Back: [4, 0, 1], Front: [5, 0, 1] };
  function signTexture(sign, part) {
    const f = FACES[sign.face] || FACES.Front;
    const c = document.createElement('canvas');
    const aspect = part.size[f[1]] / part.size[f[2]];
    c.height = 300; c.width = Math.round(300 * aspect);
    const g = c.getContext('2d');
    g.fillStyle = part.c; g.fillRect(0, 0, c.width, c.height);
    g.fillStyle = sign.color;
    const family = sign.font === 'LuckiestGuy' ? '"Luckiest Guy"' : '"Fredoka"';
    const weight = sign.font === 'LuckiestGuy' ? '' : '600 ';
    const lines = String(sign.text || '').split('\n');
    let fs = 220;
    const fits = () => {
      g.font = `${weight}${fs}px ${family}`;
      const widest = Math.max(...lines.map((l) => g.measureText(l).width));
      return widest <= c.width * 0.9 && fs * 1.15 * lines.length <= c.height * 0.92;
    };
    while (!fits() && fs > 8) fs -= 2;
    const left = sign.align === 'Left';
    g.textAlign = left ? 'left' : 'center';
    g.textBaseline = 'middle';
    const total = fs * 1.15 * lines.length;
    lines.forEach((l, i) => g.fillText(l, left ? c.width * 0.06 : c.width / 2, c.height / 2 - total / 2 + fs * 1.15 * (i + 0.5)));
    const t = new THREE.CanvasTexture(c);
    t.encoding = THREE.sRGBEncoding;
    return { texture: t, index: f[0] };
  }
  function skyTexture() {
    const c = document.createElement('canvas');
    c.width = 2; c.height = 512;
    const g = c.getContext('2d');
    const grad = g.createLinearGradient(0, 0, 0, 512);
    grad.addColorStop(0, '#4f8fe8'); grad.addColorStop(0.55, '#9cc8f5'); grad.addColorStop(1, '#dcefff');
    g.fillStyle = grad; g.fillRect(0, 0, 2, 512);
    const t = new THREE.CanvasTexture(c);
    t.encoding = THREE.sRGBEncoding;
    return t;
  }

  function render3D(snap) {
    const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
    renderer.setPixelRatio(window.devicePixelRatio || 1);
    renderer.setSize(W, H);
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFSoftShadowMap;
    renderer.outputEncoding = THREE.sRGBEncoding;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 0.95;
    document.getElementById('world').appendChild(renderer.domElement);

    const scene = new THREE.Scene();
    scene.background = skyTexture();
    scene.fog = new THREE.Fog(0xcfe4fb, 260, 1100);
    scene.add(new THREE.HemisphereLight(0xd8ecff, 0x7a7466, 0.75));
    const cam = snap.camera;
    const target = new THREE.Vector3(...cam.target);
    const sun = new THREE.DirectionalLight(0xfff1d6, 1.9);
    sun.position.copy(target).add(new THREE.Vector3(60, 110, -45));
    sun.target.position.copy(target);
    sun.castShadow = true;
    sun.shadow.mapSize.set(4096, 4096);
    const s = 110;
    Object.assign(sun.shadow.camera, { left: -s, right: s, top: s, bottom: -s, near: 1, far: 400 });
    sun.shadow.bias = -0.0004;
    sun.shadow.normalBias = 0.02;
    scene.add(sun, sun.target);

    const m4 = new THREE.Matrix4();
    snap.parts.forEach((p, i) => {
      let mat = material(p);
      const sign = snap.signs.find((sg) => sg.part === i + 1);
      if (sign && p.s === 'Block') {
        const st = signTexture(sign, p);
        const face = new THREE.MeshStandardMaterial({ map: st.texture, roughness: 0.6 });
        const mats = [mat, mat, mat, mat, mat, mat];
        mats[st.index] = face;
        mat = mats;
      }
      if (p.studs && p.s === 'Block' && !Array.isArray(mat)) {
        const top = new THREE.MeshStandardMaterial({ color: new THREE.Color(p.c), map: studTexture(p.size[0], p.size[2]), roughness: 0.45 });
        if (p.t > 0) { top.transparent = true; top.opacity = 1 - p.t; }
        mat = [mat, mat, top, mat, mat, mat];
      }
      const mesh = new THREE.Mesh(geometry(p), mat);
      const m = p.m;
      m4.set(m[3], m[4], m[5], m[0], m[6], m[7], m[8], m[1], m[9], m[10], m[11], m[2], 0, 0, 0, 1);
      mesh.matrixAutoUpdate = false;
      mesh.matrix.copy(m4);
      const flat = p.size[1] < 0.6 && (p.size[0] > 30 || p.size[2] > 30);
      mesh.castShadow = !flat && p.t < 0.5;
      mesh.receiveShadow = true;
      scene.add(mesh);
    });
    // fire effect on burning stations
    snap.fires.forEach((f) => {
      const group = new THREE.Group();
      group.position.set(...f.pos);
      const colors = [0xff3b1f, 0xff8a1f, 0xffd23f];
      for (let i = 0; i < 18; i++) {
        const h = 1.5 + Math.random() * 3.5;
        const cone = new THREE.Mesh(new THREE.ConeGeometry(0.35 + Math.random() * 0.5, h, 8),
          new THREE.MeshBasicMaterial({ color: colors[i % 3], transparent: true, opacity: 0.75, depthWrite: false }));
        cone.position.set((Math.random() - 0.5) * 4, h / 2, (Math.random() - 0.5) * 2.5);
        group.add(cone);
      }
      const light = new THREE.PointLight(0xff7a2a, 2.2, 22);
      light.position.y = 2;
      group.add(light);
      scene.add(group);
    });

    const camera = new THREE.PerspectiveCamera(cam.fov || 70, W / H, 0.1, 3000);
    camera.position.set(...cam.pos);
    camera.lookAt(target);
    camera.updateMatrixWorld();
    renderer.render(scene, camera);
    return camera;
  }

  // ---------- GUI ----------
  const FONTS = {
    FredokaOne: '"Fredoka", "Noto Color Emoji", sans-serif',
    LuckiestGuy: '"Luckiest Guy", "Noto Color Emoji", sans-serif',
  };
  const DEFAULTS = {
    Frame: { Size: [0, 100, 0, 100], BackgroundColor3: '#a3a2a5' },
    ScrollingFrame: { Size: [0, 100, 0, 100], BackgroundColor3: '#a3a2a5' },
    TextLabel: { Size: [0, 200, 0, 50], BackgroundColor3: '#ffffff', Text: 'Label', TextColor3: '#000000', TextSize: 14 },
    TextButton: { Size: [0, 200, 0, 50], BackgroundColor3: '#ffffff', Text: 'Button', TextColor3: '#000000', TextSize: 14 },
  };
  function rgba(hex, transparency) {
    const c = new THREE.Color(hex);
    return `rgba(${Math.round(c.r * 255)},${Math.round(c.g * 255)},${Math.round(c.b * 255)},${1 - (transparency || 0)})`;
  }
  const calc = (scale, offset) => `calc(${scale * 100}% + ${offset}px)`;
  const ALIGN = { Left: 'flex-start', Top: 'flex-start', Center: 'center', Right: 'flex-end', Bottom: 'flex-end' };

  function buildNode(node, parentEl, inLayout, inAutoParent) {
    const props = Object.assign({}, DEFAULTS[node.cls] || {}, node.props || {});
    if (props.Visible === false) return;
    const el = document.createElement('div');
    el.className = 'gui ' + node.cls;
    const size = props.Size || [0, 0, 0, 0];
    const pos = props.Position || [0, 0, 0, 0];
    const anchor = props.AnchorPoint || [0, 0];
    const auto = props.AutomaticSize || 'None';
    const flow = inLayout || inAutoParent;
    el.style.position = flow ? 'relative' : 'absolute';
    if (!flow) {
      el.style.left = calc(pos[0], pos[1]);
      el.style.top = calc(pos[2], pos[3]);
      el.style.transform = `translate(${-anchor[0] * 100}%, ${-anchor[1] * 100}%)`;
    }
    el.style.flexShrink = '0';
    const w = calc(size[0], size[1]), h = calc(size[2], size[3]);
    if (auto === 'X' || auto === 'XY') { el.style.width = 'max-content'; el.style.minWidth = w; } else el.style.width = w;
    if (auto === 'Y' || auto === 'XY') { el.style.height = 'auto'; el.style.minHeight = h; } else el.style.height = h;
    const bgT = props.BackgroundTransparency ?? 0;
    const modsG = node.mods || {};
    if (bgT < 1 && props.BackgroundColor3) {
      if (modsG.UIGradient && modsG.UIGradient.Color) {
        // Roblox multiplies the background colour by the gradient
        const base = new THREE.Color(props.BackgroundColor3);
        const stops = modsG.UIGradient.Color.map(([t, c]) => {
          const g = new THREE.Color(c);
          const m = new THREE.Color(base.r * g.r, base.g * g.g, base.b * g.b);
          return `${rgba('#' + m.getHexString(), bgT)} ${t * 100}%`;
        });
        el.style.background = `linear-gradient(${(modsG.UIGradient.Rotation || 0) + 90}deg, ${stops.join(', ')})`;
      } else {
        el.style.background = rgba(props.BackgroundColor3, bgT);
      }
    }
    if (props.ZIndex) el.style.zIndex = props.ZIndex;
    if (props.ClipsDescendants) el.style.overflow = 'hidden';
    const mods = node.mods || {};
    if (mods.UICorner) {
      const r = mods.UICorner.CornerRadius || [0, 8];
      el.style.borderRadius = r[0] > 0 ? `${r[0] * 100}%` : `${r[1]}px`;
    }
    if (mods.UIStroke) {
      const st = mods.UIStroke;
      el.style.boxShadow = `0 0 0 ${st.Thickness ?? 1}px ${rgba(st.Color || '#000000', st.Transparency || 0)}`;
    }
    // text
    if (node.cls === 'TextLabel' || node.cls === 'TextButton') {
      const span = document.createElement('span');
      span.className = 'txt';
      span.textContent = props.Text ?? '';
      const fam = FONTS[props.Font] || '"Fredoka", "Noto Color Emoji", sans-serif';
      el.style.fontFamily = fam;
      el.style.fontWeight = props.Font === 'FredokaOne' ? '600' : '400';
      el.style.fontSize = `${props.TextSize || 14}px`;
      el.style.color = rgba(props.TextColor3 || '#000000', props.TextTransparency || 0);
      el.style.display = 'flex';
      el.style.justifyContent = ALIGN[props.TextXAlignment || 'Center'];
      el.style.alignItems = ALIGN[props.TextYAlignment || 'Center'];
      el.style.textAlign = (props.TextXAlignment || 'Center').toLowerCase();
      el.style.whiteSpace = props.TextWrapped ? 'pre-wrap' : 'pre';
      el.style.lineHeight = '1.05';
      if (props.TextTruncate === 'AtEnd') { span.style.overflow = 'hidden'; span.style.textOverflow = 'ellipsis'; span.style.maxWidth = '100%'; }
      const ts = (node.mods || {}).TextStroke;
      if (ts) {
        const w = ts.Thickness || 1, sc = rgba(ts.Color || '#000000', ts.Transparency || 0), parts = [];
        for (let a = 0; a < 16; a++) {
          const ang = a / 16 * Math.PI * 2;
          parts.push(`${(Math.cos(ang) * w).toFixed(2)}px ${(Math.sin(ang) * w).toFixed(2)}px 0 ${sc}`);
        }
        parts.push(`0 ${(w * 0.9).toFixed(2)}px 0 ${sc}`);
        span.style.textShadow = parts.join(', ');
      } else if ((props.TextStrokeTransparency ?? 1) < 1) {
        const sc = rgba(props.TextStrokeColor3 || '#000000', props.TextStrokeTransparency);
        span.style.textShadow = `1.5px 0 ${sc}, -1.5px 0 ${sc}, 0 1.5px ${sc}, 0 -1.5px ${sc}`;
      }
      if (props.TextScaled) el.dataset.scaled = '1';
      el.appendChild(span);
    }
    // children container honours UIPadding and layouts
    const content = document.createElement('div');
    content.className = 'content';
    const pad = mods.UIPadding || {};
    const pv = (u) => (u ? u[1] : 0);
    content.style.position = 'absolute';
    content.style.left = pv(pad.PaddingLeft) + 'px';
    content.style.right = pv(pad.PaddingRight) + 'px';
    content.style.top = pv(pad.PaddingTop) + 'px';
    content.style.bottom = pv(pad.PaddingBottom) + 'px';
    let layout = false;
    if (mods.UIListLayout) {
      const L = mods.UIListLayout;
      const horizontal = L.FillDirection === 'Horizontal';
      content.style.display = 'flex';
      content.style.flexDirection = horizontal ? 'row' : 'column';
      content.style.gap = `${(L.Padding || [0, 0])[1]}px`;
      const hA = ALIGN[L.HorizontalAlignment || 'Left'], vA = ALIGN[L.VerticalAlignment || 'Top'];
      content.style.justifyContent = horizontal ? hA : vA;
      content.style.alignItems = horizontal ? vA : hA;
      layout = true;
    } else if (mods.UIGridLayout) {
      const G = mods.UIGridLayout;
      const cell = G.CellSize || [0, 100, 0, 100], gap = G.CellPadding || [0, 5, 0, 5];
      content.style.display = 'grid';
      content.style.gridTemplateColumns = `repeat(auto-fill, ${cell[1]}px)`;
      content.style.gridAutoRows = `${cell[3]}px`;
      content.style.columnGap = `${gap[1]}px`;
      content.style.rowGap = `${gap[3]}px`;
      if (G.HorizontalAlignment === 'Center') content.style.justifyContent = 'center';
      layout = 'grid';
    }
    // auto-sized containers with a layout grow with their content
    if (auto !== 'None') { content.style.position = 'relative'; content.style.left = content.style.top = '0'; content.style.padding = `${pv(pad.PaddingTop)}px ${pv(pad.PaddingRight)}px ${pv(pad.PaddingBottom)}px ${pv(pad.PaddingLeft)}px`; }
    const kids = (node.children || []).slice();
    if (layout) kids.sort((a, b) => ((a.props || {}).LayoutOrder || 0) - ((b.props || {}).LayoutOrder || 0));
    kids.forEach((k) => {
      if (layout === 'grid') {
        const G = mods.UIGridLayout, cell = G.CellSize || [0, 100, 0, 100];
        k = Object.assign({}, k, { props: Object.assign({}, k.props, { Size: [0, cell[1], 0, cell[3]] }) });
      }
      buildNode(k, content, !!layout, auto !== 'None' && !layout);
    });
    if (kids.length) el.appendChild(content);
    parentEl.appendChild(el);
  }

  function buildRoot(tree, parentEl) {
    const mods = tree.mods || {};
    (tree.children || []).forEach((k) => buildNode(k, parentEl, false));
    return mods;
  }

  function fitScaledText(root) {
    root.querySelectorAll('[data-scaled="1"]').forEach((el) => {
      const span = el.querySelector('.txt');
      if (!span || !span.textContent) return;
      let lo = 4, hi = 100;
      const boxW = el.clientWidth, boxH = el.clientHeight;
      if (!boxW || !boxH) return;
      while (hi - lo > 0.5) {
        const mid = (lo + hi) / 2;
        el.style.fontSize = mid + 'px';
        if (span.scrollWidth <= boxW + 0.5 && span.scrollHeight <= boxH + 0.5 && span.offsetWidth <= boxW + 0.5 && span.offsetHeight <= boxH + 0.5) lo = mid; else hi = mid;
      }
      el.style.fontSize = lo + 'px';
    });
  }

  function project(camera, v) {
    const p = new THREE.Vector3(...v).project(camera);
    return { x: (p.x + 1) / 2 * W, y: (1 - p.y) / 2 * H, behind: p.z > 1 };
  }

  function renderBillboards(snap, camera, layer) {
    const camPos = camera.position;
    const right = new THREE.Vector3(), up = new THREE.Vector3(), back = new THREE.Vector3();
    camera.matrixWorld.extractBasis(right, up, back);
    const items = snap.billboards.map((b) => {
      const base = new THREE.Vector3(...b.pos);
      const world = base.clone().addScaledVector(right, b.offset[0]).addScaledVector(up, b.offset[1]).addScaledVector(back, b.offset[2]);
      return { b, world, dist: world.distanceTo(camPos) };
    }).filter((it) => it.dist <= it.b.maxDistance).sort((a, b) => b.dist - a.dist);
    items.forEach(({ b, world }) => {
      const p = project(camera, world.toArray());
      if (p.behind) return;
      const raw = b.size || [0, 100, 0, 50];
      // Scale parts of a BillboardGui size are studs: convert at this distance
      const dist = world.distanceTo(camPos);
      const pxPerStud = H / (2 * dist * Math.tan((camera.fov * Math.PI / 180) / 2));
      const size = [0, raw[0] * pxPerStud + raw[1], 0, raw[2] * pxPerStud + raw[3]];
      if (size[1] < 4 || size[3] < 3) return;
      const div = document.createElement('div');
      div.className = 'billboard';
      Object.assign(div.style, { position: 'absolute', left: `${p.x - size[1] / 2}px`, top: `${p.y - size[3] / 2}px`, width: `${size[1]}px`, height: `${size[3]}px` });
      buildRoot(b.tree, div);
      layer.appendChild(div);
    });
  }

  // ---------- SurfaceGuis (leaderboards): a DOM canvas mapped onto the part face with a projective transform
  function adj(m) {
    return [m[4] * m[8] - m[5] * m[7], m[2] * m[7] - m[1] * m[8], m[1] * m[5] - m[2] * m[4],
      m[5] * m[6] - m[3] * m[8], m[0] * m[8] - m[2] * m[6], m[2] * m[3] - m[0] * m[5],
      m[3] * m[7] - m[4] * m[6], m[1] * m[6] - m[0] * m[7], m[0] * m[4] - m[1] * m[3]];
  }
  function multmm(a, b) {
    const c = Array(9);
    for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) {
      let v = 0;
      for (let k = 0; k < 3; k++) v += a[3 * i + k] * b[3 * k + j];
      c[3 * i + j] = v;
    }
    return c;
  }
  function multmv(m, v) {
    return [m[0] * v[0] + m[1] * v[1] + m[2] * v[2], m[3] * v[0] + m[4] * v[1] + m[5] * v[2], m[6] * v[0] + m[7] * v[1] + m[8] * v[2]];
  }
  function basisToPoints(p) {
    const m = [p[0], p[2], p[4], p[1], p[3], p[5], 1, 1, 1];
    const v = multmv(adj(m), [p[6], p[7], 1]);
    return multmm(m, [v[0], 0, 0, 0, v[1], 0, 0, 0, v[2]]);
  }
  function projection(src, dst) {
    const t = multmm(basisToPoints(dst), adj(basisToPoints(src)));
    for (let i = 0; i < 9; i++) t[i] /= t[8];
    return [t[0], t[3], 0, t[6], t[1], t[4], 0, t[7], 0, 0, 1, 0, t[2], t[5], 0, t[8]];
  }
  function renderSurfaces(snap, camera, layer) {
    (snap.surfaces || []).forEach((sf) => {
      const toCam = new THREE.Vector3(...camera.position.toArray()).sub(new THREE.Vector3(...sf.center));
      if (toCam.dot(new THREE.Vector3(...sf.normal)) <= 0) return; // facing away
      const pts = sf.corners.map((c) => project(camera, c));
      if (pts.some((p) => p.behind)) return;
      const [w, h] = sf.canvas;
      const div = document.createElement('div');
      div.className = 'surface';
      Object.assign(div.style, { position: 'absolute', left: '0', top: '0', width: w + 'px', height: h + 'px', transformOrigin: '0 0' });
      const m = projection([0, 0, w, 0, 0, h, w, h], [pts[0].x, pts[0].y, pts[1].x, pts[1].y, pts[2].x, pts[2].y, pts[3].x, pts[3].y]);
      div.style.transform = `matrix3d(${m.join(',')})`;
      buildRoot(sf.tree, div);
      layer.appendChild(div);
    });
  }

  function renderPrompts(snap, camera, layer) {
    snap.prompts.forEach((pr) => {
      const p = project(camera, pr.pos);
      if (p.behind) return;
      const div = document.createElement('div');
      div.className = 'prompt';
      div.style.left = p.x + 'px';
      div.style.top = p.y + 'px';
      div.innerHTML = `<div class="key${pr.hold ? ' hold' : ''}">${pr.key === 'E' || pr.key === 'F' || pr.key === 'R' ? pr.key : 'E'}</div>
        <div class="labels"><div class="obj"></div><div class="act"></div></div>`;
      div.querySelector('.obj').textContent = pr.object;
      div.querySelector('.act').textContent = pr.action;
      layer.appendChild(div);
    });
  }

  function renderScreens(snap, layer) {
    snap.screens.sort((a, b) => a.order - b.order).forEach((sg) => {
      const div = document.createElement('div');
      div.className = 'screengui';
      const scale = ((sg.tree.mods || {}).UIScale || {}).Scale || 1;
      Object.assign(div.style, { position: 'absolute', left: '0', top: INSET + 'px', width: (W / scale) + 'px', height: ((H - INSET) / scale) + 'px', transform: `scale(${scale})`, transformOrigin: '0 0' });
      buildRoot(sg.tree, div);
      layer.appendChild(div);
    });
  }

  window.renderSnapshot = async function (snap) {
    W = window.innerWidth; H = window.innerHeight; INSET = H < 500 ? 36 : 58;
    await document.fonts.load('40px "Luckiest Guy"');
    await document.fonts.load('600 40px "Fredoka"');
    const camera = render3D(snap);
    const overlay = document.getElementById('overlay');
    renderSurfaces(snap, camera, overlay);
    renderBillboards(snap, camera, overlay);
    renderPrompts(snap, camera, overlay);
    renderScreens(snap, overlay);
    await document.fonts.ready;
    fitScaledText(overlay);
    return true;
  };
})();
