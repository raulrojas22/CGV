const http = require("http");

function readinessProbeUrl(appUrl) {
  const base = appUrl.endsWith("/") ? appUrl : `${appUrl}/`;
  return new URL("favicon.ico", base).toString();
}

function waitForHttp(url, options = {}) {
  const {
    timeoutMs = 240000,
    requestTimeoutMs = 15000,
    retryDelayMs = 1000,
    onRetry = () => {}
  } = options;
  const started = Date.now();
  let attempt = 0;

  return new Promise((resolve, reject) => {
    let settled = false;
    let retryTimer = null;

    const finish = (callback, value) => {
      if (settled) return;
      settled = true;
      if (retryTimer) clearTimeout(retryTimer);
      callback(value);
    };

    const scheduleRetry = (reason) => {
      if (settled) return;
      const elapsedMs = Date.now() - started;
      onRetry({ attempt, elapsedMs, reason });
      if (elapsedMs >= timeoutMs) {
        finish(reject, new Error(`Timed out waiting for ${url}: ${reason}`));
        return;
      }
      retryTimer = setTimeout(tick, Math.min(retryDelayMs, timeoutMs - elapsedMs));
    };

    const tick = () => {
      if (settled) return;
      attempt += 1;
      let attemptFinished = false;

      const failAttempt = (reason) => {
        if (attemptFinished || settled) return;
        attemptFinished = true;
        scheduleRetry(reason);
      };

      const req = http.get(url, (res) => {
        res.resume();
        if ([200, 301, 302, 303, 307, 308].includes(res.statusCode)) {
          if (attemptFinished || settled) return;
          attemptFinished = true;
          finish(resolve, { attempt, elapsedMs: Date.now() - started, statusCode: res.statusCode });
          return;
        }
        failAttempt(`HTTP ${res.statusCode}`);
      });

      req.on("error", (error) => failAttempt(error.code || error.message));
      req.setTimeout(requestTimeoutMs, () => {
        failAttempt(`request exceeded ${requestTimeoutMs} ms`);
        req.destroy();
      });
    };

    tick();
  });
}

module.exports = {
  readinessProbeUrl,
  waitForHttp
};
