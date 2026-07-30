const fs = require("fs");
const path = require("path");

const REGISTRY_PATHS = new Set([
  "annotations/registry.tsv",
  "genomes/registry.tsv",
  "go_annotations/registry.tsv"
]);

const SHARED_DATA_PATHS = new Set([
  "go_annotations/go-basic.obo",
  "go_annotations/go_term_map.rds",
  "desktop-datasets.json",
  "data-manifest.json",
  "bundled-dataset.json"
]);

function normalizeRelativePath(value) {
  return String(value || "")
    .trim()
    .replace(/\\/g, "/")
    .replace(/^\.\/+/, "")
    .replace(/^\/+/, "");
}

function resolveInside(root, relativePath) {
  const normalized = normalizeRelativePath(relativePath);
  if (!normalized) return "";
  const resolvedRoot = path.resolve(root);
  const target = path.resolve(resolvedRoot, ...normalized.split("/"));
  if (target === resolvedRoot || !target.startsWith(`${resolvedRoot}${path.sep}`)) {
    throw new Error(`Refusing to remove path outside ${resolvedRoot}: ${relativePath}`);
  }
  return target;
}

function isInside(root, targetPath) {
  const resolvedRoot = path.resolve(root);
  const target = path.resolve(targetPath);
  return target !== resolvedRoot && target.startsWith(`${resolvedRoot}${path.sep}`);
}

function readTsvRows(filePath) {
  if (!fs.existsSync(filePath)) return { headers: [], rows: [] };
  const text = fs.readFileSync(filePath, "utf8").trim();
  if (!text) return { headers: [], rows: [] };
  const lines = text.split(/\r?\n/);
  const headers = lines.shift().split("\t");
  const rows = lines.filter(Boolean).map((line) => {
    const values = line.split("\t");
    return Object.fromEntries(headers.map((header, index) => [header, values[index] || ""]));
  });
  return { headers, rows };
}

function writeTsvRows(filePath, headers, rows) {
  if (!headers.length) return;
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const body = rows.map((row) => headers.map((header) => row[header] || "").join("\t"));
  fs.writeFileSync(filePath, `${headers.join("\t")}\n${body.length ? `${body.join("\n")}\n` : ""}`);
}

function registryDataPaths(row, registryName) {
  const fieldsByRegistry = {
    annotations: ["annotation", "annotation_tabix", "annotation_index", "genome", "genome_2bit"],
    genomes: ["fasta", "two_bit", "genome", "genome_2bit", "assembly_report", "assembly_stats"],
    go_annotations: ["gaf_file", "index_file"]
  };
  const paths = [];
  for (const field of fieldsByRegistry[registryName] || []) {
    let value = normalizeRelativePath(row[field]);
    if (value && !value.includes("/") && registryName === "genomes") {
      value = `genomes/${value}`;
    }
    if (value && !value.includes("/") && registryName === "go_annotations") {
      value = field === "index_file"
        ? `go_annotations/index/${value}`
        : `go_annotations/raw/${value}`;
    }
    if (value) paths.push(value);
  }
  if (registryName === "annotations") {
    const icon = normalizeRelativePath(row.icon);
    if (icon) paths.push(icon.startsWith("www/") ? icon : `www/${icon}`);
  }
  return paths;
}

function rowMatchesSpecies(row, speciesIds) {
  const speciesId = String(row.species_id || "").trim().toLowerCase();
  return Boolean(speciesId && speciesIds.has(speciesId));
}

function rowOwnsArchivePath(row, archivePaths) {
  const archiveBasenames = new Set(Array.from(archivePaths, (value) => path.posix.basename(value).toLowerCase()));
  return Object.values(row).some((value) => {
    const normalized = normalizeRelativePath(value);
    if (!normalized) return false;
    if (archivePaths.has(normalized)) return true;
    const basename = path.posix.basename(normalized).toLowerCase();
    return basename.includes(".") && archiveBasenames.has(basename);
  });
}

function sanitizeCacheKey(value) {
  return String(value || "").replace(/[^A-Za-z0-9._-]/g, "_").replace(/_+/g, "_");
}

function pruneEmptyParents(filePath, root) {
  let parent = path.dirname(filePath);
  const resolvedRoot = path.resolve(root);
  while (parent !== resolvedRoot && parent.startsWith(`${resolvedRoot}${path.sep}`)) {
    try {
      if (fs.readdirSync(parent).length > 0) break;
      fs.rmdirSync(parent);
      parent = path.dirname(parent);
    } catch (_) {
      break;
    }
  }
}

function removeRelativePath(root, relativePath, removedPaths) {
  const target = resolveInside(root, relativePath);
  if (!target || !fs.existsSync(target)) return false;
  fs.rmSync(target, { recursive: true, force: true });
  removedPaths.push(target);
  pruneEmptyParents(target, root);
  return true;
}

function removeAbsolutePathInside(root, targetPath, removedPaths) {
  if (!targetPath || !isInside(root, targetPath) || !fs.existsSync(targetPath)) return false;
  fs.rmSync(targetPath, { recursive: true, force: true });
  removedPaths.push(path.resolve(targetPath));
  pruneEmptyParents(targetPath, root);
  return true;
}

async function archiveEntriesForDataset(dataset, installed, dataRoot, validateZipArchive) {
  const fallbackPackagePath = dataset && dataset.package
    ? path.join(dataRoot, "packages", `${dataset.id}-${dataset.version || "latest"}.zip`)
    : "";
  const packagePath = String(installed.packagePath || fallbackPackagePath || "");
  if (!packagePath || !fs.existsSync(packagePath)) return { entries: [], packagePath };
  try {
    const entries = await validateZipArchive(packagePath);
    return {
      entries: entries.map(normalizeRelativePath).filter(Boolean),
      packagePath
    };
  } catch (_) {
    // A corrupt or incomplete package must not prevent removing its installed files.
    return { entries: [], packagePath };
  }
}

function removeMatchingCacheFiles(cacheRoot, annotationPaths, packagedCacheNames, removedPaths) {
  const cacheDir = path.join(cacheRoot, "annotation_index");
  if (!fs.existsSync(cacheDir)) return;
  const tokens = annotationPaths
    .map((filePath) => sanitizeCacheKey(path.basename(filePath)).toLowerCase())
    .filter(Boolean);
  const exactNames = new Set(packagedCacheNames.map((name) => path.basename(name).toLowerCase()));
  for (const name of fs.readdirSync(cacheDir)) {
    const lowerName = name.toLowerCase();
    if (!exactNames.has(lowerName) && !tokens.some((token) => lowerName.includes(token))) continue;
    removeAbsolutePathInside(cacheRoot, path.join(cacheDir, name), removedPaths);
  }
}

async function removeInstalledDatasets({
  dataRoot,
  cacheRoot,
  datasetIds,
  manifest,
  installRegistry,
  validateZipArchive
}) {
  const requestedIds = Array.from(new Set((datasetIds || []).map((id) => String(id || "").trim()).filter(Boolean)));
  const installedDatasets = installRegistry && installRegistry.datasets || {};
  const manifestById = new Map((manifest.datasets || []).map((dataset) => [dataset.id, dataset]));
  const unknownIds = requestedIds.filter((id) => !installedDatasets[id] && !manifestById.has(id));
  if (unknownIds.length) {
    throw new Error(`These organisms are not installed: ${unknownIds.join(", ")}`);
  }
  if (!requestedIds.length) {
    return { ok: true, removedDatasetIds: [], removedPaths: [] };
  }

  const speciesIds = new Set();
  const archivePaths = new Set();
  const packagedCacheNames = [];
  const packagePaths = [];
  for (const datasetId of requestedIds) {
    const installed = installedDatasets[datasetId] || {};
    const dataset = manifestById.get(datasetId) || { id: datasetId, speciesId: installed.speciesId || datasetId };
    for (const value of [datasetId, dataset.speciesId, installed.speciesId]) {
      const normalized = String(value || "").trim().toLowerCase();
      if (normalized) speciesIds.add(normalized);
    }
    const archive = await archiveEntriesForDataset(dataset, installed, dataRoot, validateZipArchive);
    if (archive.packagePath) packagePaths.push(archive.packagePath);
    for (const file of dataset.files || []) {
      const relativePath = normalizeRelativePath(file.path);
      if (relativePath) archivePaths.add(relativePath);
    }
    for (const entry of archive.entries) {
      if (entry.startsWith("cache/annotation_index/") && !entry.endsWith("/")) {
        packagedCacheNames.push(path.basename(entry));
      } else if (!entry.endsWith("/")) {
        archivePaths.add(entry);
      }
    }
  }

  const registryFiles = {
    annotations: path.join(dataRoot, "annotations", "registry.tsv"),
    genomes: path.join(dataRoot, "genomes", "registry.tsv"),
    go_annotations: path.join(dataRoot, "go_annotations", "registry.tsv")
  };
  const registries = Object.fromEntries(
    Object.entries(registryFiles).map(([name, filePath]) => [name, readTsvRows(filePath)])
  );
  const targetAnnotationRows = registries.annotations.rows.filter((row) => rowMatchesSpecies(row, speciesIds));
  for (const row of targetAnnotationRows) {
    for (const dataPath of registryDataPaths(row, "annotations")) archivePaths.add(dataPath);
  }
  const targetOrganisms = new Set(targetAnnotationRows.map((row) => String(row.organism || "").trim().toLowerCase()).filter(Boolean));
  const targetTaxids = new Set(targetAnnotationRows.map((row) => String(row.taxid || "").trim()).filter(Boolean));

  const relatedRow = (row) => {
    if (rowMatchesSpecies(row, speciesIds) || rowOwnsArchivePath(row, archivePaths)) return true;
    const organism = String(row.organism || "").trim().toLowerCase();
    const taxid = String(row.taxid || "").trim();
    return Boolean(
      organism &&
      taxid &&
      targetOrganisms.has(organism) &&
      targetTaxids.has(taxid)
    );
  };

  const targetRows = {
    annotations: targetAnnotationRows,
    genomes: registries.genomes.rows.filter(relatedRow),
    go_annotations: registries.go_annotations.rows.filter(relatedRow)
  };
  const remainingRows = {
    annotations: registries.annotations.rows.filter((row) => !targetRows.annotations.includes(row)),
    genomes: registries.genomes.rows.filter((row) => !targetRows.genomes.includes(row)),
    go_annotations: registries.go_annotations.rows.filter((row) => !targetRows.go_annotations.includes(row))
  };

  const ownedDataPaths = new Set(
    Array.from(archivePaths).filter((entry) => !REGISTRY_PATHS.has(entry) && !SHARED_DATA_PATHS.has(entry))
  );
  for (const [registryName, rows] of Object.entries(targetRows)) {
    for (const row of rows) {
      for (const dataPath of registryDataPaths(row, registryName)) ownedDataPaths.add(dataPath);
    }
  }
  for (const speciesId of speciesIds) {
    const aliasDir = path.join(dataRoot, "data", "alias_index");
    if (!fs.existsSync(aliasDir)) continue;
    for (const name of fs.readdirSync(aliasDir)) {
      if (name.toLowerCase().startsWith(speciesId)) {
        ownedDataPaths.add(normalizeRelativePath(path.join("data", "alias_index", name)));
      }
    }
  }

  const protectedDataPaths = new Set();
  for (const [registryName, rows] of Object.entries(remainingRows)) {
    for (const row of rows) {
      for (const dataPath of registryDataPaths(row, registryName)) protectedDataPaths.add(dataPath);
    }
  }

  const removedPaths = [];
  for (const dataPath of ownedDataPaths) {
    if (
      !dataPath ||
      dataPath === "dataset.json" ||
      REGISTRY_PATHS.has(dataPath) ||
      SHARED_DATA_PATHS.has(dataPath) ||
      protectedDataPaths.has(dataPath)
    ) {
      continue;
    }
    removeRelativePath(dataRoot, dataPath, removedPaths);
  }

  const datasetMetaPath = path.join(dataRoot, "dataset.json");
  if (fs.existsSync(datasetMetaPath)) {
    try {
      const datasetMeta = JSON.parse(fs.readFileSync(datasetMetaPath, "utf8"));
      if (requestedIds.includes(String(datasetMeta.id || ""))) {
        removeAbsolutePathInside(dataRoot, datasetMetaPath, removedPaths);
      }
    } catch (_) {
      // Ignore stale metadata; it is not used to determine installed state.
    }
  }

  const annotationPaths = targetRows.annotations.flatMap((row) => [
    normalizeRelativePath(row.annotation),
    normalizeRelativePath(row.annotation_tabix)
  ]).filter(Boolean);
  removeMatchingCacheFiles(cacheRoot, annotationPaths, packagedCacheNames, removedPaths);
  removeMatchingCacheFiles(path.join(dataRoot, "cache"), annotationPaths, packagedCacheNames, removedPaths);

  for (const [registryName, registry] of Object.entries(registries)) {
    writeTsvRows(registryFiles[registryName], registry.headers, remainingRows[registryName]);
  }

  for (const packagePath of packagePaths) {
    removeAbsolutePathInside(dataRoot, packagePath, removedPaths);
  }
  for (const datasetId of requestedIds) delete installedDatasets[datasetId];
  const installRegistryPath = path.join(dataRoot, "desktop-datasets.json");
  fs.mkdirSync(path.dirname(installRegistryPath), { recursive: true });
  fs.writeFileSync(installRegistryPath, `${JSON.stringify({
    ...installRegistry,
    version: installRegistry.version || 1,
    datasets: installedDatasets
  }, null, 2)}\n`);

  return {
    ok: true,
    removedDatasetIds: requestedIds,
    removedPaths
  };
}

module.exports = {
  normalizeRelativePath,
  readTsvRows,
  removeInstalledDatasets,
  resolveInside
};
