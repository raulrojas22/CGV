#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const repoRoot = path.resolve(__dirname, "..");
const read = (...parts) => fs.readFileSync(path.join(repoRoot, ...parts), "utf8");
const uiSource = read("ui.R");
const loaderSource = read("www", "js", "figure_studio_loader.js");
const studioSource = read("www", "js", "figure_studio.js");
const studioCss = read("www", "css", "figure_studio.css");

assert.doesNotMatch(
  uiSource,
  /tags\$link\(rel\s*=\s*"stylesheet",\s*href\s*=\s*versioned_asset_path\("css\/figure_studio\.css"\)\)/,
  "Figure Studio CSS must not be requested at cold boot"
);
assert.doesNotMatch(
  uiSource,
  /tags\$script\(src\s*=\s*versioned_asset_path\("js\/figure_studio\.js"\)\)/,
  "Figure Studio JS must not be requested at cold boot"
);
assert.match(
  uiSource,
  /id\s*=\s*"cgv-figure-studio-loader"[\s\S]*`data-module-src`\s*=\s*versioned_asset_path\("js\/figure_studio\.js"\)[\s\S]*`data-style-href`\s*=\s*versioned_asset_path\("css\/figure_studio\.css"\)[\s\S]*HTML\(figure_studio_loader_source\)/,
  "The inline bootstrap must retain versioned JS and CSS routes"
);
assert.match(
  uiSource,
  /readLines\(file\.path\("www", "js", "figure_studio_loader\.js"\)/,
  "The tested loader source must be embedded directly in the initial page"
);
assert.doesNotMatch(
  studioCss,
  /#homo_analytics_tabs|#ortho_analytics_tabs|btn-analytics-download-all/,
  "The deferred stylesheet must contain only Figure Studio-owned rules"
);
assert.match(
  uiSource,
  /#homo_analytics_tabs > \.nav,[\s\S]*\.btn-analytics-download-all\[aria-busy=/,
  "Shared Analytics rules must remain eager and unchanged"
);
assert.match(
  studioSource,
  /if \(!window\.CGVFigureStudioLoader\) \{[\s\S]*document\.addEventListener\("shiny:connected", init\)/,
  "The module must wait for the loader when loaded through the app"
);

class EventNode {
  constructor(tagName) {
    this.tagName = String(tagName || "").toUpperCase();
    this.attributes = Object.create(null);
    this.listeners = Object.create(null);
    this.parentNode = null;
    this.id = "";
    this.rel = "";
    this.href = "";
    this.src = "";
    this.async = false;
    this.sheet = null;
  }

  addEventListener(type, handler) {
    if (!this.listeners[type]) this.listeners[type] = [];
    this.listeners[type].push(handler);
  }

  setAttribute(name, value) {
    this.attributes[name] = String(value);
  }

  getAttribute(name) {
    return Object.prototype.hasOwnProperty.call(this.attributes, name)
      ? this.attributes[name]
      : null;
  }

  emit(type) {
    if (type === "load" && this.tagName === "LINK") this.sheet = {};
    (this.listeners[type] || []).slice().forEach((handler) => handler({ type, target: this }));
  }
}

function createHarness(options = {}) {
  const listeners = Object.create(null);
  const nodesById = new Map();
  const appended = [];
  const documentEvents = [];
  const shinyHandlers = Object.create(null);
  const warnings = [];
  const pendingTimers = [];
  let mutationObserverCount = 0;

  const head = {
    appendChild(node) {
      node.parentNode = head;
      appended.push(node);
      if (node.id) nodesById.set(node.id, node);
      return node;
    },
    removeChild(node) {
      if (node.id) nodesById.delete(node.id);
      node.parentNode = null;
      return node;
    }
  };

  const bootstrap = new EventNode("script");
  bootstrap.setAttribute("data-module-src", "js/figure_studio.js?av=test-build");
  bootstrap.setAttribute("data-style-href", "css/figure_studio.css?av=test-build");

  const documentMock = {
    currentScript: bootstrap,
    readyState: "complete",
    head,
    documentElement: {},
    addEventListener(type, handler) {
      if (!listeners[type]) listeners[type] = [];
      listeners[type].push(handler);
    },
    dispatchEvent(event) {
      documentEvents.push(event.type);
      (listeners[event.type] || []).slice().forEach((handler) => handler(event));
      return true;
    },
    emit(type, event = {}) {
      const payload = Object.assign({ type, target: null }, event);
      (listeners[type] || []).slice().forEach((handler) => handler(payload));
    },
    createElement(tagName) {
      return new EventNode(tagName);
    },
    getElementById(id) {
      return nodesById.get(id) || null;
    },
    getElementsByTagName(name) {
      return String(name).toLowerCase() === "head" ? [head] : [];
    },
    querySelector() {
      return null;
    }
  };

  function CustomEventMock(type) {
    this.type = type;
  }

  function MutationObserverMock() {
    mutationObserverCount += 1;
  }

  const windowMock = {
    document: documentMock,
    CustomEvent: CustomEventMock,
    Shiny: {
      addCustomMessageHandler(name, handler) {
        shinyHandlers[name] = handler;
      }
    },
    console: {
      warn(...args) {
        warnings.push(args);
      }
    }
  };
  windowMock.window = windowMock;

  const context = vm.createContext({
    window: windowMock,
    document: documentMock,
    MutationObserver: MutationObserverMock,
    Promise,
    Error,
    setTimeout(callback) {
      if (options.controlTimers) {
        pendingTimers.push(callback);
        return pendingTimers.length;
      }
      callback();
      return 1;
    },
    clearTimeout() {}
  });
  vm.runInContext(loaderSource, context, { filename: "figure_studio_loader.js" });

  return {
    window: windowMock,
    document: documentMock,
    appended,
    documentEvents,
    shinyHandlers,
    warnings,
    mutationObserverCount: () => mutationObserverCount,
    pendingTimerCount: () => pendingTimers.length,
    flushTimers() {
      while (pendingTimers.length) pendingTimers.shift()();
    },
    node(id) {
      return nodesById.get(id) || null;
    }
  };
}

function studioTrigger() {
  return {
    closest(selector) {
      assert.match(selector, /figure-studio/);
      return { dataset: { target: "figure-studio" } };
    }
  };
}

async function main() {
  const harness = createHarness();
  const loader = harness.window.CGVFigureStudioLoader;
  assert.ok(loader, "Loader API must be exposed");
  assert.equal(harness.appended.length, 0, "Cold boot must request no Figure Studio asset");
  assert.equal(harness.mutationObserverCount(), 0, "Cold boot must create no Figure Studio observer");
  assert.equal(typeof harness.shinyHandlers["cgv:figure-studio-restore"], "function", "Early restore handler must be registered");

  harness.document.emit("pointerdown", { target: studioTrigger() });
  const firstPromise = loader.load();
  const concurrentPromise = loader.load();
  assert.strictEqual(firstPromise, concurrentPromise, "Concurrent calls must share one Promise");
  harness.document.emit("focusin", { target: studioTrigger() });
  harness.document.emit("click", { target: studioTrigger() });

  assert.equal(
    harness.appended.filter((node) => node.tagName === "LINK").length,
    1,
    "First interaction must append exactly one stylesheet"
  );
  assert.equal(
    harness.appended.filter((node) => node.tagName === "SCRIPT").length,
    1,
    "First interaction must append exactly one module script"
  );
  const style = harness.node("cgv-figure-studio-style");
  const script = harness.node("cgv-figure-studio-module");
  assert.equal(style.href, "css/figure_studio.css?av=test-build", "Stylesheet route must stay versioned");
  assert.equal(script.src, "js/figure_studio.js?av=test-build", "Script route must stay versioned");
  assert.equal(script.async, true, "Dynamic module must not block the parser");

  const calls = { init: 0, restore: [], open: 0 };
  harness.window.CGVFigureStudio = {
    init() { calls.init += 1; },
    restore(message) { calls.restore.push(message); },
    open() { calls.open += 1; }
  };
  harness.shinyHandlers["cgv:figure-studio-restore"]("saved-before-load");
  assert.equal(loader.pendingRestoreCount(), 1, "Restore arriving during load must be queued");
  style.emit("load");
  script.emit("load");
  const loadedApi = await firstPromise;

  assert.strictEqual(loadedApi, harness.window.CGVFigureStudio, "Loader must resolve to the module API");
  assert.equal(calls.init, 1, "Module must initialize once after both assets load");
  assert.deepEqual(calls.restore, ["saved-before-load"], "Queued restore must be delivered unchanged");
  assert.equal(calls.open, 0, "Loader must not alter or replay navigation");
  assert.equal(loader.pendingRestoreCount(), 0, "Restore queue must drain after initialization");
  assert.ok(harness.documentEvents.includes("cgv:figure-studio-ready"), "Successful load must announce readiness");
  assert.equal(harness.warnings.length, 0, "Successful load must not warn");

  harness.document.emit("click", { target: studioTrigger() });
  await loader.load();
  assert.equal(calls.init, 1, "Later interactions must remain idempotent");
  assert.equal(harness.appended.length, 2, "Later interactions must not duplicate assets");

  const retryHarness = createHarness();
  const retryLoader = retryHarness.window.CGVFigureStudioLoader;
  const failedPromise = retryLoader.load();
  const failedScript = retryHarness.node("cgv-figure-studio-module");
  failedScript.emit("error");
  await assert.rejects(failedPromise, /could not be loaded/, "Initial load error must reject");
  assert.equal(retryHarness.node("cgv-figure-studio-module"), null, "Failed script node must be removed");
  assert.equal(retryHarness.node("cgv-figure-studio-style"), null, "Incomplete style node must be removed");

  const retryPromise = retryLoader.load();
  const retryStyle = retryHarness.node("cgv-figure-studio-style");
  const retryScript = retryHarness.node("cgv-figure-studio-module");
  assert.notStrictEqual(retryScript, failedScript, "Retry must create a fresh script node");
  let retryInit = 0;
  retryHarness.window.CGVFigureStudio = {
    init() { retryInit += 1; },
    restore() {}
  };
  retryStyle.emit("load");
  retryScript.emit("load");
  await retryPromise;
  assert.equal(retryInit, 1, "A clean retry must initialize normally");

  const restoreHarness = createHarness({ controlTimers: true });
  const restoreLoader = restoreHarness.window.CGVFigureStudioLoader;
  const restoreCalls = [];
  const restorePromise = restoreLoader.load();
  restoreHarness.window.CGVFigureStudio = {
    init() {},
    restore(message) { restoreCalls.push(message); }
  };
  restoreHarness.shinyHandlers["cgv:figure-studio-restore"]("delayed-restore");
  restoreHarness.node("cgv-figure-studio-style").emit("load");
  restoreHarness.node("cgv-figure-studio-module").emit("load");
  let restoreSettled = false;
  restorePromise.then(function () { restoreSettled = true; });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(restoreHarness.pendingTimerCount(), 1, "Queued restore must schedule one readiness timer");
  assert.equal(restoreSettled, false, "Loader must not resolve before queued restore is applied");
  assert.deepEqual(restoreCalls, [], "Queued restore must remain pending until its readiness timer runs");
  restoreHarness.flushTimers();
  await restorePromise;
  assert.deepEqual(restoreCalls, ["delayed-restore"], "Readiness must include applying queued restore state");
  assert.equal(restoreSettled, true, "Loader should resolve after queued restore has completed");

  restoreHarness.shinyHandlers["cgv:figure-studio-restore"]("late-restore");
  assert.equal(restoreLoader.pendingRestoreCount(), 1, "Late restore must remain visible to readiness checks");
  const lateReady = restoreLoader.whenReady();
  let lateSettled = false;
  lateReady.then(function () { lateSettled = true; });
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(restoreHarness.pendingTimerCount(), 1, "Late restore must schedule one readiness timer");
  assert.equal(lateSettled, false, "Late restore must also block readiness until applied");
  restoreHarness.flushTimers();
  await lateReady;
  assert.deepEqual(restoreCalls, ["delayed-restore", "late-restore"], "Late restore must be serialized through the loader");
  assert.equal(restoreLoader.pendingRestoreCount(), 0, "Late restore tracking must drain after application");

  console.log("Figure Studio lazy loader VM/static tests passed.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
