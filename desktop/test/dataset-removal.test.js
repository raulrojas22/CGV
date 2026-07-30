const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const yazl = require("yazl");
const { removeInstalledDatasets, readTsvRows } = require("../src/dataset-removal");
const { validateZipArchive } = require("../src/secure-zip");

function writeFile(filePath, content = "fixture") {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, content);
}

function writeZip(zipPath, entries) {
  return new Promise((resolve, reject) => {
    const zip = new yazl.ZipFile();
    for (const [name, content] of entries) zip.addBuffer(Buffer.from(content), name);
    fs.mkdirSync(path.dirname(zipPath), { recursive: true });
    zip.outputStream.pipe(fs.createWriteStream(zipPath)).on("close", resolve).on("error", reject);
    zip.end();
  });
}

async function createFixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-dataset-removal-"));
  const dataRoot = path.join(root, "data");
  const cacheRoot = path.join(root, "cache");
  const ids = ["alpha", "beta", "gamma"];
  const annotationHeader = "species_id\torganism\ttaxid\tannotation\tgenome_2bit\ticon";
  const genomeHeader = "organism\ttaxid\ttwo_bit";
  const goHeader = "species_id\torganism\ttaxid\tgaf_file";
  writeFile(
    path.join(dataRoot, "annotations", "registry.tsv"),
    `${annotationHeader}\n${ids.map((id, index) => `${id}\t${id} organism\t${index + 1}\tannotations/${id}.gff.gz\tgenomes/${id}.2bit\ticons/${id}.ico`).join("\n")}\n`
  );
  writeFile(
    path.join(dataRoot, "genomes", "registry.tsv"),
    `${genomeHeader}\n${ids.map((id, index) => `${id} organism\t${index + 1}\t${id}.2bit`).join("\n")}\n`
  );
  writeFile(
    path.join(dataRoot, "go_annotations", "registry.tsv"),
    `${goHeader}\n${ids.map((id, index) => `${id}\t${id} organism\t${index + 1}\tgo_annotations/raw/${id}.gaf.gz`).join("\n")}\n`
  );
  writeFile(path.join(dataRoot, "go_annotations", "go-basic.obo"), "shared ontology");
  writeFile(path.join(dataRoot, "go_annotations", "go_term_map.rds"), "shared map");

  const datasets = [];
  const installed = {};
  for (const id of ids) {
    const packagePath = path.join(dataRoot, "packages", `${id}-1.zip`);
    const archiveEntries = [
      ["annotations/registry.tsv", `${annotationHeader}\n${id}\t${id} organism\n`],
      [`annotations/${id}.gff.gz`, `${id} annotation`],
      [`genomes/${id}.2bit`, `${id} genome`],
      [`go_annotations/raw/${id}.gaf.gz`, `${id} go`],
      [`www/icons/${id}.ico`, `${id} icon`],
      [`data/alias_index/${id}.metadata.json`, "{}"],
      [`data/alias_index/${id}.alias_index.sqlite`, `${id} aliases`],
      [`cache/annotation_index/package-${id}.rds`, `${id} package cache`],
      ["dataset.json", JSON.stringify({ id })]
    ];
    await writeZip(packagePath, archiveEntries);
    for (const [relativePath, content] of archiveEntries) {
      if (
        relativePath === "annotations/registry.tsv" ||
        relativePath === "dataset.json" ||
        relativePath.startsWith("cache/")
      ) {
        continue;
      }
      writeFile(path.join(dataRoot, relativePath), content);
    }
    writeFile(path.join(cacheRoot, "annotation_index", `package-${id}.rds`), `${id} package cache`);
    writeFile(path.join(dataRoot, "cache", "annotation_index", `package-${id}.rds`), `${id} legacy cache`);
    writeFile(
      path.join(cacheRoot, "annotation_index", `gene_light__annotations_${id}.gff.gz_123.rds`),
      `${id} generated cache`
    );
    datasets.push({ id, speciesId: id, version: "1", package: { sha256: `${id}-sha` } });
    installed[id] = {
      id,
      speciesId: id,
      version: "1",
      sha256: `${id}-sha`,
      packagePath
    };
  }
  writeFile(path.join(dataRoot, "dataset.json"), JSON.stringify({ id: "gamma" }));
  const installRegistry = { version: 1, datasets: installed };
  writeFile(path.join(dataRoot, "desktop-datasets.json"), `${JSON.stringify(installRegistry, null, 2)}\n`);
  return {
    root,
    dataRoot,
    cacheRoot,
    ids,
    manifest: { datasets },
    installRegistry
  };
}

function assertRemoved(fixture, removedIds, remainingIds) {
  for (const id of removedIds) {
    assert.equal(fs.existsSync(path.join(fixture.dataRoot, "annotations", `${id}.gff.gz`)), false);
    assert.equal(fs.existsSync(path.join(fixture.dataRoot, "genomes", `${id}.2bit`)), false);
    assert.equal(fs.existsSync(path.join(fixture.dataRoot, "go_annotations", "raw", `${id}.gaf.gz`)), false);
    assert.equal(fs.existsSync(path.join(fixture.dataRoot, "data", "alias_index", `${id}.alias_index.sqlite`)), false);
    assert.equal(fs.existsSync(path.join(fixture.cacheRoot, "annotation_index", `package-${id}.rds`)), false);
    assert.equal(fs.existsSync(path.join(fixture.dataRoot, "cache", "annotation_index", `package-${id}.rds`)), false);
    assert.equal(fs.existsSync(path.join(fixture.dataRoot, "packages", `${id}-1.zip`)), false);
  }
  for (const id of remainingIds) {
    assert.equal(fs.existsSync(path.join(fixture.dataRoot, "annotations", `${id}.gff.gz`)), true);
    assert.equal(fs.existsSync(path.join(fixture.dataRoot, "genomes", `${id}.2bit`)), true);
    assert.equal(fs.existsSync(path.join(fixture.dataRoot, "go_annotations", "raw", `${id}.gaf.gz`)), true);
    assert.equal(fs.existsSync(path.join(fixture.cacheRoot, "annotation_index", `package-${id}.rds`)), true);
    assert.equal(fs.existsSync(path.join(fixture.dataRoot, "cache", "annotation_index", `package-${id}.rds`)), true);
  }
  assert.deepEqual(
    readTsvRows(path.join(fixture.dataRoot, "annotations", "registry.tsv")).rows.map((row) => row.species_id),
    remainingIds
  );
  assert.deepEqual(
    Object.keys(JSON.parse(fs.readFileSync(path.join(fixture.dataRoot, "desktop-datasets.json"), "utf8")).datasets),
    remainingIds
  );
  assert.equal(fs.existsSync(path.join(fixture.dataRoot, "go_annotations", "go-basic.obo")), true);
  assert.equal(fs.existsSync(path.join(fixture.dataRoot, "go_annotations", "go_term_map.rds")), true);
}

for (const scenario of [
  { name: "one organism", removed: ["alpha"], remaining: ["beta", "gamma"] },
  { name: "several organisms", removed: ["alpha", "beta"], remaining: ["gamma"] },
  { name: "all organisms", removed: ["alpha", "beta", "gamma"], remaining: [] }
]) {
  test(`removes ${scenario.name} without deleting unselected datasets`, async () => {
    const fixture = await createFixture();
    try {
      const result = await removeInstalledDatasets({
        dataRoot: fixture.dataRoot,
        cacheRoot: fixture.cacheRoot,
        datasetIds: scenario.removed,
        manifest: fixture.manifest,
        installRegistry: fixture.installRegistry,
        validateZipArchive
      });
      assert.deepEqual(result.removedDatasetIds, scenario.removed);
      assertRemoved(fixture, scenario.removed, scenario.remaining);
    } finally {
      fs.rmSync(fixture.root, { recursive: true, force: true });
    }
  });
}

test("rejects removal requests for organisms that are not installed", async () => {
  const fixture = await createFixture();
  try {
    await assert.rejects(removeInstalledDatasets({
      dataRoot: fixture.dataRoot,
      cacheRoot: fixture.cacheRoot,
      datasetIds: ["missing"],
      manifest: fixture.manifest,
      installRegistry: fixture.installRegistry,
      validateZipArchive
    }), /not installed/);
  } finally {
    fs.rmSync(fixture.root, { recursive: true, force: true });
  }
});

test("removes legacy file-based installable datasets without an install-registry entry", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-file-dataset-removal-"));
  const dataRoot = path.join(root, "data");
  const cacheRoot = path.join(root, "cache");
  try {
    writeFile(
      path.join(dataRoot, "annotations", "registry.tsv"),
      "species_id\torganism\ttaxid\tannotation\nlegacy\tLegacy organism\t77\tannotations/legacy.gff.gz\n"
    );
    writeFile(path.join(dataRoot, "annotations", "legacy.gff.gz"), "legacy annotation");
    const result = await removeInstalledDatasets({
      dataRoot,
      cacheRoot,
      datasetIds: ["legacy"],
      manifest: {
        datasets: [{
          id: "legacy",
          speciesId: "legacy",
          files: [{ path: "annotations/legacy.gff.gz", required: true }]
        }]
      },
      installRegistry: { version: 1, datasets: {} },
      validateZipArchive
    });
    assert.deepEqual(result.removedDatasetIds, ["legacy"]);
    assert.equal(fs.existsSync(path.join(dataRoot, "annotations", "legacy.gff.gz")), false);
    assert.deepEqual(readTsvRows(path.join(dataRoot, "annotations", "registry.tsv")).rows, []);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
