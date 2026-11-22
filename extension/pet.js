(() => {
  "use strict";

  const { defaults, allows, minSize, maxSize } = caraxesSettings;
  const newTab = location.href.split(/[?#]/, 1)[0] === chrome.runtime.getURL("newtab.html");
  const flightTime = 2000;
  const poses = {
    sleep_rest: { facesLeft: false },
    fly_side: { facesLeft: false },
    fly_diag_b: { facesLeft: true },
    fly_vertical: { facesLeft: false },
    roar_front: { facesLeft: false },
    head_roar: { facesLeft: false }
  };

  const sheet = new CSSStyleSheet();
  sheet.replaceSync(`
    :host {
      all: initial;
      position: fixed !important;
      z-index: 2147483647 !important;
      top: 0;
      left: 0;
      display: block;
      width: var(--size);
      aspect-ratio: 4 / 3;
      pointer-events: none;
      isolation: isolate;
    }
    .sprite {
      all: unset;
      position: absolute;
      inset: 0;
      display: block;
      cursor: pointer;
      pointer-events: auto;
    }
    .sprite:focus-visible { outline: 2px solid #e96658; border-radius: 12px; }
    .pose, .direction, .body, .art {
      position: absolute;
      inset: 0;
      display: block;
    }
    .art {
      width: 100%;
      height: 100%;
      object-fit: contain;
      object-position: center bottom;
      user-select: none;
      pointer-events: none;
    }
    .pose[data-mirror] .art { transform: scaleX(-1); }
    :host([data-state="idle"]) .body { animation: bob 2.6s ease-in-out infinite; }
    :host([data-state="sleep"]) .body {
      transform-origin: center bottom;
      animation: breathe 4.8s ease-in-out infinite;
    }
    :host([data-state="fly"]) .body { animation: tilt ${flightTime}ms linear both; }
    :host([data-state="fly"]) .direction { animation: turn ${flightTime}ms steps(1) both; }
    :host([data-state="fly"]) .pose:first-child { animation: blend .8s linear infinite; }
    :host([data-state="fly"]) .pose:nth-child(2) { animation: blend .8s linear -.4s infinite; }
    :host([data-paused]) * { animation-play-state: paused !important; }
    .zzz {
      position: absolute;
      left: 68%;
      top: 12%;
      color: #fff6d2;
      font: bold 13px system-ui, sans-serif;
      text-shadow: 0 1px 4px #231114;
      opacity: 0;
      animation: drift 3.6s ease-out infinite;
      animation-delay: var(--delay);
      pointer-events: none;
    }
    .flame {
      position: absolute;
      left: var(--mouth-x, 49%);
      top: var(--mouth-y, 40%);
      width: 52%;
      height: 25%;
      transform-origin: left center;
      pointer-events: none;
    }
    .spark {
      position: absolute;
      top: 40%;
      left: 0;
      width: 25%;
      aspect-ratio: 1;
      border-radius: 50%;
      background: radial-gradient(circle, #fffac1, #ffb019 35%, #e53714 66%, transparent 73%);
      animation: spark .45s ease-out infinite;
      animation-delay: var(--delay);
    }
    @keyframes bob { 50% { transform: translateY(-4px); } }
    @keyframes breathe { 50% { transform: scale(1.02); } }
    @keyframes turn {
      0% { transform: scaleX(var(--heading)); }
      50%, 100% { transform: scaleX(calc(-1 * var(--heading))); }
    }
    @keyframes tilt {
      0%, 48% { transform: rotate(var(--tilt)); }
      52%, 100% { transform: rotate(calc(-1 * var(--tilt))); }
    }
    @keyframes blend { 0%, 35%, 100% { opacity: 1; } 50%, 85% { opacity: 0; } }
    @keyframes drift {
      0% { opacity: 0; }
      28%, 52% { opacity: 1; }
      100% { opacity: 0; transform: translate(24px, -23px) scale(1.14); }
    }
    @keyframes spark {
      from { opacity: .95; transform: scale(.45); }
      to { opacity: 0; transform: translate(var(--travel), var(--rise)) scale(1.5); }
    }
  `);

  const svgNS = "http://www.w3.org/2000/svg";
  const dragonPaths = [
    ["#981d35", "M87 91Q42 128 19 100Q10 89 21 78Q17 102 36 102Q53 102 70 86Z"],
    ["#8d1935", "M94 84Q63 54 61 24Q41 17 26 10Q44 34 42 47Q56 45 58 61Q67 58 71 74Z"],
    ["#cf344b", "M61 88Q65 72 86 74Q107 67 101 44Q96 29 115 23L137 27L149 36L140 44L119 43Q126 69 114 82Q101 100 79 100Q68 102 61 88Z"],
    ["#f77964", "M112 43Q116 61 109 75Q101 91 79 95Q110 96 118 78Q126 62 119 43Z"],
    ["#b52640", "M80 81Q51 64 21 28Q30 54 22 62Q42 57 49 76Q64 69 67 88Z"],
    ["#b52640", "M73 95L81 115L98 115L98 110L85 108L85 95M101 91L106 114L124 114L124 109L114 107L114 84Z"],
    ["#edbd93", "M107 27L101 15L117 24M120 25L122 15L130 26"],
    ["#ffe091", "M128 32A2 2 0 1 0 132 32A2 2 0 1 0 128 32"]
  ];

  function fallbackDragon() {
    const svg = document.createElementNS(svgNS, "svg");
    svg.setAttribute("viewBox", "0 0 160 116");
    svg.setAttribute("preserveAspectRatio", "xMidYMax meet");
    svg.setAttribute("class", "art");
    svg.setAttribute("aria-hidden", "true");
    for (const [color, shape] of dragonPaths) {
      const path = document.createElementNS(svgNS, "path");
      path.setAttribute("fill", color);
      path.setAttribute("stroke", "#481021");
      path.setAttribute("stroke-linejoin", "round");
      path.setAttribute("stroke-width", "1.5");
      path.setAttribute("d", shape);
      svg.append(path);
    }
    return svg;
  }

  let settings = { ...defaults };
  let host;
  let button;
  let body;
  let direction;
  let effects;
  let state;
  let position;
  let motion;
  let timer;
  let deadline;
  let remaining;
  let size;
  let loaded = false;

  function pose(name) {
    const layer = document.createElement("span");
    layer.className = "pose";
    layer.append(fallbackDragon());
    // Only request poses when shown. Cache the result, including a missing PNG.
    const asset = poses[name];
    asset.decoded ??= loadPose(name);
    asset.decoded.then(image => {
      if (!image || !layer.isConnected) return;
      layer.toggleAttribute("data-mirror", asset.facesLeft);
      layer.replaceChildren(image.cloneNode());
      if (name === "roar_front" && host) {
        host.style.setProperty("--mouth-x", "49%");
        host.style.setProperty("--mouth-y", "40%");
      }
    });
    return layer;
  }

  async function loadPose(name) {
    const image = new Image();
    image.className = "art";
    image.alt = "";
    image.src = chrome.runtime.getURL("sprites/" + name + ".png");
    try {
      await image.decode();
      return image;
    } catch {
      return null;
    }
  }

  function perchBounds() {
    if (newTab) return document.querySelector("#search-box")?.getBoundingClientRect();
    const googleHome = ["google.com", "www.google.com"].includes(location.hostname) &&
      location.pathname === "/" && !new URLSearchParams(location.search).has("q");
    if (!googleHome) return null;
    const candidates = document.querySelectorAll('img[alt="Google" i], svg[aria-label="Google" i], [role="img"][aria-label="Google" i], #hplogo');
    for (const logo of candidates) {
      const rect = logo.getBoundingClientRect();
      if (rect.width && rect.height) return rect;
    }
    return null;
  }

  function home() {
    const perch = perchBounds();
    const x = perch ? perch.left + (perch.width - size) / 2 : innerWidth - size - 24;
    const y = perch ? perch.top - size * .75 : 4;
    return {
      x: Math.max(0, Math.min(innerWidth - size, x)),
      y: Math.max(0, Math.min(innerHeight - size * .75, y))
    };
  }

  function transform(point) {
    return `translate3d(${point.x}px, ${point.y}px, 0)`;
  }

  function moveTo(point) {
    position = point;
    host.style.transform = transform(point);
  }

  function applySize() {
    size = Math.max(1, Math.min(innerWidth, Math.max(minSize, Math.min(maxSize, settings.size))));
    host.style.setProperty("--size", size + "px");
  }

  function relayout() {
    if (!host || document.hidden) return;
    applySize();
    moveTo(home());
    if (state === "fly") enter("idle");
  }

  function stopMotion(keepPosition) {
    if (!motion) return;
    if (keepPosition) {
      const matrix = new DOMMatrixReadOnly(getComputedStyle(host).transform);
      moveTo({ x: matrix.m41, y: matrix.m42 });
    }
    motion.cancel();
    motion = undefined;
  }

  function fly() {
    const end = home();
    const roomLeft = position.x;
    const roomRight = Math.max(0, innerWidth - size - position.x);
    const left = roomLeft >= roomRight;
    const distance = Math.min(left ? roomLeft : roomRight, 65 + Math.random() * 140);
    const middle = { x: position.x + (left ? -distance : distance), y: Math.max(0, end.y - 9) };
    host.style.setProperty("--heading", left ? "-1" : "1");
    host.style.setProperty("--tilt", left ? "-7deg" : "7deg");
    motion = host.animate([
      { transform: transform(position), easing: "ease-in-out" },
      { transform: transform(middle), easing: "ease-in-out" },
      { transform: transform(end) }
    ], { duration: flightTime, fill: "forwards" });
  }

  function effect(className, count) {
    const container = document.createElement("span");
    if (className === "spark") container.className = "flame";
    for (let index = 0; index < count; index++) {
      const particle = document.createElement("span");
      particle.className = className;
      if (className === "zzz") particle.textContent = "Zzz";
      particle.style.setProperty("--delay", (className === "zzz" ? index * 1.2 : index * .065) + "s");
      particle.style.setProperty("--rise", (index * 4 - 16) + "px");
      particle.style.setProperty("--travel", (35 + index * 4) + "px");
      container.append(particle);
    }
    effects.replaceChildren(container);
  }

  function armTimer() {
    if (!host || document.hidden || timer !== undefined) return;
    deadline = performance.now() + remaining;
    timer = setTimeout(() => {
      timer = undefined;
      if (document.hidden) {
        remaining = 0;
        return;
      }
      if (state === "fly") moveTo(home());
      enter({ sleep: "idle", idle: "fly", fly: "sleep", fire: "idle" }[state]);
    }, remaining);
  }

  function enter(next) {
    clearTimeout(timer);
    timer = undefined;
    stopMotion(next === "fire");
    state = next;
    host.dataset.state = state;
    effects.replaceChildren();
    host.style.setProperty("--mouth-x", "86%");
    host.style.setProperty("--mouth-y", "31%");
    switch (state) {
      case "sleep":
        direction.replaceChildren(pose("sleep_rest"));
        effect("zzz", 3);
        remaining = 30000 + Math.random() * 90000;
        break;
      case "idle":
        direction.replaceChildren(pose("roar_front"));
        remaining = 5000 + Math.random() * 10000;
        break;
      case "fly":
        direction.replaceChildren(pose("fly_side"), pose("fly_diag_b"));
        fly();
        remaining = flightTime;
        break;
      case "fire":
        direction.replaceChildren(pose("roar_front"));
        effect("spark", 7);
        remaining = 1500;
        break;
    }
    button.setAttribute("aria-label", state === "sleep" ? "Wake Caraxes" : "Ask Caraxes to breathe fire");
    armTimer();
  }

  function mount() {
    host = document.createElement("caraxes-pet");
    host.dataset.caraxesPet = "";
    const shadow = host.attachShadow({ mode: "open" });
    shadow.adoptedStyleSheets = [sheet];

    button = document.createElement("button");
    button.type = "button";
    button.className = "sprite";
    body = document.createElement("span");
    body.className = "body";
    direction = document.createElement("span");
    direction.className = "direction";
    effects = document.createElement("span");
    effects.setAttribute("aria-hidden", "true");
    body.append(direction);
    button.append(body);

    button.addEventListener("click", event => {
      event.stopPropagation();
      if (state === "sleep") enter("idle");
      else if (state !== "fire") enter("fire");
    });
    shadow.append(button, effects);
    document.documentElement.append(host);
    window.addEventListener("resize", relayout, { passive: true });
    applySize();
    moveTo(home());
    enter("idle");
  }

  function unmount() {
    if (!host) return;
    clearTimeout(timer);
    timer = undefined;
    stopMotion(false);
    window.removeEventListener("resize", relayout);
    host.remove();
    host = undefined;
  }

  function syncSettings() {
    if (!loaded) return;
    if (!allows(settings, newTab ? "" : location.hostname)) {
      unmount();
    } else if (!document.hidden) {
      if (!host) mount();
      else relayout();
    }
  }

  document.addEventListener("visibilitychange", () => {
    if (!host) {
      syncSettings();
      return;
    }
    if (document.hidden) {
      if (timer !== undefined) remaining = Math.max(0, deadline - performance.now());
      clearTimeout(timer);
      timer = undefined;
      host.dataset.paused = "";
      motion?.pause();
    } else {
      delete host.dataset.paused;
      const previousSize = size;
      applySize();
      if (state === "fly" && previousSize === size) motion?.play();
      else relayout();
      armTimer();
    }
  });

  const pendingChanges = {};
  chrome.storage.onChanged.addListener((changes, area) => {
    if (area !== "local") return;
    for (const key of Object.keys(defaults)) {
      if (key in changes) {
        const value = changes[key].newValue ?? defaults[key];
        (loaded ? settings : pendingChanges)[key] = value;
      }
    }
    syncSettings();
  });

  chrome.storage.local.get(defaults).then(saved => {
    settings = { ...saved, ...pendingChanges };
    loaded = true;
    syncSettings();
  });
})();
