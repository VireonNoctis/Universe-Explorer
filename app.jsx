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
  const [exoCursor, setExoCursor] = useState("");
  const [exoHasMore, setExoHasMore] = useState(false);
  const [exoLoading, setExoLoading] = useState(false);
  const [exoLoadedCount, setExoLoadedCount] = useState(0);
  const [archiveOpen, setArchiveOpen] = useState(false);
  const [archiveMode, setArchiveMode] = useState("coverage");
  const [archiveRows, setArchiveRows] = useState([]);
  const [archiveLoading, setArchiveLoading] = useState(false);
  const [archiveError, setArchiveError] = useState("");
  const [archiveOffset, setArchiveOffset] = useState(0);
  const [archiveCursor, setArchiveCursor] = useState("");
  const [archiveHasMore, setArchiveHasMore] = useState(false);
  const [archiveKind, setArchiveKind] = useState("all");
  const [archiveNeoOnly, setArchiveNeoOnly] = useState(false);
  const [archiveQuery, setArchiveQuery] = useState("");
  const [archiveMediaQuery, setArchiveMediaQuery] = useState("");
  const [archiveMediaType, setArchiveMediaType] = useState("image");
  const [researchQuery, setResearchQuery] = useState("");
  const [researchPage, setResearchPage] = useState(0);
  const [approachDays, setApproachDays] = useState("90");
  const [approachDistance, setApproachDistance] = useState("0.05");
  const [fireballDateMin, setFireballDateMin] = useState("");
  const [sentryProbabilityMin, setSentryProbabilityMin] = useState("");
  const [coverage, setCoverage] = useState(null);
  const [coverageLoading, setCoverageLoading] = useState(false);
  const [coverageError, setCoverageError] = useState("");
  const [apiStatus, setApiStatus] = useState("CONNECTING");
  const [notice, setNotice] = useState("");
  const [activeTab, setActiveTab] = useState("Overview");
  const sceneRef = useRef(null);
  const sceneApi = useRef(null);
  const timerRef = useRef(null);
  const noticeTimer = useRef(null);
  const selectedRef = useRef(null);
  const ephemerisRef = useRef({});
  const skyConesRef = useRef(new Set());
  selectedRef.current = selected;

  const visibleCatalog = useMemo(function () {
    if (category === "all") return catalog;
    return catalog.filter(function (item) {
      return item.category === category || (category === "planet" && item.category === "dwarf-planet");
    });
  }, [catalog, category]);
  const mappedCount = useMemo(function () {
    return catalog.filter(function (item) { return Array.isArray(item.position) && item.position.length === 3 && item.map_status !== "unplotted"; }).length;
  }, [catalog]);

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
            setCatalog(function (previous) {
              return previous.map(function (item) {
                const position = ephemerisRef.current[item.id];
                if (!position || !Array.isArray(position.au) || !Array.isArray(position.ly)) return item;
                return Object.assign({}, item, {
                  position: position.ly, local_position_au: position.au,
                  distance_from_sun_au: Math.hypot.apply(null, position.au),
                  position_source: position.source || "NASA/JPL Horizons",
                  position_accuracy: "JPL Horizons current heliocentric ICRF vector",
                  map_status: "plotted"
                });
              });
            });
            setSelected(function (current) {
              const position = current && ephemerisRef.current[current.id];
              return position ? Object.assign({}, current, {
                position: position.ly, local_position_au: position.au,
                distance_from_sun_au: Math.hypot.apply(null, position.au),
                position_source: position.source || "NASA/JPL Horizons",
                position_accuracy: "JPL Horizons current heliocentric ICRF vector",
                map_status: "plotted"
              }) : current;
            });
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
    controls.minDistance = 0.1;
    controls.maxDistance = 1e10;
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
      if (!item || !item.id) return null;
      const existing = nodes.get(item.id);
      if (existing) {
        existing.item = Object.assign({}, existing.item, item);
        existing.group.userData.item = existing.item;
        existing.hit.userData.objectId = item.id;
        if (Array.isArray(item.position) && item.position.length === 3 && item.map_status !== "unplotted") {
          if (scaleMode === "system" && (item.map_frame === "solar-system" || item.system === "Solar System")) {
            const local = item.local_position_au || item.position.map(function (value) { return value * 63241.077084; });
            existing.group.position.fromArray(local);
          } else {
            existing.group.position.fromArray(item.position);
          }
          existing.basePosition = item.position.slice();
          existing.group.visible = true;
        } else {
          existing.group.visible = false;
          existing.label.style.display = "none";
        }
        existing.label.innerHTML = '<span></span>' + escapeHtml(existing.item.name);
        existing.label.title = "Explore " + existing.item.name;
        return existing;
      }
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
      label.addEventListener("click", function (event) { event.stopPropagation(); const current = nodes.get(item.id); if (current) chooseObject(current.item); });
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
      controls.minDistance = scaleMode === "system" ? 0.02 : 0.1;
      controls.maxDistance = scaleMode === "system" ? 160 : 1e10;
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
    function fitVisible() {
      const visible = Array.from(nodes.values()).filter(function (node) { return node.group.visible; });
      if (!visible.length) return;
      const minimum = new THREE.Vector3(Infinity, Infinity, Infinity);
      const maximum = new THREE.Vector3(-Infinity, -Infinity, -Infinity);
      visible.forEach(function (node) {
        minimum.min(node.group.position);
        maximum.max(node.group.position);
      });
      const center = minimum.clone().add(maximum).multiplyScalar(0.5);
      const span = maximum.clone().sub(minimum).length();
      const distance = Math.max(scaleMode === "system" ? 8 : 7, span * 1.65 + 3);
      targetGoal = center;
      const viewDirection = new THREE.Vector3(0.18, 0.24, 1).applyQuaternion(camera.quaternion).normalize();
      cameraGoal = center.clone().add(viewDirection.multiplyScalar(distance));
      if (scaleMode === "system") controls.maxDistance = Math.max(160, distance * 2.5);
      else controls.maxDistance = Math.max(1e10, distance * 2.5);
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
      fit: fitVisible,
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
        const adjusted = delta * Math.max(0.02, range * 0.12);
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

  function loadExoplanetPage(reset) {
    if (exoLoading) return;
    const cursor = reset ? "" : exoCursor;
    setExoLoading(true);
    const url = "/api/archive/exoplanets?limit=40" + (cursor ? "&after=" + encodeURIComponent(cursor) : "");
    fetch(url)
      .then(function (response) {
        if (!response.ok) throw new Error("NASA Exoplanet Archive is unavailable");
        return response.json();
      })
      .then(function (data) {
        const incoming = Array.isArray(data.objects) ? data.objects : [];
        setCatalog(function (previous) {
          const base = reset ? previous.filter(function (item) { return item.catalog_source !== "NASA Exoplanet Archive"; }) : previous;
          const ids = new Set(base.map(function (item) { return item.id; }));
          return base.concat(incoming.filter(function (item) { return !ids.has(item.id); }));
        });
        setExoCursor(data.next_cursor || "");
        setExoHasMore(Boolean(data.has_more));
        setExoLoadedCount(function (previous) { return (reset ? 0 : previous) + incoming.length; });
        setApiStatus("NASA EXOPLANET ARCHIVE");
        if (!incoming.length && data.source_status !== "ok") toast("NASA Exoplanet Archive is temporarily unavailable.");
        else if (incoming.length) toast("Loaded " + incoming.length + " archive records.");
      })
      .catch(function () { toast("NASA Exoplanet Archive is unavailable. Local and federated search still work."); })
      .finally(function () { setExoLoading(false); });
  }

  function loadCoverage() {
    if (coverageLoading) return;
    setCoverageLoading(true);
    setCoverageError("");
    fetch("/api/coverage")
      .then(function (response) { if (!response.ok) throw new Error("Coverage service unavailable"); return response.json(); })
      .then(function (data) { setCoverage(data); setApiStatus("CATALOG COVERAGE"); })
      .catch(function () { setCoverageError("The source registry is temporarily unavailable. Local browsing and search can still work."); })
      .finally(function () { setCoverageLoading(false); });
  }

  function loadArchive(mode, reset) {
    const target = mode || archiveMode;
    if (archiveLoading) return;
    if (target === "coverage") {
      setArchiveMode("coverage");
      if (!coverage && !coverageLoading) loadCoverage();
      return;
    }
    const restart = reset !== false;
    const startOffset = restart ? 0 : archiveOffset;
    const cursor = restart ? "" : archiveCursor;
    const pageNumber = restart ? 1 : researchPage + 1;
    setArchiveMode(target);
    setArchiveLoading(true);
    setArchiveError("");
    if (restart) setArchiveRows([]);
    let url = "";
    if (target === "exoplanets") {
      url = "/api/archive/exoplanets?limit=40" +
        (cursor ? "&after=" + encodeURIComponent(cursor) : "") +
        (archiveQuery.trim() ? "&q=" + encodeURIComponent(archiveQuery.trim()) : "");
    } else if (target === "small-bodies") {
      url = "/api/archive/small-bodies?limit=40&offset=" + startOffset +
        "&kind=" + encodeURIComponent(archiveKind) +
        (archiveNeoOnly ? "&neo=1" : "");
    } else if (target === "close-approaches") {
      url = "/api/close-approaches?days=" + encodeURIComponent(approachDays) +
        "&distance=" + encodeURIComponent(approachDistance) + "&limit=40";
    } else if (target === "gaia") {
      url = "/api/sky?limit=450";
    } else if (target === "fireballs") {
      url = "/api/fireballs?limit=50" + (fireballDateMin ? "&date-min=" + encodeURIComponent(fireballDateMin) : "");
    } else if (target === "impact-monitor") {
      url = "/api/impact-monitor?limit=250" + (sentryProbabilityMin ? "&probability-min=" + encodeURIComponent(sentryProbabilityMin) : "");
    } else if (target === "media") {
      const mediaTerm = archiveMediaQuery.trim() || (selected && selected.name) || "galaxy";
      url = "/api/media?q=" + encodeURIComponent(mediaTerm) + "&limit=12&type=" + encodeURIComponent(archiveMediaType);
    } else if (target === "research") {
      const researchTerm = researchQuery.trim() || (selected && selected.name) || "exoplanet atmosphere";
      url = "/api/research?q=" + encodeURIComponent(researchTerm) + "&limit=10&page=" + pageNumber;
    } else {
      setArchiveLoading(false);
      return;
    }
    fetch(url)
      .then(function (response) {
        if (!response.ok) throw new Error("The archive returned HTTP " + response.status);
        return response.json();
      })
      .then(function (data) {
        if (data.source_status === "unavailable") throw new Error("This archive is temporarily unavailable. Try again shortly.");
        const incoming = ["close-approaches", "fireballs"].includes(target) ? (data.events || []) : ["media", "research"].includes(target) ? (data.items || []) : (data.objects || []);
        setArchiveRows(function (previous) {
          const base = restart ? [] : previous;
          const ids = new Set(base.map(function (item) { return item.id; }));
          return base.concat(incoming.filter(function (item) { return !ids.has(item.id); }));
        });
        if (target === "small-bodies") setArchiveOffset(startOffset + incoming.length);
        if (target === "exoplanets") setArchiveCursor(data.next_cursor || "");
        if (target === "research") setResearchPage(pageNumber);
        setArchiveHasMore(["small-bodies", "exoplanets", "research"].includes(target) ? Boolean(data.has_more) : false);
        if (!["close-approaches", "fireballs", "media", "research"].includes(target)) {
          setCatalog(function (previous) {
            const ids = new Set(previous.map(function (item) { return item.id; }));
            return previous.concat(incoming.filter(function (item) { return !ids.has(item.id); }));
          });
        }
        setApiStatus(target === "exoplanets" ? "NASA EXOPLANET ARCHIVE" : target === "small-bodies" || target === "close-approaches" || target === "fireballs" || target === "impact-monitor" ? "NASA/JPL DATA" : target === "media" ? "NASA MEDIA LIBRARY" : target === "research" ? "NASA RESEARCH SERVER" : "ESA GAIA DR3");
        if (!incoming.length) setArchiveError("No records were returned for this page or filter. Try different search criteria.");
      })
      .catch(function (error) { setArchiveError(error.message || "Could not reach this source."); })
      .finally(function () { setArchiveLoading(false); });
  }

  function selectArchiveItem(item) {
    if (!item) return;
    setArchiveOpen(false);
    if (item.catalog_source === "JPL Small-Body Database" || item.catalog_source === "NASA/JPL Sentry" || item.object_query) {
      chooseObject(Object.assign({}, item, {
        object_query: item.pdes || item.object_query || item.designation,
        catalog_source: item.catalog_source || "JPL Small-Body Database",
        pdes: item.pdes || item.object_query || item.designation,
        map_frame: "solar-system",
        system: "Solar System",
        category: "asteroid",
        map_status: item.map_status || "unplotted"
      }));
      return;
    }
    chooseObject(item);
  }

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
    if (item.ra_deg !== null && item.ra_deg !== undefined && item.dec_deg !== null && item.dec_deg !== undefined && Number.isFinite(Number(item.ra_deg)) && Number.isFinite(Number(item.dec_deg))) {
      const tileKey = Math.round(Number(item.ra_deg) * 2) + ":" + Math.round(Number(item.dec_deg) * 2);
      if (!skyConesRef.current.has(tileKey)) {
        skyConesRef.current.add(tileKey);
        const coneUrl = "/api/sky?ra=" + encodeURIComponent(item.ra_deg) + "&dec=" + encodeURIComponent(item.dec_deg) + "&radius=1.2&limit=150";
        fetch(coneUrl)
          .then(function (response) { if (!response.ok) throw new Error("Sky cone unavailable"); return response.json(); })
          .then(function (sky) {
            const incoming = (sky.objects || []).filter(function (star) { return Array.isArray(star.position); });
            setCatalog(function (previous) {
              const ids = new Set(previous.map(function (existing) { return existing.id; }));
              return previous.concat(incoming.filter(function (star) { return !ids.has(star.id); }));
            });
          })
          .catch(function () { skyConesRef.current.delete(tileKey); });
      }
    }
    const needsSmallBodyResolution = (item.catalog_source === "JPL Small-Body Database" || item.object_query) &&
      (!Array.isArray(item.position) || item.map_status === "unplotted");
    if (needsSmallBodyResolution) {
      setLoadingDetail(true);
      const designation = item.pdes || item.object_query || item.spkid || item.name;
      fetch("/api/small-body?query=" + encodeURIComponent(designation))
        .then(function (response) { if (!response.ok) throw new Error("JPL could not resolve this designation"); return response.json(); })
        .then(function (data) {
          const raw = data.object || data;
          const detailed = Object.assign({}, item, raw, {
            catalog_source: "JPL Small-Body Database",
            facts: Object.assign({}, raw.facts || {}, item.facts || {}),
            sources: (raw.sources || []).concat(item.sources || []).filter(function (source, index, all) {
              const url = typeof source === "string" ? source : source.url;
              return url && all.findIndex(function (candidate) { return (typeof candidate === "string" ? candidate : candidate.url) === url; }) === index;
            })
          });
          setSelected(function (current) { return current && (current.id === item.id || current.name === item.name) ? detailed : current; });
          setCatalog(function (previous) {
            const exists = previous.some(function (entry) { return entry.id === detailed.id; });
            return exists ? previous.map(function (entry) { return entry.id === detailed.id ? detailed : entry; }) : previous.concat([detailed]);
          });
          if (Array.isArray(detailed.position) && sceneApi.current) {
            sceneApi.current.addCatalog([detailed]);
            sceneApi.current.scale("system");
            sceneApi.current.filter("all");
            sceneApi.current.focus(detailed);
            setViewScale("system");
          }
        })
        .catch(function () { toast("JPL detail lookup failed. Orbital measurements and source links remain available."); })
        .finally(function () { setLoadingDetail(false); });
    } else if (item.external && !item.descriptionLong && !item.facts) {
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
  const facts = selected ? Object.assign({}, selected.facts || {}) : {};
  if (selected && selected.ra_deg !== null && selected.ra_deg !== undefined && selected.dec_deg !== null && selected.dec_deg !== undefined && Number.isFinite(Number(selected.ra_deg)) && Number.isFinite(Number(selected.dec_deg))) {
    facts["Right ascension (ICRS)"] = Number(selected.ra_deg).toFixed(5) + "°";
    facts["Declination (ICRS)"] = Number(selected.dec_deg).toFixed(5) + "°";
  }
  if (selected && Number.isFinite(Number(selected.distance_ly)) && Number(selected.distance_ly) > 0) {
    facts["Distance from Sun / Earth"] = Number(selected.distance_ly).toLocaleString(undefined, { maximumFractionDigits: 2 }) + " light-years";
  }
  if (selected && Number.isFinite(Number(selected.distance_from_sun_au))) {
    facts["Mean heliocentric distance"] = Number(selected.distance_from_sun_au).toLocaleString(undefined, { maximumFractionDigits: 4 }) + " AU";
  }
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
        <div className="header-tools"><button className="catalogs-button" title="Browse live scientific archives" onClick={function () { setArchiveOpen(true); setArchiveMode("coverage"); if (!coverage && !coverageLoading) loadCoverage(); }}><span>▦</span> ARCHIVES</button><span className="system-status"><i></i>{apiStatus}</span><button className="round-tool" title="Reset universe view" onClick={function () { closeDetails(); setCategory("all"); if (sceneApi.current) sceneApi.current.reset(); }} aria-label="Reset universe"><svg viewBox="0 0 24 24"><path d="M4 11a8 8 0 1 0 2.1-5.4L3.5 8.2"></path><path d="M3.5 3.6v4.8h4.8"></path></svg></button></div>
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
      {archiveOpen && <aside className="archive-panel" aria-label="Scientific archive browser">
        <div className="archive-panel-header">
          <div><span className="archive-eyebrow"><i></i> LIVE SCIENCE SOURCES</span><h2>Catalog <em>navigator.</em></h2><p>Browse records from the archives behind the map.</p></div>
          <button className="close-panel archive-close" onClick={function () { setArchiveOpen(false); }} aria-label="Close archive browser">×</button>
        </div>
        <div className="archive-mode-row">
          <button className={archiveMode === "coverage" ? "active" : ""} onClick={function () { setArchiveMode("coverage"); if (!coverage && !coverageLoading) loadCoverage(); }} disabled={archiveLoading}>Coverage</button>
          <button className={archiveMode === "exoplanets" ? "active" : ""} onClick={function () { setArchiveMode("exoplanets"); loadArchive("exoplanets", true); }} disabled={archiveLoading}>Exoplanets</button>
          <button className={archiveMode === "small-bodies" ? "active" : ""} onClick={function () { setArchiveMode("small-bodies"); loadArchive("small-bodies", true); }} disabled={archiveLoading}>Asteroids & comets</button>
          <button className={archiveMode === "close-approaches" ? "active" : ""} onClick={function () { setArchiveMode("close-approaches"); loadArchive("close-approaches", true); }} disabled={archiveLoading}>Earth approaches</button>
          <button className={archiveMode === "gaia" ? "active" : ""} onClick={function () { setArchiveMode("gaia"); loadArchive("gaia", true); }} disabled={archiveLoading}>Gaia stars</button>
          <button className={archiveMode === "fireballs" ? "active" : ""} onClick={function () { setArchiveMode("fireballs"); loadArchive("fireballs", true); }} disabled={archiveLoading}>Fireballs</button>
          <button className={archiveMode === "impact-monitor" ? "active" : ""} onClick={function () { setArchiveMode("impact-monitor"); loadArchive("impact-monitor", true); }} disabled={archiveLoading}>Sentry monitor</button>
          <button className={archiveMode === "media" ? "active" : ""} onClick={function () { setArchiveMode("media"); loadArchive("media", true); }} disabled={archiveLoading}>NASA media</button>
          <button className={archiveMode === "research" ? "active" : ""} onClick={function () { setArchiveMode("research"); loadArchive("research", true); }} disabled={archiveLoading}>NASA research</button>
        </div>
        {archiveMode === "coverage" && <div className="coverage-view">
          <div className="archive-intro"><span>ARCHIVE STATUS</span><h3>Many catalogs. Different skies.</h3><p>Counts below are source-specific and overlap. A source marked queryable is available for bounded searches—not downloaded in full.</p><button disabled={coverageLoading} onClick={loadCoverage}><span>↻</span> {coverageLoading ? "Checking archives…" : "Refresh source status"}</button></div>
          {coverageLoading && <div className="archive-empty"><span className="spinner"></span> Checking live source totals…</div>}
          {coverageError && <div className="archive-error">{coverageError}</div>}
          {coverage && <><div className="coverage-summary"><span><small>CURATED STARTER</small><strong>{Number(coverage.local_curated_records || 0).toLocaleString()}</strong><i>local objects</i></span><span><small>CATALOG FEEDS</small><strong>{(coverage.sources || []).length}</strong><i>registered sources</i></span></div>
            <div className="coverage-list">{(coverage.sources || []).map(function (source) {
              const counts = source.families ? Object.entries(source.families).filter(function (entry) { return entry[1] !== null && entry[1] !== undefined; }).map(function (entry) { return entry[0].replace(/_/g, " ") + ": " + Number(entry[1]).toLocaleString(); }).join(" · ") : (source.record_count !== null && source.record_count !== undefined ? Number(source.record_count).toLocaleString() + " archive rows" : "");
              const statusText = ({ online: "LIVE COUNT", queryable: "QUERYABLE", supplementary: "SUPPLEMENTARY", unavailable: "OFFLINE" })[source.status] || "REGISTERED";
              return <div className="coverage-source" key={source.id}><div className="coverage-source-top"><span className={"coverage-source-dot status-" + (source.status || "registered")}></span><strong>{source.name}</strong><small>{statusText}</small></div><p>{counts || source.count_scope || source.scope || "Catalog records are available by query."}</p><a href={source.url} target="_blank" rel="noopener noreferrer">Open source ↗</a></div>;
            })}</div>
          </>}
          <p className="coverage-footnote">Astra federates public archives. This dashboard is not a claim that all objects are mirrored locally or all have distances accurate enough for a 3D position.</p>
        </div>}
        {archiveMode === "exoplanets" && <div className="archive-controls">
          <form className="archive-search-form" onSubmit={function (event) { event.preventDefault(); loadArchive("exoplanets", true); }}>
            <input value={archiveQuery} onChange={function (event) { setArchiveQuery(event.target.value); }} placeholder="Filter by planet or host-star name…" aria-label="Filter NASA exoplanet archive" />
            <button type="submit" disabled={archiveLoading}>Search</button>
          </form>
          <div className="archive-help">NASA Exoplanet Archive · PSCompPars · cursor pagination</div>
        </div>}
        {archiveMode === "research" && <div className="archive-controls">
          <form className="archive-search-form" onSubmit={function (event) { event.preventDefault(); loadArchive("research", true); }}>
            <input value={researchQuery} onChange={function (event) { setResearchQuery(event.target.value); }} placeholder="Search NASA papers, reports and mission studies…" aria-label="Search NASA research records" />
            <button type="submit" disabled={archiveLoading}>Search</button>
          </form>
          <div className="archive-help">NASA Technical Reports Server · public citations, abstracts, technical reports and mission papers.</div>
        </div>}
        {archiveMode === "small-bodies" && <div className="archive-controls">
          <div className="archive-filter-grid"><label>Object family<select value={archiveKind} onChange={function (event) { setArchiveKind(event.target.value); }}><option value="all">Asteroids + comets</option><option value="asteroid">Asteroids only</option><option value="comet">Comets only</option></select></label><label className="checkbox-filter"><input type="checkbox" checked={archiveNeoOnly} onChange={function (event) { setArchiveNeoOnly(event.target.checked); }} /> Near-Earth objects only</label></div>
          <button className="archive-query-button" disabled={archiveLoading} onClick={function () { loadArchive("small-bodies", true); }}>{archiveLoading ? "Querying JPL…" : "Query JPL small-body archive ↗"}</button>
          <div className="archive-help">NASA/JPL SBDB Query API · orbital elements, designations and physical parameters</div>
        </div>}
        {archiveMode === "close-approaches" && <div className="archive-controls">
          <div className="archive-filter-grid"><label>Forecast window<select value={approachDays} onChange={function (event) { setApproachDays(event.target.value); }}><option value="30">Next 30 days</option><option value="90">Next 90 days</option><option value="180">Next 180 days</option><option value="365">Next year</option></select></label><label>Maximum distance<select value={approachDistance} onChange={function (event) { setApproachDistance(event.target.value); }}><option value="0.01">0.01 AU</option><option value="0.05">0.05 AU</option><option value="0.1">0.1 AU</option><option value="0.25">0.25 AU</option><option value="0.5">0.5 AU</option></select></label></div>
          <button className="archive-query-button" disabled={archiveLoading} onClick={function () { loadArchive("close-approaches", true); }}>{archiveLoading ? "Querying JPL…" : "Refresh close-approach forecasts ↗"}</button>
          <div className="archive-help">Earth close-approach data · model-dependent times and distances · not collision predictions</div>
        </div>}
        {archiveMode === "gaia" && <div className="archive-controls"><div className="archive-help">ESA Gaia DR3 · a bounded bright-star sample and coordinate cone searches. The full Gaia archive remains remote.</div><button className="archive-query-button" disabled={archiveLoading} onClick={function () { loadArchive("gaia", true); }}>{archiveLoading ? "Querying Gaia…" : "Refresh Gaia star sample ↗"}</button></div>}
        {archiveMode === "fireballs" && <div className="archive-controls">
          <label className="archive-date-filter">Earliest observation date (UTC)<input type="date" value={fireballDateMin} onChange={function (event) { setFireballDateMin(event.target.value); }} /></label>
          <button className="archive-query-button" disabled={archiveLoading} onClick={function () { loadArchive("fireballs", true); }}>{archiveLoading ? "Querying CNEOS…" : "Refresh fireball observations ↗"}</button>
          <div className="archive-help">Reported atmospheric observations from government sensors. Not tracked Solar System bodies; locations and energy estimates may be incomplete.</div>
        </div>}
        {archiveMode === "media" && <div className="archive-controls">
          <form className="archive-search-form" onSubmit={function (event) { event.preventDefault(); loadArchive("media", true); }}>
            <input value={archiveMediaQuery} onChange={function (event) { setArchiveMediaQuery(event.target.value); }} placeholder="Search NASA imagery by object or mission…" aria-label="Search NASA image library" />
            <button type="submit" disabled={archiveLoading}>Search</button>
          </form>
          <div className="archive-filter-grid media-type-filter"><label>Media type<select value={archiveMediaType} onChange={function (event) { setArchiveMediaType(event.target.value); }}><option value="image">Images</option><option value="video">Videos</option><option value="audio">Audio</option></select></label><span className="archive-media-provider">NASA Image and Video Library · public API</span></div>
          <div className="archive-help">Visual source results. Thumbnails and descriptions come from NASA’s media index; they do not determine an object’s measured location or scale.</div>
        </div>}
        {archiveMode === "impact-monitor" && <div className="archive-controls">
          <label className="archive-date-filter">Minimum modeled impact probability<select value={sentryProbabilityMin} onChange={function (event) { setSentryProbabilityMin(event.target.value); }}><option value="">All entries returned by Sentry</option><option value="1e-7">1 in 10 million or greater</option><option value="1e-6">1 in 1 million or greater</option><option value="1e-5">1 in 100,000 or greater</option><option value="1e-4">1 in 10,000 or greater</option><option value="1e-3">1 in 1,000 or greater</option></select></label>
          <button className="archive-query-button" disabled={archiveLoading} onClick={function () { loadArchive("impact-monitor", true); }}>{archiveLoading ? "Querying Sentry…" : "Refresh Sentry monitoring ↗"}</button>
          <div className="archive-help">Sentry lists modeled possible-impact cases—not predictions that an impact will occur. Probabilities and ratings are uncertain and time-dependent; read the original case before interpreting a value.</div>
        </div>}
        {archiveMode !== "coverage" && <div className="archive-results-heading"><span>{archiveMode === "close-approaches" ? "UPCOMING EVENTS" : archiveMode === "fireballs" ? "ATMOSPHERIC OBSERVATIONS" : archiveMode === "impact-monitor" ? "MODELED MONITORING CASES" : archiveMode === "media" ? "NASA MEDIA RESULTS" : archiveMode === "research" ? "SCIENTIFIC PUBLICATIONS" : "ARCHIVE RECORDS"}</span><span>{archiveRows.length.toLocaleString()} LOADED</span></div>
        {archiveMode !== "coverage" && <div className="archive-results">
          {archiveLoading && !archiveRows.length && <div className="archive-empty"><span className="spinner"></span> Querying the remote catalog…</div>}
          {!archiveLoading && !archiveRows.length && !archiveError && <div className="archive-empty">Choose a query above to discover records from this source.</div>}
          {archiveRows.map(function (item) {
            if (archiveMode === "media") {
              return <a className="archive-media-card" key={item.id} href={item.page_url} target="_blank" rel="noopener noreferrer">
                <span className="archive-media-thumb">{item.thumbnail_url ? <img src={item.thumbnail_url} loading="lazy" alt={item.title || "NASA media preview"} /> : <span>NO PREVIEW</span>}</span>
                <span className="archive-media-copy"><strong>{item.title || item.name}</strong><small>{[item.center, item.date_created].filter(Boolean).join(" · ") || "NASA Image and Video Library"}</small><em>{item.description || item.media_type || "NASA media result"}</em></span><span className="archive-record-arrow">↗</span>
              </a>;
            }
            if (archiveMode === "research") {
              return <a className="archive-research-card" key={item.id} href={item.page_url} target="_blank" rel="noopener noreferrer">
                <span className="research-document-icon">⌑</span>
                <span className="archive-research-copy"><strong>{item.title || item.name}</strong><small>{[item.publication_date, item.center, item.document_type].filter(Boolean).join(" · ") || "NASA Technical Reports Server"}</small><em>{item.abstract || "Open the NASA publication record for abstract, metadata and document links."}</em></span>
                <span className="archive-record-arrow">↗</span>
              </a>;
            }
            const isEvent = archiveMode === "close-approaches";
            const isFireball = archiveMode === "fireballs";
            const isSentry = archiveMode === "impact-monitor";
            const title = item.name || item.full_name || item.designation || "Astronomical source";
            const detail = isEvent
              ? [item.date, item.distance_au !== null && item.distance_au !== undefined ? Number(item.distance_au).toPrecision(4) + " AU" : null, item.relative_velocity_km_s ? Number(item.relative_velocity_km_s).toFixed(2) + " km/s" : null].filter(Boolean).join(" · ")
              : isFireball
                ? [item.event_date_utc, item.facts && item.facts["Latitude"], item.facts && item.facts["Longitude"], item.facts && item.facts["Radiated energy"]].filter(Boolean).join(" · ")
                : isSentry
                  ? [item.facts && item.facts["Assessment range"], item.facts && item.facts["Modeled impact probability"] ? "modeled probability " + item.facts["Modeled impact probability"] : null, item.facts && item.facts["Estimated diameter"]].filter(Boolean).join(" · ")
                  : (item.subtitle || item.type || item.category || "External archive record");
            const secondary = isEvent ? "JPL close-approach event" : isFireball ? "NASA/JPL CNEOS atmospheric observation" : isSentry ? "NASA/JPL Sentry monitoring record" : (item.catalog_source || item.type || item.category || "Archive record");
            return <button className="archive-record" key={item.id} onClick={function () { selectArchiveItem(item); }}>
              <span className={"archive-record-symbol " + (item.category || "deep")}>{ICONS[item.category] || "✧"}</span>
              <span className="archive-record-copy"><strong>{title}</strong><small>{secondary}</small><em>{detail}</em></span>
              <span className="archive-record-arrow">↗</span>
            </button>;
          })}
          {archiveError && <div className="archive-error">{archiveError}</div>}
        </div>}
        {archiveMode !== "coverage" && archiveHasMore && <button className="archive-more" disabled={archiveLoading} onClick={function () { loadArchive(archiveMode, false); }}>{archiveLoading ? "Loading more records…" : "Load next page ↗"}</button>}
        <div className="archive-panel-footer"><span><i></i> SOURCES LINKED TO ORIGINAL ARCHIVES</span><span>POSITIONS MAY BE UNAVAILABLE</span></div>
      </aside>}
      <section className="explorer-dock">
        <div className="dock-heading"><div><span className="dock-eyebrow">YOUR NEXT DESTINATION</span><h2>Explore the cosmos <em>↘</em></h2></div><span className="object-count">{mappedCount} PLOTTED / {catalog.length} INDEXED</span></div>
        <div className="category-row">{CATEGORIES.map(function (item) { return <button key={item[0]} className={"category-pill" + (category === item[0] ? " active" : "")} onClick={function () {
          setCategory(item[0]);
          const nextScale = ["planet", "moon", "asteroid", "dwarf-planet"].includes(item[0]) ? "system" : "universe";
          setViewScale(nextScale);
          if (sceneApi.current) {
            sceneApi.current.scale(nextScale);
            sceneApi.current.filter(item[0]);
            if (item[0] !== "all") sceneApi.current.fit();
          }
          if (item[0] === "exoplanet" && exoLoadedCount === 0) loadExoplanetPage(true);
        }}><span>{ICONS[item[0]]}</span>{item[1]}</button>; })}</div>
        {category === "exoplanet" && <div className="archive-toolbar"><span>{exoLoadedCount ? exoLoadedCount + " NASA archive entries loaded" : "Search the confirmed exoplanet archive"}</span><button disabled={exoLoading || (!exoHasMore && exoLoadedCount > 0)} onClick={function () { loadExoplanetPage(exoLoadedCount === 0); }}>{exoLoading ? "Loading archive…" : exoLoadedCount === 0 ? "Load NASA exoplanets ↗" : exoHasMore ? "Load next page ↗" : "All matching pages loaded"}</button></div>}
        <div className="destination-row">{visibleCatalog.slice(0, 8).map(function (item) {
          return <button key={item.id} className={"destination" + (selected && selected.id === item.id ? " chosen" : "")} onClick={function () { chooseObject(item); }}><span className={"destination-icon " + item.category} style={{ "--orb": item.color || "#9e9eff" }}><i></i></span><span className="destination-copy"><small>{String(item.type || item.category || "OBJECT").toUpperCase()}</small><strong>{item.name}</strong></span><span className="destination-arrow">↗</span></button>;
        })}</div>
        <div className="dock-footer"><span><i></i> LIVE CATALOGS · {mappedCount} PLOTTED / {catalog.length} INDEXED</span><span>DRAG TO ORBIT <b>·</b> SCROLL TO ZOOM</span><div className="scene-actions"><button onClick={function () { if (sceneApi.current) sceneApi.current.zoom(-3); }} title="Zoom in" aria-label="Zoom in">+</button><button onClick={function () { if (sceneApi.current) sceneApi.current.zoom(3); }} title="Zoom out" aria-label="Zoom out">−</button><button className={labelsOn ? "selected" : ""} onClick={toggleLabels} title="Toggle labels" aria-label="Toggle labels">T</button><button className={orbitsOn ? "selected" : ""} onClick={toggleOrbits} title="Toggle orbit paths" aria-label="Toggle orbit paths">◎</button><button onClick={function () { if (sceneApi.current) sceneApi.current.fit(); }} title="Fit visible catalog objects" aria-label="Fit visible catalog objects">⌖</button></div></div>
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
