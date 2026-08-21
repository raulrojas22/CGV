const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..", "..");
const outRoot = path.resolve(__dirname, "..", "resources", "demo-data");
const speciesQuery = (process.argv[2] || "").toLowerCase();
if (!speciesQuery) {
  console.error("Usage: node build-demo-data.js <species_query>");
  console.error("  species_query: a substring matching a species in annotations/registry.tsv (e.g. 'homo_sapiens')");
  process.exit(1);
}

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

function writeTsv(filePath, headers, rows) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const body = rows.map((row) => headers.map((header) => row[header] || "").join("\t"));
  fs.writeFileSync(filePath, `${headers.join("\t")}\n${body.join("\n")}\n`);
}

function copyIfExists(relPath) {
  if (!relPath) return false;
  const source = path.join(repoRoot, relPath);
  const target = path.join(outRoot, relPath);
  if (!fs.existsSync(source)) return false;
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(source, target);
  return true;
}

function copyByPrefix(dir, prefix, shouldCopy = () => true) {
  const sourceDir = path.join(repoRoot, dir);
  if (!fs.existsSync(sourceDir)) return 0;
  let copied = 0;
  for (const name of fs.readdirSync(sourceDir)) {
    if (name.toLowerCase().startsWith(prefix.toLowerCase()) && shouldCopy(name)) {
      if (copyIfExists(path.join(dir, name))) copied += 1;
    }
  }
  return copied;
}

function removeGeneratedData() {
  for (const dirName of ["annotations", "genomes", "go_annotations", "data", "www"]) {
    fs.rmSync(path.join(outRoot, dirName), { recursive: true, force: true });
  }
}

removeGeneratedData();

const annRegistry = readTsv(path.join(repoRoot, "annotations", "registry.tsv"));
const annRows = annRegistry.rows.filter((row) => {
  const haystack = `${row.species_id} ${row.label} ${row.organism} ${row.taxid}`.toLowerCase();
  return haystack.includes(speciesQuery);
});

if (annRows.length === 0) {
  throw new Error(`No annotations registry row matched '${speciesQuery}'.`);
}

const row = annRows[0];
const speciesId = row.species_id;
writeTsv(path.join(outRoot, "annotations", "registry.tsv"), annRegistry.headers, [row]);

for (const key of ["annotation", "annotation_tabix", "annotation_index", "genome", "genome_2bit"]) {
  copyIfExists(row[key]);
}

if (row.icon) {
  copyIfExists(path.join("www", row.icon.replace(/^\/+/, "")));
}

const genomeRegistryPath = path.join(repoRoot, "genomes", "registry.tsv");
if (fs.existsSync(genomeRegistryPath)) {
  const genomeRegistry = readTsv(genomeRegistryPath);
  const genomeRows = genomeRegistry.rows.filter((genomeRow) => genomeRow.species_id === speciesId);
  writeTsv(path.join(outRoot, "genomes", "registry.tsv"), genomeRegistry.headers, genomeRows.slice(0, 1));
}

for (const name of fs.readdirSync(path.join(repoRoot, "genomes", "stats"))) {
  const compactSpecies = speciesId.replace(/_gcf_.*$/i, "");
  if (name.toLowerCase().includes(compactSpecies.toLowerCase()) || name.toLowerCase().includes("tair10")) {
    copyIfExists(path.join("genomes", "stats", name));
  }
}

const goRegistryPath = path.join(repoRoot, "go_annotations", "registry.tsv");
if (fs.existsSync(goRegistryPath)) {
  const goRegistry = readTsv(goRegistryPath);
  const goRows = goRegistry.rows.filter((goRow) => {
    return goRow.species_id === speciesId ||
      goRow.taxid === row.taxid ||
      `${goRow.organism}`.toLowerCase() === `${row.organism}`.toLowerCase();
  });
  writeTsv(path.join(outRoot, "go_annotations", "registry.tsv"), goRegistry.headers, goRows.slice(0, 1));
  for (const goRow of goRows.slice(0, 1)) {
    copyIfExists(goRow.gaf_file);
    if (goRow.index_file) copyIfExists(goRow.index_file);
  }
}
copyIfExists(path.join("go_annotations", "go-basic.obo"));
copyIfExists(path.join("go_annotations", "go_term_map.rds"));

copyByPrefix(path.join("data", "alias_index"), speciesId, (name) => {
  // Demo data intentionally stays light. Full downloadable organism packages
  // carry the SQLite alias index used for production local alias resolution.
  return /\.alias_index\.tsv\.gz$/i.test(name) || /\.metadata\.json$/i.test(name);
});

const manifest = {
  version: 1,
  generatedAt: new Date().toISOString(),
  speciesId,
  label: row.label,
  description: "Bundled offline demo data for first-run CGeV Desktop validation."
};
fs.writeFileSync(path.join(outRoot, "data-manifest.json"), `${JSON.stringify(manifest, null, 2)}\n`);

console.log(`Demo data written to ${outRoot}`);
console.log(`Species: ${row.label} (${speciesId})`);
