const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..", "..");

function argValue(name, fallback = "") {
  const prefix = `--${name}=`;
  const hit = process.argv.find((arg) => arg.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : fallback;
}

function readTsv(filePath) {
  const text = fs.readFileSync(filePath, "utf8").trim();
  const lines = text.split(/\r?\n/);
  const headers = lines.shift().split("\t");
  return lines.filter(Boolean).map((line) => {
    const values = line.split("\t");
    return Object.fromEntries(headers.map((header, index) => [header, values[index] || ""]));
  });
}

function assertFile(root, relPath) {
  if (!relPath) return;
  const fullPath = path.join(root, relPath);
  if (!fs.existsSync(fullPath) || !fs.statSync(fullPath).isFile()) {
    throw new Error(`Missing file referenced by installed dataset: ${relPath}`);
  }
}

const dataRoot = path.resolve(argValue("data-root", process.env.CGV_DATA_ROOT || repoRoot));
const speciesQuery = (argValue("species", process.argv[2] || "") || "").toLowerCase();
const registryPath = path.join(dataRoot, "annotations", "registry.tsv");

if (!fs.existsSync(registryPath)) throw new Error(`Missing annotations registry: ${registryPath}`);

const rows = readTsv(registryPath).filter((row) => {
  if (!speciesQuery) return true;
  return `${row.species_id} ${row.organism} ${row.label} ${row.taxid}`.toLowerCase().includes(speciesQuery);
});
if (rows.length === 0) throw new Error(`No installed annotation row matched '${speciesQuery}' in ${registryPath}`);

for (const row of rows) {
  for (const key of ["annotation_tabix", "annotation_index", "genome_2bit"]) {
    assertFile(dataRoot, row[key]);
  }
}

const installRegistry = path.join(dataRoot, "desktop-datasets.json");
const installState = fs.existsSync(installRegistry)
  ? JSON.parse(fs.readFileSync(installRegistry, "utf8"))
  : { datasets: {} };

console.log(JSON.stringify({
  ok: true,
  dataRoot,
  matchedRows: rows.length,
  installedDatasetIds: Object.keys(installState.datasets || {})
}, null, 2));
