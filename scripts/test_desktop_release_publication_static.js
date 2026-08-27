#!/usr/bin/env node

const assert = require("assert");
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), "utf8");

const config = JSON.parse(read("www/desktop-release-source.json"));
assert.strictEqual(typeof config.manifestUrl, "string");
assert.ok(!config.manifestUrl || /^https:\/\//.test(config.manifestUrl));
assert.ok(/^https:\/\//.test(config.fallback.api));

const browserCode = read("www/js/cgv_desktop_downloads.js");
assert.ok(browserCode.includes('var RELEASE_SOURCE_CONFIG = "desktop-release-source.json"'));
assert.ok(browserCode.includes("mapOracleManifest"));
assert.ok(browserCode.includes("isSha256"));
assert.ok(browserCode.includes('"windows-x64"'));
assert.ok(browserCode.includes("findGithubRelease(fallback)"));
assert.ok(browserCode.includes('document.addEventListener("shown.bs.tab"'));
assert.ok(browserCode.includes('value === "desktop-app"'));
assert.ok(browserCode.includes("ready(boot)"));
assert.ok(!browserCode.includes("ready(init)"), "Desktop release lookup must wait until its hidden tab is opened");

const uiCode = read("R/ui_desktop_downloads.R");
for (const kind of ["mac-arm64", "mac-x64", "linux-appimage", "linux-deb", "windows-x64"]) {
  assert.ok(uiCode.includes(`cgv_desktop_asset_action("${kind}"`), `Missing UI asset ${kind}`);
}
assert.ok(!/\b(?:signed|unsigned|SignPath)\b/i.test(uiCode), "Public download UI must use neutral Windows wording");

const preparationScript = read("scripts/preparar-publicacion-desktop.sh");
assert.ok(preparationScript.includes('"windows-x64|CGeV-Desktop-$VERSION-Windows-x64-Setup.exe"'));
assert.ok(!preparationScript.includes("--include-windows-signed"));

for (const script of [
  "scripts/configurar-url-oracle-desktop.sh",
  "scripts/preparar-publicacion-desktop.sh"
]) {
  const mode = fs.statSync(path.join(root, script)).mode;
  assert.ok(mode & 0o100, `${script} must be executable`);
}

console.log("desktop-release-publication-static-ok");
