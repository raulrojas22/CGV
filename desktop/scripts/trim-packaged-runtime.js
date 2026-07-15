const fs = require("fs");
const path = require("path");
const { Arch } = require("builder-util");

exports.default = async function trimPackagedRuntime(context) {
  const runtimeRoot = path.join(
    context.packager.getResourcesDir(context.appOutDir),
    "runtime"
  );
  const arch = Arch[context.arch];
  if (!arch) {
    throw new Error(`Unknown Electron architecture: ${context.arch}`);
  }

  const expectedRuntime = `${context.electronPlatformName}-${arch}`;
  if (!fs.existsSync(runtimeRoot)) {
    throw new Error(`Missing packaged runtime directory: ${runtimeRoot}`);
  }
  for (const entry of fs.readdirSync(runtimeRoot)) {
    if (entry === expectedRuntime) continue;
    fs.rmSync(path.join(runtimeRoot, entry), { recursive: true, force: true });
  }

  const expectedRoot = path.join(runtimeRoot, expectedRuntime);
  if (!fs.existsSync(expectedRoot)) {
    throw new Error(`Missing bundled runtime for ${expectedRuntime}: ${expectedRoot}`);
  }
};
