const fs = require("fs");
const path = require("path");

const desktopRoot = path.resolve(__dirname, "..");

function argValue(name, fallback = "") {
  const prefix = `--${name}=`;
  const hit = process.argv.find((arg) => arg.startsWith(prefix));
  return hit ? hit.slice(prefix.length) : fallback;
}

function withTrailingSlash(value) {
  return value && !value.endsWith("/") ? `${value}/` : value;
}

const packageDir = path.resolve(argValue("dir", path.join(desktopRoot, "dataset-packages")));
const outPath = path.resolve(argValue("out", path.join(packageDir, "catalog.json")));
const baseUrl = withTrailingSlash(argValue("base-url", ""));
const source = argValue("source", baseUrl || "local");

if (!fs.existsSync(packageDir)) {
  throw new Error(`Package directory does not exist: ${packageDir}`);
}

const manifestFiles = fs.readdirSync(packageDir)
  .filter((name) => name.endsWith(".manifest.json"))
  .sort();

const datasets = manifestFiles.map((name) => {
  const entry = JSON.parse(fs.readFileSync(path.join(packageDir, name), "utf8"));
  if (baseUrl && entry.package && entry.package.fileName) {
    entry.package.url = new URL(entry.package.fileName, baseUrl).toString();
  }
  return entry;
});

const catalog = {
  version: 1,
  generatedAt: new Date().toISOString(),
  source,
  datasets
};

fs.mkdirSync(path.dirname(outPath), { recursive: true });
fs.writeFileSync(outPath, `${JSON.stringify(catalog, null, 2)}\n`);

console.log(`Wrote ${datasets.length} dataset entries to ${outPath}`);
