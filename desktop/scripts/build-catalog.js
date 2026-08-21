#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const repoRoot = path.resolve(__dirname, "..", "..");
const desktopRoot = path.resolve(__dirname, "..");
const packagesDir = path.join(desktopRoot, "dataset-packages");
const outputFile = path.join(desktopRoot, "catalog.json");
const packageCatalogFile = path.join(packagesDir, "catalog.json");
const preferredVersion = process.env.CGV_DATASET_CATALOG_VERSION || process.argv.find((arg) => arg.startsWith("--version="))?.slice("--version=".length) || "";

function readTsv(filePath) {
  const text = fs.readFileSync(filePath, "utf8").trim();
  const lines = text.split(/\r?\n/);
  const headers = lines.shift().split("\t");
  return {
    headers,
    rows: lines.filter(Boolean).map((line) => {
      const values = line.split("\t");
      return Object.fromEntries(headers.map((header, index) => [header, values[index] || ""]));
    })
  };
}

function sha256File(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256");
    const stream = fs.createReadStream(filePath);
    stream.on("data", (chunk) => hash.update(chunk));
    stream.on("end", () => resolve(hash.digest("hex")));
    stream.on("error", reject);
  });
}

async function buildCatalog() {
  console.log("Building catalog from annotations/registry.tsv...\n");
  if (preferredVersion) {
    console.log(`Preferred package version: ${preferredVersion}\n`);
  }

  const registryPath = path.join(repoRoot, "annotations", "registry.tsv");
  if (!fs.existsSync(registryPath)) {
    console.error(`ERROR: Registry not found at ${registryPath}`);
    process.exit(1);
  }

  const registry = readTsv(registryPath);
  console.log(`Found ${registry.rows.length} organisms in registry\n`);

  const datasets = [];
  let missingCount = 0;

  for (const row of registry.rows) {
    const speciesId = row.species_id;
    const packageId = speciesId.replace(/[^A-Za-z0-9._-]+/g, "_").toLowerCase();
    const zipPattern = new RegExp(`^${packageId}-.*\\.zip$`, "i");

    const zipFiles = fs.readdirSync(packagesDir).filter(f => zipPattern.test(f));

    if (zipFiles.length === 0) {
      console.log(`⚠ ${row.label}: No package found (expected ${packageId}-*.zip)`);
      missingCount++;
      continue;
    }

    const preferredZip = preferredVersion ? `${packageId}-${preferredVersion}.zip` : "";
    const zipFile = preferredZip && zipFiles.includes(preferredZip)
      ? preferredZip
      : zipFiles.slice().sort().reverse()[0];
    const versionMatch = zipFile.match(new RegExp(`^${packageId}-(.+)\\.zip$`, "i"));
    const datasetVersion = versionMatch ? versionMatch[1] : preferredVersion || "latest";
    const zipPath = path.join(packagesDir, zipFile);
    const stat = fs.statSync(zipPath);
    const sha256 = await sha256File(zipPath);

    const dataset = {
      id: packageId,
      label: row.label,
      speciesId: speciesId,
      version: datasetVersion,
      description: `${row.label} — download and install for CGeV Desktop.`,
      downloadable: true,
      sizeBytes: stat.size,
      package: {
        fileName: zipFile,
        url: zipFile,
        sha256: sha256,
        sizeBytes: stat.size
      }
    };

    datasets.push(dataset);
    console.log(`✓ ${row.label}: ${zipFile} (${(stat.size / 1024 / 1024).toFixed(1)} MB)`);
  }

  const catalog = {
    version: 1,
    source: "oracle-object-storage",
    datasets: datasets
  };

  const catalogJson = `${JSON.stringify(catalog, null, 2)}\n`;
  fs.writeFileSync(outputFile, catalogJson);
  fs.writeFileSync(packageCatalogFile, catalogJson);

  console.log(`\n${"=".repeat(60)}`);
  console.log(`Catalog generated: ${outputFile}`);
  console.log(`Release copy: ${packageCatalogFile}`);
  console.log(`Total datasets: ${datasets.length}`);
  console.log(`Missing packages: ${missingCount}`);
  console.log(`${"=".repeat(60)}\n`);

  if (missingCount > 0) {
    console.log("Next steps:");
    console.log("1. Generate missing packages with:");
    for (const row of registry.rows) {
      const packageId = row.species_id.replace(/[^A-Za-z0-9._-]+/g, "_").toLowerCase();
      const zipPattern = new RegExp(`^${packageId}-.*\\.zip$`, "i");
      const zipFiles = fs.readdirSync(packagesDir).filter(f => zipPattern.test(f));
      if (zipFiles.length === 0) {
        console.log(`   npm run dataset:package -- --species=${row.species_id.split("_")[0]}`);
      }
    }
    console.log("\n2. Upload all .zip files to Zenodo");
    console.log("3. Update catalog.json with actual Zenodo URLs");
    console.log("4. Update data-manifest.json with catalogUrl");
  } else {
    console.log("All packages found! Next steps:");
    console.log("1. Upload all .zip files to Zenodo");
    console.log("2. Update catalog.json with actual Zenodo URLs");
    console.log("3. Update data-manifest.json with catalogUrl");
  }
}

buildCatalog().catch(err => {
  console.error("ERROR:", err.message);
  process.exit(1);
});
