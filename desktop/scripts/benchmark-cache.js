const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const repoRoot = path.resolve(__dirname, "..", "..");
const desktopRoot = path.resolve(__dirname, "..");

function argValue(name, fallback = "") {
  const prefix = `--${name}=`;
  const hit = process.argv.find((arg) => arg.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : fallback;
}

function platformKey() {
  return `${process.platform}-${process.arch}`;
}

const dataRoot = path.resolve(argValue("data-root", process.env.CGV_DATA_ROOT || repoRoot));
const cacheRoot = path.resolve(argValue("cache-root", process.env.CGV_CACHE_DIR || path.join(os.tmpdir(), "cgv-cache-benchmark")));
const species = argValue("species", "");
if (!species) {
  console.error("Usage: node benchmark-cache.js --species=<species_query> [--data-root=<dir>] [--cache-root=<dir>] [--rscript=<path>]");
  console.error("  --species: a substring matching a species in annotations/registry.tsv (e.g. 'homo_sapiens')");
  process.exit(1);
}
const rscript = argValue(
  "rscript",
  process.env.CGV_RSCRIPT || path.join(desktopRoot, "resources", "r", platformKey(), "bin", "Rscript")
);

if (!fs.existsSync(rscript)) throw new Error(`Rscript not found: ${rscript}`);

const rCode = `
Sys.setenv(
  CGV_DATA_ROOT=${JSON.stringify(dataRoot)},
  CGV_CACHE_DIR=${JSON.stringify(cacheRoot)},
  APP_ALIAS_DISK_CACHE_DIR=file.path(${JSON.stringify(cacheRoot)}, "external_alias"),
  CGV_NCBI_DOWNLOADS_DIR=file.path(${JSON.stringify(dataRoot)}, "ncbi_downloads"),
  APP_PERF_TIMING="1"
)
source("global.R")
registry <- read.delim(file.path(Sys.getenv("CGV_DATA_ROOT"), "annotations", "registry.tsv"), sep="\\t", stringsAsFactors=FALSE, check.names=FALSE)
hit <- registry[grepl(${JSON.stringify(species)}, paste(registry$species_id, registry$organism, registry$label, registry$taxid), ignore.case=TRUE), , drop=FALSE]
if (nrow(hit) < 1) stop("No species matched benchmark query")
annotation_path <- resolve_catalog_path(hit$annotation_tabix[1])
if (!exists("build_gff_gene_light_index")) stop("build_gff_gene_light_index is not available")
first <- system.time(idx1 <- build_gff_gene_light_index(annotation_path))[["elapsed"]]
second <- system.time(idx2 <- build_gff_gene_light_index(annotation_path))[["elapsed"]]
idx_rows <- function(x) {
  if (is.data.frame(x)) return(nrow(x))
  if (is.list(x) && is.data.frame(x$index)) return(nrow(x$index))
  if (is.list(x) && is.data.frame(x$genes)) return(nrow(x$genes))
  NA_integer_
}
cat(jsonlite::toJSON(list(ok=TRUE, species_id=hit$species_id[1], annotation_path=annotation_path, cache_dir=Sys.getenv("CGV_CACHE_DIR"), first_elapsed_s=unname(first), second_elapsed_s=unname(second), first_rows=idx_rows(idx1), second_rows=idx_rows(idx2)), auto_unbox=TRUE, pretty=TRUE))
cat("\\n")
`;

const result = spawnSync(rscript, ["-e", rCode], {
  cwd: repoRoot,
  encoding: "utf8",
  env: { ...process.env }
});

if (result.status !== 0) {
  throw new Error(result.stderr || result.stdout || `R benchmark failed with ${result.status}`);
}
process.stdout.write(result.stdout);
