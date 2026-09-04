const fs = require("fs");
const path = require("path");

const desktopRoot = path.resolve(__dirname, "..");
const repoRoot = path.resolve(desktopRoot, "..");
const packageJsonPath = path.join(desktopRoot, "package.json");
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
const mainJsPath = path.join(desktopRoot, "src", "main.js");
const mainJs = fs.readFileSync(mainJsPath, "utf8");
const legacyUserDataPath = path.join(desktopRoot, "src", "legacy-user-data.js");
const legacyUserData = fs.readFileSync(legacyUserDataPath, "utf8");
const downloadJsPath = path.join(repoRoot, "www", "js", "cgv_desktop_downloads.js");
const downloadUiPath = path.join(repoRoot, "R", "ui_desktop_downloads.R");
const installerScriptPath = path.join(repoRoot, "regenerar-instalables.sh");
const storeConfigPath = path.join(desktopRoot, "electron-builder.store.js");

const extraResources = (((packageJson || {}).build || {}).extraResources || []);
const afterPack = (((packageJson || {}).build || {}).afterPack || "");
const build = packageJson.build || {};
const win = build.win || {};
const nsis = build.nsis || {};
const mac = build.mac || {};
const linux = build.linux || {};
const publish = build.publish || {};
const appResource = extraResources.find((entry) => entry && entry.to === "app");
const windowIconResource = extraResources.find((entry) => entry && entry.to === "icon.png");
const filters = Array.isArray(appResource && appResource.filter) ? appResource.filter : [];

if (packageJson.name !== "cgv-desktop" || build.appId !== "org.cgv.desktop") {
  throw new Error("The internal package name and appId must remain cgv-desktop and org.cgv.desktop for upgrade compatibility.");
}
if (build.productName !== "CGeV Desktop") {
  throw new Error("The operating-system-visible product name must be CGeV Desktop.");
}
const storeConfig = fs.readFileSync(storeConfigPath, "utf8");
for (const fragment of [
  'applicationId: "CGVDesktop"',
  'displayName: "CGeV Desktop"',
  'artifactName: "CGeV-Desktop-${version}-Windows-${arch}-Store.${ext}"'
]) {
  if (!storeConfig.includes(fragment)) {
    throw new Error(`Microsoft Store identity configuration is missing: ${fragment}`);
  }
}
if (
  !mainJs.includes('const DESKTOP_APP_ID = "org.cgv.desktop"') ||
  !mainJs.includes("app.setAppUserModelId(DESKTOP_APP_ID)") ||
  !mainJs.includes('electronApp.setPath("userData", legacyUserDataPath({') ||
  !legacyUserData.includes('LEGACY_USER_DATA_DIRECTORY = "CGV Desktop"')
) {
  throw new Error("CGeV Desktop must keep the stable Windows app ID and historical user-data directory.");
}

if (filters.includes("cache/annotation_index/**")) {
  throw new Error("Lite Desktop builds must not embed a developer-machine annotation cache; dataset packages install their own precomputed indexes.");
}

if (afterPack !== "scripts/trim-packaged-runtime.js") {
  throw new Error("Desktop build must trim non-target runtimes after packaging.");
}

const expectedVersions = {
  electron: "42.6.1",
  "electron-builder": "26.15.3",
  "electron-updater": "6.8.9",
  "js-yaml": "4.3.2"
};
for (const [dependency, version] of Object.entries(expectedVersions)) {
  const actual = packageJson.devDependencies?.[dependency] || packageJson.dependencies?.[dependency];
  if (actual !== version) throw new Error(`${dependency} must be pinned to ${version}; found ${actual || "missing"}.`);
}

if (packageJson.repository?.url !== "https://github.com/raulrojas22/CGeV") {
  throw new Error("Desktop source metadata must point to the canonical public CGeV source repository.");
}
if (packageJson.homepage !== "https://cgev.mobilomics.org") {
  throw new Error("Desktop homepage metadata must point to the official CGV Web deployment.");
}
if (
  publish.provider !== "github" ||
  publish.owner !== "raulrojas22" ||
  publish.repo !== "CGV-Desktop-Releases"
) {
  throw new Error("Desktop updates and installer publication must use raulrojas22/CGV-Desktop-Releases exclusively.");
}
if (publish.releaseType !== "draft") {
  throw new Error("Desktop packaging must create draft releases so installers can be reviewed before publication.");
}
if (mac.artifactName !== "CGeV-Desktop-${version}-macOS-${arch}.${ext}") {
  throw new Error("New macOS artifacts must use the CGeV Desktop release filename.");
}
if (linux.artifactName !== "CGeV-Desktop-${version}-Linux-${arch}.${ext}") {
  throw new Error("New Linux artifacts must use the CGeV Desktop release filename.");
}
if (
  !windowIconResource ||
  windowIconResource.from !== "build/icon.png" ||
  !fs.existsSync(path.join(desktopRoot, windowIconResource.from))
) {
  throw new Error("Desktop packages must include the CGV PNG used by the native application window.");
}
if (linux.syncDesktopName !== true || linux.desktop?.entry?.StartupWMClass !== "cgv-desktop") {
  throw new Error("Linux desktop metadata must match Electron's cgv-desktop window class.");
}
for (const requiredMainFragment of [
  "icon: windowIconPath()",
  "findRscript(preparedRuntimeRoot)",
  "APP_LASTZ_WORKERS: process.env.APP_LASTZ_WORKERS || String(Math.max(1, Math.min(2, os.cpus().length - 1)))",
  "APP_LASTZ_TIMEOUT_SECONDS: process.env.APP_LASTZ_TIMEOUT_SECONDS || \"90\"",
  "APP_MEMORY_CACHE_BUDGET_MB: process.env.APP_MEMORY_CACHE_BUDGET_MB || \"1024\"",
  "APP_SEQ_EXTRACT_CACHE_MAX_MB: process.env.APP_SEQ_EXTRACT_CACHE_MAX_MB || \"256\"",
  "APP_SPLICED_SEQ_CACHE_MAX_MB: process.env.APP_SPLICED_SEQ_CACHE_MAX_MB || \"192\"",
  "APP_ALIAS_SQLITE_CACHE_MB: process.env.APP_ALIAS_SQLITE_CACHE_MB || \"16\"",
  "APP_ALIAS_SQLITE_MAX_CONNECTIONS: process.env.APP_ALIAS_SQLITE_MAX_CONNECTIONS || \"8\"",
  "env.FONTCONFIG_FILE = fontconfigFile",
  "env.FONTCONFIG_PATH = fontconfigPath"
]) {
  if (!mainJs.includes(requiredMainFragment)) {
    throw new Error(`Desktop runtime safety configuration is missing: ${requiredMainFragment}`);
  }
}
for (const releaseSurfacePath of [downloadJsPath, downloadUiPath]) {
  if (!fs.existsSync(releaseSurfacePath)) {
    throw new Error(`Missing Desktop release surface: ${releaseSurfacePath}`);
  }
  const releaseSurface = fs.readFileSync(releaseSurfacePath, "utf8");
  if (!releaseSurface.includes("raulrojas22/CGV-Desktop-Releases/releases")) {
    throw new Error(`${path.basename(releaseSurfacePath)} must link to the dedicated CGV Desktop release repository.`);
  }
  if (releaseSurface.includes("raulrojas22/CGV/releases")) {
    throw new Error(`${path.basename(releaseSurfacePath)} must not fall back to releases from the CGV source repository.`);
  }
}
const expectedRuntimeScripts = {
  "runtime:mac:arm64": "bash scripts/build-runtime-macos-arm64.sh",
  "runtime:mac:x64": "bash scripts/build-runtime-macos-x64.sh",
  "runtime:linux:x64": "bash scripts/build-runtime-linux-x64.sh",
  "runtime:win": "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build-runtime-windows-x64.ps1"
};
for (const [scriptName, expectedCommand] of Object.entries(expectedRuntimeScripts)) {
  if (packageJson.scripts?.[scriptName] !== expectedCommand) {
    throw new Error(`${scriptName} must invoke the supported platform runtime builder.`);
  }
}
for (const buildScript of [
  "build",
  "build:mac",
  "build:mac:arm64",
  "build:mac:x64",
  "build:linux",
  "build:linux:x64",
  "build:win",
  "build:store"
]) {
  if (!/(?:^|\s)--publish(?:\s+|=)never(?:\s|$)/.test(String(packageJson.scripts?.[buildScript] || ""))) {
    throw new Error(`${buildScript} must disable electron-builder implicit publishing.`);
  }
}
if (!mainJs.includes("autoUpdater.checkForUpdatesAndNotify()") || !mainJs.includes("isDirectWindowsBuild")) {
  throw new Error("Direct Windows builds must check the electron-builder update feed automatically.");
}
if (!/CGV_RUNTIME:\s*[\"']desktop[\"']/.test(mainJs)) {
  throw new Error("The local Shiny process must be marked as CGV Desktop so report exports never publish a Web URL.");
}
if (!mainJs.includes("CGV_RELEASE_VERSION: app.getVersion()")) {
  throw new Error("The embedded CGeV UI must display the Desktop package version.");
}
if (!mainJs.includes('exportDownloadSession.on("will-download"') || !mainJs.includes("setSaveDialogOptions")) {
  throw new Error("Desktop exports must use the operating-system save dialog.");
}

const winTargets = Array.isArray(win.target) ? win.target : [];
const nsisTarget = winTargets.find((target) => target && target.target === "nsis");
if (!nsisTarget || !Array.isArray(nsisTarget.arch) || nsisTarget.arch.join(",") !== "x64") {
  throw new Error("Windows builds must target NSIS x64 only.");
}
if (win.requestedExecutionLevel !== "asInvoker" || nsis.oneClick !== false || nsis.perMachine !== false || nsis.allowElevation !== false) {
  throw new Error("Windows NSIS must be an assisted, per-user, non-elevated installer.");
}
if (nsis.allowToChangeInstallationDirectory !== true || nsis.deleteAppDataOnUninstall !== false) {
  throw new Error("Windows NSIS must allow an install-directory choice and preserve app data on uninstall.");
}
if (nsis.artifactName !== "CGeV-Desktop-${version}-Windows-${arch}-Setup.${ext}") {
  throw new Error("Windows NSIS artifact name must be stable and architecture-specific.");
}
if (
  win.signExecutable !== false ||
  win.verifyUpdateCodeSignature !== true ||
  win.signtoolOptions?.publisherName !== "SignPath Foundation"
) {
  throw new Error("Windows packaging must remain unsigned before SignPath and require SignPath Foundation for update verification.");
}
if (!fs.existsSync(path.resolve(desktopRoot, win.icon || ""))) {
  throw new Error(`Windows icon is missing: ${win.icon || "not configured"}.`);
}
if (nsis.packElevateHelper !== false || nsis.license !== "../LICENSE" || nsis.include !== "build/installer.nsh") {
  throw new Error("Windows NSIS must force current-user install, omit the elevation helper, and display the project license.");
}
const nsisInclude = fs.readFileSync(path.join(desktopRoot, "build", "installer.nsh"), "utf8");
if (!/StrCpy\s+\$isForceCurrentInstall\s+"1"/.test(nsisInclude)) {
  throw new Error("Windows NSIS custom install mode must force current-user installation.");
}
if (!mainJs.includes('host=\'127.0.0.1\'')) {
  throw new Error("Desktop Shiny must listen on 127.0.0.1 only.");
}
if (/execFile\([^\n]*["']unzip["']/.test(mainJs)) {
  throw new Error("Desktop dataset extraction must not invoke an external unzip command.");
}

const windowsLockPath = path.join(desktopRoot, "runtime-windows-lock.json");
const windowsLock = JSON.parse(fs.readFileSync(windowsLockPath, "utf8"));
if (
  windowsLock.platform !== "win32-x64" ||
  windowsLock.r?.version !== "4.4.3" ||
  windowsLock.rtools44?.version !== "6459-6401" ||
  windowsLock.rtools44?.toolchainVersion !== "6459" ||
  windowsLock.rtools44?.distribution !== "installer" ||
  windowsLock.bioconductorVersion !== "3.20"
) {
  throw new Error("Windows runtime lock must pin win32-x64, R 4.4.3, Rtools44 6459-6401 with toolchain 6459, and Bioconductor 3.20.");
}
const lockedArtifacts = [windowsLock.r, windowsLock.rtools44, windowsLock.lastz, windowsLock.mmanWin32];
for (const artifact of lockedArtifacts) {
  if (!/^https:\/\//.test(artifact?.url || "") || !/^[a-f0-9]{64}$/.test(artifact?.sha256 || "")) {
    throw new Error("Windows runtime artifacts must have HTTPS URLs and SHA-256 hashes.");
  }
}
if (!/^https:\/\/github\.com\/r-hub\/rtools44\/releases\/download\/6459-6401\/rtools44\.exe$/.test(windowsLock.rtools44.url)) {
  throw new Error("Windows runtime must use the fixed, checksum-locked Rtools44 installer mirror.");
}
const windowsRuntimeBuilderPath = path.join(desktopRoot, "scripts", "build-runtime-windows-x64.ps1");
const windowsRtoolsVerifierPath = path.join(desktopRoot, "scripts", "verify-windows-rtools.R");
const windowsRuntimeBuilder = fs.readFileSync(windowsRuntimeBuilderPath, "utf8");
if (
  !fs.existsSync(windowsRtoolsVerifierPath) ||
  !windowsRuntimeBuilder.includes("R_CUSTOM_TOOLS_SOFT") ||
  !windowsRuntimeBuilder.includes("R_CUSTOM_TOOLS_PATH") ||
  !windowsRuntimeBuilder.includes("MsysMake") ||
  !windowsRuntimeBuilder.includes("MsysGcc") ||
  !windowsRuntimeBuilder.includes("/MERGETASKS=!recordversion,!createStartMenu") ||
  !windowsRuntimeBuilder.includes("verify-windows-rtools.R")
) {
  throw new Error("Windows runtime build must isolate and verify the locked Rtools44 toolchain.");
}
if (!/^\d{4}-\d{2}-\d{2}$/.test(windowsLock.cranRepository?.snapshotDate || "") || !/^https:\/\//.test(windowsLock.cranRepository?.url || "") || !/^[a-f0-9]{64}$/.test(windowsLock.cranRepository?.windowsR44IndexSha256 || "")) {
  throw new Error("Windows CRAN snapshot and binary index hash must be pinned.");
}
const bioconductorIndexes = windowsLock.bioconductorRepository?.indexes || [];
if (bioconductorIndexes.length < 2) throw new Error("Windows Bioconductor source and binary indexes must be pinned.");
for (const index of bioconductorIndexes) {
  if (!/^https:\/\//.test(index.url || "") || !/^[a-f0-9]{64}$/.test(index.sha256 || "")) {
    throw new Error(`Invalid locked Bioconductor index: ${index.name || "unnamed"}.`);
  }
}
if (Object.keys(windowsLock.packages?.required || {}).length < 35) {
  throw new Error("Windows runtime lock is missing required R package versions.");
}
for (const legalFile of ["CODE_SIGNING_POLICY.md", "PRIVACY.md", "THIRD_PARTY_NOTICES.md"]) {
  if (!fs.existsSync(path.join(desktopRoot, "legal", legalFile))) {
    throw new Error(`Missing Windows distribution policy: desktop/legal/${legalFile}.`);
  }
}
for (const licenseFile of ["LASTZ-LICENSE.txt", "mman-win32-LICENSE.txt"]) {
  if (!fs.existsSync(path.join(desktopRoot, "legal", "licenses", licenseFile))) {
    throw new Error(`Missing bundled third-party license: desktop/legal/licenses/${licenseFile}.`);
  }
}
if (!fs.existsSync(path.join(repoRoot, ".github", "workflows", "desktop-windows.yml"))) {
  throw new Error("Missing Windows x64 GitHub Actions workflow.");
}
const windowsWorkflow = fs.readFileSync(path.join(repoRoot, ".github", "workflows", "desktop-windows.yml"), "utf8");
if (!windowsWorkflow.includes("WINDOWS_BETA_ARTIFACT_PASSWORD") || !windowsWorkflow.includes("-mhe=on")) {
  throw new Error("Windows beta workflow must encrypt unsigned artifacts with a repository secret.");
}
if (/uses:\s+[^\s]+@v\d+/i.test(windowsWorkflow)) {
  throw new Error("Every action in the Windows beta workflow must be pinned to an immutable commit SHA.");
}
if (
  !windowsWorkflow.includes("id: msys2") ||
  !windowsWorkflow.includes("CGV_MSYS2_ROOT: ${{ steps.msys2.outputs.msys2-location }}")
) {
  throw new Error("Windows beta workflow must pass the setup-msys2 installation root to the scientific runtime builder.");
}
const signedWorkflowPath = path.join(repoRoot, ".github", "workflows", "desktop-windows-release.yml");
if (!fs.existsSync(signedWorkflowPath)) throw new Error("Missing SignPath Windows release workflow.");
const signedWorkflow = fs.readFileSync(signedWorkflowPath, "utf8");
if (/uses:\s+[^\s]+@v\d+/i.test(signedWorkflow)) {
  throw new Error("Every action in the signed Windows release workflow must be pinned to an immutable commit SHA.");
}
if (
  !signedWorkflow.includes("id: msys2") ||
  !signedWorkflow.includes("CGV_MSYS2_ROOT: ${{ steps.msys2.outputs.msys2-location }}")
) {
  throw new Error("Windows workflows must pass the setup-msys2 installation root to the scientific runtime builder.");
}
for (const requiredFragment of [
  "signpath/github-action-submit-signing-request@b9d91eadd323de506c0c81cf0c7fe7438f3360fd",
  "refresh-signed-windows-update.js",
  "CN=SignPath Foundation",
  "CGV_DESKTOP_RELEASE_TOKEN",
  "already public; this workflow may update draft releases only"
]) {
  if (!signedWorkflow.includes(requiredFragment)) {
    throw new Error(`Windows signed release workflow is missing required safeguard: ${requiredFragment}`);
  }
}
if (!signedWorkflow.includes('installer=CGeV-Desktop-$Version-Windows-x64-Setup.exe')) {
  throw new Error("Windows signed releases must use the new CGeV installer filename.");
}
const signPathArtifactConfig = path.join(desktopRoot, "signing", "signpath-windows-installer.xml");
if (!fs.existsSync(signPathArtifactConfig)) throw new Error("Missing SignPath Windows artifact configuration.");
const signPathArtifactXml = fs.readFileSync(signPathArtifactConfig, "utf8");
for (const requiredFragment of [
  "<zip-file>",
  'path="CGeV-Desktop-${version}-Windows-x64-Setup.exe"',
  'product-name="CGeV Desktop"',
  'product-version="${version}"',
  'file-version="${version}"',
  "<authenticode-sign"
]) {
  if (!signPathArtifactXml.includes(requiredFragment)) {
    throw new Error(`SignPath artifact configuration is missing: ${requiredFragment}`);
  }
}

const linuxWorkflowPath = path.join(repoRoot, ".github", "workflows", "desktop-linux.yml");
if (!fs.existsSync(linuxWorkflowPath)) throw new Error("Missing Linux x64 GitHub Actions workflow.");
const linuxWorkflow = fs.readFileSync(linuxWorkflowPath, "utf8");
if (/uses:\s+[^\s]+@v\d+/i.test(linuxWorkflow)) {
  throw new Error("Every action in the Linux workflow must be pinned to an immutable commit SHA.");
}
for (const requiredFragment of [
  "runs-on: ubuntu-24.04",
  "environment-name: cgv-build",
  "create-args: conda-pack",
  "shell: micromamba-shell {0}",
  "npm run runtime:linux:x64",
  "npm run build:linux:x64",
  "*-Linux-x86_64.AppImage",
  "*-Linux-amd64.deb",
  "id: release",
  "node -p \"require('./package.json').version\"",
  "CGeV-Desktop-Linux-x64-${{ steps.release.outputs.version }}",
  "CGeV-Desktop-${{ steps.release.outputs.version }}-Linux-x86_64.AppImage",
  "CGeV-Desktop-${{ steps.release.outputs.version }}-Linux-amd64.deb",
  "--appimage-extract",
  "SHA256SUMS-linux-x64.txt",
  "actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a"
]) {
  if (!linuxWorkflow.includes(requiredFragment)) {
    throw new Error(`Linux workflow is missing required safeguard: ${requiredFragment}`);
  }
}

if (!fs.existsSync(installerScriptPath)) throw new Error("Missing installer regeneration script.");
const installerScript = fs.readFileSync(installerScriptPath, "utf8");
if (installerScript.includes("--jq --arg")) {
  throw new Error("Installer regeneration must not pass jq variables as gh run list options.");
}
for (const requiredFragment of [
  "latest_workflow_run_id",
  '--commit "$sha"',
  "--event workflow_dispatch",
  "run_id > after_id",
  '(cd "$DESKTOP_DIR" && npm run build:mac:arm64)',
  '(cd "$DESKTOP_DIR" && npm run build:mac:x64)'
]) {
  if (!installerScript.includes(requiredFragment)) {
    throw new Error(`Installer regeneration is missing required safeguard: ${requiredFragment}`);
  }
}

const expectedDesktopDefaults = {
  APP_ORTHO_WORKER_PREWARM: "0",
  APP_ORTHO_BACKGROUND_CACHE_WARM: "0",
  APP_ORTHO_PREFLIGHT_SUGGESTIONS: "0",
  APP_ORTHO_PREWARM_LOCAL_HANDLES: "1",
  APP_ORTHO_PREFER_MAIN_CACHE: "1",
  APP_ORTHO_REQUIRE_VERIFIED_ORTHOLOGY: "0",
  APP_SESSION_METRICS: "0",
  APP_PERF_TIMING: "0",
  APP_TRANSPORT_TIMING: "0",
  APP_INLINE_FAST_SEQUENCE_PREFETCH: "1",
  APP_GENE_PLOT_RENDERER_PREWARM: "1",
  APP_HOMO_INITIAL_VISIBLE: "1",
  APP_ORTHO_INITIAL_VISIBLE: "1",
  APP_HOMO_UPFRONT_ISOFORMS: "0",
  APP_ORTHO_UPFRONT_ISOFORMS: "0",
  APP_HOMO_RENDER_CHUNK_SIZE: "1",
  APP_HOMO_AUTO_RENDER_DELAY_MS: "120",
  APP_ORTHO_RENDER_CHUNK_SIZE: "1",
  APP_ORTHO_AUTO_RENDER_MORE: "1",
  APP_ORTHO_AUTO_RENDER_DELAY_MS: "120",
  APP_ISOFORM_RENDER_BATCH_SIZE: "1",
  APP_ISOFORM_RENDER_BATCH_DELAY_MS: "120",
  APP_ORTHO_SERVER_RENDER_NUDGE: "0",
  APP_ORTHO_LOOKUP_PARALLEL_MIN_JOBS: "4",
  APP_ORTHO_SUSPEND_HIDDEN: "1",
  APP_GENE_CATALOG_ENABLED: "0",
  APP_HOMO_DEFER_SEQUENCE: "0",
  APP_ORTHO_DEFER_SEQUENCE: "0",
  APP_FOOTER_DEFER_SEQUENCE: "0",
  APP_DEFER_FEATURE_GC: "0",
  APP_ANALYTICS_PHASE2_DELAY_MS: "0",
  APP_ANALYTICS_PHASE3_DELAY_MS: "0"
};

for (const [key, value] of Object.entries(expectedDesktopDefaults)) {
  const pattern = new RegExp(`${key}:\\s*process\\.env\\.${key}\\s*\\|\\|\\s*["']${value}["']`);
  if (!pattern.test(mainJs)) {
    throw new Error(`Desktop runtime default missing or changed: ${key}=${value}`);
  }
}

console.log(`desktop-package-config-ok lite_annotation_cache=dataset_packages runtime_defaults=${Object.keys(expectedDesktopDefaults).length} windows_runtime=locked`);
