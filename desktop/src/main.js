const { app, BrowserWindow, dialog, ipcMain, Menu, shell } = require("electron");
const { autoUpdater } = require("electron-updater");
const crypto = require("crypto");
const fs = require("fs");
const http = require("http");
const https = require("https");
const os = require("os");
const path = require("path");
const { execFile, spawn, spawnSync } = require("child_process");
const { downloadFile, sha256File, throwIfCanceled } = require("./download-file");
const { removeInstalledDatasets } = require("./dataset-removal");
const { extractZipArchive, validateZipArchive } = require("./secure-zip");
const {
  bundledRuntimeResourceParts,
  executableNames,
  isUsableExecutable,
  runtimeExecutableCandidates,
  shouldInstallRuntimeLocally
} = require("./runtime-platform");
const { needsInitialStorageSelection, parseDesktopSettings } = require("./storage-settings");
const { legacyUserDataPath } = require("./legacy-user-data");

const DESKTOP_APP_ID = "org.cgv.desktop";
if (process.platform === "win32" && typeof app.setAppUserModelId === "function") {
  app.setAppUserModelId(DESKTOP_APP_ID);
}

function configureLegacyUserData(electronApp = app) {
  // A few unit tests evaluate selected main-process helpers with a minimal
  // Electron stub. Real Electron always provides both methods.
  if (typeof electronApp?.getPath !== "function" || typeof electronApp?.setPath !== "function") return false;
  electronApp.setPath("userData", legacyUserDataPath({
    platform: process.platform,
    localAppData: process.env.LOCALAPPDATA,
    appData: electronApp.getPath("appData")
  }));
  return true;
}

configureLegacyUserData();

let mainWindow = null;
let shinyProcess = null;
let shinyUrl = null;
let startupLogPath = null;
let appIsQuitting = false;
let datasetInstallQueue = Promise.resolve();
const datasetInstallControllers = new Map();
const cancelableDatasetInstalls = new Set();
let shinyStartPromise = null;
let exportDownloadSession = null;
let preparedRuntimeRoot = "";

// Increment when the bundled conda runtime changes. A new revision replaces
// the user-local runtime on the next app launch.
const RUNTIME_REVISION = "2026-07-09-relocatable-4";

function isExecutable(filePath) {
  return isUsableExecutable(fs, filePath);
}

function isFile(filePath) {
  try {
    return fs.statSync(filePath).isFile();
  } catch (_) {
    return false;
  }
}

function platformKey() {
  return `${process.platform}-${process.arch}`;
}

function resourcePath(...parts) {
  if (app.isPackaged) {
    return path.join(process.resourcesPath, ...parts);
  }
  return path.join(__dirname, "..", ...parts);
}

function appRoot() {
  if (process.env.CGV_APP_ROOT) return process.env.CGV_APP_ROOT;
  if (app.isPackaged) return resourcePath("app");
  return path.resolve(__dirname, "..", "..");
}

function windowIconPath() {
  return app.isPackaged
    ? resourcePath("icon.png")
    : path.join(__dirname, "..", "build", "icon.png");
}

function findRscript(runtimeRoot = "") {
  const runtimeRoots = [
    runtimeRoot,
    resourcePath("runtime", platformKey()),
    resourcePath("runtime"),
    resourcePath("resources", "r", platformKey()),
    resourcePath("resources", "r"),
    resourcePath("r", platformKey()),
    resourcePath("r")
  ].filter(Boolean);
  const bundled = [
    process.env.CGV_RSCRIPT,
    ...runtimeRoots.flatMap((root) => runtimeExecutableCandidates(root, "Rscript"))
  ].filter(Boolean);
  const system = [
    "/usr/local/bin/Rscript",
    "/opt/homebrew/bin/Rscript",
    "/usr/bin/Rscript",
    ...executableNames("Rscript")
  ].filter(Boolean);
  const candidates = app.isPackaged ? bundled : bundled.concat(system);

  for (const candidate of candidates) {
    if (isExecutable(candidate)) return candidate;
  }

  return "Rscript";
}

function findBundledBinary(name, envName, runtimeRoot = "") {
  const runtimeRoots = [
    runtimeRoot,
    resourcePath("runtime", platformKey()),
    resourcePath("runtime"),
    resourcePath("resources", "r", platformKey()),
    resourcePath("resources", "r"),
    resourcePath("r", platformKey()),
    resourcePath("r")
  ].filter(Boolean);
  const standaloneRoots = [
    resourcePath("bin", platformKey()),
    resourcePath("bin"),
    resourcePath("resources", "bin", platformKey()),
    resourcePath("resources", "bin")
  ];
  const bundled = [
    process.env[envName],
    ...runtimeRoots.flatMap((root) => runtimeExecutableCandidates(root, name)),
    ...standaloneRoots.flatMap((root) => executableNames(name).map((candidate) => path.join(root, candidate)))
  ].filter(Boolean);
  const system = [
    `/opt/homebrew/bin/${name}`,
    `/usr/local/bin/${name}`,
    `/usr/bin/${name}`,
    ...executableNames(name)
  ].filter(Boolean);
  const candidates = app.isPackaged ? bundled : bundled.concat(system);
  for (const candidate of candidates) {
    if (isExecutable(candidate)) return candidate;
  }
  return "";
}

function runtimeBinDir(rscript) {
  if (!path.isAbsolute(rscript)) return "";
  const binDir = path.dirname(rscript);
  return fs.existsSync(binDir) ? binDir : "";
}

function runtimeBinDirs(runtimeRoot, rscript) {
  return Array.from(new Set([
    runtimeBinDir(rscript),
    runtimeRoot && path.join(runtimeRoot, "bin"),
    process.platform === "win32" && runtimeRoot && path.join(runtimeRoot, "bin", "x64")
  ].filter((candidate) => candidate && fs.existsSync(candidate))));
}

function bundledRuntimeRoot() {
  return resourcePath(
    ...bundledRuntimeResourceParts(app.isPackaged, platformKey())
  );
}

function localRuntimeRoot() {
  return path.join(app.getPath("userData"), "runtime", platformKey());
}

function runtimeMarkerPath(runtimeRoot) {
  return path.join(runtimeRoot, ".cgv-runtime.json");
}

function isCurrentLocalRuntime(runtimeRoot) {
  try {
    const marker = JSON.parse(fs.readFileSync(runtimeMarkerPath(runtimeRoot), "utf8"));
    return marker.revision === RUNTIME_REVISION &&
      marker.platform === platformKey() &&
      runtimeExecutableCandidates(runtimeRoot, "Rscript").some(isExecutable);
  } catch (_) {
    return false;
  }
}

function allowPrunedFilesInCondaUnpack(unpackPath) {
  const source = fs.readFileSync(unpackPath, "utf8");
  const target = source.replace(
    /^(\s*)update_prefix\(new_path, new_prefix, placeholder, mode=mode\)$/gm,
    "$1if os.path.exists(new_path):\n$1    update_prefix(new_path, new_prefix, placeholder, mode=mode)"
  );
  if (target === source) {
    throw new Error("Unable to prepare conda-unpack for the pruned runtime.");
  }
  fs.writeFileSync(unpackPath, target);
}

function quoteRuntimePathsInRWrapper(wrapperPath) {
  const source = fs.readFileSync(wrapperPath, "utf8");
  const target = source.replace(/^(R_(?:HOME|SHARE|INCLUDE|DOC)_DIR)=(.+)$/gm, (_match, name, runtimePath) => {
    return `${name}="${runtimePath.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
  });
  if (target === source) {
    throw new Error(`Unable to prepare R wrapper: ${wrapperPath}`);
  }
  fs.writeFileSync(wrapperPath, target);
}

async function prepareRuntime() {
  const explicit = process.env.CGV_DESKTOP_RUNTIME_ROOT;
  if (explicit) return explicit;

  const sourceRoot = bundledRuntimeRoot();
  if (!fs.existsSync(sourceRoot)) {
    throw requiredRuntimeError(
      "Bundled R runtime",
      `Expected it at ${sourceRoot}. Rebuild the platform runtime before packaging.`
    );
  }
  if (!shouldInstallRuntimeLocally()) return sourceRoot;

  const targetRoot = localRuntimeRoot();
  if (isCurrentLocalRuntime(targetRoot)) return targetRoot;

  sendStatus({ phase: "starting", message: "Preparing local R runtime..." });
  logStartupLine("electron", `Installing runtime ${RUNTIME_REVISION} at ${targetRoot}`);

  const stagingRoot = `${targetRoot}.staging-${process.pid}`;
  fs.rmSync(stagingRoot, { recursive: true, force: true });
  fs.mkdirSync(path.dirname(stagingRoot), { recursive: true });
  fs.cpSync(sourceRoot, stagingRoot, { recursive: true, errorOnExist: false });

  try {
    // conda-unpack writes the final install prefix into R and Python wrappers,
    // so it must run only after the runtime reaches its permanent location.
    fs.rmSync(targetRoot, { recursive: true, force: true });
    fs.renameSync(stagingRoot, targetRoot);

    const python = path.join(targetRoot, "bin", "python");
    const unpack = path.join(targetRoot, "bin", "conda-unpack");
    if (!isExecutable(python) || !isFile(unpack)) {
      throw new Error("Bundled runtime is missing python or conda-unpack.");
    }
    allowPrunedFilesInCondaUnpack(unpack);
    await runFile(python, [unpack]);
    quoteRuntimePathsInRWrapper(path.join(targetRoot, "bin", "R"));
    quoteRuntimePathsInRWrapper(path.join(targetRoot, "lib", "R", "bin", "R"));
    fs.writeFileSync(runtimeMarkerPath(targetRoot), JSON.stringify({
      revision: RUNTIME_REVISION,
      platform: platformKey(),
      installedAt: new Date().toISOString()
    }, null, 2));
  } catch (error) {
    fs.rmSync(stagingRoot, { recursive: true, force: true });
    fs.rmSync(targetRoot, { recursive: true, force: true });
    throw new Error(`Unable to prepare the local R runtime: ${error.message}`);
  }

  return targetRoot;
}

function desktopSettingsPath() {
  return path.join(app.getPath("userData"), "desktop-settings.json");
}

function readDesktopSettings() {
  try {
    return parseDesktopSettings(fs.readFileSync(desktopSettingsPath(), "utf8"));
  } catch (_) {
    return {};
  }
}

function writeDesktopSettings(storageRoot) {
  const settingsPath = desktopSettingsPath();
  const value = {
    schemaVersion: 1,
    storageRoot: path.resolve(storageRoot)
  };
  fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
  const temporaryPath = `${settingsPath}.tmp-${process.pid}`;
  fs.writeFileSync(temporaryPath, `${JSON.stringify(value, null, 2)}\n`);
  fs.renameSync(temporaryPath, settingsPath);
  return value;
}

function configuredStorageRoot() {
  return readDesktopSettings().storageRoot || "";
}

async function promptForStorageRoot() {
  const current = configuredStorageRoot();
  const result = await dialog.showOpenDialog(mainWindow || undefined, {
    title: "Choose where CGeV Desktop stores genomes and caches",
    buttonLabel: "Use this folder",
    defaultPath: current || path.join(app.getPath("home"), "CGeV Desktop Data"),
    properties: ["openDirectory", "createDirectory"]
  });
  if (result.canceled || !result.filePaths[0]) return null;
  try {
    const selectedRoot = path.resolve(result.filePaths[0]);
    fs.mkdirSync(path.join(selectedRoot, "data"), { recursive: true });
    fs.mkdirSync(path.join(selectedRoot, "cache"), { recursive: true });
    fs.accessSync(selectedRoot, fs.constants.W_OK);
    return writeDesktopSettings(selectedRoot);
  } catch (error) {
    await dialog.showMessageBox(mainWindow || undefined, {
      type: "error",
      title: "CGeV Desktop cannot use this folder",
      message: "Choose a folder where your Windows account can create and update files.",
      detail: error.message
    });
    return null;
  }
}

async function ensureStorageConfigured() {
  const needsSelection = needsInitialStorageSelection({
    platform: process.platform,
    isPackaged: app.isPackaged,
    env: process.env,
    storageRoot: configuredStorageRoot()
  });
  if (!needsSelection) return true;
  const selected = await promptForStorageRoot();
  if (selected) return true;
  sendStatus({
    phase: "storage-required",
    message: "Choose a folder for genomes and caches before starting CGeV Desktop."
  });
  return false;
}

function defaultDataRoot() {
  const explicit = process.env.CGV_DESKTOP_DATA_ROOT || process.env.CGV_DATA_ROOT;
  if (explicit) return explicit;

  const localRoot = appRoot();
  if (!app.isPackaged && fs.existsSync(path.join(localRoot, "annotations", "registry.tsv"))) {
    return localRoot;
  }
  const storageRoot = configuredStorageRoot();
  if (storageRoot) return path.join(storageRoot, "data");
  return path.join(app.getPath("userData"), "data");
}

function defaultCacheRoot() {
  if (process.env.CGV_DESKTOP_CACHE_ROOT || process.env.CGV_CACHE_DIR) {
    return process.env.CGV_DESKTOP_CACHE_ROOT || process.env.CGV_CACHE_DIR;
  }
  const localCache = path.join(appRoot(), "cache");
  if (!app.isPackaged && fs.existsSync(path.join(localCache, "annotation_index"))) {
    return localCache;
  }
  const storageRoot = configuredStorageRoot();
  if (storageRoot) return path.join(storageRoot, "cache");
  return path.join(app.getPath("userData"), "cache");
}

function copyDirIfMissing(source, target) {
  if (!fs.existsSync(source) || fs.existsSync(target)) return;
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.cpSync(source, target, { recursive: true, errorOnExist: false });
}

function copyDirIfMissingOrEmpty(source, target) {
  if (!fs.existsSync(source)) return;
  const hasTargetFiles = fs.existsSync(target) && fs.readdirSync(target).length > 0;
  if (hasTargetFiles) return;
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.cpSync(source, target, { recursive: true, errorOnExist: false });
}

function copyFileIfMissing(source, target) {
  if (!isFile(source) || fs.existsSync(target)) return;
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.copyFileSync(source, target);
}

function seedDemoData(dataRoot) {
  const explicitDemoRoot = process.env.CGV_DESKTOP_BUNDLED_DEMO_ROOT || "";
  const demoRoot = explicitDemoRoot || resourcePath("demo-data");
  const manifest = path.join(demoRoot, "data-manifest.json");
  if (!fs.existsSync(manifest)) return;
  for (const dirName of ["annotations", "genomes", "go_annotations", "data"]) {
    copyDirIfMissingOrEmpty(path.join(demoRoot, dirName), path.join(dataRoot, dirName));
  }
  copyFileIfMissing(manifest, path.join(dataRoot, "data-manifest.json"));
}

function seedCommonGoData(dataRoot) {
  const appGoRoot = path.join(appRoot(), "go_annotations");
  copyFileIfMissing(path.join(appGoRoot, "go-basic.obo"), path.join(dataRoot, "go_annotations", "go-basic.obo"));
  copyFileIfMissing(path.join(appGoRoot, "go_term_map.rds"), path.join(dataRoot, "go_annotations", "go_term_map.rds"));
}

function seedBundledCache(cacheRoot) {
  const bundledCacheRoot = resourcePath("app", "cache");
  copyDirIfMissingOrEmpty(path.join(bundledCacheRoot, "annotation_index"), path.join(cacheRoot, "annotation_index"));
}

function migrateAnnotationIndexCache(sourceCacheDir, cacheRoot, options = {}) {
  if (!fs.existsSync(sourceCacheDir)) {
    return { bundled: 0, migrated: 0, alreadyPresent: 0 };
  }

  const targetCacheDir = path.join(cacheRoot, "annotation_index");
  fs.mkdirSync(targetCacheDir, { recursive: true });

  const rdsFiles = fs.readdirSync(sourceCacheDir).filter((file) => file.endsWith(".rds"));
  let migrated = 0;
  let alreadyPresent = 0;
  for (const file of rdsFiles) {
    const sourcePath = path.join(sourceCacheDir, file);
    const targetPath = path.join(targetCacheDir, file);
    if (!fs.existsSync(targetPath)) {
      fs.copyFileSync(sourcePath, targetPath);
      migrated += 1;
    } else {
      alreadyPresent += 1;
    }
  }

  if (options.cleanupSource && rdsFiles.length > 0) {
    try {
      fs.rmSync(sourceCacheDir, { recursive: true, force: true });
      const parentDir = path.dirname(sourceCacheDir);
      if (fs.readdirSync(parentDir).length === 0) {
        fs.rmSync(parentDir, { recursive: true, force: true });
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  return { bundled: rdsFiles.length, migrated, alreadyPresent };
}

function migrateDatasetCache(dataRoot, cacheRoot) {
  return migrateAnnotationIndexCache(path.join(dataRoot, "cache", "annotation_index"), cacheRoot, {
    cleanupSource: true
  });
}

function seedBundledData(dataRoot) {
  if (process.env.CGV_DESKTOP_ALLOW_BUNDLED_ORGANISMS !== "1") {
    return;
  }
  const bundledRoot = resourcePath("bundled-data");
  const registryPath = path.join(bundledRoot, "annotations", "registry.tsv");
  if (!fs.existsSync(registryPath)) return;
  for (const dirName of ["annotations", "genomes", "go_annotations", "data", "www"]) {
    copyDirIfMissingOrEmpty(path.join(bundledRoot, dirName), path.join(dataRoot, dirName));
  }
  copyFileIfMissing(path.join(bundledRoot, "dataset.json"), path.join(dataRoot, "bundled-dataset.json"));
}

function ensureDataRootStructure(dataRoot) {
  for (const dirName of ["annotations", "genomes", "go_annotations", "data", "packages", "ncbi_downloads"]) {
    fs.mkdirSync(path.join(dataRoot, dirName), { recursive: true });
  }
}

function assertOrganismRemovalAllowed(dataRoot = defaultDataRoot()) {
  const explicitDataRoot = process.env.CGV_DESKTOP_DATA_ROOT || process.env.CGV_DATA_ROOT;
  if (!app.isPackaged && !explicitDataRoot && path.resolve(dataRoot) === path.resolve(appRoot())) {
    throw new Error("Refusing to remove organisms from the source workspace. Set CGV_DESKTOP_DATA_ROOT to a disposable profile when testing reset in development.");
  }
}

function getFreePort() {
  return new Promise((resolve, reject) => {
    const server = http.createServer();
    server.listen(0, "127.0.0.1", () => {
      const address = server.address();
      const port = address.port;
      server.close(() => resolve(port));
    });
    server.on("error", reject);
  });
}

function waitForHttp(url, timeoutMs = 120000) {
  const started = Date.now();
  return new Promise((resolve, reject) => {
    const tick = () => {
      const req = http.get(url, (res) => {
        res.resume();
        if ([200, 301, 302, 303, 307, 308].includes(res.statusCode)) {
          resolve();
        } else {
          retry();
        }
      });
      req.on("error", retry);
      req.setTimeout(2500, () => {
        req.destroy();
        retry();
      });
    };
    const retry = () => {
      if (Date.now() - started > timeoutMs) {
        reject(new Error(`Timed out waiting for ${url}`));
      } else {
        setTimeout(tick, 1000);
      }
    };
    tick();
  });
}

function recentOutputMessage(lines) {
  const recent = (lines || []).filter(Boolean).slice(-12);
  if (!recent.length) return "";
  return ` Recent R output: ${recent.join(" | ")}`;
}

function waitForShinyReady(url, childProcess, getRecentOutput, timeoutMs = 120000) {
  return new Promise((resolve, reject) => {
    let settled = false;
    const finish = (callback, value) => {
      if (settled) return;
      settled = true;
      callback(value);
    };

    waitForHttp(url, timeoutMs).then(
      () => finish(resolve),
      (error) => {
        const detail = recentOutputMessage(getRecentOutput());
        finish(reject, new Error(`${error.message}.${detail}`));
      }
    );

    childProcess.once("exit", (code, signal) => {
      const detail = recentOutputMessage(getRecentOutput());
      finish(
        reject,
        new Error(`R/Shiny stopped before CGeV was ready (${code ?? signal}).${detail}`)
      );
    });

    childProcess.once("error", (error) => {
      finish(reject, new Error(`Unable to start R/Shiny: ${error.message}`));
    });
  });
}

function sendStatus(payload) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send("cgv:status", payload);
  }
}

function sendUpdateStatus(payload) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send("cgv:update-status", payload);
  }
}

function getStartupLogPath() {
  if (!startupLogPath) {
    startupLogPath = path.join(app.getPath("userData"), "logs", "startup.log");
  }
  return startupLogPath;
}

function appendStartupLog(message) {
  const logPath = getStartupLogPath();
  fs.mkdirSync(path.dirname(logPath), { recursive: true });
  fs.appendFileSync(logPath, message);
}

function logStartupLine(scope, message) {
  const text = String(message || "");
  if (!text) return;
  const timestamp = new Date().toISOString();
  const lines = text.split(/\r?\n/).filter((line) => line.length);
  const entry = lines.length
    ? lines.map((line) => `[${timestamp}] [${scope}] ${line}\n`).join("")
    : `[${timestamp}] [${scope}]\n`;
  appendStartupLog(entry);
}

function setupAutoUpdater() {
  const isDirectWindowsBuild = app.isPackaged && process.platform === "win32" && !process.windowsStore;
  const enabled = process.env.CGV_DISABLE_AUTO_UPDATE !== "1" && (
    process.env.CGV_ENABLE_AUTO_UPDATE === "1" || isDirectWindowsBuild
  );
  if (!enabled) {
    logStartupLine("update", "Auto updates disabled for this distribution channel.");
    return;
  }

  autoUpdater.autoDownload = true;
  autoUpdater.autoInstallOnAppQuit = true;

  autoUpdater.on("checking-for-update", () => {
    sendUpdateStatus({ phase: "checking", message: "Checking for updates..." });
  });

  autoUpdater.on("update-available", (info) => {
    sendUpdateStatus({ phase: "available", version: info.version, message: `CGeV Desktop ${info.version} available. Downloading...` });
  });

  autoUpdater.on("update-not-available", () => {
    sendUpdateStatus({ phase: "up-to-date", message: "CGeV Desktop is up to date." });
  });

  autoUpdater.on("download-progress", (progress) => {
    sendUpdateStatus({ phase: "downloading", percent: Math.round(progress.percent) });
  });

  autoUpdater.on("update-downloaded", (info) => {
    sendUpdateStatus({ phase: "downloaded", version: info.version, message: `CGeV Desktop ${info.version} ready. Restart to apply the update.` });
  });

  autoUpdater.on("error", (error) => {
    sendUpdateStatus({ phase: "error", message: error.message });
  });

  autoUpdater.checkForUpdatesAndNotify();
}

function requiredRuntimeError(binaryName, hint) {
  return new Error(`${binaryName} is required for CGeV Desktop but was not found. ${hint}`);
}

function validateRuntime(rscript, binaries) {
  if (!isExecutable(rscript)) {
    throw requiredRuntimeError(
      "Rscript",
      "Build the bundled runtime for this platform or set CGV_RSCRIPT to a valid executable."
    );
  }
  for (const [name, value] of Object.entries(binaries)) {
    if (process.platform === "win32" && ["samtools", "tabix"].includes(name)) continue;
    if (!value || !isExecutable(value)) {
      throw requiredRuntimeError(
        name,
        `Bundle it in desktop/resources/bin/${platformKey()}/ or set APP_${name.toUpperCase()}_BIN.`
      );
    }
  }
}

async function startShiny() {
  appendStartupLog(`\n--- CGeV Desktop startup ${new Date().toISOString()} ---\n`);
  sendStatus({ phase: "starting", message: "Preparing CGeV Desktop..." });
  const root = appRoot();
  const dataRoot = defaultDataRoot();
  const cacheRoot = defaultCacheRoot();
  fs.mkdirSync(dataRoot, { recursive: true });
  fs.mkdirSync(cacheRoot, { recursive: true });
  ensureDataRootStructure(dataRoot);
  seedCommonGoData(dataRoot);
  seedBundledData(dataRoot);
  seedDemoData(dataRoot);
  seedBundledCache(cacheRoot);

  const runtimeRoot = await prepareRuntime();
  preparedRuntimeRoot = runtimeRoot;
  const port = Number(process.env.APP_PORT || await getFreePort());
  const rscript = findRscript(runtimeRoot);
  const lastz = findBundledBinary("lastz", "APP_LASTZ_BIN", runtimeRoot);
  const samtools = findBundledBinary("samtools", "APP_SAMTOOLS_BIN", runtimeRoot);
  const tabix = findBundledBinary("tabix", "APP_TABIX_BIN", runtimeRoot);
  validateRuntime(rscript, { lastz, samtools, tabix });

  const binDirs = runtimeBinDirs(runtimeRoot, rscript);
  const pathEntries = [
    ...binDirs,
    path.dirname(lastz),
    samtools && path.dirname(samtools),
    tabix && path.dirname(tabix),
    process.env.PATH
  ].filter(Boolean);

  const env = {
    ...process.env,
    APP_PORT: String(port),
    APP_HOST: "127.0.0.1",
    APP_FUTURE_MODE: process.env.APP_FUTURE_MODE || "multisession",
    APP_FUTURE_WORKERS: process.env.APP_FUTURE_WORKERS || String(Math.max(1, Math.min(2, os.cpus().length - 1))),
    APP_LASTZ_WORKERS: process.env.APP_LASTZ_WORKERS || String(Math.max(1, Math.min(2, os.cpus().length - 1))),
    APP_LASTZ_TIMEOUT_SECONDS: process.env.APP_LASTZ_TIMEOUT_SECONDS || "90",
    APP_LASTZ_MAX_SEQUENCE_BP: process.env.APP_LASTZ_MAX_SEQUENCE_BP || "2000000",
    APP_LASTZ_CACHE_MAX_ENTRIES: process.env.APP_LASTZ_CACHE_MAX_ENTRIES || "12",
    APP_LASTZ_CACHE_MAX_MB: process.env.APP_LASTZ_CACHE_MAX_MB || "64",
    APP_MEMORY_CACHE_BUDGET_MB: process.env.APP_MEMORY_CACHE_BUDGET_MB || "1024",
    APP_SEQ_EXTRACT_CACHE_MAX_MB: process.env.APP_SEQ_EXTRACT_CACHE_MAX_MB || "256",
    APP_SPLICED_SEQ_CACHE_MAX_MB: process.env.APP_SPLICED_SEQ_CACHE_MAX_MB || "192",
    APP_ALIAS_SQLITE_CACHE_MB: process.env.APP_ALIAS_SQLITE_CACHE_MB || "16",
    APP_ALIAS_SQLITE_MAX_CONNECTIONS: process.env.APP_ALIAS_SQLITE_MAX_CONNECTIONS || "8",
    APP_LASTZ_DISK_CACHE: process.env.APP_LASTZ_DISK_CACHE || "1",
    APP_LASTZ_DISK_CACHE_MAX_MB: process.env.APP_LASTZ_DISK_CACHE_MAX_MB || "512",
    APP_LASTZ_DISK_CACHE_TTL_DAYS: process.env.APP_LASTZ_DISK_CACHE_TTL_DAYS || "30",
    APP_PREWARM_ON_START: "0",
    APP_ORTHO_WORKER_PREWARM: process.env.APP_ORTHO_WORKER_PREWARM || "0",
    APP_ORTHO_BACKGROUND_CACHE_WARM: process.env.APP_ORTHO_BACKGROUND_CACHE_WARM || "0",
    APP_ORTHO_PREFLIGHT_SUGGESTIONS: process.env.APP_ORTHO_PREFLIGHT_SUGGESTIONS || "0",
    APP_ORTHO_PREWARM_LOCAL_HANDLES: process.env.APP_ORTHO_PREWARM_LOCAL_HANDLES || "1",
    APP_ORTHO_PREFER_MAIN_CACHE: process.env.APP_ORTHO_PREFER_MAIN_CACHE || "1",
    APP_ORTHO_REQUIRE_VERIFIED_ORTHOLOGY: process.env.APP_ORTHO_REQUIRE_VERIFIED_ORTHOLOGY || "0",
    APP_FAST_ORGANISM_SYNC: process.env.APP_FAST_ORGANISM_SYNC || "1",
    APP_IDLE_AUTOCOMPLETE_MIGRATION: process.env.APP_IDLE_AUTOCOMPLETE_MIGRATION || "1",
    APP_ANNOTATION_DISK_CACHE_MAX_FILES: process.env.APP_ANNOTATION_DISK_CACHE_MAX_FILES || "192",
    APP_SESSION_METRICS: process.env.APP_SESSION_METRICS || "0",
    APP_PERF_TIMING: process.env.APP_PERF_TIMING || "0",
    APP_TRANSPORT_TIMING: process.env.APP_TRANSPORT_TIMING || "0",
    APP_INLINE_FAST_SEQUENCE_PREFETCH: process.env.APP_INLINE_FAST_SEQUENCE_PREFETCH || "1",
    APP_GENE_PLOT_RENDERER_PREWARM: process.env.APP_GENE_PLOT_RENDERER_PREWARM || "1",
    APP_HOMO_INITIAL_VISIBLE: process.env.APP_HOMO_INITIAL_VISIBLE || "1",
    APP_ORTHO_INITIAL_VISIBLE: process.env.APP_ORTHO_INITIAL_VISIBLE || "1",
    APP_HOMO_UPFRONT_ISOFORMS: process.env.APP_HOMO_UPFRONT_ISOFORMS || "0",
    APP_ORTHO_UPFRONT_ISOFORMS: process.env.APP_ORTHO_UPFRONT_ISOFORMS || "0",
    APP_HOMO_RENDER_CHUNK_SIZE: process.env.APP_HOMO_RENDER_CHUNK_SIZE || "1",
    APP_HOMO_AUTO_RENDER_DELAY_MS: process.env.APP_HOMO_AUTO_RENDER_DELAY_MS || "120",
    APP_ORTHO_RENDER_CHUNK_SIZE: process.env.APP_ORTHO_RENDER_CHUNK_SIZE || "1",
    APP_ORTHO_AUTO_RENDER_MORE: process.env.APP_ORTHO_AUTO_RENDER_MORE || "1",
    APP_ORTHO_AUTO_RENDER_DELAY_MS: process.env.APP_ORTHO_AUTO_RENDER_DELAY_MS || "120",
    APP_ISOFORM_RENDER_BATCH_SIZE: process.env.APP_ISOFORM_RENDER_BATCH_SIZE || "1",
    APP_ISOFORM_RENDER_BATCH_DELAY_MS: process.env.APP_ISOFORM_RENDER_BATCH_DELAY_MS || "2500",
    APP_ORTHO_SERVER_RENDER_NUDGE: process.env.APP_ORTHO_SERVER_RENDER_NUDGE || "0",
    APP_ORTHO_LOOKUP_PARALLEL_MIN_JOBS: process.env.APP_ORTHO_LOOKUP_PARALLEL_MIN_JOBS || "4",
    APP_ORTHO_SUSPEND_HIDDEN: process.env.APP_ORTHO_SUSPEND_HIDDEN || "1",
    APP_GENE_CATALOG_ENABLED: process.env.APP_GENE_CATALOG_ENABLED || "0",
    APP_HOMO_DEFER_SEQUENCE: process.env.APP_HOMO_DEFER_SEQUENCE || "0",
    APP_ORTHO_DEFER_SEQUENCE: process.env.APP_ORTHO_DEFER_SEQUENCE || "0",
    APP_FOOTER_DEFER_SEQUENCE: process.env.APP_FOOTER_DEFER_SEQUENCE || "0",
    APP_DEFER_FEATURE_GC: process.env.APP_DEFER_FEATURE_GC || "0",
    APP_ANALYTICS_PHASE2_DELAY_MS: process.env.APP_ANALYTICS_PHASE2_DELAY_MS || "0",
    APP_ANALYTICS_PHASE3_DELAY_MS: process.env.APP_ANALYTICS_PHASE3_DELAY_MS || "0",
    APP_CACHE_WARM_EAGER: "1",
    CGV_RUNTIME: "desktop",
    CGV_RELEASE_VERSION: app.getVersion(),
    CGV_DATA_ROOT: dataRoot,
    CGV_CACHE_DIR: cacheRoot,
    APP_ALIAS_DISK_CACHE_DIR: path.join(cacheRoot, "external_alias"),
    CGV_NCBI_DOWNLOADS_DIR: path.join(dataRoot, "ncbi_downloads"),
    PATH: pathEntries.join(path.delimiter)
  };
  if (process.platform === "win32") env.R_HOME = runtimeRoot;
  if (process.platform === "linux") {
    const fontconfigFile = path.join(runtimeRoot, "etc", "fonts", "fonts.conf");
    const fontconfigPath = path.join(runtimeRoot, "etc", "fonts");
    if (isFile(fontconfigFile)) env.FONTCONFIG_FILE = fontconfigFile;
    if (fs.existsSync(fontconfigPath)) env.FONTCONFIG_PATH = fontconfigPath;
  }
  if (lastz) env.APP_LASTZ_BIN = lastz;
  if (samtools) env.APP_SAMTOOLS_BIN = samtools;
  if (tabix) env.APP_TABIX_BIN = tabix;

  shinyUrl = `http://127.0.0.1:${port}`;
  logStartupLine("electron", `Starting CGeV on ${shinyUrl}`);
  logStartupLine("electron", `Rscript: ${rscript}`);
  logStartupLine("electron", `Runtime: ${runtimeRoot}`);
  logStartupLine("electron", `Data: ${dataRoot}`);
  logStartupLine("electron", `Cache: ${cacheRoot}`);
  sendStatus({
    phase: "starting",
    message: "Preparing CGeV Desktop..."
  });

  shinyProcess = spawn(rscript, [
    "-e",
    `shiny::runApp(${JSON.stringify(root)}, host='127.0.0.1', port=as.integer(${port}), launch.browser=FALSE)`
  ], {
    cwd: root,
    env,
    windowsHide: true,
    stdio: ["ignore", "pipe", "pipe"]
  });

  const recentRLines = [];
  const rememberRLine = (message) => {
    for (const line of String(message || "").split(/\r?\n/)) {
      const clean = line.trim();
      if (clean) recentRLines.push(clean);
    }
    while (recentRLines.length > 24) recentRLines.shift();
  };

  shinyProcess.stdout.on("data", (chunk) => {
    const message = chunk.toString();
    rememberRLine(message);
    logStartupLine("R stdout", message);
    sendStatus({ phase: "log", message });
  });
  shinyProcess.stderr.on("data", (chunk) => {
    const message = chunk.toString();
    rememberRLine(message);
    logStartupLine("R stderr", message);
    sendStatus({ phase: "log", message });
  });
  shinyProcess.on("exit", (code, signal) => {
    const stoppedDuringStartup = Boolean(shinyStartPromise);
    const message = `R/Shiny stopped (${code ?? signal})`;
    logStartupLine("electron", message);
    sendStatus({ phase: "stopped", message });
    shinyProcess = null;
    if (!appIsQuitting && !stoppedDuringStartup && mainWindow && !mainWindow.isDestroyed() && signal !== "SIGTERM") {
      mainWindow.loadFile(path.join(__dirname, "launcher.html"));
    }
  });
  shinyProcess.on("error", (error) => {
    const message = `Unable to start R/Shiny: ${error.message}`;
    logStartupLine("electron", message);
    sendStatus({ phase: "error", message });
  });

  await waitForShinyReady(shinyUrl, shinyProcess, () => recentRLines);
  logStartupLine("electron", `CGeV is ready at ${shinyUrl}`);
  sendStatus({ phase: "ready", message: "CGeV is ready", url: shinyUrl, dataRoot, cacheRoot });
  return shinyUrl;
}

function manifestPath() {
  if (process.env.CGV_DESKTOP_MANIFEST) return process.env.CGV_DESKTOP_MANIFEST;
  const packaged = resourcePath("data-manifest.json");
  const dev = path.join(__dirname, "..", "data-manifest.json");
  if (fs.existsSync(packaged)) return packaged;
  if (fs.existsSync(dev)) return dev;
  return "";
}

function readManifest() {
  const filePath = manifestPath();
  if (!filePath || !fs.existsSync(filePath)) return { datasets: [] };
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function localCatalogPath() {
  if (process.env.CGV_DESKTOP_LOCAL_CATALOG) return process.env.CGV_DESKTOP_LOCAL_CATALOG;
  const packaged = resourcePath("catalog.json");
  const dev = path.join(__dirname, "..", "catalog.json");
  if (fs.existsSync(packaged)) return packaged;
  if (fs.existsSync(dev)) return dev;
  return "";
}

function readLocalCatalog() {
  const filePath = localCatalogPath();
  if (!filePath || !fs.existsSync(filePath)) return { datasets: [] };
  try {
    return { ...JSON.parse(fs.readFileSync(filePath, "utf8")), source: `file://${filePath}` };
  } catch (_) {
    return { datasets: [] };
  }
}

function catalogResponseUrlHash(url) {
  return crypto.createHash("sha256").update(String(url || ""), "utf8").digest("hex");
}

function catalogResponseCachePath(url) {
  return path.join(
    defaultCacheRoot(),
    "desktop-catalog-http",
    `${catalogResponseUrlHash(url).slice(0, 32)}.json`
  );
}

function normalizedHttpEtag(value) {
  const etag = String(value || "").trim();
  if (!etag || etag.length > 1024 || /[\r\n]/.test(etag)) return "";
  return etag;
}

function readCatalogResponseCache(cachePath, url) {
  if (!cachePath || !fs.existsSync(cachePath)) return null;
  try {
    const cached = JSON.parse(fs.readFileSync(cachePath, "utf8"));
    if (!cached || cached.version !== 1 || cached.urlHash !== catalogResponseUrlHash(url)) return null;
    if (!Object.prototype.hasOwnProperty.call(cached, "body")) return null;
    return {
      body: cached.body,
      etag: normalizedHttpEtag(cached.etag)
    };
  } catch (_) {
    return null;
  }
}

function writeCatalogResponseCache(cachePath, url, etag, body) {
  if (!cachePath) return false;
  let temporaryPath = "";
  try {
    const cacheDir = path.dirname(cachePath);
    temporaryPath = `${cachePath}.${process.pid}.${Date.now()}.${crypto.randomBytes(6).toString("hex")}.tmp`;
    fs.mkdirSync(cacheDir, { recursive: true });
    fs.writeFileSync(temporaryPath, `${JSON.stringify({
      version: 1,
      urlHash: catalogResponseUrlHash(url),
      etag: normalizedHttpEtag(etag),
      body
    })}\n`, { encoding: "utf8", mode: 0o600 });
    fs.renameSync(temporaryPath, cachePath);
    return true;
  } catch (_) {
    return false;
  } finally {
    try {
      if (temporaryPath && fs.existsSync(temporaryPath)) fs.unlinkSync(temporaryPath);
    } catch (_) {}
  }
}

function requestJsonWithEtag(url, etag, timeoutMs) {
  const client = url.startsWith("https:") ? https : http;
  return new Promise((resolve, reject) => {
    const headers = etag ? { "If-None-Match": etag } : {};
    const request = client.get(url, { headers }, (response) => {
      if ([301, 302, 303, 307, 308].includes(response.statusCode) && response.headers.location) {
        response.resume();
        let redirectUrl;
        try {
          redirectUrl = new URL(response.headers.location, url).toString();
        } catch (error) {
          reject(error);
          return;
        }
        requestJsonWithEtag(redirectUrl, etag, timeoutMs).then(resolve, reject);
        return;
      }
      if (response.statusCode === 304 && etag) {
        response.resume();
        resolve({ notModified: true, etag });
        return;
      }
      if (response.statusCode !== 200) {
        response.resume();
        reject(new Error(`Catalog request failed with HTTP ${response.statusCode}: ${url}`));
        return;
      }
      let body = "";
      response.setEncoding("utf8");
      response.on("data", (chunk) => {
        body += chunk;
      });
      response.on("end", () => {
        try {
          resolve({
            body: JSON.parse(body),
            etag: normalizedHttpEtag(response.headers.etag),
            notModified: false
          });
        } catch (error) {
          reject(new Error(`Catalog JSON could not be parsed: ${error.message}`));
        }
      });
    });
    request.on("error", reject);
    request.setTimeout(timeoutMs, () => {
      request.destroy(new Error(`Catalog request timed out: ${url}`));
    });
  });
}

function httpGetJson(url, options = {}) {
  const cachePath = options.cachePath || "";
  const cached = readCatalogResponseCache(cachePath, url);
  const etag = cached && cached.etag ? cached.etag : "";
  const timeoutMs = Number.isFinite(Number(options.timeoutMs)) && Number(options.timeoutMs) > 0
    ? Number(options.timeoutMs)
    : 15000;
  // There is deliberately no TTL or stale-on-error path: every caller reaches
  // the origin, and the persisted body is used only after a valid HTTP 304.
  return requestJsonWithEtag(url, etag, timeoutMs).then((response) => {
    if (response.notModified) return cached.body;
    writeCatalogResponseCache(cachePath, url, response.etag, response.body);
    return response.body;
  });
}

function isHttpUrl(value) {
  return /^https?:\/\//i.test(value || "");
}

function isFileUrl(value) {
  return /^file:\/\//i.test(value || "");
}

function resolveCatalogResourceUrl(resourceUrl, dataset, manifest) {
  if (!resourceUrl || isHttpUrl(resourceUrl) || isFileUrl(resourceUrl) || path.isAbsolute(resourceUrl)) {
    return resourceUrl;
  }
  const base = dataset.source || manifest.catalogUrl || process.env.CGV_DESKTOP_CATALOG_URL || "";
  if (isHttpUrl(base) || isFileUrl(base)) {
    return new URL(resourceUrl, base).toString();
  }
  return resourceUrl;
}

function emitDownloadProgress(datasetId, payload) {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.webContents.send("cgv:download-progress", { datasetId, ...payload });
  }
}

function localInstallRegistryPath(dataRoot = defaultDataRoot()) {
  return path.join(dataRoot, "desktop-datasets.json");
}

function readInstallRegistry(dataRoot = defaultDataRoot()) {
  const registryPath = localInstallRegistryPath(dataRoot);
  if (!fs.existsSync(registryPath)) return { version: 1, datasets: {} };
  try {
    return JSON.parse(fs.readFileSync(registryPath, "utf8"));
  } catch (_) {
    return { version: 1, datasets: {} };
  }
}

function writeInstallRegistry(registry, dataRoot = defaultDataRoot()) {
  const registryPath = localInstallRegistryPath(dataRoot);
  fs.mkdirSync(path.dirname(registryPath), { recursive: true });
  fs.writeFileSync(registryPath, `${JSON.stringify(registry, null, 2)}\n`);
}

function enqueueDatasetInstall(task) {
  const run = datasetInstallQueue.then(task, task);
  datasetInstallQueue = run.catch(() => {});
  return run;
}

function mergeDatasetCatalogs(baseManifest, remoteManifest) {
  const retiredDatasetIds = new Set([
    "triticum_aestivum_gcf_018294505_1_iwgsc_cs_refseq_v2_1_genomic"
  ]);
  const byId = new Map();
  for (const dataset of baseManifest.datasets || []) {
    if (!retiredDatasetIds.has(dataset.id)) byId.set(dataset.id, dataset);
  }
  for (const dataset of remoteManifest.datasets || []) {
    if (retiredDatasetIds.has(dataset.id)) continue;
    byId.set(dataset.id, { ...byId.get(dataset.id), ...dataset, source: remoteManifest.source || "remote" });
  }
  return {
    ...baseManifest,
    remoteCatalog: remoteManifest,
    datasets: Array.from(byId.values())
  };
}

async function readMergedManifest() {
  const baseManifest = readManifest();
  const localCatalog = readLocalCatalog();
  const baseWithLocal = (localCatalog.datasets || []).length
    ? mergeDatasetCatalogs(baseManifest, localCatalog)
    : baseManifest;
  const catalogUrl = process.env.CGV_DESKTOP_CATALOG_URL || baseManifest.catalogUrl || "";
  if (!catalogUrl) return baseWithLocal;
  try {
    const remoteManifest = await httpGetJson(catalogUrl, {
      cachePath: catalogResponseCachePath(catalogUrl)
    });
    return mergeDatasetCatalogs(baseWithLocal, { ...remoteManifest, source: catalogUrl });
  } catch (error) {
    return {
      ...baseWithLocal,
      catalogError: error.message
    };
  }
}

async function fileMatchesSha256(filePath, expectedSha256) {
  if (!expectedSha256 || !isFile(filePath)) return false;
  const actual = await sha256File(filePath);
  return actual.toLowerCase() === expectedSha256.toLowerCase();
}

function datasetInstallState(dataset, dataRoot = defaultDataRoot()) {
  if (dataset.downloadable === false) {
    return { status: "bundled", files: [], installedFiles: 0, partialFiles: 0, totalFiles: 0 };
  }
  const registry = readInstallRegistry(dataRoot);
  const installed = registry.datasets && registry.datasets[dataset.id];
  const packageInfo = dataset.package || null;
  const packagePath = packageInfo
    ? path.join(dataRoot, "packages", `${dataset.id}-${dataset.version || "latest"}.zip`)
    : "";
  const packagePartPath = packagePath ? `${packagePath}.part` : "";

  const files = dataset.files || [];
  const states = files.map((file) => {
    const targetPath = path.join(dataRoot, file.path);
    const partPath = `${targetPath}.part`;
    return {
      path: file.path,
      required: file.required !== false,
      installed: isFile(targetPath),
      partial: isFile(partPath),
      sizeBytes: file.sizeBytes || null,
      sha256: file.sha256 || ""
    };
  });
  const required = states.filter((file) => file.required);
  const installedRequired = required.filter((file) => file.installed).length;
  let status = required.length > 0 && installedRequired === required.length ? "installed" : "not_installed";
  if (packageInfo) {
    if (installed && installed.version === dataset.version && installed.sha256 === packageInfo.sha256) {
      status = "installed";
    } else if (installed && installed.version !== dataset.version) {
      status = "update_available";
    } else if (isFile(packagePartPath)) {
      status = "partial";
    } else {
      status = "not_installed";
    }
  }
  return {
    files: states,
    installedFiles: states.filter((file) => file.installed).length,
    partialFiles: states.filter((file) => file.partial).length,
    totalFiles: states.length,
    installedAt: installed ? installed.installedAt : null,
    packagePath: packagePath || null,
    status
  };
}

async function readManifestWithState() {
  const manifest = await readMergedManifest();
  const dataRoot = defaultDataRoot();
  return {
    ...manifest,
    dataRoot,
    cacheRoot: defaultCacheRoot(),
    datasets: (manifest.datasets || []).map((dataset) => ({
      ...dataset,
      local: datasetInstallState(dataset, dataRoot)
    }))
  };
}

function runFile(command, args) {
  return new Promise((resolve, reject) => {
    execFile(command, args, { encoding: "utf8", maxBuffer: 1024 * 1024 * 20, windowsHide: true }, (error, stdout, stderr) => {
      if (error) {
        reject(new Error(`${command} ${args.join(" ")} failed: ${stderr || stdout || error.message}`));
        return;
      }
      resolve({ stdout, stderr });
    });
  });
}

function readTsvRows(filePath) {
  if (!fs.existsSync(filePath)) return { headers: [], rows: [] };
  const text = fs.readFileSync(filePath, "utf8").trim();
  if (!text) return { headers: [], rows: [] };
  const lines = text.split(/\r?\n/);
  const headers = lines.shift().split("\t");
  const rows = lines.filter(Boolean).map((line) => {
    const values = line.split("\t");
    return Object.fromEntries(headers.map((header, index) => [header, values[index] || ""]));
  });
  return { headers, rows };
}

function writeTsvRows(filePath, headers, rows) {
  if (!headers.length) return;
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  const body = rows.map((row) => headers.map((header) => row[header] || "").join("\t"));
  fs.writeFileSync(filePath, `${headers.join("\t")}\n${body.join("\n")}\n`);
}

function mergeRegistryFile(sourcePath, targetPath, keyColumns) {
  if (!fs.existsSync(sourcePath)) return;
  const source = readTsvRows(sourcePath);
  if (!source.headers.length) return;
  const target = readTsvRows(targetPath);
  const headers = target.headers.length
    ? Array.from(new Set(target.headers.concat(source.headers)))
    : source.headers;
  const keyFor = (row) => {
    for (const key of keyColumns) {
      const value = String(row[key] || "").trim();
      if (value) return `${key}:${value}`;
    }
    return JSON.stringify(row);
  };
  const byKey = new Map();
  for (const row of target.rows) byKey.set(keyFor(row), row);
  for (const row of source.rows) byKey.set(keyFor(row), { ...byKey.get(keyFor(row)), ...row });
  writeTsvRows(targetPath, headers, Array.from(byKey.values()));
}

function copyDirContents(sourceDir, targetDir, skipRelPaths = new Set(), relPrefix = "") {
  if (!fs.existsSync(sourceDir)) return;
  fs.mkdirSync(targetDir, { recursive: true });
  for (const name of fs.readdirSync(sourceDir)) {
    const relPath = relPrefix ? path.join(relPrefix, name) : name;
    if (skipRelPaths.has(relPath)) continue;
    const sourcePath = path.join(sourceDir, name);
    const targetPath = path.join(targetDir, name);
    const stat = fs.statSync(sourcePath);
    if (stat.isDirectory()) {
      copyDirContents(sourcePath, targetPath, skipRelPaths, relPath);
    } else {
      fs.mkdirSync(path.dirname(targetPath), { recursive: true });
      fs.copyFileSync(sourcePath, targetPath);
    }
  }
}

async function validateZipEntries(zipPath) {
  return validateZipArchive(zipPath);
}

async function extractDatasetPackage(zipPath, dataRoot, cacheRoot) {
  await validateZipEntries(zipPath);
  const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-dataset-install-"));
  let cacheStats = { bundled: 0, migrated: 0, alreadyPresent: 0 };
  try {
    await extractZipArchive(zipPath, tmpRoot);
    cacheStats = migrateAnnotationIndexCache(path.join(tmpRoot, "cache", "annotation_index"), cacheRoot);
    const registryPaths = new Set([
      path.join("annotations", "registry.tsv"),
      path.join("genomes", "registry.tsv"),
      path.join("go_annotations", "registry.tsv"),
      path.join("cache", "annotation_index")
    ]);
    copyDirContents(tmpRoot, dataRoot, registryPaths);
    mergeRegistryFile(
      path.join(tmpRoot, "annotations", "registry.tsv"),
      path.join(dataRoot, "annotations", "registry.tsv"),
      ["species_id", "taxid", "organism"]
    );
    mergeRegistryFile(
      path.join(tmpRoot, "genomes", "registry.tsv"),
      path.join(dataRoot, "genomes", "registry.tsv"),
      ["species_id", "taxid", "organism", "fasta", "two_bit"]
    );
    mergeRegistryFile(
      path.join(tmpRoot, "go_annotations", "registry.tsv"),
      path.join(dataRoot, "go_annotations", "registry.tsv"),
      ["species_id", "taxid", "organism", "gaf_file"]
    );
  } finally {
    fs.rmSync(tmpRoot, { recursive: true, force: true });
  }
  return cacheStats;
}

async function warmDatasetAfterInstall(dataset, dataRoot, cacheRoot) {
  const speciesId = String(dataset.speciesId || dataset.id || "");
  if (!speciesId) return { stdout: "", stderr: "" };
  const registryPath = path.join(dataRoot, "annotations", "registry.tsv");
  const registry = readTsvRows(registryPath);
  const hit = registry.rows.find((row) => String(row.species_id || "") === speciesId);
  if (!hit) return { stdout: "", stderr: "" };
  const relAnnotation = hit.annotation_tabix || hit.annotation || "";
  const annotationPath = relAnnotation ? path.join(dataRoot, relAnnotation) : "";
  const aliasSqlitePath = path.join(dataRoot, "data", "alias_index", `${speciesId}.alias_index.sqlite`);
  const rscript = findRscript(preparedRuntimeRoot);
  const root = appRoot();
  const rCode = `
    Sys.setenv(
      CGV_DATA_ROOT=${JSON.stringify(dataRoot)},
      CGV_CACHE_DIR=${JSON.stringify(cacheRoot)}
    )
    suppressPackageStartupMessages({
      library(dplyr)
      library(tidyr)
      library(purrr)
      library(stringr)
    })
    source(${JSON.stringify(path.join(root, "R", "utils.R"))})
    source(${JSON.stringify(path.join(root, "R", "server_go_domain.R"))})
    alias_file <- ${JSON.stringify(aliasSqlitePath)}
    if (file.exists(alias_file)) {
      source(${JSON.stringify(path.join(root, "R", "alias_resolution.R"))})
      alias_ok <- isTRUE(warm_alias_index(${JSON.stringify(speciesId)}, base_dir=${JSON.stringify(root)}))
      if (!isTRUE(alias_ok)) {
        stop("alias index warmup failed for ${speciesId}", call. = FALSE)
      }
      cat("alias index ready\\n")
    }
    ann_path <- ${JSON.stringify(annotationPath)}
    if (nzchar(ann_path) && file.exists(ann_path)) {
      existing_cache <- find_existing_gff_disk_index_path(ann_path, cache_kind="gene_light", base_dir=${JSON.stringify(root)})
      if (nzchar(existing_cache) && file.exists(existing_cache)) {
        cat("annotation cache already present\\n")
        idx <- load_gff_index_from_disk(ann_path, cache_kind="gene_light", base_dir=${JSON.stringify(root)})
      } else {
        invisible(capture.output({
          idx <- precompute_annotation_index_cache(ann_path, base_dir=${JSON.stringify(root)})
        }))
        if (is.null(idx)) {
          stop("annotation cache precompute returned NULL", call. = FALSE)
        }
        cat("annotation cache regenerated\\n")
      }
      if (is.null(idx)) {
        idx <- precompute_annotation_index_cache(ann_path, base_dir=${JSON.stringify(root)})
      }
      autocomplete_cache <- ensure_gff_autocomplete_cache(
        ann_path,
        idx,
        base_dir=${JSON.stringify(root)}
      )
      if (is.null(autocomplete_cache)) {
        stop("autocomplete sidecar preparation failed", call. = FALSE)
      }
      cat("autocomplete sidecar ready\\n")
      if (!isTRUE(slim_gff_gene_light_index_file(ann_path, base_dir=${JSON.stringify(root)}))) {
        stop("annotation cache slimming failed", call. = FALSE)
      }
      cat("annotation cache slimmed\\n")
    }
    go_registry_path <- file.path(${JSON.stringify(dataRoot)}, "go_annotations", "registry.tsv")
    if (file.exists(go_registry_path)) {
      go_registry <- read.delim(go_registry_path, sep="\\t", stringsAsFactors=FALSE, check.names=FALSE)
      go_hit <- go_registry[
        as.character(go_registry$species_id %||% "") == ${JSON.stringify(speciesId)} |
        as.character(go_registry$taxid %||% "") == ${JSON.stringify(String(hit.taxid || ""))},
        ,
        drop=FALSE
      ]
      if (nrow(go_hit) > 0L) {
        gaf_rel <- as.character(go_hit$gaf_file[1] %||% "")
        gaf_path <- if (grepl("^/", gaf_rel)) gaf_rel else file.path(${JSON.stringify(dataRoot)}, gaf_rel)
        configured_rel <- as.character(go_hit$index_file[1] %||% "")
        configured_path <- if (nzchar(configured_rel)) {
          if (grepl("^/", configured_rel)) configured_rel else file.path(${JSON.stringify(dataRoot)}, configured_rel)
        } else ""
        valid_index <- nzchar(configured_path) && go_index_is_valid(
          configured_path,
          gaf_path,
          expected_fingerprint=as.character(go_hit$index_fingerprint[1] %||% "")
        )
        if (!isTRUE(valid_index) && file.exists(gaf_path)) {
          cache_index <- go_index_cache_path(gaf_path, base_dir=${JSON.stringify(root)})
          build_go_gaf_index(gaf_path, cache_index, force=FALSE)
          cat("GO index generated in cache\\n")
        } else if (isTRUE(valid_index)) {
          cat("GO index ready\\n")
        }
      }
    }
  `;
  return runFile(rscript, ["-e", rCode]);
}

function stopShinyProcess() {
  const processToStop = shinyProcess;
  shinyProcess = null;
  if (!processToStop || !processToStop.pid) return;
  if (process.platform === "win32") {
    spawnSync("taskkill", ["/PID", String(processToStop.pid), "/T", "/F"], {
      windowsHide: true,
      stdio: "ignore"
    });
    return;
  }
  try { processToStop.kill(); } catch (_) {}
}

async function startShinyAndLoad() {
  if (shinyUrl && shinyProcess) return shinyUrl;
  if (shinyStartPromise) return shinyStartPromise;
  shinyStartPromise = (async () => {
    const url = await startShiny();
    if (mainWindow && !mainWindow.isDestroyed()) await mainWindow.loadURL(url);
    return url;
  })();
  try {
    return await shinyStartPromise;
  } catch (error) {
    logStartupLine("electron:error", error.message);
    sendStatus({ phase: "error", message: error.message });
    throw error;
  } finally {
    shinyStartPromise = null;
  }
}

async function changeStorageRootAndRestart() {
  const confirmation = await dialog.showMessageBox(mainWindow || undefined, {
    type: "info",
    title: "Change CGeV Desktop data folder",
    message: "Existing genomes and caches will not be moved or deleted.",
    detail: "CGeV Desktop will restart and use the selected folder. Select the previous folder again to reuse its data.",
    buttons: ["Choose folder", "Cancel"],
    defaultId: 0,
    cancelId: 1
  });
  if (confirmation.response !== 0) return;
  const selected = await promptForStorageRoot();
  if (!selected) return;
  appIsQuitting = true;
  stopShinyProcess();
  app.relaunch();
  app.quit();
}

function installApplicationMenu() {
  if (process.platform !== "win32") return;
  const menu = Menu.buildFromTemplate([
    {
      label: "File",
      submenu: [
        { label: "Change data folder...", click: () => changeStorageRootAndRestart() },
        {
          label: "Open data folder",
          click: () => {
            fs.mkdirSync(defaultDataRoot(), { recursive: true });
            shell.openPath(defaultDataRoot());
          }
        },
        {
          label: "Show diagnostics log",
          click: () => {
            const logPath = getStartupLogPath();
            fs.mkdirSync(path.dirname(logPath), { recursive: true });
            if (!fs.existsSync(logPath)) fs.writeFileSync(logPath, "");
            shell.showItemInFolder(logPath);
          }
        },
        {
          label: "Privacy policy",
          click: () => shell.openPath(resourcePath("legal", "PRIVACY.md"))
        },
        { type: "separator" },
        { role: "quit" }
      ]
    },
    {
      label: "Edit",
      submenu: [
        { role: "undo" },
        { role: "redo" },
        { type: "separator" },
        { role: "cut" },
        { role: "copy" },
        { role: "paste" },
        { role: "selectAll" }
      ]
    },
    {
      label: "View",
      submenu: [
        { role: "resetZoom" },
        { role: "zoomIn" },
        { role: "zoomOut" },
        { type: "separator" },
        { role: "togglefullscreen" }
      ]
    },
    {
      label: "Window",
      submenu: [{ role: "minimize" }, { role: "close" }]
    }
  ]);
  Menu.setApplicationMenu(menu);
}

async function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1320,
    height: 900,
    minWidth: 1100,
    minHeight: 720,
    title: "CGeV Desktop",
    icon: windowIconPath(),
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  mainWindow.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url);
    return { action: "deny" };
  });
  if (exportDownloadSession !== mainWindow.webContents.session) {
    exportDownloadSession = mainWindow.webContents.session;
    exportDownloadSession.on("will-download", (_event, item) => {
      item.setSaveDialogOptions({
        title: "Save CGeV export",
        defaultPath: item.getFilename()
      });
    });
  }

  await mainWindow.loadFile(path.join(__dirname, "launcher.html"));
  installApplicationMenu();
  setupAutoUpdater();
  if (!await ensureStorageConfigured()) return;
  try { await startShinyAndLoad(); } catch (_) {}
}

ipcMain.handle("cgv:get-runtime", () => ({
  appRoot: appRoot(),
  dataRoot: defaultDataRoot(),
  cacheRoot: defaultCacheRoot(),
  startupLogPath: getStartupLogPath(),
  shinyUrl,
  platform: process.platform,
  arch: process.arch,
  appVersion: app.getVersion()
}));

ipcMain.handle("cgv:get-storage-settings", () => ({
  storageRoot: configuredStorageRoot(),
  dataRoot: defaultDataRoot(),
  cacheRoot: defaultCacheRoot()
}));

ipcMain.handle("cgv:choose-storage-root", async () => {
  const selected = await promptForStorageRoot();
  if (!selected) return { ok: false, canceled: true };
  sendStatus({ phase: "starting", message: "Starting CGeV Desktop..." });
  try {
    await startShinyAndLoad();
    return { ok: true, ...selected };
  } catch (error) {
    return { ok: false, message: error.message };
  }
});

ipcMain.handle("cgv:show-startup-log", async () => {
  const logPath = getStartupLogPath();
  fs.mkdirSync(path.dirname(logPath), { recursive: true });
  if (!fs.existsSync(logPath)) fs.writeFileSync(logPath, "");
  return shell.showItemInFolder(logPath);
});

ipcMain.handle("cgv:list-datasets", () => readManifestWithState());

ipcMain.handle("cgv:remove-installed-organisms", async (_event, datasetIds) => {
  const dataRoot = defaultDataRoot();
  const cacheRoot = defaultCacheRoot();
  assertOrganismRemovalAllowed(dataRoot);
  const installRegistry = readInstallRegistry(dataRoot);
  const manifest = await readMergedManifest();
  const removableIds = (manifest.datasets || []).filter((dataset) => {
    if (dataset.downloadable === false) return false;
    const status = datasetInstallState(dataset, dataRoot).status;
    return status === "installed" || status === "update_available";
  }).map((dataset) => dataset.id);
  const requestedIds = Array.isArray(datasetIds)
    ? Array.from(new Set(datasetIds.map((id) => String(id || "").trim()).filter(Boolean)))
    : removableIds;
  const unavailableIds = requestedIds.filter((id) => !removableIds.includes(id));
  if (unavailableIds.length) {
    throw new Error(`These organisms are not installed or cannot be removed: ${unavailableIds.join(", ")}`);
  }
  const activeIds = requestedIds.filter((id) => datasetInstallControllers.has(id));
  if (activeIds.length) {
    throw new Error(`Cancel or wait for the active download before removing: ${activeIds.join(", ")}`);
  }
  const result = await enqueueDatasetInstall(() => removeInstalledDatasets({
    dataRoot,
    cacheRoot,
    datasetIds: requestedIds,
    manifest,
    installRegistry,
    validateZipArchive
  }));
  ensureDataRootStructure(dataRoot);
  seedCommonGoData(dataRoot);
  fs.mkdirSync(cacheRoot, { recursive: true });
  return { ...result, dataRoot, cacheRoot };
});

async function installDataset(datasetId, signal) {
  try {
    throwIfCanceled(signal);
    emitDownloadProgress(datasetId, { phase: "preparing", percent: null });
    const manifest = await readMergedManifest();
    const dataset = (manifest.datasets || []).find((item) => item.id === datasetId);
    if (!dataset) throw new Error(`Unknown dataset: ${datasetId}`);
    if (dataset.downloadable === false) throw new Error(`${dataset.label || dataset.id} is bundled with CGeV Desktop and does not need downloading.`);

    const dataRoot = defaultDataRoot();
    const cacheRoot = defaultCacheRoot();
    if (dataset.package) {
      const packageInfo = dataset.package;
      const packagePath = path.join(dataRoot, "packages", `${dataset.id}-${dataset.version || "latest"}.zip`);
      const initialRegistry = readInstallRegistry(dataRoot);
      const installed = initialRegistry.datasets && initialRegistry.datasets[dataset.id];
      if (
        installed &&
        installed.version === dataset.version &&
        installed.sha256 === packageInfo.sha256 &&
        fs.existsSync(packagePath)
      ) {
        emitDownloadProgress(datasetId, { path: packagePath, phase: "complete", skipped: true, verified: true });
        return { ok: true, dataRoot, installed: true };
      }
      if (!packageInfo.url) throw new Error(`Missing package URL for ${dataset.id}`);
      if (packageInfo.sha256 && await fileMatchesSha256(packagePath, packageInfo.sha256)) {
        emitDownloadProgress(datasetId, { path: packagePath, phase: "complete", skipped: true, verified: true });
      } else {
        const packageUrl = resolveCatalogResourceUrl(packageInfo.url, dataset, manifest);
        logStartupLine("download", `Downloading ${dataset.id} from ${packageUrl}`);
        await downloadFile(packageUrl, packagePath, packageInfo.sha256, (progress) => {
          emitDownloadProgress(datasetId, { path: packagePath, ...progress });
        }, { signal });
      }
      throwIfCanceled(signal);
      cancelableDatasetInstalls.delete(datasetId);
      emitDownloadProgress(datasetId, { path: packagePath, phase: "extracting", percent: 1 });
      const packageCacheStats = await extractDatasetPackage(packagePath, dataRoot, cacheRoot);
      emitDownloadProgress(datasetId, { path: packagePath, phase: "installing_cache", percent: 1 });
      const dataRootCacheStats = migrateDatasetCache(dataRoot, cacheRoot);
      const bundledCacheFiles = packageCacheStats.bundled + dataRootCacheStats.bundled;
      const migratedCacheFiles = packageCacheStats.migrated + dataRootCacheStats.migrated;
      const alreadyPresentCacheFiles = packageCacheStats.alreadyPresent + dataRootCacheStats.alreadyPresent;
      if (bundledCacheFiles > 0) {
        logStartupLine("download:cache", `${dataset.id}: cache bundled (${bundledCacheFiles} file(s))`);
      }
      if (migratedCacheFiles > 0) {
        logStartupLine("download:cache", `${dataset.id}: cache migrated (${migratedCacheFiles} file(s))`);
      }
      if (alreadyPresentCacheFiles > 0) {
        logStartupLine("download:cache", `${dataset.id}: cache already present (${alreadyPresentCacheFiles} file(s))`);
      }
      try {
        const warmResult = await warmDatasetAfterInstall(dataset, dataRoot, cacheRoot);
        const warmOutput = `${warmResult.stdout || ""}${warmResult.stderr || ""}`.trim();
        if (warmOutput) {
          logStartupLine("download:warm", `${dataset.id}: ${warmOutput}`);
        }
      } catch (error) {
        logStartupLine("download:warm", `${dataset.id}: ${error.message}`);
      }
      const registry = readInstallRegistry(dataRoot);
      registry.datasets = registry.datasets || {};
      registry.datasets[dataset.id] = {
        id: dataset.id,
        speciesId: dataset.speciesId || "",
        label: dataset.label || dataset.id,
        version: dataset.version || "",
        sha256: packageInfo.sha256 || "",
        packagePath,
        installedAt: new Date().toISOString()
      };
      writeInstallRegistry(registry, dataRoot);
      emitDownloadProgress(datasetId, { path: packagePath, phase: "complete", percent: 1 });
      return { ok: true, dataRoot, installed: true };
    }

    for (const file of dataset.files || []) {
      throwIfCanceled(signal);
      const targetPath = path.join(dataRoot, file.path);
      const existingFileIsValid = file.sha256 && await fileMatchesSha256(targetPath, file.sha256);
      throwIfCanceled(signal);
      if (existingFileIsValid) {
        emitDownloadProgress(datasetId, { path: file.path, phase: "complete", skipped: true, verified: true });
        continue;
      }
      if (!file.sha256 && fs.existsSync(targetPath)) {
        emitDownloadProgress(datasetId, { path: file.path, phase: "complete", skipped: true });
        continue;
      }
      if (!file.url) throw new Error(`Missing URL for ${file.path}`);
      const fileUrl = resolveCatalogResourceUrl(file.url, dataset, manifest);
      logStartupLine("download", `Downloading ${dataset.id} file ${file.path} from ${fileUrl}`);
      await downloadFile(fileUrl, targetPath, file.sha256, (progress) => {
        emitDownloadProgress(datasetId, { path: file.path, ...progress });
      }, { signal });
    }
    cancelableDatasetInstalls.delete(datasetId);
    emitDownloadProgress(datasetId, { phase: "complete", percent: 1 });
    return { ok: true, dataRoot };
  } catch (error) {
    if (error && error.code === "CGV_DOWNLOAD_CANCELED") {
      logStartupLine("download", `${datasetId}: canceled`);
      emitDownloadProgress(datasetId, { phase: "cancelled", message: "Download canceled." });
      throw error;
    }
    logStartupLine("download:error", `${datasetId}: ${error.stack || error.message}`);
    emitDownloadProgress(datasetId, { phase: "error", message: error.message });
    throw error;
  }
}

ipcMain.handle("cgv:download-dataset", async (_event, datasetId) => {
  const id = String(datasetId || "");
  if (!id) throw new Error("Dataset id is required.");
  if (datasetInstallControllers.has(id)) throw new Error(`A download is already active for ${id}.`);
  const controller = new AbortController();
  datasetInstallControllers.set(id, controller);
  cancelableDatasetInstalls.add(id);
  try {
    return await enqueueDatasetInstall(() => installDataset(id, controller.signal));
  } catch (error) {
    if (error && error.code === "CGV_DOWNLOAD_CANCELED") return { ok: false, canceled: true };
    throw error;
  } finally {
    if (datasetInstallControllers.get(id) === controller) datasetInstallControllers.delete(id);
    cancelableDatasetInstalls.delete(id);
  }
});

ipcMain.handle("cgv:cancel-dataset-download", (_event, datasetId) => {
  const id = String(datasetId || "");
  const controller = datasetInstallControllers.get(id);
  if (!controller || !cancelableDatasetInstalls.has(id)) return { ok: false, active: false };
  controller.abort();
  emitDownloadProgress(id, { phase: "cancelled", message: "Download canceled." });
  return { ok: true, active: true };
});

ipcMain.handle("cgv:install-update", () => {
  autoUpdater.quitAndInstall();
});

app.whenReady().then(createWindow);

app.on("window-all-closed", () => {
  appIsQuitting = true;
  stopShinyProcess();
  if (process.platform !== "darwin") app.quit();
});

app.on("before-quit", () => {
  appIsQuitting = true;
  stopShinyProcess();
});

app.on("activate", () => {
  if (mainWindow && !mainWindow.isDestroyed()) {
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.show();
    mainWindow.focus();
  } else if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});
