const { app, BrowserWindow, ipcMain, shell } = require("electron");
const { autoUpdater } = require("electron-updater");
const fs = require("fs");
const http = require("http");
const https = require("https");
const crypto = require("crypto");
const os = require("os");
const path = require("path");
const { spawn } = require("child_process");
const { execFile } = require("child_process");

let mainWindow = null;
let shinyProcess = null;
let shinyUrl = null;
let startupLogPath = null;
let appIsQuitting = false;

function isExecutable(filePath) {
  try {
    fs.accessSync(filePath, fs.constants.X_OK);
    return true;
  } catch (_) {
    return false;
  }
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

function findRscript() {
  const bundled = [
    process.env.CGV_RSCRIPT,
    resourcePath("runtime", platformKey(), "bin", "Rscript"),
    resourcePath("runtime", "bin", "Rscript"),
    resourcePath("resources", "r", platformKey(), "bin", "Rscript"),
    resourcePath("resources", "r", "bin", "Rscript"),
    resourcePath("r", platformKey(), "bin", "Rscript"),
    resourcePath("r", "bin", "Rscript")
  ].filter(Boolean);
  const system = [
    "/usr/local/bin/Rscript",
    "/opt/homebrew/bin/Rscript",
    "/usr/bin/Rscript"
  ].filter(Boolean);
  const candidates = app.isPackaged ? bundled : bundled.concat(system);

  for (const candidate of candidates) {
    if (isExecutable(candidate)) return candidate;
  }

  return "Rscript";
}

function findBundledBinary(name, envName) {
  const bundled = [
    process.env[envName],
    resourcePath("bin", platformKey(), name),
    resourcePath("bin", name),
    resourcePath("runtime", platformKey(), "bin", name),
    resourcePath("runtime", "bin", name),
    resourcePath("resources", "bin", platformKey(), name),
    resourcePath("resources", "bin", name),
    resourcePath("resources", "r", platformKey(), "bin", name),
    resourcePath("resources", "r", "bin", name),
    resourcePath("r", platformKey(), "bin", name),
    resourcePath("r", "bin", name)
  ].filter(Boolean);
  const system = [
    `/opt/homebrew/bin/${name}`,
    `/usr/local/bin/${name}`,
    `/usr/bin/${name}`
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

function defaultDataRoot() {
  const explicit = process.env.CGV_DESKTOP_DATA_ROOT || process.env.CGV_DATA_ROOT;
  if (explicit) return explicit;

  const localRoot = appRoot();
  if (!app.isPackaged && fs.existsSync(path.join(localRoot, "annotations", "registry.tsv"))) {
    return localRoot;
  }
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

function seedBundledCache(cacheRoot) {
  const bundledCacheRoot = resourcePath("app", "cache");
  copyDirIfMissingOrEmpty(path.join(bundledCacheRoot, "annotation_index"), path.join(cacheRoot, "annotation_index"));
}

function seedBundledData(dataRoot) {
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
  if (process.env.CGV_ENABLE_AUTO_UPDATE !== "1") {
    logStartupLine("update", "Auto updates disabled. Set CGV_ENABLE_AUTO_UPDATE=1 to enable GitHub release checks.");
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
      "Build the bundled runtime with npm run runtime:mac or npm run runtime:linux, or set CGV_RSCRIPT to a valid executable."
    );
  }
  for (const [name, value] of Object.entries(binaries)) {
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
  const root = appRoot();
  const dataRoot = defaultDataRoot();
  const cacheRoot = defaultCacheRoot();
  fs.mkdirSync(dataRoot, { recursive: true });
  fs.mkdirSync(cacheRoot, { recursive: true });
  ensureDataRootStructure(dataRoot);
  seedBundledData(dataRoot);
  seedDemoData(dataRoot);
  seedBundledCache(cacheRoot);

  const port = Number(process.env.APP_PORT || await getFreePort());
  const rscript = findRscript();
  const lastz = findBundledBinary("lastz", "APP_LASTZ_BIN");
  const samtools = findBundledBinary("samtools", "APP_SAMTOOLS_BIN");
  const tabix = findBundledBinary("tabix", "APP_TABIX_BIN");
  validateRuntime(rscript, { lastz, samtools, tabix });

  const binDir = runtimeBinDir(rscript);
  const pathEntries = [
    binDir,
    path.dirname(lastz),
    path.dirname(samtools),
    path.dirname(tabix),
    process.env.PATH
  ].filter(Boolean);

  const env = {
    ...process.env,
    APP_PORT: String(port),
    APP_HOST: "127.0.0.1",
    APP_FUTURE_MODE: process.env.APP_FUTURE_MODE || "multisession",
    APP_FUTURE_WORKERS: process.env.APP_FUTURE_WORKERS || String(Math.max(1, Math.min(2, os.cpus().length - 1))),
    APP_PREWARM_ON_START: "0",
    APP_SESSION_METRICS: "1",
    APP_PERF_TIMING: process.env.APP_PERF_TIMING || "1",
    CGV_DATA_ROOT: dataRoot,
    CGV_CACHE_DIR: cacheRoot,
    APP_ALIAS_DISK_CACHE_DIR: path.join(cacheRoot, "external_alias"),
    CGV_NCBI_DOWNLOADS_DIR: path.join(dataRoot, "ncbi_downloads"),
    PATH: pathEntries.join(path.delimiter)
  };
  if (lastz) env.APP_LASTZ_BIN = lastz;
  if (samtools) env.APP_SAMTOOLS_BIN = samtools;
  if (tabix) env.APP_TABIX_BIN = tabix;

  shinyUrl = `http://127.0.0.1:${port}`;
  logStartupLine("electron", `Starting CGeV on ${shinyUrl}`);
  logStartupLine("electron", `Rscript: ${rscript}`);
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
    stdio: ["ignore", "pipe", "pipe"]
  });

  shinyProcess.stdout.on("data", (chunk) => {
    const message = chunk.toString();
    logStartupLine("R stdout", message);
    sendStatus({ phase: "log", message });
  });
  shinyProcess.stderr.on("data", (chunk) => {
    const message = chunk.toString();
    logStartupLine("R stderr", message);
    sendStatus({ phase: "log", message });
  });
  shinyProcess.on("exit", (code, signal) => {
    const message = `R/Shiny stopped (${code ?? signal})`;
    logStartupLine("electron", message);
    sendStatus({ phase: "stopped", message });
    shinyProcess = null;
    if (!appIsQuitting && mainWindow && !mainWindow.isDestroyed() && signal !== "SIGTERM") {
      mainWindow.loadFile(path.join(__dirname, "launcher.html"));
    }
  });
  shinyProcess.on("error", (error) => {
    const message = `Unable to start R/Shiny: ${error.message}`;
    logStartupLine("electron", message);
    sendStatus({ phase: "error", message });
  });

  await waitForHttp(shinyUrl);
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

function httpGetJson(url) {
  const client = url.startsWith("https:") ? https : http;
  return new Promise((resolve, reject) => {
    const request = client.get(url, (response) => {
      if ([301, 302, 303, 307, 308].includes(response.statusCode) && response.headers.location) {
        httpGetJson(response.headers.location).then(resolve, reject);
        return;
      }
      if (response.statusCode !== 200) {
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
          resolve(JSON.parse(body));
        } catch (error) {
          reject(new Error(`Catalog JSON could not be parsed: ${error.message}`));
        }
      });
    });
    request.on("error", reject);
    request.setTimeout(15000, () => {
      request.destroy(new Error(`Catalog request timed out: ${url}`));
    });
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

function mergeDatasetCatalogs(baseManifest, remoteManifest) {
  const byId = new Map();
  for (const dataset of baseManifest.datasets || []) byId.set(dataset.id, dataset);
  for (const dataset of remoteManifest.datasets || []) {
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
  const catalogUrl = process.env.CGV_DESKTOP_CATALOG_URL || baseManifest.catalogUrl || "";
  if (!catalogUrl) return baseManifest;
  try {
    const remoteManifest = await httpGetJson(catalogUrl);
    return mergeDatasetCatalogs(baseManifest, { ...remoteManifest, source: catalogUrl });
  } catch (error) {
    return {
      ...baseManifest,
      catalogError: error.message
    };
  }
}

function sha256File(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256");
    const stream = fs.createReadStream(filePath);
    stream.on("data", (chunk) => hash.update(chunk));
    stream.on("error", reject);
    stream.on("end", () => resolve(hash.digest("hex")));
  });
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
    datasets: (manifest.datasets || []).map((dataset) => ({
      ...dataset,
      local: datasetInstallState(dataset, dataRoot)
    }))
  };
}

function runFile(command, args) {
  return new Promise((resolve, reject) => {
    execFile(command, args, { encoding: "utf8", maxBuffer: 1024 * 1024 * 20 }, (error, stdout, stderr) => {
      if (error) {
        reject(new Error(`${command} ${args.join(" ")} failed: ${stderr || stdout || error.message}`));
        return;
      }
      resolve({ stdout, stderr });
    });
  });
}

async function validateZipEntries(zipPath) {
  const { stdout } = await runFile("unzip", ["-Z1", zipPath]);
  const entries = stdout.split(/\r?\n/).filter(Boolean);
  for (const entry of entries) {
    if (path.isAbsolute(entry) || entry.includes("..") || entry.includes("\\")) {
      throw new Error(`Unsafe zip entry blocked: ${entry}`);
    }
  }
  return entries;
}

async function extractDatasetPackage(zipPath, dataRoot) {
  await validateZipEntries(zipPath);
  await runFile("unzip", ["-n", zipPath, "-d", dataRoot]);
}

function downloadFile(url, targetPath, expectedSha256, progressCallback) {
  if (isFileUrl(url) || path.isAbsolute(url)) {
    const sourcePath = isFileUrl(url) ? new URL(url) : url;
    fs.mkdirSync(path.dirname(targetPath), { recursive: true });
    const partPath = `${targetPath}.part`;
    if (fs.existsSync(partPath)) fs.rmSync(partPath, { force: true });
    fs.copyFileSync(sourcePath, partPath);
    const total = fs.statSync(partPath).size;
    progressCallback({ done: total, total, percent: 1 });
    return (async () => {
      if (expectedSha256) {
        const actualSha256 = await sha256File(partPath);
        if (actualSha256.toLowerCase() !== expectedSha256.toLowerCase()) {
          fs.rmSync(partPath, { force: true });
          throw new Error(`Checksum mismatch for ${path.basename(targetPath)}. Expected ${expectedSha256}, got ${actualSha256}.`);
        }
      }
      fs.renameSync(partPath, targetPath);
      return targetPath;
    })();
  }
  const client = url.startsWith("https:") ? https : http;
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  const partPath = `${targetPath}.part`;
  if (fs.existsSync(partPath)) fs.rmSync(partPath, { force: true });
  return new Promise((resolve, reject) => {
    const request = client.get(url, (response) => {
      if ([301, 302, 303, 307, 308].includes(response.statusCode) && response.headers.location) {
        downloadFile(response.headers.location, targetPath, expectedSha256, progressCallback).then(resolve, reject);
        return;
      }
      if (response.statusCode !== 200) {
        reject(new Error(`Download failed with HTTP ${response.statusCode}: ${url}`));
        return;
      }
      const total = Number(response.headers["content-length"] || 0);
      let done = 0;
      const stream = fs.createWriteStream(partPath);
      response.on("data", (chunk) => {
        done += chunk.length;
        progressCallback({ done, total, percent: total > 0 ? done / total : null });
      });
      response.pipe(stream);
      stream.on("finish", () => {
        stream.close(async () => {
          try {
            if (expectedSha256) {
              const actualSha256 = await sha256File(partPath);
              if (actualSha256.toLowerCase() !== expectedSha256.toLowerCase()) {
                fs.rmSync(partPath, { force: true });
                reject(new Error(`Checksum mismatch for ${path.basename(targetPath)}. Expected ${expectedSha256}, got ${actualSha256}.`));
                return;
              }
            }
            fs.renameSync(partPath, targetPath);
            resolve(targetPath);
          } catch (error) {
            reject(error);
          }
        });
      });
      stream.on("error", reject);
    });
    request.on("error", reject);
  });
}

async function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1320,
    height: 900,
    minWidth: 1100,
    minHeight: 720,
    title: "CGeV Desktop",
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

  await mainWindow.loadFile(path.join(__dirname, "launcher.html"));
  setupAutoUpdater();
  try {
    const url = await startShiny();
    await mainWindow.loadURL(url);
  } catch (error) {
    logStartupLine("electron:error", error.message);
    sendStatus({ phase: "error", message: error.message });
  }
}

ipcMain.handle("cgv:get-runtime", () => ({
  appRoot: appRoot(),
  dataRoot: defaultDataRoot(),
  cacheRoot: defaultCacheRoot(),
  startupLogPath: getStartupLogPath(),
  shinyUrl
}));

ipcMain.handle("cgv:show-startup-log", async () => {
  const logPath = getStartupLogPath();
  fs.mkdirSync(path.dirname(logPath), { recursive: true });
  if (!fs.existsSync(logPath)) fs.writeFileSync(logPath, "");
  return shell.showItemInFolder(logPath);
});

ipcMain.handle("cgv:list-datasets", () => readManifestWithState());

ipcMain.handle("cgv:download-dataset", async (_event, datasetId) => {
  const manifest = await readMergedManifest();
  const dataset = (manifest.datasets || []).find((item) => item.id === datasetId);
  if (!dataset) throw new Error(`Unknown dataset: ${datasetId}`);
  if (dataset.downloadable === false) throw new Error(`${dataset.label || dataset.id} is bundled with CGeV Desktop and does not need downloading.`);

  const dataRoot = defaultDataRoot();
  const registry = readInstallRegistry(dataRoot);
  if (dataset.package) {
    const packageInfo = dataset.package;
    const packagePath = path.join(dataRoot, "packages", `${dataset.id}-${dataset.version || "latest"}.zip`);
    const installed = registry.datasets && registry.datasets[dataset.id];
    if (
      installed &&
      installed.version === dataset.version &&
      installed.sha256 === packageInfo.sha256 &&
      fs.existsSync(packagePath)
    ) {
      mainWindow.webContents.send("cgv:download-progress", { datasetId, path: packagePath, skipped: true, verified: true });
      return { ok: true, dataRoot, installed: true };
    }
    if (!packageInfo.url) throw new Error(`Missing package URL for ${dataset.id}`);
    if (packageInfo.sha256 && await fileMatchesSha256(packagePath, packageInfo.sha256)) {
      mainWindow.webContents.send("cgv:download-progress", { datasetId, path: packagePath, skipped: true, verified: true });
    } else {
      const packageUrl = resolveCatalogResourceUrl(packageInfo.url, dataset, manifest);
      await downloadFile(packageUrl, packagePath, packageInfo.sha256, (progress) => {
        mainWindow.webContents.send("cgv:download-progress", { datasetId, path: packagePath, ...progress });
      });
    }
    mainWindow.webContents.send("cgv:download-progress", { datasetId, path: packagePath, phase: "extracting" });
    await extractDatasetPackage(packagePath, dataRoot);
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
    return { ok: true, dataRoot, installed: true };
  }

  for (const file of dataset.files || []) {
    const targetPath = path.join(dataRoot, file.path);
    if (file.sha256 && await fileMatchesSha256(targetPath, file.sha256)) {
      mainWindow.webContents.send("cgv:download-progress", { datasetId, path: file.path, skipped: true, verified: true });
      continue;
    }
    if (!file.sha256 && fs.existsSync(targetPath)) {
      mainWindow.webContents.send("cgv:download-progress", { datasetId, path: file.path, skipped: true });
      continue;
    }
    if (!file.url) throw new Error(`Missing URL for ${file.path}`);
    const fileUrl = resolveCatalogResourceUrl(file.url, dataset, manifest);
    await downloadFile(fileUrl, targetPath, file.sha256, (progress) => {
      mainWindow.webContents.send("cgv:download-progress", { datasetId, path: file.path, ...progress });
    });
  }
  return { ok: true, dataRoot };
});

ipcMain.handle("cgv:install-update", () => {
  autoUpdater.quitAndInstall();
});

app.whenReady().then(createWindow);

app.on("window-all-closed", () => {
  appIsQuitting = true;
  if (shinyProcess) shinyProcess.kill();
  if (process.platform !== "darwin") app.quit();
});

app.on("before-quit", () => {
  appIsQuitting = true;
  if (shinyProcess) shinyProcess.kill();
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
