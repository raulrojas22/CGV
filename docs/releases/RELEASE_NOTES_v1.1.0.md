# CGeV Web v1.1.0

CGeV Web v1.1.0 adds a stable figure workflow centered on Figure Studio and
improves export reliability across the Web and Desktop editions.

## Highlights

- Figure Studio is now a stable CGeV workspace rather than a beta feature.
- Build publication figures with a variable number of independent panels.
- Select gene structures, transcript variants, analytics, and eligible
  alignment views from an organized panel library.
- Use automatic chart-aware panel heights or intentional manual sizing.
- Preview the exact SVG composition before exporting.
- Export full-color, colorblind, paper-color, grayscale, or monochrome SVG and
  PNG figures.
- Save and restore Figure Studio drafts through CGeV work-session files.

## Export and workflow improvements

- Analytics and result charts can render for export without requiring every
  chart to be opened manually first.
- Analytics SVG ZIP exports report preparation progress while hidden charts
  render.
- Figure Studio identifies genes and transcript IDs in large result libraries.
- Tooltips and the guided workflow remain visible above all Studio surfaces.
- Temporary drafts are cleared on a normal reload and persist only through an
  explicitly saved CGeV session.

## Documentation

- Adds the CGeV User Manual Web and Desktop Edition v1.1.
- Publishes the current manual at the stable `docs/CGeV_User_Manual.pdf` path.
- Keeps a versioned manual archive for reproducible use and citation.

## Desktop

- The Desktop source has continued on its own release line and is currently
  version 1.2.2.
- Retains offline scientific runtimes and platform-specific package
  verification.
- Adds explicit macOS arm64, macOS x64, Linux x64, and Windows x64 runtime and
  packaging commands.
- Hardens Windows runtime construction with a locked Rtools44 installer,
  setup-msys2 root propagation, isolated R-package verification, and the
  direct official MSYS2 repository for `mman-win32`.
- Disables implicit Electron Builder publishing for every local package command.
- Public installers remain pending in the dedicated download repository;
  Windows packages also require the signed release workflow and SignPath approval.

## Validation

The release candidate is expected to pass:

- R source parsing and testthat session-restore tests;
- Figure Studio, theme, sequence-export, and manual integration guards;
- Desktop Node tests and package-configuration checks;
- bundled scientific runtime verification;
- a browser smoke test covering result generation, multi-panel composition,
  preview, state restoration, and export readiness.
