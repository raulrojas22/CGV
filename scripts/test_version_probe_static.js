#!/usr/bin/env node

const assert = require("assert");
const fs = require("fs");
const path = require("path");
const vm = require("vm");

const root = path.resolve(__dirname, "..");
const script = fs.readFileSync(path.join(root, "www/js/version_probe.js"), "utf8");
const globalCode = fs.readFileSync(path.join(root, "global.R"), "utf8");
const uiCode = fs.readFileSync(path.join(root, "ui.R"), "utf8");

assert.ok(globalCode.includes('shiny::addResourcePath("cgv-meta", .cgv_runtime_metadata_dir)'));
assert.ok(globalCode.includes('file.path(.cgv_runtime_metadata_dir, "version.json")'));
assert.ok(uiCode.includes('window.__cgvVersionProbeUrl = %s'));
assert.ok(!script.includes("DOMParser"));
assert.ok(!script.includes("resp.text()"));
assert.ok(script.includes("resp.json()"));
assert.ok(!script.includes("Date.now()"), "Probe URL must remain stable for conditional revalidation");
assert.ok(!script.includes("cache: 'no-store'"), "Probe must allow browser/HTTP validators");

async function runProbe(latestVersion) {
  let domReady;
  let requestedUrl = "";
  let replacedUrl = "";
  const window = {
    location: {
      href: "https://example.test/app_i/cgv/session-1/?tab=home",
      replace(value) { replacedUrl = value; }
    },
    fetch(url) {
      requestedUrl = String(url);
      return Promise.resolve({
        ok: true,
        json: () => Promise.resolve({ version: latestVersion })
      });
    }
  };
  const document = {
    baseURI: "https://example.test/app_i/cgv/session-1/",
    readyState: "loading",
    addEventListener(type, callback) {
      if (type === "DOMContentLoaded") domReady = callback;
    }
  };
  const context = vm.createContext({ window, document, URL, Date, Promise });
  vm.runInContext(script, context);

  // Configuration is deliberately supplied after script evaluation to guard
  // against the parser ordering bug that existed in the old implementation.
  window.__cgvAppVersion = "build-a";
  window.__cgvVersionProbeUrl = "cgv-meta/version.json";
  domReady();
  await new Promise((resolve) => setImmediate(resolve));
  await new Promise((resolve) => setImmediate(resolve));

  return { requestedUrl, replacedUrl };
}

(async () => {
  const same = await runProbe("build-a");
  assert.match(same.requestedUrl, /\/app_i\/cgv\/session-1\/cgv-meta\/version[.]json$/);
  assert.strictEqual(same.replacedUrl, "");

  const changed = await runProbe("build-b");
  assert.match(changed.replacedUrl, /[?&]v=build-b(?:&|$)/);
  assert.ok(!changed.requestedUrl.includes("tab=home"), "Probe must not refetch the full page URL");

  console.log("version-probe-static-ok");
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
