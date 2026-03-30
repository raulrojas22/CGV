#!/usr/bin/env Rscript

suppressWarnings({
  suppressPackageStartupMessages(library(stringr))
  suppressPackageStartupMessages(library(httr2))
  suppressPackageStartupMessages(library(jsonlite))
  args <- commandArgs(trailingOnly = TRUE)
})

arg_value <- function(name, default = NULL) {
  prefix <- paste0("--", name, "=")
  hit <- args[startsWith(args, prefix)]
  if (length(hit) == 0) {
    return(default)
  }
  sub(prefix, "", hit[1], fixed = TRUE)
}

has_flag <- function(name) {
  paste0("--", name) %in% args
}

if (has_flag("help")) {
  cat(
    "Usage:\n",
    "  Rscript scripts/update_registries.R [--root=PATH] [--genomes-dir=DIR] [--annotations-dir=DIR] [--timeout-sec=N] [--offline] [--write] [--keep-existing]\n\n",
    "Defaults:\n",
    "  --root=. --genomes-dir=genomes --annotations-dir=annotations (clean rebuild mode)\n\n",
    "Behavior:\n",
    "  - Scans genome and annotation folders.\n",
    "  - Rebuilds genomes/registry.tsv and annotations/registry.tsv from current files.\n",
    "  - Auto-fills optimized preloaded fields when present (annotation_tabix/annotation_index/genome_2bit).\n",
    "  - Tries to infer canonical organism name/taxid/aliases from file metadata and NCBI taxonomy.\n",
    "  - By default does NOT reuse old TSV rows (clean generation).\n",
    "  - Use --keep-existing to reuse existing TSV metadata when possible.\n",
    "  - Use --offline to skip NCBI queries.\n",
    "  - Without --write, runs in dry-run mode.\n",
    sep = ""
  )
  quit(save = "no", status = 0)
}

root <- normalizePath(arg_value("root", "."), winslash = "/", mustWork = FALSE)
genomes_dir_rel <- arg_value("genomes-dir", "genomes")
annotations_dir_rel <- arg_value("annotations-dir", "annotations")
write_mode <- has_flag("write")
offline_mode <- has_flag("offline")
keep_existing <- has_flag("keep-existing")
timeout_sec <- suppressWarnings(as.numeric(arg_value("timeout-sec", "4")))
if (!is.finite(timeout_sec) || timeout_sec <= 0) timeout_sec <- 4

genomes_dir <- normalizePath(file.path(root, genomes_dir_rel), winslash = "/", mustWork = FALSE)
annotations_dir <- normalizePath(file.path(root, annotations_dir_rel), winslash = "/", mustWork = FALSE)
icons_dir <- normalizePath(file.path(root, "www", "icons"), winslash = "/", mustWork = FALSE)

utils_path <- file.path(root, "R", "utils.R")
if (!file.exists(utils_path)) {
  stop("Cannot find R/utils.R at: ", utils_path)
}
source(utils_path, local = TRUE)

ensure_cols <- function(df, cols) {
  for (nm in setdiff(cols, colnames(df))) df[[nm]] <- rep(NA_character_, nrow(df))
  df
}

safe_chr <- function(x) {
  y <- as.character(x %||% "")
  y[is.na(y)] <- ""
  y
}

safe_int <- function(x) {
  y <- suppressWarnings(as.integer(x))
  y
}

clean_stem <- function(path) {
  x <- basename(path)
  x <- sub("\\.gz$", "", x, ignore.case = TRUE)
  x <- sub("\\.(gff3?|gtf|fa|fasta|fna|2bit)$", "", x, ignore.case = TRUE)
  x
}

clean_label <- function(x) {
  x <- safe_chr(x)
  x <- gsub("[._]+", " ", x)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

to_species_id <- function(x) {
  x <- tolower(safe_chr(x))
  x <- gsub("[^a-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  x <- gsub("_+", "_", x)
  if (!nzchar(x)) x <- "species"
  if (grepl("^[0-9]", x)) x <- paste0("sp_", x)
  x
}

rel_path <- function(abs_path, root_path) {
  ap <- normalizePath(abs_path, winslash = "/", mustWork = FALSE)
  rp <- normalizePath(root_path, winslash = "/", mustWork = FALSE)
  pref <- paste0(rp, "/")
  if (startsWith(ap, pref)) {
    sub(pref, "", ap, fixed = TRUE)
  } else {
    ap
  }
}

first_non_empty <- function(...) {
  xs <- list(...)
  for (x in xs) {
    v <- safe_chr(x)
    if (length(v) > 0 && nzchar(v[1])) {
      return(v[1])
    }
  }
  ""
}

common_prefix_nchar <- function(a, b) {
  a <- safe_chr(a)[1]
  b <- safe_chr(b)[1]
  n <- min(nchar(a), nchar(b))
  if (n <= 0) {
    return(0L)
  }
  for (i in seq_len(n)) {
    if (substr(a, i, i) != substr(b, i, i)) {
      return(as.integer(i - 1))
    }
  }
  as.integer(n)
}

read_tsv_or_empty <- function(path, cols) {
  if (!file.exists(path)) {
    out <- data.frame(stringsAsFactors = FALSE)
    out <- ensure_cols(out, cols)
    return(out)
  }
  out <- tryCatch(
    read.delim(path, sep = "\t", stringsAsFactors = FALSE, check.names = FALSE),
    error = function(e) data.frame(stringsAsFactors = FALSE)
  )
  ensure_cols(out, cols)
}

find_files <- function(dir_path, pattern) {
  if (!dir.exists(dir_path)) {
    return(character(0))
  }
  list.files(dir_path, pattern = pattern, recursive = TRUE, full.names = TRUE, ignore.case = TRUE)
}

is_fasta_path <- function(path) grepl("\\.(fa|fasta|fna)(\\.gz)?$", path, ignore.case = TRUE)
is_twobit_path <- function(path) grepl("\\.2bit$", path, ignore.case = TRUE)
is_annotation_plain_path <- function(path) grepl("\\.(gff|gff3|gtf)$", path, ignore.case = TRUE)
is_annotation_gz_path <- function(path) grepl("\\.(gff|gff3|gtf)\\.(gz|bgz)$", path, ignore.case = TRUE)
annotation_stem_key <- function(path) tolower(clean_stem(path))
find_annotation_index_for_bgz <- function(path) {
  p <- safe_chr(path)[1]
  if (!nzchar(p)) {
    return("")
  }
  candidates <- c(paste0(p, ".tbi"), paste0(p, ".csi"))
  hit <- candidates[file.exists(candidates)]
  if (length(hit) == 0) "" else hit[1]
}

split_aliases <- function(x) {
  x <- safe_chr(x)
  if (length(x) == 0) {
    return(character(0))
  }
  toks <- unlist(strsplit(paste(x, collapse = "|"), "\\|", fixed = FALSE))
  toks <- trimws(toks)
  toks[nzchar(toks)]
}

normalize_alias_vector <- function(x) {
  x <- safe_chr(x)
  x <- trimws(x)
  x <- x[nzchar(x)]
  if (length(x) == 0) {
    return(character(0))
  }
  x <- unique(x)
  x[order(tolower(x))]
}

default_icon_web_path <- if (file.exists(file.path(icons_dir, "DNA.ico"))) "/icons/DNA.ico" else "/icons/dna.ico"

normalize_icon_key <- function(x) {
  y <- tolower(safe_chr(x))
  y <- gsub("[._]+", " ", y)
  y <- gsub("\\b(ssp\\.?|subsp\\.?|subspecies|var\\.?|strain|group|clade|lineage)\\b", " ", y, ignore.case = TRUE)
  y <- gsub("[^a-z0-9]+", " ", y)
  y <- gsub("\\s+", " ", y)
  trimws(y)
}

icon_label_variants <- function(x) {
  y <- clean_label(x)
  if (!nzchar(y)) {
    return(character(0))
  }
  out <- c(
    y,
    gsub("\\b(ssp\\.?|subsp\\.?|subspecies|var\\.?|strain|group|clade|lineage)\\b", " ", y, ignore.case = TRUE)
  )
  out <- gsub("\\s+", " ", trimws(out))
  unique(out[nzchar(out)])
}

build_icon_catalog <- function(dir_path) {
  if (!dir.exists(dir_path)) {
    return(data.frame(key = character(), web_path = character(), stringsAsFactors = FALSE))
  }
  files <- list.files(
    dir_path,
    pattern = "\\.(ico|png|svg|jpg|jpeg|webp)$",
    full.names = TRUE,
    ignore.case = TRUE
  )
  if (length(files) == 0) {
    return(data.frame(key = character(), web_path = character(), stringsAsFactors = FALSE))
  }
  labels <- sub("\\.[^.]+$", "", basename(files))
  keys <- normalize_icon_key(labels)
  keep <- nzchar(keys)
  out <- data.frame(
    key = keys[keep],
    web_path = paste0("/icons/", basename(files[keep])),
    stringsAsFactors = FALSE
  )
  out <- out[!duplicated(out$key), , drop = FALSE]
  rownames(out) <- NULL
  out
}

icon_catalog <- build_icon_catalog(icons_dir)

resolve_icon_for_species <- function(organism = "", aliases = character(), existing_icon = "") {
  existing <- trimws(safe_chr(existing_icon)[1])
  default_candidates <- tolower(c("", "/icons/dna.ico", "/icons/DNA.ico", "icons/dna.ico", "icons/DNA.ico", "www/icons/dna.ico", "www/icons/DNA.ico"))
  if (nzchar(existing) && !(tolower(existing) %in% default_candidates)) {
    return(existing)
  }
  if (nrow(icon_catalog) == 0) {
    return(default_icon_web_path)
  }

  candidates <- unique(c(
    icon_label_variants(organism),
    unlist(lapply(split_aliases(aliases), icon_label_variants), use.names = FALSE)
  ))
  keys <- unique(normalize_icon_key(candidates))
  keys <- keys[nzchar(keys)]
  if (length(keys) == 0) {
    return(default_icon_web_path)
  }

  for (k in keys) {
    hit <- which(icon_catalog$key == k)
    if (length(hit) > 0) {
      return(icon_catalog$web_path[hit[1]])
    }
  }

  fuzzy_hits <- integer(0)
  for (k in keys) {
    hit <- which(grepl(k, icon_catalog$key, fixed = TRUE) | grepl(icon_catalog$key, k, fixed = TRUE))
    if (length(hit) > 0) fuzzy_hits <- c(fuzzy_hits, hit)
  }
  fuzzy_hits <- unique(fuzzy_hits)
  if (length(fuzzy_hits) > 0) {
    best <- fuzzy_hits[which.max(nchar(icon_catalog$key[fuzzy_hits]))]
    return(icon_catalog$web_path[best])
  }

  default_icon_web_path
}

collect_strings_recursive <- function(x) {
  if (is.null(x)) {
    return(character(0))
  }
  if (is.character(x)) {
    return(x)
  }
  if (is.atomic(x)) {
    return(as.character(x))
  }
  if (is.list(x)) {
    return(unlist(lapply(x, collect_strings_recursive), use.names = FALSE))
  }
  character(0)
}

read_text_sample <- function(path, n = 200L) {
  if (!file.exists(path)) {
    return(character(0))
  }
  con <- if (grepl("\\.gz$", path, ignore.case = TRUE)) gzfile(path, open = "rt") else file(path, open = "r")
  on.exit(try(close(con), silent = TRUE), add = TRUE)
  out <- tryCatch(readLines(con, n = as.integer(n), warn = FALSE), error = function(e) character(0))
  out
}

extract_taxid_from_text <- function(text_vec) {
  txt <- paste(safe_chr(text_vec), collapse = "\n")
  m <- stringr::str_match(
    txt,
    stringr::regex("taxon:(\\d+)|taxid\\s*[:=]\\s*(\\d+)|\\bOX=(\\d+)\\b|wwwtax\\.cgi\\?id=(\\d+)", ignore_case = TRUE)
  )
  vals <- as.character(na.omit(m[1, -1]))
  if (length(vals) == 0) {
    return(NA_integer_)
  }
  suppressWarnings(as.integer(vals[1]))
}

sanitize_organism_hint <- function(x) {
  y <- trimws(safe_chr(x)[1])
  if (!nzchar(y)) {
    return("")
  }
  if (grepl("^https?://", y, ignore.case = TRUE)) {
    return("")
  }
  if (grepl("^(GCF|GCA)[_\\s]\\d+", y, ignore.case = TRUE)) {
    return("")
  }
  if (grepl("\\bgenomic\\b", y, ignore.case = TRUE) && grepl("\\d", y)) {
    return("")
  }
  y
}

sanitize_label_hint <- function(x) {
  y <- trimws(safe_chr(x)[1])
  if (!nzchar(y)) {
    return("")
  }
  if (grepl("^https?://", y, ignore.case = TRUE)) {
    return("")
  }
  if (grepl("^(GCF|GCA)[_\\s]\\d+", y, ignore.case = TRUE)) {
    return("")
  }
  y
}

known_species_map <- list(
  list(pattern = "oryza\\s+sativa.*japonica|japonica|irgsp|nipponbare", organism = "Oryza sativa ssp. japonica", taxid = 4530L, aliases = c("rice", "oryza", "osativa", "japonica")),
  list(pattern = "oryza\\s+sativa.*indica|indica|asm465v1", organism = "Oryza sativa ssp. indica", taxid = NA_integer_, aliases = c("rice", "oryza", "osativa", "indica")),
  list(pattern = "arabidopsis|thaliana|athaliana", organism = "Arabidopsis thaliana", taxid = 3702L, aliases = c("arabidopsis")),
  list(pattern = "zea\\s+mays|maize|corn|zmays", organism = "Zea mays", taxid = 4577L, aliases = c("maize", "corn")),
  list(pattern = "triticum|wheat|taestivum", organism = "Triticum aestivum", taxid = 4565L, aliases = c("wheat")),
  list(pattern = "hordeum|barley|vulgare", organism = "Hordeum vulgare", taxid = 4513L, aliases = c("barley")),
  list(pattern = "sorghum|sbicolor", organism = "Sorghum bicolor", taxid = 4558L, aliases = c("sorghum")),
  list(pattern = "homo\\s+sapiens|human|hsapiens", organism = "Homo sapiens", taxid = 9606L, aliases = c("human")),
  list(pattern = "mus\\s+musculus|mouse|mmusculus", organism = "Mus musculus", taxid = 10090L, aliases = c("mouse")),
  list(pattern = "saccharomyces|yeast|scerevisiae", organism = "Saccharomyces cerevisiae", taxid = 4932L, aliases = c("yeast")),
  list(pattern = "drosophila|melanogaster", organism = "Drosophila melanogaster", taxid = 7227L, aliases = c("drosophila"))
)

known_species_taxid_map <- list(
  list(taxid = 7955L, organism = "Danio rerio", kingdom = "Animalia", aliases = c("zebrafish")),
  list(taxid = 9606L, organism = "Homo sapiens", kingdom = "Animalia", aliases = c("human")),
  list(taxid = 9598L, organism = "Pan troglodytes", kingdom = "Animalia", aliases = c("chimpanzee")),
  list(taxid = 10090L, organism = "Mus musculus", kingdom = "Animalia", aliases = c("mouse")),
  list(taxid = 9615L, organism = "Canis lupus familiaris", kingdom = "Animalia", aliases = c("dog", "canine")),
  list(taxid = 9823L, organism = "Sus scrofa", kingdom = "Animalia", aliases = c("pig")),
  list(taxid = 9796L, organism = "Equus caballus", kingdom = "Animalia", aliases = c("horse")),
  list(taxid = 8355L, organism = "Xenopus laevis", kingdom = "Animalia", aliases = c("xenopus")),
  list(taxid = 7227L, organism = "Drosophila melanogaster", kingdom = "Animalia", aliases = c("drosophila", "fruit fly")),
  list(taxid = 6239L, organism = "Caenorhabditis elegans", kingdom = "Animalia", aliases = c("c elegans", "nematode")),
  list(taxid = 4932L, organism = "Saccharomyces cerevisiae", kingdom = "Fungi", aliases = c("yeast")),
  list(taxid = 559292L, organism = "Saccharomyces cerevisiae", kingdom = "Fungi", aliases = c("yeast")),
  list(taxid = 237561L, organism = "Candida albicans", kingdom = "Fungi", aliases = c("candida")),
  list(taxid = 367110L, organism = "Neurospora crassa", kingdom = "Fungi", aliases = c("neurospora")),
  list(taxid = 332648L, organism = "Botrytis cinerea", kingdom = "Fungi", aliases = c("botrytis")),
  list(taxid = 3702L, organism = "Arabidopsis thaliana", kingdom = "Plantae", aliases = c("arabidopsis")),
  list(taxid = 4577L, organism = "Zea mays", kingdom = "Plantae", aliases = c("maize", "corn")),
  list(taxid = 4565L, organism = "Triticum aestivum", kingdom = "Plantae", aliases = c("wheat")),
  list(taxid = 39947L, organism = "Oryza sativa ssp. japonica", kingdom = "Plantae", aliases = c("rice", "japonica")),
  list(taxid = 39946L, organism = "Oryza sativa ssp. indica", kingdom = "Plantae", aliases = c("rice", "indica")),
  list(taxid = 4530L, organism = "Oryza sativa ssp. japonica", kingdom = "Plantae", aliases = c("rice", "japonica")),
  list(taxid = 4081L, organism = "Solanum lycopersicum", kingdom = "Plantae", aliases = c("tomato")),
  list(taxid = 29760L, organism = "Vitis vinifera", kingdom = "Plantae", aliases = c("grape")),
  list(taxid = 3750L, organism = "Malus domestica", kingdom = "Plantae", aliases = c("apple")),
  list(taxid = 101020L, organism = "Fragaria vesca", kingdom = "Plantae", aliases = c("strawberry")),
  list(taxid = 3885L, organism = "Phaseolus vulgaris", kingdom = "Plantae", aliases = c("common bean")),
  list(taxid = 9430L, organism = "Desmodus rotundus", kingdom = "Animalia", aliases = c("vampire bat"))
)

guess_from_known_species <- function(text_candidates) {
  txt <- tolower(paste(safe_chr(text_candidates), collapse = " | "))
  for (k in known_species_map) {
    if (grepl(k$pattern, txt, perl = TRUE)) {
      return(list(
        organism = as.character(k$organism),
        taxid = suppressWarnings(as.integer(k$taxid)),
        aliases = normalize_alias_vector(k$aliases)
      ))
    }
  }
  list(organism = "", taxid = NA_integer_, aliases = character(0))
}

guess_from_known_taxid <- function(taxid) {
  tx <- suppressWarnings(as.integer(taxid))
  if (!is.finite(tx) || is.na(tx) || tx <= 0) {
    return(list(organism = "", taxid = NA_integer_, kingdom = "", aliases = character(0)))
  }
  for (k in known_species_taxid_map) {
    if (!is.null(k$taxid) && suppressWarnings(as.integer(k$taxid)) == tx) {
      return(list(
        organism = as.character(k$organism),
        taxid = tx,
        kingdom = as.character(k$kingdom %||% ""),
        aliases = normalize_alias_vector(k$aliases)
      ))
    }
  }
  list(organism = "", taxid = tx, kingdom = "", aliases = character(0))
}

extract_organism_from_fasta_header <- function(lines) {
  if (length(lines) == 0) {
    return("")
  }
  hdr <- lines[grepl("^>", lines)]
  if (length(hdr) == 0) {
    return("")
  }
  txt <- paste(hdr[1:min(length(hdr), 20)], collapse = " ")
  pats <- c(
    "organism=([^\\]\\[;|]+)",
    "species=([^\\]\\[;|]+)",
    "OS=([^=]+?)\\s+OX=",
    "\\[(?:organism|species)[:=]\\s*([^\\]]+)\\]"
  )
  for (p in pats) {
    m <- stringr::str_match(txt, stringr::regex(p, ignore_case = TRUE))
    if (!all(is.na(m)) && nzchar(trimws(m[1, 2]))) {
      return(trimws(m[1, 2]))
    }
  }
  ""
}

detect_genome_metadata <- function(path) {
  stem <- clean_stem(path)
  lines <- read_text_sample(path, n = 160L)
  org_h <- extract_organism_from_fasta_header(lines)
  tx_h <- extract_taxid_from_text(lines)
  known <- guess_from_known_species(c(org_h, stem, basename(path)))
  organism <- first_non_empty(org_h, known$organism, clean_label(stem))
  taxid <- if (!is.na(tx_h)) tx_h else suppressWarnings(as.integer(known$taxid[1]))
  aliases <- normalize_alias_vector(c(known$aliases, clean_label(stem)))
  list(organism = organism, taxid = taxid, aliases = aliases)
}

.taxonomy_cache <- new.env(parent = emptyenv())

cache_get <- function(cache_key) {
  if (exists(cache_key, envir = .taxonomy_cache, inherits = FALSE)) get(cache_key, envir = .taxonomy_cache, inherits = FALSE) else NULL
}

cache_set <- function(cache_key, value) {
  assign(cache_key, value, envir = .taxonomy_cache)
  value
}

safe_eutils_json <- function(endpoint, query) {
  if (isTRUE(offline_mode)) {
    return(NULL)
  }
  req <- httr2::request(sprintf("https://eutils.ncbi.nlm.nih.gov/entrez/eutils/%s", endpoint))
  req <- do.call(httr2::req_url_query, c(list(.req = req), query))
  req <- httr2::req_timeout(req, timeout_sec)
  resp <- tryCatch(httr2::req_perform(req), error = function(e) NULL)
  if (is.null(resp)) {
    return(NULL)
  }
  txt <- tryCatch(httr2::resp_body_string(resp), error = function(e) "")
  if (!nzchar(txt)) {
    return(NULL)
  }
  tryCatch(jsonlite::fromJSON(txt, simplifyVector = FALSE), error = function(e) NULL)
}

taxonomy_lookup_by_taxid <- function(taxid) {
  taxid <- suppressWarnings(as.integer(taxid))
  if (!is.finite(taxid) || is.na(taxid) || taxid <= 0) {
    return(NULL)
  }
  key <- paste0("taxid:", taxid)
  hit <- cache_get(key)
  if (!is.null(hit)) {
    return(hit)
  }

  res <- safe_eutils_json("esummary.fcgi", list(db = "taxonomy", id = as.character(taxid), retmode = "json"))
  if (is.null(res) || is.null(res$result)) {
    return(cache_set(key, NULL))
  }

  rec <- res$result[[as.character(taxid)]]
  if (is.null(rec)) {
    return(cache_set(key, NULL))
  }
  sci <- first_non_empty(rec$scientificname, rec$title)
  common <- first_non_empty(rec$commonname, rec$genbankcommonname)
  other <- normalize_alias_vector(collect_strings_recursive(rec$othernames))
  out <- list(
    organism = sci,
    taxid = taxid,
    aliases = normalize_alias_vector(c(common, other))
  )
  cache_set(key, out)
}

taxonomy_lookup_by_name <- function(name) {
  name <- first_non_empty(name)
  if (!nzchar(name)) {
    return(NULL)
  }
  key <- paste0("name:", tolower(name))
  hit <- cache_get(key)
  if (!is.null(hit)) {
    return(hit)
  }

  res <- safe_eutils_json(
    "esearch.fcgi",
    list(db = "taxonomy", term = paste0(name, "[All Names]"), retmode = "json", retmax = "1")
  )
  taxid <- NA_integer_
  if (!is.null(res$esearchresult$idlist) && length(res$esearchresult$idlist) > 0) {
    taxid <- suppressWarnings(as.integer(res$esearchresult$idlist[[1]]))
  }
  out <- taxonomy_lookup_by_taxid(taxid)
  cache_set(key, out)
}

enrich_species_metadata <- function(organism_hint = "", taxid_hint = NA_integer_, aliases_hint = character(0), text_candidates = character(0)) {
  org_hint <- sanitize_organism_hint(first_non_empty(organism_hint))
  tax_hint <- suppressWarnings(as.integer(taxid_hint))
  known <- guess_from_known_species(c(org_hint, text_candidates))
  known_tx <- guess_from_known_taxid(tax_hint)
  base_org <- first_non_empty(org_hint, known_tx$organism, known$organism)
  base_tax <- if (!is.na(tax_hint) && is.finite(tax_hint)) tax_hint else first_non_empty(known_tx$taxid, known$taxid[1])
  base_tax <- suppressWarnings(as.integer(base_tax))
  if (!is.finite(base_tax) || is.na(base_tax)) base_tax <- NA_integer_

  tax_meta <- taxonomy_lookup_by_taxid(base_tax)
  name_meta <- if (is.null(tax_meta) && nzchar(base_org)) taxonomy_lookup_by_name(base_org) else NULL
  meta <- tax_meta %||% name_meta

  organism <- first_non_empty(meta$organism, base_org)
  taxid <- suppressWarnings(as.integer(first_non_empty(meta$taxid, base_tax)))
  if (!is.finite(taxid) || is.na(taxid)) taxid <- NA_integer_
  aliases <- normalize_alias_vector(c(
    split_aliases(aliases_hint),
    known_tx$aliases,
    known$aliases,
    meta$aliases,
    org_hint
  ))
  aliases <- aliases[tolower(aliases) != tolower(organism)]

  kingdom <- first_non_empty(known_tx$kingdom, "")

  list(
    organism = organism,
    taxid = taxid,
    kingdom = kingdom,
    aliases = aliases
  )
}

genome_files <- find_files(genomes_dir, "\\.(fa|fasta|fna)(\\.gz)?$|\\.2bit$")
annotation_files <- find_files(annotations_dir, "\\.(gff|gff3|gtf)(\\.gz)?$")
annotation_files <- annotation_files[!grepl("registry\\.tsv$", annotation_files, ignore.case = TRUE)]

genome_registry_path <- file.path(genomes_dir, "registry.tsv")
anno_registry_path <- file.path(annotations_dir, "registry.tsv")

if (isTRUE(keep_existing)) {
  existing_genome <- read_tsv_or_empty(genome_registry_path, c("organism", "taxid", "fasta", "aliases"))
  existing_anno <- read_tsv_or_empty(
    anno_registry_path,
    c("species_id", "label", "organism", "taxid", "annotation", "annotation_tabix", "annotation_index", "genome", "genome_2bit", "aliases", "icon", "kingdom")
  )
} else {
  existing_genome <- ensure_cols(data.frame(stringsAsFactors = FALSE), c("organism", "taxid", "fasta", "aliases"))
  existing_anno <- ensure_cols(
    data.frame(stringsAsFactors = FALSE),
    c("species_id", "label", "organism", "taxid", "annotation", "annotation_tabix", "annotation_index", "genome", "genome_2bit", "aliases", "icon", "kingdom")
  )
}

existing_genome$fasta <- safe_chr(existing_genome$fasta)
existing_anno$annotation <- safe_chr(existing_anno$annotation)
existing_anno$annotation_tabix <- safe_chr(existing_anno$annotation_tabix)
existing_anno$annotation_index <- safe_chr(existing_anno$annotation_index)
existing_anno$genome <- safe_chr(existing_anno$genome)
existing_anno$genome_2bit <- safe_chr(existing_anno$genome_2bit)
existing_anno$icon <- safe_chr(existing_anno$icon)
existing_anno$kingdom <- safe_chr(existing_anno$kingdom)

match_existing_by_path <- function(df, colname, relp) {
  if (nrow(df) == 0) {
    return(integer(0))
  }
  which(safe_chr(df[[colname]]) == safe_chr(relp))
}

match_existing_by_path_or_basename <- function(df, colname, relp) {
  if (nrow(df) == 0) {
    return(integer(0))
  }
  vals <- safe_chr(df[[colname]])
  idx <- which(vals == safe_chr(relp))
  if (length(idx) > 0) {
    return(idx)
  }
  rel_base <- basename(relp)
  which(basename(vals) == rel_base)
}

build_genome_registry <- function() {
  rows <- vector("list", length(genome_files))
  for (i in seq_along(genome_files)) {
    g_abs <- genome_files[i]
    g_rel <- rel_path(g_abs, genomes_dir)
    g_stem <- clean_stem(g_abs)
    idx <- match_existing_by_path_or_basename(existing_genome, "fasta", g_rel)
    ex <- if (length(idx) > 0) existing_genome[idx[1], , drop = FALSE] else NULL
    g_meta <- detect_genome_metadata(g_abs)
    merged <- enrich_species_metadata(
      organism_hint = first_non_empty(ex$organism, g_meta$organism, clean_label(g_stem)),
      taxid_hint = first_non_empty(ex$taxid, g_meta$taxid),
      aliases_hint = c(ex$aliases, g_meta$aliases),
      text_candidates = c(g_stem, basename(g_abs), g_meta$organism)
    )

    organism <- first_non_empty(merged$organism, clean_label(g_stem))
    taxid <- suppressWarnings(as.integer(merged$taxid))
    if (!is.finite(taxid) || is.na(taxid)) taxid <- NA_integer_
    aliases <- normalize_alias_vector(c(split_aliases(ex$aliases), g_meta$aliases, merged$aliases))
    aliases <- aliases[tolower(aliases) != tolower(organism)]
    aliases_txt <- if (length(aliases) > 0) paste(aliases, collapse = "|") else ""

    rows[[i]] <- data.frame(
      organism = organism,
      taxid = taxid,
      fasta = g_rel,
      aliases = aliases_txt,
      stringsAsFactors = FALSE
    )
  }
  out <- if (length(rows) > 0) do.call(rbind, rows) else data.frame(organism = character(), taxid = integer(), fasta = character(), aliases = character(), stringsAsFactors = FALSE)
  if (nrow(out) > 0) {
    out <- out[!duplicated(out$fasta), , drop = FALSE]
    out <- out[order(tolower(out$organism), tolower(out$fasta)), , drop = FALSE]
  }
  rownames(out) <- NULL
  out
}

find_best_genome <- function(organism, ann_file_abs, genomes_df) {
  if (nrow(genomes_df) == 0) {
    return("")
  }
  org_key <- normalize_org_key(organism)
  if (nzchar(org_key)) {
    g_keys <- vapply(genomes_df$organism, normalize_org_key, character(1))
    idx_exact <- which(g_keys == org_key)
    if (length(idx_exact) > 0) {
      return(genomes_df$fasta[idx_exact[1]])
    }
    idx_fuzzy <- which(nzchar(g_keys) & (grepl(org_key, g_keys, fixed = TRUE) | grepl(g_keys, org_key, fixed = TRUE)))
    if (length(idx_fuzzy) > 0) {
      return(genomes_df$fasta[idx_fuzzy[1]])
    }
  }

  ann_stem <- tolower(clean_stem(ann_file_abs))
  scores <- vapply(genomes_df$fasta, function(g_rel) {
    g_stem <- tolower(clean_stem(g_rel))
    common_prefix_nchar(ann_stem, g_stem)
  }, integer(1))
  best <- which.max(scores)
  if (length(best) == 0 || is.na(scores[best]) || scores[best] < 4) {
    return("")
  }
  genomes_df$fasta[best]
}

resolve_existing_annotation_genome <- function(genome_ref) {
  gref <- safe_chr(genome_ref)[1]
  if (!nzchar(gref)) {
    return("")
  }
  candidates <- c(
    normalizePath(file.path(root, gref), winslash = "/", mustWork = FALSE),
    normalizePath(file.path(genomes_dir, gref), winslash = "/", mustWork = FALSE)
  )
  hit <- candidates[file.exists(candidates)]
  if (length(hit) == 0) {
    return("")
  }
  rel_path(hit[1], root)
}

build_annotation_registry <- function(genomes_df) {
  ann_keys <- unique(annotation_stem_key(annotation_files))
  rows <- vector("list", length(ann_keys))
  fasta_genomes <- genomes_df[is_fasta_path(genomes_df$fasta), , drop = FALSE]
  twobit_genomes <- genomes_df[is_twobit_path(genomes_df$fasta), , drop = FALSE]

  for (i in seq_along(ann_keys)) {
    key <- ann_keys[i]
    ann_group <- annotation_files[annotation_stem_key(annotation_files) == key]
    if (length(ann_group) == 0) next

    ann_plain <- ann_group[is_annotation_plain_path(ann_group)]
    ann_gz <- ann_group[is_annotation_gz_path(ann_group)]
    ann_index_for_gz <- if (length(ann_gz) > 0) {
      stats::setNames(vapply(ann_gz, find_annotation_index_for_bgz, character(1)), ann_gz)
    } else {
      character(0)
    }
    ann_tabix <- names(ann_index_for_gz)[nzchar(ann_index_for_gz)]

    a_abs <- if (length(ann_plain) > 0) ann_plain[1] else if (length(ann_gz) > 0) ann_gz[1] else ann_group[1]
    ann_tabix_abs <- if (length(ann_tabix) > 0) ann_tabix[1] else ""
    ann_index_abs <- if (nzchar(ann_tabix_abs)) safe_chr(ann_index_for_gz[[ann_tabix_abs]])[1] else ""

    a_rel <- rel_path(a_abs, root)
    ann_tabix_rel <- if (nzchar(ann_tabix_abs)) rel_path(ann_tabix_abs, root) else ""
    ann_index_rel <- if (nzchar(ann_index_abs)) rel_path(ann_index_abs, root) else ""
    a_stem <- clean_stem(a_abs)

    idx <- unique(c(
      match_existing_by_path(existing_anno, "annotation", a_rel),
      if (nzchar(ann_tabix_rel)) match_existing_by_path(existing_anno, "annotation_tabix", ann_tabix_rel) else integer(0),
      if (nzchar(ann_index_rel)) match_existing_by_path(existing_anno, "annotation_index", ann_index_rel) else integer(0)
    ))
    ex <- if (length(idx) > 0) existing_anno[idx[1], , drop = FALSE] else NULL

    det <- tryCatch(
      detect_organism_from_gff(a_abs, original_name = basename(a_abs)),
      error = function(e) list(organism = NULL, taxid = NULL, source = "none")
    )
    det_org <- safe_chr(det$organism)[1]
    det_tax <- safe_int(det$taxid)[1]
    header_lines <- read_text_sample(a_abs, n = 180L)
    merged <- enrich_species_metadata(
      organism_hint = first_non_empty(det_org, ex$organism, clean_label(a_stem)),
      taxid_hint = first_non_empty(det_tax, ex$taxid, extract_taxid_from_text(header_lines)),
      aliases_hint = ex$aliases,
      text_candidates = c(a_stem, basename(a_abs))
    )

    organism <- first_non_empty(merged$organism, clean_label(a_stem))
    taxid <- suppressWarnings(as.integer(merged$taxid))
    if (!is.finite(taxid) || is.na(taxid)) taxid <- NA_integer_
    label <- first_non_empty(sanitize_label_hint(ex$label), organism)
    species_id_hint <- first_non_empty(ex$species_id, "")
    if (grepl("^https?_www_", species_id_hint, ignore.case = TRUE)) species_id_hint <- ""
    species_id <- first_non_empty(species_id_hint, to_species_id(paste(organism, a_stem)))
    aliases <- normalize_alias_vector(c(split_aliases(ex$aliases), merged$aliases))
    aliases <- aliases[tolower(aliases) != tolower(organism)]
    aliases_txt <- if (length(aliases) > 0) paste(aliases, collapse = "|") else ""

    genome_rel_existing <- resolve_existing_annotation_genome(first_non_empty(ex$genome, ""))
    genome_2bit_existing <- resolve_existing_annotation_genome(first_non_empty(ex$genome_2bit, ""))
    genome_rel <- if (nzchar(genome_rel_existing)) {
      genome_rel_existing
    } else {
      best_g <- find_best_genome(organism, a_abs, fasta_genomes)
      if (nzchar(best_g)) rel_path(file.path(genomes_dir, best_g), root) else ""
    }
    genome_2bit_rel <- if (nzchar(genome_2bit_existing)) {
      genome_2bit_existing
    } else {
      best_g2 <- find_best_genome(organism, a_abs, twobit_genomes)
      if (nzchar(best_g2)) rel_path(file.path(genomes_dir, best_g2), root) else ""
    }

    kingdom <- first_non_empty(safe_chr(ex$kingdom), merged$kingdom, "")

    rows[[i]] <- data.frame(
      species_id = species_id,
      label = label,
      organism = organism,
      taxid = taxid,
      annotation = a_rel,
      annotation_tabix = ann_tabix_rel,
      annotation_index = ann_index_rel,
      genome = genome_rel,
      genome_2bit = genome_2bit_rel,
      aliases = aliases_txt,
      icon = resolve_icon_for_species(organism = organism, aliases = aliases_txt, existing_icon = ex$icon),
      kingdom = kingdom,
      stringsAsFactors = FALSE
    )
  }

  out <- if (length(rows) > 0) {
    do.call(rbind, rows)
  } else {
    data.frame(
      species_id = character(),
      label = character(),
      organism = character(),
      taxid = integer(),
      annotation = character(),
      annotation_tabix = character(),
      annotation_index = character(),
      genome = character(),
      genome_2bit = character(),
      aliases = character(),
      icon = character(),
      kingdom = character(),
      stringsAsFactors = FALSE
    )
  }

  if (nrow(out) > 0) {
    out <- out[!duplicated(out$annotation), , drop = FALSE]
    # Ensure species_id uniqueness
    if (anyDuplicated(out$species_id)) {
      seen <- list()
      out$species_id <- vapply(seq_len(nrow(out)), function(i) {
        sid <- to_species_id(out$species_id[i])
        n <- seen[[sid]] %||% 0L
        seen[[sid]] <<- n + 1L
        if (n == 0L) sid else paste0(sid, "_", n + 1L)
      }, character(1))
    }
    out <- out[order(tolower(out$organism), tolower(out$annotation)), , drop = FALSE]
  }
  rownames(out) <- NULL
  out
}

genome_registry_new <- build_genome_registry()
anno_registry_new <- build_annotation_registry(genome_registry_new)

cat(sprintf("Scanned genome files: %d\n", length(genome_files)))
cat(sprintf("Scanned annotation files: %d\n", length(annotation_files)))
cat(sprintf("Generated genome registry rows: %d\n", nrow(genome_registry_new)))
cat(sprintf("Generated annotation registry rows: %d\n", nrow(anno_registry_new)))
cat(sprintf("Mode: %s\n", ifelse(keep_existing, "merge-existing", "clean-rebuild")))

if (!write_mode) {
  cat("\nDry-run mode (no files written). Use --write to save.\n\n")
  cat("Genome registry preview:\n")
  print(utils::head(genome_registry_new, 10))
  cat("\nAnnotation registry preview:\n")
  print(utils::head(anno_registry_new, 10))
  quit(save = "no", status = 0)
}

if (!dir.exists(genomes_dir)) dir.create(genomes_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(annotations_dir)) dir.create(annotations_dir, recursive = TRUE, showWarnings = FALSE)

write.table(genome_registry_new, file = genome_registry_path, sep = "\t", quote = FALSE, row.names = FALSE, na = "")
write.table(anno_registry_new, file = anno_registry_path, sep = "\t", quote = FALSE, row.names = FALSE, na = "")

cat("\nUpdated files:\n")
cat(" - ", genome_registry_path, "\n", sep = "")
cat(" - ", anno_registry_path, "\n", sep = "")
