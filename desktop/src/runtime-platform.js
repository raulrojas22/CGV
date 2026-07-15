const path = require("path");

function bundledRuntimeResourceParts(isPackaged, platformKey) {
  return isPackaged
    ? ["runtime", platformKey]
    : ["resources", "r", platformKey];
}

function shouldInstallRuntimeLocally(platform = process.platform) {
  return platform !== "win32";
}

function executableNames(name, platform = process.platform) {
  if (platform !== "win32" || /\.exe$/i.test(name)) return [name];
  return [`${name}.exe`, name];
}

function runtimeExecutableCandidates(runtimeRoot, name, platform = process.platform) {
  if (!runtimeRoot) return [];
  const candidates = [];
  for (const executable of executableNames(name, platform)) {
    candidates.push(path.join(runtimeRoot, "bin", executable));
    if (platform === "win32") {
      candidates.push(path.join(runtimeRoot, "bin", "x64", executable));
    }
  }
  return candidates;
}

function isUsableExecutable(fsModule, filePath, platform = process.platform) {
  if (!filePath) return false;
  try {
    if (!fsModule.statSync(filePath).isFile()) return false;
    if (platform !== "win32") fsModule.accessSync(filePath, fsModule.constants.X_OK);
    return true;
  } catch (_) {
    return false;
  }
}

module.exports = {
  bundledRuntimeResourceParts,
  executableNames,
  isUsableExecutable,
  runtimeExecutableCandidates,
  shouldInstallRuntimeLocally
};
