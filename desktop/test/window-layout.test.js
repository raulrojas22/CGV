const test = require("node:test");
const assert = require("node:assert/strict");
const { computeWindowBounds } = require("../src/window-layout");

test("fits a common 1600x768 Windows work area", () => {
  const bounds = computeWindowBounds({ width: 1600, height: 728 });
  assert.deepEqual(bounds, {
    width: 1472,
    height: 669,
    minWidth: 1040,
    minHeight: 620
  });
});

test("never exceeds a small display work area", () => {
  const bounds = computeWindowBounds({ width: 1024, height: 600 });
  assert.equal(bounds.width, 1024);
  assert.equal(bounds.height, 600);
  assert.equal(bounds.minWidth, 1024);
  assert.equal(bounds.minHeight, 600);
});

test("caps the initial window on large displays", () => {
  const bounds = computeWindowBounds({ width: 3840, height: 2160 });
  assert.equal(bounds.width, 1480);
  assert.equal(bounds.height, 960);
});
