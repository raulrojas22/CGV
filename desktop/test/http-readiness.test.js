const assert = require("node:assert/strict");
const http = require("node:http");
const test = require("node:test");
const { readinessProbeUrl, waitForHttp } = require("../src/http-readiness");

function listen(server) {
  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", () => resolve(server.address().port));
  });
}

function close(server) {
  return new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
}

test("readiness probe uses a static Shiny resource instead of the full Home", () => {
  assert.equal(
    readinessProbeUrl("http://127.0.0.1:51179"),
    "http://127.0.0.1:51179/favicon.ico"
  );
});

test("static readiness succeeds even when the Home response exceeds the request limit", async () => {
  const server = http.createServer((request, response) => {
    if (request.url === "/favicon.ico") {
      response.writeHead(200, { "content-type": "image/x-icon" });
      response.end("ready");
      return;
    }
    setTimeout(() => {
      response.writeHead(200, { "content-type": "text/html" });
      response.end("slow home");
    }, 250);
  });
  const port = await listen(server);

  try {
    const result = await waitForHttp(readinessProbeUrl(`http://127.0.0.1:${port}`), {
      timeoutMs: 1000,
      requestTimeoutMs: 50,
      retryDelayMs: 10
    });
    assert.equal(result.statusCode, 200);
    assert.equal(result.attempt, 1);
  } finally {
    await close(server);
  }
});

test("a timed-out request schedules only one retry", async () => {
  let requests = 0;
  const retries = [];
  const server = http.createServer((_request, response) => {
    requests += 1;
    if (requests === 1) return;
    response.writeHead(200);
    response.end("ready");
  });
  const port = await listen(server);

  try {
    const result = await waitForHttp(`http://127.0.0.1:${port}/favicon.ico`, {
      timeoutMs: 1000,
      requestTimeoutMs: 40,
      retryDelayMs: 10,
      onRetry: (retry) => retries.push(retry)
    });
    assert.equal(result.attempt, 2);
    assert.equal(requests, 2);
    assert.equal(retries.length, 1);
    assert.match(retries[0].reason, /exceeded/);
  } finally {
    await close(server);
  }
});
