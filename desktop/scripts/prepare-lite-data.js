const fs = require("fs");
const os = require("os");
const path = require("path");

const desktopRoot = path.resolve(__dirname, "..");
const demoRoot = path.join(desktopRoot, "resources", "demo-data");
const bundledRoot = path.join(desktopRoot, "resources", "bundled-data");

fs.rmSync(demoRoot, { recursive: true, force: true });
fs.mkdirSync(demoRoot, { recursive: true });

function removeDesktopProfileDatasets() {
  const supportRoot = path.join(os.homedir(), "Library", "Application Support");
  const profileRoots = [
    path.join(supportRoot, "cgv-desktop"),
    path.join(supportRoot, "CGV Desktop")
  ];
  const rels = [
    "data",
    "cache"
  ];
  for (const profileRoot of profileRoots) {
    for (const rel of rels) {
      const target = path.join(profileRoot, rel);
      try {
        fs.rmSync(target, { recursive: true, force: true });
      } catch (error) {
        throw new Error(`Could not clear ${target}: ${error.message}. Quit CGV Desktop and retry the build.`);
      }
    }
  }
  console.log("Cleared desktop organism test profile data/cache for a clean build run.");
}

function listFiles(root, limit = 8) {
  if (!fs.existsSync(root)) return [];
  const out = [];
  const walk = (dir) => {
    if (out.length >= limit) return;
    for (const name of fs.readdirSync(dir)) {
      if (name === ".DS_Store" || name === ".gitkeep") continue;
      const fullPath = path.join(dir, name);
      const stat = fs.statSync(fullPath);
      if (stat.isDirectory()) {
        walk(fullPath);
      } else {
        out.push(path.relative(root, fullPath));
      }
      if (out.length >= limit) break;
    }
  };
  walk(root);
  return out;
}

const bundledFiles = listFiles(bundledRoot);
if (bundledFiles.length > 0) {
  console.error("Lite desktop build blocked: desktop/resources/bundled-data contains organism files.");
  console.error("Move/remove bundled organisms before building. Examples:");
  for (const file of bundledFiles) console.error(`  - ${file}`);
  process.exit(1);
}

if (process.env.CGV_DESKTOP_CLEAN_PROFILE === "1") {
  removeDesktopProfileDatasets();
} else {
  console.log("Skipped desktop profile data/cache cleanup. Set CGV_DESKTOP_CLEAN_PROFILE=1 for a destructive clean-profile build.");
}
console.log(`Lite desktop build uses no bundled organisms. Cleared ${demoRoot} and verified ${bundledRoot}`);
