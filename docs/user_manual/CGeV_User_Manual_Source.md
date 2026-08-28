# CGeV User Manual

## Comparative Gene Viewer

**Web and Desktop Edition**

Version {{MANUAL_VERSION}}

Revision: {{REVISION_DISPLAY}}

Comparative Gene Viewer (CGeV) brings gene search, transcript visualization, comparative alignment, functional context, analytics, and publication export into one workspace. This manual describes the complete user-facing workflow in CGeV Web and CGeV Desktop.

---PAGE---

# About this manual

## Purpose

This manual is written for researchers, students, instructors, and technical users who want to use CGeV without first learning its implementation details. It explains what each major control does, when to use it, how to interpret the result, and how to preserve or export the analysis.

The procedures apply to both CGeV Web and CGeV Desktop unless a section is marked **Desktop only**. The scientific interface is shared by both editions. Desktop adds a private local runtime, persistent local data storage, an organism catalog, and operating-system integration.

## Product scope

CGeV is designed for gene-centered structural and comparative analysis. It is especially useful for:

- comparing several annotated genes within one organism;
- comparing one gene across several organisms;
- inspecting gene, transcript, exon, CDS, UTR, intron, and neighboring-gene structure;
- comparing transcript isoforms and cross-species structural relationships;
- examining local sequence conservation with aligned synteny, LASTZ blocks, and MultiPIP;
- reviewing gene metrics, sequence composition, Gene Ontology annotations, functional summaries, literature, and protein interaction context;
- exporting figures, tables, sequences, and reproducible work sessions;
- sharing immutable interactive read-only reports by secret URL in CGeV Web or self-contained HTML in CGeV Desktop.

CGeV is not a replacement for differential-expression analysis, variant calling, genome assembly, whole-genome browsing, phylogenetic inference, population-genetic analysis, protein 3D prediction, or clinical interpretation.

> IMPORTANT: CGeV displays and analyzes the annotations and assemblies supplied by the selected data source. A missing feature can reflect the source annotation rather than the biological absence of that feature.

## Conventions

- **Bold text** identifies labels that appear in the CGeV interface.
- `Monospace text` identifies file types, file names, identifiers, or literal values.
- Numbered steps are actions to perform in order.
- A note explains behavior that affects interpretation or reproducibility.
- A tip recommends an efficient working practice.
- Organism names are written using their scientific names where possible.

## Terms used throughout the manual

**Multi-Gene Search** means several gene queries within one selected organism. **Cross-Species Gene Search** means one target gene resolved across several selected organisms. A **canonical card** is the primary displayed transcript record for a gene. An **isoform card** is an additional transcript record revealed from the canonical card. A **result card** contains a header, an interactive gene model, and a footer with statistics and analysis actions.

---PAGE---

# 1. CGeV at a glance

CGeV follows a consistent analysis path regardless of the data source or search mode.

[[WORKFLOW_DIAGRAM]]

## Choose the correct search mode

| Research question | Use | Query pattern | Typical result |
|---|---|---|---|
| How do several genes differ in one organism? | Multi-Gene Search | Multiple genes, one organism | One or more gene and transcript cards per query |
| How do transcript isoforms of one gene differ? | Multi-Gene Search | One gene with multiple transcripts | Canonical card, expandable isoform cards, transcript alignment |
| How does one gene compare across species? | Cross-Species Gene Search | One gene, multiple organisms | Representative cards by organism and comparative views |
| Where are conserved local sequence blocks? | Cross-Species Gene Search | One gene, multiple genomes | LASTZ Blocks or MultiPIP |
| Do I need every family member in one organism? | Multi-Gene Search | Add the family members as a batch | Within-organism family comparison |

> NOTE: Cross-Species Gene Search resolves the selected target across organisms. It is not a complete inventory of every related family member present in each organism.

## The first ten minutes

1. Open **Multi-Gene Search** or **Cross-Species Gene Search** from the left sidebar.
2. Select a data source: **Preloaded organism**, **NCBI Search**, **Upload files**, or, in Cross-Species Search, **Mixed sources**.
3. Select the organism or organisms.
4. Enter a gene symbol, stable identifier, or recognized alias in the sidebar search.
5. In Multi-Gene Search, add more genes to the batch if required.
6. Select **Generate visualization**.
7. Inspect the result cards in **Compact** or **Detailed** view.
8. Open **Show Summary Table** and **Show Analytics** for structured comparisons.
9. Use card actions for function, network, GO, external records, charts, literature, or sequence download.
10. Export the required figures and tables, save the work session from **Settings**, or use **Share** to create an interactive report for other readers.

## A recommended working pattern

- Begin with **Compact** view to verify that the intended genes and organisms were resolved.
- Expand transcript isoforms only for genes that require transcript-level interpretation.
- Switch to **Detailed** view before documenting feature-level conclusions.
- Use alignment views after verifying the underlying transcript structures.
- Save a session before making a major source, organism, or layout change.
- Export SVG for editable publication graphics and CSV for auditable supporting data.

---PAGE---

# 2. Interface tour

[[INTERFACE_MAP]]

[[SCREENSHOT_INTERFACE]]

## 2.1 Left sidebar

The sidebar is the primary navigation and search surface.

| Item | Purpose |
|---|---|
| **Home** | Product overview, workflow orientation, scope, troubleshooting, and FAQ |
| **Multi-Gene Search** | Configure one organism and one or more gene queries |
| **Cross-Species Gene Search** | Configure several organisms and one shared gene query |
| **Figure Studio** | Assemble available CGeV charts into a multi-panel publication figure |
| **CGeV Guide** | Follow the video-based step-by-step learning routes |
| **Settings** | Configure appearance, deletion confirmation, quick actions, alias sources, organisms, and sessions |
| **Feedback** | Submit a bug report or feature suggestion |
| **CGeV Desktop** | Review desktop capabilities and obtain the appropriate installer |

Select the triangle control in the CGeV brand area to collapse or expand the sidebar. The collapsed sidebar keeps the main navigation accessible and provides a compact gene-search panel.

## 2.2 Workflow configuration panels

Selecting a search workflow expands its configuration panel.

**Multi-Gene Search** contains:

- a data-source selector;
- a single-organism selector or source-specific controls;
- annotation and genome uploads;
- optional assembly-report, assembly-statistics, and GO-annotation uploads;
- NCBI organism search when that source is selected.

**Cross-Species Gene Search** contains:

- a data-source selector with **Mixed sources**;
- a multiple-organism selector;
- multi-file annotation and genome uploads;
- optional assembly and GO files for multiple organisms;
- an NCBI search queue for adding several assemblies.

## 2.3 Global search and gene batches

The search box changes its meaning with the active workflow:

- in Multi-Gene Search it accepts one gene or a batch;
- in Cross-Species Gene Search it focuses on one target gene.

Autocomplete suggestions are drawn from the selected local annotations. Choose a suggestion when possible to preserve the exact identifier spelling used by the source.

To build a Multi-Gene batch:

1. Type a gene.
2. Press **Space** or **Ctrl+Enter**, or select the add control.
3. Repeat for each gene.
4. Review the chips in the batch list.
5. Remove an individual chip if necessary, or use **Clear** to reset the batch.
6. Select **Generate visualization**.

CGeV keeps unique entries and limits a single submitted batch to 24 genes for a stable interactive session. If a larger list is supplied, the first 24 unique genes are used.

## 2.4 Notification history and progress

The bell in the context header opens notification history. It collects search, download, alignment, warning, and completion messages that may otherwise disappear after a short notification. Use **Clear** in the status popup to empty the history.

Long operations display a working state. The interface remains usable while background alias resolution, cache preparation, deferred plot work, or supported external lookups complete.

LASTZ and MultiPIP runs, including automatic reference scoring, open the status
popup automatically with a patience notice, current progress, and elapsed time.
Keep CGeV open until the run finishes. The transient working popup closes when
the active run ends, and the completion or failure notice remains available in
notification history.

## 2.5 Result context header

After data are loaded, the context header identifies:

- the active search type;
- selected organisms;
- the current gene or gene batch;
- whether CGeV is in visualization or alignment mode;
- the active visual detail level.

The header provides **Visualize mode** and **Alignment mode**. Under Visualize mode, choose **Compact** or **Detailed**. Alignment choices depend on the workflow and loaded data.

Visualize mode also provides three independent context controls:

- **Scale** shows or hides genomic coordinates and the compressed
  neighbor-distance scale;
- **Neighbors** shows or hides the nearest flanking genes;
- **Overlaps** shows or hides genes that overlap the displayed locus.

These controls change presentation only. Their state is retained for the
current browser or desktop session and is applied to newly rendered cards.

## 2.6 Summary, analytics, sorting, and zoom

The toolbar above the result cards contains:

- **Show Summary Table** or **Hide Summary Table**;
- **Download CSV**;
- **Show Analytics** or **Hide Analytics**;
- batch SVG export controls;
- **Sort plots**;
- plot zoom controls.

Zoom changes the horizontal display scale of the interactive plot cards without changing the biological coordinates. Sorting changes presentation order, not the data or alignment calculation.

## 2.7 Share analysis

The unobtrusive **Share** action in the active result header appears after CGeV
has at least one result. In CGeV Web it creates an expiring secret read-only URL.
In CGeV Desktop the same action prepares a self-contained interactive HTML file
and reproducibility ZIP without uploading the analysis. See Sections 11.10 and
11.11 for privacy, contents, and reproducibility details.

## 2.8 Quick navigation button

When enabled in **Settings**, the floating quick-actions button provides:

- gene search and batch preview;
- Compact, Detailed, and alignment-mode switching;
- plot zoom;
- a scroll-to-top control when the page is away from the top.

This control is useful on long result pages. It does not replace the full workflow configuration panel.

---PAGE---

# 3. Data sources and input requirements

## 3.1 Preloaded references

Preloaded references combine an indexed annotation with a matching genome assembly. They provide the fastest route to all CGeV capabilities, including feature tooltips, sequence composition, FASTA export, promoter extraction, and local alignment.

In CGeV Web, the server determines which references are available. In CGeV Desktop, references installed from the organism catalog appear in the same **Preloaded organism** selectors.

Select the information icon beside an organism selection to review assembly metadata and statistics. Where organism imagery is available, CGeV can also display licensed organism photographs with their source attribution.

## 3.2 NCBI Search

Use NCBI Search when the required assembly is not in the preloaded set.

1. Select **NCBI Search** as the data source.
2. Enter a scientific name, common name, or assembly-oriented search phrase.
3. Select the search icon.
4. Review matching assemblies and inspect the available accession, assembly name, level, and statistics.
5. Select the intended assembly.
6. Allow CGeV to download and prepare the annotation, genome, assembly report, and assembly statistics.
7. Continue with the gene search after the source status reports readiness.

For Cross-Species Search, repeat the NCBI search to build the organism queue.

> IMPORTANT: Different assemblies of the same organism may contain different coordinates, contig names, transcript versions, and annotation content. Record the assembly accession used in every reported result.

## 3.3 Upload files

Upload mode accepts user-supplied annotation and genome files.

### Required files

| Data | Accepted formats | Purpose |
|---|---|---|
| Annotation | `.gff`, `.gff3`, `.gtf`, `.txt` | Defines genes, transcripts, exons, CDS, UTR, and related features |
| Genome | `.fa`, `.fasta`, `.fna`, gzip-compressed FASTA, `.2bit` | Supports sequence composition, FASTA export, promoter extraction, and local alignment |

### Optional files

| File | Accepted formats | Added capability |
|---|---|---|
| Assembly report | `.txt` | Assembly accessions, names, aliases, chromosome mapping, and metadata |
| Assembly statistics | `.txt` | Assembly-level size and contiguity statistics |
| GO annotations | `.gaf`, `.gaf.gz` | Local Gene Ontology lookup |

### Single-organism upload

For Multi-Gene Search, upload one annotation and one matching genome. Optional files must describe the same assembly.

### Multi-organism upload

For Cross-Species Search, upload one annotation and one genome per organism. CGeV pairs them by shared sequence identifiers and file-name evidence. Use clear, matching names and ensure chromosome or contig identifiers agree between each annotation and genome.

If CGeV cannot establish a confident pairing, rename the files more clearly or verify that the genome build and sequence identifiers match.

## 3.4 Mixed sources

**Mixed sources** is available in Cross-Species Search. It combines:

- preloaded references;
- NCBI-prepared assemblies;
- uploaded annotation and genome pairs.

Use it when no single source contains the full comparison set. Every selected organism is treated as an independent track, while the result header records its source status.

## 3.5 What works when a file is missing

| Available input | Expected behavior |
|---|---|
| Annotation and genome | Complete structural, sequence, promoter, alignment, and export workflow |
| Annotation only | Structural plots and annotation-derived metrics work; sequence-dependent values report N/A |
| Genome without annotation | Gene-centered plotting cannot begin because feature locations are not defined |
| Annotation and GO file | Local GO lookup is available |
| Annotation without GO file | GO can use the supported online fallback when a local record is unavailable |
| Assembly report and statistics | Assembly details and stronger chromosome naming are available |

## 3.6 Data provenance checklist

Before reporting a result, record:

- organism and taxonomic identifier;
- assembly accession and version;
- annotation source and version;
- gene query and resolved local identifier;
- transcript identifier;
- whether an external alias was used;
- CGeV search mode and visualization mode;
- alignment settings, when applicable;
- export date and CGeV version.

---PAGE---

# 4. Multi-Gene Search

## 4.1 When to use it

Use Multi-Gene Search when the comparison is centered on one organism. Suitable tasks include:

- comparing paralogs or members of a known family;
- comparing structural differences among selected genes;
- reviewing several loci from one experiment;
- examining alternative transcripts of one gene;
- aligning isoforms within one gene;
- comparing sequence and architecture metrics across a gene set.

## 4.2 Configure the source and organism

1. Select **Multi-Gene Search**.
2. Choose **Preloaded organism**, **NCBI Search**, or **Upload files**.
3. Select or prepare one organism.
4. Use the assembly information icon to confirm the expected build when precision matters.
5. Wait until the source panel reports readiness.

Changing organism after results exist prompts for confirmation because the current cards belong to the previous source. Save the session or export required results before replacing the source.

## 4.3 Enter one gene

1. Type a symbol, stable gene ID, transcript-oriented identifier, or alias.
2. Review autocomplete matches.
3. Select the exact record when it appears.
4. Select **Generate visualization** or press Enter.

CGeV first searches the local annotation and local alias index. If the query is not an exact local match, it can offer partial-name suggestions or consult the external alias sources enabled in **Settings**.

## 4.4 Enter a gene batch

1. Type the first query.
2. Press Space or Ctrl+Enter to turn it into a chip.
3. Continue until the batch list contains the intended genes.
4. Review the batch count.
5. Select **Generate visualization**.

The search processes the batch in sequence and preserves successful plots. On completion, the notification history reports:

- genes plotted;
- genes not found;
- records without usable transcript structure;
- genes already plotted;
- search errors.

## 4.5 Resolve suggestions and ambiguous aliases

When no exact match exists, CGeV can show similar local gene names. Multi-Gene Search allows one or more suggestions to be selected and plotted.

When an alias maps to several records, the **Several Alias Matches** dialog displays:

- the official symbol or local identifier;
- chromosome, coordinates, and strand;
- the alias or match role;
- the evidence source and confidence;
- a description when available;
- a recommended match when the evidence supports one.

Select only records that match the biological question. The **Alias** badge in a result card reopens the evidence used for the resolved record.

## 4.6 Review the first result

After the cards appear:

1. Confirm the organism, gene, transcript, and chromosome in the card header.
2. Hover the central gene model and its features.
3. Check strand direction and coordinates.
4. Review neighboring genes and the promoter-side indicator.
5. Check the footer for gene length, transcript length, sequence composition, and coordinates.
6. Expand the transcript control if multiple transcripts are available.

## 4.7 Choose a visual mode

**Compact** emphasizes the principal transcript structure and is best for dense comparisons.

**Detailed** exposes feature-level layers and richer tooltips. Use it to distinguish exon, CDS, UTR, intron, and other annotated elements.

**Synteny** compares transcripts belonging to one loaded gene. It is the only
alignment method in Multi-Gene Search and becomes available when at least one
selected gene has multiple transcript tracks. LASTZ Blocks and MultiPIP are
available only in Cross-Species Search.

## 4.8 Sort and compare

Multi-Gene result cards can be sorted by:

- load order;
- total exon difference, high to low or low to high;
- transcript length;
- exon count;
- transcript name;
- chromosome.

Use the summary table for exact values and the cards for structural inspection. Sorting does not redefine the reference transcript or recalculate the underlying gene data.

## 4.9 Expand transcript isoforms

Canonical cards show a transcript-count control when additional isoforms are available.

1. Select the transcript-count control in the card footer.
2. Review the canonical copy and additional transcript cards shown below the gene.
3. Compare transcript-specific coordinates, length, composition, and charts.
4. Select the control again to collapse the group.

Isoform cards use transcript-level **Info** and **Charts** views. The canonical gene card retains the gene-wide information and literature actions.

## 4.10 Multi-gene alignment

Select **Aligned** when a loaded gene has at least two transcript tracks.

Controls include:

- **Gene to align** - chooses the multi-transcript gene;
- **Alignment mode** - Translated CDS, CDS nucleotide, or Full exon with UTRs;
- **Transcript order** - loaded order, reverse order, or transcript label;
- **Min. block identity** - hides ribbons below the selected threshold.

Translated CDS is the preferred starting point for protein-coding isoforms. CDS nucleotide keeps the coding comparison in nucleotide space. Full exon includes UTR extent and is useful for transcript-architecture differences.

## 4.11 Multi-gene LASTZ and MultiPIP

These modes compare transcripts from the selected gene using the canonical transcript as reference whenever it is available.

Configure:

- the gene to align;
- the alignment window: gene body, or the gene plus 5, 10, or 25 kb;
- minimum identity;
- minimum block or segment size;
- **Run local alignments**.

Use LASTZ Blocks to inspect discrete local matches. Use MultiPIP to inspect a reference-centered conservation profile. Export either view as SVG.

---PAGE---

# 5. Cross-Species Gene Search

## 5.1 When to use it

Use Cross-Species Gene Search to compare a selected gene across organisms. Typical questions include:

- whether a gene is represented in several selected annotations;
- how representative transcript structures differ;
- which exon-level relationships are conserved;
- where local genomic sequence remains similar;
- how gene metrics vary across organism tracks.

## 5.2 Build the organism set

1. Select **Cross-Species Gene Search**.
2. Choose **Preloaded organisms**, **NCBI Search**, **Upload files**, or **Mixed sources**.
3. Add at least two organisms.
4. Confirm each assembly and source.
5. For uploads, verify annotation-genome pairing.

The organism selector allows multiple entries. In Desktop, only installed references appear as preloaded selections.

[[SCREENSHOT_CROSS_SPECIES]]

## 5.3 Search one target gene

1. Enter one gene symbol, stable identifier, or known alias.
2. Select an autocomplete suggestion when available.
3. Select **Generate visualization**.

CGeV checks each organism independently. A direct local match is used first. If no local match is found, enabled alias services can resolve alternate nomenclature in the background.

The context header marks organism states such as:

- local match;
- match recovered through external alias evidence;
- external search in progress;
- no match in the current annotation.

Select **About results** in the Cross-Species context header to review the
comparison scope. CGeV displays the selected gene when the same name or a
resolved alias is available in at least two selected organisms. Additional
family members found only within one organism are not added to this result; use
Multi-Gene Search to explore those genes within that organism.

## 5.4 Interpret partial availability

Cross-species results may contain fewer cards than selected organisms. Common reasons include:

- the gene is absent from the annotation;
- the organism uses a different symbol or stable identifier;
- the assembly or annotation version differs from the expected record;
- no transcript structure is available;
- external alias evidence is insufficient or ambiguous.

Use the notification history and organism status pills to distinguish these cases. A missing card should be reported as "not resolved in the selected source" rather than as biological absence unless the source annotation has been independently verified.

## 5.5 Resolve suggestions

If no exact cross-species match is available, CGeV can suggest similar genes shared by the selected annotations. Select one exact suggestion to rerun the comparison. Cross-species results require a usable match in at least two organisms.

If nomenclature differs strongly across species, select the external-alias option and review the resulting evidence badges.

## 5.6 Compact and Detailed views

Compact view is appropriate for a first pass across many organisms. Detailed view is appropriate for feature-level inspection.

Before alignment:

1. verify the representative gene and transcript label for each organism;
2. check strand, coordinates, and chromosome;
3. inspect expanded isoforms where they affect interpretation;
4. identify any source or alias badges;
5. confirm that genome sequence is available for alignment-oriented work.

## 5.7 Comparative Aligned Synteny

**Aligned synteny** compares transcript structures in a common left-to-right 5' to 3' display.

Controls include:

- **Alignment mode** - Translated CDS, CDS nucleotide, or Full exon with UTRs;
- alignment anchor/reference selection;
- **Track order** - biological similarity chain, load order, organism name, reverse order, or manual drag order;
- **Min. block identity**.

Ribbons indicate structural correspondence between adjacent displayed tracks. Hover a ribbon to review identity, support length, GC context, and mapping-event details.

## 5.8 LASTZ Block View

LASTZ Block View aligns every selected query locus against a reference locus.

Controls include:

- reference organism or track;
- **Alignment window** - gene body, or gene plus 5, 10, 25, or 50 kb;
- track order;
- minimum block length: 50, 100, 250, or 500 bp;
- minimum local identity;
- **Run local alignments**.

After the run, CGeV evaluates the selected reference using the same alignments already displayed: supported organisms, reference-window coverage, weighted identity, and reduced block count. It does not run an all-against-all reference search.

The full genomic window is used, including introns and selected flanking sequence. Conserved blocks outside the transcribed region can therefore represent non-coding regulatory context, but they require independent biological validation.

## 5.9 MultiPIP-style View

MultiPIP presents reference-centered conservation across the organism set. Configure:

- reference track;
- alignment window;
- track order;
- minimum segment length: 10, 25, 50, or 100 bp;
- minimum local identity;
- **Run local alignments**.

LASTZ Block View and MultiPIP reuse one canonical LASTZ result when the reference, loci, window, and engine inputs are unchanged. Identity and length filters reinterpret that result without rerunning LASTZ; changing the alignment window creates a new exact alignment. Switching between the two views therefore does not repeat the alignment when their windows match.

Use the view to identify conserved intervals that recur across several organisms. It summarizes local alignment support; it is not a multiple-sequence alignment for phylogenetic inference.

## 5.10 Reference selection

Choose a biologically meaningful, well-annotated reference with a complete genome sequence. Run the selected reference once and inspect the resulting support metrics before interpreting the visualization. The choice affects projection and visual order, so record it with exported results. CGeV deliberately avoids testing every organism as a candidate reference because that all-against-all sweep scales quadratically and can consume substantial CPU.

## 5.11 Sort cross-species cards

Cards can be sorted by:

- load order;
- total exon difference;
- transcript length;
- exon count;
- organism name;
- transcript name.

Use organism-name sorting for a predictable report layout. Use exon-difference or transcript-length sorting to foreground structural outliers.

---PAGE---

# 6. Reading a result card

## 6.1 Card header

The header identifies the current organism, gene, chromosome, and transcript context. It can also show chromosome mapping or alias evidence.

Header controls include:

| Control | Action |
|---|---|
| **Function** | Opens a gene-function summary from local annotation or NCBI Gene |
| **Network** | Opens the interactive STRING protein-interaction network |
| **GO** | Opens local GO annotations and supported online fallback |
| **NCBI** | Opens the exact GeneID or an organism-aware NCBI Gene search |
| **Ensembl** | Opens the relevant Ensembl portal search, including plant or fungal portals |
| **UniProt** | Opens a gene, protein-name, and organism-aware UniProt search |
| **Alias** | Displays the local or external alias evidence used to resolve the query |
| **SVG** | Exports the current structural plot as editable SVG |
| **Download FASTA** | Opens the Gene, Transcript, CDS, and Introns sequence menu |
| Close icon | Removes the current card after confirmation when enabled |

External links open outside the CGeV application. In Desktop they open in the default system browser.

[[SCREENSHOT_RESULT_CARD]]

## 6.2 Interactive gene model

The central model may contain:

- a gene or transcript backbone;
- exon blocks;
- CDS blocks;
- UTR features;
- inferred intron intervals;
- other annotated RNA or transcript features;
- strand-direction arrows;
- chromosome coordinates;
- neighboring genes and distances;
- promoter-side connector.

Hover over an interactive feature to inspect its type, coordinates, length, identifiers, attributes, and GC content where sequence is available.

Select a neighboring-gene marker or overlap band to open its context popup. The
popup identifies the relation to the current gene, genomic coordinates, and
strand. In Multi-Gene Search, **Visualize [gene] below** adds that neighbor as a
new result card. In Cross-Species Search, neighbors remain genomic context
only; adding one as a result is intentionally available only through
Multi-Gene Search.

## 6.3 Compact and Detailed feature behavior

Compact view reduces the number of visible layers and uses combined structural regions. Detailed view displays more annotation layers and attribute-rich tooltips.

Use Detailed view before concluding that a region is coding or untranslated. A visually similar block can represent a different feature type in a source with incomplete or nonstandard annotation.

## 6.4 Strand and orientation

The central transcript is displayed in its biological orientation. Neighbor context and promoter direction follow the annotated strand. A negative-strand gene has its upstream promoter region on the higher-coordinate side.

Alignment modes normalize tracks into left-to-right transcript order. Their x-axis is comparative transcript space, not raw genomic coordinates.

## 6.5 Genomic context scale, neighbors, and overlaps

The solid center of the **Scale** is a linear chromosome or sequence axis for
the displayed gene interval. Its labels use bp, kb, or Mb according to the
span. Hover the line, ticks, or labels to inspect exact positions.

The dashed side sections place the nearest flanking genes on a compressed
distance scale. Break marks separate these logarithmically compressed side
sections from the linear gene interval. The side ticks show 100 bp, 1 kb,
10 kb, and at least 100 kb reference distances.

Overlapping genes are drawn as bands across the locus. Multiple overlaps can
use separate lanes and a combined label. Use the marker popup or tooltip for
the exact relation and overlap length; do not estimate a side distance from
screen width because the neighboring-gene sections are compressed.

Use **Scale**, **Neighbors**, and **Overlaps** in the result context header to
show or hide these layers independently. Hiding a layer does not change the
annotation, coordinates, summary, or analysis.

## 6.6 Promoter region

The dashed promoter-side connector is interactive.

1. Select the promoter region.
2. Enter or slide to the required upstream length.
3. Choose a value from 100 to 5,000 bp in 10 bp increments. The default is 1,000 bp.
4. Select **Download promoter region**.

CGeV extracts the strand-aware upstream interval and downloads it as FASTA. Coordinates are clipped to the sequence boundary when necessary.

> NOTE: "Promoter region" in this tool means a configurable upstream sequence window. It does not assert experimentally validated promoter activity.

## 6.7 Card footer

The footer can be horizontally scrolled and provides:

- transcript count and isoform expansion;
- gene and transcript lengths;
- nucleotide composition;
- gene or transcript coordinates;
- **Info**;
- **Charts**;
- **Literature** on canonical gene cards.

Footer arrows appear when the available width cannot show all items.

## 6.8 Info popup

On a canonical gene card, **Info** opens gene statistics. On an isoform card it opens transcript information. Depending on the record, sections can include:

- gene summary;
- current transcript;
- architecture and feature counts;
- sequence metrics;
- neighboring-gene context;
- coordinate and strand information.

## 6.9 Charts popup

Canonical gene cards provide gene and isoform chart groups. Transcript cards provide transcript-oriented charts.

Transcript charts include:

- structure composition;
- intron map;
- nucleotide composition.

Gene and isoform charts include:

- transcript isoform length comparison;
- gene architecture by isoform;
- exonic and intronic base-pair comparison;
- sequence composition;
- gene-versus-transcript context;
- exon-length distribution;
- intron-length distribution.

Each chart has an information control and SVG export.

## 6.10 Removing results

Use the close icon on a card to remove only that result. Use **Clear visualizations** in the sidebar to remove all active cards. When **Confirm before deleting** is enabled, CGeV asks before destructive workspace actions.

Removing a card changes the summary table, analytics set, and Figure Studio availability. Export or save the session first if the result may be needed again.

---PAGE---

# 7. Alignment and conservation views

## 7.1 Select the view that answers the question

| View | Best for | Coordinate basis | Primary evidence |
|---|---|---|---|
| Compact | Rapid structural overview | Genomic/transcript model | Annotation |
| Detailed | Feature-level inspection | Genomic/transcript model | Annotation |
| Aligned synteny | Structural correspondence | Normalized 5' to 3' transcript space | Annotation and aligned blocks |
| LASTZ Blocks | Discrete local sequence similarity | Reference genomic window | Local sequence alignment |
| MultiPIP | Reference-centered conservation pattern | Reference genomic window | Filtered local alignment segments |

## 7.2 Aligned-synteny mapping events

CGeV uses visual event categories read from each upper track to the next lower
track:

- **1:1 direct (blue, solid)** - one upper block corresponds preferentially to
  one lower block;
- **1:n split (teal, dashed)** - one upper block maps to several lower blocks;
- **n:1 merge (violet, dash-dot)** - several upper blocks map to one lower
  block;
- **partial or ambiguous (grey, dotted)** - support is divided or does not form
  a clean direct, split, or merge mapping.

Here **n means several blocks**, not a sequence-identity score. Ribbon color
encodes the mapping category; identity percentage is shown in the ribbon
tooltip and controlled by the minimum-identity filter.

Feature boxes use a separate color language. In the default palette, red/pink
marks exon extent, gold/yellow marks CDS, cyan/blue marks UTR, and grey marks
the gene span. These feature colors do not mean low, medium, or high identity
and do not indicate an error or warning.

The ribbon tooltip is the authoritative source for the event label, identity, and support. Ribbon width and curvature are visual aids and should not be treated as independent quantitative measures.

## 7.3 Alignment modes

**Translated CDS** compares coding blocks in protein-oriented space when CDS features are available. It is robust to synonymous nucleotide differences and is the recommended first choice for protein-coding genes.

**CDS nucleotide** uses coding-sequence nucleotides. It is useful for closely related coding sequences or when nucleotide-level differences matter.

**Full exon (+ UTRs)** includes exon geometry and untranslated extent. Use it for transcript-architecture questions and UTR differences.

When a transcript lacks CDS, CGeV can fall back to exon geometry so the track remains interpretable. Report such tracks separately from complete protein-coding comparisons.

## 7.4 Identity thresholds

Increasing the minimum identity removes weaker ribbons, blocks, or segments from view. It does not change the annotation.

- Use a low threshold for exploratory comparison across distant organisms.
- Use a moderate threshold to reduce visual noise.
- Use a high threshold when the question specifically concerns strong conservation.

Always report the threshold used. A visually empty track at a high threshold does not imply that no relationship exists.

## 7.5 Alignment windows

**Gene body only** restricts local alignment to the transcribed locus window.

Flanking-window options add sequence on both sides of the gene. They are useful for:

- promoter and proximal-regulatory comparison;
- identifying conserved non-coding intervals;
- observing boundary-spanning blocks.

Larger windows increase runtime and the number of candidate local matches.

## 7.6 Track order

Track order affects which adjacent tracks are connected in a ribbon view and how quickly a reader can recognize patterns.

- **Biological chain** places similar tracks near one another.
- **Loaded order** preserves the original selection order.
- **Organism A-Z** produces a stable reference layout.
- **Reverse current** reverses the current display.
- **Manual** allows drag-based arrangement.

Track order is a presentation choice unless the view explicitly recalculates adjacent correspondence. Record non-default ordering with the exported figure.

## 7.7 Local alignment execution

Select **Run local alignments** after changing reference, window, or other parameters. CGeV reports the run state and raw hit count in the view footer.

Because LASTZ is computationally intensive, the notification popup opens
automatically during LASTZ Blocks, MultiPIP, and reference-scoring runs. It
shows progress and elapsed time. Keep CGeV open and wait for the completion
message before changing the source or closing Desktop.

If the local engine reports unavailable sequence:

- confirm that each organism has a genome file;
- confirm that annotation sequence identifiers match the genome;
- verify that the selected coordinates exist;
- reduce the organism set to isolate the problematic source.

If CGeV reports a safety timeout or a locus window that is too large, select a
smaller alignment window and retry. Completed results remain available even
when another query track fails.

## 7.8 Sequence export from alignment views

Aligned-synteny, LASTZ, and MultiPIP cards provide **Download sequences**. The export contains the reference and displayed query sequences for the active comparison context. Use the exported headers to preserve organism, gene, sequence identifier, interval, and role.

## 7.9 Interpretation limits

Alignment views provide evidence of structural or local sequence similarity. They do not, by themselves, establish orthology, conserved regulation, functional equivalence, evolutionary direction, or statistical significance.

Combine CGeV results with curated orthology, phylogenetic analysis, experimental evidence, and source-specific annotation review where those conclusions are required.

---PAGE---

# 8. Summary tables and analytics

## 8.1 Summary table

Select **Show Summary Table** to inspect a searchable, sortable table behind the current cards. The table includes record labels and metrics such as:

- organism;
- gene and transcript identifiers;
- chromosome and strand;
- gene and transcript coordinates;
- gene and transcript length;
- exon and intron counts;
- exonic, intronic, CDS, and UTR measures;
- sequence composition and GC percentage;
- neighboring-gene distances where available.

Select **Download CSV** to preserve the current summary. The CSV is the preferred source for exact numeric reporting.

## 8.2 Opening analytics

Select **Show Analytics** after generating results. Analytics use the currently active card set. Removing cards or changing sources changes the comparison population.

Every analytics tab provides:

- an interactive chart;
- hover details;
- an information control explaining axes and interpretation;
- a chart-specific ordering selector;
- single-chart SVG export.

The **SVG ZIP** action exports the available analytics charts as a batch.

[[SCREENSHOT_ANALYTICS]]

## 8.3 Gene Architecture

The stacked bar displays CDS, UTR, and intronic base-pair composition.

Use it to compare:

- total gene size;
- coding proportion;
- UTR contribution;
- intronic contribution.

Longer bars indicate larger genes. Similar total length can conceal different structural composition, so inspect the segments and tooltip values.

## 8.4 Exons / Introns

This view compares exon and intron counts together with exonic and intronic base pairs.

Use it to distinguish:

- many short features from a few long features;
- structurally compact genes from intron-rich genes;
- count differences from length differences.

Feature count is annotation-dependent and should not be interpreted as regulatory complexity without additional evidence.

## 8.5 Sequence

The sequence chart shows A, T, C, and G percentages and reports GC percentage.

Use it to compare broad nucleotide composition. N/A means the corresponding genome sequence could not be extracted; it does not represent zero content.

## 8.6 Genomic Context

The context chart shows edge-to-edge distances to the nearest upstream and downstream genes.

- Negative values indicate overlap.
- Zero or positive values indicate adjacency or a gap.
- Upstream and downstream panels define biological side; do not infer side from sign alone.

## 8.7 Exon Lengths

The exon distribution uses violin, box, and jitter layers on a log10 scale.

- the box represents the interquartile range;
- the line represents the median;
- dots represent individual exons;
- the violin represents the distribution shape.

## 8.8 Intron Lengths

The intron distribution shows inferred gaps between consecutive annotated exons. Single-exon transcripts are omitted. When no displayed transcript has introns, the chart provides an explicit no-intron message.

## 8.9 Scatter

The scatter plot compares GC percentage with gene length. Point encoding also supports interpretation of additional structural metrics such as exon count.

Use hover labels rather than estimating exact values from position. The chart is descriptive and does not imply causation.

## 8.10 Heatmap

The heatmap compares normalized gene metrics across the loaded set. It requires at least two usable records.

Values are scaled within the loaded comparison. A high color intensity means high relative to this set, not high relative to the organism or genome.

## 8.11 Radar

The radar chart compares six normalized metrics on a 0 to 1 scale. It is useful for visual profile comparison when at least two records have complete metrics.

Radar area should not be treated as a formal composite score. Compare individual axes and consult the summary table.

## 8.12 Correlations

The correlation matrix summarizes pairwise metric relationships. Base-pair and count metrics can be log10 transformed before correlation. Ordering options include default, alphabetical, mean absolute correlation, and clustered order.

Correlation requires enough complete records to be meaningful. Small gene sets can produce unstable or visually strong coefficients.

## 8.13 Analytics ordering

Ordering menus include load order, numeric high-to-low or low-to-high options, and label order. Ordering affects chart presentation only. For reproducible figures, keep the order visible in the exported caption or record it in the analysis notes.

## 8.14 Missing values

Analytics exclude or mark records that lack the required metric. Common causes are:

- unavailable genome sequence;
- incomplete transcript or exon annotation;
- no introns;
- no usable neighboring-gene record;
- insufficient records for a comparative statistic.

Do not replace N/A with zero unless the biological and computational meaning supports that decision.

---PAGE---

# 9. Functional and contextual tools

## 9.1 Gene Function Summary

Select **Function** on a result card.

CGeV first uses descriptions, notes, or products in the local annotation. When a local summary is unavailable and a resolvable NCBI Gene record exists, it retrieves and caches the NCBI Gene summary.

The dialog identifies:

- gene and transcript;
- chromosome;
- organism and TaxID;
- GeneID when available;
- annotation file;
- information source;
- search workflow.

Use the source label when citing or auditing the summary.

## 9.2 STRING Protein Network

Select **Network** to open an interactive protein-protein interaction network.

Visual roles are:

- red - target gene;
- orange - genes already displayed in CGeV;
- gray - additional STRING interactors.

Edge thickness reflects STRING combined confidence. Hover nodes and edges for details. Drag nodes, pan, use wheel zoom, navigation controls, keyboard controls, or double-click to refit the network.

Select **SVG** to export the current network.

> NOTE: STRING integrates several evidence channels, including experiments, curated databases, co-expression, text mining, genomic neighborhood, fusion, and co-occurrence. An edge is evidence of association, not necessarily direct physical binding.

## 9.3 Gene Ontology

Select **GO** to search GO annotations for the current gene and organism.

CGeV groups results into:

- Biological Process;
- Molecular Function;
- Cellular Component.

Local GAF data are used when available. If no local entry is resolved, select the online lookup action to query the supported MyGene.info fallback. The popup reports the source and can reveal additional terms with **Show more**.

GO terms describe curated or inferred annotations from the source. Check evidence codes and source records when evidence strength matters.

## 9.4 Scientific Literature

Select **Literature** on a canonical gene card. CGeV searches Europe PMC using the gene, known synonyms, organism, and organism aliases.

The literature window supports:

- sorting by most cited, newest, oldest, or relevance;
- client-side filtering by author, title, or journal;
- paged results;
- titles, authors, year, journal, abstract, citation count, and external record links.

Review the search context before treating the result list as exhaustive. Gene symbols that are common words or reused across taxa may need manual verification.

## 9.5 External database links

CGeV builds organism-aware links:

- NCBI uses a GeneID when available, otherwise a symbol-and-organism search;
- Ensembl selects the main, plant, fungal, protist, metazoan, or bacterial portal from organism context;
- UniProt combines gene symbol, protein product, and organism context.

The external site is responsible for the record shown after the link opens. Confirm that its assembly, species, and identifier match the CGeV card.

## 9.6 Assembly details

Select the information icon next to the preloaded organism selection or the organism pill in the result context.

Available details include:

- assembly name and description;
- organism and TaxID;
- BioSample and BioProject;
- submitter and release date;
- assembly type, level, and representation;
- RefSeq and GenBank accessions;
- assembly statistics;
- chromosome-name mapping;
- organism photographs and attribution when available.

Use assembly details to resolve chromosome aliases and to document the exact reference used.

## 9.7 Alias evidence

The **Alias** badge explains how the input query reached the plotted local record. It can show:

- input query;
- alias used;
- matched local symbol;
- local stable identifier;
- locally indexed aliases and their source database;
- alternate query variants reviewed.

This evidence is especially important when comparing species whose official nomenclature differs.

---PAGE---

# 10. Figure Studio

## 10.1 Purpose

Figure Studio assembles independent CGeV visualizations into a publication-ready multi-panel figure. It uses the SVG source of existing results and analytics, so the final composition remains vector-based when exported as SVG.

Open **Figure Studio** after generating the result charts that the figure requires.

[[SCREENSHOT_FIGURE_STUDIO]]

## 10.2 Publication toolbar

Configure:

- **Figure title**;
- optional subtitle;
- one, two, or three columns;
- **Figure style**;
- PNG size;
- preview and export.

Figure styles are:

- Full Color;
- Paper Color;
- Colorblind;
- Paper Gray;
- Paper Mono.

PNG size options are Screen, High, and Ultra. For editable publication work, SVG is the preferred master export.

## 10.3 Panel library

Choose a data context:

- Multi-Gene Search;
- Cross-Species Search.

Search the catalog by chart name. Available sources include:

- Gene architecture;
- Exons / introns;
- Sequence composition;
- Genomic context;
- Exon lengths;
- Intron lengths;
- GC vs gene length;
- Comparative heatmap;
- Comparative radar;
- Metric correlations;
- Aligned synteny;
- LASTZ blocks;
- MultiPIP;
- individual gene and transcript result plots.

Unavailable entries remain visible and explain which result or alignment must be generated first.

## 10.4 Add a panel

1. Select the required data context.
2. Locate a chart in the panel library.
3. Select **Add**.
4. Repeat for every panel.

> NOTE: Each selection creates one independent panel. The same source may be added more than once when different placement or labeling is required.

## 10.5 Edit a panel

Select a panel on the canvas. The inspector provides:

- panel title;
- chart-source readout;
- width of one, two, or three columns;
- Auto, Compact, Standard, or Tall height;
- show or hide panel label and title;
- move Earlier or Later;
- duplicate;
- remove.

Auto height preserves the source chart's proportions and adapts to the number of genes or transcripts. Use manual height only when deliberate compression improves the composition without reducing legibility.

## 10.6 Reorder and resize

Drag a panel to reorder it, or use **Earlier** and **Later**. Panel width is constrained by the selected figure-column count. If the figure changes from three columns to two, spans are reduced to fit the new grid.

## 10.7 Undo, redo, new, and clear

- **Undo** reverses the most recent studio edit.
- **Redo** reapplies the reversed edit.
- **New figure** resets title, subtitle, layout, style, and panels after confirmation.
- **Clear** removes every panel but leaves the underlying CGeV search results intact.
- **Back to results** returns to the scientific result page.

## 10.8 Preview

Select **Preview** to render the same composition used by export. Inspect:

- title and subtitle;
- panel labels;
- font and line legibility;
- panel order;
- empty or clipped areas;
- color profile;
- overall dimensions.

Export directly from the preview when the composition is correct.

## 10.9 Export

**Export SVG** creates the editable vector master with source metadata. **Export PNG** rasterizes the same composition at the selected scale. Very large figures are automatically constrained to a safe pixel count.

Keep the SVG even when a journal requests PNG or another raster format. It preserves editable text, paths, and panel structure.

## 10.10 Save the studio draft

The Figure Studio draft is temporary until the CGeV work session is exported. Saving a session records:

- figure title and subtitle;
- column count;
- style and PNG scale;
- panel order, size, and labels;
- source references.

When the session is restored, CGeV reconnects panels to their source results. If a source is missing, regenerate or restore that result and refresh the panel.

---PAGE---

# 11. Exporting and preserving work

[[EXPORT_MATRIX]]

## 11.1 Structural SVG

Use **SVG** in a result-card header to export one gene or transcript plot. SVG retains vector geometry and is appropriate for Inkscape, Illustrator, Affinity Designer, and compatible journal workflows.

## 11.2 Result SVG ZIP

Select **Download result SVGs (.zip)** to export all active structural plots in the current workflow. Expand required isoforms before export when they must be included.

## 11.3 Analytics SVG and SVG ZIP

Every analytics chart has an SVG action. Use **SVG ZIP** to export all available analytics charts for the active workflow.

## 11.4 Summary CSV

Select **Download CSV** above the summary table. Use CSV for exact numeric values, audit trails, supplemental tables, and downstream statistical work.

## 11.5 Sequence FASTA

The **Download FASTA** menu on a result card provides:

- **Gene** - strand-aware complete gene interval;
- **Transcript** - current transcript sequence;
- **CDS** - coding sequence assembled from CDS features;
- **Introns** - intronic intervals inferred from consecutive exons.

If the required genome or coordinates are unavailable, the export is disabled or contains only the resolvable context.

## 11.6 Promoter FASTA

Select the promoter-side region in the plot, choose 100 to 5,000 bp, and download the strand-aware upstream sequence.

## 11.7 Alignment sequences

Aligned-synteny, LASTZ, and MultiPIP cards export the sequences represented by the active reference and query configuration.

## 11.8 Figure Studio SVG and PNG

Use SVG as the editable master and PNG for presentation, review, or submission systems that require raster output.

## 11.9 Work-session RDS

Go to **Settings** and select **Export current session (.rds)**.

The session records:

- active navigation and preferred workflow;
- source modes and organism selections;
- Compact, Detailed, or alignment modes;
- sorting;
- enabled external alias services;
- summary visibility;
- search status and source context;
- active plots, plot data, metrics, and sequence blobs;
- query and batch state;
- Figure Studio draft.

To restore:

1. Open **Settings**.
2. Choose the saved `.rds` file.
3. Select **Restore session**.
4. Review the restored source and organism context.

Restoring replaces current visualizations.

> TIP: Save a session before changing organism, clearing results, or beginning a substantially different analysis.

## 11.10 Reproducible export set

Select the unobtrusive **Share** action in the active result header after
generating at least one result. CGeV prepares a versioned reproducibility
package. After the report is ready, select **Generate / download ZIP** to create
the archive containing:

- `analysis.json`, with CGeV version, workflows, queries, organisms, source
  provenance (assembly/annotation accession, version, source, and SHA-256
  checksum), alias decisions, parameters, unresolved organisms, and completed
  alignment metadata;
- a human-readable `README.md` and `CHECKSUMS.sha256`;
- a portable schema-v2 CGeV session;
- available summary CSV, completed LASTZ/MultiPIP TSV, and captured SVG files;
- FASTA only when private sequence inclusion is explicitly enabled.

Complete reference genomes are not copied into the package. CGeV records their
assembly and annotation provenance instead. When private sequences are
excluded, restored visualizations remain available but sequence-dependent
downloads may be disabled.

The captured SVG set follows the selected report detail mode described below.
In CGeV Web, enabling reader downloads publishes the ZIP with the secret report;
when that option is off, the author can still generate a private local copy
from the Share dialog.

## 11.11 Read-only interactive reports

On CGeV Web, the header **Share** action also creates an immutable secret URL. Before
publishing, choose:

- **Complete** or **Fast** report detail;
- when both workflows contain results, whether to include **Multi-Gene**,
  **Cross-Species**, or both;
- whether to include private or uploaded sequence content;
- whether readers may download the reproducibility ZIP;
- whether CGeV should run the compatible current Cross-Species LASTZ and
  MultiPIP comparisons before capturing both alignment views;
- an expiry of 7, 14, or 30 days. The default is 7 days.

When reader downloads are disabled, CSV, FASTA, and ZIP files are not published
with the secret report. Tables and figures already included in the read-only
HTML remain visible.

**Complete** is the recommended mode. It generates structural views, Analytics
charts, and eligible aligned-synteny views that have not yet been opened.
Optional LASTZ/MultiPIP execution is available only in this mode.
These sequence-alignment views belong to Cross-Species Search. In Multi-Gene
Search, Synteny is the only alignment method and is available when a loaded
gene has more than one transcript.

**Fast** captures only views that are already rendered and idle. It does not
activate hidden Analytics, structures, alignments, or synteny. The report
records those intentional omissions so readers can distinguish them from
capture failures.

The report gives the gene structure full page width and presents chromosome
position as a compact location aid. It contains aligned synteny when available,
completed LASTZ/MultiPIP results, external results used in the analysis, and
Figure Studio when available. In Complete mode, CGeV derives the complete
analytics chart set and summary tables during publication even when the author
never opened those panels. Readers can use tooltips, zoom, filters, table
sorting, and collapsible sections. The report cannot run new searches, modify
the analysis, or contact external databases.

When one report contains both workflows, every location, structure, synteny,
alignment, analytics, and table block is labelled and separated as
**Multi-Gene** or **Cross-Species**. Detailed sections start collapsed to keep
large analyses navigable. Gene-structure results are grouped by gene and
organism; each group initially shows its primary transcript and provides a
selector for one specific transcript or all captured isoforms.

For Multi-Gene results, CGeV captures one aligned-synteny view for every loaded
gene that has more than one transcript. Each view is labelled with that gene
instead of with the complete search list. Report preparation temporarily
renders uncached views behind the Share dialog. CGeV freezes a visual copy of
the current application beneath the modal during this process, so the visible
workspace does not turn blank or expose intermediate mode changes.

Report generation is one of CGeV's most intensive processes and can take several
minutes, especially in Complete mode or when LASTZ/MultiPIP is requested. Keep
CGeV and the Share dialog open until the final link or local-file message
appears. The dialog reports the current preparation stage.

If the browser cannot capture an expected element, CGeV lists it before
publication. The author must either cancel or explicitly continue with that
element excluded; capture failures are never omitted silently.

Anyone with the URL can view and copy visible information. The link is not
indexed, but it must still be treated as a secret. Reports created in the
current browser appear under **Settings > Shared analysis reports**, where they
can be copied or revoked.

CGeV Desktop does not upload analyses. It exports the same interactive report as
a self-contained HTML file plus the reproducibility ZIP. Select **Build files**,
then save **Download HTML** and **Generate / download ZIP** separately through
the operating-system save dialogs.

The optional pre-publication LASTZ/MultiPIP action is tied to the current report
generation and only completed results are included. Persistent background
queues for unfinished LASTZ/MultiPIP jobs are not part of this release; durable
cancel/retry/resume jobs remain planned for a future phase.

---HARDPAGE---

# 12. Settings

[[SCREENSHOT_SETTINGS]]

## 12.1 Day / Night Mode

The theme control switches between light and dark presentation. The selected theme is stored in the current application profile.

Theme changes affect on-screen plots and supported exported visualizations. Verify the final Figure Studio style independently of the interface theme.

## 12.2 Colorblind Palette

Enable **Colorblind Palette** to apply an accessible feature and chart color scheme. Use it for presentations, collaborative review, or publications where color-vision accessibility is required.

## 12.3 Confirm before deleting

When enabled, CGeV asks before removing cards, clearing visualizations, or replacing destructive workspace state. Disable it only when rapid iterative clearing is more important than protection from accidental loss.

## 12.4 Quick navigation button

Enable this setting to display the floating search, display-mode, and zoom control described in Section 2.

## 12.5 External alias lookup

Select which services CGeV may use when the local annotation does not contain the entered gene name:

- MyGene;
- NCBI Gene;
- UniProt;
- Ensembl.

Disabling a source narrows external resolution and can reduce background network activity. It can also reduce the number of recoverable aliases. Local exact matches and local alias-index matches remain preferred.

## 12.6 Organisms - Desktop only

The Organisms section manages locally installed references.

Controls include:

- installed, available, and pending counts;
- **Open catalog**;
- **Remove organisms**;
- **Refresh**;
- data and cache paths;
- catalog search;
- status filters: All, Available, Not installed, Installed, Updates.

Installed references appear in the preloaded selectors.

## 12.7 Work sessions

Use **Export current session (.rds)** and **Restore session** as described in Section 11. Session files are CGeV workspace snapshots, not interchangeable biological data formats.

## 12.8 Shared analysis reports - Web

This section lists secret reports created in the current browser. Use it to
open or copy a report URL, or to revoke the report before its scheduled expiry.

The list itself is stored only in the browser and does not require a CGeV
account. Clearing browser storage can remove the local receipt without
revoking the published report; the secret link still expires automatically.

---PAGE---

# 13. CGeV Desktop

## 13.1 What Desktop adds

CGeV Desktop packages the complete scientific interface with a local application runtime. It provides:

- a private localhost session inside the desktop window;
- bundled R and analysis tools;
- local LASTZ, sequence, and indexing utilities;
- persistent organism packages and caches;
- user-selected storage;
- local diagnostics;
- desktop update handling;
- the same search, analytics, Figure Studio, and export features as CGeV Web;
- self-contained interactive HTML reports and reproducibility ZIPs saved only
  to a location chosen by the user.

CGeV Desktop does not require a separate R, Docker, WSL, or command-line installation for normal use.

## 13.2 Supported installers

| Platform | Installer | Architecture |
|---|---|---|
| macOS | DMG | Apple Silicon arm64 and Intel x64 |
| Linux | AppImage or DEB | x86_64 |
| Windows | Assisted offline per-user NSIS setup | Windows 10 or 11 x64 |

Allow at least 2 GB for the application, plus storage for every organism installed from the catalog.

## 13.3 First launch

1. Open CGeV Desktop.
2. On the first packaged Windows launch, choose a writable folder for genomes and caches when prompted. On macOS and Linux, CGeV initializes its application-managed data location.
3. Allow the local runtime to initialize.
4. Wait for the main CGeV interface.
5. Open **Settings** and install at least one organism.

The selected storage folder contains:

- `data` - genomes, annotations, manifests, and downloaded packages;
- `cache` - reusable indexes and derived cache data.

## 13.4 Organism catalog

1. Open **Settings**.
2. In **Organisms**, select **Open catalog**.
3. Search by organism name or filter by status.
4. Select **Download**.
5. Follow download, verification, extraction, and cache-preparation progress.
6. Return to the search workflow and select the installed organism.

Dataset states are:

- bundled;
- not installed;
- partial;
- installed;
- update available.

Downloads use temporary partial files, SHA-256 verification, safe ZIP extraction, and a local installation record. Existing verified files are reused. Active downloads can be canceled, and partial files are removed.

## 13.5 Verify and update an organism

Use **Verify** for an installed catalog entry. If a newer package is available, the catalog marks it as an update. Install the update from the same entry, then refresh the source selector.

## 13.6 Remove local organisms

Select **Remove organisms** to open the installed-organism list. Choose one, several, or **Select all installed organisms**, then confirm **Remove selected**. CGeV removes only the selected catalog datasets and their associated local files and caches from the active desktop profile. This is a destructive data-management action. Export sessions and verify the storage path before confirming.

## 13.7 Change the data folder

On Windows, use **File > Change data folder...**.

CGeV restarts and uses the newly selected folder. Existing genomes and caches are not moved or deleted. Select the previous folder again to reuse its content, or move the data manually while CGeV is closed.

The Windows **File** menu also provides:

- **Open data folder**;
- **Show diagnostics log**;
- **Privacy policy**.

## 13.8 Automatic updates

Direct Windows releases check for updates, download them in the background, and install them when CGeV restarts or quits as indicated by the update notification. Dataset updates remain separate from application updates and are managed in the organism catalog.

## 13.9 Diagnostics log

Startup and runtime details are kept out of the normal interface and written to:

| Platform | Default log |
|---|---|
| macOS | `~/Library/Application Support/CGV Desktop/logs/startup.log` |
| Linux | `~/.config/CGV Desktop/logs/startup.log` |
| Windows | `%LOCALAPPDATA%\CGV Desktop\logs\startup.log` |

Share the relevant final lines with a bug report. Review the file first if local paths are sensitive.

## 13.10 Desktop privacy model

The Shiny service listens on a private local port and is displayed inside Electron. Installed reference data and caches remain in the selected local storage folder.

External features still require network access, including:

- NCBI assembly search and download;
- external alias lookup;
- GO online fallback;
- Europe PMC literature;
- STRING networks;
- organism imagery;
- external database links;
- Feedback delivery and its optional confirmation email;
- application and dataset updates.

## 13.11 Uninstallation

Removing the desktop application preserves the user-selected storage folder and installed datasets. Delete that folder separately only when its genomes, annotations, caches, packages, and session-related data are no longer required.

---PAGE---

# 14. CGeV Guide

CGeV Guide complements this manual with short visual demonstrations.

## 14.1 Guide routes

**Desktop Downloads** covers opening Settings, browsing the catalog, filtering,
downloading, verifying availability, and selectively removing one, several, or
all downloaded organisms.

**Multi-Gene Search** covers:

- preloaded, NCBI, and uploaded sources;
- single and batch gene entry;
- visualization generation;
- Compact and Detailed inspection;
- transcript Synteny alignment;
- figure and table export.

**Cross-Species Search** covers:

- preloaded, NCBI, uploaded, and mixed sources;
- one-gene search;
- visualization generation;
- Compact and Detailed inspection;
- aligned synteny, LASTZ, and MultiPIP;
- alignment export.

**Common Analysis** covers:

- analytics;
- summary tables;
- transcript variants;
- gene information;
- promoter sequences;
- literature;
- organism and assembly information;
- external alias configuration;
- save and load session;
- sharing an expiring read-only report URL in Web or exporting the interactive
  HTML and ZIP locally in Desktop;
- clear visualizations.

**Figure Studio** covers:

- opening the workspace from the current analysis;
- adding structural, alignment, and analytics panels;
- arranging, resizing, labelling, and styling the composition;
- previewing and exporting SVG or PNG;
- including a non-empty Figure Studio composition in an interactive report.

## 14.2 Use the Guide effectively

1. Choose a route.
2. Select a numbered step.
3. Open a substep when available.
4. Watch the short demonstration.
5. Use the route action to open the corresponding CGeV workflow.
6. Return to the Guide whenever a control sequence is unfamiliar.

The Guide is designed for procedural learning. Use this manual for complete option reference, interpretation guidance, and troubleshooting.

---PAGE---

# 15. Troubleshooting

## 15.1 A gene is not found

Check, in order:

1. the correct workflow is active;
2. the intended organism or organisms are selected;
3. the query spelling and capitalization;
4. autocomplete suggestions;
5. stable IDs and known synonyms;
6. partial-name suggestions;
7. enabled external alias sources;
8. alias evidence from another successful record;
9. the source annotation version.

For Cross-Species Search, remember that at least two organism matches are required for a comparative result.

## 15.2 The wrong gene was resolved

- Review the **Alias** badge.
- Compare the official symbol, local ID, chromosome, and description.
- Rerun using the exact stable identifier.
- Disable unsuitable external alias sources.
- Check whether the symbol is reused by several gene families or taxa.

## 15.3 An upload pair is rejected

- Confirm one genome per annotation.
- Confirm both describe the same assembly.
- Compare chromosome or contig identifiers.
- Use clear matching file names.
- Decompress or convert unusual archives to an accepted format.
- Remove unrelated files from a multi-file selection.

## 15.4 A plot has N/A sequence values

- Verify that a genome file is available.
- Confirm the chromosome exists in the genome.
- Check annotation-genome build agreement.
- Check that coordinates fall inside the sequence.
- For an uploaded FASTA, verify headers match annotation sequence IDs.

## 15.5 Promoter download fails

- Confirm the plot has a genome sequence.
- Confirm transcript coordinates and strand.
- Reduce the upstream length near a chromosome boundary.
- Check sequence-identifier mapping in assembly details.

## 15.6 GO is empty

- Confirm the selected organism has a local GO file.
- Check that the GAF identifiers match the plotted record.
- Select the online lookup action.
- Try the official stable gene ID.
- Verify the organism TaxID.

## 15.7 STRING has no network

- Confirm the gene resolves to a protein-coding record.
- Verify the organism TaxID.
- Try an official symbol or stable ID.
- Check network access.
- Recognize that some organisms or proteins have limited STRING coverage.

## 15.8 Literature results are noisy

- Verify the organism shown in the dialog.
- Filter by author, title, or journal.
- Sort by relevance.
- Follow the external record and confirm the gene context.
- Search the official stable identifier separately for ambiguous symbols.

## 15.9 Alignment is empty

- Confirm at least two usable tracks.
- Confirm genome sequence for every track.
- Lower the identity threshold.
- Lower the minimum block or segment length.
- use a smaller, well-annotated reference set;
- select another reference;
- verify the alignment window and coordinates.

## 15.10 Alignment is slow

- Begin with gene body only.
- Reduce the organism or transcript set.
- Increase the minimum segment or block length.
- Avoid running multiple large NCBI downloads simultaneously.
- In Desktop, allow the first run to build reusable caches.
- Keep CGeV open while the automatic status popup shows LASTZ or MultiPIP as
  active.
- If a safety timeout or oversized-window message appears, reduce the alignment
  window before retrying.

## 15.11 Analytics are missing

- Confirm at least one result card is active.
- Open the analytics section after plot rendering completes.
- For Heatmap, Radar, and Correlations, load at least two records with usable metrics.
- Confirm sequence-dependent metrics have genomes.
- Review the explicit no-data message in the chart.

## 15.12 SVG export is incomplete

- Wait for all cards or charts to finish rendering.
- Expand isoforms that must be exported.
- Use the specific card or analytics export control.
- Retry after switching back to the relevant result tab.
- Use Figure Studio preview to identify an unavailable source.

## 15.13 A session does not restore as expected

- Confirm the file is a CGeV `.rds` work session.
- Confirm the file is accessible and not truncated.
- Restore into the same or a compatible CGeV version.
- Keep original upload data available for operations that need fresh source access.
- Reinstall missing Desktop organisms.
- Regenerate any Figure Studio source marked unavailable.

## 15.14 Desktop does not start

1. Wait for runtime preparation to complete on first launch.
2. Confirm the storage folder is writable.
3. Open the diagnostics log.
4. Confirm free disk space.
5. Restart CGeV Desktop.
6. On macOS, approve the application in **System Settings > Privacy & Security** when required.
7. On Linux, confirm AppImage execution permission or use the DEB package.
8. On Windows, use the signed per-user installer and review security prompts.

## 15.15 A Desktop organism does not appear

- Open **Settings > Organisms**.
- Refresh the catalog.
- Confirm the state is installed.
- Select **Verify**.
- Restart CGeV Desktop if the selector was already open during installation.
- Confirm the data path belongs to the active profile.

## 15.16 Feedback and support

Open **Feedback** and choose **Report a Bug** or **Suggest a Feature**.

A useful bug report includes:

- short title;
- exact steps to reproduce;
- expected behavior;
- active workflow;
- organism and assembly;
- gene query;
- view and alignment settings;
- browser or operating system;
- CGeV Desktop log excerpt when applicable.

Full name, a valid reply email, a short title, and a detailed description are
required. CGeV also records the active application section, submission time, and
page context. The email address is used only for this submission and follow-up.

After successful delivery, CGeV clears the submitted detail fields and displays
a confirmation notice. When confirmation email is enabled, a copy with the
submission reference is sent to the reporter; failure of that copy does not
discard feedback already delivered to the CGeV inbox.

If Desktop reports that the message was saved locally but cannot be sent, use
the Feedback page at `cgev.mobilomics.org`, use `cgvapp.com` while the official
server is unavailable, or email `cgvviewer@gmail.com`. Repeated or duplicate
submissions can be temporarily rate-limited; follow the notification message
before retrying.

---PAGE---

# Appendix A. Supported reference organisms

The curated registry contains the following 25 organism references. Availability in Web depends on the server deployment. In Desktop, installed catalog entries appear in the preloaded selectors.

[[SUPPORTED_ORGANISMS]]

---PAGE---

# Appendix B. Input and output reference

## B.1 Input formats

| Purpose | Formats |
|---|---|
| Annotation | GFF, GFF3, GTF, text |
| Genome | FASTA, FNA, gzip-compressed FASTA/FNA, 2bit |
| Assembly report | NCBI-style text |
| Assembly statistics | NCBI-style text |
| GO annotations | GAF, gzip-compressed GAF |
| Work session | CGeV RDS |

## B.2 Output formats

| Output | Format | Scope |
|---|---|---|
| Structural figure | SVG | One card |
| Structural figure bundle | ZIP of SVG | Active result set |
| Analytics chart | SVG | One analytics tab |
| Analytics bundle | ZIP of SVG | Active analytics set |
| Publication figure | SVG or PNG | Figure Studio composition |
| Summary table | CSV | Active result set |
| Gene, transcript, CDS, introns | FASTA | One card |
| Promoter window | FASTA | One selected promoter interval |
| Alignment sequence set | FASTA | Active alignment view |
| Work session | RDS | Complete CGeV workspace |

## B.3 Annotation expectations

CGeV works best when the annotation contains:

- gene features;
- transcript or mRNA features;
- exon features;
- CDS and UTR features where applicable;
- stable parent-child identifiers;
- valid sequence identifiers;
- numeric start and end coordinates;
- strand.

Fallback logic supports several transcript and non-coding RNA feature names, but nonstandard annotations may require validation before interpretation.

---PAGE---

# Appendix C. Keyboard and interaction reference

| Interaction | Result |
|---|---|
| Enter in an active gene field | Runs the current single-gene search |
| Space in Multi-Gene batch input | Adds the current gene as a batch chip |
| Ctrl+Enter in Multi-Gene input | Adds the current gene as a batch chip |
| Escape | Closes the active supported popup or modal |
| Hover a feature | Shows annotation or metric details |
| Select a neighboring or overlapping gene | Opens relation, coordinate, and strand details |
| Select **Visualize [gene] below** | Adds that neighbor in Multi-Gene Search only |
| Select **Scale**, **Neighbors**, or **Overlaps** | Shows or hides that genomic-context layer |
| Select promoter connector | Opens promoter-length and FASTA controls |
| Drag Figure Studio panel | Reorders panels |
| Drag STRING node | Rearranges the network |
| Mouse wheel in STRING | Zooms the network |
| Double-click STRING canvas | Fits the network |
| Floating plus button | Opens quick search, display, and zoom actions |

---PAGE---

# Appendix D. Glossary

**Alias** - An alternative gene symbol, stable identifier, synonym, or database-specific name used to resolve a local annotation record.

**Annotation** - A structured description of genomic features and their coordinates, typically stored as GFF3 or GTF.

**Assembly** - A specific version of an organism's reference genome sequence.

**Canonical transcript** - The primary transcript representative selected for a gene in the current annotation and CGeV context.

**CDS** - Coding sequence translated into protein.

**Exon** - A transcribed feature retained in a mature transcript; coding and untranslated portions can both occur within exons.

**FASTA** - A text format for nucleotide or protein sequences.

**GAF** - Gene Association File used for Gene Ontology annotations.

**Gene body** - The interval covered by the annotated gene or selected transcript locus, excluding optional flanks.

**GC percentage** - The fraction of sequence bases that are G or C.

**Intron** - The interval between consecutive annotated exons in a transcript model.

**LASTZ** - A local sequence-alignment program used by CGeV for block and conservation views.

**MultiPIP** - A reference-centered display of local conservation segments across several query tracks.

**Orthology** - An evolutionary relationship between genes separated by speciation. CGeV provides comparative evidence but does not by itself establish orthology.

**Preloaded organism** - A reference whose annotation, genome, and registry metadata are ready for selection in the current CGeV environment.

**Promoter window** - In CGeV, a user-defined upstream sequence interval from 100 to 5,000 bp.

**Synteny** - Conserved genomic or feature order. CGeV's aligned-synteny view focuses on gene and transcript structural correspondence.

**Transcript isoform** - One annotated transcript model among several associated with the same gene.

**UTR** - Untranslated region of a transcript.

**Work session** - A CGeV RDS snapshot containing plots, settings, source context, and Figure Studio state.

---PAGE---

# Appendix E. Quick-reference checklists

## E.1 Before running a search

- Correct workflow selected.
- Correct organism or organism set.
- Assembly version confirmed.
- Annotation and genome paired.
- Optional GO and assembly files added.
- Query spelling or stable ID checked.

## E.2 Before interpreting a result

- Gene and transcript labels verified.
- Organism and chromosome verified.
- Alias evidence reviewed.
- Strand and coordinates checked.
- Missing sequence values identified.
- Isoforms expanded where relevant.
- Detailed view reviewed for feature-level claims.

## E.3 Before interpreting an alignment

- At least two complete tracks.
- Reference recorded.
- Alignment mode recorded.
- Window recorded.
- Identity and length thresholds recorded.
- High-threshold empty results checked at a lower threshold.
- Conclusions separated from formal orthology or regulatory claims.

## E.4 Before export

- Rendering complete.
- Desired cards and isoforms active.
- Sort order correct.
- Figure Studio preview checked.
- SVG master saved.
- CSV saved.
- Relevant FASTA saved.
- Session RDS saved.
- Source assembly and settings documented.

## E.5 Before closing Desktop

- Session exported.
- Long downloads complete or intentionally canceled.
- Dataset state verified.
- Update status reviewed.
- Diagnostics captured if an error occurred.

---PAGE---

# Document control

**Title:** CGeV User Manual - Comparative Gene Viewer

**Coverage:** CGeV Web and CGeV Desktop

**Product version:** {{PRODUCT_VERSION}}

**Manual revision:** {{REVISION_DISPLAY}}

**Primary application:** https://cgev.mobilomics.org

**Source repository:** https://github.com/raulrojas22/CGV

This manual describes the complete user-facing behavior represented by CGeV version {{PRODUCT_VERSION}}, including the desktop data catalog, aligned-synteny tools, LASTZ and MultiPIP views, Figure Studio, interactive read-only reports, reproducibility exports, and session management.
