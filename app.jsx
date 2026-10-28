const { useEffect, useMemo, useRef, useState } = React;

const ICONS = {
  all: "✧", planet: "◉", exoplanet: "⊙", star: "✦", galaxy: "◎",
  nebula: "✳", deep: "✧", "black-hole": "◉", moon: "◌", "dwarf-planet": "◉", asteroid: "◇"
};
const CATEGORIES = [
  ["all", "Everything"], ["planet", "Planets"], ["exoplanet", "Exoplanets"],
  ["star", "Stars"], ["galaxy", "Galaxies"], ["nebula", "Nebulae"],
  ["black-hole", "Black holes"], ["moon", "Moons"], ["asteroid", "Comets & asteroids"], ["deep", "Deep space"]
];

function App() {
  const [catalog, setCatalog] = useState([]);
  const [selected, setSelected] = useState(null);
  const [category, setCategory] = useState("all");
  const [search, setSearch] = useState("");
  const [results, setResults] = useState([]);
  const [searchOpen, setSearchOpen] = useState(false);
  const [searching, setSearching] = useState(false);
  const [loadingDetail, setLoadingDetail] = useState(false);
  const [labelsOn, setLabelsOn] = useState(true);
  const [orbitsOn, setOrbitsOn] = useState(true);
  const [sceneReady, setSceneReady] = useState(false);
  const [viewScale, setViewScale] = useState("universe");
  const [apiStatus, setApiStatus] = useState("CONNECTING");
  const [notice, setNotice] = useState("");
  const [activeTab, setActiveTab] = useState("Overview");
  const sceneRef = useRef(null);
  const sceneApi = useRef(null);
  const timerRef = useRef(null);
  const noticeTimer = useRef(null);
  const selectedRef = useRef(null);
  const ephemerisRef = useRef({});
  selectedRef.current = selected;

  const visibleCatalog = useMemo(function () {
    if (category === "all") return catalog;
    return catalog.filter(function (item) {
      return item.category === category || (category === "planet" && item.category === "dwarf-planet");
    });
  }, [catalog, category]);

  function toast(message) {
    setNotice(message);
    clearTimeout(noticeTimer.current);
    noticeTimer.current = setTimeout(function () { setNotice(""); }, 2500);
  }

  useEffect(function () {
    let alive = true;
    fetch("/api/catalog")
      .then(function (response) { if (!response.ok) throw new Error("Catalog unavailable"); return response.json(); })
      .then(function (data) {
        if (!alive) return;
        setCatalog(data.objects || []);
        setApiStatus("CATALOG ONLINE");
        fetch("/api/sky?limit=450")
          .then(function (response) { if (!response.ok) throw new Error("Gaia sample unavailable"); return response.json(); })
          .then(function (sky) {
            if (!alive) return;
            const incoming = (sky.objects || []).filter(function (item) { return Array.isArray(item.position); });
            setCatalog(function (previous) {
              const ids = new Set(previous.map(function (item) { return item.id; }));
              return previous.concat(incoming.filter(function (item) { return !ids.has(item.id); }));
            });
            setApiStatus("GAIA + CATALOGS");
          })
          .catch(function () { if (alive) setApiStatus("LOCAL + LIVE SEARCH"); });
        fetch("/api/ephemeris")
          .then(function (response) { if (!response.ok) throw new Error("Ephemeris unavailable"); return response.json(); })
          .then(function (data) {
            if (!alive) return;
            ephemerisRef.current = data.positions || {};
            if (sceneApi.current) sceneApi.current.ephemeris(ephemerisRef.current);
          })
          .catch(function () { if (alive) toast("JPL Horizons is unavailable; mean orbital distances remain available."); });
      })
      .catch(function () { if (alive) { setApiStatus("API OFFLINE"); toast("Start the server with ruby server.rb to load the live catalog."); } });
    return function () { alive = false; clearTimeout(timerRef.current); clearTimeout(noticeTimer.current); };
  }, []);

  useEffect(function () {
    if (!search.trim()) {
      setResults([]);
      setSearching(false);
      return;
    }
    clearTimeout(timerRef.current);
    setSearching(true);
    timerRef.current = setTimeout(function () {
      fetch("/api/search?q=" + encodeURIComponent(search.trim()))
        .then(function (response) { if (!response.ok) throw new Error("Search failed"); return response.json(); })
        .then(function (data) { setResults(data.results || []); setSearching(false); })
        .catch(function () { setResults([]); setSearching(false); });
    }, 260);
    return function () { clearTimeout(timerRef.current); };
  }, [search]);

  useEffect(function () {
    if (!sceneRef.current || !window.THREE || !window.THREE.OrbitControls) return;
    const THREE = window.THREE;
    const host = sceneRef.current;
    const scene = new THREE.Scene();
    scene.background = new THREE.Color("#050713");
    // The map spans light-years to millions of light-years; fixed-distance fog would mislead.
    const camera = new THREE.PerspectiveCamera(49, host.clientWidth / Math.max(host.clientHeight, 1), 1e-7, 1e10);
    camera.position.set(0, 6, 14);
    const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: "high-performance" });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setSize(host.clientWidth, host.clientHeight);
    renderer.outputEncoding = THREE.sRGBEncoding;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.17;
    renderer.domElement.className = "space-canvas";
    host.appendChild(renderer.domElement);
    const controls = new THREE.OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true;
    controls.dampingFactor = 0.055;
    controls.rotateSpeed = 0.46;
    controls.zoomSpeed = 0.8;
    controls.minDistance = 3;
    controls.maxDistance = 180;
    controls.target.set(0, 0, 0);
    scene.add(new THREE.AmbientLight(0x9daee2, 1.3));
    const key = new THREE.PointLight(0xeaf2ff, 1450, 200, 1.7);
    key.position.set(-13, 12, 12);
    scene.add(key);
    const fill = new THREE.PointLight(0x6d7bff, 480, 160, 2);
    fill.position.set(18, -8, -10);
    scene.add(fill);

    const labelLayer = document.createElement("div");
    labelLayer.className = "object-label-layer";
    host.appendChild(labelLayer);
    const raycaster = new THREE.Raycaster();
    const pointer = new THREE.Vector2();
    const clickable = [];
    const nodes = new Map();
    const animated = [];
    const orbits = [];
    const orbitRadii = new Set();
    let scaleMode = "universe";
    let raf = 0;
    let cameraGoal = null;
    let targetGoal = null;
    let dragStart = null;

    function randomFor(seed) {
      let value = 0;
      String(seed).split("").forEach(function (char) { value = (value * 31 + char.charCodeAt(0)) >>> 0; });
      return function () { value = (value * 1664525 + 1013904223) >>> 0; return value / 4294967296; };
    }
    const random = randomFor("astra-2026-star-map");
    const starPositions = new Float32Array(9500 * 3);
    const starColors = new Float32Array(9500 * 3);
    for (let i = 0; i < 9500; i++) {
      const rad = 70 + random() * 430;
      const theta = random() * Math.PI * 2;
      const phi = Math.acos(2 * random() - 1);
      starPositions[i * 3] = rad * Math.sin(phi) * Math.cos(theta);
      starPositions[i * 3 + 1] = rad * Math.cos(phi);
      starPositions[i * 3 + 2] = rad * Math.sin(phi) * Math.sin(theta);
      const palette = random() > 0.75 ? [0.71, 0.77, 1] : random() > 0.5 ? [1, 0.83, 0.69] : [0.9, 0.92, 1];
      const glow = 0.4 + random() * 0.6;
      starColors[i * 3] = palette[0] * glow;
      starColors[i * 3 + 1] = palette[1] * glow;
      starColors[i * 3 + 2] = palette[2] * glow;
    }
    const starGeometry = new THREE.BufferGeometry();
    starGeometry.setAttribute("position", new THREE.BufferAttribute(starPositions, 3));
    starGeometry.setAttribute("color", new THREE.BufferAttribute(starColors, 3));
    const starfield = new THREE.Points(starGeometry, new THREE.PointsMaterial({ size: 0.17, vertexColors: true, transparent: true, opacity: 0.22, sizeAttenuation: true, depthWrite: false }));
    scene.add(starfield);
    const dustPositions = new Float32Array(1800 * 3);
    for (let i = 0; i < 1800; i++) {
      dustPositions[i * 3] = (random() - 0.5) * 160;
      dustPositions[i * 3 + 1] = (random() - 0.5) * 50;
      dustPositions[i * 3 + 2] = -25 - random() * 100;
    }
    const dustGeometry = new THREE.BufferGeometry();
    dustGeometry.setAttribute("position", new THREE.BufferAttribute(dustPositions, 3));
    scene.add(new THREE.Points(dustGeometry, new THREE.PointsMaterial({ color: 0x7888ca, size: 0.11, transparent: true, opacity: 0.3, depthWrite: false })));

    function canvasTexture(item) {
      const canvas = document.createElement("canvas");
      canvas.width = 512;
      canvas.height = 256;
      const ctx = canvas.getContext("2d");
      const rand = randomFor(item.id);
      const colors = item.textureColors || [item.color || "#8098cf", "#18243e"];
      const gradient = ctx.createLinearGradient(0, 0, 0, 256);
      gradient.addColorStop(0, colors[0]);
      gradient.addColorStop(1, colors[1]);
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, 512, 256);
      if (["Jupiter", "Saturn", "Uranus", "Neptune"].includes(item.name)) {
        for (let i = 0; i < (item.name === "Jupiter" ? 24 : 38); i++) {
          const y = i * 256 / (item.name === "Jupiter" ? 24 : 38);
          ctx.globalAlpha = 0.12 + rand() * 0.3;
          ctx.fillStyle = i % 2 ? "#fff2df" : "#162441";
          ctx.beginPath();
          ctx.moveTo(0, y);
          for (let x = 0; x <= 512; x += 12) ctx.lineTo(x, y + Math.sin(x / 48 + i) * (1 + rand() * 5));
          ctx.lineTo(512, y + 256 / 24);
          ctx.lineTo(0, y + 256 / 24);
          ctx.closePath();
          ctx.fill();
        }
        if (item.name === "Jupiter") {
          ctx.globalAlpha = 0.8;
          ctx.fillStyle = "#c66c53";
          ctx.beginPath();
          ctx.ellipse(344, 154, 35, 15, -0.15, 0, Math.PI * 2);
          ctx.fill();
        }
      } else {
        const count = item.category === "moon" || item.category === "asteroid" ? 100 : 56;
        for (let i = 0; i < count; i++) {
          ctx.globalAlpha = 0.05 + rand() * 0.19;
          ctx.fillStyle = rand() > 0.5 ? "#f3ecff" : "#101729";
          ctx.beginPath();
          ctx.ellipse(rand() * 512, rand() * 256, 2 + rand() * 14, 1 + rand() * 8, rand() * 3, 0, Math.PI * 2);
          ctx.fill();
        }
      }
      ctx.globalAlpha = 1;
      const texture = new THREE.CanvasTexture(canvas);
      texture.encoding = THREE.sRGBEncoding;
      return texture;
    }
    function halo(parent, color, size) {
      const canvas = document.createElement("canvas");
      canvas.width = canvas.height = 128;
      const ctx = canvas.getContext("2d");
      const gradient = ctx.createRadialGradient(64, 64, 1, 64, 64, 64);
      gradient.addColorStop(0, color);
      gradient.addColorStop(0.25, color + "7a");
      gradient.addColorStop(1, color + "00");
      ctx.fillStyle = gradient;
      ctx.fillRect(0, 0, 128, 128);
      const texture = new THREE.CanvasTexture(canvas);
      const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: texture, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, opacity: 0.8 }));
      sprite.scale.set(size * 5, size * 5, 1);
      parent.add(sprite);
    }
    function makeGalaxy(parent, item, size) {
      const rand = randomFor(item.id);
      const count = 900;
      const positions = new Float32Array(count * 3);
      const colors = new Float32Array(count * 3);
      const centerColor = new THREE.Color(item.color || "#e9c1ff");
      const outerColor = new THREE.Color("#637bd1");
      for (let i = 0; i < count; i++) {
        const arm = i % 4;
        const t = rand();
        const radius = 0.06 + Math.pow(t, 0.8) * size * 2.8;
        const angle = t * Math.PI * 5.5 + arm * Math.PI / 2 + (rand() - 0.5) * 0.85;
        positions[i * 3] = Math.cos(angle) * radius;
        positions[i * 3 + 1] = (rand() - 0.5) * size * 0.25 * (1 - t);
        positions[i * 3 + 2] = Math.sin(angle) * radius;
        const c = outerColor.clone().lerp(centerColor, 1 - t);
        colors[i * 3] = c.r; colors[i * 3 + 1] = c.g; colors[i * 3 + 2] = c.b;
      }
      const geo = new THREE.BufferGeometry();
      geo.setAttribute("position", new THREE.BufferAttribute(positions, 3));
      geo.setAttribute("color", new THREE.BufferAttribute(colors, 3));
      parent.add(new THREE.Points(geo, new THREE.PointsMaterial({ size: 0.058, vertexColors: true, transparent: true, opacity: 0.9, depthWrite: false })));
      const core = new THREE.Mesh(new THREE.SphereGeometry(size * 0.22, 20, 16), new THREE.MeshBasicMaterial({ color: item.color || "#e5c5ff" }));
      parent.add(core);
    }
    function makeNebula(parent, item, size) {
      const rand = randomFor(item.id);
      const count = 1300;
      const positions = new Float32Array(count * 3);
      const colors = new Float32Array(count * 3);
      const a = new THREE.Color(item.color || "#a18aff");
      const b = new THREE.Color("#5cafd3");
      for (let i = 0; i < count; i++) {
        const angle = rand() * Math.PI * 2;
        const radius = Math.pow(rand(), 0.56) * size * 1.65;
        positions[i * 3] = Math.cos(angle) * radius;
        positions[i * 3 + 1] = (rand() - 0.5) * size * 0.8;
        positions[i * 3 + 2] = Math.sin(angle) * radius * 0.8;
        const color = a.clone().lerp(b, rand());
        colors[i * 3] = color.r; colors[i * 3 + 1] = color.g; colors[i * 3 + 2] = color.b;
      }
      const geo = new THREE.BufferGeometry();
      geo.setAttribute("position", new THREE.BufferAttribute(positions, 3));
      geo.setAttribute("color", new THREE.BufferAttribute(colors, 3));
      parent.add(new THREE.Points(geo, new THREE.PointsMaterial({ size: 0.085, vertexColors: true, transparent: true, opacity: 0.66, blending: THREE.AdditiveBlending, depthWrite: false })));
    }
    function addOrbit(radius, center) {
      const points = [];
      for (let i = 0; i < 150; i++) {
        const t = i / 150 * Math.PI * 2;
        points.push(new THREE.Vector3(center[0] + Math.cos(t) * radius, center[1], center[2] + Math.sin(t) * radius));
      }
      const geo = new THREE.BufferGeometry().setFromPoints(points);
      const line = new THREE.LineLoop(geo, new THREE.LineBasicMaterial({ color: 0x7181b6, transparent: true, opacity: 0.23, depthWrite: false }));
      scene.add(line);
      orbits.push(line);
    }
    function makeNode(item) {
      if (!item || !item.id || nodes.has(item.id)) return nodes.get(item.id);
      if (!Array.isArray(item.position) || item.position.length !== 3 || item.map_status === "unplotted") return null;
      const radius = Math.max(0.025, Math.min(Number(item.size) || 0.08, 0.12));
      const group = new THREE.Group();
      group.position.fromArray(item.position);
      group.userData.item = item;
      let hit;
      if (item.category === "galaxy") {
        makeGalaxy(group, item, Math.max(0.65, radius * 1.45));
        hit = new THREE.Mesh(new THREE.SphereGeometry(radius * 2.4, 14, 12), new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false }));
        group.add(hit);
        animated.push({ group: group, kind: "galaxy" });
      } else if (item.category === "nebula" || item.category === "deep") {
        makeNebula(group, item, Math.max(0.8, radius * 1.75));
        hit = new THREE.Mesh(new THREE.SphereGeometry(radius * 2.1, 14, 12), new THREE.MeshBasicMaterial({ transparent: true, opacity: 0, depthWrite: false }));
        group.add(hit);
        animated.push({ group: group, kind: "nebula" });
      } else if (item.category === "black-hole") {
        hit = new THREE.Mesh(new THREE.SphereGeometry(radius * 0.88, 30, 22), new THREE.MeshBasicMaterial({ color: 0x020208, transparent: true, opacity: 0.98 }));
        group.add(hit);
        const ring = new THREE.Mesh(new THREE.TorusGeometry(radius * 1.55, radius * 0.16, 12, 84), new THREE.MeshBasicMaterial({ color: 0xd79c86, transparent: true, opacity: 0.87, side: THREE.DoubleSide }));
        ring.rotation.x = Math.PI / 2.5;
        group.add(ring);
        const ring2 = new THREE.Mesh(new THREE.TorusGeometry(radius * 1.9, radius * 0.055, 8, 84), new THREE.MeshBasicMaterial({ color: 0x8a80ec, transparent: true, opacity: 0.76, side: THREE.DoubleSide }));
        ring2.rotation.x = Math.PI / 2.5;
        ring2.rotation.y = 0.25;
        group.add(ring2);
        halo(group, item.color || "#a98dff", radius * 1.8);
        animated.push({ group: group, kind: "black-hole" });
      } else {
        const material = new THREE.MeshStandardMaterial({
          map: canvasTexture(item), roughness: item.category === "star" ? 0.35 : 0.9,
          metalness: 0.025, emissive: new THREE.Color(item.color || "#7585b9"),
          emissiveIntensity: item.category === "star" ? 0.75 : 0.035
        });
        hit = new THREE.Mesh(new THREE.SphereGeometry(radius, 32, 24), material);
        group.add(hit);
        if (item.category === "star") halo(group, item.color || "#ffd6a3", radius * 2.2);
        if (item.name === "Saturn") {
          const rings = new THREE.Mesh(new THREE.RingGeometry(radius * 1.25, radius * 2.05, 80), new THREE.MeshStandardMaterial({ color: 0xd9c5a7, side: THREE.DoubleSide, transparent: true, opacity: 0.68, roughness: 1 }));
          rings.rotation.x = Math.PI / 2;
          group.add(rings);
        }
        animated.push({ group: group, kind: item.category === "moon" ? "moon" : "planet" });
      }
      hit.userData.objectId = item.id;
      clickable.push(hit);
      scene.add(group);
      const label = document.createElement("button");
      label.type = "button";
      label.className = "sky-label";
      label.innerHTML = '<span></span>' + escapeHtml(item.name);
      label.title = "Explore " + item.name;
      label.addEventListener("click", function (event) { event.stopPropagation(); chooseObject(item); });
      labelLayer.appendChild(label);
      const node = { item: item, group: group, hit: hit, label: label, radius: radius, basePosition: item.position.slice() };
      nodes.set(item.id, node);
      if (item.map_frame === "solar-system" && item.orbit_radius_au && !orbitRadii.has(item.orbit_radius_au)) addOrbit(item.orbit_radius_au, [0, 0, 0]);
      return node;
    }
    function addCatalog(items) {
      (items || []).forEach(function (item) { if (Array.isArray(item.position)) makeNode(item); });
      if (Object.keys(ephemerisRef.current || {}).length) applyEphemeris(ephemerisRef.current);
      setFilter("all");
    }
    function isSolarSystem(node) {
      return node.item.map_frame === "solar-system" || node.item.system === "Solar System";
    }
    function setFilter(filter) {
      nodes.forEach(function (node) {
        const solar = isSolarSystem(node);
        const inFrame = scaleMode === "system" ? solar : (!solar || node.item.id === "sun");
        const inCategory = filter === "all" || node.item.category === filter || (filter === "planet" && node.item.category === "dwarf-planet");
        node.group.visible = inFrame && inCategory;
        const showLabel = node.group.visible && labelsOn && (scaleMode === "system" || !solar || node.item.id === "sun");
        node.label.style.display = showLabel ? "flex" : "none";
      });
      orbits.forEach(function (orbit) { orbit.visible = scaleMode === "system" && orbitsOn; });
    }
    function setScaleMode(mode) {
      scaleMode = mode === "system" ? "system" : "universe";
      nodes.forEach(function (node) {
        const solar = isSolarSystem(node);
        if (scaleMode === "system" && solar) {
          const local = node.item.local_position_au || node.item.position.map(function (value) { return value * 63241.077084; });
          node.group.position.fromArray(local);
        } else {
          node.group.position.fromArray(node.item.position);
        }
      });
      orbits.forEach(function (orbit) { orbit.visible = scaleMode === "system" && orbitsOn; });
      setFilter("all");
      cameraGoal = scaleMode === "system" ? new THREE.Vector3(0, 11, 37) : new THREE.Vector3(0, 6, 14);
      targetGoal = new THREE.Vector3(0, 0, 0);
    }
    function applyEphemeris(values) {
      Object.keys(values || {}).forEach(function (id) {
        const node = nodes.get(id);
        const vector = values[id];
        if (!node || !vector || !Array.isArray(vector.ly) || !Array.isArray(vector.au)) return;
        node.item.position = vector.ly;
        node.item.local_position_au = vector.au;
        node.item.position_source = vector.source || "NASA/JPL Horizons";
        node.item.position_accuracy = "JPL Horizons current heliocentric ICRF vector";
        node.item.map_status = "plotted";
        node.basePosition = vector.ly.slice();
        if (scaleMode === "system" && isSolarSystem(node)) node.group.position.fromArray(vector.au);
        else if (scaleMode === "universe") node.group.position.fromArray(vector.ly);
        node.group.userData.item = node.item;
      });
    }
    function focus(item) {
      const node = nodes.get(item.id);
      if (!node) return;
      const point = node.group.position.clone();
      const viewDirection = new THREE.Vector3(0.12, 0.24, 1).applyQuaternion(camera.quaternion).normalize();
      const cameraRight = new THREE.Vector3(1, 0, 0).applyQuaternion(camera.quaternion).normalize();
      const distance = scaleMode === "system" ? 5.2 : 7.0;
      targetGoal = point.clone().sub(cameraRight.multiplyScalar(Math.min(scaleMode === "system" ? 2 : 2.7, distance * 0.36)));
      cameraGoal = targetGoal.clone().add(viewDirection.multiplyScalar(distance));
    }
    function resize() {
      const width = Math.max(host.clientWidth, 1);
      const height = Math.max(host.clientHeight, 1);
      camera.aspect = width / height;
      camera.updateProjectionMatrix();
      renderer.setSize(width, height);
    }
    function render() {
      raf = requestAnimationFrame(render);
      controls.update();
      const viewRange = Math.max(camera.position.distanceTo(controls.target), 0.001);
      const nearPlane = Math.max(1e-8, viewRange * 1e-6);
      const farPlane = Math.max(1200, viewRange * 100);
      if (Math.abs(camera.near - nearPlane) > camera.near * 0.08 || Math.abs(camera.far - farPlane) > camera.far * 0.08) {
        camera.near = nearPlane;
        camera.far = farPlane;
        camera.updateProjectionMatrix();
      }
      if (cameraGoal && targetGoal) {
        camera.position.lerp(cameraGoal, 0.055);
        controls.target.lerp(targetGoal, 0.055);
        if (camera.position.distanceTo(cameraGoal) < 0.04 && controls.target.distanceTo(targetGoal) < 0.04) {
          cameraGoal = null;
          targetGoal = null;
        }
      }
      const time = performance.now() * 0.001;
      animated.forEach(function (object) {
        if (object.kind === "planet" || object.kind === "moon") object.group.rotation.y += 0.002;
        if (object.kind === "galaxy") object.group.rotation.y = Math.sin(time * 0.12) * 0.08;
        if (object.kind === "nebula") object.group.rotation.y = Math.sin(time * 0.08) * 0.04;
        if (object.kind === "black-hole") object.group.rotation.y += 0.0015;
      });
      nodes.forEach(function (node) {
        if (!node.group.visible || !labelsOn) { node.label.style.display = "none"; return; }
        const projected = node.group.position.clone();
        projected.y += node.radius * 1.45 + 0.32;
        projected.project(camera);
        const x = (projected.x * 0.5 + 0.5) * host.clientWidth;
        const y = (-projected.y * 0.5 + 0.5) * host.clientHeight;
        const inFrame = projected.z > -1 && projected.z < 1 && x > -100 && x < host.clientWidth + 100 && y > -35 && y < host.clientHeight + 35;
        node.label.style.display = inFrame ? "flex" : "none";
        node.label.style.left = x + "px";
        node.label.style.top = y + "px";
        node.label.classList.toggle("is-selected", Boolean(selectedRef.current && selectedRef.current.id === node.item.id));
      });
      starfield.rotation.y = time * 0.002;
      renderer.render(scene, camera);
    }
    function onPointerMove(event) {
      const rect = renderer.domElement.getBoundingClientRect();
      pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
      pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
      raycaster.setFromCamera(pointer, camera);
      const hits = raycaster.intersectObjects(clickable.filter(function (mesh) { return mesh.parent && mesh.parent.visible; }), false);
      renderer.domElement.style.cursor = hits.length ? "pointer" : "grab";
    }
    function onClick(event) {
      if (dragStart && Math.hypot(event.clientX - dragStart.x, event.clientY - dragStart.y) > 6) return;
      const rect = renderer.domElement.getBoundingClientRect();
      pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
      pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
      raycaster.setFromCamera(pointer, camera);
      const hits = raycaster.intersectObjects(clickable.filter(function (mesh) { return mesh.parent && mesh.parent.visible; }), false);
      if (hits.length) {
        const id = hits[0].object.userData.objectId;
        const node = nodes.get(id);
        if (node) chooseObject(node.item);
      }
    }
    function onDown(event) { dragStart = { x: event.clientX, y: event.clientY }; }
    renderer.domElement.addEventListener("pointerdown", onDown);
    renderer.domElement.addEventListener("pointermove", onPointerMove);
    renderer.domElement.addEventListener("click", onClick);
    window.addEventListener("resize", resize);
    const api = {
      addCatalog: addCatalog,
      filter: setFilter,
      focus: focus,
      scale: setScaleMode,
      ephemeris: applyEphemeris,
      reset: function () {
        setScaleMode("universe");
        cameraGoal = new THREE.Vector3(0, 6, 14);
        targetGoal = new THREE.Vector3(0, 0, 0);
      },
      zoom: function (delta) {
        const direction = camera.position.clone().sub(controls.target).normalize();
        const range = camera.position.distanceTo(controls.target);
        const adjusted = scaleMode === "system" ? delta : delta * Math.max(0.5, range * 0.12);
        camera.position.addScaledVector(direction, adjusted);
      },
      labels: function (value) {
        nodes.forEach(function (node) { node.label.style.display = value && node.group.visible ? "flex" : "none"; });
      },
      orbits: function (value) {
        orbits.forEach(function (orbit) { orbit.visible = value && scaleMode === "system"; });
      },
      dispose: function () {
        cancelAnimationFrame(raf);
        window.removeEventListener("resize", resize);
        renderer.domElement.removeEventListener("pointerdown", onDown);
        renderer.domElement.removeEventListener("pointermove", onPointerMove);
        renderer.domElement.removeEventListener("click", onClick);
        controls.dispose();
        renderer.dispose();
        host.innerHTML = "";
      }
    };
    sceneApi.current = api;
    addCatalog(catalog);
    catalog.filter(function (item) { return item.map_frame === "solar-system" && item.orbit_radius_au; })
      .map(function (item) { return item.orbit_radius_au; })
      .filter(function (radius, index, values) { return values.indexOf(radius) === index; })
      .forEach(function (radius) { if (!orbitRadii.has(radius)) addOrbit(radius, [0, 0, 0]); });
    orbits.forEach(function (orbit) { orbit.visible = false; });
    render();
    setSceneReady(true);
    return function () {
      api.dispose();
      sceneApi.current = null;
      setSceneReady(false);
    };
  }, []);

  useEffect(function () {
    if (sceneApi.current && catalog.length) {
      sceneApi.current.addCatalog(catalog);
      sceneApi.current.filter(category);
      sceneApi.current.labels(labelsOn);
      sceneApi.current.orbits(orbitsOn);
    }
  }, [catalog, category, labelsOn, orbitsOn]);

  function chooseObject(item) {
    if (!item) return;
    setSearchOpen(false);
    setSearch(item.name || "");
    setActiveTab("Overview");
    setSelected(item);
    const nextScale = item.map_frame === "solar-system" || item.system === "Solar System" ? "system" : "universe";
    setViewScale(nextScale);
    if (sceneApi.current) {
      if (Array.isArray(item.position)) sceneApi.current.addCatalog([item]);
      sceneApi.current.scale(nextScale);
      sceneApi.current.filter("all");
      if (Array.isArray(item.position)) sceneApi.current.focus(item);
    }
    setCategory("all");
    if (item.external && !item.descriptionLong && !item.facts) {
      setLoadingDetail(true);
      fetch("/api/lookup?title=" + encodeURIComponent(item.name))
        .then(function (response) { if (!response.ok) throw new Error("Could not load reference"); return response.json(); })
        .then(function (data) { setSelected(function (current) { return current && current.id === item.id ? Object.assign({}, current, data.object || data) : current; }); })
        .catch(function () { toast("Reference details could not be loaded. The source links are still available."); })
        .finally(function () { setLoadingDetail(false); });
    }
  }
  function closeDetails() {
    setSelected(null);
    setViewScale("universe");
    if (sceneApi.current) sceneApi.current.reset();
  }
  function submitSearch(event) {
    if (event) event.preventDefault();
    if (results.length) chooseObject(results[0]);
    else if (search.trim()) {
      fetch("/api/lookup?title=" + encodeURIComponent(search.trim()))
        .then(function (response) { if (!response.ok) throw new Error("No result"); return response.json(); })
        .then(function (data) { chooseObject(data.object || data); })
        .catch(function () { toast("No result found. Try a more specific astronomical name."); });
    }
  }
  function toggleLabels() {
    setLabelsOn(function (value) {
      const next = !value;
      if (sceneApi.current) sceneApi.current.labels(next);
      return next;
    });
  }
  function toggleOrbits() {
    setOrbitsOn(function (value) {
      const next = !value;
      if (sceneApi.current) sceneApi.current.orbits(next);
      return next;
    });
  }
  const facts = selected ? (selected.facts || {}) : {};
  const sources = selected ? (selected.sources || []) : [];
  const related = selected && Array.isArray(selected.related) ? selected.related.map(function (id) {
    return catalog.find(function (item) { return item.id === id; });
  }).filter(Boolean).slice(0, 5) : [];
  const description = selected && (selected.description || selected.descriptionLong || selected.extract);
  const objectType = selected ? (selected.type || selected.category || "Celestial object") : "";
  return (
    <div className={"app-shell" + (selected ? " has-selection" : "")}>
      <div className="universe" ref={sceneRef} aria-label="Interactive 3D universe"></div>
      <div className="scene-overlay"></div>
      <header className="topbar">
        <button className="brand" onClick={closeDetails} aria-label="Return to universe overview">
          <span className="brand-emblem"><i></i><b></b><span></span></span>
          <span className="brand-wordmark">ASTRA<small>UNIVERSE EXPLORER</small></span>
        </button>
        <form className="search-box" onSubmit={submitSearch}>
          <svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="10.7" cy="10.7" r="6.4"></circle><path d="m15.6 15.6 4.5 4.5"></path></svg>
          <input value={search} onChange={function (event) { setSearch(event.target.value); setSearchOpen(true); }} onFocus={function () { setSearchOpen(true); }} onKeyDown={function (event) { if (event.key === "Escape") setSearchOpen(false); }} placeholder="Search planets, stars, galaxies..." aria-label="Search the universe" autoComplete="off" />
          {search ? <button className="clear-search" type="button" onClick={function () { setSearch(""); setSearchOpen(false); }} aria-label="Clear search">×</button> : <kbd>/</kbd>}
          {searchOpen && search.trim() && <div className="search-dropdown">
            <div className="dropdown-heading">{searching ? "SEARCHING THE COSMOS" : "CATALOG + KNOWLEDGE INDEX"}<span>{searching ? "···" : results.length + " RESULTS"}</span></div>
            {searching && <div className="search-message"><span className="spinner"></span> Looking through the catalog and references…</div>}
            {!searching && results.map(function (item) {
              return <button type="button" className="search-result" key={item.id} onClick={function () { chooseObject(item); }}>
                <span className={"result-icon " + (item.category || "reference")}>{ICONS[item.category] || "↗"}</span>
                <span className="result-text"><strong>{item.name}</strong><small>{item.type || item.category || "Reference"}{item.subtitle ? " · " + item.subtitle : item.host ? " · " + item.host : ""}</small></span>
                <span className="result-arrow">↗</span>
              </button>;
            })}
            {!searching && !results.length && <div className="search-message">No exact match yet. Press Enter to look up a wider reference.</div>}
            {!searching && <div className="dropdown-footer">ENTER TO OPEN FIRST RESULT <span>WIKIPEDIA · NASA · ESA</span></div>}
          </div>}
        </form>
        <div className="header-tools"><span className="system-status"><i></i>{apiStatus}</span><button className="round-tool" title="Reset universe view" onClick={function () { closeDetails(); setCategory("all"); if (sceneApi.current) sceneApi.current.reset(); }} aria-label="Reset universe"><svg viewBox="0 0 24 24"><path d="M4 11a8 8 0 1 0 2.1-5.4L3.5 8.2"></path><path d="M3.5 3.6v4.8h4.8"></path></svg></button></div>
      </header>
      <main className="main-content">
        {!selected && <section className="hero-copy">
          <div className="eyebrow"><span></span> A MAP OF THE KNOWN COSMOS</div>
          <h1>Look beyond<br />the <em>ordinary.</em></h1>
          <p>Billions of worlds. Uncountable stars.<br />One universe waiting to be explored.</p>
          <div className="hero-actions"><button className="primary-action" onClick={function () { const earth = catalog.find(function (item) { return item.id === "earth"; }); if (earth) chooseObject(earth); }}><span>Explore Earth</span><b>↗</b></button><span className="drag-hint"><span>↔</span> DRAG TO ORBIT</span></div>
          <div className="hero-foot"><span className="live-star"></span> INTERACTIVE 3D MAP <b>·</b> POSITIONS ILLUSTRATIVE</div>
        </section>}
        <div className={"scene-instructions" + (selected ? " hidden" : "")}><span className="mouse-outline"><i></i></span><span>DRAG TO EXPLORE <b>·</b> SCROLL TO TRAVEL</span></div>
        <div className="sky-legend"><span><i className="legend-planet"></i> CATALOG OBJECTS</span><span><i className="legend-star"></i> GAIA DR3 STARS</span><span><i className="legend-galaxy"></i> BACKDROP / DECORATIVE</span></div>
        <div className="scale-ribbon"><small>SPATIAL REFERENCE</small><strong>{viewScale === "system" ? "1 SCENE UNIT = 1 AU" : "1 SCENE UNIT = 1 LIGHT-YEAR"}</strong><button onClick={function () { const next = viewScale === "system" ? "universe" : "system"; setViewScale(next); if (sceneApi.current) sceneApi.current.scale(next); }}>Switch to {viewScale === "system" ? "universe" : "Solar System"} view ↗</button></div>
      </main>
      {selected && <aside className="detail-panel" aria-label={"Details for " + selected.name}>
        <div className="panel-header"><span className="micro-label"><i></i> CELESTIAL OBJECT / PROFILE</span><button className="close-panel" onClick={closeDetails} aria-label="Close details">×</button></div>
        <div className="detail-title"><span className="object-kind">{String(objectType).toUpperCase()}</span><h2>{selected.name}</h2><p>{selected.subtitle || selected.host || selected.system || "A destination in the observable universe"}</p></div>
        <div className="object-portrait">
          <div className={"portrait-orb " + (selected.category || "planet")} style={{ "--orb": selected.color || "#a9a4ff" }}><span></span><i></i></div>
          <div className="portrait-orbit portrait-orbit-a"></div><div className="portrait-orbit portrait-orbit-b"></div>
          <span className="portrait-caption">{String(selected.system || selected.category || "DEEP SPACE").toUpperCase()} / FIELD NOTES</span>
        </div>
        <div className="detail-tabs"><button className={activeTab === "Overview" ? "active" : ""} onClick={function () { setActiveTab("Overview"); }}>Overview</button><button className={activeTab === "Measurements" ? "active" : ""} onClick={function () { setActiveTab("Measurements"); }}>Measurements</button><button className={activeTab === "Sources" ? "active" : ""} onClick={function () { setActiveTab("Sources"); }}>Sources <span>{sources.length}</span></button></div>
        <div className={"coordinate-note " + ((!Array.isArray(selected.position) || selected.map_status === "unplotted") ? "unplotted" : "plotted")}>
          <span></span><div><strong>{(!Array.isArray(selected.position) || selected.map_status === "unplotted") ? "Not placed on the 3D map" : (viewScale === "system" ? "Solar System spatial frame · AU" : "Universe spatial frame · light-years")}</strong><small>{(!Array.isArray(selected.position) || selected.map_status === "unplotted") ? (selected.position_accuracy || "The source does not provide a reliable 3D position; no coordinates have been invented.") : (selected.position_source || "Catalog coordinates and distance")}</small></div>
        </div>
        {loadingDetail && <div className="inline-loading"><span className="spinner"></span> Fetching reference details…</div>}
        {activeTab === "Overview" && <><p className="object-description">{description || "This entry is indexed for exploration. Open the references below for additional scientific context."}</p><div className="section-title"><span>AT A GLANCE</span><i></i><small>KEY FACTS</small></div><div className="fact-grid">
          {Object.entries(facts).slice(0, 6).map(function (entry) { return <div className="fact-card" key={entry[0]}><span>{entry[0]}</span><strong>{String(entry[1])}</strong></div>; })}
          {!Object.keys(facts).length && <div className="no-facts">No structured measurements for this external entry yet. See linked sources.</div>}
        </div></>}
        {activeTab === "Measurements" && <><div className="section-title"><span>OBSERVATIONAL DATA</span><i></i></div><div className="fact-grid measurement-grid">
          {Object.entries(facts).map(function (entry) { return <div className="fact-card" key={entry[0]}><span>{entry[0]}</span><strong>{String(entry[1])}</strong></div>; })}
          {!Object.keys(facts).length && <div className="no-facts">Structured measurements are not available from this record.</div>}
        </div><p className="disclaimer">Values are presented as supplied by the linked catalog; estimated quantities and discovery status can change with new observations.</p></>}
        {activeTab === "Sources" && <p className="object-description">Follow the references to read the source descriptions, data releases, and mission findings. A source link opens in a new tab.</p>}
        <div className="section-title"><span>EXPLORE THE SOURCES</span><i></i></div>
        <div className="source-list">{sources.map(function (source, index) {
          const url = typeof source === "string" ? source : source.url;
          if (!url) return null;
          let domain = "";
          try { domain = new URL(url).hostname.replace(/^www\./, ""); } catch (_) { domain = "Reference"; }
          return <a className="source-card" key={url + index} href={url} target="_blank" rel="noopener noreferrer"><span className="source-emblem">↗</span><span className="source-copy"><strong>{typeof source === "string" ? domain : (source.label || source.publisher || domain)}</strong><small>{typeof source === "string" ? domain : (source.publisher || domain)}</small></span><span className="source-external">↗</span></a>;
        })}{!sources.length && <p className="no-facts">Search the knowledge index for external source references.</p>}</div>
        {related.length > 0 && <><div className="section-title"><span>CONNECTED OBJECTS</span><i></i></div><div className="related-list">{related.map(function (item) { return <button key={item.id} onClick={function () { chooseObject(item); }}><i style={{ "--orb": item.color || "#ada6ff" }}></i>{item.name}<span>↗</span></button>; })}</div></>}
        <div className="panel-note"><span>✳</span> Visual scale and placement are illustrative; facts link back to scientific references.</div>
      </aside>}
      <section className="explorer-dock">
        <div className="dock-heading"><div><span className="dock-eyebrow">YOUR NEXT DESTINATION</span><h2>Explore the cosmos <em>↘</em></h2></div><span className="object-count">{catalog.length} MAPPED ENTRIES</span></div>
        <div className="category-row">{CATEGORIES.map(function (item) { return <button key={item[0]} className={"category-pill" + (category === item[0] ? " active" : "")} onClick={function () { setCategory(item[0]); if (sceneApi.current) sceneApi.current.filter(item[0]); }}><span>{ICONS[item[0]]}</span>{item[1]}</button>; })}</div>
        <div className="destination-row">{visibleCatalog.slice(0, 8).map(function (item) {
          return <button key={item.id} className={"destination" + (selected && selected.id === item.id ? " chosen" : "")} onClick={function () { chooseObject(item); }}><span className={"destination-icon " + item.category} style={{ "--orb": item.color || "#9e9eff" }}><i></i></span><span className="destination-copy"><small>{String(item.type || item.category || "OBJECT").toUpperCase()}</small><strong>{item.name}</strong></span><span className="destination-arrow">↗</span></button>;
        })}</div>
        <div className="dock-footer"><span><i></i> LIVE CATALOGS · MAPPED ENTRIES {catalog.length}</span><span>DRAG TO ORBIT <b>·</b> SCROLL TO ZOOM</span><div className="scene-actions"><button onClick={function () { if (sceneApi.current) sceneApi.current.zoom(-3); }} title="Zoom in" aria-label="Zoom in">+</button><button onClick={function () { if (sceneApi.current) sceneApi.current.zoom(3); }} title="Zoom out" aria-label="Zoom out">−</button><button className={labelsOn ? "selected" : ""} onClick={toggleLabels} title="Toggle labels" aria-label="Toggle labels">T</button><button className={orbitsOn ? "selected" : ""} onClick={toggleOrbits} title="Toggle orbit paths" aria-label="Toggle orbit paths">◎</button></div></div>
      </section>
      <div className="bottom-credit"><span></span> MULTI-CATALOG SKY MAP <b>/</b> MARKER SIZES EXAGGERATED FOR VISIBILITY</div>
      <div className={"toast" + (notice ? " visible" : "")} role="status">{notice}</div>
      {!sceneReady && <div className="scene-loading"><span className="loading-orbit"></span><p>INITIALIZING THE COSMOS</p><small>Preparing your 3D observatory</small></div>}
    </div>
  );
}
function escapeHtml(value) {
  return String(value == null ? "" : value).replace(/[&<>"']/g, function (character) {
    return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[character];
  });
}

ReactDOM.createRoot(document.getElementById("root")).render(<App />);
