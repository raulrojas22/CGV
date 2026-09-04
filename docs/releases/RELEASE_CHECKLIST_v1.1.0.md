# CGV v1.1.0 release checklist

## Release identity

- [x] Web/App version: `1.1.0`
- [x] CGV Desktop version: `1.1.0`
- [x] User Manual edition: `1.1`
- [x] Citation, Zenodo, Docker, ShinyProxy, and Figure Studio metadata aligned
- [x] Figure Studio beta label removed

## Automated validation

- [x] Figure Studio static contract
- [x] User Manual publishing and integration contract
- [x] Release metadata consistency contract
- [x] R testthat session and source restoration suite
- [x] Theme, sequence export, render lifecycle, alias, lookup, PIP, and cache
      regression scripts
- [x] Desktop Node tests: 19/19
- [x] Desktop package guardrails
- [x] Bundled macOS scientific runtime verification

## Browser smoke

- [x] Generate a real Multi-Gene result
- [x] Open Figure Studio without a beta badge
- [x] Add one gene structure, one transcript with visible ID, and one Analytics
      chart
- [x] Preview the exact three-panel composition with title and subtitle
- [x] Clear the canvas and restore all three panels with Undo

## Installer handoff

Installer generation is intentionally not executed as part of the source RC.
Run it on each target platform after the RC branch is pushed and reviewed.

### macOS

```bash
npm --prefix desktop ci
npm --prefix desktop run build:mac:arm64
npm --prefix desktop run build:mac:x64
```

### Linux x64

```bash
npm --prefix desktop ci
npm --prefix desktop run build:linux:x64
```

### Windows x64 private beta

```bash
gh workflow run desktop-windows.yml \
  --repo raulrojas22/CGV \
  --ref codex/cgv-1.1.0-rc
```

### Windows x64 signed release

Create the immutable `desktop-v1.1.0` tag only after the private beta passes:

```bash
gh workflow run desktop-windows-release.yml \
  --repo raulrojas22/CGV \
  --ref desktop-v1.1.0 \
  -f create_release_draft=false
```

The signed workflow requires the configured SignPath secrets and manual signing
approval. It leaves release publication as an explicit later decision.
