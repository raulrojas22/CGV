const fs = require("fs");
const path = require("path");

const desktopRoot = path.resolve(__dirname, "..");
const distDir = path.join(desktopRoot, "dist");
const manifestPath = path.join(distDir, "latest-mac.yml");

if (!fs.existsSync(manifestPath)) {
  console.log("mac-update-manifest-skip latest-mac.yml not found");
  process.exit(0);
}

const files = fs.existsSync(distDir) ? fs.readdirSync(distDir) : [];

function findArtifact(ext, expectedSize) {
  const candidates = files.filter((file) => file.endsWith(ext) && fs.statSync(path.join(distDir, file)).size === expectedSize);
  if (candidates.length !== 1) {
    throw new Error(`Expected exactly one ${ext} artifact with size ${expectedSize}, found ${candidates.length}: ${candidates.join(", ")}`);
  }
  return candidates[0];
}

let manifest = fs.readFileSync(manifestPath, "utf8");
const sizeMatches = [...manifest.matchAll(/^\s+size:\s+(\d+)\s*$/gm)].map((match) => Number(match[1]));
if (sizeMatches.length < 2) {
  throw new Error(`Could not find zip and dmg file sizes in ${manifestPath}`);
}

const zipName = findArtifact(".zip", sizeMatches[0]);
const dmgName = findArtifact(".dmg", sizeMatches[1]);

manifest = manifest.replace(/^(\s+- url:\s+).+\.zip\s*$/m, `$1${zipName}`);
manifest = manifest.replace(/^(\s+- url:\s+).+\.dmg\s*$/m, `$1${dmgName}`);
manifest = manifest.replace(/^(path:\s+).+\.zip\s*$/m, `$1${zipName}`);

fs.writeFileSync(manifestPath, manifest);
console.log(`mac-update-manifest-ok zip="${zipName}" dmg="${dmgName}"`);
