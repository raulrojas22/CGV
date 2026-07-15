const fs = require("fs");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..", "..");
const desktopRoot = path.resolve(__dirname, "..");
const bundledDir = path.join(desktopRoot, "resources", "bundled-data");

const TARGET_SPECIES = [
  "homo_sapiens_gcf_000001405_40_grch38_p14_genomic",
  "drosophila_melanogaster_gcf_000001215_4_release_6_plus_iso1_mt_genomic",
  "caenorhabditis_elegans_gcf_000002985_6_wbcel235_genomic",
  "arabidopsis_thaliana_gcf_000001735_4_tair10_1_genomic",
  "oryza_sativa_ssp_japonica_gcf_034140825_1_asm3414082v1_genomic",
  "saccharomyces_cerevisiae_gcf_000146045_2_r64_genomic",
  "candida_albicans_gcf_000182965_3_asm18296v3_genomic",
];

function readTsv(filePath) {
  if (!fs.existsSync(filePath)) return { headers: [], rows: [] };
  const text = fs.readFileSync(filePath, "utf8").trim();
  const lines = text.split(/\r?\n/);
  const headers = lines.shift().split("\t");
  return {
    headers,
    rows: lines.filter(Boolean).map((line) => {
      const values = line.split("\t");
      return Object.fromEntries(headers.map((h, i) => [h, values[i] || ""]));
    }),
  };
}

function writeTsv(filePath, headers, rows) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const body = rows.map((row) => headers.map((h) => row[h] || "").join("\t"));
  fs.writeFileSync(filePath, `${headers.join("\t")}\n${body.join("\n")}\n`);
}

function copyFile(relPath) {
  if (!relPath) return false;
  const src = path.join(repoRoot, relPath);
  const dst = path.join(bundledDir, relPath);
  if (!fs.existsSync(src)) {
    console.warn(`  WARN: missing ${relPath}`);
    return false;
  }
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  fs.copyFileSync(src, dst);
  return true;
}

function copyMatching(relDir, prefix, filterFn) {
  const srcDir = path.join(repoRoot, relDir);
  if (!fs.existsSync(srcDir)) return 0;
  let count = 0;
  for (const name of fs.readdirSync(srcDir)) {
    if (name.toLowerCase().startsWith(prefix.toLowerCase())) {
      if (filterFn && !filterFn(name)) continue;
      if (copyFile(path.join(relDir, name))) count++;
    }
  }
  return count;
}

// Clean and recreate
fs.rmSync(bundledDir, { recursive: true, force: true });
fs.mkdirSync(bundledDir, { recursive: true });

console.log("Reading registries...");

const annReg = readTsv(path.join(repoRoot, "annotations", "registry.tsv"));
const genReg = readTsv(path.join(repoRoot, "genomes", "registry.tsv"));
const goReg = readTsv(path.join(repoRoot, "go_annotations", "registry.tsv"));

// Filter annotation rows for target species
const annRows = annReg.rows.filter((r) => TARGET_SPECIES.includes(r.species_id));
if (annRows.length !== TARGET_SPECIES.length) {
  const found = annRows.map((r) => r.species_id);
  const missing = TARGET_SPECIES.filter((s) => !found.includes(s));
  throw new Error(`Missing species in registry: ${missing.join(", ")}`);
}

console.log(`Found ${annRows.length} target species in registry`);
console.log("");

// Copy annotation files
console.log("--- Annotations ---");
for (const row of annRows) {
  console.log(`  ${row.organism}`);
  for (const key of ["annotation", "annotation_tabix", "annotation_index"]) {
    if (row[key]) copyFile(row[key]);
  }
  // Copy icon
  if (row.icon) copyFile(path.join("www", row.icon.replace(/^\/+/, "")));

  // Copy genome 2bit
  if (row.genome_2bit) copyFile(row.genome_2bit);

  // Copy GO files
  const goRows = goReg.rows.filter(
    (gr) =>
      gr.species_id === row.species_id ||
      gr.taxid === row.taxid ||
      `${gr.organism}`.toLowerCase() === `${row.organism}`.toLowerCase()
  );
  for (const gr of goRows.slice(0, 1)) {
    if (gr.gaf_file) copyFile(gr.gaf_file);
    if (gr.index_file) copyFile(gr.index_file);
  }

  // Copy alias index files for this species
  copyMatching(path.join("data", "alias_index"), row.species_id);

  // Copy genome stats
  const statsDir = path.join(repoRoot, "genomes", "stats");
  if (fs.existsSync(statsDir)) {
    const g2b = path.basename(row.genome_2bit || "")
      .replace(/_genomic\.2bit$/i, "")
      .replace(/\.2bit$/i, "");
    for (const name of fs.readdirSync(statsDir)) {
      if (name.toLowerCase().includes(g2b.toLowerCase())) {
        copyFile(path.join("genomes", "stats", name));
      }
    }
  }
}

// Write filtered annotations registry
writeTsv(path.join(bundledDir, "annotations", "registry.tsv"), annReg.headers, annRows);
console.log(`  -> annotations/registry.tsv (${annRows.length} rows)`);

// Write filtered genomes registry
const genRows = genReg.rows.filter((gr) => {
  const haystack = `${gr.organism} ${gr.fasta} ${gr.aliases}`.toLowerCase();
  return annRows.some((ar) => {
    const g2bName = path
      .basename(ar.genome_2bit || "")
      .replace(/\.2bit$/i, "")
      .toLowerCase();
    return (
      haystack.includes(g2bName) ||
      haystack.includes(ar.organism.toLowerCase())
    );
  });
});
writeTsv(path.join(bundledDir, "genomes", "registry.tsv"), genReg.headers, genRows.slice(0, annRows.length));
console.log(`  -> genomes/registry.tsv (${genRows.length} rows)`);

// Write filtered GO registry
const goFilteredRows = goReg.rows.filter((gr) => {
  return annRows.some(
    (ar) =>
      gr.species_id === ar.species_id ||
      gr.taxid === ar.taxid ||
      `${gr.organism}`.toLowerCase() === `${ar.organism}`.toLowerCase()
  );
});
writeTsv(path.join(bundledDir, "go_annotations", "registry.tsv"), goReg.headers, goFilteredRows);
console.log(`  -> go_annotations/registry.tsv (${goFilteredRows.length} rows)`);

// Copy go-basic.obo and go_term_map.rds
copyFile(path.join("go_annotations", "go-basic.obo"));
copyFile(path.join("go_annotations", "go_term_map.rds"));

// Create dataset.json
const meta = {
  id: "bundled-organisms",
  version: "2026.05",
  description: "CGV Desktop bundled organisms (7 species).",
  species: annRows.map((r) => ({
    speciesId: r.species_id,
    label: r.label,
    organism: r.organism,
    kingdom: r.kingdom,
  })),
};
fs.writeFileSync(
  path.join(bundledDir, "dataset.json"),
  `${JSON.stringify(meta, null, 2)}\n`
);

// Report sizes
function du(dir) {
  let total = 0;
  if (!fs.existsSync(dir)) return 0;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      total += du(p);
    } else {
      total += fs.statSync(p).size;
    }
  }
  return total;
}

const totalBytes = du(bundledDir);
console.log("");
console.log(`=== BUNDLED DATA SIZE: ${(totalBytes / 1073741824).toFixed(2)} GB ===`);
console.log(`Output: ${bundledDir}`);
