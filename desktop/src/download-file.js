const crypto = require("crypto");
const fs = require("fs");
const http = require("http");
const https = require("https");
const path = require("path");
const { Transform } = require("stream");
const { pipeline } = require("stream/promises");
const { fileURLToPath } = require("url");

class DownloadCanceledError extends Error {
  constructor(message = "Download canceled.") {
    super(message);
    this.name = "DownloadCanceledError";
    this.code = "CGV_DOWNLOAD_CANCELED";
  }
}

function throwIfCanceled(signal) {
  if (signal && signal.aborted) throw new DownloadCanceledError();
}

function normalizeDownloadError(error) {
  if (error instanceof DownloadCanceledError || (error && error.name === "AbortError")) {
    return new DownloadCanceledError();
  }
  return error;
}

function sha256File(filePath) {
  return new Promise((resolve, reject) => {
    const hash = crypto.createHash("sha256");
    const stream = fs.createReadStream(filePath);
    stream.on("data", (chunk) => hash.update(chunk));
    stream.on("error", reject);
    stream.on("end", () => resolve(hash.digest("hex")));
  });
}

function openHttpResponse(url, signal, redirectsRemaining = 5) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith("https:") ? https : http;
    const request = client.get(url, { signal }, (response) => {
      if ([301, 302, 303, 307, 308].includes(response.statusCode) && response.headers.location) {
        response.resume();
        if (redirectsRemaining <= 0) {
          reject(new Error(`Too many redirects while downloading: ${url}`));
          return;
        }
        const redirectUrl = new URL(response.headers.location, url).toString();
        openHttpResponse(redirectUrl, signal, redirectsRemaining - 1).then(resolve, reject);
        return;
      }
      if (response.statusCode !== 200) {
        response.resume();
        reject(new Error(`Download failed with HTTP ${response.statusCode}: ${url}`));
        return;
      }
      resolve(response);
    });
    request.on("error", (error) => reject(normalizeDownloadError(error)));
    request.setTimeout(30000, () => {
      request.destroy(new Error(`Download timed out while connecting or waiting for data: ${url}`));
    });
  });
}

async function downloadFile(url, targetPath, expectedSha256, progressCallback = () => {}, options = {}) {
  const signal = options.signal;
  const partPath = `${targetPath}.part`;
  const startedAt = Date.now();
  let done = 0;
  let total = 0;

  const report = (phase, payload = {}) => {
    const elapsedSeconds = Math.max(0.001, (Date.now() - startedAt) / 1000);
    const speed = done > 0 ? done / elapsedSeconds : null;
    const eta = speed && total > done ? (total - done) / speed : null;
    progressCallback({
      phase,
      path: targetPath,
      done,
      total,
      percent: total > 0 ? done / total : null,
      speed,
      eta,
      ...payload
    });
  };

  throwIfCanceled(signal);
  fs.mkdirSync(path.dirname(targetPath), { recursive: true });
  fs.rmSync(partPath, { force: true });
  report("connecting", { url });

  try {
    const localPath = url.startsWith("file:")
      ? fileURLToPath(url)
      : (path.isAbsolute(url) ? url : "");
    let source;
    if (localPath) {
      total = fs.statSync(localPath).size;
      source = fs.createReadStream(localPath);
    } else {
      source = await openHttpResponse(url, signal);
      total = Number(source.headers["content-length"] || 0);
    }

    const progress = new Transform({
      transform(chunk, _encoding, callback) {
        done += chunk.length;
        report("downloading");
        callback(null, chunk);
      }
    });
    await pipeline(source, progress, fs.createWriteStream(partPath, { flags: "wx" }), { signal });
    throwIfCanceled(signal);

    if (expectedSha256) {
      report("verifying", { percent: 1 });
      const actualSha256 = await sha256File(partPath);
      throwIfCanceled(signal);
      if (actualSha256.toLowerCase() !== expectedSha256.toLowerCase()) {
        throw new Error(`Checksum mismatch for ${path.basename(targetPath)}. Expected ${expectedSha256}, got ${actualSha256}.`);
      }
    }

    fs.rmSync(targetPath, { force: true });
    fs.renameSync(partPath, targetPath);
    return targetPath;
  } catch (error) {
    fs.rmSync(partPath, { force: true });
    throw normalizeDownloadError(error);
  }
}

module.exports = {
  DownloadCanceledError,
  downloadFile,
  sha256File,
  throwIfCanceled
};
