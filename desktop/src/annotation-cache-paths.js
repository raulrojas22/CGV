const fs = require("fs");
const path = require("path");

const PORTABLE_CACHE_KINDS = new Set(["gene_light", "autocomplete"]);
const STAGING_PATH_MARKER = "_annotations_";
const MAX_UNCOMPACTED_FILENAME_LENGTH = 160;

function portableAnnotationCacheFilename(fileName, { force = false } = {}) {
  const baseName = path.basename(String(fileName || ""));
  const kindMatch = baseName.match(/^([^_]+(?:_[^_]+)?)__/);
  const kind = kindMatch ? kindMatch[1] : "";
  if (!PORTABLE_CACHE_KINDS.has(kind) || !baseName.toLowerCase().endsWith(".rds")) {
    return baseName;
  }

  const lowerName = baseName.toLowerCase();
  const markerIndex = lowerName.lastIndexOf(STAGING_PATH_MARKER);
  const needsCompaction = force ||
    baseName.length > MAX_UNCOMPACTED_FILENAME_LENGTH ||
    lowerName.includes("dataset_packages_work_");
  if (!needsCompaction || markerIndex < 0) {
    return baseName;
  }

  const portableIdentity = baseName.slice(markerIndex + STAGING_PATH_MARKER.length);
  if (!/\.gff(?:3)?(?:\.gz)?(?:_|\.rds$)/i.test(portableIdentity)) {
    return baseName;
  }
  return `${kind}__portable__${portableIdentity}`;
}

function normalizeAnnotationCacheDirectory(cacheDir, { force = false } = {}) {
  if (!fs.existsSync(cacheDir)) {
    return { compacted: 0, duplicatesRemoved: 0, unchanged: 0 };
  }

  let compacted = 0;
  let duplicatesRemoved = 0;
  let unchanged = 0;
  for (const fileName of fs.readdirSync(cacheDir).filter((name) => name.toLowerCase().endsWith(".rds"))) {
    const portableName = portableAnnotationCacheFilename(fileName, { force });
    if (portableName === fileName) {
      unchanged += 1;
      continue;
    }

    const sourcePath = path.join(cacheDir, fileName);
    const targetPath = path.join(cacheDir, portableName);
    if (fs.existsSync(targetPath)) {
      fs.rmSync(sourcePath, { force: true });
      duplicatesRemoved += 1;
      continue;
    }
    fs.renameSync(sourcePath, targetPath);
    compacted += 1;
  }
  return { compacted, duplicatesRemoved, unchanged };
}

module.exports = {
  normalizeAnnotationCacheDirectory,
  portableAnnotationCacheFilename
};
