const fs = require("fs");
const os = require("os");
const path = require("path");
const crypto = require("crypto");
const { spawnSync } = require("child_process");

function argValue(name, fallback = "") {
  const prefix = `--${name}=`;
  const hit = process.argv.find((arg) => arg.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : fallback;
}

function run(command, args, cwd) {
  const result = spawnSync(command, args, { cwd, encoding: "utf8" });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed\n${result.stdout || ""}${result.stderr || ""}`);
  }
  return result.stdout || "";
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

function readTsv(filePath) {
  const text = fs.readFileSync(filePath, "utf8").trim();
  const lines = text.split(/\r?\n/);
  const headers = lines.shift().split("\t");
  return lines.filter(Boolean).map((line) => {
    const values = line.split("\t");
    return Object.fromEntries(headers.map((header, index) => [header, values[index] || ""]));
  });
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function assertSafeEntries(zipPath) {
  const entries = run("unzip", ["-Z1", zipPath]).split(/\r?\n/).filter(Boolean);
  for (const entry of entries) {
    if (path.isAbsolute(entry) || entry.includes("..") || entry.includes("\\")) {
      throw new Error(`Unsafe zip entry: ${entry}`);
    }
  }
  return entries;
}

function assertFile(root, relPath) {
  if (!relPath) return;
  const fullPath = path.join(root, relPath);
  if (!fs.existsSync(fullPath) || !fs.statSync(fullPath).isFile()) {
    throw new Error(`Missing required file: ${relPath}`);
  }
}

function assertNonEmptyFile(root, relPath) {
  assertFile(root, relPath);
  const fullPath = path.join(root, relPath);
  if (fs.statSync(fullPath).size <= 0) {
    throw new Error(`Required file is empty: ${relPath}`);
  }
}

function sqliteScalar(sqlitePath, sql) {
  return run("sqlite3", [sqlitePath, sql]).trim();
}

function assertCompactAliasSqlite(root, relPath) {
  assertNonEmptyFile(root, relPath);
  const fullPath = path.join(root, relPath);
  const columns = sqliteScalar(fullPath, "PRAGMA table_info(alias_index);")
    .split(/\r?\n/)
    .filter(Boolean)
    .map((line) => line.split("|")[1]);
  const requiredColumns = [
    "organism_id",
    "query_term_original",
    "query_term_upper",
    "query_term_clean_basic",
    "query_term_clean_strict",
    "term_type",
    "local_gene_id",
    "local_feature_id",
    "local_symbol",
    "confidence",
    "source_db"
  ];
  for (const column of requiredColumns) {
    if (!columns.includes(column)) {
      throw new Error(`Alias SQLite missing compact column ${column}: ${relPath}`);
    }
  }
  const rowCount = Number(sqliteScalar(fullPath, "SELECT COUNT(*) FROM alias_index;"));
  if (!Number.isFinite(rowCount) || rowCount <= 0) {
    throw new Error(`Alias SQLite must contain at least one external row: ${relPath}`);
  }
  const format = sqliteScalar(
    fullPath,
    "SELECT value FROM alias_index_meta WHERE key = 'format' LIMIT 1;"
  );
  if (format !== "external_compact") {
    throw new Error(`Alias SQLite is not external_compact: ${relPath}`);
  }
}

function assertGoSqlite(root, relPath, expectedFingerprint = "") {
  assertNonEmptyFile(root, relPath);
  const fullPath = path.join(root, relPath);
  const integrity = sqliteScalar(fullPath, "PRAGMA integrity_check;");
  if (integrity !== "ok") {
    throw new Error(`GO SQLite integrity check failed: ${relPath}`);
  }
  const schema = sqliteScalar(
    fullPath,
    "SELECT value FROM go_index_meta WHERE key = 'schema_version' LIMIT 1;"
  );
  if (schema !== "1") {
    throw new Error(`Unsupported GO SQLite schema ${schema}: ${relPath}`);
  }
  const fingerprint = sqliteScalar(
    fullPath,
    "SELECT value FROM go_index_meta WHERE key = 'gaf_fingerprint' LIMIT 1;"
  );
  if (expectedFingerprint && fingerprint !== expectedFingerprint) {
    throw new Error(`GO SQLite fingerprint mismatch: ${relPath}`);
  }
  const rows = Number(sqliteScalar(fullPath, "SELECT COUNT(*) FROM gaf;"));
  if (!Number.isFinite(rows) || rows <= 0) {
    throw new Error(`GO SQLite contains no annotations: ${relPath}`);
  }
}

const packagePath = path.resolve(argValue("package", process.argv[2] || ""));
if (!packagePath || !fs.existsSync(packagePath)) {
  throw new Error("Pass a dataset package with --package=/path/to/file.zip");
}

const manifestPath = argValue("manifest", "");

(async () => {
if (manifestPath) {
  const manifest = JSON.parse(fs.readFileSync(path.resolve(manifestPath), "utf8"));
  const expected = (manifest.package && manifest.package.sha256) || manifest.sha256 || "";
  if (expected) {
    const actual = await sha256File(packagePath);
    if (actual.toLowerCase() !== expected.toLowerCase()) {
      throw new Error(`Checksum mismatch. Expected ${expected}, got ${actual}`);
    }
  }
}

assertSafeEntries(packagePath);

const extractRoot = path.resolve(argValue("extract-to", fs.mkdtempSync(path.join(os.tmpdir(), "cgv-dataset-verify-"))));
fs.rmSync(extractRoot, { recursive: true, force: true });
fs.mkdirSync(extractRoot, { recursive: true });
run("unzip", ["-q", packagePath, "-d", extractRoot]);

assertFile(extractRoot, "dataset.json");
assertFile(extractRoot, "annotations/registry.tsv");
assertFile(extractRoot, "genomes/registry.tsv");

for (const row of readTsv(path.join(extractRoot, "annotations", "registry.tsv"))) {
  for (const key of ["annotation_tabix", "annotation_index", "genome_2bit"]) {
    assertFile(extractRoot, row[key]);
  }
  if (row.icon) assertFile(extractRoot, path.join("www", row.icon.replace(/^\/+/, "")));
  const speciesId = String(row.species_id || "").trim();
  if (speciesId) {
    const aliasMetadataRel = path.join("data", "alias_index", `${speciesId}.metadata.json`);
    const aliasSqliteRel = path.join("data", "alias_index", `${speciesId}.alias_index.sqlite`);
    const aliasMetadataPath = path.join(extractRoot, aliasMetadataRel);
    const aliasSqlitePath = path.join(extractRoot, aliasSqliteRel);
    if (fs.existsSync(aliasMetadataPath)) {
      const metadata = readJson(aliasMetadataPath);
      if (fs.existsSync(aliasSqlitePath)) {
        assertCompactAliasSqlite(extractRoot, aliasSqliteRel);
        if (metadata.alias_sqlite_format !== "external_compact") {
          throw new Error(`Alias metadata must declare external_compact format: ${aliasMetadataRel}`);
        }
      } else if (Number(metadata.alias_sqlite_external_rows || 0) !== 0 || metadata.alias_sqlite_packaged !== false) {
        throw new Error(`Alias metadata requires a packaged SQLite or explicit external_rows=0: ${aliasMetadataRel}`);
      }
    }
  }
}

const goRegistryPath = path.join(extractRoot, "go_annotations", "registry.tsv");
if (fs.existsSync(goRegistryPath)) {
  for (const row of readTsv(goRegistryPath)) {
    if (row.gaf_file) assertNonEmptyFile(extractRoot, row.gaf_file);
    if (row.index_file) {
      assertGoSqlite(extractRoot, row.index_file, row.index_fingerprint || "");
    }
  }
}

console.log(`Verified ${path.basename(packagePath)} in ${extractRoot}`);
})();
