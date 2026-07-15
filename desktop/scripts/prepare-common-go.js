#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const { downloadFile, sha256File } = require("../src/download-file");
const { runtimeExecutableCandidates } = require("../src/runtime-platform");

const desktopRoot = path.resolve(__dirname, "..");
const repoRoot = path.resolve(desktopRoot, "..");
const outputRoot = path.join(desktopRoot, "resources", "common-go");
const oboPath = path.join(outputRoot, "go-basic.obo");
const mapPath = path.join(outputRoot, "go_term_map.rds");
const manifestPath = path.join(outputRoot, "manifest.json");
const lock = JSON.parse(fs.readFileSync(path.join(desktopRoot, "go-assets-lock.json"), "utf8"));

function runtimeKey() {
  return `${process.platform}-${process.arch}`;
}

function rscriptCandidates() {
  const configured = String(process.env.CGV_RSCRIPT || "").trim();
  const runtimeRoot = path.join(desktopRoot, "resources", "r", runtimeKey());
  return [
    ...(configured ? [configured] : []),
    ...runtimeExecutableCandidates(runtimeRoot, "Rscript", process.platform),
    process.platform === "win32" ? "Rscript.exe" : "Rscript"
  ];
}

function generateLookup() {
  const scriptPath = path.join(repoRoot, "scripts", "build_go_term_map.R");
  const args = [scriptPath, `--obo=${oboPath}`, `--out=${mapPath}`];
  const failures = [];
  for (const candidate of rscriptCandidates()) {
    const result = spawnSync(candidate, args, { cwd: repoRoot, stdio: "inherit" });
    if (!result.error && result.status === 0) return candidate;
    failures.push(`${candidate}: ${result.error?.message || `exit ${result.status}`}`);
  }
  throw new Error(`Unable to build go_term_map.rds with Rscript. Tried:\n${failures.join("\n")}`);
}

async function main() {
  if (
    lock.version !== 1 ||
    !/^https:\/\//.test(lock.obo?.url || "") ||
    !/^[a-f0-9]{64}$/.test(lock.obo?.sha256 || "")
  ) {
    throw new Error("Invalid desktop/go-assets-lock.json");
  }

  fs.mkdirSync(outputRoot, { recursive: true });
  const currentHash = fs.existsSync(oboPath) ? await sha256File(oboPath) : "";
  if (currentHash !== lock.obo.sha256) {
    console.log(`Downloading locked GO ontology ${lock.obo.dataVersion}...`);
    await downloadFile(lock.obo.url, oboPath, lock.obo.sha256);
  } else {
    console.log(`Using verified GO ontology ${lock.obo.dataVersion}.`);
  }

  let existingManifest = {};
  try {
    existingManifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  } catch (_) {}

  const existingMapHash = fs.existsSync(mapPath) ? await sha256File(mapPath) : "";
  if (
    !existingMapHash ||
    existingManifest.oboSha256 !== lock.obo.sha256 ||
    existingManifest.mapSha256 !== existingMapHash
  ) {
    const rscript = generateLookup();
    if (!fs.existsSync(mapPath) || fs.statSync(mapPath).size === 0) {
      throw new Error("GO lookup generation did not produce go_term_map.rds.");
    }
    existingManifest = {
      schemaVersion: 1,
      dataVersion: lock.obo.dataVersion,
      sourceUrl: lock.obo.url,
      oboSha256: lock.obo.sha256,
      mapSha256: await sha256File(mapPath),
      generatedWith: path.basename(rscript)
    };
    fs.writeFileSync(manifestPath, `${JSON.stringify(existingManifest, null, 2)}\n`, "utf8");
  }

  if (
    existingManifest.oboSha256 !== lock.obo.sha256 ||
    existingManifest.mapSha256 !== await sha256File(mapPath)
  ) {
    throw new Error("Common GO manifest does not match the locked ontology.");
  }
  console.log(`common-go-ok data_version=${lock.obo.dataVersion} map_sha256=${existingManifest.mapSha256}`);
}

main().catch((error) => {
  console.error(error.stack || error.message || String(error));
  process.exit(1);
});
