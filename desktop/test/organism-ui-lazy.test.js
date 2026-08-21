const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const uiPath = path.resolve(__dirname, "..", "..", "ui.R");

function organismScript() {
  const ui = fs.readFileSync(uiPath, "utf8");
  const anchor = ui.indexOf("var desktopDatasetProgress = {};");
  assert.ok(anchor >= 0, "organism UI script anchor is missing");
  const wrapper = ui.lastIndexOf('tags$script(HTML("', anchor);
  const start = ui.indexOf("(function() {", wrapper);
  const endMarker = "        })();";
  const end = ui.indexOf(endMarker, anchor);
  assert.ok(start >= 0 && end > start, "organism UI IIFE could not be extracted");
  const encoded = ui.slice(start, end + endMarker.length);
  return JSON.parse(`"${encoded.replace(/\r/g, "\\r").replace(/\n/g, "\\n")}"`);
}

class FakeClassList {
  constructor(values = []) {
    this.values = new Set(values);
  }
  add(value) { this.values.add(value); }
  contains(value) { return this.values.has(value); }
  remove(value) { this.values.delete(value); }
  toggle(value, force) {
    if (force === undefined) force = !this.values.has(value);
    if (force) this.values.add(value);
    else this.values.delete(value);
    return force;
  }
}

class FakeElement {
  constructor(id = "") {
    this.id = id;
    this.attributes = {};
    this.children = [];
    this.classList = new FakeClassList();
    this.dataset = {};
    this.disabled = false;
    this.innerHTML = "";
    this.listeners = new Map();
    this.textContent = "";
    this.title = "";
    this.value = "";
  }
  addEventListener(type, callback) {
    if (!this.listeners.has(type)) this.listeners.set(type, []);
    this.listeners.get(type).push(callback);
  }
  append(...children) { this.children.push(...children); }
  appendChild(child) { this.children.push(child); return child; }
  closest() { return null; }
  fire(type, detail = {}) {
    const event = { target: this, type, ...detail };
    for (const callback of this.listeners.get(type) || []) callback(event);
  }
  focus() { this.focused = true; }
  getAttribute(name) { return this.attributes[name] || null; }
  querySelector() { return null; }
  querySelectorAll() { return []; }
  removeAttribute(name) { delete this.attributes[name]; }
  replaceChildren(...children) { this.children = children; }
  setAttribute(name, value) { this.attributes[name] = String(value); }
}

function deferred() {
  let resolve;
  let reject;
  const promise = new Promise((res, rej) => { resolve = res; reject = rej; });
  return { promise, reject, resolve };
}

async function flush() {
  await Promise.resolve();
  await new Promise((resolve) => setImmediate(resolve));
}

function makeHarness({ active = false, desktop = true, listFactory } = {}) {
  const documentListeners = new Map();
  const jqueryHandlers = new Map();
  const elements = new Map();
  const log = [];
  const addElement = (id) => {
    const element = new FakeElement(id);
    elements.set(id, element);
    return element;
  };
  for (const id of [
    "desktop-organism-cache-path",
    "desktop-organism-count",
    "desktop-organism-data-path",
    "desktop-organism-filter",
    "desktop-organism-installed-count",
    "desktop-organism-list",
    "desktop-organism-modal",
    "desktop-organism-modal-count",
    "desktop-organism-modal-list",
    "desktop-organism-open-catalog",
    "desktop-organism-pending-count",
    "desktop-organism-refresh",
    "desktop-organism-reset",
    "desktop-organism-search",
    "desktop-organism-status"
  ]) addElement(id);

  const pane = new FakeElement("settings-pane");
  pane.classList = new FakeClassList(active ? ["active"] : []);
  const settingsRoot = new FakeElement("settings-root");
  settingsRoot.closest = (selector) => selector === ".tab-pane" ? pane : null;
  const settingsNav = new FakeElement("settings-nav");
  settingsNav.closest = (selector) => selector.includes('data-target="settings"') ? settingsNav : null;

  const document = {
    addEventListener(type, callback) {
      if (!documentListeners.has(type)) documentListeners.set(type, []);
      documentListeners.get(type).push(callback);
    },
    createElement: () => new FakeElement(),
    dispatch(type, detail = {}) {
      const event = { type, ...detail };
      for (const callback of documentListeners.get(type) || []) callback(event);
    },
    getElementById: (id) => elements.get(id) || null,
    querySelector(selector) {
      if (selector === ".app-settings-pane") return settingsRoot;
      if (selector.includes("#navtabs li.active") || selector.includes("#navtabs a.active")) return active ? settingsNav : null;
      if (selector.includes('.app-nav-btn.is-active[data-target="settings"]')) return active ? settingsNav : null;
      return null;
    },
    querySelectorAll: () => []
  };

  let progressCallback = null;
  let listCalls = 0;
  let runtimeCalls = 0;
  const cgvDesktop = desktop ? {
    getRuntime() {
      runtimeCalls += 1;
      log.push("runtime");
      return Promise.resolve({ dataRoot: "/data", cacheRoot: "/cache" });
    },
    listDatasets() {
      listCalls += 1;
      log.push("list");
      return listFactory ? listFactory(listCalls) : Promise.resolve({ datasets: [] });
    },
    onDownloadProgress(callback) {
      log.push("progress-bound");
      progressCallback = callback;
    }
  } : null;

  function jQuery() {
    return {
      on(name, callback) { jqueryHandlers.set(name, callback); }
    };
  }
  const window = {
    CSS: { escape: (value) => String(value) },
    cgvDesktop,
    clearTimeout,
    confirm: () => true,
    jQuery,
    setTimeout
  };
  const context = vm.createContext({
    Array,
    Date,
    Error,
    Intl,
    Map,
    Math,
    Number,
    Object,
    Promise,
    Set,
    String,
    URL,
    clearTimeout,
    console,
    document,
    isFinite,
    jQuery,
    setTimeout,
    window
  });
  vm.runInContext(organismScript(), context, { filename: "ui-organism-inline.js" });

  return {
    document,
    elements,
    fireJquery(name, event) {
      const callback = jqueryHandlers.get(name);
      assert.ok(callback, `missing jQuery handler ${name}`);
      callback(event);
    },
    get listCalls() { return listCalls; },
    get progressCallback() { return progressCallback; },
    get runtimeCalls() { return runtimeCalls; },
    log,
    settingsNav
  };
}

test("hidden Settings performs no Desktop IPC, while web still renders its Desktop-only state", async () => {
  const desktop = makeHarness({ active: false, desktop: true });
  desktop.document.dispatch("DOMContentLoaded");
  await flush();
  assert.equal(desktop.listCalls, 0);
  assert.equal(desktop.runtimeCalls, 0);
  assert.equal(typeof desktop.progressCallback, "function", "progress must bind eagerly even while Settings is hidden");
  desktop.progressCallback({ phase: "connecting" });
  assert.equal(desktop.elements.get("desktop-organism-status").textContent, "Connecting organism package...");

  const web = makeHarness({ active: false, desktop: false });
  web.document.dispatch("DOMContentLoaded");
  await flush();
  assert.match(web.elements.get("desktop-organism-list").innerHTML, /available only in CGeV Desktop/);
});

test("initial, click, Bootstrap shown and Shiny programmatic Settings activation each load the catalog", async () => {
  const initial = makeHarness({ active: true });
  initial.document.dispatch("DOMContentLoaded");
  await flush();
  assert.equal(initial.listCalls, 1);
  assert.ok(initial.log.indexOf("progress-bound") < initial.log.indexOf("list"));

  const click = makeHarness();
  click.document.dispatch("DOMContentLoaded");
  click.document.dispatch("click", { target: click.settingsNav });
  await flush();
  assert.equal(click.listCalls, 1);

  const shown = makeHarness({ active: true });
  shown.document.dispatch("DOMContentLoaded");
  await flush();
  shown.document.dispatch("shown.bs.tab", { target: shown.settingsNav });
  await flush();
  assert.equal(shown.listCalls, 2, "a later Settings activation must revalidate rather than use a TTL");

  const shiny = makeHarness();
  shiny.document.dispatch("DOMContentLoaded");
  shiny.fireJquery("shiny:inputchanged.cgvDesktopDatasets", { name: "navtabs", value: "settings" });
  await flush();
  assert.equal(shiny.listCalls, 1);
});

test("simultaneous activation/open/refresh events share one in-flight request, then Refresh revalidates", async () => {
  const pending = [];
  const harness = makeHarness({
    listFactory() {
      const next = deferred();
      pending.push(next);
      return next.promise;
    }
  });
  harness.document.dispatch("DOMContentLoaded");
  harness.document.dispatch("click", { target: harness.settingsNav });
  harness.document.dispatch("shown.bs.tab", { target: harness.settingsNav });
  harness.fireJquery("shiny:inputchanged.cgvDesktopDatasets", { name: "navtabs", value: "settings" });
  harness.elements.get("desktop-organism-open-catalog").fire("click");
  harness.elements.get("desktop-organism-refresh").fire("click");
  await flush();
  assert.equal(harness.listCalls, 1);
  assert.equal(harness.runtimeCalls, 1);
  assert.equal(harness.elements.get("desktop-organism-modal").attributes["aria-hidden"], "false");

  pending[0].resolve({ datasets: [] });
  await flush();
  harness.elements.get("desktop-organism-status").textContent = "old status";
  harness.elements.get("desktop-organism-refresh").fire("click");
  await flush();
  assert.equal(harness.listCalls, 2, "a settled explicit Refresh must perform a new revalidation");
  pending[1].resolve({ datasets: [] });
  await flush();
  assert.equal(harness.elements.get("desktop-organism-status").textContent, "");
});

test("catalog failures preserve the visible error and a later activation retries", async () => {
  const first = deferred();
  const harness = makeHarness({
    listFactory(call) {
      return call === 1 ? first.promise : Promise.resolve({ datasets: [] });
    }
  });
  harness.document.dispatch("DOMContentLoaded");
  harness.document.dispatch("click", { target: harness.settingsNav });
  await flush();
  first.reject(new Error("catalog offline"));
  await flush();
  assert.equal(harness.elements.get("desktop-organism-status").textContent, "catalog offline");

  harness.document.dispatch("click", { target: harness.settingsNav });
  await flush();
  assert.equal(harness.listCalls, 2);
});
