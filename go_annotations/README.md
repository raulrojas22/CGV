# GO Annotations

Put GO annotation files (`.gaf` or `.gaf.gz`) in `go_annotations/raw/`.

You do not need to rename files. Both naming styles are supported:

- NCBI-like: `GCF_XXXXXXXXX.Y_*_gene_ontology.gaf.gz`
- GO Consortium-like: `fb.gaf.gz`, `zfin.gaf.gz`, `goa_human.gaf.gz`, etc.

Build/update the GO registry:

```bash
Rscript scripts/build_go_registry.R --write
```

Or from any directory:

```bash
Rscript /Users/rarojas/Documents/A_FULLAPP/scripts/build_go_registry.R --write
```

This generates:

- `go_annotations/registry.tsv`

The script matches each GAF to a preloaded organism using:

1. `GCF` accession in file name
2. Taxon ID inside GAF rows (`taxon:####`)
3. Source alias fallback (for common GO file names)

Recommended workflow:

1. Copy GAF files into `go_annotations/raw/`
2. Build the SQLite indexes:

```bash
Rscript scripts/build_gaf_index.R --root=. --all --write-registry
Rscript scripts/verify_gaf_indexes.R --root=. --expected=24
```

3. Run the registry builder when organism mappings change
4. Review `go_annotations/registry.tsv` and check rows with empty `species_id` or `notes`

The generated `go_annotations/index/*.go.sqlite` files contain normalized GAF
columns and indexed lookups by object ID and symbol. Downloadable Desktop
datasets should include their corresponding SQLite file. If an older or
external dataset has no packaged index, CGV returns the first result using the
streaming fallback and builds an index later under `CGV_CACHE_DIR/go_index`.

Optional (recommended): local GO term names

To show textual names for GO IDs (not only `GO:xxxxxxx`) in the app popup, place an ontology file here:

- `go_annotations/go-basic.obo` (or `go-basic.obo.gz`)
- Official source: `https://current.geneontology.org/ontology/go-basic.obo`

You can prebuild the fast lookup cache:

```bash
Rscript scripts/build_go_term_map.R --obo=go_annotations/go-basic.obo --out=go_annotations/go_term_map.rds
```

Or auto-download and build in one step:

```bash
Rscript scripts/build_go_term_map.R --download --obo=go_annotations/go-basic.obo --out=go_annotations/go_term_map.rds
```

The app will also build this cache automatically on first GO popup use if the OBO file exists.
