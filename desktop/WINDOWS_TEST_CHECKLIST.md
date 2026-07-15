# CGV Desktop Windows release checklist

Use this checklist for both Windows 10 x64 and Windows 11 x64. Test with a standard user account that does not have R, Docker, WSL, MSYS2, samtools, tabix, or LASTZ installed.

## Automated gate

- [ ] `CGV Desktop Windows x64 beta` workflow completes.
- [ ] Runtime lock verifies R 4.4.3, Bioconductor 3.20, package versions, and source/index hashes.
- [ ] LASTZ native build passes its upstream known alignment and the copied-runtime alignment test.
- [ ] NSIS silent install starts CGV, logs `CGV is ready`, and returns HTTP 200 from `127.0.0.1`.
- [ ] Normal window close leaves no bundled `R.exe`, `Rterm.exe`, or `Rscript.exe` process.
- [ ] Silent uninstall preserves the selected data folder.
- [ ] Node tests cover valid ZIP extraction, bad checksum, truncated ZIP, traversal, symbolic links, and download cancellation.

## Manual gate on each Windows version

- [ ] Assisted installer runs without an administrator prompt and allows a custom install directory.
- [ ] First launch requests a storage folder; cancelling leaves the launcher open and does not start R.
- [ ] A folder containing spaces and accented characters works for storage and restart.
- [ ] Multi-Gene Search, plots, exports, and saved sessions work.
- [ ] Homolog and ortholog searches render expected results.
- [ ] LASTZ alignment completes without any external tools installed.
- [ ] NCBI download completes through the Rsamtools fallback and produces usable GFF/Tabix and 2bit data.
- [ ] A catalog dataset downloads, verifies, installs, and appears in organism selectors.
- [ ] Cancelling a catalog download removes its `.part` file and a later retry succeeds.
- [ ] Installed datasets and caches survive app restart.
- [ ] `File > Change data folder` restarts into the new folder without moving or deleting the old folder.
- [ ] Direct-build update downloads and applies; Microsoft Store package uses Store updates only.
- [ ] Upgrade installation preserves datasets, caches, settings, and saved sessions.
- [ ] Uninstall removes the app and shortcuts but preserves the selected storage folder.
- [ ] Firewall inspection confirms the Shiny listener is bound only to `127.0.0.1`.

## Distribution gate

- [ ] Unsigned builds are shared only as limited beta artifacts.
- [ ] Public direct-download EXEs are signed through an approved SignPath configuration or another trusted certificate.
- [ ] If direct signing is unavailable, publish the AppX through Microsoft Store instead.
- [ ] The code signing policy, privacy policy, and third-party notices match the release behavior.
