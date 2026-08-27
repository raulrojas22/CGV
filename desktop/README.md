# CGeV Desktop v1.2.0

CGeV Desktop starts the Shiny app on a private localhost port and opens it in an
Electron window with its own scientific runtime and persistent data workspace.

Version 1.2.0 changes the operating-system-visible product name from
`CGV Desktop` to `CGeV Desktop`. Compatibility identifiers remain unchanged:
the Electron package is still `cgv-desktop`, the app ID is still
`org.cgv.desktop`, updates still use `CGV-Desktop-Releases`, and all supported
systems explicitly reuse the historical `CGV Desktop` user-data directory.

## Development

```bash
cd desktop
npm install
npm start
```

In development, CGeV Desktop uses the repository root as `CGV_DATA_ROOT` when it
finds `annotations/registry.tsv`. On the first packaged Windows launch, the user
selects a storage folder. CGeV stores genomes under `<storageRoot>/data`, caches
under `<storageRoot>/cache`, and the setting under
`%LOCALAPPDATA%\CGV Desktop\desktop-settings.json`.

Storage precedence is `CGV_DESKTOP_DATA_ROOT` / `CGV_DESKTOP_CACHE_ROOT`, then
the saved storage root, then the first-launch selector. If only one environment
override is set, the selector supplies the other root. Cancelling the selector
keeps the launcher open without starting Shiny. Changing the folder later does
not move or delete existing data.

The startup window hides R/Shiny internals by default and keeps them in a
diagnostics log instead. Use the launcher's "Open log file" button during
startup, or inspect the Electron user-data log directly. The old directory name
below is intentional and must not be renamed:

```text
macOS: ~/Library/Application Support/CGV Desktop/logs/startup.log
Linux: ~/.config/CGV Desktop/logs/startup.log
Windows: %LOCALAPPDATA%\CGV Desktop\logs\startup.log
```

## Windows x64 runtime

Windows 10/11 x64 is built natively and does not require R, Docker, WSL,
MSYS2, or administrator access on the end-user machine. Runtime construction
itself must run on Windows with Node.js 22 and MSYS2 MinGW64 packages `gcc`,
`make`, `diffutils`, `sed`, and `tar`. The runtime builder downloads and
SHA-256-verifies the locked `mman-win32` package itself:

```powershell
cd desktop
npm ci
npm test
npm run runtime:win
npm run build:win
```

`runtime:win` verifies the locked R and LASTZ downloads, fixed CRAN snapshot,
Bioconductor indexes, exact top-level package versions, native LASTZ tests, and
the runtime copied into a path containing spaces and accented characters. It
writes `resources/r/win32-x64/cgv-runtime-manifest.json`.

`build:win` creates an assisted, offline, per-user NSIS installer without
elevation. The output includes the stable setup EXE name, `latest.yml`, and
blockmap used by direct-build updates. The uninstaller preserves the storage
folder and installed datasets.

## Desktop Performance Defaults

CGeV Desktop starts the Shiny app with a conservative resource profile. It keeps
the first result responsive by rendering one card initially, auto-rendering
orthologous cards in small chunks, deferring sequence-heavy footer work until
after the first plot render, calculating feature-GC tooltips in the same
background pass, and disabling background lookup-worker prewarm and verbose
performance logging unless explicitly requested. Small cross-species searches
also stay sequential by default to avoid R worker startup overhead.

These defaults do not remove features; they delay heavier work until the first
plot is visible, then complete the remaining cards and sequence statistics
progressively. Power users can restore eager behavior when launching:

```bash
APP_ORTHO_AUTO_RENDER_MORE=1 \
APP_ORTHO_WORKER_PREWARM=0 \
APP_ORTHO_BACKGROUND_CACHE_WARM=0 \
APP_ORTHO_PREFLIGHT_SUGGESTIONS=0 \
APP_ORTHO_PREWARM_LOCAL_HANDLES=1 \
APP_ORTHO_PREFER_MAIN_CACHE=1 \
APP_ORTHO_LOOKUP_PARALLEL_MIN_JOBS=2 \
APP_HOMO_UPFRONT_ISOFORMS=0 \
APP_ORTHO_UPFRONT_ISOFORMS=0 \
APP_HOMO_DEFER_SEQUENCE=0 \
APP_ORTHO_DEFER_SEQUENCE=0 \
APP_FOOTER_DEFER_SEQUENCE=0 \
APP_DEFER_FEATURE_GC=0 \
npm start
```

For a benchmark/diagnostic run, enable detailed timing logs:

```bash
APP_PERF_TIMING=1 APP_SESSION_METRICS=1 npm start
```

## Portable Runtime Layout

For a fully self-contained build, generate the runtime for the target
architecture. These commands are intentionally separate from installer
generation because runtime construction is the slowest stage:

```bash
cd desktop
npm run runtime:mac:arm64  # Apple Silicon macOS
npm run runtime:mac:x64    # macOS x64; Rosetta 2 is required on Apple Silicon
npm run runtime:linux:x64  # Run on Linux x64 or in a Linux x64 build environment
npm run verify:config    # Fast build-config guardrails
npm run verify
```

The scripts write platform-specific runtime files here:

```text
desktop/resources/r/linux-x64/bin/Rscript
desktop/resources/r/darwin-arm64/bin/Rscript
desktop/resources/bin/linux-x64/lastz
desktop/resources/bin/darwin-arm64/lastz
```

The runtime includes R, CRAN/Bioconductor packages, `lastz`, `samtools`, and
`tabix`. Packaged releases must pass `npm run verify` against bundled files.

`prepare:lite` no longer clears the local Desktop profile by default, so local
dataset and annotation caches survive packaging runs. For a destructive clean
profile test build, launch with `CGV_DESKTOP_CLEAN_PROFILE=1 npm run prepare:lite`.

## Demo Data

Create a one-organism demo payload before packaging:

```bash
cd desktop
npm run prepare:demo -- homo_sapiens
```

The packaged build includes this demo payload only. Full genomes should be
delivered by a package catalog and downloaded into the user's local data folder.

## Dataset Catalog

CGeV Desktop supports an IGV-style lightweight catalog: the installer ships with
runtime + app + demo data, while full organisms are downloaded later from a NAS,
web server, or mounted `file://` location.

Build package files for organisms:

```bash
cd desktop
npm run dataset:package -- --species=homo_sapiens --version=2026.09
npm run dataset:package -- --species=mus_musculus --version=2026.09
CGV_DATASET_CATALOG_VERSION=2026.09 npm run dataset:catalog
```

This writes zip packages plus `desktop/dataset-packages/catalog.json`. The
catalog can use relative package URLs, so publishing is as simple as copying the
whole `dataset-packages/` directory to one NAS/web folder and pointing Desktop
at the catalog:

```bash
CGV_DESKTOP_CATALOG_URL=https://your-nas.example/cgv/datasets/catalog.json npm start
```

Or put that URL in `desktop/data-manifest.json` as `catalogUrl` before building
the installer. Desktop merges the bundled manifest and remote catalog, then
reports each organism as `bundled`, `not_installed`, `partial`, `installed`, or
`update_available`.

Package downloads are written as `.part`, verified by SHA-256, extracted into
`CGV_DATA_ROOT` with the built-in safe ZIP extractor, and recorded in
`desktop-datasets.json`. Absolute paths, drive paths, traversal, Windows device
names, and symbolic links are rejected. Active downloads can be cancelled and
partial files are removed. Existing valid installs are reused rather than
overwritten.

Validation commands:

```bash
npm run dataset:verify -- --package=dataset-packages/homo_sapiens_gcf_000001405_40_grch38_p14_genomic-2026.09.zip --manifest=dataset-packages/homo_sapiens_gcf_000001405_40_grch38_p14_genomic.manifest.json
npm run dataset:smoke -- --data-root=/path/to/extracted/data --species=homo_sapiens
npm run dataset:benchmark -- --data-root=/path/to/data --species=homo_sapiens
```

`CGV_CACHE_DIR`, `APP_ALIAS_DISK_CACHE_DIR`, and `CGV_NCBI_DOWNLOADS_DIR` remain
stable under the user's app-data folder in packaged builds, so second-use cache
hits survive app restarts.

Use `data-manifest.example.json` as the template for a real `data-manifest.json`
when the CDN URLs are ready.

## Packaging

The complete maintainer procedure for CGeV Desktop 1.2.0—including macOS,
GitHub Actions for Linux and signed Windows, GitHub draft publication, Oracle
upload, and the 1.1.0 → 1.2.0 compatibility test—is in
[`../GUIA-INSTALABLES.md`](../GUIA-INSTALABLES.md).

Installer commands use `--publish never`; generating a local package cannot
implicitly upload it from CI or create a GitHub release.

Lite installers do not embed the developer machine's global annotation cache.
Each downloadable organism package includes and installs its own precomputed
annotation index, keeping clean release builds reproducible across platforms.

```bash
cd desktop
npm ci
npm run build:mac:arm64
npm run build:mac:x64
```

Run Linux packaging on Linux x64:

```bash
cd desktop
npm ci
npm run build:linux:x64
```

A clean GitHub-hosted Linux x64 build is also available through
`.github/workflows/desktop-linux.yml`. It constructs the scientific runtime,
validates both package formats and uploads the AppImage, DEB and SHA-256 file
as one private workflow artifact.

macOS produces `.dmg` and `.zip`; Linux produces `AppImage` and `.deb`. Apple
signing/notarization remains a separate release step after the local installers
have been validated.

### Windows beta and Microsoft Store fallback

The Windows GitHub Actions workflow produces a private beta artifact and never
publishes or uploads a raw unsigned installer. Before using `workflow_dispatch`,
set the repository Actions secret `WINDOWS_BETA_ARTIFACT_PASSWORD`. The workflow
uploads only a header-encrypted 7z payload with 14-day retention. It builds the
scientific runtime, installer, and update metadata; installs the NSIS package
silently; waits for `CGeV is ready`; checks the localhost response; closes the
app; and confirms that no bundled R process remains.

To build locally on Windows x64 with Node.js 22 and the required MSYS2 MinGW64
packages:

```powershell
cd desktop
npm ci
npm test
npm run runtime:win
npm run build:win
```

For a Microsoft Store package, define these values and run `npm run build:store`:

```text
WINDOWS_STORE_IDENTITY_NAME
WINDOWS_STORE_PUBLISHER
WINDOWS_STORE_PUBLISHER_DISPLAY_NAME
```

Store builds produce AppX and do not use `electron-updater`. Direct Windows
builds use the GitHub update feed unless `CGV_DISABLE_AUTO_UPDATE=1` is set.

Before a public direct-download release, complete the SignPath Foundation
application and configure its signing policy. The repository includes the
[code signing policy](legal/CODE_SIGNING_POLICY.md),
[privacy policy](legal/PRIVACY.md), and
[third-party notices](legal/THIRD_PARTY_NOTICES.md) required for that review.
Run the [Windows 10/11 release checklist](WINDOWS_TEST_CHECKLIST.md) before
promoting any beta.
