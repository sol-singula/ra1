/* Materials and terrain for the gameplay renderer (renderer.js), so renders look like the game in Roblox:
 *
 *  PBR          real CC0 texture sets (tools/gameplay/fetch_textures.py) standing in for Roblox's built-in
 *               materials: colour detail, normal and roughness maps, tinted by the part's Color the way Roblox
 *               tints its materials, tiled at world scale (studs per tile per material)
 *  buildTerrain Roblox smooth terrain from the snapshot's fills (FillBlock, FillBall, FillCylinder, FillWedge, in
 *               order, with Air carving and Water): a signed distance field on a grid, meshed with surface nets,
 *               textured triplanar per material; the water's own surface; and Roblox's grass decoration as
 *               static blades near the camera.
 * Without a texture folder everything still renders, in flat colours. */
(function () {
  // studs per texture repeat, metalness, roughness scale, normal strength, colour boost (the grey detail maps
  // average ~0.86, so colours are lifted to show true), aliases for materials that share a look
  const MATS = {
    Grass: { tile: 9, normal: 0.9 },
    LeafyGrass: { tile: 8, normal: 0.9 },
    Ground: { tile: 12 },
    Mud: { tile: 12 },
    Sand: { tile: 14, normal: 0.7 },
    Salt: { alias: 'Sand' },
    Rock: { tile: 16, normal: 1.2 },
    Slate: { tile: 12, normal: 1.1 },
    Basalt: { tile: 16, normal: 1.1 },
    Sandstone: { tile: 20, normal: 1.0 },
    Limestone: { tile: 16 },
    Granite: { tile: 12 },
    Snow: { tile: 18, normal: 0.6 },
    Glacier: { tile: 14 },
    Ice: { alias: 'Glacier' },
    Cobblestone: { tile: 8, normal: 1.2 },
    Pebble: { tile: 8, normal: 1.1 },
    Pavement: { tile: 10 },
    Asphalt: { alias: 'Concrete' },
    Brick: { tile: 8, normal: 1.1 },
    WoodPlanks: { tile: 8 },
    Wood: { tile: 6 },
    Fabric: { tile: 3, normal: 0.7 },
    Carpet: { tile: 3, normal: 0.6 },
    Leather: { tile: 3, normal: 0.8 },
    Metal: { tile: 8, metal: 0.85, rough: 0.7, normal: 0.6 },
    DiamondPlate: { alias: 'Metal' },
    Foil: { alias: 'Metal' },
    CorrodedMetal: { tile: 8, metal: 0.55, normal: 0.9 },
    ClayRoofTiles: { tile: 8, normal: 1.2 },
    RoofShingles: { tile: 8, normal: 1.1 },
    Plaster: { tile: 12, normal: 0.7 },
    Concrete: { tile: 12 },
    Marble: { tile: 12, rough: 0.5, normal: 0.5 },
    CrackedLava: { tile: 16, emissive: true },
  };
  const resolve = (mat) => (MATS[mat] && MATS[mat].alias) || mat;
  const PBR = { dir: null, cache: {} };
  PBR.info = (mat) => MATS[resolve(mat)];
  PBR.has = (mat) => !!(PBR.dir && PBR.cache[resolve(mat)]);
  PBR.get = (mat) => PBR.cache[resolve(mat)];
  // Load the texture sets these materials need (once each). Resolves when all are ready (missing ones are skipped).
  PBR.load = function (dir, materials) {
    if (!dir) return Promise.resolve();
    PBR.dir = dir;
    const loader = new THREE.TextureLoader();
    const want = new Set();
    materials.forEach((m) => { const r = resolve(m); if (MATS[r] && !PBR.cache[r]) want.add(r); });
    const one = (url, srgb) => new Promise((ok) => {
      loader.load(url, (t) => {
        t.wrapS = t.wrapT = THREE.RepeatWrapping;
        t.anisotropy = 8;
        t.encoding = srgb ? THREE.sRGBEncoding : THREE.LinearEncoding;
        ok(t);
      }, undefined, () => ok(null));
    });
    return Promise.all([...want].map(async (m) => {
      const [map, normal, rough] = await Promise.all([
        one(`${dir}/${m}_color.jpg`, true), one(`${dir}/${m}_normal.jpg`, false), one(`${dir}/${m}_rough.jpg`, false),
      ]);
      if (map) PBR.cache[m] = { map, normal, rough };
    }));
  };
  // A textured MeshStandardMaterial for a part (the geometry carries world-scale UVs, see PBR.worldUV).
  PBR.partMaterial = function (mat, hex, transparency) {
    const tex = PBR.get(mat), info = PBR.info(mat) || {};
    const color = new THREE.Color(hex).multiplyScalar(info.boost || 1.2);
    const shiny = info.metal || info.rough;
    const opts = {
      color, map: tex.map, roughness: info.rough ?? 0.92, metalness: info.metal ?? 0, envMapIntensity: 0.65,
    };
    if (tex.normal) { opts.normalMap = tex.normal; const s = info.normal ?? 1; opts.normalScale = new THREE.Vector2(s, s); }
    if (tex.rough && shiny) opts.roughnessMap = tex.rough;
    if (info.emissive) { opts.emissive = new THREE.Color(hex); opts.emissiveMap = tex.map; opts.emissiveIntensity = 0.6; }
    if (transparency > 0) { opts.transparent = true; opts.opacity = 1 - transparency; }
    return new THREE.MeshStandardMaterial(opts);
  };
  // World-scale UVs for a part's geometry: one texture repeat every `tile` studs on every face, with a random-ish
  // offset per part so neighbouring parts don't line up exactly.
  PBR.worldUV = function (g, shape, size, mat, seed) {
    const info = PBR.info(mat);
    if (!info || !g.attributes.uv && shape !== 'Wedge') return g;
    const tile = info.tile || 8;
    const [x, y, z] = size;
    const ou = (Math.sin(seed * 12.9898) * 43758.5453) % 1, ov = (Math.sin(seed * 78.233) * 12543.1234) % 1;
    if (shape === 'Wedge') {
      // planar projection per triangle onto its main axis
      const pos = g.attributes.position, uv = new Float32Array(pos.count * 2);
      for (let t = 0; t < pos.count; t += 3) {
        const a = new THREE.Vector3().fromBufferAttribute(pos, t), b = new THREE.Vector3().fromBufferAttribute(pos, t + 1), c = new THREE.Vector3().fromBufferAttribute(pos, t + 2);
        const n = new THREE.Vector3().subVectors(b, a).cross(new THREE.Vector3().subVectors(c, a));
        const ax = Math.abs(n.x), ay = Math.abs(n.y), az = Math.abs(n.z);
        for (let k = 0; k < 3; k++) {
          const p = [a, b, c][k];
          let u, v;
          if (ax >= ay && ax >= az) { u = p.z; v = p.y; } else if (ay >= az) { u = p.x; v = p.z; } else { u = p.x; v = p.y; }
          uv[(t + k) * 2] = u / tile + ou; uv[(t + k) * 2 + 1] = v / tile + ov;
        }
      }
      g.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
      return g;
    }
    const uv = g.attributes.uv;
    let su, sv;
    if (shape === 'Block') {
      // BoxGeometry faces in order +X, -X, +Y, -Y, +Z, -Z, four vertices each
      const dims = [[z, y], [z, y], [x, z], [x, z], [x, y], [x, y]];
      for (let f = 0; f < 6; f++) {
        for (let k = 0; k < 4; k++) {
          const i = f * 4 + k;
          uv.setXY(i, uv.getX(i) * dims[f][0] / tile + ou, uv.getY(i) * dims[f][1] / tile + ov);
        }
      }
      uv.needsUpdate = true;
      return g;
    }
    if (shape === 'Cylinder') { const d = Math.min(y, z); su = Math.PI * d / tile; sv = x / tile; }
    else { const d = (x + z) / 2; su = Math.PI * d / tile; sv = Math.PI * y / 2 / tile; }
    for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * su + ou, uv.getY(i) * sv + ov);
    uv.needsUpdate = true;
    return g;
  };
  window.PBR = PBR;

  // ---------- terrain ----------
  // Roblox's default terrain colours (Terrain:SetMaterialColor overrides them)
  const TERRAIN_COLORS = {
    Grass: '#6a7f3f', LeafyGrass: '#73844a', Ground: '#665c3b', Mud: '#3a2e24', Sand: '#8f7e5f', Rock: '#666c6f',
    Slate: '#3f7f6b', Basalt: '#1e1e25', Sandstone: '#89573e', Limestone: '#cecdc0', Snow: '#c3c7da', Glacier: '#65b0ea',
    Ice: '#81c2e0', Cobblestone: '#848484', Pavement: '#94948c', Asphalt: '#73747b', Concrete: '#7f6650', Brick: '#8a563e',
    WoodPlanks: '#8b6d4f', CrackedLava: '#e89c4a', Salt: '#c6bdb5',
  };
  const TRI_GLSL = `
uniform float triTile;
varying vec3 vTriPos;
varying vec3 vTriNormal;
vec3 triWeights(vec3 n) { vec3 w = pow(abs(n), vec3(4.0)); return w / (w.x + w.y + w.z); }
vec4 triSample(sampler2D t, vec3 p, vec3 w) { return texture2D(t, p.zy) * w.x + texture2D(t, p.xz) * w.y + texture2D(t, p.xy) * w.z; }
vec3 triNormal(sampler2D t, vec3 p, vec3 w, vec3 n, vec2 s) {
  vec3 tx = texture2D(t, p.zy).xyz * 2.0 - 1.0; vec3 ty = texture2D(t, p.xz).xyz * 2.0 - 1.0; vec3 tz = texture2D(t, p.xy).xyz * 2.0 - 1.0;
  tx.xy *= s; ty.xy *= s; tz.xy *= s;
  tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
  ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
  tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
  vec3 wn = normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
  return normalize((viewMatrix * vec4(wn, 0.0)).xyz);
}`;
  const NOISE_GLSL = `
float h31(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise3(vec3 x) {
  vec3 i = floor(x), f = fract(x); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
             mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}`;
  // A terrain material: PBR maps sampled from three directions in world space (no UVs needed). overlay: the
  // see-through version drawn where it blends into a neighbouring material (alpha from the 'blend' attribute).
  function terrainMaterial(name, hex, overlay) {
    const tex = PBR.has(name) ? PBR.get(name) : null;
    const info = PBR.info(name) || { tile: 10 };
    const color = new THREE.Color(hex).multiplyScalar(tex ? 1.2 : 1);
    const blendOpts = overlay ? { transparent: true, depthWrite: false, depthFunc: THREE.LessEqualDepth, polygonOffset: true, polygonOffsetFactor: -1, polygonOffsetUnits: -2 } : {};
    const m = new THREE.MeshStandardMaterial(Object.assign(tex
      ? { color, roughness: 1, metalness: 0, map: tex.map, roughnessMap: tex.rough || null, normalMap: tex.normal || null }
      : { color, roughness: 0.95 }, blendOpts));
    const ns = info.normal ?? 1;
    m.normalScale = new THREE.Vector2(ns, ns);
    if (info.emissive) { m.emissive = new THREE.Color(hex); m.emissiveIntensity = 0.5; }
    m.onBeforeCompile = (shader) => {
      shader.uniforms.triTile = { value: 1 / (info.tile || 10) };
      shader.vertexShader = shader.vertexShader
        .replace('#include <common>', '#include <common>\nvarying vec3 vTriPos;\nvarying vec3 vTriNormal;' + (overlay ? '\nattribute float blend;\nvarying float vBlend;' : ''))
        .replace('#include <worldpos_vertex>', '#include <worldpos_vertex>\nvTriPos = (modelMatrix * vec4(transformed, 1.0)).xyz;\nvTriNormal = normalize(mat3(modelMatrix) * objectNormal);' + (overlay ? '\nvBlend = blend;' : ''));
      let f = shader.fragmentShader.replace('#include <common>', '#include <common>\n' + TRI_GLSL + (overlay ? '\nvarying float vBlend;\n' + NOISE_GLSL : ''));
      if (!tex) {
        f = f.replace('#include <map_fragment>', 'vec3 triW = triWeights(normalize(vTriNormal));');
      } else {
        f = f.replace('#include <map_fragment>', 'vec3 triW = triWeights(normalize(vTriNormal));\ndiffuseColor *= triSample(map, vTriPos * triTile, triW);');
      }
      // a ragged edge where materials meet (noise in world space), like Roblox's blends
      if (overlay) f = f.replace('#include <alphamap_fragment>', '#include <alphamap_fragment>\ndiffuseColor.a = smoothstep(0.22, 0.78, vBlend + (vnoise3(vTriPos * 0.45) - 0.5) * 0.75);');
      if (tex && tex.rough) f = f.replace('#include <roughnessmap_fragment>', 'float roughnessFactor = roughness * mix(0.72, 1.0, triSample(roughnessMap, vTriPos * triTile, triW).g);');
      if (tex && tex.normal) f = f.replace('#include <normal_fragment_maps>', 'normal = triNormal(normalMap, vTriPos * triTile, triW, normalize(vTriNormal), normalScale);');
      if (tex && info.emissive) f = f.replace('#include <emissivemap_fragment>', 'totalEmissiveRadiance *= triSample(map, vTriPos * triTile, triW).rgb;');
      shader.fragmentShader = f;
    };
    return m;
  }

  // The blend shader for where terrain materials meet: every material's maps in texture arrays (one layer each,
  // in matNames order), up to three materials per triangle mixed per pixel. Single-material triangles use
  // terrainMaterial, which samples the same maps the same way, so the two meet without a seam.
  const SPLAT_GLSL = `
precision highp sampler2DArray;
uniform sampler2DArray splatColor; uniform sampler2DArray splatNormal; uniform sampler2DArray splatRough;
varying vec3 vBMat; varying vec3 vBWt;
vec4 triSampleA(sampler2DArray t, vec3 p, vec3 w, float layer) {
  return texture(t, vec3(p.zy, layer)) * w.x + texture(t, vec3(p.xz, layer)) * w.y + texture(t, vec3(p.xy, layer)) * w.z;
}
vec3 triNormalWA(sampler2DArray t, vec3 p, vec3 w, vec3 n, float s, float layer) {
  vec3 tx = texture(t, vec3(p.zy, layer)).xyz * 2.0 - 1.0; vec3 ty = texture(t, vec3(p.xz, layer)).xyz * 2.0 - 1.0; vec3 tz = texture(t, vec3(p.xy, layer)).xyz * 2.0 - 1.0;
  tx.xy *= s; ty.xy *= s; tz.xy *= s;
  tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
  ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
  tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
  return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}`;
  let splatCache = null;
  function splatArrays(names) {
    const key = names.join(',');
    if (splatCache && splatCache.key === key) return splatCache;
    const S = 512, layers = names.length;
    const c = document.createElement('canvas');
    c.width = c.height = S;
    const g = c.getContext('2d', { willReadFrequently: true });
    const make = (kind, srgb) => {
      const data = new Uint8Array(S * S * 4 * layers);
      names.forEach((name, li) => {
        const set = PBR.has(name) ? PBR.get(name) : null;
        const tex = set ? (kind === 'color' ? set.map : kind === 'normal' ? set.normal : set.rough) : null;
        if (tex && tex.image) {
          g.clearRect(0, 0, S, S);
          g.drawImage(tex.image, 0, 0, S, S);
          data.set(g.getImageData(0, 0, S, S).data, li * S * S * 4);
        } else {
          const fill = kind === 'normal' ? [128, 128, 255, 255] : kind === 'rough' ? [255, 255, 255, 255] : [219, 219, 219, 255];
          for (let i = 0; i < S * S; i++) data.set(fill, li * S * S * 4 + i * 4);
        }
      });
      const t = new THREE.DataArrayTexture(data, S, S, layers);
      t.format = THREE.RGBAFormat;
      t.type = THREE.UnsignedByteType;
      t.wrapS = t.wrapT = THREE.RepeatWrapping;
      t.minFilter = THREE.LinearMipmapLinearFilter;
      t.magFilter = THREE.LinearFilter;
      t.generateMipmaps = true;
      t.anisotropy = 8;
      t.encoding = srgb ? THREE.sRGBEncoding : THREE.LinearEncoding;
      t.needsUpdate = true;
      return t;
    };
    splatCache = { key, color: make('color', true), normal: make('normal', false), rough: make('rough', false) };
    return splatCache;
  }
  function splatMaterial(names, colors) {
    const arrays = splatArrays(names);
    const n = names.length;
    const tints = names.map((nm) => new THREE.Color(colors[nm] || '#7f7f7f').multiplyScalar(PBR.has(nm) ? 1.2 : 1));
    const tiles = names.map((nm) => 1 / ((PBR.info(nm) || {}).tile || 10));
    const nscale = names.map((nm) => (PBR.info(nm) || {}).normal ?? 1);
    const m = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 1, metalness: 0 });
    m.onBeforeCompile = (shader) => {
      Object.assign(shader.uniforms, {
        splatColor: { value: arrays.color }, splatNormal: { value: arrays.normal }, splatRough: { value: arrays.rough },
        splatTint: { value: tints }, splatTile: { value: tiles }, splatNS: { value: nscale },
      });
      shader.vertexShader = shader.vertexShader
        .replace('#include <common>', '#include <common>\nvarying vec3 vTriPos;\nvarying vec3 vTriNormal;\nattribute vec3 bmat;\nattribute vec3 bwt;\nvarying vec3 vBMat;\nvarying vec3 vBWt;')
        .replace('#include <worldpos_vertex>', '#include <worldpos_vertex>\nvTriPos = (modelMatrix * vec4(transformed, 1.0)).xyz;\nvTriNormal = normalize(mat3(modelMatrix) * objectNormal);\nvBMat = bmat;\nvBWt = bwt;');
      let f = shader.fragmentShader.replace('#include <common>', `#include <common>
varying vec3 vTriPos; varying vec3 vTriNormal;
uniform vec3 splatTint[${n}]; uniform float splatTile[${n}]; uniform float splatNS[${n}];
vec3 triWeights(vec3 n) { vec3 w = pow(abs(n), vec3(4.0)); return w / (w.x + w.y + w.z); }
${NOISE_GLSL}
${SPLAT_GLSL}`);
      f = f.replace('#include <map_fragment>', `
vec3 triW = triWeights(normalize(vTriNormal));
vec3 sw = vBWt * (vec3(vnoise3(vTriPos * 0.4), vnoise3(vTriPos * 0.4 + 19.1), vnoise3(vTriPos * 0.4 + 43.7)) + 0.3);
sw = pow(max(sw, vec3(0.0)), vec3(2.4));
sw /= max(sw.x + sw.y + sw.z, 1e-5);
vec3 sCol = vec3(0.0); vec3 sNrm = vec3(0.0); float sRgh = 0.0;
for (int k = 0; k < 3; k++) {
  float wk = sw[k];
  if (wk < 0.003) continue;
  int L = int(vBMat[k] + 0.5);
  vec3 p = vTriPos * splatTile[L];
  sCol += wk * triSampleA(splatColor, p, triW, float(L)).rgb * splatTint[L];
  sNrm += wk * triNormalWA(splatNormal, p, triW, normalize(vTriNormal), splatNS[L], float(L));
  sRgh += wk * mix(0.72, 1.0, triSampleA(splatRough, p, triW, float(L)).g);
}
diffuseColor.rgb *= sCol;`);
      f = f.replace('#include <roughnessmap_fragment>', 'float roughnessFactor = roughness * sRgh;');
      f = f.replace('#include <normal_fragment_maps>', 'normal = normalize((viewMatrix * vec4(normalize(sNrm), 0.0)).xyz);');
      shader.fragmentShader = f;
    };
    return m;
  }

  // Signed distance (studs, negative inside) and bounds for each kind of fill.
  function shapeOf(op) {
    if (op.o === 'ball') {
      const [cx, cy, cz] = op.c, r = op.r;
      return { box: [cx - r, cy - r, cz - r, cx + r, cy + r, cz + r], d: (x, y, z) => Math.hypot(x - cx, y - cy, z - cz) - r };
    }
    const m = op.m, px = m[0], py = m[1], pz = m[2];
    // world -> local: transpose of the rotation (rows m3..m5, m6..m8, m9..m11)
    const L = (x, y, z) => {
      const dx = x - px, dy = y - py, dz = z - pz;
      return [m[3] * dx + m[6] * dy + m[9] * dz, m[4] * dx + m[7] * dy + m[10] * dz, m[5] * dx + m[8] * dy + m[11] * dz];
    };
    let hx, hy, hz, d;
    if (op.o === 'cylinder') {
      // axis along the CFrame's up vector, like Terrain:FillCylinder
      hx = op.r; hy = op.h / 2; hz = op.r;
      d = (x, y, z) => {
        const l = L(x, y, z);
        const a = Math.hypot(l[0], l[2]) - op.r, b = Math.abs(l[1]) - hy;
        return Math.hypot(Math.max(a, 0), Math.max(b, 0)) + Math.min(Math.max(a, b), 0);
      };
    } else {
      hx = op.s[0] / 2; hy = op.s[1] / 2; hz = op.s[2] / 2;
      const boxD = (l) => {
        const qx = Math.abs(l[0]) - hx, qy = Math.abs(l[1]) - hy, qz = Math.abs(l[2]) - hz;
        return Math.hypot(Math.max(qx, 0), Math.max(qy, 0), Math.max(qz, 0)) + Math.min(Math.max(qx, qy, qz), 0);
      };
      if (op.o === 'wedge') {
        // like a WedgePart: full height at the back (+Z), sloping down to the front (-Z) edge
        const nl = Math.hypot(op.s[1], op.s[2]), ny = op.s[2] / nl, nz = -op.s[1] / nl;
        d = (x, y, z) => {
          const l = L(x, y, z);
          const plane = ny * (l[1] + hy) + nz * (l[2] + hz);
          return Math.max(boxD(l), plane);
        };
      } else {
        d = (x, y, z) => boxD(L(x, y, z));
      }
    }
    const ex = Math.abs(m[3]) * hx + Math.abs(m[4]) * hy + Math.abs(m[5]) * hz;
    const ey = Math.abs(m[6]) * hx + Math.abs(m[7]) * hy + Math.abs(m[8]) * hz;
    const ez = Math.abs(m[9]) * hx + Math.abs(m[10]) * hy + Math.abs(m[11]) * hz;
    return { box: [px - ex, py - ey, pz - ez, px + ex, py + ey, pz + ez], d };
  }

  // Naive surface nets (after Mikola Lysenko): one vertex per cell where the field changes sign, quads across
  // every crossing edge. Returns vertex positions in grid units, the cell each vertex came from, and quads.
  const cubeEdges = new Int32Array(24);
  const edgeTable = new Int32Array(256);
  (function () {
    let k = 0;
    for (let i = 0; i < 8; ++i) for (let j = 1; j <= 4; j <<= 1) { const p = i ^ j; if (i <= p) { cubeEdges[k++] = i; cubeEdges[k++] = p; } }
    for (let i = 0; i < 256; ++i) {
      let em = 0;
      for (let j = 0; j < 24; j += 2) { const a = !!(i & (1 << cubeEdges[j])), b = !!(i & (1 << cubeEdges[j + 1])); em |= a !== b ? 1 << (j >> 1) : 0; }
      edgeTable[i] = em;
    }
  })();
  function surfaceNets(data, dims) {
    let vcap = 1 << 18, fcap = 1 << 18, vn = 0, fn = 0;
    let verts = new Float32Array(vcap * 3), cells = new Int32Array(vcap), quads = new Int32Array(fcap * 4);
    const R = [1, dims[0] + 1, (dims[0] + 1) * (dims[1] + 1)];
    const grid = new Float32Array(8), buffer = new Int32Array(R[2] * 2), x = [0, 0, 0], v = [0, 0, 0];
    let n = 0, bufNo = 1;
    for (x[2] = 0; x[2] < dims[2] - 1; ++x[2], n += dims[0], bufNo ^= 1, R[2] = -R[2]) {
      let m = 1 + (dims[0] + 1) * (1 + bufNo * (dims[1] + 1));
      for (x[1] = 0; x[1] < dims[1] - 1; ++x[1], ++n, m += 2) {
        for (x[0] = 0; x[0] < dims[0] - 1; ++x[0], ++n, ++m) {
          let mask = 0, g = 0, idx = n;
          for (let k = 0; k < 2; ++k, idx += dims[0] * (dims[1] - 2)) {
            for (let j = 0; j < 2; ++j, idx += dims[0] - 2) {
              for (let i = 0; i < 2; ++i, ++g, ++idx) { const p = data[idx]; grid[g] = p; mask |= p < 0 ? 1 << g : 0; }
            }
          }
          if (mask === 0 || mask === 0xff) continue;
          const em = edgeTable[mask];
          v[0] = v[1] = v[2] = 0;
          let ec = 0;
          for (let i = 0; i < 12; ++i) {
            if (!(em & (1 << i))) continue;
            const e0 = cubeEdges[i << 1], e1 = cubeEdges[(i << 1) + 1], g0 = grid[e0], g1 = grid[e1];
            let t = g0 - g1;
            if (Math.abs(t) < 1e-9) continue;
            t = g0 / t;
            ++ec;
            for (let j = 0, k = 1; j < 3; ++j, k <<= 1) {
              const a = e0 & k, b = e1 & k;
              if (a !== b) v[j] += a ? 1 - t : t; else v[j] += a ? 1 : 0;
            }
          }
          if (ec === 0) continue;
          if (vn >= vcap) {
            vcap *= 2;
            const nv = new Float32Array(vcap * 3); nv.set(verts); verts = nv;
            const nc = new Int32Array(vcap); nc.set(cells); cells = nc;
          }
          verts[vn * 3] = x[0] + v[0] / ec; verts[vn * 3 + 1] = x[1] + v[1] / ec; verts[vn * 3 + 2] = x[2] + v[2] / ec;
          cells[vn] = n;
          buffer[m] = vn++;
          for (let i = 0; i < 3; ++i) {
            if (!(em & (1 << i))) continue;
            const iu = (i + 1) % 3, iv = (i + 2) % 3;
            if (x[iu] === 0 || x[iv] === 0) continue;
            const du = R[iu], dv = R[iv];
            if (fn >= fcap) { fcap *= 2; const nq = new Int32Array(fcap * 4); nq.set(quads); quads = nq; }
            if (mask & 1) { quads.set([buffer[m], buffer[m - du], buffer[m - du - dv], buffer[m - dv]], fn * 4); }
            else { quads.set([buffer[m], buffer[m - dv], buffer[m - du - dv], buffer[m - du]], fn * 4); }
            fn++;
          }
        }
      }
    }
    return { verts: verts.subarray(0, vn * 3), cells: cells.subarray(0, vn), quads: quads.subarray(0, fn * 4), vn, fn };
  }

  // Waves for the water's normal map (a small tiling canvas of soft ripples).
  function waveTexture() {
    const n = 256, c = document.createElement('canvas');
    c.width = c.height = n;
    const g = c.getContext('2d'), img = g.createImageData(n, n);
    const h = (x, y) => 0.5 * Math.sin((x * 3 + y * 1) * Math.PI * 2 / n) + 0.35 * Math.sin((x * -2 + y * 5) * Math.PI * 2 / n) + 0.25 * Math.sin((x * 7 - y * 4) * Math.PI * 2 / n);
    for (let y = 0; y < n; y++) {
      for (let x = 0; x < n; x++) {
        const dx = h(x + 1, y) - h(x - 1, y), dy = h(x, y + 1) - h(x, y - 1);
        const i = (y * n + x) * 4;
        img.data[i] = 128 - dx * 90; img.data[i + 1] = 128 - dy * 90; img.data[i + 2] = 255; img.data[i + 3] = 255;
      }
    }
    g.putImageData(img, 0, 0);
    const t = new THREE.CanvasTexture(c);
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    return t;
  }

  // The voxels (Terrain:WriteVoxels, from Capture.luau): run-length encoded chunks of 4-stud voxels, decoded into
  // one coarse grid of solid occupancy, water occupancy and material (0-255 / palette ids).
  function decodeVoxels(V) {
    if (!V || !V.chunks || !V.chunks.length) return null;
    const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
    V.chunks.forEach((c) => { for (let i = 0; i < 3; i++) { lo[i] = Math.min(lo[i], c.o[i]); hi[i] = Math.max(hi[i], c.o[i] + c.n[i] * 4); } });
    const nx = (hi[0] - lo[0]) / 4, ny = (hi[1] - lo[1]) / 4, nz = (hi[2] - lo[2]) / 4;
    const occ = new Uint8Array(nx * ny * nz), wocc = new Uint8Array(nx * ny * nz), mat = new Uint8Array(nx * ny * nz);
    const waterId = V.palette.indexOf('Water');
    for (const c of V.chunks) {
      const [cx, cy, cz] = [(c.o[0] - lo[0]) / 4, (c.o[1] - lo[1]) / 4, (c.o[2] - lo[2]) / 4];
      const [cnx, cny, cnz] = c.n;
      let i = 0;
      const toks = c.rle.split(',');
      for (const t of toks) {
        const star = t.indexOf('*');
        const code = star < 0 ? +t : +t.slice(0, star), count = star < 0 ? 1 : +t.slice(star + 1);
        const id = code & 255, o = code >> 8;
        for (let r = 0; r < count; r++, i++) {
          const ly = i % cny, lz = Math.floor(i / cny) % cnz, lx = Math.floor(i / (cny * cnz));
          const g = (cx + lx) + nx * ((cy + ly) + ny * (cz + lz));
          if (id === waterId) { wocc[g] = o; occ[g] = 0; mat[g] = 0; } else { occ[g] = id ? o : 0; wocc[g] = 0; mat[g] = id; }
        }
      }
    }
    // the field: occupancy blurred [1 2 1] along each axis, so slopes built from stacked part-full voxels come out
    // smooth (as Roblox draws them) instead of terraced; level ground stays exactly level
    const field = new Float32Array(nx * ny * nz);
    for (let g = 0; g < field.length; g++) field[g] = occ[g] / 255;
    const tmp = new Float32Array(field.length);
    const blur = (src, dst, step, n, idxOf) => {
      for (let g = 0; g < src.length; g++) {
        const c = idxOf(g);
        const a = c > 0 ? src[g - step] : src[g], b = c < n - 1 ? src[g + step] : src[g];
        dst[g] = (a + 2 * src[g] + b) * 0.25;
      }
    };
    blur(field, tmp, 1, nx, (g) => g % nx);
    blur(tmp, field, nx, ny, (g) => Math.floor(g / nx) % ny);
    blur(field, tmp, nx * ny, nz, (g) => Math.floor(g / (nx * ny)));
    field.set(tmp);
    // where the materials show: each surface voxel's material, blurred over its neighbours (3 x 3 x 3), kept as
    // the top three (material, weight) per voxel near the surface. Vertices blend between these, so material edges
    // run smooth instead of following the 4-stud voxel steps.
    const N = nx * ny * nz;
    const isSurface = new Uint8Array(N);
    for (let k = 0; k < nz; k++) for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
      const g = i + nx * (j + ny * k);
      if (!occ[g] || !mat[g]) continue;
      let open = occ[g] < 250;
      if (!open) {
        if (j + 1 < ny && !occ[g + nx]) open = true;
        else if (i > 0 && !occ[g - 1]) open = true;
        else if (i + 1 < nx && !occ[g + 1]) open = true;
        else if (k > 0 && !occ[g - nx * ny]) open = true;
        else if (k + 1 < nz && !occ[g + nx * ny]) open = true;
        else if (j > 0 && !occ[g - nx]) open = true;
      }
      if (open) isSurface[g] = 1;
    }
    const bm = new Uint8Array(N * 3), bw = new Float32Array(N * 3), acc = new Float32Array(V.palette.length), touched = [];
    for (let k = 0; k < nz; k++) for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
      const g = i + nx * (j + ny * k);
      let any = false;
      for (let c = -1; c <= 1 && !any; c++) for (let b = -1; b <= 1 && !any; b++) for (let a = -1; a <= 1; a++) {
        const ii = i + a, jj = j + b, kk = k + c;
        if (ii < 0 || jj < 0 || kk < 0 || ii >= nx || jj >= ny || kk >= nz) continue;
        if (isSurface[ii + nx * (jj + ny * kk)]) { any = true; break; }
      }
      if (!any) continue;
      for (let c = -1; c <= 1; c++) for (let b = -1; b <= 1; b++) for (let a = -1; a <= 1; a++) {
        const ii = i + a, jj = j + b, kk = k + c;
        if (ii < 0 || jj < 0 || kk < 0 || ii >= nx || jj >= ny || kk >= nz) continue;
        const h = ii + nx * (jj + ny * kk);
        if (!isSurface[h]) continue;
        const w = (a ? 0.55 : 1) * (b ? 0.55 : 1) * (c ? 0.55 : 1);
        const m = mat[h];
        if (acc[m] === 0) touched.push(m);
        acc[m] += w;
      }
      if (!touched.length) continue;
      let total = 0;
      for (const m of touched) total += acc[m];
      touched.sort((x, y) => acc[y] - acc[x]);
      for (let q = 0; q < 3 && q < touched.length; q++) { bm[g * 3 + q] = touched[q]; bw[g * 3 + q] = acc[touched[q]] / total; }
      for (const m of touched) acc[m] = 0;
      touched.length = 0;
    }
    return { lo, hi, nx, ny, nz, occ, wocc, mat, palette: V.palette, bm, bw, field };
  }

  // Build the terrain meshes into the scene. camera: for the grass blades (only drawn near and in view).
  window.buildTerrain = function (scene, T, camera) {
    if (!T || (!(T.ops && T.ops.length) && !T.voxels)) return null;
    const shapes = (T.ops || []).map((op) => ({ op, ...shapeOf(op) }));
    const VX = decodeVoxels(T.voxels);
    // the grid: everything the fills and voxels touch, at 2 studs (or coarser for a very big world). The land's
    // signed distance is kept as bytes (clamped to 3 cells either side of the surface).
    const bb = [Infinity, Infinity, Infinity, -Infinity, -Infinity, -Infinity];
    const grow = (box) => { for (let i = 0; i < 3; i++) { bb[i] = Math.min(bb[i], box[i]); bb[i + 3] = Math.max(bb[i + 3], box[i + 3]); } };
    shapes.forEach((s) => grow(s.box));
    if (VX) grow([...VX.lo, ...VX.hi]);
    let res = 2;
    const cellsAt = (r) => ((bb[3] - bb[0]) / r + 4) * ((bb[4] - bb[1]) / r + 4) * ((bb[5] - bb[2]) / r + 4);
    while (cellsAt(res) > 32e6) res += 1;
    const ox = bb[0] - res * 2, oy = bb[1] - res * 2, oz = bb[2] - res * 2;
    const nx = Math.ceil((bb[3] - ox) / res) + 3, ny = Math.ceil((bb[4] - oy) / res) + 3, nz = Math.ceil((bb[5] - oz) / res) + 3;
    const N = nx * ny * nz, B = res * 3, Q = 127 / B;
    const q = (d) => (d >= B ? 127 : d <= -B ? -127 : Math.round(d * Q));
    const solid = new Int8Array(N).fill(127), mat = new Uint8Array(N);
    const matNames = ['Air'], matId = {};
    const idOf = (name) => { if (matId[name] == null) { matId[name] = matNames.length; matNames.push(name); } return matId[name]; };
    // water: its own (float) grid over just where there is water
    const wb = [Infinity, Infinity, Infinity, -Infinity, -Infinity, -Infinity];
    const wgrow = (box) => { for (let i = 0; i < 3; i++) { wb[i] = Math.min(wb[i], box[i]); wb[i + 3] = Math.max(wb[i + 3], box[i + 3]); } };
    shapes.forEach((s) => { if (s.op.mat === 'Water') wgrow(s.box); });
    if (VX) {
      for (let k = 0; k < VX.nz; k++) for (let j = 0; j < VX.ny; j++) for (let i = 0; i < VX.nx; i++) {
        if (VX.wocc[i + VX.nx * (j + VX.ny * k)]) {
          const x = VX.lo[0] + i * 4, y = VX.lo[1] + j * 4, z = VX.lo[2] + k * 4;
          wgrow([x, y, z, x + 4, y + 4, z + 4]);
        }
      }
    }
    let W = null;
    if (wb[0] < Infinity) {
      const wox = Math.max(ox, Math.floor((wb[0] - 8 - ox) / res) * res + ox), woy = Math.max(oy, Math.floor((wb[1] - 8 - oy) / res) * res + oy), woz = Math.max(oz, Math.floor((wb[2] - 8 - oz) / res) * res + oz);
      const wnx = Math.ceil((wb[3] + 8 - wox) / res) + 1, wny = Math.ceil((wb[4] + 8 - woy) / res) + 1, wnz = Math.ceil((wb[5] + 8 - woz) / res) + 1;
      W = { ox: wox, oy: woy, oz: woz, nx: wnx, ny: wny, nz: wnz, f: new Float32Array(wnx * wny * wnz).fill(B) };
      W.i0 = Math.round((wox - ox) / res); W.j0 = Math.round((woy - oy) / res); W.k0 = Math.round((woz - oz) / res);
    }
    // 1. the voxels: the field between voxel centres is linear in (0.5 - occupancy), 4 studs per voxel; a grid
    // point takes the material of the fullest voxel near it
    const vidOf = VX ? Uint8Array.from(VX.palette.map((name) => (name === 'Air' || name === 'Water' ? 0 : idOf(name)))) : null;
    if (VX) {
      const vid = vidOf;
      const axis = (n, o, lo, vn) => {
        const c0 = new Int32Array(n), fr = new Float32Array(n);
        for (let i = 0; i < n; i++) { const u = (o + i * res - lo - 2) / 4; c0[i] = Math.floor(u); fr[i] = u - c0[i]; }
        return { c0, fr, vn };
      };
      const sample = (data, scale, onto, ontoMat, x0, y0, z0, mnx, mny, mnz) => {
        const ax = axis(mnx, x0, VX.lo[0]), ay = axis(mny, y0, VX.lo[1]), az = axis(mnz, z0, VX.lo[2]);
        const vnx = VX.nx, vny = VX.ny, vnz = VX.nz, sy = vnx, sz = vnx * vny;
        const val = new Float32Array(8), wt = new Float32Array(8), gi = new Int32Array(8);
        for (let k = 0; k < mnz; k++) {
          const k0 = az.c0[k], fz = az.fr[k];
          for (let j = 0; j < mny; j++) {
            const j0 = ay.c0[j], fy = ay.fr[j];
            let idx = mnx * (j + mny * k);
            for (let i = 0; i < mnx; i++, idx++) {
              const i0 = ax.c0[i], fx = ax.fr[i];
              let f = 0;
              for (let c = 0; c < 8; c++) {
                const ii = i0 + (c & 1), jj = j0 + ((c >> 1) & 1), kk = k0 + ((c >> 2) & 1);
                let o = 0, g = -1;
                if (ii >= 0 && jj >= 0 && kk >= 0 && ii < vnx && jj < vny && kk < vnz) { g = ii + sy * jj + sz * kk; o = data[g] * scale; }
                gi[c] = g;
                const v = (0.5 - o) * 4;
                val[c] = v;
                const w = ((c & 1) ? fx : 1 - fx) * ((c & 2) ? fy : 1 - fy) * ((c & 4) ? fz : 1 - fz);
                wt[c] = w;
                f += w * v;
              }
              if (ontoMat) {
                onto[idx] = q(f);
                if (f < res * 0.9) {
                  // the solid voxel nearest the surface wins (a part-full top voxel over full ones below), then
                  // the nearest one
                  let best = -1, bm = 0;
                  for (let c = 0; c < 8; c++) {
                    if (gi[c] < 0 || val[c] >= 2) continue;
                    const sc = (4 - Math.abs(val[c])) * 4 + wt[c];
                    if (sc > best) { best = sc; bm = vid[VX.mat[gi[c]]]; }
                  }
                  ontoMat[idx] = bm;
                }
              } else {
                onto[idx] = f;
              }
            }
          }
        }
      };
      sample(VX.field, 1, solid, mat, ox, oy, oz, nx, ny, nz);
      if (W) {
        const wf = new Float32Array(W.f.length);
        sample(VX.wocc, 1 / 255, wf, null, W.ox, W.oy, W.oz, W.nx, W.ny, W.nz);
        for (let i = 0; i < wf.length; i++) W.f[i] = Math.min(W.f[i], wf[i]);
      }
    }
    // 2. the fills, in order: solid ones add land (and push water out), Water adds water, Air carves both
    for (const s of shapes) {
      const kind = s.op.mat === 'Air' ? 0 : s.op.mat === 'Water' ? 1 : 2;
      const id = kind === 2 ? idOf(s.op.mat) : 0;
      const i0 = Math.max(0, Math.floor((s.box[0] - B - ox) / res)), i1 = Math.min(nx - 1, Math.ceil((s.box[3] + B - ox) / res));
      const j0 = Math.max(0, Math.floor((s.box[1] - B - oy) / res)), j1 = Math.min(ny - 1, Math.ceil((s.box[4] + B - oy) / res));
      const k0 = Math.max(0, Math.floor((s.box[2] - B - oz) / res)), k1 = Math.min(nz - 1, Math.ceil((s.box[5] + B - oz) / res));
      const paint = res * 0.9;
      for (let k = k0; k <= k1; k++) {
        const z = oz + k * res;
        for (let j = j0; j <= j1; j++) {
          const y = oy + j * res;
          let idx = i0 + nx * (j + ny * k);
          for (let i = i0; i <= i1; i++, idx++) {
            const d = s.d(ox + i * res, y, z);
            if (d >= B) continue;
            const wi = W ? (i - W.i0) + W.nx * ((j - W.j0) + W.ny * (k - W.k0)) : -1;
            const inW = W && i >= W.i0 && j >= W.j0 && k >= W.k0 && i < W.i0 + W.nx && j < W.j0 + W.ny && k < W.k0 + W.nz;
            if (kind === 2) {
              const qd = q(d);
              if (qd < solid[idx]) solid[idx] = qd;
              if (d < paint) mat[idx] = id;
              if (inW && -d > W.f[wi]) W.f[wi] = -d;
            } else if (kind === 1) {
              if (inW && d < W.f[wi]) W.f[wi] = d;
              const qn = q(-d);
              if (qn > solid[idx]) solid[idx] = qn;
            } else {
              const qn = q(-d);
              if (qn > solid[idx]) solid[idx] = qn;
              if (inW && -d > W.f[wi]) W.f[wi] = -d;
            }
          }
        }
      }
    }
    const trilinear = (data, x, y, z) => {
      const i = Math.max(0, Math.min(nx - 2, Math.floor(x))), j = Math.max(0, Math.min(ny - 2, Math.floor(y))), k = Math.max(0, Math.min(nz - 2, Math.floor(z)));
      const fx = x - i, fy = y - j, fz = z - k, b = i + nx * (j + ny * k);
      const c = (o) => data[b + o];
      const sx = 1, sy = nx, sz = nx * ny;
      const a0 = c(0) * (1 - fx) + c(sx) * fx, a1 = c(sy) * (1 - fx) + c(sx + sy) * fx;
      const a2 = c(sz) * (1 - fx) + c(sx + sz) * fx, a3 = c(sy + sz) * (1 - fx) + c(sx + sy + sz) * fx;
      return (a0 * (1 - fy) + a1 * fy) * (1 - fz) + (a2 * (1 - fy) + a3 * fy) * fz;
    };
    const group = new THREE.Group();
    group.name = 'Terrain';
    const colors = Object.assign({}, TERRAIN_COLORS, T.colors || {});
    const grassBlades = [];
    // the land: one mesh with a group per material (each triangle drawn with the material most of it has), then
    // see-through overlays where materials meet, so they blend over a few studs like Roblox's terrain does
    {
      const net = surfaceNets(solid, [nx, ny, nz]);
      const vn = net.vn;
      const pos = new Float32Array(vn * 3), nor = new Float32Array(vn * 3);
      const vm = new Uint8Array(vn * 3), vw = new Float32Array(vn * 3); // each vertex's top 3 materials and weights
      const acc = new Float32Array(matNames.length);
      const touched = [];
      const sy = nx, sz = nx * ny;
      for (let v = 0; v < vn; v++) {
        const gx = net.verts[v * 3], gy = net.verts[v * 3 + 1], gz = net.verts[v * 3 + 2];
        pos[v * 3] = ox + gx * res; pos[v * 3 + 1] = oy + gy * res; pos[v * 3 + 2] = oz + gz * res;
        const e = 0.5;
        const dx = trilinear(solid, gx + e, gy, gz) - trilinear(solid, gx - e, gy, gz);
        const dy = trilinear(solid, gx, gy + e, gz) - trilinear(solid, gx, gy - e, gz);
        const dz = trilinear(solid, gx, gy, gz + e) - trilinear(solid, gx, gy, gz - e);
        const l = Math.hypot(dx, dy, dz) || 1;
        nor[v * 3] = dx / l; nor[v * 3 + 1] = dy / l; nor[v * 3 + 2] = dz / l;
        // material weights: from the voxels' blurred surface materials (trilinear between voxel centres), or else
        // from grid points within 2 cells, nearer the surface counting more
        let inFill = false;
        for (const sh of shapes) {
          const bx0 = sh.box;
          if (pos[v * 3] > bx0[0] - B && pos[v * 3] < bx0[3] + B && pos[v * 3 + 1] > bx0[1] - B && pos[v * 3 + 1] < bx0[4] + B && pos[v * 3 + 2] > bx0[2] - B && pos[v * 3 + 2] < bx0[5] + B) { inFill = true; break; }
        }
        if (VX && !inFill) {
          const u = (pos[v * 3] - VX.lo[0] - 2) / 4, w0 = (pos[v * 3 + 1] - VX.lo[1] - 2) / 4, t0 = (pos[v * 3 + 2] - VX.lo[2] - 2) / 4;
          const i0 = Math.floor(u), j0 = Math.floor(w0), k0 = Math.floor(t0);
          const fx = u - i0, fy = w0 - j0, fz = t0 - k0;
          for (let c = 0; c < 8; c++) {
            const ii = i0 + (c & 1), jj = j0 + ((c >> 1) & 1), kk = k0 + ((c >> 2) & 1);
            if (ii < 0 || jj < 0 || kk < 0 || ii >= VX.nx || jj >= VX.ny || kk >= VX.nz) continue;
            const wt = ((c & 1) ? fx : 1 - fx) * ((c & 2) ? fy : 1 - fy) * ((c & 4) ? fz : 1 - fz);
            if (wt <= 0) continue;
            const g = ii + VX.nx * (jj + VX.ny * kk);
            for (let q = 0; q < 3; q++) {
              const pm = VX.bm[g * 3 + q];
              if (!pm) continue;
              const m = vidOf[pm];
              if (!m) continue;
              if (acc[m] === 0) touched.push(m);
              acc[m] += wt * VX.bw[g * 3 + q];
            }
          }
        }
        const bx = Math.floor(gx), by = Math.floor(gy), bz = Math.floor(gz);
        const fromGrid = touched.length === 0;
        for (let k = bz - 1; k <= bz + 2 && fromGrid; k++) {
          if (k < 0 || k >= nz) continue;
          const wz = 2 - Math.abs(k - gz);
          if (wz <= 0) continue;
          for (let j = by - 1; j <= by + 2; j++) {
            if (j < 0 || j >= ny) continue;
            const wy = 2 - Math.abs(j - gy);
            if (wy <= 0) continue;
            for (let i = bx - 1; i <= bx + 2; i++) {
              if (i < 0 || i >= nx) continue;
              const wx = 2 - Math.abs(i - gx);
              if (wx <= 0) continue;
              const g = i + sy * j + sz * k;
              const m = mat[g];
              if (!m || solid[g] > 0) continue;
              const near = 1.05 - Math.abs(solid[g]) / 127;
              const w = wx * wy * wz * near * near;
              if (acc[m] === 0) touched.push(m);
              acc[m] += w;
            }
          }
        }
        let total = 0;
        for (const m of touched) total += acc[m];
        touched.sort((a, b) => acc[b] - acc[a]);
        for (let q = 0; q < 3; q++) {
          const m = touched[q];
          vm[v * 3 + q] = m || 0;
          vw[v * 3 + q] = m && total > 0 ? acc[m] / total : 0;
        }
        if (!touched.length) { vm[v * 3] = 1; vw[v * 3] = 1; }
        for (const m of touched) acc[m] = 0;
        touched.length = 0;
      }
      const weightOf = (v, m) => (vm[v * 3] === m ? vw[v * 3] : vm[v * 3 + 1] === m ? vw[v * 3 + 1] : vm[v * 3 + 2] === m ? vw[v * 3 + 2] : 0);
      // triangles: where one material covers all three corners, it goes in that material's group of the main mesh;
      // where materials meet, it goes in the blend mesh (up to three materials, mixed per pixel with a little
      // noise, like Roblox's terrain)
      const byMat = {};
      const bPos = [], bNor = [], bMat = [], bWt = [];
      const tri = (a, b, c) => {
        const tot = new Map();
        for (const v of [a, b, c]) for (let q = 0; q < 3; q++) {
          const m = vm[v * 3 + q];
          if (m) tot.set(m, (tot.get(m) || 0) + vw[v * 3 + q]);
        }
        const order = [...tot.keys()].sort((x, y) => tot.get(y) - tot.get(x));
        const top = order[0] || 1;
        if ((tot.get(top) || 3) >= 2.94 || order.length < 2) {
          (byMat[top] = byMat[top] || []).push(a, b, c);
          return;
        }
        const ms = [order[0], order[1], order[2] || 0];
        for (const v of [a, b, c]) {
          bPos.push(pos[v * 3], pos[v * 3 + 1], pos[v * 3 + 2]);
          bNor.push(nor[v * 3], nor[v * 3 + 1], nor[v * 3 + 2]);
          const w0 = weightOf(v, ms[0]), w1 = weightOf(v, ms[1]), w2 = ms[2] ? weightOf(v, ms[2]) : 0;
          const sum = w0 + w1 + w2 || 1;
          bWt.push(w0 / sum, w1 / sum, w2 / sum);
          bMat.push(ms[0], ms[1], ms[2] || ms[0]);
        }
      };
      for (let f = 0; f < net.fn; f++) {
        const a = net.quads[f * 4], b = net.quads[f * 4 + 1], c = net.quads[f * 4 + 2], d = net.quads[f * 4 + 3];
        tri(a, b, c);
        tri(a, c, d);
      }
      const geo = new THREE.BufferGeometry();
      geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
      geo.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
      const indices = [], materials = [];
      Object.keys(byMat).forEach((m, gi) => {
        geo.addGroup(indices.length, byMat[m].length, gi);
        for (const i of byMat[m]) indices.push(i);
        const name = matNames[m];
        materials.push(terrainMaterial(name, colors[name] || '#7f7f7f'));
      });
      geo.setIndex(indices);
      const mesh = new THREE.Mesh(geo, materials);
      mesh.castShadow = true;
      mesh.receiveShadow = true;
      mesh.name = 'Land';
      group.add(mesh);
      if (bPos.length) {
        const bg = new THREE.BufferGeometry();
        bg.setAttribute('position', new THREE.Float32BufferAttribute(bPos, 3));
        bg.setAttribute('normal', new THREE.Float32BufferAttribute(bNor, 3));
        // material ids index the texture arrays, whose layers follow matNames
        bg.setAttribute('bmat', new THREE.Float32BufferAttribute(bMat, 3));
        bg.setAttribute('bwt', new THREE.Float32BufferAttribute(bWt, 3));
        const blend = new THREE.Mesh(bg, splatMaterial(matNames, colors));
        blend.castShadow = true;
        blend.receiveShadow = true;
        blend.name = 'LandBlend';
        group.add(blend);
      }
      // Roblox's grass decoration: short blades on flat grass near the camera, in view
      const grassId = matId.Grass;
      if (T.decoration !== false && camera && grassId) {
        const frustum = new THREE.Frustum().setFromProjectionMatrix(new THREE.Matrix4().multiplyMatrices(camera.projectionMatrix, camera.matrixWorldInverse));
        const cp = camera.position, blades = [];
        const rnd = (() => { let sd = 1234567; return () => ((sd = (sd * 16807) % 2147483647) / 2147483647); })();
        const tmp = new THREE.Vector3();
        const grassTris = (byMat[grassId] || []).slice();
        for (let t = 0; t < bPos.length / 3; t += 3) {
          // blend triangles: find their vertices again by position (they were copied out of the main mesh)
          if (bMat[t * 3] !== grassId && bMat[t * 3 + 1] !== grassId && bMat[t * 3 + 2] !== grassId) continue;
          grassTris.push(-1 - t, -2 - t, -3 - t);
        }
        const P = (v) => (v >= 0 ? [pos[v * 3], pos[v * 3 + 1], pos[v * 3 + 2]] : [bPos[(-1 - v) * 3], bPos[(-1 - v) * 3 + 1], bPos[(-1 - v) * 3 + 2]]);
        const Ny = (v) => (v >= 0 ? nor[v * 3 + 1] : bNor[(-1 - v) * 3 + 1]);
        const G = (v) => {
          if (v >= 0) return weightOf(v, grassId);
          const i = -1 - v;
          for (let q = 0; q < 3; q++) if (bMat[i * 3 + q] === grassId) return bWt[i * 3 + q];
          return 0;
        };
        for (let t = 0; t < grassTris.length; t += 3) {
          const a = grassTris[t], b = grassTris[t + 1], c = grassTris[t + 2];
          const gsum = G(a) + G(b) + G(c);
          if (gsum < 0.9) continue;
          if (Ny(a) < 0.8) continue;
          const pa = P(a), pb = P(b), pc = P(c);
          const ax = pa[0], ay = pa[1], az = pa[2];
          const dist = Math.hypot(ax - cp.x, ay - cp.y, az - cp.z);
          if (dist > 95) continue;
          if (!frustum.containsPoint(tmp.set(ax, ay + 0.5, az))) continue;
          const area = res * res * 0.5;
          const count = Math.round(area * (dist < 30 ? 7 : dist < 55 ? 3.2 : 1.1) * (rnd() * 0.4 + 0.8) * Math.min(1, gsum / 3));
          for (let q = 0; q < count; q++) {
            let u = rnd(), w = rnd();
            if (u + w > 1) { u = 1 - u; w = 1 - w; }
            const bx = ax + (pb[0] - ax) * u + (pc[0] - ax) * w;
            const by = ay + (pb[1] - ay) * u + (pc[1] - ay) * w;
            const bz = az + (pb[2] - az) * u + (pc[2] - az) * w;
            blades.push(bx, by, bz, rnd() * Math.PI * 2, 0.6 + rnd() * 0.75, rnd());
          }
          if (blades.length > 6 * 420000) break;
        }
        const n = blades.length / 6;
        if (n > 0) {
          // a thin tapered blade with a bend, darker at the root
          const bg = new THREE.BufferGeometry();
          const bw = 0.07;
          bg.setAttribute('position', new THREE.Float32BufferAttribute([-bw, 0, 0, bw, 0, 0, -bw * 0.7, 0.55, 0.05, bw * 0.7, 0.55, 0.05, 0, 1, 0.18], 3));
          bg.setAttribute('color', new THREE.Float32BufferAttribute([0.62, 0.62, 0.62, 0.62, 0.62, 0.62, 0.88, 0.88, 0.88, 0.88, 0.88, 0.88, 1.06, 1.06, 1.06], 3));
          bg.setIndex([0, 1, 3, 0, 3, 2, 2, 3, 4]);
          bg.computeVertexNormals();
          // blades lit like the ground under them (normals up), so they don't flicker light and dark
          const nrm = bg.attributes.normal;
          for (let i = 0; i < nrm.count; i++) nrm.setXYZ(i, 0, 1, 0);
          const bm = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95, side: THREE.DoubleSide });
          const inst = new THREE.InstancedMesh(bg, bm, n);
          const mtx = new THREE.Matrix4(), qt = new THREE.Quaternion(), sc = new THREE.Vector3(), p = new THREE.Vector3(), eu = new THREE.Euler();
          const col = new THREE.Color(), base = new THREE.Color(colors.Grass).multiplyScalar(1.12);
          for (let i = 0; i < n; i++) {
            const b = i * 6;
            eu.set((blades[b + 5] - 0.5) * 0.5, blades[b + 3], (blades[b + 5] - 0.5) * 0.3);
            qt.setFromEuler(eu);
            sc.set(1, blades[b + 4], 1);
            p.set(blades[b], blades[b + 1] - 0.08, blades[b + 2]);
            mtx.compose(p, qt, sc);
            inst.setMatrixAt(i, mtx);
            col.copy(base).multiplyScalar(0.92 + (blades[b + 5] - 0.5) * 0.3);
            inst.setColorAt(i, col);
          }
          inst.receiveShadow = true;
          inst.name = 'GrassBlades';
          group.add(inst);
        }
      }
    }
    // the water's surface: where water meets air (faces against the land under it are dropped)
    if (W) {
      let any = false;
      for (let i = 0; i < W.f.length; i++) if (W.f[i] < 0) { any = true; break; }
      if (any) {
        const net = surfaceNets(W.f, [W.nx, W.ny, W.nz]);
        const pos = new Float32Array(net.vn * 3), uv = new Float32Array(net.vn * 2), dry = new Uint8Array(net.vn);
        for (let v = 0; v < net.vn; v++) {
          const gx = net.verts[v * 3], gy = net.verts[v * 3 + 1], gz = net.verts[v * 3 + 2];
          const x = W.ox + gx * res, y = W.oy + gy * res, z = W.oz + gz * res;
          pos[v * 3] = x; pos[v * 3 + 1] = y; pos[v * 3 + 2] = z;
          uv[v * 2] = x / 14; uv[v * 2 + 1] = z / 14;
          // the land's distance here (in studs): against the bed or a bank, this is no water surface
          const land = trilinear(solid, gx + W.i0, gy + W.j0, gz + W.k0) / Q;
          dry[v] = land < 0.35 ? 1 : 0;
        }
        const idx = [];
        for (let f = 0; f < net.fn; f++) {
          const a = net.quads[f * 4], b = net.quads[f * 4 + 1], c = net.quads[f * 4 + 2], d = net.quads[f * 4 + 3];
          if (dry[a] + dry[b] + dry[c] + dry[d] >= 2) continue;
          idx.push(a, b, c, a, c, d);
        }
        const geo = new THREE.BufferGeometry();
        geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
        geo.setAttribute('uv', new THREE.BufferAttribute(uv, 2));
        geo.setIndex(idx);
        geo.computeVertexNormals();
        const WS = T.water || {};
        const wm = new THREE.MeshStandardMaterial({
          color: new THREE.Color(WS.color || '#2a8fc0').multiplyScalar(1.15), roughness: 0.05, metalness: 0.15,
          transparent: true, opacity: 0.55 + 0.4 * (1 - Math.min(1, WS.transparency ?? 0.3)), depthWrite: false,
          normalMap: waveTexture(), envMapIntensity: 1.5, side: THREE.DoubleSide,
        });
        wm.normalScale = new THREE.Vector2(0.4, 0.4);
        const mesh = new THREE.Mesh(geo, wm);
        mesh.receiveShadow = true;
        mesh.name = 'Water';
        mesh.renderOrder = 2;
        group.add(mesh);
      }
    }
    scene.add(group);
    return { group, res };
  };
})();
