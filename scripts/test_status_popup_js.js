#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

function makeClassList(initial = []) {
  const values = new Set(initial);
  return {
    add(...names) {
      names.forEach((name) => values.add(name));
    },
    remove(...names) {
      names.forEach((name) => values.delete(name));
    },
    contains(name) {
      return values.has(name);
    },
    toggle(name, force) {
      const enabled = force === undefined ? !values.has(name) : Boolean(force);
      if (enabled) values.add(name);
      else values.delete(name);
      return enabled;
    }
  };
}

function makeElement(initialClasses = []) {
  return {
    classList: makeClassList(initialClasses),
    style: {},
    innerHTML: "",
    textContent: "",
    attributes: {},
    setAttribute(name, value) {
      this.attributes[name] = String(value);
    },
    getBoundingClientRect() {
      return { width: 460, height: 240, right: 1000, bottom: 700 };
    },
    querySelector() {
      return null;
    }
  };
}

const popup = makeElement(["app-status-popup"]);
const loaderText = makeElement(["app-status-popup-loader-text"]);
const log = makeElement(["app-status-popup-log"]);
const toggle = makeElement(["app-notification-center-toggle"]);
const badge = makeElement(["app-notification-center-badge"]);
const elements = {
  "app-status-popup": popup,
  "app-status-popup-loader-text": loaderText,
  "app-status-popup-log": log
};
const handlers = {};

const documentMock = {
  readyState: "complete",
  addEventListener() {},
  getElementById(id) {
    return elements[id] || null;
  },
  querySelector() {
    return null;
  },
  querySelectorAll(selector) {
    if (selector === ".app-notification-center-toggle") return [toggle];
    if (selector === ".app-notification-center-badge") return [badge];
    return [];
  }
};
const windowMock = {
  document: documentMock,
  innerWidth: 1200,
  innerHeight: 800,
  addEventListener() {},
  Shiny: {
    addCustomMessageHandler(name, handler) {
      handlers[name] = handler;
    }
  }
};
windowMock.window = windowMock;

const context = vm.createContext({
  window: windowMock,
  document: documentMock,
  Shiny: windowMock.Shiny,
  Date,
  Math,
  Set,
  isFinite,
  setTimeout() {
    return 1;
  },
  clearTimeout() {},
  setInterval() {
    return 1;
  },
  clearInterval() {},
  $(selector) {
    return {
      on() {
        return selector;
      }
    };
  }
});

vm.runInContext(
  fs.readFileSync("www/js/status_popup.js", "utf8"),
  context,
  { filename: "status_popup.js" }
);

assert.equal(typeof handlers.app_status_popup_loading, "function");
assert.equal(typeof handlers.app_status_popup, "function");

handlers.app_status_popup_loading({
  active: true,
  auto_open: true,
  context: "LASTZ Blocks",
  headline: "Please be patient",
  text: "Running LASTZ jobs."
});

assert.equal(popup.classList.contains("loading"), true, "LASTZ loader must be visible");
assert.equal(popup.classList.contains("open"), true, "LASTZ loader must auto-open");
assert.equal(toggle.classList.contains("is-loading"), true, "notification toggle must show activity");
assert.match(loaderText.innerHTML, /Running LASTZ jobs/);
assert.equal(badge.classList.contains("is-visible"), false, "progress must not create unread history");

handlers.app_status_popup_loading({
  active: true,
  auto_open: true,
  context: "LASTZ Blocks",
  headline: "Please be patient",
  text: "Running LASTZ jobs (2 / 4)."
});

assert.equal(popup.classList.contains("open"), true);
assert.match(loaderText.innerHTML, /2 \/ 4/);
assert.equal(badge.classList.contains("is-visible"), false, "progress updates must not create history");

handlers.app_status_popup_loading({
  active: false,
  context: "LASTZ Blocks"
});

assert.equal(popup.classList.contains("loading"), false);
assert.equal(popup.classList.contains("open"), false, "transient loader must close when work ends");
assert.equal(toggle.classList.contains("is-loading"), false);

handlers.app_status_popup_loading({
  active: true,
  auto_open: true,
  context: "MultiPIP",
  text: "Running MultiPIP."
});
handlers.app_status_popup({
  context: "MultiPIP",
  tone: "success",
  text: "Local alignments finished."
});
handlers.app_status_popup_loading({
  active: false,
  context: "MultiPIP"
});

assert.equal(popup.classList.contains("loading"), false);
assert.equal(popup.classList.contains("open"), true, "completion notification must remain visible");
assert.equal(badge.classList.contains("is-visible"), true, "only the final result enters history");

console.log("Status popup transient loading tests passed.");
