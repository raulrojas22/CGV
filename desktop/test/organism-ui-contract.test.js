const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");

const uiPath = path.resolve(__dirname, "..", "..", "ui.R");
const ui = fs.readFileSync(uiPath, "utf8");
const preload = fs.readFileSync(path.resolve(__dirname, "..", "src", "preload.js"), "utf8");
const main = fs.readFileSync(path.resolve(__dirname, "..", "src", "main.js"), "utf8");

test("completed downloads clear the transient status before percent rendering", () => {
  const completeBranch = ui.indexOf("if (payload.phase === 'complete')");
  const percentBranch = ui.indexOf("if (payload.percent != null)", completeBranch);
  assert.ok(completeBranch >= 0, "missing completed-download status branch");
  assert.ok(percentBranch > completeBranch, "completed downloads must be handled before generic percent progress");
  assert.match(ui.slice(completeBranch, percentBranch), /clearDesktopOrganismStatusIfIdle\(\)/);
});

test("organism removal sends the selected dataset ids and exposes one/several/all controls", () => {
  assert.match(ui, /removeInstalledOrganisms\(selectedIds\)/);
  assert.match(preload, /removeInstalledOrganisms: \(datasetIds\).*datasetIds/);
  assert.match(main, /removeInstalledDatasets\(\{/);
  assert.match(ui, /id = "desktop-organism-remove-all"/);
  assert.match(ui, /id = "desktop-organism-remove-selected"/);
  assert.match(ui, /Choose one, several, or all downloaded organisms/);
});

test("successful removal no longer leaves the catalog-refresh message visible", () => {
  assert.doesNotMatch(ui, /Installed organisms removed\. Refreshing catalog/);
});
