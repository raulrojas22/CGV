const fs = require("fs");
const path = require("path");
const { downloadFile } = require("../src/download-file");
const { extractZipArchive, validateZipArchive } = require("../src/secure-zip");

const desktopRoot = path.resolve(__dirname, "..");
const repoRoot = path.resolve(desktopRoot, "..");
const lockPath = path.join(desktopRoot, "guide-media-lock.json");
const lock = JSON.parse(fs.readFileSync(lockPath, "utf8"));
const destination = path.join(repoRoot, "www", "screencasts");
const archivePath = path.join(desktopRoot, "resources", "cgv-guide-media-v1.zip");
const stagingPath = path.join(desktopRoot, "resources", "guide-media-staging");

function expectedFiles() {
  const files = Array.isArray(lock.expectedFiles) ? lock.expectedFiles.map(String).sort() : [];
  if (lock.version !== 1 || !/^https:\/\//.test(lock.url || "") || !/^[a-f0-9]{64}$/.test(lock.sha256 || "") || files.length < 30) {
    throw new Error("CGV Guide media lock is incomplete or invalid.");
  }
  if (files.some((name) => name.includes("/") || !name.endsWith(".mp4"))) {
    throw new Error("CGV Guide media lock contains an invalid filename.");
  }
  return files;
}

function mediaIsComplete(files) {
  return files.every((name) => {
    const target = path.join(destination, name);
    return fs.existsSync(target) && fs.statSync(target).isFile() && fs.statSync(target).size > 1024;
  });
}

async function main() {
  const files = expectedFiles();
  if (mediaIsComplete(files)) {
    process.stdout.write(`guide-media-ok files=${files.length} source=existing\n`);
    return;
  }

  fs.mkdirSync(path.dirname(archivePath), { recursive: true });
  await downloadFile(lock.url, archivePath, lock.sha256, (progress) => {
    if (progress.phase === "verifying") process.stdout.write("guide-media-verifying\n");
  });

  const archiveEntries = (await validateZipArchive(archivePath))
    .filter((name) => !name.endsWith("/"))
    .sort();
  if (JSON.stringify(archiveEntries) !== JSON.stringify(files)) {
    throw new Error("CGV Guide media archive contents do not match the locked file list.");
  }

  fs.rmSync(stagingPath, { recursive: true, force: true });
  fs.mkdirSync(stagingPath, { recursive: true });
  await extractZipArchive(archivePath, stagingPath);
  for (const name of files) {
    const target = path.join(stagingPath, name);
    if (!fs.existsSync(target) || fs.statSync(target).size <= 1024) {
      throw new Error(`CGV Guide media file is missing or empty: ${name}`);
    }
  }

  fs.rmSync(destination, { recursive: true, force: true });
  fs.renameSync(stagingPath, destination);
  process.stdout.write(`guide-media-ok files=${files.length} source=locked-release\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.stack || error.message}\n`);
  process.exitCode = 1;
});
