#!/usr/bin/env node

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const yaml = require("js-yaml");
const { appBuilderPath } = require("app-builder-bin");
const packageJson = require("../package.json");

function sha512Base64(filePath) {
  return crypto.createHash("sha512").update(fs.readFileSync(filePath)).digest("base64");
}

function buildBlockmap(installerPath, blockmapPath) {
  execFileSync(appBuilderPath, ["blockmap", "--input", installerPath, "--output", blockmapPath], {
    stdio: "inherit"
  });
}

function refreshSignedWindowsUpdate(options) {
  const installerPath = path.resolve(options.installerPath);
  const updateInfoPath = path.resolve(options.updateInfoPath);
  const createBlockmap = options.createBlockmap || buildBlockmap;
  const version = packageJson.version;
  const expectedName = `CGV-Desktop-${version}-Windows-x64-Setup.exe`;

  if (!fs.existsSync(installerPath)) throw new Error(`Signed Windows installer not found: ${installerPath}`);
  if (!fs.existsSync(updateInfoPath)) throw new Error(`Windows update manifest not found: ${updateInfoPath}`);
  if (path.basename(installerPath) !== expectedName) {
    throw new Error(`Signed Windows installer must be named ${expectedName}.`);
  }

  const updateInfo = yaml.load(fs.readFileSync(updateInfoPath, "utf8"));
  if (!updateInfo || updateInfo.version !== version) {
    throw new Error(`latest.yml version must match desktop/package.json (${version}).`);
  }
  if (!Array.isArray(updateInfo.files)) throw new Error("latest.yml does not contain a files list.");

  const fileEntry = updateInfo.files.find((entry) => entry && entry.url === expectedName);
  if (!fileEntry) throw new Error(`latest.yml does not reference ${expectedName}.`);
  if (updateInfo.path !== expectedName) throw new Error(`latest.yml path must be ${expectedName}.`);

  const blockmapPath = `${installerPath}.blockmap`;
  createBlockmap(installerPath, blockmapPath);
  if (!fs.existsSync(blockmapPath)) throw new Error(`Signed installer blockmap was not created: ${blockmapPath}`);

  const installerStat = fs.statSync(installerPath);
  const blockmapStat = fs.statSync(blockmapPath);
  const sha512 = sha512Base64(installerPath);

  fileEntry.sha512 = sha512;
  fileEntry.size = installerStat.size;
  fileEntry.blockMapSize = blockmapStat.size;
  updateInfo.sha512 = sha512;

  fs.writeFileSync(updateInfoPath, yaml.dump(updateInfo, { lineWidth: -1, noRefs: true }), "utf8");
  return {
    installerPath,
    blockmapPath,
    updateInfoPath,
    sha512,
    installerSize: installerStat.size,
    blockmapSize: blockmapStat.size
  };
}

if (require.main === module) {
  const installerPath = process.argv[2];
  const updateInfoPath = process.argv[3] || path.join(path.dirname(installerPath || ""), "latest.yml");
  if (!installerPath) {
    console.error("Usage: node scripts/refresh-signed-windows-update.js <signed-installer.exe> [latest.yml]");
    process.exit(2);
  }
  const result = refreshSignedWindowsUpdate({ installerPath, updateInfoPath });
  console.log(
    `signed-windows-update-ok installer_bytes=${result.installerSize} blockmap_bytes=${result.blockmapSize}`
  );
}

module.exports = { refreshSignedWindowsUpdate, sha512Base64 };
