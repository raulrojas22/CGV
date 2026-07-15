const fs = require("fs");
const path = require("path");
const yauzl = require("yauzl");

function validateZipEntryName(entryName) {
  const name = String(entryName || "");
  if (!name || name.includes("\0")) throw new Error("ZIP entry has an invalid name.");
  if (name.includes("\\")) throw new Error(`Unsafe ZIP entry blocked: ${name}`);
  if (name.includes(":") || name.startsWith("/") || /^[A-Za-z]:/.test(name) || name.startsWith("//")) {
    throw new Error(`Unsafe ZIP entry blocked: ${name}`);
  }
  const segments = name.split("/");
  if (segments.includes("..")) throw new Error(`Unsafe ZIP entry blocked: ${name}`);
  for (const segment of segments) {
    if (segment && /[ .]$/.test(segment)) throw new Error(`Unsafe ZIP entry blocked: ${name}`);
    const windowsBaseName = segment.split(".", 1)[0].replace(/[ .]+$/g, "").toUpperCase();
    if (/^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$/.test(windowsBaseName)) {
      throw new Error(`Unsafe ZIP entry blocked: ${name}`);
    }
  }
  const normalized = path.posix.normalize(name);
  if (normalized === ".." || normalized.startsWith("../")) {
    throw new Error(`Unsafe ZIP entry blocked: ${name}`);
  }
  return normalized;
}

function isSymlinkEntry(entry) {
  const unixMode = (entry.externalFileAttributes >>> 16) & 0xffff;
  return (unixMode & 0o170000) === 0o120000;
}

function openZip(zipPath) {
  return new Promise((resolve, reject) => {
    yauzl.open(zipPath, { lazyEntries: true, decodeStrings: true, validateEntrySizes: true }, (error, zipFile) => {
      if (error) reject(error);
      else resolve(zipFile);
    });
  });
}

async function validateZipArchive(zipPath) {
  const zipFile = await openZip(zipPath);
  const entries = [];
  return new Promise((resolve, reject) => {
    const fail = (error) => {
      try { zipFile.close(); } catch (_) {}
      reject(error);
    };
    zipFile.on("error", fail);
    zipFile.on("entry", (entry) => {
      try {
        const normalized = validateZipEntryName(entry.fileName);
        if (isSymlinkEntry(entry)) throw new Error(`Symbolic link ZIP entry blocked: ${entry.fileName}`);
        entries.push(normalized);
        zipFile.readEntry();
      } catch (error) {
        fail(error);
      }
    });
    zipFile.on("end", () => resolve(entries));
    zipFile.readEntry();
  });
}

async function extractZipArchive(zipPath, destinationRoot) {
  const root = path.resolve(destinationRoot);
  fs.mkdirSync(root, { recursive: true });
  const zipFile = await openZip(zipPath);
  return new Promise((resolve, reject) => {
    let settled = false;
    const fail = (error) => {
      if (settled) return;
      settled = true;
      try { zipFile.close(); } catch (_) {}
      reject(error);
    };
    const next = () => {
      if (!settled) zipFile.readEntry();
    };

    zipFile.on("error", fail);
    zipFile.on("entry", (entry) => {
      let normalized;
      try {
        normalized = validateZipEntryName(entry.fileName);
        if (isSymlinkEntry(entry)) throw new Error(`Symbolic link ZIP entry blocked: ${entry.fileName}`);
      } catch (error) {
        fail(error);
        return;
      }

      const outputPath = path.resolve(root, ...normalized.split("/"));
      if (outputPath !== root && !outputPath.startsWith(`${root}${path.sep}`)) {
        fail(new Error(`Unsafe ZIP entry blocked: ${entry.fileName}`));
        return;
      }
      if (entry.fileName.endsWith("/")) {
        fs.mkdirSync(outputPath, { recursive: true });
        next();
        return;
      }

      fs.mkdirSync(path.dirname(outputPath), { recursive: true });
      zipFile.openReadStream(entry, (error, readStream) => {
        if (error) {
          fail(error);
          return;
        }
        const writeStream = fs.createWriteStream(outputPath, { flags: "wx", mode: 0o644 });
        readStream.on("error", fail);
        writeStream.on("error", fail);
        writeStream.on("finish", next);
        readStream.pipe(writeStream);
      });
    });
    zipFile.on("end", () => {
      if (settled) return;
      settled = true;
      resolve();
    });
    next();
  });
}

module.exports = {
  extractZipArchive,
  validateZipArchive,
  validateZipEntryName
};
