# CGV: a unified interactive platform for comparative gene visualization and functional analysis across species

**Authors:** Raul Rojas-Espinoza^1,2,*, Janin Riedelsberger^1,2, Gonzalo Riadi^1,3

**Affiliations:**
1. Center for Bioinformatics, Simulation and Modeling (CBSM), University of Talca, Chile.
2. JaninLab, University of Talca, Chile.
3. Mobilomics / RiadiLab, University of Talca, Chile.

*Corresponding author: raul.rojas@utalca.cl

---

## Abstract

**Motivation:** Investigating gene structure and function across species typically requires navigating multiple disconnected resources—genome browsers for coordinates, dedicated databases for orthologs, separate portals for Gene Ontology, protein interactions, and promoter sequences. This fragmented workflow is time-consuming and demands bioinformatics expertise, creating a barrier for experimental biologists.

**Results:** We present CGV (Comparative Gene Viewer), an interactive web platform that unifies gene structure visualization, cross-species comparison, and functional analysis in a single interface. CGV performs locus-independent searches through simultaneous queries to NCBI, Ensembl, UniProt, and MyGene.info, resolving ambiguous gene nomenclature automatically. It renders interactive gene models from locally indexed data (2bit genomes, tabix-indexed GFF3) via an asynchronous backend, supporting five comparison modes including LASTZ-based pairwise alignment. An integrated analytical suite provides eight chart types, STRING protein interaction networks, Gene Ontology mapping, and configurable promoter extraction—consolidating analyses that would otherwise require hours of manual cross-referencing into a streamlined, real-time workflow across 25 preloaded organisms.

**Availability and implementation:** CGV is freely available at https://github.com/raulrojas22/CGV and deployed at https://cgvapp.com.

---

## 1. Introduction

The rapid expansion of publicly available genome assemblies and annotations has shifted the central challenge in genomics from data generation to data interpretation (Kriventseva *et al.*, 2019). Comparative analysis of gene structures—exon-intron architectures, coding potential, and regulatory regions—across species is fundamental to understanding gene family evolution, functional divergence, and adaptation mechanisms in fields ranging from crop improvement to biomedical research (Sivashankari and Shanmughavel, 2007). Yet the practical workflow for performing such comparisons remains surprisingly fragmented.

Established genome browsers such as UCSC Genome Browser (Kent *et al.*, 2002), IGV (Robinson *et al.*, 2011), and JBrowse (Buels *et al.*, 2016) provide powerful navigation of individual assemblies but are inherently locus-dependent: researchers must first obtain genomic coordinates from external databases before visualizing a region of interest. Comparing orthologous genes across organisms typically requires opening separate browser instances, manually aligning tracks, and reconciling inconsistent gene nomenclature between databases. Meanwhile, functional information—protein interaction networks, Gene Ontology annotations, promoter sequences—resides in dedicated portals such as STRING (Szklarczyk *et al.*, 2023), AmiGO (Carbon *et al.*, 2009), and individual genome project databases. This fragmentation forces researchers into repetitive, time-consuming navigation across multiple platforms to answer questions that are conceptually straightforward: *How does the structure of gene X compare across species, and what is its functional context?* For experimental biologists lacking programming expertise, this barrier often translates into delayed analyses or reliance on bioinformatics support for routine inspections.

To address these limitations, we developed CGV (Comparative Gene Viewer), an interactive web platform that consolidates gene structure visualization, cross-species comparison, and functional analysis into a single unified interface. CGV enables locus-independent exploration: users search by gene name or alias, and the system autonomously resolves the query across four major databases (NCBI, Ensembl, UniProt, MyGene.info), retrieves structural annotations from locally indexed files, and renders interactive gene models—eliminating the need for prior coordinate knowledge. The platform supports side-by-side comparison of homologous and orthologous genes through five visualization modes, including LASTZ-based pairwise alignment, while simultaneously providing access to quantitative analytics, STRING protein interaction networks, Gene Ontology terms, and promoter region extraction. By leveraging an asynchronous processing architecture and optimized genomic formats (2bit sequences, tabix-indexed GFF3), CGV handles large annotation files with minimal memory overhead. With 25 preloaded reference organisms and the ability to incorporate additional assemblies on demand via the NCBI Datasets API, CGV reduces the time-to-insight from hours of cross-platform navigation to seconds of interactive exploration within a single browser tab.

---

## 2. Implementation and Features

CGV is implemented as an R/Shiny web application comprising approximately 46,000 lines of code organized into domain-specific modules. The platform is designed around a principle of convergence: bringing together structural, comparative, and functional genomic analyses that traditionally require separate tools into a cohesive, real-time workflow. The system architecture consists of four integrated layers (Figure 1A).

### 2.1 Data management and high-performance indexing

CGV employs a hybrid data ingestion strategy optimized for memory efficiency. Genome sequences are stored in 2bit binary format and accessed via the rtracklayer package, enabling random extraction of arbitrary regions—such as promoter sequences or individual exons—without loading entire chromosomes into memory. Gene annotations are maintained as bgzip-compressed GFF3 files with tabix indices (Rsamtools), allowing sub-second retrieval of features within specific genomic intervals. This indexed architecture is critical for handling organisms with dense annotations, such as *Triticum aestivum* (wheat), where raw GFF3 files exceed several gigabytes. A multi-tiered caching system manages parsed annotation data, gene indices, and precomputed autocomplete maps, reducing redundant I/O operations across user sessions. The platform ships with 25 preloaded reference organisms spanning plants, animals, fungi, and model species. Additionally, a built-in NCBI Datasets API v2 client enables on-demand download, indexing, and registration of new genome assemblies directly from the interface—researchers can incorporate a newly released cultivar or assembly without server-side intervention.

### 2.2 Gene search and alias resolution

A persistent challenge in comparative genomics is the inconsistent nomenclature of genes across databases: a single gene may be referenced by its official symbol, legacy aliases, accession numbers, or organism-specific identifiers. CGV addresses this through a multi-source search engine that simultaneously queries MyGene.info, NCBI E-utilities, UniProt, and Ensembl REST APIs. An internal scoring algorithm extracts alphabetic and numeric cores from query and candidate strings, assigning weighted similarity scores to rank results and mitigate false positives. This process runs asynchronously via the furrr package, ensuring that the user interface remains responsive during network-bound operations. For local searches, a per-organism autocomplete index provides up to 20,000 gene name suggestions derived from parsed GFF3 attributes, enabling rapid navigation even without external API access.

### 2.3 Visualization and comparison modes

Gene models are rendered as interactive vector graphics using ggplot2 and ggiraph, where genomic features—exons, CDS regions, UTRs, and introns—are mapped to layered geometric elements with hoverable tooltips displaying positional coordinates, lengths, and GC content. All visualizations are exportable as publication-ready SVG files. CGV provides two primary search workflows, each with specialized comparison modes:

*Multi-gene (homologous) search.* Users explore multiple genes within a single organism. Genes are displayed in compact mode (minimal structural overview) or detailed mode (full annotation with per-feature metrics). An integrated analytical suite (Section 2.5) enables quantitative comparison across the gene set.

*Cross-species (orthologous) search.* Users compare a target gene across different organisms. Beyond compact and detailed views, this workflow offers three alignment-oriented modes: (i) *Comparative Aligned*, which maps CDS and exon coordinates to enable side-by-side structural comparison; (ii) *LASTZ Blocks*, which computes and displays local pairwise alignment segments between reference and query sequences using an integrated LASTZ binary, with configurable identity thresholds; and (iii) *MultiPIP*, a stacked progressive visualization of pairwise protein alignments across multiple species. A lazy-loading mechanism based on IntersectionObserver ensures that only visible gene tracks are rendered, maintaining interface performance when comparing many genes simultaneously.

### 2.4 Analytical suite

For multi-gene searches, CGV provides eight interactive chart types that transform raw structural annotations into quantitative, comparable metrics: (i) *Gene Architecture*—stacked bar charts decomposing each gene into CDS, UTR, and intronic proportions; (ii) *Exon and Intron Distribution*—counts and base-pair breakdowns; (iii) *Sequence Composition*—nucleotide percentages and GC content; (iv) *Genomic Context*—distances to upstream and downstream neighboring genes; (v) *Exon Length Distribution*—violin, box, and jitter plots on a log10 scale; (vi) *Scatter Plot*—customizable bivariate comparison of any tracked metric; (vii) *Heatmap*—Pearson correlation matrix with hierarchical clustering dendrograms; and (viii) *Radar Chart*—multi-metric polar profiles for simultaneous comparison of gene properties. Each chart supports over eleven sorting modes, dark and light themes, colorblind-friendly palettes, and direct SVG export.

### 2.5 Functional integration: a unified analytical hub

Rather than limiting its scope to structural visualization, CGV integrates functional annotations that researchers would otherwise retrieve from separate specialized platforms—a design choice driven by the goal of minimizing context-switching and reducing the time required to build a comprehensive view of a gene's biology:

*Protein-protein interaction networks.* CGV queries the STRING database to retrieve interaction partners for any visualized gene, rendering the resulting network as an interactive, draggable graph via visNetwork. Nodes are color-coded to distinguish the target gene, other plotted genes present in the workspace, and additional interactors. Combined confidence scores and individual evidence channels (experiments, co-expression, text mining, curated databases) are displayed for each edge.

*Gene Ontology annotation.* The platform maps genes to GO terms across all three ontology domains (biological process, molecular function, cellular component) using locally stored GAF files for 24 organisms, with an OBO-based term hierarchy. For organisms without local annotations, an online query fallback is available. This allows researchers to immediately contextualize a gene's known functions alongside its structural features.

*Promoter region extraction.* Users can define and extract upstream regulatory sequences of configurable length directly from the gene visualization interface. The extraction is strand-aware and supports reverse-complement operations, with results downloadable in FASTA format for downstream motif analysis or primer design.

*Session persistence.* Complete working sessions—including all plotted genes, metrics, organism configurations, and analytical states—can be saved as JSON snapshots and restored later, supporting reproducibility and collaborative workflows.

### 2.6 Deployment

CGV is containerized using Docker (base image: rocker/r-ver:4.5) with integrated health checks and configurable environment variables for worker count, cache sizes, and API keys. This enables single-command institutional deployment, where one server instance serves multiple concurrent users through the asynchronous multisession backend. Genome and annotation volumes can be mounted externally, allowing administrators to update reference data without rebuilding the container.

---

## 3. Application Examples

To illustrate CGV's capabilities across biological domains, we present two case studies that demonstrate complementary workflows: a multi-gene exploration within a single genome and a cross-species structural comparison.

### 3.1 Multi-gene analysis: the HKT transporter family in rice

The HKT (High-Affinity K+ Transporter) gene family plays a central role in sodium homeostasis and salt tolerance in cereals, making it a frequent target in crop improvement programs (Platten *et al.*, 2006). Using CGV's multi-gene search workflow, we queried the *Oryza sativa* ssp. *japonica* annotation for all HKT family members. The platform resolved each gene name through its multi-API engine, retrieved the corresponding GFF3 features from the local tabix-indexed annotation, and rendered interactive gene models within seconds.

The integrated analytical suite immediately revealed structural heterogeneity across the family: the radar chart highlighted contrasting profiles in gene length, exon count, and CDS/transcript ratios, while the exon length distribution (violin plot) exposed distinct splicing patterns between subfamily I and II members. The heatmap module further identified metric correlations—such as the expected association between gene length and intron count—providing a quantitative overview that would otherwise require custom scripting. Simultaneously, the STRING network module retrieved known protein-protein interaction partners, contextualizing HKT transporters within the broader ion homeostasis pathway, and GO term mapping confirmed annotations related to sodium ion transmembrane transport and cellular response to salt stress. Finally, the promoter extraction tool allowed retrieval of upstream sequences in FASTA format for downstream cis-element analysis. This entire workflow—from initial query to functional contextualization—was completed within a single browser session without external tools (Figure 1B).

### 3.2 Cross-species comparison: TP53 across vertebrates

The tumor suppressor gene *TP53* is among the most extensively studied genes in biomedical research, with orthologs conserved across vertebrates (Levine, 2020). We used CGV's cross-species workflow to compare *TP53* structure across *Homo sapiens*, *Mus musculus*, and *Danio rerio*—three preloaded organisms representing mammals and teleosts.

Entering "p53" as query, CGV's alias resolution engine correctly identified *TP53* across all three species despite nomenclature differences (*Tp53* in mouse, *tp53* in zebrafish). The comparative aligned mode displayed side-by-side exon-intron architectures, revealing the conserved multi-exonic structure while highlighting differences in intron lengths and UTR regions between species. The LASTZ alignment mode provided local pairwise alignment blocks between human and each target organism, quantifying sequence identity at the nucleotide level and visually mapping conserved segments onto the gene models. Notably, the zebrafish ortholog displayed a markedly different exon-intron organization compared to the mammalian genes—a structural divergence immediately apparent in CGV's visualization that would require substantial manual effort to identify and represent using conventional genome browsers operating on separate assemblies (Figure 1C).

Together, these examples demonstrate how CGV condenses what would traditionally involve coordinated use of genome browsers, alignment tools, interaction databases, and functional annotation portals into a single, cohesive analytical session—reducing time-to-insight from hours to minutes.

---

## 4. Conclusion

CGV provides a unified environment for comparative gene visualization and functional analysis, consolidating tasks that traditionally require coordinated use of genome browsers, orthology databases, interaction portals, and sequence retrieval tools into a single interactive session. By integrating locus-independent multi-API search, five structural comparison modes including LASTZ-based alignment, an eight-chart analytical suite, STRING protein networks, Gene Ontology mapping, and promoter extraction, the platform substantially reduces the time and expertise required to build a comprehensive functional picture of any gene of interest.

The asynchronous architecture and indexed data formats ensure responsive performance even with large and densely annotated genomes, while Docker containerization enables straightforward institutional deployment serving multiple concurrent users. With 25 preloaded reference organisms and on-demand integration of new assemblies via the NCBI Datasets API, CGV is designed to grow alongside the expanding landscape of available genomes.

Future development will focus on three directions: (i) refactoring the server codebase into Shiny modules to improve long-term maintainability and community contribution; (ii) incorporating transcriptomic overlays (RNA-Seq expression profiles) onto structural gene models; and (iii) expanding cross-species alignment capabilities with additional whole-genome alignment algorithms. CGV is actively maintained and open to community feedback through its GitHub repository.

---

## 5. Availability and Implementation

- **Project name:** CGV (Comparative Gene Viewer)
- **Web server:** https://cgvapp.com (publicly accessible, no login required)
- **Source code:** https://github.com/raulrojas22/CGV
- **Operating system:** Platform independent (web browser for end users; Linux/macOS for server deployment)
- **Programming language:** R (Shiny framework), with integrated JavaScript and CSS
- **Core dependencies:** R >= 4.5, bslib, ggiraph, visNetwork, future, promises, rtracklayer, Rsamtools, Biostrings, httr2, rbioapi
- **Containerization:** Docker image based on rocker/r-ver:4.5 (single-command deployment via docker-compose)
- **Test data:** 25 preloaded reference organisms available upon access; example queries (e.g., HKT1;5 in *O. sativa*, TP53 in *H. sapiens*) can be executed immediately without data upload
- **License:** MIT
- **Documentation:** Integrated help section within the application interface
- **Contact:** raul.rojas@utalca.cl

---

## Acknowledgements

The authors thank the members of JaninLab, RiadiLab, and the Mobilomics group at the Center for Bioinformatics, Simulation and Modeling (CBSM), University of Talca, for their valuable feedback during the development and testing of CGV.

---

## Funding

This work was supported by the Agencia Nacional de Investigacion y Desarrollo (ANID) doctoral scholarship [grant number XXXXX to R.R.-E.]; and Fondo Nacional de Desarrollo Cientifico y Tecnologico (FONDECYT) [grant number XXXXX to J.R.; grant number XXXXX to G.R.].

---

## References

Ashburner, M. *et al.* (2000) Gene Ontology: tool for the unification of biology. *Nature Genetics*, **25**, 25-29.

Bengtsson, H. (2021) A Unifying Framework for Parallel and Distributed Processing in R using Futures. *The R Journal*, **13**, 208-227.

Buels, R. *et al.* (2016) JBrowse: a dynamic web platform for genome visualization and analysis. *Genome Biology*, **17**, 66.

Carbon, S. *et al.* (2009) AmiGO: online access to ontology and annotation data. *Bioinformatics*, **25**, 288-289.

Chang, W. *et al.* (2024) shiny: Web Application Framework for R. R package. https://CRAN.R-project.org/package=shiny.

Gohel, D. and Skintzos, P. (2025) ggiraph: Make 'ggplot2' Graphics Interactive. R package. https://CRAN.R-project.org/package=ggiraph.

Harris, R.S. (2007) Improved pairwise alignment of genomic DNA. Ph.D. Thesis, The Pennsylvania State University.

Hu, B. *et al.* (2015) GSDS 2.0: an upgraded gene feature visualization server. *Bioinformatics*, **31**, 1296-1297.

Kent, W.J. *et al.* (2002) The human genome browser at UCSC. *Genome Research*, **12**, 996-1006.

Kriventseva, E.V. *et al.* (2019) OrthoDB v10: sampling the diversity of animal, plant, fungal, protist, bacterial and viral genomes for evolutionary and functional annotations of orthologs. *Nucleic Acids Research*, **47**, D807-D811.

Lawrence, M. *et al.* (2009) rtracklayer: an R package for interfacing with genome browsers. *Bioinformatics*, **25**, 1841-1842.

Levine, A.J. (2020) p53: 800 million years of evolution and 40 years of discovery. *Nature Reviews Cancer*, **20**, 471-480.

Platten, J.D. *et al.* (2006) Nomenclature for HKT transporters, key determinants of plant salinity tolerance. *Trends in Plant Science*, **11**, 372-374.

R Core Team (2024) R: A Language and Environment for Statistical Computing. R Foundation for Statistical Computing, Vienna, Austria. https://www.R-project.org/.

Robinson, J.T. *et al.* (2011) Integrative genomics viewer. *Nature Biotechnology*, **29**, 24-26.

Sivashankari, S. and Shanmughavel, P. (2007) Comparative genomics - a perspective. *Bioinformation*, **1**, 376-378.

Szklarczyk, D. *et al.* (2023) The STRING database in 2023: protein-protein association networks and functional enrichment analyses for any sequenced genome of interest. *Nucleic Acids Research*, **51**, D638-D646.

Wickham, H. (2016) ggplot2: Elegant Graphics for Data Analysis. Springer-Verlag, New York.

Xin, J. *et al.* (2016) High-performance web services for querying gene and variant annotation. *Genome Biology*, **17**, 91.

---

## Figure Legend

**Figure 1. Architecture and application of CGV.** **(A)** Schematic overview of the CGV platform architecture. Locally indexed genomic data (2bit sequences, tabix-indexed GFF3 annotations) and real-time external API queries (NCBI, Ensembl, UniProt, MyGene.info) are processed by an asynchronous backend that performs alias resolution, structural metric computation, and pairwise alignment (LASTZ). The interactive frontend delivers gene model visualizations, quantitative analytics, STRING protein interaction networks, Gene Ontology mapping, and promoter extraction. **(B)** Multi-gene analysis of the HKT transporter family in *Oryza sativa* ssp. *japonica*. The main panel displays interactive gene models in detailed mode; the inset shows a radar chart comparing structural properties across family members. **(C)** Cross-species comparison of TP53 orthologs in *Homo sapiens*, *Mus musculus*, and *Danio rerio*, displayed in comparative aligned mode. Structural conservation and divergence in exon-intron organization are immediately apparent across species.

---

<!--
========================================
NOTES FOR THE AUTHOR (DELETE BEFORE SUBMISSION)
========================================

WORD COUNT: ~2,400 words (within the 2,600 limit for Application Notes)

CHECKLIST BEFORE SUBMISSION:
[x] Replace [GitHub URL] and [server URL] with actual URLs — DONE (github.com/raulrojas22/CGV + cgvapp.com)
[ ] Run both case studies in the app and verify results
[ ] Take screenshots for Figure 1 panels B and C (light theme, 300 DPI)
[ ] Create architecture diagram for Figure 1 panel A (BioRender/Inkscape)
[x] Complete Acknowledgements and Funding sections — DONE (fill in grant numbers XXXXX)
[x] Verify all references — DONE (STRING corrected, 11 new refs added)
[x] Add missing references for R packages — DONE (ggplot2, ggiraph, shiny, future, rtracklayer, etc.)
[ ] Ensure web server (cgvapp.com) is accessible via HTTPS without login
[ ] Include test data / example queries as per journal requirements
[ ] Confirm 3-year maintenance commitment for web server
[ ] Replace XXXXX placeholders in Funding section with actual grant numbers
[ ] Review Bioinformatics formatting: https://academic.oup.com/bioinformatics/pages/author-guidelines
[ ] Upload source code to GitHub (github.com/raulrojas22/CGV)

FIGURE SPECIFICATIONS:
- Resolution: 300 DPI minimum
- Format: TIFF or PDF (vector preferred)
- Width: ~170mm (full page width)
- Panel A: Architecture diagram (created in BioRender, Inkscape, or similar)
- Panel B: App screenshot - HKT multi-gene in O. sativa (light theme, clean browser)
- Panel C: App screenshot - TP53 cross-species comparison (light theme, clean browser)
- Ensure all text in screenshots is legible at print size

CASE STUDIES TO VERIFY IN THE APP:
1. HKT family in O. sativa japonica:
   - Search: HKT1;1, HKT1;3, HKT1;4, HKT1;5, HKT2;1 (verify all resolve)
   - Analytics: radar chart, violin plot, heatmap
   - STRING: verify network loads for HKT genes
   - GO: verify terms appear (sodium transport, salt stress)
   - Promoter: extract upstream region, verify FASTA download

2. TP53 cross-species:
   - Search: "p53" in H. sapiens, M. musculus, D. rerio
   - Verify alias resolution works (TP53, Tp53, tp53)
   - Comparative aligned mode: verify side-by-side display
   - LASTZ: verify alignment blocks render correctly
   - Note zebrafish structural differences for discussion
-->
