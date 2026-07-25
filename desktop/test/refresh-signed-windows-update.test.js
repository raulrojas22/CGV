const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const yaml = require("js-yaml");
const packageJson = require("../package.json");
const { refreshSignedWindowsUpdate, sha512Base64 } = require("../scripts/refresh-signed-windows-update");

async function withTempDirectory(callback) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-signed-update-"));
  try {
    return await callback(directory);
  } finally {
    fs.rmSync(directory, { recursive: true, force: true });
  }
}

test("regenerates Windows updater metadata from the signed installer bytes", async () => {
  await withTempDirectory(async (directory) => {
    const installerName = `CGV-Desktop-${packageJson.version}-Windows-x64-Setup.exe`;
    const installerPath = path.join(directory, installerName);
    const updateInfoPath = path.join(directory, "latest.yml");
    fs.writeFileSync(installerPath, Buffer.from("signed-installer-content"));
    fs.writeFileSync(updateInfoPath, yaml.dump({
      version: packageJson.version,
      files: [{ url: installerName, sha512: "unsigned", size: 1, blockMapSize: 1 }],
      path: installerName,
      sha512: "unsigned",
      releaseDate: "2026-07-15T00:00:00.000Z"
    }));

    const result = await refreshSignedWindowsUpdate({
      installerPath,
      updateInfoPath,
      createBlockmap: (_input, output) => fs.writeFileSync(output, Buffer.from("signed-blockmap"))
    });
    const refreshed = yaml.load(fs.readFileSync(updateInfoPath, "utf8"));

    assert.equal(refreshed.sha512, sha512Base64(installerPath));
    assert.equal(refreshed.files[0].sha512, refreshed.sha512);
    assert.equal(refreshed.files[0].size, fs.statSync(installerPath).size);
    assert.equal(refreshed.files[0].blockMapSize, fs.statSync(result.blockmapPath).size);
  });
});

test("rejects updater metadata for a different version", async () => {
  await withTempDirectory(async (directory) => {
    const installerName = `CGV-Desktop-${packageJson.version}-Windows-x64-Setup.exe`;
    const installerPath = path.join(directory, installerName);
    const updateInfoPath = path.join(directory, "latest.yml");
    fs.writeFileSync(installerPath, "signed");
    fs.writeFileSync(updateInfoPath, yaml.dump({
      version: "99.0.0",
      files: [{ url: installerName }],
      path: installerName
    }));

    await assert.rejects(
      refreshSignedWindowsUpdate({ installerPath, updateInfoPath, createBlockmap: () => {} }),
      /version must match/
    );
  });
});
