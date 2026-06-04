const ENDPOINTS = {
  // Frontend Health button -> Backend GET /health.
  health: {
    label: "Health",
    path: "/health",
    expectedError: false,
  },

  // Frontend Fast button/profile -> Backend GET /api/fast.
  // Use this to create normal low-latency traffic.
  fast: {
    label: "Fast",
    path: "/api/fast",
    expectedError: false,
  },

  // Frontend Slow button/profile -> Backend GET /api/slow.
  // Backend sleeps about 2 seconds. Use this to observe latency.
  slow: {
    label: "Slow",
    path: "/api/slow",
    expectedError: false,
  },

  // Frontend Error 500 button/profile -> Backend GET /api/error.
  // Backend intentionally raises an exception. Use this to observe 500 logs/traces.
  error: {
    label: "Error 500",
    path: "/api/error",
    expectedError: true,
  },
};

const PROFILE_WEIGHTS = {
  mixed: ["fast", "fast", "fast", "slow", "error"],
  fast: ["fast"],
  slow: ["slow", "fast"],
  error: ["error", "error", "fast"],
};

const state = {
  timer: null,
  total: 0,
  ok: 0,
  error: 0,
  latencySum: 0,
};

const els = {
  apiBase: document.querySelector("#apiBase"),
  saveBase: document.querySelector("#saveBase"),
  healthStatus: document.querySelector("#healthStatus"),
  trafficProfile: document.querySelector("#trafficProfile"),
  intervalMs: document.querySelector("#intervalMs"),
  burstCount: document.querySelector("#burstCount"),
  startAuto: document.querySelector("#startAuto"),
  stopAuto: document.querySelector("#stopAuto"),
  sendBurst: document.querySelector("#sendBurst"),
  clearLog: document.querySelector("#clearLog"),
  requestLog: document.querySelector("#requestLog"),
  totalCount: document.querySelector("#totalCount"),
  okCount: document.querySelector("#okCount"),
  errorCount: document.querySelector("#errorCount"),
  avgLatency: document.querySelector("#avgLatency"),
};

function defaultApiBase() {
  const isFile = window.location.protocol === "file:";
  const isStandaloneFrontend =
    window.location.hostname === "localhost" &&
    window.location.port &&
    window.location.port !== "80";

  if (isFile || isStandaloneFrontend) {
    return "http://localhost:8081";
  }

  return window.location.origin;
}

function loadApiBase() {
  return localStorage.getItem("observability.apiBase") || defaultApiBase();
}

function saveApiBase() {
  const value = normalizeBase(els.apiBase.value);
  localStorage.setItem("observability.apiBase", value);
  els.apiBase.value = value;
}

function normalizeBase(value) {
  const trimmed = value.trim().replace(/\/+$/, "");
  return trimmed || defaultApiBase();
}

function endpointUrl(endpoint) {
  return `${normalizeBase(els.apiBase.value)}${endpoint.path}`;
}

function isCrossOrigin(url) {
  try {
    return new URL(url).origin !== window.location.origin;
  } catch {
    return true;
  }
}

function pickProfileEndpoint() {
  const profile = els.trafficProfile.value;
  const choices = PROFILE_WEIGHTS[profile] || PROFILE_WEIGHTS.mixed;
  return choices[Math.floor(Math.random() * choices.length)];
}

async function callApi(key) {
  const endpoint = ENDPOINTS[key];
  const url = endpointUrl(endpoint);
  const start = performance.now();
  const crossOrigin = isCrossOrigin(url);

  try {
    const response = await fetch(url, {
      method: "GET",
      cache: "no-store",
      mode: crossOrigin ? "no-cors" : "cors",
    });
    const latency = Math.round(performance.now() - start);

    if (response.type === "opaque") {
      recordResult(endpoint, url, "sent", latency, true, "Cross-origin no-cors request; traffic still reaches backend.");
      return;
    }

    const ok = endpoint.expectedError ? response.status >= 500 : response.ok;
    const note = endpoint.expectedError
      ? "Expected backend 500 for observability testing."
      : response.ok
        ? "Backend response OK."
        : "Unexpected non-2xx response.";

    recordResult(endpoint, url, String(response.status), latency, ok, note);

    if (key === "health") {
      updateHealth(response.ok);
    }
  } catch (err) {
    const latency = Math.round(performance.now() - start);
    recordResult(endpoint, url, "network", latency, false, err.message);

    if (key === "health") {
      updateHealth(false);
    }
  }
}

function recordResult(endpoint, url, status, latency, ok, note) {
  state.total += 1;
  state.latencySum += latency;

  if (ok) {
    state.ok += 1;
  } else {
    state.error += 1;
  }

  renderStats();
  appendLog({
    time: new Date().toLocaleTimeString(),
    label: endpoint.label,
    path: endpoint.path,
    url,
    status,
    latency,
    ok,
    note,
  });
}

function renderStats() {
  const avg = state.total ? Math.round(state.latencySum / state.total) : 0;
  els.totalCount.textContent = state.total;
  els.okCount.textContent = state.ok;
  els.errorCount.textContent = state.error;
  els.avgLatency.textContent = `${avg} ms`;
}

function appendLog(row) {
  if (state.total === 1) {
    els.requestLog.innerHTML = "";
  }

  const tr = document.createElement("tr");
  tr.innerHTML = `
    <td>${escapeHtml(row.time)}</td>
    <td><code>${escapeHtml(row.path)}</code></td>
    <td>${escapeHtml(row.url)}</td>
    <td class="${row.ok ? "ok-text" : "bad-text"}">${escapeHtml(row.status)}</td>
    <td>${row.latency} ms</td>
    <td>${escapeHtml(row.note)}</td>
  `;
  els.requestLog.prepend(tr);

  while (els.requestLog.children.length > 80) {
    els.requestLog.lastElementChild.remove();
  }
}

function updateHealth(ok) {
  els.healthStatus.classList.toggle("ok", ok);
  els.healthStatus.classList.toggle("bad", !ok);
  els.healthStatus.textContent = ok ? "Backend OK" : "Backend lỗi";
}

function startAutoTraffic() {
  stopAutoTraffic();
  const interval = Math.max(Number(els.intervalMs.value) || 1000, 250);

  state.timer = window.setInterval(() => {
    callApi(pickProfileEndpoint());
  }, interval);

  callApi(pickProfileEndpoint());
}

function stopAutoTraffic() {
  if (state.timer) {
    window.clearInterval(state.timer);
    state.timer = null;
  }
}

function sendBurst() {
  const count = Math.min(Math.max(Number(els.burstCount.value) || 1, 1), 100);

  for (let i = 0; i < count; i += 1) {
    window.setTimeout(() => {
      callApi(pickProfileEndpoint());
    }, i * 80);
  }
}

function clearLog() {
  state.total = 0;
  state.ok = 0;
  state.error = 0;
  state.latencySum = 0;
  renderStats();
  els.requestLog.innerHTML = '<tr><td colspan="6" class="muted">Chưa có request.</td></tr>';
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function bindEvents() {
  document.querySelectorAll("[data-api]").forEach((button) => {
    button.addEventListener("click", () => callApi(button.dataset.api));
  });

  els.saveBase.addEventListener("click", saveApiBase);
  els.startAuto.addEventListener("click", startAutoTraffic);
  els.stopAuto.addEventListener("click", stopAutoTraffic);
  els.sendBurst.addEventListener("click", sendBurst);
  els.clearLog.addEventListener("click", clearLog);

  els.apiBase.addEventListener("keydown", (event) => {
    if (event.key === "Enter") {
      saveApiBase();
    }
  });
}

function init() {
  els.apiBase.value = loadApiBase();
  bindEvents();
  renderStats();
  callApi("health");
}

init();
