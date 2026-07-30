#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const calls = [];
const documentMock = {
  body: {
    classList: { add() {}, remove() {} },
    appendChild() {}
  },
  readyState: "complete",
  addEventListener() {},
  querySelector() { return null; },
  querySelectorAll() { return []; },
  getElementById() { return null; }
};
const windowMock = {
  document: documentMock,
  localStorage: { getItem() { return null; }, setItem() {} },
  navigator: {},
  setTimeout,
  clearTimeout,
  setInterval,
  clearInterval,
  requestAnimationFrame(callback) { callback(); },
  getComputedStyle() { return { display: "none", zIndex: "1050" }; },
  Shiny: {
    setInputValue(id, value) { calls.push({ id, value }); },
    addCustomMessageHandler() {}
  }
};
windowMock.window = windowMock;

const context = vm.createContext({
  window: windowMock,
  document: documentMock,
  navigator: windowMock.navigator,
  Blob,
  Date,
  Math,
  Promise,
  Set,
  XMLSerializer: class {
    serializeToString() { return ""; }
  },
  setTimeout,
  clearTimeout,
  setInterval,
  clearInterval
});

const source = fs.readFileSync("www/js/reproducible_report.js", "utf8");
vm.runInContext(source, context, { filename: "reproducible_report.js" });

assert.ok(windowMock.CGVSharedAnalysis);
windowMock.CGVSharedAnalysis.capture({
  request_id: "fast-test",
  capture_mode: "fast",
  capture_contexts: ["multi_gene"],
  analytics_contexts: ["homo"],
  structural_targets: { homo: ["1"] }
});

setTimeout(() => {
  assert.equal(
    calls.some((call) => call.id === "homo_analytics_export_all_nonce"),
    false,
    "fast capture must not request hidden Analytics"
  );
  assert.equal(
    calls.some((call) => call.id === "figure_studio_plot_render_request"),
    false,
    "fast capture must not request hidden structures"
  );
  const payloadCall = calls.find((call) => call.id === "cgv_analysis_assets");
  assert.ok(payloadCall, "fast capture should submit one report payload");
  assert.equal(payloadCall.value.capture_mode, "fast");
  assert.equal(payloadCall.value.assets.length, 0);
  assert.equal(payloadCall.value.omitted.length, 1);
  assert.ok(Number.isFinite(payloadCall.value.timings.client_capture_ms));
  console.log("Reproducible report browser tests passed.");
}, 25);
