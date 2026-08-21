const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { spawnSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "..", "..");
const desktopRoot = path.resolve(__dirname, "..");

function argValue(name, fallback = "") {
  const prefix = `--${name}=`;
  const hit = process.argv.find((arg) => arg.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : fallback;
}

const speciesQuery = (argValue("species", "") || "").toLowerCase();
if (!speciesQuery) {
  console.error("Usage: node build-dataset-package.js --species=<species_query> [--version=<version>] [--out=<dir>]");
  console.error("  --species: a substring matching a species in annotations/registry.tsv (e.g. 'homo_sapiens')");
  process.exit(1);
}
const version = argValue("version", "2026.05");
const outDir = path.resolve(argValue("out", path.join(desktopRoot, "dataset-packages")));
const workRoot = path.join(outDir, "work");

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

function sha256File(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256");
    const stream = fs.createReadStream(filePath);
    stream.on("data", (chunk) => hash.update(chunk));
    stream.on("end", () => resolve(hash.digest("hex")));
    stream.on("error", reject);
  });
}

function copyIfExists(stageRoot, relPath) {
  if (!relPath) return false;
  const source = path.join(repoRoot, relPath);
  const target = path.join(stageRoot, relPath);
  if (!fs.existsSync(source) || !fs.statSync(source).isFile()) return false;
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(source, target);
  return true;
}

function copyByPrefix(stageRoot, dir, prefix, shouldCopy = () => true) {
  const sourceDir = path.join(repoRoot, dir);
  if (!fs.existsSync(sourceDir)) return 0;
  let copied = 0;
  for (const name of fs.readdirSync(sourceDir)) {
    if (name.toLowerCase().startsWith(prefix.toLowerCase()) && shouldCopy(name)) {
      if (copyIfExists(stageRoot, path.join(dir, name))) copied += 1;
    }
  }
  return copied;
}

function readJsonIfExists(filePath, fallback = {}) {
  if (!fs.existsSync(filePath)) return fallback;
  try {
    return JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch (_) {
    return fallback;
  }
}

function writeJson(filePath, value) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function run(command, args, cwd) {
  const result = spawnSync(command, args, { cwd, encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed\n${result.stdout || ""}${result.stderr || ""}`);
  }
  return `${result.stdout || ""}${result.stderr || ""}`;
}

const annRegistry = readTsv(path.join(repoRoot, "annotations", "registry.tsv"));
const matches = annRegistry.rows.filter((row) => {
  const haystack = `${row.species_id} ${row.label} ${row.organism} ${row.taxid}`.toLowerCase();
  return haystack.includes(speciesQuery);
});
if (matches.length === 0) throw new Error(`No species matched '${speciesQuery}'.`);

const row = matches[0];
const speciesId = row.species_id;
const packageId = speciesId.replace(/[^A-Za-z0-9._-]+/g, "_").toLowerCase();
const stageRoot = path.join(workRoot, packageId);
const zipName = `${packageId}-${version}.zip`;
const zipPath = path.join(outDir, zipName);

fs.rmSync(stageRoot, { recursive: true, force: true });
fs.mkdirSync(stageRoot, { recursive: true });
fs.mkdirSync(outDir, { recursive: true });

writeTsv(path.join(stageRoot, "annotations", "registry.tsv"), annRegistry.headers, [row]);
for (const key of ["annotation", "annotation_tabix", "annotation_index", "genome", "genome_2bit"]) {
  copyIfExists(stageRoot, row[key]);
}
if (row.icon) copyIfExists(stageRoot, path.join("www", row.icon.replace(/^\/+/, "")));

const genomeRegistryPath = path.join(repoRoot, "genomes", "registry.tsv");
if (fs.existsSync(genomeRegistryPath)) {
  const genomeRegistry = readTsv(genomeRegistryPath);
  const genomeRows = genomeRegistry.rows.filter((genomeRow) => {
    const haystack = `${genomeRow.organism} ${genomeRow.fasta} ${genomeRow.aliases}`.toLowerCase();
    return haystack.includes((row.genome_2bit || "").split("/").pop().replace(/\.2bit$/i, "").toLowerCase()) ||
      haystack.includes(row.organism.toLowerCase()) ||
      haystack.includes(row.taxid);
  });
  writeTsv(path.join(stageRoot, "genomes", "registry.tsv"), genomeRegistry.headers, genomeRows.slice(0, 1));
}

const statsDir = path.join(repoRoot, "genomes", "stats");
if (fs.existsSync(statsDir)) {
  const basenameStem = path.basename(row.genome_2bit || "").replace(/_genomic\.2bit$/i, "").replace(/\.2bit$/i, "");
  for (const name of fs.readdirSync(statsDir)) {
    if (name.toLowerCase().includes(basenameStem.toLowerCase())) {
      copyIfExists(stageRoot, path.join("genomes", "stats", name));
    }
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
  writeTsv(path.join(stageRoot, "go_annotations", "registry.tsv"), goRegistry.headers, goRows.slice(0, 1));
  for (const goRow of goRows.slice(0, 1)) {
    copyIfExists(stageRoot, goRow.gaf_file);
    if (goRow.index_file) {
      const copied = copyIfExists(stageRoot, goRow.index_file);
      if (!copied) {
        console.warn(`Warning: GO index declared but missing: ${goRow.index_file}`);
      }
    }
  }
}
// Common GO ontology/map files are bundled with the desktop app once and seeded
// into the local profile at startup, so per-organism packages only carry GAFs.

const rscript = process.env.CGV_RSCRIPT || "Rscript";

copyByPrefix(stageRoot, path.join("data", "alias_index"), speciesId, (name) => {
  return /\.metadata\.json$/i.test(name);
});

function buildCompactAliasIndexForPackage() {
  const aliasDirRel = path.join("data", "alias_index");
  const sourceSqlite = path.join(repoRoot, aliasDirRel, `${speciesId}.alias_index.sqlite`);
  const targetSqlite = path.join(stageRoot, aliasDirRel, `${speciesId}.alias_index.sqlite`);
  const metadataPath = path.join(stageRoot, aliasDirRel, `${speciesId}.metadata.json`);
  const metadata = readJsonIfExists(metadataPath, {});
  metadata.alias_sqlite_format = "external_compact";
  metadata.alias_sqlite_schema_version = 2;
  metadata.alias_sqlite_packaged = false;
  metadata.alias_sqlite_external_rows = 0;

  if (!fs.existsSync(sourceSqlite)) {
    writeJson(metadataPath, metadata);
    console.warn(`Warning: Alias SQLite source not found for ${speciesId}. Package will rely on local GFF alias lookup.`);
    return metadata;
  }

  const rCode = `
    source(${JSON.stringify(path.join(repoRoot, "R", "utils.R"))})
    source(${JSON.stringify(path.join(repoRoot, "R", "alias_resolution.R"))})
    res <- build_alias_sqlite_external_compact(
      source_sqlite_path = ${JSON.stringify(sourceSqlite)},
      sqlite_path = ${JSON.stringify(targetSqlite)}
    )
    cat("ALIAS_COMPACT_ROWS=", as.integer(res$row_count), "\\n", sep = "")
  `;
  const result = spawnSync(rscript, ["-e", rCode], { cwd: repoRoot, encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(`${rscript} alias compact build failed\n${result.stdout || ""}${result.stderr || ""}`);
  }
  const output = `${result.stdout || ""}${result.stderr || ""}`;
  const match = output.match(/ALIAS_COMPACT_ROWS=(\d+)/);
  const rows = match ? Number(match[1]) : 0;
  metadata.alias_sqlite_external_rows = Number.isFinite(rows) ? rows : 0;
  metadata.alias_sqlite_packaged = metadata.alias_sqlite_external_rows > 0 && fs.existsSync(targetSqlite);
  if (!metadata.alias_sqlite_packaged && fs.existsSync(targetSqlite)) {
    fs.rmSync(targetSqlite, { force: true });
  }
  writeJson(metadataPath, metadata);
  if (metadata.alias_sqlite_packaged) {
    console.log(`Alias SQLite compact generated (${metadata.alias_sqlite_external_rows} external rows).`);
  } else {
    console.log("Alias SQLite compact skipped: no external alias rows; local GFF alias lookup is sufficient.");
  }
  return metadata;
}

buildCompactAliasIndexForPackage();

function annotationCacheFiles(stageRoot) {
  const cacheDir = path.join(stageRoot, "cache", "annotation_index");
  if (!fs.existsSync(cacheDir)) return [];
  return fs.readdirSync(cacheDir).filter((name) => name.endsWith(".rds"));
}

const annotationPath = row.annotation || row.annotation_tabix || "";
if (annotationPath) {
  const fullAnnotationPath = path.join(stageRoot, annotationPath);
  if (fs.existsSync(fullAnnotationPath)) {
    console.log("Pre-generating annotation index cache...");
    const rCode = `
      suppressPackageStartupMessages({
        library(dplyr)
        library(tidyr)
        library(purrr)
        library(stringr)
        source("${path.join(repoRoot, "R", "utils.R").replace(/\\/g, "\\\\")}")
      })
      ann_path <- "${fullAnnotationPath.replace(/\\/g, "\\\\")}"
      cache_dir <- file.path("${stageRoot.replace(/\\/g, "\\\\")}", "cache", "annotation_index")
      dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
      Sys.setenv(CGV_CACHE_DIR = "${path.join(stageRoot, "cache").replace(/\\/g, "\\\\")}")
      idx <- tryCatch({
        precompute_annotation_index_cache(ann_path, base_dir = "${stageRoot.replace(/\\/g, "\\\\")}")
      }, error = function(e) {
        message("Error: ", e$message)
        NULL
      })
      if (!is.null(idx)) {
        cat("Annotation index cache generated successfully\\n")
        quit(status = 0)
      } else {
        cat("Failed to generate annotation index cache\\n")
        quit(status = 1)
      }
    `;
    const result = spawnSync(rscript, ["-e", rCode], { encoding: "utf8", stdio: "inherit" });
    if (result.status === 0) {
      const cacheFiles = annotationCacheFiles(stageRoot);
      if (cacheFiles.length > 0) {
        console.log(`Annotation index cache generated (${cacheFiles.length} file(s)).`);
      } else {
        console.warn("Warning: Annotation cache command succeeded but no cache/annotation_index/*.rds file was packaged.");
      }
    } else {
      console.warn("Warning: Failed to generate annotation index cache. Continuing without it.");
    }
  } else {
    console.warn(`Warning: Annotation file not found at ${fullAnnotationPath}. Skipping cache generation.`);
  }
} else {
  console.warn("Warning: No annotation path found in registry. Skipping cache generation.");
}

const datasetMeta = {
  id: packageId,
  speciesId,
  label: row.label,
  organism: row.organism,
  taxid: row.taxid,
  version,
  description: `${row.label} CGeV Desktop dataset package.`,
  packageFile: zipName
};
fs.writeFileSync(path.join(stageRoot, "dataset.json"), `${JSON.stringify(datasetMeta, null, 2)}\n`);

(async () => {
fs.rmSync(zipPath, { force: true });
run("zip", ["-qry", zipPath, "."], stageRoot);

const stat = fs.statSync(zipPath);
const sha256 = await sha256File(zipPath);
const manifestEntry = {
  id: packageId,
  label: row.label,
  speciesId,
  version,
  description: datasetMeta.description,
  downloadable: true,
  sizeBytes: stat.size,
  package: {
    fileName: zipName,
    url: zipName,
    sha256,
    sizeBytes: stat.size
  }
};
fs.writeFileSync(path.join(outDir, `${packageId}.manifest.json`), `${JSON.stringify(manifestEntry, null, 2)}\n`);

console.log(JSON.stringify(manifestEntry, null, 2));
})();
