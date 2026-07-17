const fs = require("fs");
const path = require("path");
const { buildAppSourceManifest, outputPath: appSourceManifestPath } = require("./write-app-source-manifest");

const desktopRoot = path.resolve(__dirname, "..");
const repoRoot = path.resolve(desktopRoot, "..");
const packageJsonPath = path.join(desktopRoot, "package.json");
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, "utf8"));
const mainJsPath = path.join(desktopRoot, "src", "main.js");
const mainJs = fs.readFileSync(mainJsPath, "utf8");
const annotationCachePathsJs = fs.readFileSync(path.join(desktopRoot, "src", "annotation-cache-paths.js"), "utf8");
const datasetPackageBuilderJs = fs.readFileSync(path.join(desktopRoot, "scripts", "build-dataset-package.js"), "utf8");
const serverSource = fs.readFileSync(path.join(repoRoot, "server.R"), "utf8");
const dockerfileSource = fs.readFileSync(path.join(repoRoot, "Dockerfile"), "utf8");
const dockerGuidePreparePath = path.join(repoRoot, "docker", "prepare-guide-media.R");
const downloadJsPath = path.join(repoRoot, "www", "js", "cgv_desktop_downloads.js");
const downloadUiPath = path.join(repoRoot, "R", "ui_desktop_downloads.R");

const extraResources = (((packageJson || {}).build || {}).extraResources || []);
const afterPack = (((packageJson || {}).build || {}).afterPack || "");
const build = packageJson.build || {};
const win = build.win || {};
const nsis = build.nsis || {};
const mac = build.mac || {};
const linux = build.linux || {};
const publish = build.publish || {};
const appResource = extraResources.find((entry) => entry && entry.to === "app");
const filters = Array.isArray(appResource && appResource.filter) ? appResource.filter : [];
const commonGoResource = extraResources.find((entry) => entry && entry.to === "app/go_annotations");
const appSourceManifestResource = extraResources.find((entry) => entry && entry.to === "app/app-source-manifest.json");

if (filters.includes("cache/annotation_index/**")) {
  throw new Error("The lite Desktop installer must not bundle repository annotation caches; each verified organism package supplies its own indexes.");
}
if (
  commonGoResource?.from !== "resources/common-go" ||
  !Array.isArray(commonGoResource.filter) ||
  !["go-basic.obo", "go_term_map.rds", "manifest.json"].every((file) => commonGoResource.filter.includes(file))
) {
  throw new Error("Desktop must package the locked common GO resources prepared under resources/common-go.");
}
if (appSourceManifestResource?.from !== "resources/app-source-manifest.json") {
  throw new Error("Desktop must package the generated application-source manifest beside the Shiny source.");
}

if (afterPack !== "scripts/trim-packaged-runtime.js") {
  throw new Error("Desktop build must trim non-target runtimes after packaging.");
}

const expectedVersions = {
  electron: "42.6.1",
  "electron-builder": "26.11.1",
  "electron-updater": "6.8.5",
  "js-yaml": "4.3.0"
};
for (const [dependency, version] of Object.entries(expectedVersions)) {
  const actual = packageJson.devDependencies?.[dependency] || packageJson.dependencies?.[dependency];
  if (actual !== version) throw new Error(`${dependency} must be pinned to ${version}; found ${actual || "missing"}.`);
}

if (packageJson.repository?.url !== "https://github.com/raulrojas22/CGV") {
  throw new Error("Desktop source metadata must continue to point to the public CGV source repository.");
}
if (packageJson.homepage !== "https://cgv.mobilomics.org") {
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
if (mac.artifactName !== "CGV-Desktop-${version}-macOS-${arch}.${ext}") {
  throw new Error("macOS artifacts must use the stable CGV Desktop release filename.");
}
if (linux.artifactName !== "CGV-Desktop-${version}-Linux-${arch}.${ext}") {
  throw new Error("Linux artifacts must use the stable CGV Desktop release filename.");
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

const goLockPath = path.join(desktopRoot, "go-assets-lock.json");
const goLock = JSON.parse(fs.readFileSync(goLockPath, "utf8"));
if (
  goLock.version !== 1 ||
  !/^https:\/\/release\.geneontology\.org\/\d{4}-\d{2}-\d{2}\/ontology\/go-basic\.obo$/.test(goLock.obo?.url || "") ||
  !/^[a-f0-9]{64}$/.test(goLock.obo?.sha256 || "")
) {
  throw new Error("Common GO assets must be pinned to a dated official Gene Ontology release with SHA-256.");
}
if (packageJson.scripts?.["prepare:go"] !== "node scripts/prepare-common-go.js") {
  throw new Error("Desktop must prepare the locked common GO assets before packaging.");
}
if (packageJson.scripts?.["prepare:source"] !== "node scripts/write-app-source-manifest.js") {
  throw new Error("Desktop must generate an application-source manifest before packaging.");
}
if (packageJson.scripts?.["prepare:guide"] !== "node scripts/prepare-guide-media.js") {
  throw new Error("Desktop must prepare the locked CGV Guide media bundle before packaging.");
}
for (const buildScript of ["build", "build:mac", "build:linux", "build:win", "build:store"]) {
  if (!String(packageJson.scripts?.[buildScript] || "").includes("npm run prepare:guide")) {
    throw new Error(`${buildScript} must prepare the locked CGV Guide media bundle.`);
  }
  if (!String(packageJson.scripts?.[buildScript] || "").includes("npm run prepare:go")) {
    throw new Error(`${buildScript} must prepare locked common GO assets.`);
  }
  if (!String(packageJson.scripts?.[buildScript] || "").includes("npm run prepare:source")) {
    throw new Error(`${buildScript} must identify the exact Shiny application source being packaged.`);
  }
}
const guideMediaLockPath = path.join(desktopRoot, "guide-media-lock.json");
const guideMediaPreparePath = path.join(desktopRoot, "scripts", "prepare-guide-media.js");
if (!fs.existsSync(guideMediaLockPath) || !fs.existsSync(guideMediaPreparePath)) {
  throw new Error("Missing locked CGV Guide media preparation files.");
}
const guideMediaLock = JSON.parse(fs.readFileSync(guideMediaLockPath, "utf8"));
if (
  guideMediaLock.version !== 1 ||
  !/^https:\/\/github\.com\/raulrojas22\/CGV-Desktop-Releases\/releases\/download\/guide-media-v1\//.test(guideMediaLock.url || "") ||
  !/^[a-f0-9]{64}$/.test(guideMediaLock.sha256 || "") ||
  !Array.isArray(guideMediaLock.expectedFiles) ||
  guideMediaLock.expectedFiles.length !== 35
) {
  throw new Error("CGV Guide media must be release-hosted, checksum-locked, and contain the 35 available walkthrough videos.");
}
if (!filters.includes("www/**")) {
  throw new Error("Desktop packaging must include the prepared CGV Guide media under www.");
}
if (
  !fs.existsSync(dockerGuidePreparePath) ||
  !dockerfileSource.includes('org.opencontainers.image.authors="Raul Rojas"') ||
  !dockerfileSource.includes('org.opencontainers.image.source="https://github.com/raulrojas22/CGV"') ||
  !dockerfileSource.includes("Rscript /app/docker/prepare-guide-media.R")
) {
  throw new Error("Docker builds must use the correct CGV metadata and prepare the same locked Guide media bundle as Desktop.");
}
if (!fs.existsSync(appSourceManifestPath)) {
  throw new Error("Missing generated app-source-manifest.json; run npm run prepare:source before package verification.");
}
const actualAppSourceManifest = JSON.parse(fs.readFileSync(appSourceManifestPath, "utf8"));
const expectedAppSourceManifest = buildAppSourceManifest();
if (
  actualAppSourceManifest.schemaVersion !== 1 ||
  actualAppSourceManifest.appVersion !== packageJson.version ||
  JSON.stringify(actualAppSourceManifest.files) !== JSON.stringify(expectedAppSourceManifest.files)
) {
  throw new Error("Generated application-source manifest does not match the current Home, UI, server, and Desktop source files.");
}
const modernUiSource = fs.readFileSync(path.join(repoRoot, "ui.R"), "utf8");
const modernHomeSource = fs.readFileSync(path.join(repoRoot, "www", "home_preview_cgv.html"), "utf8");
for (const requiredFragment of ["app-optional-uploads-panel", "desktop-organism-modal", "cgv_desktop_downloads_page()", "Mixed sources"]) {
  if (!modernUiSource.includes(requiredFragment)) {
    throw new Error(`Desktop cannot package the obsolete Shiny UI; missing modern capability marker: ${requiredFragment}`);
  }
}
for (const requiredFragment of ["Live gene suggestions", "transcript alignment", "25 installable reference organisms", "Explore CGV Desktop"]) {
  if (!modernHomeSource.includes(requiredFragment)) {
    throw new Error(`Desktop cannot package the obsolete Home; missing modern capability marker: ${requiredFragment}`);
  }
}
for (const windowsBuildScript of ["build:win", "build:store"]) {
  if (!/(?:^|\s)--publish(?:\s+|=)never(?:\s|$)/.test(String(packageJson.scripts?.[windowsBuildScript] || ""))) {
    throw new Error(`${windowsBuildScript} must disable electron-builder implicit CI publishing.`);
  }
}
if (!mainJs.includes("autoUpdater.checkForUpdatesAndNotify()") || !mainJs.includes("isDirectWindowsBuild")) {
  throw new Error("Direct Windows builds must check the electron-builder update feed automatically.");
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
if (!Array.isArray(nsis.preCompressedFileExtensions) || nsis.preCompressedFileExtensions.length !== 0) {
  throw new Error("Windows NSIS must keep pre-compressed assets inside the main archive to prevent literal $INSTDIR output paths.");
}
if (!String(nsis.artifactName || "").includes("Windows-${arch}-Setup")) {
  throw new Error("Windows NSIS artifact name must be stable and architecture-specific.");
}
if (
  JSON.stringify(nsis.installerLanguages) !== JSON.stringify(["en_US"]) ||
  nsis.language !== "1033" ||
  nsis.multiLanguageInstaller !== false ||
  nsis.displayLanguageSelector !== false
) {
  throw new Error("Windows NSIS must use English consistently and must not inherit the host language.");
}
if (
  win.icon !== "build/icon.ico" ||
  nsis.installerIcon !== "build/icon.ico" ||
  nsis.uninstallerIcon !== "build/icon.ico" ||
  nsis.installerSidebar !== "build/installerSidebar.bmp" ||
  nsis.installerHeader !== "build/installerHeader.bmp"
) {
  throw new Error("Windows must use the branded CGV application icon and lightweight installer artwork.");
}
for (const artwork of [win.icon, nsis.installerSidebar, nsis.installerHeader]) {
  if (!fs.existsSync(path.resolve(desktopRoot, artwork))) {
    throw new Error(`Missing Windows installer artwork: ${artwork}`);
  }
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
if (
  !/!macro\s+customCheckAppRunning/.test(nsisInclude) ||
  !/taskkill[^\r\n]*\/T\s+\/F/i.test(nsisInclude) ||
  !/\$\$attempt\s+-lt\s+4/.test(nsisInclude) ||
  !/resources\\runtime/.test(nsisInclude) ||
  !/runtimeRootForward\s*=\s*\$\$runtimeRoot\.Replace/.test(nsisInclude) ||
  !/\$\$_\.CommandLine\.IndexOf\(\$\$runtimeRoot/.test(nsisInclude) ||
  !/\$\$_\.CommandLine\.IndexOf\(\$\$runtimeRootForward/.test(nsisInclude) ||
  !/\$\$_\.ExecutablePath/.test(nsisInclude)
) {
  throw new Error("Windows NSIS must close the complete Electron/R process tree and retry cleanup only under the CGV install directory.");
}
if (!mainJs.includes('host=\'127.0.0.1\'')) {
  throw new Error("Desktop Shiny must listen on 127.0.0.1 only.");
}
if (
  !mainJs.includes("normalizeAnnotationCacheDirectory") ||
  !mainJs.includes("portableAnnotationCacheFilename(file, { force: true })") ||
  !mainJs.includes('runFile(rscript, ["--vanilla", scriptPath]') ||
  mainJs.includes('runFile(rscript, ["-e", rCode]') ||
  !annotationCachePathsJs.includes("dataset_packages_work_") ||
  !datasetPackageBuilderJs.includes("normalizeAnnotationCacheDirectory(cacheDir, { force: true })")
) {
  throw new Error("Desktop dataset caches must use portable Windows-safe filenames and a temporary R warmup script.");
}
if (
  !serverSource.includes("Always release it so a failed cache warmup") ||
  !serverSource.includes("state$ready(TRUE)") ||
  !serverSource.includes("continuing with a direct search")
) {
  throw new Error("A failed cache preload must release queued gene searches instead of waiting forever.");
}
const preloadJs = fs.readFileSync(path.join(desktopRoot, "src", "preload.js"), "utf8");
const keepaliveJs = fs.readFileSync(path.join(repoRoot, "www", "js", "keepalive.js"), "utf8");
const windowsSmokeTest = fs.readFileSync(path.join(desktopRoot, "scripts", "smoke-windows-installer.ps1"), "utf8");
if (
  !mainJs.includes('ipcMain.handle("cgv:recover-analysis"') ||
  !mainJs.includes("CGV renderer loaded at") ||
  !preloadJs.includes('recoverAnalysis: () => ipcRenderer.invoke("cgv:recover-analysis")') ||
  !keepaliveJs.includes("scheduleDesktopRecovery")
) {
  throw new Error("CGV Desktop must recover a disconnected local Shiny session without repeated manual page reloads.");
}
for (const requiredFragment of [
  "CGV renderer loaded at",
  "app-source-manifest.json",
  "CGV recovered automatically at",
  "Wait-ForNoBundledRProcesses",
  "Format-BundledRProcesses"
]) {
  if (!windowsSmokeTest.includes(requiredFragment)) {
    throw new Error(`Windows smoke test is missing a current-source/recovery assertion: ${requiredFragment}`);
  }
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
if (
  !windowsWorkflow.includes("WINDOWS_BETA_ARTIFACT_PASSWORD") ||
  !windowsWorkflow.includes("-mhe=on") ||
  !windowsWorkflow.includes("npm run prepare:go") ||
  !windowsWorkflow.includes("npm run prepare:guide") ||
  !windowsWorkflow.includes("npm run prepare:source") ||
  !windowsWorkflow.includes("CGV_DESKTOP_SOURCE_REVISION: ${{ github.sha }}") ||
  /uses:\s+[^\s]+@v\d+/i.test(windowsWorkflow)
) {
  throw new Error("Windows beta workflow must pin actions, prepare locked GO assets, and encrypt unsigned artifacts with a repository secret.");
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
  "npm run prepare:go",
  "npm run prepare:guide",
  "npm run prepare:source",
  "CGV_DESKTOP_SOURCE_REVISION: ${{ github.sha }}",
  "already public; this workflow may update draft releases only"
]) {
  if (!signedWorkflow.includes(requiredFragment)) {
    throw new Error(`Windows signed release workflow is missing required safeguard: ${requiredFragment}`);
  }
}
const signPathArtifactConfig = path.join(desktopRoot, "signing", "signpath-windows-installer.xml");
if (!fs.existsSync(signPathArtifactConfig)) throw new Error("Missing SignPath Windows artifact configuration.");
const signPathArtifactXml = fs.readFileSync(signPathArtifactConfig, "utf8");
for (const requiredFragment of [
  "<zip-file>",
  'product-name="CGV Desktop"',
  'product-version="${version}"',
  'file-version="${version}"',
  "<authenticode-sign"
]) {
  if (!signPathArtifactXml.includes(requiredFragment)) {
    throw new Error(`SignPath artifact configuration is missing: ${requiredFragment}`);
  }
}

const expectedDesktopDefaults = {
  APP_ORTHO_WORKER_PREWARM: "0",
  APP_ORTHO_BACKGROUND_CACHE_WARM: "0",
  APP_ORTHO_PREFLIGHT_SUGGESTIONS: "0",
  APP_ORTHO_PREWARM_LOCAL_HANDLES: "1",
  APP_ORTHO_PREFER_MAIN_CACHE: "1",
  APP_SESSION_METRICS: "0",
  APP_PERF_TIMING: "0",
  APP_TRANSPORT_TIMING: "0",
  APP_INLINE_FAST_SEQUENCE_PREFETCH: "1",
  APP_GENE_PLOT_RENDERER_PREWARM: "1",
  APP_HOMO_INITIAL_VISIBLE: "1",
  APP_ORTHO_INITIAL_VISIBLE: "1",
  APP_HOMO_UPFRONT_ISOFORMS: "0",
  APP_ORTHO_UPFRONT_ISOFORMS: "0",
  APP_ORTHO_RENDER_CHUNK_SIZE: "2",
  APP_ORTHO_AUTO_RENDER_MORE: "1",
  APP_ORTHO_AUTO_RENDER_DELAY_MS: "250",
  APP_ORTHO_LOOKUP_PARALLEL_MIN_JOBS: "4",
  APP_ORTHO_SUSPEND_HIDDEN: "1",
  APP_HOMO_DEFER_SEQUENCE: "1",
  APP_ORTHO_DEFER_SEQUENCE: "1",
  APP_FOOTER_DEFER_SEQUENCE: "1",
  APP_DEFER_FEATURE_GC: "1",
  APP_ANALYTICS_PHASE2_DELAY_MS: "0",
  APP_ANALYTICS_PHASE3_DELAY_MS: "0"
};

for (const [key, value] of Object.entries(expectedDesktopDefaults)) {
  const pattern = new RegExp(`${key}:\\s*process\\.env\\.${key}\\s*\\|\\|\\s*["']${value}["']`);
  if (!pattern.test(mainJs)) {
    throw new Error(`Desktop runtime default missing or changed: ${key}=${value}`);
  }
}

console.log(`desktop-package-config-ok installer=lite-catalog-first runtime_defaults=${Object.keys(expectedDesktopDefaults).length} windows_runtime=locked`);
