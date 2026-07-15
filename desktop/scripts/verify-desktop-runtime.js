const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");
const {
  executableNames,
  isUsableExecutable,
  runtimeExecutableCandidates
} = require("../src/runtime-platform");

const desktopRoot = path.resolve(__dirname, "..");
const repoRoot = path.resolve(desktopRoot, "..");
const allowSystemRuntime = process.argv.includes("--allow-system-runtime");
const platformKey = `${process.platform}-${process.arch}`;

const requiredPackages = [
  "shiny",
  "bslib",
  "shinyjs",
  "shinycssloaders",
  "shinyWidgets",
  "dplyr",
  "tidyr",
  "purrr",
  "stringr",
  "ggiraph",
  "ggplot2",
  "ggrepel",
  "patchwork",
  "scales",
  "vroom",
  "future",
  "promises",
  "httr2",
  "furrr",
  "rbioapi",
  "visNetwork",
  "jsonlite",
  "later",
  "htmltools",
  "DT",
  "sass",
  "data.table",
  "processx",
  "BiocManager",
  "DBI",
  "RSQLite",
  "Biostrings",
  "Rsamtools",
  "GenomicRanges",
  "IRanges",
  "GenomeInfoDb",
  "rtracklayer",
  "biomaRt"
];

const optionalPackages = [
  "pwalign"
];

function isExecutable(filePath) {
  return isUsableExecutable(fs, filePath);
}

function firstExecutable(candidates) {
  return candidates.filter(Boolean).find(isExecutable) || "";
}

function bundledRuntimeRoot() {
  const candidate = path.join(desktopRoot, "resources", "r", platformKey);
  return fs.existsSync(candidate) ? candidate : "";
}

function allowPrunedFilesInCondaUnpack(unpackPath) {
  const source = fs.readFileSync(unpackPath, "utf8");
  const target = source.replace(
    /^(\s*)update_prefix\(new_path, new_prefix, placeholder, mode=mode\)$/gm,
    "$1if os.path.exists(new_path):\n$1    update_prefix(new_path, new_prefix, placeholder, mode=mode)"
  );
  if (target === source) {
    throw new Error(`Unable to prepare conda-unpack for: ${unpackPath}`);
  }
  fs.writeFileSync(unpackPath, target);
}

function prepareRelocatedRuntime(sourceRoot) {
  if (!sourceRoot) return { root: "", cleanup: () => {} };
  const prefix = process.platform === "win32" ? "CGV Runtime á verify-" : "cgv-runtime-verify-";
  const tempRoot = fs.mkdtempSync(path.join(os.tmpdir(), prefix));
  const runtimeRoot = path.join(tempRoot, "runtime");
  fs.cpSync(sourceRoot, runtimeRoot, { recursive: true, errorOnExist: false });

  if (process.platform === "win32") {
    return {
      root: runtimeRoot,
      cleanup: () => fs.rmSync(tempRoot, { recursive: true, force: true })
    };
  }

  const python = path.join(runtimeRoot, "bin", "python");
  const unpack = path.join(runtimeRoot, "bin", "conda-unpack");
  if (!isExecutable(python) || !fs.existsSync(unpack)) {
    fs.rmSync(tempRoot, { recursive: true, force: true });
    throw new Error("Bundled runtime must retain python and conda-unpack for first-run relocation.");
  }
  allowPrunedFilesInCondaUnpack(unpack);
  const result = spawnSync(python, [unpack], { encoding: "utf8" });
  if (result.status !== 0) {
    fs.rmSync(tempRoot, { recursive: true, force: true });
    throw new Error(`conda-unpack failed\n${result.stdout || ""}${result.stderr || ""}`);
  }
  return {
    root: runtimeRoot,
    cleanup: () => fs.rmSync(tempRoot, { recursive: true, force: true })
  };
}

const preparedRuntime = prepareRelocatedRuntime(bundledRuntimeRoot());
process.on("exit", preparedRuntime.cleanup);

function runtimeRscript() {
  const candidates = [
    process.env.CGV_RSCRIPT,
    ...runtimeExecutableCandidates(preparedRuntime.root, "Rscript"),
    ...runtimeExecutableCandidates(path.join(desktopRoot, "resources", "r", platformKey), "Rscript"),
    ...runtimeExecutableCandidates(path.join(desktopRoot, "resources", "r"), "Rscript")
  ];
  if (allowSystemRuntime) {
    candidates.push("/opt/homebrew/bin/Rscript", "/usr/local/bin/Rscript", "/usr/bin/Rscript", ...executableNames("Rscript"));
  }
  return firstExecutable(candidates);
}

function runtimeBinary(name, envName) {
  const candidates = [
    process.env[envName],
    ...runtimeExecutableCandidates(preparedRuntime.root, name),
    ...runtimeExecutableCandidates(path.join(desktopRoot, "resources", "r", platformKey), name),
    ...runtimeExecutableCandidates(path.join(desktopRoot, "resources", "r"), name),
    ...executableNames(name).map((candidate) => path.join(desktopRoot, "resources", "bin", platformKey, candidate)),
    ...executableNames(name).map((candidate) => path.join(desktopRoot, "resources", "bin", candidate))
  ];
  if (allowSystemRuntime) {
    candidates.push(`/opt/homebrew/bin/${name}`, `/usr/local/bin/${name}`, `/usr/bin/${name}`, ...executableNames(name));
  }
  return firstExecutable(candidates);
}

function run(command, args, options = {}) {
  const { acceptedStatuses = [0], ...spawnOptions } = options;
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    encoding: "utf8",
    windowsHide: true,
    ...spawnOptions
  });
  if (!acceptedStatuses.includes(result.status)) {
    const commandLine = [command, ...args].map((value) => JSON.stringify(value)).join(" ");
    const diagnostics = [
      `status=${result.status === null ? "null" : result.status}`,
      `signal=${result.signal || "none"}`
    ];
    if (result.error) diagnostics.push(`process_error=${result.error.stack || result.error.message || result.error}`);
    if (result.stdout) diagnostics.push(`stdout:\n${result.stdout}`);
    if (result.stderr) diagnostics.push(`stderr:\n${result.stderr}`);
    throw new Error(`${commandLine} failed\n${diagnostics.join("\n")}`);
  }
  return `${result.stdout || ""}${result.stderr || ""}`.trim();
}

const rscript = runtimeRscript();
if (!rscript) {
  throw new Error(`Rscript not found for ${platformKey}. Build the platform runtime first.`);
}

const binaries = {
  lastz: runtimeBinary("lastz", "APP_LASTZ_BIN"),
  samtools: runtimeBinary("samtools", "APP_SAMTOOLS_BIN"),
  tabix: runtimeBinary("tabix", "APP_TABIX_BIN")
};

for (const [name, binary] of Object.entries(binaries)) {
  if (process.platform === "win32" && ["samtools", "tabix"].includes(name)) {
    console.log(`${name}: optional on Windows (Rsamtools fallback${binary ? `, found ${binary}` : ""})`);
    continue;
  }
  if (!binary) {
    throw new Error(`${name} not found for ${platformKey}. Add it to desktop/resources/bin/${platformKey}/ or the bundled runtime.`);
  }
}

console.log(run(rscript, ["--version"]));
for (const [name, binary] of Object.entries(binaries)) {
  console.log(`${name}: ${binary}`);
}

console.log(run(binaries.lastz, ["--version"], { acceptedStatuses: [0, 1] }));
const lastzTestRoot = fs.mkdtempSync(path.join(os.tmpdir(), "CGV LASTZ á test-"));
try {
  const targetFasta = path.join(lastzTestRoot, "known target.fa");
  const queryFasta = path.join(lastzTestRoot, "known query.fa");
  const sequence = "ACGT".repeat(100);
  fs.writeFileSync(targetFasta, `>known_target\n${sequence}\n`);
  fs.writeFileSync(queryFasta, `>known_query\n${sequence}\n`);
  const alignment = run(binaries.lastz, [
    targetFasta,
    queryFasta,
    "--format=general:name1,name2,identity"
  ], { cwd: lastzTestRoot });
  if (!alignment.includes("100.0%")) {
    throw new Error(`LASTZ known alignment did not contain a 100% identity match:\n${alignment}`);
  }
  console.log("LASTZ known alignment ok");
} finally {
  fs.rmSync(lastzTestRoot, { recursive: true, force: true });
}

const packageCheckRoot = fs.mkdtempSync(path.join(os.tmpdir(), "CGV R package á verify-"));
const packageCheckScript = path.join(packageCheckRoot, "verify package.R");
fs.copyFileSync(path.join(__dirname, "verify-r-package.R"), packageCheckScript);

try {
  for (const packageName of requiredPackages) {
    console.log(run(rscript, [packageCheckScript, packageName, "required"]));
  }
  console.log(`Required R packages ok: ${requiredPackages.length}`);

  for (const packageName of optionalPackages) {
    const optionalResult = run(
      rscript,
      [packageCheckScript, packageName, "optional"],
      { acceptedStatuses: [0, 10] }
    );
    if (optionalResult) console.log(optionalResult);
  }
} finally {
  fs.rmSync(packageCheckRoot, { recursive: true, force: true });
}

const manifestPath = path.join(desktopRoot, "data-manifest.json");
if (!fs.existsSync(manifestPath)) {
  throw new Error(`Desktop data manifest not found: ${manifestPath}`);
}
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const datasetCount = Array.isArray(manifest.datasets) ? manifest.datasets.length : 0;
console.log(`Desktop data manifest ok: ${manifestPath} (${datasetCount} bundled/downloadable entries)`);
