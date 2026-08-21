const assert = require("node:assert/strict");
const fs = require("node:fs");
const http = require("node:http");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");
const { createRequire } = require("node:module");

const mainPath = path.resolve(__dirname, "..", "src", "main.js");

function loadMainInternals() {
  const source = fs.readFileSync(mainPath, "utf8");
  const localRequire = createRequire(mainPath);
  const fakeApp = {
    isPackaged: false,
    getPath: () => os.tmpdir(),
    on: () => {},
    quit: () => {},
    whenReady: () => ({ then: () => {} })
  };
  const fakeElectron = {
    app: fakeApp,
    BrowserWindow: { getAllWindows: () => [] },
    dialog: {},
    ipcMain: { handle: () => {} },
    Menu: { buildFromTemplate: () => ({}) },
    shell: {}
  };
  const module = { exports: {} };
  const testRequire = (id) => {
    if (id === "electron") return fakeElectron;
    if (id === "electron-updater") return { autoUpdater: {} };
    return localRequire(id);
  };
  const exposed = `\nmodule.exports = {
    catalogResponseCachePath,
    catalogResponseUrlHash,
    httpGetJson,
    readCatalogResponseCache,
    readMergedManifest,
    writeCatalogResponseCache
  };`;
  const context = vm.createContext({
    AbortController,
    Buffer,
    Date,
    Error,
    JSON,
    Map,
    Number,
    Object,
    Promise,
    Set,
    URL,
    clearInterval,
    clearTimeout,
    console,
    exports: module.exports,
    module,
    process,
    require: testRequire,
    setInterval,
    setTimeout,
    __dirname: path.dirname(mainPath),
    __filename: mainPath
  });
  vm.runInContext(source + exposed, context, { filename: mainPath });
  return module.exports;
}

function plain(value) {
  return JSON.parse(JSON.stringify(value));
}

function listen(server) {
  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => {
      server.off("error", reject);
      resolve(`http://127.0.0.1:${server.address().port}`);
    });
  });
}

function close(server) {
  return new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  });
}

test("catalog HTTP cache revalidates every call and handles 200, 304, new ETag, errors, invalid JSON and redirects", async (t) => {
  const { httpGetJson, readCatalogResponseCache } = loadMainInternals();
  const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-catalog-http-"));
  t.after(() => fs.rmSync(tmpRoot, { recursive: true, force: true }));

  let etag = '"catalog-v1"';
  let body = { version: 1, datasets: [{ id: "alpha" }] };
  let mode = "normal";
  const requests = [];
  const server = http.createServer((request, response) => {
    requests.push({ url: request.url, etag: request.headers["if-none-match"] || "" });
    if (request.url === "/redirect") {
      response.writeHead(302, { Location: "/catalog" });
      response.end();
      return;
    }
    if (request.url === "/slow") return;
    if (mode === "error") {
      response.writeHead(503);
      response.end("unavailable");
      return;
    }
    if (mode === "invalid") {
      response.writeHead(200, { ETag: '"invalid"', "Content-Type": "application/json" });
      response.end("{not-json");
      return;
    }
    if (request.headers["if-none-match"] === etag) {
      response.writeHead(304, { ETag: etag });
      response.end();
      return;
    }
    response.writeHead(200, { ETag: etag, "Content-Type": "application/json" });
    response.end(JSON.stringify(body));
  });
  const origin = await listen(server);
  t.after(() => close(server));

  const cachePath = path.join(tmpRoot, "catalog-cache.json");
  const catalogUrl = `${origin}/catalog`;
  const first = await httpGetJson(catalogUrl, { cachePath });
  assert.deepEqual(plain(first), body);
  assert.equal(requests.length, 1);
  assert.equal(requests[0].etag, "");
  assert.equal(fs.existsSync(cachePath), true);
  assert.deepEqual(plain(readCatalogResponseCache(cachePath, catalogUrl)), { body, etag });
  assert.deepEqual(fs.readdirSync(tmpRoot).filter((name) => name.endsWith(".tmp")), []);

  const unchanged = await httpGetJson(catalogUrl, { cachePath });
  assert.deepEqual(plain(unchanged), body);
  assert.equal(requests.length, 2, "a cache hit must still revalidate over HTTP");
  assert.equal(requests[1].etag, etag);

  etag = '"catalog-v2"';
  body = { version: 2, datasets: [{ id: "beta" }] };
  const updated = await httpGetJson(catalogUrl, { cachePath });
  assert.deepEqual(plain(updated), body);
  assert.equal(requests.at(-1).etag, '"catalog-v1"');
  assert.deepEqual(plain(readCatalogResponseCache(cachePath, catalogUrl)), { body, etag });

  mode = "error";
  await assert.rejects(
    httpGetJson(catalogUrl, { cachePath }),
    /Catalog request failed with HTTP 503/,
    "a network/status error must not return the cached body"
  );
  mode = "invalid";
  await assert.rejects(
    httpGetJson(catalogUrl, { cachePath }),
    /Catalog JSON could not be parsed/,
    "invalid fresh JSON must not fall back to the cached body"
  );
  assert.deepEqual(
    plain(readCatalogResponseCache(cachePath, catalogUrl)),
    { body, etag },
    "failed responses must not replace the last valid validator/body pair"
  );

  mode = "normal";
  const redirectCachePath = path.join(tmpRoot, "redirect-cache.json");
  const redirected = await httpGetJson(`${origin}/redirect`, { cachePath: redirectCachePath });
  assert.deepEqual(plain(redirected), body);
  assert.deepEqual(requests.slice(-2).map((entry) => entry.url), ["/redirect", "/catalog"]);
  const redirectedAgain = await httpGetJson(`${origin}/redirect`, { cachePath: redirectCachePath });
  assert.deepEqual(plain(redirectedAgain), body);
  assert.equal(requests.at(-1).etag, etag, "the validator must survive a redirect");

  await assert.rejects(
    httpGetJson(`${origin}/slow`, {
      cachePath: path.join(tmpRoot, "slow-cache.json"),
      timeoutMs: 30
    }),
    /Catalog request timed out/
  );
});

test("corrupt or wrong-URL cache is ignored and atomically replaced by a fresh 200", async (t) => {
  const { httpGetJson, writeCatalogResponseCache } = loadMainInternals();
  const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-catalog-corrupt-"));
  t.after(() => fs.rmSync(tmpRoot, { recursive: true, force: true }));
  const seenEtags = [];
  const body = { datasets: [{ id: "fresh" }] };
  const server = http.createServer((request, response) => {
    seenEtags.push(request.headers["if-none-match"] || "");
    response.writeHead(200, { ETag: '"fresh"', "Content-Type": "application/json" });
    response.end(JSON.stringify(body));
  });
  const origin = await listen(server);
  t.after(() => close(server));

  const cachePath = path.join(tmpRoot, "catalog-cache.json");
  fs.writeFileSync(cachePath, "not-json");
  assert.deepEqual(plain(await httpGetJson(`${origin}/catalog`, { cachePath })), body);
  assert.equal(seenEtags[0], "");

  assert.equal(
    writeCatalogResponseCache(cachePath, `${origin}/other`, '"wrong"', { datasets: [{ id: "wrong" }] }),
    true
  );
  assert.deepEqual(plain(await httpGetJson(`${origin}/catalog`, { cachePath })), body);
  assert.equal(seenEtags[1], "", "a validator cached for another URL must never be sent");
  assert.deepEqual(fs.readdirSync(tmpRoot).filter((name) => name.endsWith(".tmp")), []);
});

test("readMergedManifest preserves the existing base-catalog fallback and catalogError", async (t) => {
  const { readMergedManifest } = loadMainInternals();
  const tmpRoot = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-catalog-fallback-"));
  const previous = {
    cache: process.env.CGV_DESKTOP_CACHE_ROOT,
    localCatalog: process.env.CGV_DESKTOP_LOCAL_CATALOG,
    manifest: process.env.CGV_DESKTOP_MANIFEST
  };
  t.after(() => {
    fs.rmSync(tmpRoot, { recursive: true, force: true });
    if (previous.cache === undefined) delete process.env.CGV_DESKTOP_CACHE_ROOT;
    else process.env.CGV_DESKTOP_CACHE_ROOT = previous.cache;
    if (previous.localCatalog === undefined) delete process.env.CGV_DESKTOP_LOCAL_CATALOG;
    else process.env.CGV_DESKTOP_LOCAL_CATALOG = previous.localCatalog;
    if (previous.manifest === undefined) delete process.env.CGV_DESKTOP_MANIFEST;
    else process.env.CGV_DESKTOP_MANIFEST = previous.manifest;
  });

  const server = http.createServer((_request, response) => {
    response.writeHead(502);
    response.end("bad gateway");
  });
  const origin = await listen(server);
  t.after(() => close(server));

  const manifestPath = path.join(tmpRoot, "data-manifest.json");
  fs.writeFileSync(manifestPath, JSON.stringify({
    version: 1,
    catalogUrl: `${origin}/catalog`,
    datasets: [{ id: "bundled-base", downloadable: false }]
  }));
  process.env.CGV_DESKTOP_MANIFEST = manifestPath;
  process.env.CGV_DESKTOP_LOCAL_CATALOG = path.join(tmpRoot, "missing-local.json");
  process.env.CGV_DESKTOP_CACHE_ROOT = path.join(tmpRoot, "cache");

  const manifest = plain(await readMergedManifest());
  assert.deepEqual(manifest.datasets, [{ id: "bundled-base", downloadable: false }]);
  assert.match(manifest.catalogError, /Catalog request failed with HTTP 502/);
  assert.equal(manifest.remoteCatalog, undefined);
});
