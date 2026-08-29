'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

const scriptPath = path.resolve(__dirname, '../../www/js/plot_paint_timing.js');
const scriptSource = fs.readFileSync(scriptPath, 'utf8');

function createHarness(perfTimingEnabled) {
  const handlers = Object.create(null);
  const inputs = [];
  const rafQueue = [];
  const outputs = Object.create(null);
  const observers = [];
  const clickListeners = [];
  let now = 100;

  const cardRoot = { id: 'ortho-plot-cards-container' };
  const homoCardRoot = { id: 'homo-plot-cards-container' };
  const documentElement = {
    id: 'document-root',
    contains(node) { return !!node; }
  };
  const document = {
    documentElement,
    addEventListener(type, listener) {
      if (type === 'click') clickListeners.push(listener);
    },
    getElementById(id) {
      if (id === cardRoot.id) return cardRoot;
      if (id === homoCardRoot.id) return homoCardRoot;
      return outputs[id] || null;
    },
    querySelectorAll() { return Object.keys(outputs).map((id) => outputs[id]); }
  };

  class FakeMutationObserver {
    constructor(callback) {
      this.callback = callback;
      this.root = null;
      this.disconnected = false;
      observers.push(this);
    }
    observe(root) { this.root = root; }
    disconnect() { this.disconnected = true; }
  }

  const window = {
    __cgvPlotPaintTiming: perfTimingEnabled,
    performance: { now() { now += 1; return now; } },
    requestAnimationFrame(callback) { rafQueue.push(callback); },
    setTimeout(callback) { callback(); },
    MutationObserver: FakeMutationObserver,
    TextEncoder,
    Shiny: {
      addCustomMessageHandler(name, handler) { handlers[name] = handler; },
      setInputValue(name, payload, options) { inputs.push({ name, payload, options }); }
    }
  };

  vm.runInNewContext(scriptSource, {
    window,
    document,
    MutationObserver: FakeMutationObserver,
    TextEncoder,
    Date,
    Array,
    Object,
    String,
    Math,
    RegExp,
    unescape,
    encodeURIComponent
  }, { filename: scriptPath });

  function addSvg(outputId) {
    const svg = {
      outerHTML: '<svg><g><path /></g></svg>',
      querySelectorAll() { return [{}, {}, {}]; }
    };
    outputs[outputId] = {
      id: outputId,
      querySelector(selector) { return selector === 'svg' ? svg : null; }
    };
  }

  function drainFrames(limit = 20) {
    let count = 0;
    while (rafQueue.length && count < limit) {
      rafQueue.shift()();
      count += 1;
    }
    assert.ok(count < limit, 'requestAnimationFrame queue did not settle');
  }

  function runNextFrame() {
    assert.ok(rafQueue.length > 0, 'expected a queued requestAnimationFrame callback');
    rafQueue.shift()();
  }

  return { handlers, inputs, outputs, observers, clickListeners, cardRoot, homoCardRoot, documentElement, addSvg, drainFrames, runNextFrame };
}

{
  const h = createHarness(false);
  h.handlers.cgv_plot_timing_start({ run_id: 'ORTHO_RACE', context: 'orthologous', first_paint_only: true });
  h.handlers.cgv_plot_timing_expect({
    run_id: 'ORTHO_RACE',
    context: 'orthologous',
    output_ids: ['plot_ortho_A-plot'],
    first_paint_only: true
  });
  h.addSvg('plot_ortho_A-plot');
  h.runNextFrame();
  h.handlers.cgv_plot_timing_expect({
    run_id: 'ORTHO_RACE',
    context: 'orthologous',
    output_ids: ['plot_ortho_B-plot'],
    first_paint_only: true
  });
  h.addSvg('plot_ortho_B-plot');
  h.drainFrames();
  assert.equal(h.inputs.length, 1, 'a stale double-RAF callback must not consume the one-shot run');
  assert.equal(h.inputs[0].payload.output_id, 'plot_ortho_B-plot');
}

{
  const h = createHarness(false);
  h.handlers.cgv_plot_timing_start({
    run_id: 'HOMO_PROGRESSIVE',
    context: 'homologous',
    first_paint_only: false,
    functional_only: true
  });
  h.handlers.cgv_plot_timing_expect({
    run_id: 'HOMO_PROGRESSIVE',
    context: 'homologous',
    output_ids: ['plot_homo_1-plot', 'plot_homo_2-plot'],
    functional_only: true
  });
  assert.equal(h.observers.length, 1);
  assert.equal(h.observers[0].root, h.homoCardRoot, 'progressive Multi-Gene observer must stay scoped to its cards');
  h.addSvg('plot_homo_1-plot');
  h.observers[0].callback();
  h.drainFrames();
  h.addSvg('plot_homo_2-plot');
  h.observers[0].callback();
  h.drainFrames();
  assert.deepEqual(
    h.inputs.map((entry) => entry.payload.output_id),
    ['plot_homo_1-plot', 'plot_homo_2-plot'],
    'progressive Multi-Gene paint tracking must acknowledge every card'
  );
}

{
  const h = createHarness(false);
  h.addSvg('plot_ortho_1-plot');
  h.handlers.cgv_plot_timing_start({
    run_id: 'ORTHO_EXISTING',
    context: 'orthologous',
    first_paint_only: true
  });
  h.handlers.cgv_plot_timing_expect({
    run_id: 'ORTHO_EXISTING',
    context: 'orthologous',
    output_ids: ['plot_ortho_1-plot'],
    first_paint_only: true
  });
  h.drainFrames();
  assert.equal(h.inputs.length, 1, 'an already visible primary card must acknowledge the functional gate');
}

{
  const h = createHarness(false);
  assert.equal(h.clickListeners.length, 0, 'functional mode must not install click telemetry');
  assert.equal(h.observers.length, 0, 'functional mode must remain idle before expectations');

  h.handlers.cgv_plot_timing_start({
    run_id: 'ORTHO_A',
    context: 'orthologous',
    first_paint_only: true
  });
  h.handlers.cgv_plot_timing_expect({
    run_id: 'ORTHO_A',
    context: 'orthologous',
    output_ids: [],
    first_paint_only: true
  });
  assert.equal(h.observers.length, 0, 'empty expectations must not start a mutation observer');

  h.handlers.cgv_plot_timing_expect({
    run_id: 'ORTHO_A',
    context: 'orthologous',
    output_ids: 'plot_ortho_1-plot',
    first_paint_only: true
  });
  assert.equal(h.observers.length, 1);
  assert.equal(h.observers[0].root, h.cardRoot, 'functional observer must be scoped to Cross-Species cards');

  h.addSvg('plot_ortho_1-plot');
  h.observers[0].callback();
  h.drainFrames();

  assert.equal(h.inputs.length, 1, 'the functional watcher must publish exactly once');
  assert.equal(h.inputs[0].name, 'cgv_plot_painted');
  assert.equal(h.inputs[0].payload.output_id, 'plot_ortho_1-plot');
  assert.equal(h.inputs[0].payload.svg_bytes, null, 'functional mode must not serialize SVG');
  assert.equal(h.inputs[0].payload.svg_nodes, null, 'functional mode must not count SVG nodes');
  assert.equal(h.observers[0].disconnected, true, 'one-shot observer must disconnect after paint');

  h.observers[0].callback();
  h.drainFrames();
  assert.equal(h.inputs.length, 1, 'later mutations must not duplicate the paint acknowledgement');
}

{
  const h = createHarness(false);
  h.handlers.cgv_plot_timing_start({ run_id: 'ORTHO_OLD', context: 'orthologous', first_paint_only: true });
  h.handlers.cgv_plot_timing_expect({
    run_id: 'ORTHO_OLD',
    context: 'orthologous',
    output_ids: ['plot_ortho_old-plot'],
    first_paint_only: true
  });
  assert.equal(h.observers.length, 1);
  h.handlers.cgv_plot_timing_start({ run_id: 'ORTHO_NEW', context: 'orthologous', first_paint_only: true });
  assert.equal(h.observers[0].disconnected, true, 'a new search must disconnect the previous one-shot observer');
}

{
  const h = createHarness(false);
  h.handlers.cgv_plot_timing_start({ run_id: 'ORTHO_STOP', context: 'orthologous', first_paint_only: true });
  h.handlers.cgv_plot_timing_expect({
    run_id: 'ORTHO_STOP',
    context: 'orthologous',
    output_ids: ['plot_ortho_1-plot'],
    first_paint_only: true
  });
  assert.equal(h.observers.length, 1);
  h.handlers.cgv_plot_timing_stop({ run_id: 'ORTHO_STOP' });
  assert.equal(h.observers[0].disconnected, true, 'server fail-safe must cancel the browser watcher');
}

{
  const h = createHarness(true);
  assert.equal(h.clickListeners.length, 1, 'performance mode keeps click telemetry');
  h.handlers.cgv_plot_timing_start({ run_id: 'ORTHO_PERF', context: 'orthologous' });
  h.handlers.cgv_plot_timing_expect({
    run_id: 'ORTHO_PERF',
    context: 'orthologous',
    output_ids: ['plot_ortho_1-plot']
  });
  assert.equal(h.observers[0].root, h.documentElement, 'performance mode retains complete document telemetry');
  h.addSvg('plot_ortho_1-plot');
  h.observers[0].callback();
  h.drainFrames();
  assert.ok(h.inputs[0].payload.svg_bytes > 0);
  assert.equal(h.inputs[0].payload.svg_nodes, 3);
}

console.log('plot-paint-gate-js-ok');
