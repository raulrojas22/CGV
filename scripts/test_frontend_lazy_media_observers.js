#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const uiSource = fs.readFileSync("ui.R", "utf8");
const guideStart = uiSource.indexOf('title = "CGeV Guide"');
const guideEnd = uiSource.indexOf('title = "Home"', guideStart);
assert.ok(guideStart >= 0 && guideEnd > guideStart, "CGeV Guide UI block must exist");
const guideSource = uiSource.slice(guideStart, guideEnd);

assert.match(guideSource, /preload = "none"/, "Guide video must not preload before activation");
assert.doesNotMatch(
  guideSource.slice(guideSource.indexOf("tags$video("), guideSource.indexOf("span(class = \"guide-video-icon\"")),
  /tags\$source\s*\(/,
  "Guide video must not render an initial source"
);
assert.doesNotMatch(guideSource, /preloadRouteVideos/, "Guide must not preload an entire route");
assert.match(guideSource, /if \(!guideActivated\) \{[\s\S]*?return;/, "Media loading must be activation-gated");
assert.match(guideSource, /function preloadNextVideo\(src\)/, "Guide must expose one-next-video preload logic");
assert.doesNotMatch(
  guideSource.slice(guideSource.indexOf("function preloadNextVideo"), guideSource.indexOf("function getStep")),
  /fetch\s*\(/,
  "Next-video preload must use only one request mechanism"
);

assert.doesNotMatch(
  uiSource,
  /tags\$script\(src = versioned_asset_path\("js\/info_button_relocator\.js"\)\)/,
  "Unused info relocator must not be shipped to the browser"
);

const appMain = { name: "app-main" };
const mobileMediaQuery = {
  matches: false,
  listener: null,
  addEventListener(name, listener) {
    if (name === "change") this.listener = listener;
  }
};
const phoneMediaQuery = { matches: false, addEventListener() {} };
const observerInstances = [];

class MutationObserverMock {
  constructor(callback) {
    this.callback = callback;
    this.observeCalls = [];
    this.disconnectCalls = 0;
    observerInstances.push(this);
  }
  observe(target, options) {
    this.observeCalls.push({ target, options });
  }
  disconnect() {
    this.disconnectCalls += 1;
  }
}

const documentMock = {
  readyState: "complete",
  body: { appendChild() {} },
  addEventListener() {},
  querySelector(selector) {
    if (selector === ".app-main") return appMain;
    return null;
  },
  querySelectorAll() {
    return [];
  }
};
const windowMock = {
  document: documentMock,
  navigator: { maxTouchPoints: 0 },
  __mobileEnhancementsInit: false,
  matchMedia(query) {
    return query === "(max-width: 960px)" ? mobileMediaQuery : phoneMediaQuery;
  },
  requestAnimationFrame(callback) {
    callback();
  }
};
windowMock.window = windowMock;

const context = vm.createContext({
  window: windowMock,
  document: documentMock,
  navigator: windowMock.navigator,
  MutationObserver: MutationObserverMock,
  requestAnimationFrame: windowMock.requestAnimationFrame,
  setTimeout(callback) {
    callback();
    return 1;
  },
  clearTimeout() {}
});

vm.runInContext(
  fs.readFileSync("www/js/mobile_enhancements.js", "utf8"),
  context,
  { filename: "mobile_enhancements.js" }
);

assert.equal(typeof mobileMediaQuery.listener, "function", "Mobile breakpoint changes must be observed");
assert.equal(
  observerInstances.some((observer) => observer.observeCalls.some((call) => call.target === appMain)),
  false,
  ".app-main must not be observed on desktop"
);

mobileMediaQuery.matches = true;
mobileMediaQuery.listener({ matches: true });
const contextObserver = observerInstances.find((observer) =>
  observer.observeCalls.some((call) => call.target === appMain)
);
assert.ok(contextObserver, ".app-main must be observed after entering the mobile breakpoint");

const disconnectsBeforeDesktop = contextObserver.disconnectCalls;
mobileMediaQuery.matches = false;
mobileMediaQuery.listener({ matches: false });
assert.ok(
  contextObserver.disconnectCalls > disconnectsBeforeDesktop,
  ".app-main observer must disconnect after returning to desktop"
);

console.log("Frontend lazy media and observer tests passed.");
