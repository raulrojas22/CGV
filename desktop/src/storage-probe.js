const path = require("path");

function recommendedStorageRoot(userDataPath) {
  return path.join(userDataPath, "Storage");
}

function rString(value) {
  return JSON.stringify(String(value).replace(/\\/g, "/"));
}

function buildStorageProbeExpression(storageRoot, probeId = `${process.pid}-${Date.now()}`) {
  const targets = ["data", "cache"].map((name) => path.join(storageRoot, name));
  const safeProbeId = String(probeId).replace(/[^a-zA-Z0-9_-]/g, "-");
  return [
    `targets <- c(${targets.map(rString).join(", ")})`,
    `probe_name <- ${rString(`.cgv-r-write-probe-${safeProbeId}`)}`,
    "for (target in targets) {",
    "  if (!dir.exists(target) && !dir.create(target, recursive=TRUE, showWarnings=FALSE)) stop(sprintf('cannot create %s', target))",
    "  probe <- file.path(target, probe_name)",
    "  tryCatch({",
    "    writeLines('cgv-storage-ok', probe, useBytes=TRUE)",
    "    if (!file.exists(probe)) stop(sprintf('write probe was not created in %s', target))",
    "  }, finally=unlink(probe, force=TRUE))",
    "}",
    "cat('cgv-storage-probe-ok\\n')"
  ].join("\n");
}

module.exports = {
  buildStorageProbeExpression,
  recommendedStorageRoot
};
