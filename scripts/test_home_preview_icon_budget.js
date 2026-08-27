#!/usr/bin/env node

"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const repoRoot = path.resolve(__dirname, "..");
const homePath = path.join(repoRoot, "www", "home_preview_cgv.html");
const iconDirectory = path.join(repoRoot, "www", "icons", "home");
const homeHtml = fs.readFileSync(homePath, "utf8");
const byteBudgetPerTheme = 55_000;

const expectedImages = [
  {
    src: "icons/home/favicon-light@2x.png",
    width: "31",
    height: "31",
    loading: "eager",
    themeLogo: true
  },
  { src: "icons/home/database-mygene@2x.png", width: "14", height: "14" },
  { src: "icons/home/database-ncbi@2x.png", width: "14", height: "14" },
  { src: "icons/home/database-uniprot@2x.png", width: "14", height: "14" },
  { src: "icons/home/database-ensembl@2x.png", width: "14", height: "14" },
  { src: "icons/home/species-homo-sapiens@2x.png", width: "24", height: "24" },
  { src: "icons/home/species-mus-musculus@2x.png", width: "24", height: "24" },
  { src: "icons/home/species-danio-rerio@2x.png", width: "24", height: "24" },
  {
    src: "icons/home/species-arabidopsis-thaliana@2x.png",
    width: "24",
    height: "24"
  },
  {
    src: "icons/home/species-oryza-sativa-japonica@2x.png",
    width: "24",
    height: "24"
  },
  {
    src: "icons/home/species-saccharomyces-cerevisiae@2x.png",
    width: "24",
    height: "24"
  },
  {
    src: "icons/home/favicon-light@2x.png",
    width: "29",
    height: "24",
    themeLogo: true
  }
];

const expectedIntrinsicSizes = new Map([
  ["icons/home/favicon-light@2x.png", [62, 47]],
  ["icons/home/favicon-dark@2x.png", [62, 47]],
  ["icons/home/database-mygene@2x.png", [28, 22]],
  ["icons/home/database-ncbi@2x.png", [28, 27]],
  ["icons/home/database-uniprot@2x.png", [28, 15]],
  ["icons/home/database-ensembl@2x.png", [28, 27]],
  ["icons/home/species-homo-sapiens@2x.png", [48, 48]],
  ["icons/home/species-mus-musculus@2x.png", [48, 48]],
  ["icons/home/species-danio-rerio@2x.png", [48, 48]],
  ["icons/home/species-arabidopsis-thaliana@2x.png", [48, 48]],
  ["icons/home/species-oryza-sativa-japonica@2x.png", [48, 48]],
  ["icons/home/species-saccharomyces-cerevisiae@2x.png", [48, 48]]
]);

function parseAttributes(tag) {
  const attributes = Object.create(null);
  for (const match of tag.matchAll(/\s([A-Za-z_:][\w:.-]*)\s*=\s*"([^"]*)"/g)) {
    assert.equal(attributes[match[1]], undefined, `duplicate ${match[1]} attribute in ${tag}`);
    attributes[match[1]] = match[2];
  }
  return attributes;
}

function pngDimensions(filePath) {
  const header = fs.readFileSync(filePath).subarray(0, 24);
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  assert.ok(header.subarray(0, 8).equals(signature), `${filePath} must be a PNG`);
  assert.equal(header.toString("ascii", 12, 16), "IHDR", `${filePath} must start with IHDR`);
  return [header.readUInt32BE(16), header.readUInt32BE(20)];
}

function absoluteAssetPath(route) {
  assert.match(route, /^icons\/home\/[a-z0-9-]+@2x\.png$/);
  return path.join(repoRoot, "www", ...route.split("/"));
}

const imageTags = [...homeHtml.matchAll(/<img\b[^>]*>/g)].map((match) => match[0]);
assert.equal(imageTags.length, expectedImages.length, "Home must keep exactly 12 image references");

const actualImages = imageTags.map(parseAttributes);
for (const [index, expected] of expectedImages.entries()) {
  const actual = actualImages[index];
  assert.equal(actual.src, expected.src, `unexpected route for Home image ${index + 1}`);
  assert.equal(actual.alt, "", `Home image ${index + 1} must remain decorative`);
  assert.equal(actual.width, expected.width, `wrong width for ${actual.src}`);
  assert.equal(actual.height, expected.height, `wrong height for ${actual.src}`);
  assert.equal(actual.decoding, "async", `async decode missing for ${actual.src}`);
  assert.equal(actual.loading, expected.loading || "lazy", `wrong loading mode for ${actual.src}`);

  if (expected.themeLogo) {
    assert.equal(actual["data-cgv-theme-logo"], "true", "theme logo marker missing");
    assert.equal(actual["data-light-src"], "icons/home/favicon-light@2x.png");
    assert.equal(actual["data-dark-src"], "icons/home/favicon-dark@2x.png");
  } else {
    assert.equal(actual["data-cgv-theme-logo"], undefined, `${actual.src} is not a theme logo`);
  }
}

assert.equal(
  actualImages.filter((image) => image.loading === "eager").length,
  1,
  "Only the upper navigation logo may load eagerly"
);
assert.equal(
  actualImages.filter((image) => image.loading === "lazy").length,
  11,
  "Every below-fold Home image must load lazily"
);
assert.equal(
  actualImages.filter((image) => image["data-cgv-theme-logo"] === "true").length,
  2,
  "The navigation and footer logos must remain theme-aware"
);

assert.match(
  homeHtml,
  /document\.querySelectorAll\('img\[data-cgv-theme-logo="true"\]'\)/,
  "Theme switching must select only explicit Home logo variants"
);
assert.match(
  homeHtml,
  /logo\.src\s*=\s*theme\s*===\s*"dark"\s*\?\s*logo\.getAttribute\("data-dark-src"\)\s*:\s*logo\.getAttribute\("data-light-src"\)/,
  "Theme switching must use the local light/dark PNG routes"
);

const expectedFiles = [...expectedIntrinsicSizes.keys()]
  .map((route) => path.basename(route))
  .sort();
const actualFiles = fs.readdirSync(iconDirectory)
  .filter((name) => !name.startsWith("."))
  .sort();
assert.deepEqual(actualFiles, expectedFiles, "Home icon directory must contain only guarded variants");

for (const [route, expectedSize] of expectedIntrinsicSizes) {
  const filePath = absoluteAssetPath(route);
  assert.ok(fs.statSync(filePath).isFile(), `missing Home icon asset: ${route}`);
  assert.deepEqual(pngDimensions(filePath), expectedSize, `wrong intrinsic dimensions for ${route}`);
}

const sharedRoutes = actualImages
  .filter((image) => image["data-cgv-theme-logo"] !== "true")
  .map((image) => image.src);
const lightRoutes = new Set([...sharedRoutes, "icons/home/favicon-light@2x.png"]);
const darkFinalRoutes = new Set([...sharedRoutes, "icons/home/favicon-dark@2x.png"]);
// The static markup starts with the light logo. A cold dark-theme boot may
// transfer both logo variants before applyTheme replaces the eager logo, so
// guard that stricter network budget as well as the final 11-source DOM state.
const darkBootRoutes = new Set([
  ...sharedRoutes,
  "icons/home/favicon-light@2x.png",
  "icons/home/favicon-dark@2x.png"
]);

function routeBytes(routes) {
  return [...routes].reduce((total, route) => total + fs.statSync(absoluteAssetPath(route)).size, 0);
}

const lightBytes = routeBytes(lightRoutes);
const darkFinalBytes = routeBytes(darkFinalRoutes);
const darkBootBytes = routeBytes(darkBootRoutes);
assert.equal(lightRoutes.size, 11, "Light Home must use 11 unique image sources");
assert.equal(darkFinalRoutes.size, 11, "Dark Home must use 11 unique image sources");
assert.ok(lightBytes <= byteBudgetPerTheme, `light icon budget exceeded: ${lightBytes} bytes`);
assert.ok(
  darkBootBytes <= byteBudgetPerTheme,
  `dark cold-boot icon budget exceeded: ${darkBootBytes} bytes`
);

console.log(
  `Home preview icon guards passed (12 refs; light=${lightBytes} B; dark-final=${darkFinalBytes} B; dark-cold-boot<=${darkBootBytes} B; budget=${byteBudgetPerTheme} B).`
);
