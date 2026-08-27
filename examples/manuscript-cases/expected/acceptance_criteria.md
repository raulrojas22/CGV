# Expected results and acceptance criteria

These checks correspond to the examples and Figure 1 in the manuscript. They
test whether a reviewer can reproduce the reported workflow; they are not new
biological claims.

## HKT multi-gene case

- The selected assembly is `GCF_034140825.1`.
- Seven input queries produce seven locally resolved gene models.
- `HKT1;5` is represented by the source annotation label `LOC4327757`.
- The common 5'-to-3' view displays all seven models.
- Gene Architecture reports CDS, UTR, and intron contributions.
- Nucleotide Composition reports A, T, C, G, and GC percentages.
- Export produces a non-empty resolved-gene table and SVG or PNG figure.

The paper notes that HKT1;2 and HKT2;2 are absent from this annotation release;
they are deliberately not included as expected resolved models.

## TP53 cross-species case

- Seven organisms produce seven locally resolved gene models.
- The resolved display labels match `resolved_genes.tsv`, including `Trp53` in
  mouse and `tp53.L` in *Xenopus laevis*.
- All models can be normalized to a common 5'-to-3' orientation.
- *Homo sapiens* is the reference for LASTZ Blocks and MultiPIP.
- The minimum local identity is 50% and no flanking sequence is added.
- LASTZ Blocks and MultiPIP both render non-empty outputs.
- Export produces a non-empty resolved-gene table and SVG or PNG figures.

Exact block coordinates and percent-identity traces are conditional on the
selected transcript, genomic window, threshold, and installed source package.
The reproducibility export must therefore record those parameters and the
assembly accessions above.
