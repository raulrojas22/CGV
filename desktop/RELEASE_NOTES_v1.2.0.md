# CGeV Desktop 1.2.0

This release adopts the operating-system-visible name **CGeV Desktop** for the
Comparative Gene Viewer.

## What changed

- Application, installer, shortcuts, Programs list, and new artifact filenames
  now display `CGeV Desktop`.
- New installer files use the prefix `CGeV-Desktop-`.

## Compatibility

- Existing settings, sessions, datasets, caches, logs, and selected storage
  roots continue to use the historical `CGV Desktop` application-data folder.
- The internal package name remains `cgv-desktop` and the application ID remains
  `org.cgv.desktop`.
- Updates continue through the existing `CGV-Desktop-Releases` repository.
- Existing `CGV_*` environment variables and `cgv-*` internal interfaces remain
  supported.

No migration or manual data move is required.
