const fs = require("fs");
const path = require("path");

const desktopRoot = path.resolve(__dirname, "..");
const platform = process.argv[2] || `${process.platform}-${process.arch}`;
const runtimeRoot = process.env.CGV_RUNTIME_ROOT || path.join(desktopRoot, "resources", "r", platform);

function rm(relPath) {
  const target = path.join(runtimeRoot, relPath);
  fs.rmSync(target, { recursive: true, force: true });
}

function walk(dir, visit) {
  if (!fs.existsSync(dir)) return;
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      walk(full, visit);
      visit(full, true);
    } else {
      visit(full, false);
    }
  }
}

if (!fs.existsSync(runtimeRoot)) {
  throw new Error(`Runtime not found: ${runtimeRoot}`);
}

function ensureSelectizeOptgroupScss() {
  const rLibraryRoot = platform.startsWith("win32")
    ? path.join(runtimeRoot, "library")
    : path.join(runtimeRoot, "lib", "R", "library");
  const pluginPath = path.join(
    rLibraryRoot,
    "shiny",
    "www",
    "shared",
    "selectize",
    "scss",
    "plugins",
    "optgroup_columns.scss"
  );
  if (fs.existsSync(pluginPath)) return;
  fs.mkdirSync(path.dirname(pluginPath), { recursive: true });
  fs.writeFileSync(pluginPath, `.#{$selectize}-dropdown.plugin-optgroup_columns {
  .#{$selectize}-dropdown-content {
    display: flex;
  }

  .optgroup {
    border-right: 1px solid lighten($select-color-border, 13%);
    border-top: 0 none;
    flex-grow: 1;
    flex-basis: 0;
    min-width: 0;

    &:last-child {
      border-right: 0 none;
    }

    &:before {
      display: none;
    }
  }

  .optgroup-header {
    border-top: 0 none;
  }
}
`);
}

const removeTopLevel = [
  "include",
  "conda-meta",
  "share/doc",
  "share/man",
  "share/info",
  "share/examples",
  "lib/cmake",
  "lib/pkgconfig",
  "lib/clang",
  "lib/gcc",
  "libexec/gcc",
  "lib/tcl8.6",
  "lib/tk8.6",
  "share/gir-1.0",
  "share/locale",
  "share/terminfo",
  "share/zoneinfo",
  "share/bioconductor-data-packages"
];
removeTopLevel.forEach(rm);

const heavyBins = [
  "pandoc",
  "clang",
  "clang++",
  "gfortran",
  `${platform.startsWith("darwin") ? "arm64-apple-darwin20.0.0-" : ""}gfortran`,
  "pip",
  "pip3",
  "idle3",
  "idle3.14",
  "tclsh",
  "tclsh8.6",
  "wish",
  "wish8.6",
  "pandoc-lua",
  "pandoc-server",
  "make"
];
for (const name of heavyBins) rm(path.join("bin", name));

const unusedRPackages = [
  "BH",
  "rmarkdown",
  "knitr",
  "tinytex",
  "gfonts"
];
const rLibraryRoot = platform.startsWith("win32")
  ? path.join(runtimeRoot, "library")
  : path.join(runtimeRoot, "lib", "R", "library");
for (const pkg of unusedRPackages) {
  fs.rmSync(path.join(rLibraryRoot, pkg), { recursive: true, force: true });
}

if (platform.startsWith("win32")) {
  rm("doc");
  rm("unins000.dat");
  rm("unins000.exe");
}

walk(runtimeRoot, (full, isDir) => {
  const base = path.basename(full);
  if (isDir && ["__pycache__", "test", "tests", "doc", "docs", "example", "examples"].includes(base)) {
    fs.rmSync(full, { recursive: true, force: true });
    return;
  }
  if (!isDir && /\.(a|la|o|pyc)$/i.test(base)) {
    fs.rmSync(full, { force: true });
    return;
  }
  if (!isDir && /^(llvm-|clang-|llc|lli|opt|bugpoint|dsymutil)/.test(base)) {
    fs.rmSync(full, { force: true });
  }
  if (!isDir && /^libLLVM/.test(base)) {
    fs.rmSync(full, { force: true });
    return;
  }
  if (!isDir && /^libclang/.test(base)) {
    fs.rmSync(full, { force: true });
    return;
  }
  if (!isDir && /^libisl/.test(base)) {
    fs.rmSync(full, { force: true });
    return;
  }

  if (!isDir && /^libtk/.test(base)) {
    fs.rmSync(full, { force: true });
    return;
  }
  if (!isDir && /^libtcl/.test(base)) {
    fs.rmSync(full, { force: true });
    return;
  }
});

ensureSelectizeOptgroupScss();

console.log(`Pruned runtime: ${runtimeRoot}`);
