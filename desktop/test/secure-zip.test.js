const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const yazl = require("yazl");
const {
  extractZipArchive,
  validateZipArchive,
  validateZipEntryName
} = require("../src/secure-zip");

function writeZip(zipPath, entries) {
  return new Promise((resolve, reject) => {
    const zip = new yazl.ZipFile();
    for (const [name, content] of entries) zip.addBuffer(Buffer.from(content), name);
    zip.outputStream.pipe(fs.createWriteStream(zipPath)).on("close", resolve).on("error", reject);
    zip.end();
  });
}

function writeSymlinkZip(zipPath) {
  return new Promise((resolve, reject) => {
    const zip = new yazl.ZipFile();
    zip.addBuffer(Buffer.from("annotations/registry.tsv"), "linked-registry", { mode: 0o120777 });
    zip.outputStream.pipe(fs.createWriteStream(zipPath)).on("close", resolve).on("error", reject);
    zip.end();
  });
}

test("ZIP entry validation blocks Windows and traversal paths", () => {
  assert.equal(validateZipEntryName("annotations/registry.tsv"), "annotations/registry.tsv");
  for (const name of ["../escape", "a/../../escape", "C:/escape", "/escape", "a\\escape", "file:stream", "NUL.txt", "NUL .txt", "trailing-dot."]) {
    assert.throws(() => validateZipEntryName(name), /Unsafe ZIP entry/);
  }
});

test("valid archives are listed and extracted", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-zip-test-"));
  const zipPath = path.join(root, "valid.zip");
  const output = path.join(root, "output");
  try {
    await writeZip(zipPath, [["annotations/registry.tsv", "species_id\thuman\n"]]);
    assert.deepEqual(await validateZipArchive(zipPath), ["annotations/registry.tsv"]);
    await extractZipArchive(zipPath, output);
    assert.equal(fs.readFileSync(path.join(output, "annotations", "registry.tsv"), "utf8"), "species_id\thuman\n");
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test("truncated archives fail validation", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-zip-test-"));
  const zipPath = path.join(root, "truncated.zip");
  try {
    fs.writeFileSync(zipPath, Buffer.from("PK\u0003\u0004broken"));
    await assert.rejects(validateZipArchive(zipPath));
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test("archives containing traversal entries are rejected before extraction", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-zip-test-"));
  const zipPath = path.join(root, "traversal.zip");
  try {
    await writeZip(zipPath, [["aa/escape", "blocked"]]);
    const archive = fs.readFileSync(zipPath);
    const safeName = Buffer.from("aa/escape");
    const unsafeName = Buffer.from("../escape");
    let replacements = 0;
    for (let offset = archive.indexOf(safeName); offset !== -1; offset = archive.indexOf(safeName, offset + unsafeName.length)) {
      unsafeName.copy(archive, offset);
      replacements += 1;
    }
    assert.equal(replacements, 2);
    fs.writeFileSync(zipPath, archive);
    await assert.rejects(validateZipArchive(zipPath), /invalid relative path|Unsafe ZIP entry/);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test("archives containing symbolic links are rejected", async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-zip-test-"));
  const zipPath = path.join(root, "symlink.zip");
  try {
    await writeSymlinkZip(zipPath);
    await assert.rejects(validateZipArchive(zipPath), /Symbolic link ZIP entry blocked/);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
