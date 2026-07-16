const crypto = require("crypto");
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const desktopRoot = path.resolve(__dirname, "..");
const repoRoot = path.resolve(desktopRoot, "..");
const outputPath = path.join(desktopRoot, "resources", "app-source-manifest.json");
const rootSourceFiles = [
  "global.R",
  "ui.R",
  "server.R",
  "custom.scss",
  "gene_search_lib.R",
  "docker/run-app.sh"
];

function collectTreeFiles(root, relativeDirectory, { skipDirectories = new Set() } = {}) {
  const collected = [];
  const walk = (relativePath) => {
    const absolutePath = path.join(root, relativePath);
    for (const entry of fs.readdirSync(absolutePath, { withFileTypes: true })) {
      const childRelativePath = path.posix.join(relativePath.replaceAll(path.sep, "/"), entry.name);
      if (entry.isDirectory()) {
        if (!skipDirectories.has(childRelativePath)) walk(childRelativePath);
      } else if (entry.isFile()) {
        collected.push(childRelativePath);
      }
    }
  };
  walk(relativeDirectory);
  return collected;
}

function collectSourceFiles(root = repoRoot) {
  const scriptFiles = fs.readdirSync(path.join(root, "scripts"), { withFileTypes: true })
    .filter((entry) => entry.isFile() && entry.name.endsWith(".R"))
    .map((entry) => path.posix.join("scripts", entry.name));
  return [
    ...rootSourceFiles,
    ...collectTreeFiles(root, "R"),
    ...scriptFiles,
    ...collectTreeFiles(root, "www", { skipDirectories: new Set(["www/screencasts.orig"]) })
  ].sort();
}

function sha256File(filePath) {
  return crypto.createHash("sha256").update(fs.readFileSync(filePath)).digest("hex");
}

function resolveRevision(root, env = process.env) {
  const explicit = String(env.CGV_DESKTOP_SOURCE_REVISION || "").trim();
  if (explicit) return explicit;
  try {
    return execFileSync("git", ["rev-parse", "HEAD"], {
      cwd: root,
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"]
    }).trim();
  } catch (_) {
    return "unknown";
  }
}

function buildAppSourceManifest({ root = repoRoot, env = process.env } = {}) {
  const packageJson = JSON.parse(fs.readFileSync(path.join(root, "desktop", "package.json"), "utf8"));
  const files = {};
  const sourceFiles = collectSourceFiles(root);
  for (const relativePath of sourceFiles) {
    const absolutePath = path.join(root, relativePath);
    if (!fs.existsSync(absolutePath) || !fs.statSync(absolutePath).isFile()) {
      throw new Error(`Required CGV application source is missing: ${relativePath}`);
    }
    files[relativePath] = {
      sha256: sha256File(absolutePath),
      bytes: fs.statSync(absolutePath).size
    };
  }
  return {
    schemaVersion: 1,
    appVersion: packageJson.version,
    sourceRevision: resolveRevision(root, env),
    files
  };
}

function writeAppSourceManifest() {
  const manifest = buildAppSourceManifest();
  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, `${JSON.stringify(manifest, null, 2)}\n`);
  process.stdout.write(`app-source-manifest-ok version=${manifest.appVersion} revision=${manifest.sourceRevision}\n`);
  return manifest;
}

if (require.main === module) writeAppSourceManifest();

module.exports = {
  buildAppSourceManifest,
  collectSourceFiles,
  outputPath,
  resolveRevision,
  rootSourceFiles,
  sha256File,
  writeAppSourceManifest
};
