# Terminology Replacement Matrix

Scope: visible terminology only for the first pass. Keep internal mode keys (`homologous`, `orthologous`) unchanged for now.

## Official public names

- `Multi-Gene Search`
- `Cross-Species Gene Search`

Short descriptors:

- `Search many genes within one organism.`
- `Search one gene across many organisms.`

Preferred neutral phrase for cross-species copy:

- `selected gene and its annotated counterparts across organisms`

## Phase 1: visible UI replacements

| File | Lines | Current text | Replace with | Notes |
| --- | --- | --- | --- | --- |
| `ui.R` | 3420, 3422 | `Homologous Search` | `Multi-Gene Search` | Sidebar button title and label |
| `ui.R` | 3423 | `Homo` | `Multi` | Collapsed sidebar label |
| `ui.R` | 3537, 3539 | `Ortholog Search` | `Cross-Species Gene Search` | Sidebar button title and label |
| `ui.R` | 3540 | `Ortho` | `Cross` | Collapsed sidebar label |
| `ui.R` | 4342 | `Run homologous or orthologous searches across selected organisms.` | `Run multi-gene searches within one organism or cross-species searches for one selected gene.` | Home feature card |
| `ui.R` | 4391 | `Reviewing representative orthologs with aligned exon-level relationships` | `Reviewing representative gene models with aligned exon-level relationships across organisms` | Home scope card |
| `ui.R` | 4494 | `Homologous search` | `Multi-Gene Search` | Main tab title |
| `ui.R` | 4737 | `Ortholog Search` | `Cross-Species Gene Search` | Main tab title |
| `ui.R` | 4847 | `Compare CDS proportion across orthologs.` | `Compare CDS proportion across the compared gene models.` | Analytics tooltip |
| `ui.R` | 6020 | `Homologous and orthologous search` | `Search workflows` | Help pill |
| `ui.R` | 6059 | `Pick Homologous or Orthologous first so the app builds the correct comparison context.` | `Pick Multi-Gene or Cross-Species first so the app builds the correct comparison context.` | Help flow |
| `ui.R` | 6073 | `Homologous Search` | `Multi-Gene Search` | Help mode card title |
| `ui.R` | 6074 | `Use this when you want to inspect one gene in a narrower organism context, review its isoforms, or compare structural variation without forcing a representative ortholog alignment.` | `Use this when you want to inspect multiple annotated genes within one organism, review isoforms, or compare structural variation without cross-species alignment.` | Help mode card body |
| `ui.R` | 6083 | `Ortholog Search` | `Cross-Species Gene Search` | Help mode card title |
| `ui.R` | 6084 | `Use this when you need the same gene tracked across several organisms and want representative gene models aligned side by side.` | `Use this when you want one selected gene and its annotated counterparts compared across several organisms, with representative gene models aligned side by side.` | Help mode card body |
| `ui.R` | 6205 | `representative ortholog alignment` | `representative cross-species gene alignment` | FAQ copy |
| `ui.R` | 6218 | `When should I choose Homologous versus Orthologous search?` | `When should I choose Multi-Gene versus Cross-Species Gene Search?` | FAQ title |
| `ui.R` | 6221 | `Homologous` / `Orthologous` sentence | `Multi-Gene Search is better for inspecting several genes within one organism. Cross-Species Gene Search is better when you want one selected gene compared across multiple organisms and need the Comparative Aligned view.` | Replace whole sentence |
| `ui.R` | 6376 | `Opened Orthologous search...` | `Opened Cross-Species Gene Search...` | Bug-report placeholder |
| `ui.R` | 6508 | `Homologous mode` | `Multi-Gene mode` | FAB default context |
| `ui.R` | 2123-2125 | `Orthologous mode` / `Homologous mode` | `Cross-Species mode` / `Multi-Gene mode` | FAB dynamic context |

## Phase 1: visible server-side text replacements

| File | Lines | Current text | Replace with | Notes |
| --- | --- | --- | --- | --- |
| `server.R` | 9642-9645 | `Session restored: %d homologous and %d orthologous plot(s).` | `Session restored: %d multi-gene and %d cross-species plot(s).` | Restore notification |
| `server.R` | 9397 | `Ortholog search` / `Homologous search` | `Cross-Species Gene Search` / `Multi-Gene Search` | Batch popup context |
| `server.R` | 9700, 9741, 9742, 9744, 9800, 10032, 10033, 10038, 10039, 10085, 10110, 10111, 10123, 10137, 10141, 10182, 10203, 10214, 10231, 10244, 10258, 10268, 10272, 10338, 10507 | `Homologous search` | `Multi-Gene Search` | Popup contexts, modal subtitle, status text |
| `server.R` | 9813, 9849, 9854, 9857, 9865, 9879, 9931, 9951, 9954, 9959, 9970, 9996, 10526, 10527, 10544, 10552, 10573, 10579, 10588, 10592, 10602, 10609, 10632, 10648, 10652, 10700, 10718, 10724, 10762, 10781, 10919, 11118 | `Ortholog search` | `Cross-Species Gene Search` | Popup contexts, modal subtitle, status text |
| `server.R` | 10179 | `A homologous search is already running. Please wait for it to finish.` | `A multi-gene search is already running. Please wait for it to finish.` | Busy message |
| `server.R` | 10658 | `You currently have ortholog visualizations for gene` | `You currently have cross-species visualizations for gene` | Confirmation modal |
| `server.R` | 10664-10666 | `Ortholog search is designed to compare one gene across multiple organisms.` | `Cross-Species Gene Search is designed to compare one selected gene across multiple organisms.` | Confirmation modal |
| `server.R` | 10697 | `An ortholog search is already running. Please wait for it to finish.` | `A cross-species gene search is already running. Please wait for it to finish.` | Busy message |
| `server.R` | 12915 | `Could not build orthologous visualization container. Please retry the view mode switch.` | `Could not build the cross-species visualization container. Please retry the view mode switch.` | Warning alert |
| `server.R` | 15634, 15688, 16717 | `Load orthologous organism tracks first...` | `Load cross-species organism tracks first...` | LASTZ/MultiPIP guidance |
| `server.R` | 15799 | `No orthologous tracks loaded yet for LASTZ Block View.` | `No cross-species tracks loaded yet for LASTZ Block View.` | Empty-state copy |
| `server.R` | 15880 | `Load at least one non-reference orthologous track to run local comparisons.` | `Load at least one non-reference cross-species track to run local comparisons.` | LASTZ status panel |
| `server.R` | 16822 | `No orthologous tracks loaded yet for MultiPIP-style view.` | `No cross-species tracks loaded yet for MultiPIP-style view.` | Empty-state copy |
| `server.R` | 18379 | `Homologous` | `Multi-Gene` | Summary context header label |
| `server.R` | 18389 | `Orthologous` | `Cross-Species` | Summary context header label |
| `server.R` | 19014 | `Orthologous search` / `Homologous search` | `Cross-Species Gene Search` / `Multi-Gene Search` | Gene-function modal context |
| `server.R` | 21857 | `homolog_summary_` | `multi_gene_summary_` | Download filename stem |
| `server.R` | 21868 | `ortholog_summary_` | `cross_species_summary_` | Download filename stem |

## Phase 1: auxiliary visible labels

| File | Lines | Current text | Replace with | Notes |
| --- | --- | --- | --- | --- |
| `R/server_plot_lifecycle_domain.R` | 668-670 | `Homologous search` / `Orthologous search` | `Multi-Gene Search` / `Cross-Species Gene Search` | Shared panel display label used in UI actions |
| `Dockerfile` | 4 | `interactive Shiny app for ortholog analysis, GO enrichment, and genome comparison` | `interactive Shiny app for gene-centered comparative genomics, GO enrichment, and genome comparison` | Container metadata |

## Do not touch yet: internal identifiers

Leave these unchanged in the first pass:

- `ui.R`: `data-target="homologous"`, `data-target="orthologous"`, panel ids, `data-workflow-panel`, `value="homologous"`, `value="orthologous"`, output ids like `orthologous_plots_ui`
- `server.R`: reactive values, function names, observer names, mode routing, snapshot keys, panel keys, `finish_search_run("homologous")`, `finalize_search_cleanup("orthologous")`
- `R/server_state_helpers_domain.R`: mode validation against `c("homologous", "orthologous")`
- `R/server_session_snapshot_domain.R`: persisted workflow and panel keys
- `R/modules.R`: `plot_context = "homologous"` and `plot_context = "orthologous"`

## Suggested implementation order

1. `ui.R` visible labels and help copy
2. `server.R` popup, modal, status, summary-header, and filename strings
3. `R/server_plot_lifecycle_domain.R` shared display label
4. `Dockerfile` metadata

## Out of scope for this first pass

- Renaming functions, variables, output ids, or snapshot schema
- Replacing biological terms inside third-party datasets or GO files
- Any change to the actual comparison logic
