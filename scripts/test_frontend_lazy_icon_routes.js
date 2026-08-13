#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const fromRepo = (...parts) => path.join(repoRoot, ...parts);

const uiSource = fs.readFileSync(fromRepo("ui.R"), "utf8");
const serverSource = fs.readFileSync(fromRepo("server.R"), "utf8");
const registrySource = fs.readFileSync(fromRepo("annotations", "registry.tsv"), "utf8").trim();

function sliceBetween(source, startMarker, endMarker, label) {
  const start = source.indexOf(startMarker);
  const end = source.indexOf(endMarker, start + startMarker.length);
  assert.ok(start >= 0 && end > start, `${label} block must exist`);
  return source.slice(start, end);
}

function countMatches(source, pattern) {
  return [...source.matchAll(pattern)].length;
}

function assertLazySpeciesGenerator(source, label) {
  assert.equal(
    countMatches(source, /class\s*=\s*"species-grid-icon-img"/g),
    1,
    `${label} must keep exactly one species icon generator`
  );
  assert.match(
    source,
    /tags\$img\([\s\S]*?class\s*=\s*"species-grid-icon-img"[\s\S]*?src\s*=\s*icn[\s\S]*?alt\s*=\s*org[\s\S]*?loading\s*=\s*"lazy"[\s\S]*?\)/,
    `${label} must lazily load the unchanged dynamic icon route`
  );
  assert.match(
    source,
    /icon_url\[i\]\s*%\|\|%\s*"\/icons\/DNA\.ico"/,
    `${label} must preserve the DNA fallback route`
  );
}

const initialGenerator = sliceBetween(
  uiSource,
  "build_initial_species_grouped_grid <- function",
  "initial_homo_species_grid <-",
  "initial species generator"
);
const rerenderGenerator = sliceBetween(
  serverSource,
  "build_species_grouped_grid <- function",
  "output$homo_species_grid <- renderUI",
  "rerendered species generator"
);
assertLazySpeciesGenerator(initialGenerator, "Initial species generator");
assertLazySpeciesGenerator(rerenderGenerator, "Rerendered species generator");

assert.equal(
  countMatches(uiSource, /build_initial_species_grouped_grid\(initial_ready_preloaded_registry,/g),
  2,
  "Initial UI must keep its two species grids"
);
assert.equal(
  countMatches(serverSource, /build_species_grouped_grid\(ready_reg,/g),
  2,
  "Server rerender must keep its two species grids"
);

const databaseBlock = sliceBetween(
  uiSource,
  'h3(icon("database"), span("External alias lookup"))',
  'class = "help-section desktop-organisms-section"',
  "external alias database cards"
);
const expectedDatabaseRoutes = [
  "icons/databases/mygene.ico",
  "icons/databases/ncbi.ico",
  "icons/databases/uniprot.ico",
  "icons/databases/ensembl.ico"
];
const actualDatabaseRoutes = [
  ...databaseBlock.matchAll(/src\s*=\s*"(icons\/databases\/[^"]+\.ico)"/g)
].map((match) => match[1]);
assert.deepEqual(
  actualDatabaseRoutes,
  expectedDatabaseRoutes,
  "Database icon routes and order must remain unchanged"
);
assert.equal(
  countMatches(databaseBlock, /class\s*=\s*"db-source-card-icon"/g),
  4,
  "External alias settings must keep four database icons"
);
assert.equal(
  countMatches(databaseBlock, /loading\s*=\s*"lazy"/g),
  4,
  "Every database icon must use native lazy loading"
);
assert.equal(
  countMatches(databaseBlock, /onerror\s*=\s*"this\.onerror=null;this\.src='icons\/DNA\.ico';"/g),
  4,
  "Every database icon must preserve its fallback handler"
);

const registryLines = registrySource.split(/\r?\n/);
const headers = registryLines[0].split("\t");
const iconColumn = headers.indexOf("icon");
assert.ok(iconColumn >= 0, "Preloaded registry must keep an icon column");
const registryIconRoutes = registryLines.slice(1).map((line) => line.split("\t")[iconColumn]);
assert.equal(registryIconRoutes.length, 25, "Cold UI baseline must keep 25 preloaded species");
for (const route of registryIconRoutes) {
  assert.match(route, /^\/icons\/[^"]+\.ico$/, `Unexpected registry icon route: ${route}`);
  assert.ok(
    fs.existsSync(fromRepo("www", route.replace(/^\//, ""))),
    `Registry icon asset must exist: ${route}`
  );
}

const generatedImageCount = registryIconRoutes.length * 2 + expectedDatabaseRoutes.length;
assert.equal(
  generatedImageCount,
  54,
  "Cold hidden-panel baseline must remain 50 species references plus 4 database references"
);

console.log("Frontend lazy icon route guards passed (54 references, routes unchanged).");
