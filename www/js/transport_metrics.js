(function () {
  'use strict';

  if (window.__cgvTransportMetricsInitialized) return;
  window.__cgvTransportMetricsInitialized = true;

  var enabled = !!window.__cgvTransportTiming;
  if (!enabled) return;

  var flushIntervalMs = Number(window.__cgvTransportFlushMs || 5000);
  if (!isFinite(flushIntervalMs) || flushIntervalMs < 1000) flushIntervalMs = 5000;

  var startedAt = Date.now();
  var socketSeq = 0;
  var counters = {
    wsInBytes: 0,
    wsOutBytes: 0,
    wsInMessages: 0,
    wsOutMessages: 0,
    wsOpenCount: 0,
    wsCloseCount: 0
  };

  function byteLength(value) {
    try {
      if (value == null) return 0;
      if (typeof value === 'string') {
        if (window.TextEncoder) return new TextEncoder().encode(value).length;
        return unescape(encodeURIComponent(value)).length;
      }
      if (value instanceof ArrayBuffer) return value.byteLength || 0;
      if (ArrayBuffer.isView && ArrayBuffer.isView(value)) return value.byteLength || 0;
      if (typeof Blob !== 'undefined' && value instanceof Blob) return value.size || 0;
      return byteLength(String(value));
    } catch (_e) {
      return 0;
    }
  }

  function patchWebSocket() {
    var NativeWebSocket = window.WebSocket;
    if (typeof NativeWebSocket !== 'function' || NativeWebSocket.__cgvPatched) return;

    function PatchedWebSocket(url, protocols) {
      var ws = protocols !== undefined ? new NativeWebSocket(url, protocols) : new NativeWebSocket(url);
      var id = ++socketSeq;
      try { ws.__cgvSocketId = id; } catch (_e0) {}

      ws.addEventListener('open', function () {
        counters.wsOpenCount += 1;
      });
      ws.addEventListener('close', function () {
        counters.wsCloseCount += 1;
      });
      ws.addEventListener('message', function (event) {
        counters.wsInMessages += 1;
        counters.wsInBytes += byteLength(event && event.data);
      });

      var nativeSend = ws.send;
      ws.send = function (data) {
        counters.wsOutMessages += 1;
        counters.wsOutBytes += byteLength(data);
        return nativeSend.call(ws, data);
      };

      return ws;
    }

    PatchedWebSocket.prototype = NativeWebSocket.prototype;
    try {
      Object.setPrototypeOf(PatchedWebSocket, NativeWebSocket);
    } catch (_protoErr) {}
    try {
      Object.defineProperty(PatchedWebSocket, '__cgvPatched', { value: true });
    } catch (_markErr) {
      PatchedWebSocket.__cgvPatched = true;
    }

    try {
      window.WebSocket = PatchedWebSocket;
    } catch (assignErr) {
      if (window.console && typeof console.warn === 'function') {
        console.warn('[CGV transport] WebSocket patch unavailable', assignErr);
      }
    }
  }

  function summarizeResources(includeDetails) {
    var entries = [];
    try {
      entries = performance.getEntriesByType('resource') || [];
    } catch (_e) {
      entries = [];
    }

    var totalTransfer = 0;
    var totalEncoded = 0;
    var totalDecoded = 0;
    var byType = {};
    var largest = [];

    function addToType(type, transfer, encoded, decoded) {
      if (!byType[type]) {
        byType[type] = { count: 0, transferSize: 0, encodedBodySize: 0, decodedBodySize: 0 };
      }
      byType[type].count += 1;
      byType[type].transferSize += transfer;
      byType[type].encodedBodySize += encoded;
      byType[type].decodedBodySize += decoded;
    }

    entries.forEach(function (entry) {
      var transfer = Number(entry.transferSize || 0);
      var encoded = Number(entry.encodedBodySize || 0);
      var decoded = Number(entry.decodedBodySize || 0);
      var type = String(entry.initiatorType || 'other');
      totalTransfer += isFinite(transfer) ? transfer : 0;
      totalEncoded += isFinite(encoded) ? encoded : 0;
      totalDecoded += isFinite(decoded) ? decoded : 0;
      if (includeDetails) {
        addToType(type, transfer, encoded, decoded);
        largest.push({
          name: String(entry.name || '').slice(0, 180),
          initiatorType: type,
          transferSize: transfer,
          encodedBodySize: encoded,
          decodedBodySize: decoded,
          durationMs: Math.round(Number(entry.duration || 0))
        });
      }
    });

    largest.sort(function (a, b) {
      return (b.transferSize || b.encodedBodySize || 0) - (a.transferSize || a.encodedBodySize || 0);
    });

    return {
      count: entries.length,
      transferSize: Math.round(totalTransfer),
      encodedBodySize: Math.round(totalEncoded),
      decodedBodySize: Math.round(totalDecoded),
      byType: includeDetails ? byType : null,
      largest: includeDetails ? largest.slice(0, 12) : null
    };
  }

  function buildPayload(reason) {
    var reasonTxt = String(reason || 'interval');
    var includeResourceDetails = reasonTxt !== 'interval';
    var nav = null;
    try {
      var navEntries = performance.getEntriesByType('navigation') || [];
      if (navEntries.length) {
        var n = navEntries[0];
        nav = {
          transferSize: Math.round(Number(n.transferSize || 0)),
          encodedBodySize: Math.round(Number(n.encodedBodySize || 0)),
          decodedBodySize: Math.round(Number(n.decodedBodySize || 0)),
          domContentLoadedMs: Math.round(Number(n.domContentLoadedEventEnd || 0)),
          loadMs: Math.round(Number(n.loadEventEnd || 0))
        };
      }
    } catch (_e) {}

    return {
      reason: reasonTxt,
      url: window.location.href,
      elapsedMs: Date.now() - startedAt,
      websocket: {
        inBytes: Math.round(counters.wsInBytes),
        outBytes: Math.round(counters.wsOutBytes),
        inMessages: counters.wsInMessages,
        outMessages: counters.wsOutMessages,
        openCount: counters.wsOpenCount,
        closeCount: counters.wsCloseCount
      },
      resources: summarizeResources(includeResourceDetails),
      navigation: nav
    };
  }

  function flush(reason) {
    var payload = buildPayload(reason);
    window.__cgvLastTransportMetrics = payload;

    if (window.console && typeof console.info === 'function') {
      console.info('[CGV transport]', payload);
    }

    try {
      if (window.Shiny && typeof window.Shiny.setInputValue === 'function') {
        window.Shiny.setInputValue('cgv_transport_metrics', payload, { priority: 'event' });
      }
    } catch (_e) {}
  }

  patchWebSocket();

  window.CGVTransportMetrics = {
    flush: flush,
    snapshot: function () { return buildPayload('manual'); }
  };

  document.addEventListener('shiny:connected', function () {
    setTimeout(function () { flush('connected'); }, 500);
  });
  window.addEventListener('load', function () {
    setTimeout(function () { flush('load'); }, 1000);
  });
  window.addEventListener('beforeunload', function () {
    flush('beforeunload');
  });

  setInterval(function () {
    flush('interval');
  }, flushIntervalMs);
})();
