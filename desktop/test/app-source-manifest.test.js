const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  buildAppSourceManifest,
  collectSourceFiles,
  sha256File,
} = require("../scripts/write-app-source-manifest");

const repoRoot = path.resolve(__dirname, "..", "..");

test("application source manifest identifies the exact modern Shiny source", () => {
  const revision = "0123456789abcdef0123456789abcdef01234567";
  const sourceFiles = collectSourceFiles(repoRoot);
  const manifest = buildAppSourceManifest({
    root: repoRoot,
    env: { CGV_DESKTOP_SOURCE_REVISION: revision }
  });

  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest.appVersion, "0.1.3");
  assert.equal(manifest.sourceRevision, revision);
  assert.deepEqual(Object.keys(manifest.files), sourceFiles);
  assert.ok(sourceFiles.length > 100, "the manifest must cover the complete packaged Shiny application");
  for (const requiredPath of [
    "R/ui_desktop_downloads.R",
    "www/home_preview_cgv.html",
    "www/js/keepalive.js",
    "www/js/cgv_desktop_downloads.js"
  ]) {
    assert.ok(sourceFiles.includes(requiredPath), `missing packaged source: ${requiredPath}`);
  }
  for (const relativePath of sourceFiles) {
    const absolutePath = path.join(repoRoot, relativePath);
    assert.equal(manifest.files[relativePath].sha256, sha256File(absolutePath));
    assert.equal(manifest.files[relativePath].bytes, fs.statSync(absolutePath).size);
  }
});
