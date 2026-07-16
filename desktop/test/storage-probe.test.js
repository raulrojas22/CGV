const assert = require("node:assert/strict");
const path = require("node:path");
const test = require("node:test");
const { buildStorageProbeExpression, recommendedStorageRoot } = require("../src/storage-probe");

test("Windows storage recommendation stays under the local CGV profile", () => {
  assert.equal(
    recommendedStorageRoot("C:\\Users\\Raul\\AppData\\Local\\CGV Desktop"),
    path.join("C:\\Users\\Raul\\AppData\\Local\\CGV Desktop", "Storage")
  );
});

test("R storage probe checks data and cache using Unicode, slash-safe Windows paths", () => {
  const expression = buildStorageProbeExpression("C:\\Users\\Raul\\CGV Datos á", "test:id");
  assert.match(expression, /C:\/Users\/Raul\/CGV Datos á\/data/);
  assert.match(expression, /C:\/Users\/Raul\/CGV Datos á\/cache/);
  assert.match(expression, /\.cgv-r-write-probe-test-id/);
  assert.match(expression, /writeLines\('cgv-storage-ok'/);
  assert.doesNotMatch(expression, /C:\\Users/);
});
