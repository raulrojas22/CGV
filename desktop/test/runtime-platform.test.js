const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const {
  bundledRuntimeResourceParts,
  executableNames,
  isUsableExecutable,
  runtimeExecutableCandidates,
  shouldInstallRuntimeLocally
} = require("../src/runtime-platform");

test("development runtime is loaded from the source resources directory", () => {
  assert.deepEqual(
    bundledRuntimeResourceParts(false, "darwin-arm64"),
    ["resources", "r", "darwin-arm64"]
  );
});

test("packaged runtime is loaded from Electron's extraResources directory", () => {
  assert.deepEqual(
    bundledRuntimeResourceParts(true, "darwin-arm64"),
    ["runtime", "darwin-arm64"]
  );
});

test("macOS and Linux runtimes are installed locally before use", () => {
  assert.equal(shouldInstallRuntimeLocally("darwin"), true);
  assert.equal(shouldInstallRuntimeLocally("linux"), true);
});

test("Windows runtime can run directly from Electron resources", () => {
  assert.equal(shouldInstallRuntimeLocally("win32"), false);
});

test("Windows executable names prefer .exe", () => {
  assert.deepEqual(executableNames("Rscript", "win32"), ["Rscript.exe", "Rscript"]);
  assert.deepEqual(executableNames("lastz.exe", "win32"), ["lastz.exe"]);
  assert.deepEqual(executableNames("Rscript", "darwin"), ["Rscript"]);
});

test("Windows runtime searches both standard R bin layouts", () => {
  const candidates = runtimeExecutableCandidates("C:\\CGV Runtime", "Rscript", "win32");
  assert.ok(candidates.includes(path.join("C:\\CGV Runtime", "bin", "Rscript.exe")));
  assert.ok(candidates.includes(path.join("C:\\CGV Runtime", "bin", "x64", "Rscript.exe")));
});

test("Windows executable validation only requires a regular file", () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-exec-test-"));
  const candidate = path.join(root, "tool.exe");
  fs.writeFileSync(candidate, "test");
  try {
    assert.equal(isUsableExecutable(fs, candidate, "win32"), true);
    assert.equal(isUsableExecutable(fs, root, "win32"), false);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
