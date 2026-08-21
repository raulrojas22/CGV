const assert = require("node:assert/strict");
const path = require("node:path");
const test = require("node:test");
const { LEGACY_USER_DATA_DIRECTORY, legacyUserDataPath } = require("../src/legacy-user-data");

test("keeps the historical Windows user-data directory after the visible rename", () => {
  assert.equal(
    legacyUserDataPath({ platform: "win32", localAppData: "C:\\Users\\tester\\AppData\\Local", appData: "ignored" }),
    path.join("C:\\Users\\tester\\AppData\\Local", "CGV Desktop")
  );
});

test("keeps the historical macOS and Linux user-data directory", () => {
  assert.equal(LEGACY_USER_DATA_DIRECTORY, "CGV Desktop");
  assert.equal(
    legacyUserDataPath({ platform: "darwin", appData: "/Users/tester/Library/Application Support" }),
    "/Users/tester/Library/Application Support/CGV Desktop"
  );
  assert.equal(
    legacyUserDataPath({ platform: "linux", appData: "/home/tester/.config" }),
    "/home/tester/.config/CGV Desktop"
  );
});

test("fails closed when Electron cannot provide an application-data root", () => {
  assert.throws(
    () => legacyUserDataPath({ platform: "linux", appData: "" }),
    /Cannot resolve/
  );
});
