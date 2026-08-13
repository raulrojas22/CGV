#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const calls = [];
const elementsById = new Map();
const documentMock = {
  body: {
    classList: { add() {}, remove() {} },
    appendChild() {}
  },
  readyState: "complete",
  addEventListener() {},
  querySelector() { return null; },
  querySelectorAll() { return []; },
  getElementById(id) { return elementsById.get(id) || null; }
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
const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function main() {
  windowMock.CGVSharedAnalysis.capture({
    request_id: "fast-test",
    capture_mode: "fast",
    capture_contexts: ["multi_gene"],
    analytics_contexts: ["homo"],
    structural_targets: { homo: ["1"] }
  });
  await wait(25);

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

  calls.length = 0;
  elementsById.set("figure_studio_state", { value: '{"panels":[{"id":"saved"}]}' });
  let resolveStudioLoad;
  let studioLoadCalls = 0;
  windowMock.CGVFigureStudioLoader = {
    pendingRestoreCount() { return 1; },
    whenReady() {
      studioLoadCalls += 1;
      return new Promise((resolve) => { resolveStudioLoad = resolve; });
    }
  };
  windowMock.CGVSharedAnalysis.capture({
    request_id: "studio-wait-test",
    capture_mode: "fast",
    capture_contexts: ["figure_studio"]
  });
  await wait(10);
  assert.equal(studioLoadCalls, 1, "saved Figure Studio capture should start the lazy loader");
  assert.equal(
    calls.some((call) => call.id === "cgv_analysis_assets"),
    false,
    "capture must wait until the saved Figure Studio state can be restored"
  );
  resolveStudioLoad();
  await wait(25);
  assert.equal(
    calls.filter((call) => call.id === "cgv_analysis_assets").length,
    1,
    "capture should resume exactly once after Figure Studio loads"
  );

  calls.length = 0;
  windowMock.CGVFigureStudioLoader = {
    pendingRestoreCount() { return 1; },
    whenReady() { return Promise.reject(new Error("fixture load failure")); }
  };
  windowMock.CGVSharedAnalysis.capture({
    request_id: "studio-failure-test",
    capture_mode: "fast",
    capture_contexts: ["figure_studio"]
  });
  await wait(25);
  const failedStudioPayload = calls.find((call) => call.id === "cgv_analysis_assets");
  assert.ok(failedStudioPayload, "a failed lazy load must not stall report capture");
  assert.ok(
    failedStudioPayload.value.missing.some((item) => /Figure Studio: fixture load failure/.test(item)),
    "a failed Figure Studio load should be reported as a missing capture"
  );

  console.log("Reproducible report browser tests passed.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
