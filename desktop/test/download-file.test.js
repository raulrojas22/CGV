const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const { downloadFile } = require("../src/download-file");

test("downloads and verifies a local file", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-download-test-"));
  const source = path.join(root, "source.bin");
  const target = path.join(root, "nested", "target.bin");
  const content = Buffer.from("CGV dataset payload");
  fs.writeFileSync(source, content);
  const sha256 = crypto.createHash("sha256").update(content).digest("hex");
  try {
    await downloadFile(source, target, sha256);
    assert.deepEqual(fs.readFileSync(target), content);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test("removes partial files after a checksum failure", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-download-test-"));
  const source = path.join(root, "source.bin");
  const target = path.join(root, "target.bin");
  fs.writeFileSync(source, "wrong payload");
  try {
    await assert.rejects(downloadFile(source, target, "0".repeat(64)), /Checksum mismatch/);
    assert.equal(fs.existsSync(target), false);
    assert.equal(fs.existsSync(`${target}.part`), false);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test("cancels an HTTP download and removes its partial file", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-download-test-"));
  const target = path.join(root, "target.bin");
  const server = http.createServer((_request, response) => {
    response.writeHead(200, { "content-length": 1024 * 1024 });
    const interval = setInterval(() => response.write(Buffer.alloc(4096, 1)), 5);
    response.on("close", () => clearInterval(interval));
  });
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  const controller = new AbortController();
  try {
    const url = `http://127.0.0.1:${server.address().port}/dataset.zip`;
    const pending = downloadFile(url, target, "", () => {}, { signal: controller.signal });
    setTimeout(() => controller.abort(), 25);
    await assert.rejects(pending, (error) => error && error.code === "CGV_DOWNLOAD_CANCELED");
    assert.equal(fs.existsSync(target), false);
    assert.equal(fs.existsSync(`${target}.part`), false);
  } finally {
    await new Promise((resolve) => server.close(resolve));
    fs.rmSync(root, { recursive: true, force: true });
  }
});
