#!/usr/bin/env node
'use strict';

const assert = require('assert');
const fs = require('fs');
const vm = require('vm');

function classList() {
  const values = new Set();
  return {
    add: (...items) => items.forEach((item) => values.add(item)),
    remove: (...items) => items.forEach((item) => values.delete(item)),
    contains: (item) => values.has(item)
  };
}

const elements = {
  'app-work-indicator': {
    hidden: true,
    attributes: { 'aria-hidden': 'true' },
    classList: classList(),
    style: {},
    setAttribute(name, value) { this.attributes[name] = String(value); },
    removeAttribute(name) { delete this.attributes[name]; }
  },
  'app-work-indicator-headline': { textContent: '' },
  'app-work-indicator-detail': { textContent: '' }
};
const documentAttributes = Object.create(null);
const nativeHandlers = Object.create(null);
const jqueryHandlers = Object.create(null);
let mainRect = { left: 320, width: 960 };
const main = {
  getBoundingClientRect() { return mainRect; }
};
const shell = {
  addEventListener(name, handler) { nativeHandlers[`shell:${name}`] = handler; }
};

global.document = {
  readyState: 'complete',
  documentElement: {
    setAttribute(name, value) { documentAttributes[name] = String(value); },
    removeAttribute(name) { delete documentAttributes[name]; }
  },
  getElementById(id) { return elements[id] || null; },
  querySelector(selector) {
    if (selector === '.app-main') return main;
    if (selector === '.app-shell') return shell;
    return null;
  },
  addEventListener(name, handler) { nativeHandlers[name] = handler; }
};

global.window = {
  setTimeout,
  clearTimeout,
  addEventListener(name, handler) { nativeHandlers[name] = handler; }
};
global.window.jQuery = function () {
  return {
    on(name, handler) { jqueryHandlers[name] = handler; }
  };
};

const source = fs.readFileSync('www/js/activity_feedback.js', 'utf8');
vm.runInThisContext(source, { filename: 'activity_feedback.js' });

const wait = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

(async function () {
  assert.ok(window.cgvActivity, 'activity API should be exposed');
  assert.strictEqual(elements['app-work-indicator'].style.left, '800px');
  assert.strictEqual(elements['app-work-indicator'].style.width, '460px');
  assert.strictEqual(elements['app-work-indicator'].attributes['data-layout-anchor'], 'app-main');

  mainRect = { left: 100, width: 1180 };
  nativeHandlers['shell:transitionend']();
  await wait(8);
  assert.strictEqual(elements['app-work-indicator'].style.left, '690px');

  window.cgvActivity.begin('generic', {
    headline: 'CGV is working', detail: 'Processing data…', priority: 5, delay: 0
  });
  await wait(8);
  assert.strictEqual(elements['app-work-indicator'].hidden, false);
  assert.strictEqual(elements['app-work-indicator-detail'].textContent, 'Processing data…');
  assert.strictEqual(documentAttributes['data-app-working'], 'true');

  window.cgvActivity.begin('specific', {
    headline: 'Multi-gene search', detail: 'Plotting TP53…', priority: 60, delay: 0
  });
  await wait(2);
  assert.strictEqual(elements['app-work-indicator-headline'].textContent, 'Multi-gene search');
  assert.strictEqual(elements['app-work-indicator-detail'].textContent, 'Plotting TP53…');

  window.cgvActivity.end('specific');
  assert.strictEqual(elements['app-work-indicator-detail'].textContent, 'Processing data…');
  window.cgvActivity.end('generic');
  await wait(440);
  assert.strictEqual(elements['app-work-indicator'].hidden, true);
  assert.strictEqual(documentAttributes['data-app-working'], undefined);

  window.cgvActivity.begin('cancelled-before-delay', {
    headline: 'Figure Studio', detail: 'Preparing panel…', delay: 60
  });
  window.cgvActivity.end('cancelled-before-delay');
  await wait(75);
  assert.strictEqual(elements['app-work-indicator'].hidden, true);

  window.cgvActivity.begin('disconnect-test', { detail: 'Waiting…', delay: 0 });
  await wait(5);
  assert.strictEqual(elements['app-work-indicator'].hidden, false);
  jqueryHandlers['shiny:disconnected']();
  assert.strictEqual(elements['app-work-indicator'].hidden, true);

  console.log('activity-feedback-behavior-ok');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
