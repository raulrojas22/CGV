cgv_desktop_asset_action <- function(kind, pending_label) {
  tags$a(
    class = "cgv-download-asset-action",
    `data-cgv-desktop-asset` = kind,
    `data-pending-label` = pending_label,
    href = "#",
    `aria-disabled` = "true",
    tabindex = "-1",
    tags$i(class = "fas fa-download", `aria-hidden` = "true"),
    tags$span(pending_label)
  )
}

cgv_desktop_downloads_page <- function() {
  section <- tags$section
  article <- tags$article
  ol <- tags$ol
  ul <- tags$ul
  dl <- tags$dl
  dt <- tags$dt
  dd <- tags$dd
  strong <- tags$strong

  div(
    id = "cgv-desktop-downloads-page",
    class = "content-wrapper app-main-pane cgv-download-page",
    `data-cgv-runtime` = "web",
    `data-cgv-web-url` = "https://cgev.mobilomics.org",
    section(
      class = "cgv-download-hero",
      div(class = "cgv-download-hero-glow cgv-download-hero-glow-one", `aria-hidden` = "true"),
      div(class = "cgv-download-hero-glow cgv-download-hero-glow-two", `aria-hidden` = "true"),
      div(
        class = "cgv-download-hero-inner",
        div(
          class = "cgv-download-context-pill",
          tags$i(class = "fas fa-globe", `data-cgv-context-icon` = "true", `aria-hidden` = "true"),
          span(`data-cgv-runtime-label` = "true", "CGeV Web")
        ),
        h1("Your CGeV workspace, ", span("wherever you work.")),
        p(
          class = "cgv-download-hero-copy",
          `data-cgv-hero-copy` = "true",
          "Run the complete Comparative Gene Viewer locally with the same searches, alignments, analytics, and exports you use on the web."
        ),
        div(
          class = "cgv-download-hero-actions",
          tags$a(
            id = "cgv-download-primary-action",
            class = "cgv-download-button cgv-download-button-primary",
            href = "#cgv-download-platforms",
            tags$i(class = "fas fa-download", `aria-hidden` = "true"),
            span(`data-cgv-primary-label` = "true", "View download options")
          ),
          tags$a(
            class = "cgv-download-button cgv-download-button-secondary",
            href = "#cgv-desktop-capabilities",
            tags$i(class = "fas fa-circle-play", `aria-hidden` = "true"),
            span("Explore Desktop")
          )
        ),
        div(
          class = "cgv-download-hero-facts",
          span(tags$i(class = "fas fa-shield-halved"), "Private local session"),
          span(tags$i(class = "fas fa-database"), "25 reference organisms"),
          span(tags$i(class = "fas fa-code-branch"), "Same CGeV workflows")
        ),
        div(
          class = "cgv-download-visual",
          `aria-label` = "Preview of the CGeV Desktop Multi-Gene Search workspace",
          div(
            class = "cgv-download-window",
            div(
              class = "cgv-download-window-bar",
              span(class = "cgv-download-window-dots", tags$i(), tags$i(), tags$i()),
              span("CGeV Desktop"),
              span(class = "cgv-download-window-local", tags$i(class = "fas fa-lock"), "Local")
            ),
            div(
              class = "cgv-download-window-body",
              div(
                class = "cgv-download-mini-sidebar",
                div(
                  class = "cgv-download-mini-brand",
                  span(class = "cgv-download-mini-mark", tags$i(class = "fas fa-dna")),
                  div(strong("CGeV"), tags$small("Comparative Gene Viewer"))
                ),
                div(
                  class = "cgv-download-mini-nav",
                  span(tags$i(class = "fas fa-house"), "Home"),
                  span(class = "is-active", tags$i(class = "fas fa-dna"), "Multi-Gene Search"),
                  span(tags$i(class = "fas fa-sitemap"), "Cross-Species"),
                  span(tags$i(class = "fas fa-image"), "Figure Studio"),
                  span(tags$i(class = "fas fa-route"), "CGeV Guide")
                ),
                span(class = "cgv-download-mini-desktop", tags$i(class = "fas fa-laptop"), "CGeV Desktop")
              ),
              div(
                class = "cgv-download-mini-canvas",
                div(
                  class = "cgv-download-mini-control-panel",
                  div(
                    class = "cgv-download-mini-heading",
                    div(
                      span("SEARCH TYPE"),
                      strong("Multi-Gene"),
                      tags$em(tags$i(class = "fas fa-seedling"), "Oryza sativa ssp. japonica")
                    ),
                    span(class = "cgv-download-mini-count", "Genes: 7")
                  ),
                  div(
                    class = "cgv-download-mini-modes",
                    div(
                      class = "cgv-download-mini-context",
                      tags$small("CONTEXT"),
                      span(class = "is-neighbor", tags$i(class = "fas fa-location-arrow"), "Neighbors"),
                      span(class = "is-overlap", tags$i(class = "fas fa-layer-group"), "Overlaps")
                    ),
                    span(class = "is-active", tags$i(class = "fas fa-eye"), strong("Visualize mode"), tags$small("Explore gene models")),
                    span(tags$i(class = "fas fa-project-diagram"), strong("Alignment mode"), tags$small("Compare transcripts"))
                  )
                ),
                div(
                  class = "cgv-download-mini-toolbar",
                  span(class = "is-dark", tags$i(class = "fas fa-chart-bar"), "Show Analytics"),
                  span(class = "is-teal", tags$i(class = "fas fa-play"), "Show Summary Table"),
                  span(tags$i(class = "fas fa-download"), "CSV"),
                  span(tags$i(class = "fas fa-file-archive"), "Result SVGs")
                ),
                div(
                  class = "cgv-download-gene-results",
                  div(
                    class = "cgv-download-gene-card",
                    div(
                      class = "cgv-download-gene-head",
                      div(
                        span(class = "cgv-download-species-mark", tags$i(class = "fas fa-seedling")),
                        tags$em("Oryza sativa ssp. japonica"),
                        tags$i(),
                        strong("Gene: LOC112938776"),
                        tags$i(),
                        tags$b("Chr: 4")
                      ),
                      div(
                        span(class = "is-purple", "Function"),
                        span(class = "is-pink", "Network"),
                        span(class = "is-cyan", "GO"),
                        span(class = "is-blue", "NCBI"),
                        span(class = "is-close", tags$i(class = "fas fa-xmark"))
                      )
                    ),
                    div(
                      class = "cgv-download-gene-plot",
                      div(class = "cgv-download-plot-scale", span("≥100 kb"), span("10 kb"), span("1 kb"), span("31.2320 Mb"), span("31.2335 Mb")),
                      div(class = "cgv-download-context-line", span(class = "left-neighbor"), span(class = "focus-region"), span(class = "right-neighbor")),
                      div(class = "cgv-download-transcript-line", span(class = "arrow-left"), span(class = "exon e1"), span(class = "exon e2"), span(class = "exon e3"), span(class = "arrow-right"))
                    ),
                    div(
                      class = "cgv-download-gene-metrics",
                      span("5 transcripts"),
                      span("Gene length ", strong("2,690 bp")),
                      span("Transcript length ", strong("2,623 bp")),
                      span("Sequence composition ", tags$b(class = "base-a", "A"), " 30.07% ", tags$b(class = "base-t", "T"), " 29.29%")
                    )
                  ),
                  div(
                    class = "cgv-download-gene-card cgv-download-gene-card-alt",
                    div(
                      class = "cgv-download-gene-head",
                      div(
                        span(class = "cgv-download-species-mark", tags$i(class = "fas fa-seedling")),
                        tags$em("Oryza sativa ssp. japonica"),
                        tags$i(),
                        strong("Gene: LOC4328465"),
                        tags$i(),
                        tags$b("Chr: 2")
                      ),
                      div(
                        span(class = "is-purple", "Function"),
                        span(class = "is-pink", "Network"),
                        span(class = "is-cyan", "GO"),
                        span(class = "is-blue", "NCBI"),
                        span(class = "is-close", tags$i(class = "fas fa-xmark"))
                      )
                    ),
                    div(
                      class = "cgv-download-gene-plot",
                      div(class = "cgv-download-plot-scale", span("≥100 kb"), span("10 kb"), span("1 kb"), span("4.1125 Mb"), span("4.1148 Mb")),
                      div(class = "cgv-download-context-line", span(class = "left-neighbor"), span(class = "focus-region"), span(class = "right-neighbor")),
                      div(class = "cgv-download-transcript-line", span(class = "arrow-left"), span(class = "exon e1"), span(class = "exon e2"), span(class = "exon e3"), span(class = "arrow-right"))
                    ),
                    div(
                      class = "cgv-download-gene-metrics",
                      span("3 transcripts"),
                      span("Gene length ", strong("2,271 bp")),
                      span("Transcript length ", strong("2,271 bp")),
                      span("Sequence composition ", tags$b(class = "base-a", "A"), " 30.25% ", tags$b(class = "base-t", "T"), " 30.52%")
                    )
                  )
                )
              )
            )
          )
        )
      )
    ),
    section(
      class = "cgv-download-section cgv-download-platform-section",
      id = "cgv-download-platforms",
      div(
        class = "cgv-download-section-heading",
        div(
          span(class = "cgv-download-eyebrow", "Choose your platform"),
          h2("One workspace. Three operating systems."),
          p("CGeV checks this device and highlights the best match. Download buttons activate only for installers listed with a verified SHA-256 checksum in the official public release manifest.")
        ),
        div(
          id = "cgv-download-release-status",
          class = "cgv-download-release-status is-checking",
          role = "status",
          `aria-live` = "polite",
          tags$i(class = "fas fa-spinner fa-spin"),
          span("Checking public installer availability…")
        )
      ),
      div(
        class = "cgv-download-platform-grid",
        article(
          class = "cgv-download-platform-card",
          `data-cgv-platform-card` = "mac",
          div(class = "cgv-download-recommended-badge", tags$i(class = "fas fa-wand-magic-sparkles"), span("Recommended for this device")),
          div(
            class = "cgv-download-platform-head",
            span(class = "cgv-download-platform-icon", tags$i(class = "fab fa-apple")),
            span(class = "cgv-download-platform-state", "Installer pending")
          ),
          span(class = "cgv-download-platform-kicker", "Desktop"),
          h3("macOS"),
          p("Native DMG builds for Apple Silicon and Intel Macs, with the complete local analysis runtime included."),
          div(
            class = "cgv-download-asset-list",
            div(
              class = "cgv-download-asset-row",
              div(strong("Apple Silicon"), span("M1, M2, M3, M4 and newer · arm64")),
              cgv_desktop_asset_action("mac-arm64", "DMG pending")
            ),
            div(
              class = "cgv-download-asset-row",
              div(strong("Intel Mac"), span("64-bit Intel processors · x64")),
              cgv_desktop_asset_action("mac-x64", "DMG pending")
            )
          ),
          tags$details(
            class = "cgv-download-install-guide",
            tags$summary(tags$i(class = "fas fa-circle-info"), "How to open CGeV on macOS"),
            ol(
              tags$li("Download the correct DMG and drag CGeV Desktop into Applications."),
              tags$li("Try to open it once. If macOS blocks it, open System Settings → Privacy & Security."),
              tags$li("Choose Open Anyway for CGeV Desktop, then confirm Open.")
            ),
            p("This manual approval is expected while the macOS build is distributed without paid Apple notarization.")
          )
        ),
        article(
          class = "cgv-download-platform-card",
          `data-cgv-platform-card` = "linux",
          div(class = "cgv-download-recommended-badge", tags$i(class = "fas fa-wand-magic-sparkles"), span("Recommended for this device")),
          div(
            class = "cgv-download-platform-head",
            span(class = "cgv-download-platform-icon", tags$i(class = "fab fa-linux")),
            span(class = "cgv-download-platform-state", "Installer pending")
          ),
          span(class = "cgv-download-platform-kicker", "Desktop"),
          h3("Linux"),
          p("Portable and package-based x86_64 builds for common Linux distributions, with no system R installation required."),
          div(
            class = "cgv-download-asset-list",
            div(
              class = "cgv-download-asset-row",
              div(strong("AppImage"), span("Portable · recommended for most distributions")),
              cgv_desktop_asset_action("linux-appimage", "AppImage pending")
            ),
            div(
              class = "cgv-download-asset-row",
              div(strong("Debian / Ubuntu"), span("Installable x86_64 DEB package")),
              cgv_desktop_asset_action("linux-deb", "DEB pending")
            )
          ),
          tags$details(
            class = "cgv-download-install-guide",
            tags$summary(tags$i(class = "fas fa-terminal"), "Linux installation notes"),
            ul(
              tags$li("AppImage: mark the downloaded file as executable, then open it. FUSE may be required on some distributions."),
              tags$li("Debian / Ubuntu: open the DEB with your package manager or install it from a terminal."),
              tags$li("The bundled runtime means you do not need to install R separately.")
            )
          )
        ),
        article(
          class = "cgv-download-platform-card",
          `data-cgv-platform-card` = "windows",
          div(class = "cgv-download-recommended-badge", tags$i(class = "fas fa-wand-magic-sparkles"), span("Recommended for this device")),
          div(
            class = "cgv-download-platform-head",
            span(class = "cgv-download-platform-icon", tags$i(class = "fab fa-windows")),
            span(class = "cgv-download-platform-state", "Installer pending")
          ),
          span(class = "cgv-download-platform-kicker", "Desktop"),
          h3("Windows"),
          p("A Windows x64 installer with the same private local runtime and CGeV workflows."),
          div(
            class = "cgv-download-asset-list",
            div(
              class = "cgv-download-asset-row",
              div(strong("Windows x64"), span("Windows 10 and 11 · x64 setup")),
              cgv_desktop_asset_action("windows-x64", "Setup pending")
            )
          ),
          tags$details(
            class = "cgv-download-install-guide",
            tags$summary(tags$i(class = "fab fa-windows"), "Windows installation notes"),
            ul(
              tags$li("Download the x64 setup from this page."),
              tags$li("Windows may show a Microsoft Defender SmartScreen warning because this release does not use a commercial code-signing certificate."),
              tags$li("If the warning appears, choose More info, verify that the file name begins with CGeV-Desktop, then choose Run anyway."),
              tags$li("Follow the installation wizard for your Windows account."),
              tags$li("CGeV Desktop stores its runtime and workspace locally on your computer.")
            )
          )
        )
      )
    ),
    section(
      class = "cgv-download-section cgv-download-capabilities",
      id = "cgv-desktop-capabilities",
      div(
        class = "cgv-download-section-heading cgv-download-section-heading-centered",
        div(
          span(class = "cgv-download-eyebrow", "Built for local comparative genomics"),
          h2("The complete CGeV experience, on your machine."),
          p("Desktop is not a reduced companion. It packages the same analysis interface and adds persistent local data management.")
        )
      ),
      div(
        class = "cgv-download-feature-grid",
        div(class = "cgv-download-feature", span(tags$i(class = "fas fa-dna")), h3("Multi-Gene Search"), p("Compare genes within one organism and align isoforms when a gene has multiple transcripts.")),
        div(class = "cgv-download-feature", span(tags$i(class = "fas fa-sitemap")), h3("Cross-Species Search"), p("Inspect homologous structures, synteny, LASTZ blocks, and MultiPIP-style conservation.")),
        div(class = "cgv-download-feature", span(tags$i(class = "fas fa-lightbulb")), h3("Smarter gene discovery"), p("Use gene suggestions, alias resolution, and disambiguation when several records share a name.")),
        div(class = "cgv-download-feature", span(tags$i(class = "fas fa-chart-column")), h3("Figures and analytics"), p("Generate structural plots, sequence metrics, context charts, tables, and publication-ready exports.")),
        div(class = "cgv-download-feature", span(tags$i(class = "fas fa-file-code")), h3("Local interactive reports"), p("Save a self-contained read-only HTML report and reproducibility ZIP for sharing without uploading the analysis to a server.")),
        div(class = "cgv-download-feature", span(tags$i(class = "fas fa-database")), h3("25-organism catalog"), p("Install only the curated animal, plant, and fungal references needed for your work.")),
        div(class = "cgv-download-feature", span(tags$i(class = "fas fa-folder-open")), h3("Persistent workspace"), p("Keep downloaded organisms, generated caches, settings, and saved sessions between launches."))
      )
    ),
    section(
      class = "cgv-download-section cgv-download-local-section",
      div(
        class = "cgv-download-local-card",
        div(
          class = "cgv-download-local-copy",
          span(class = "cgv-download-eyebrow", "Local by design"),
          h2("Your analyses stay in a private session on your computer."),
          p("CGeV Desktop starts its own local Shiny service and opens it only inside the desktop application. Reference datasets and caches are stored in your user profile, where they remain available for later work. Interactive reports are written only to locations you choose through the operating-system save dialog."),
          div(
            class = "cgv-download-local-points",
            span(tags$i(class = "fas fa-lock"), "Private localhost session"),
            span(tags$i(class = "fas fa-hard-drive"), "User-controlled storage"),
            span(tags$i(class = "fas fa-cloud-arrow-down"), "Organisms installed on demand"),
            span(tags$i(class = "fas fa-file-code"), "Local HTML reports; no public URL"),
            span(tags$i(class = "fas fa-rotate"), "Reusable local caches")
          )
        ),
        div(
          class = "cgv-download-local-diagram",
          div(class = "cgv-download-local-node is-main", tags$i(class = "fas fa-laptop"), strong("CGeV Desktop"), span("Private local app")),
          div(class = "cgv-download-local-line"),
          div(
            class = "cgv-download-local-stack",
            div(class = "cgv-download-local-node", tags$i(class = "fas fa-flask"), strong("Analysis runtime"), span("Bundled tools")),
            div(class = "cgv-download-local-node", tags$i(class = "fas fa-database"), strong("Reference library"), span("25 organisms")),
            div(class = "cgv-download-local-node", tags$i(class = "fas fa-folder-tree"), strong("Your workspace"), span("Data and sessions"))
          )
        )
      )
    ),
    section(
      class = "cgv-download-section cgv-download-info-grid",
      article(
        class = "cgv-download-info-card",
        span(class = "cgv-download-eyebrow", "System requirements"),
        h2("Before you install"),
        div(class = "cgv-download-requirement", tags$i(class = "fab fa-apple"), div(strong("macOS"), span("64-bit Apple Silicon or Intel Mac; approve first launch in Privacy & Security when required."))),
        div(class = "cgv-download-requirement", tags$i(class = "fab fa-linux"), div(strong("Linux"), span("64-bit x86_64 system; AppImage or Debian/Ubuntu package support."))),
        div(class = "cgv-download-requirement", tags$i(class = "fab fa-windows"), div(strong("Windows"), span("Windows 10 or 11 on x64 hardware."))),
        div(class = "cgv-download-requirement", tags$i(class = "fas fa-hard-drive"), div(strong("Storage"), span("Allow at least 2 GB for the app, plus space for the reference organisms you install.")))
      ),
      article(
        class = "cgv-download-info-card cgv-download-release-card",
        span(class = "cgv-download-eyebrow", "Current release"),
        h2(`data-cgv-release-title` = "true", "Public installers pending"),
        p(`data-cgv-release-copy` = "true", "The download center reads the official CGeV Desktop release manifest and enables only the verified assets that are actually public."),
        dl(
          div(dt("Version"), dd(`data-cgv-release-version` = "true", "Not published")),
          div(dt("Published"), dd(`data-cgv-release-date` = "true", "—")),
          div(dt("Platforms"), dd(`data-cgv-release-platforms` = "true", "Waiting for assets"))
        ),
        h3(class = "cgv-download-release-notes-title", "Release notes"),
        tags$ul(
          class = "cgv-download-release-notes",
          `data-cgv-release-notes` = "true",
          tags$li("Release notes will appear here when the first public installers are published.")
        ),
        div(
          class = "cgv-download-release-links",
          tags$a(
            class = "cgv-download-release-link",
            `data-cgv-release-center` = "true",
            href = "https://github.com/raulrojas22/CGV-Desktop-Releases/releases",
            target = "_blank",
            rel = "noopener noreferrer",
            tags$i(class = "fas fa-file-shield"),
            span("Open release manifest"),
            tags$i(class = "fas fa-arrow-up-right-from-square")
          ),
          tags$a(
            class = "cgv-download-release-link",
            href = "https://github.com/raulrojas22/CGV-Desktop-Releases/blob/master/CODE_SIGNING_POLICY.md",
            target = "_blank",
            rel = "noopener noreferrer",
            tags$i(class = "fas fa-signature"),
            span("Code signing policy"),
            tags$i(class = "fas fa-arrow-up-right-from-square")
          ),
          tags$a(
            class = "cgv-download-release-link",
            href = "https://github.com/raulrojas22/CGV-Desktop-Releases/blob/master/PRIVACY.md",
            target = "_blank",
            rel = "noopener noreferrer",
            tags$i(class = "fas fa-user-shield"),
            span("Privacy policy"),
            tags$i(class = "fas fa-arrow-up-right-from-square")
          )
        )
      )
    ),
    section(
      class = "cgv-download-section cgv-download-web-card",
      div(
        span(class = "cgv-download-web-icon", tags$i(class = "fas fa-globe")),
        div(
          span(class = "cgv-download-eyebrow", "CGeV Web"),
          h2(`data-cgv-web-title` = "true", "Already working in your browser?"),
          p(`data-cgv-web-copy` = "true", "Continue with the hosted application when you prefer server-managed references and no local installation.")
        )
      ),
      tags$a(
        class = "cgv-download-button cgv-download-button-secondary",
        href = "https://cgev.mobilomics.org",
        target = "_blank",
        rel = "noopener noreferrer",
        tags$i(class = "fas fa-arrow-up-right-from-square"),
        span("Open CGeV Web")
      )
    )
  )
}
