const assert = require("node:assert/strict");
const test = require("node:test");
const { needsInitialStorageSelection, parseDesktopSettings } = require("../src/storage-settings");

test("desktop settings accept only schema version 1 with a storage root", () => {
  assert.deepEqual(parseDesktopSettings('{"schemaVersion":1,"storageRoot":" C:\\\\CGV "}'), {
    schemaVersion: 1,
    storageRoot: "C:\\CGV"
  });
  assert.deepEqual(parseDesktopSettings('{"schemaVersion":2,"storageRoot":"C:\\\\CGV"}'), {});
  assert.deepEqual(parseDesktopSettings("not json"), {});
});

test("packaged Windows prompts until both environment roots or a saved root exist", () => {
  const base = { platform: "win32", isPackaged: true, storageRoot: "" };
  assert.equal(needsInitialStorageSelection({ ...base, env: {} }), true);
  assert.equal(needsInitialStorageSelection({ ...base, env: { CGV_DESKTOP_DATA_ROOT: "D:\\data" } }), true);
  assert.equal(needsInitialStorageSelection({
    ...base,
    env: { CGV_DESKTOP_DATA_ROOT: "D:\\data", CGV_DESKTOP_CACHE_ROOT: "D:\\cache" }
  }), false);
  assert.equal(needsInitialStorageSelection({ ...base, env: {}, storageRoot: "D:\\CGV" }), false);
  assert.equal(needsInitialStorageSelection({ platform: "darwin", isPackaged: true, env: {}, storageRoot: "" }), false);
});
