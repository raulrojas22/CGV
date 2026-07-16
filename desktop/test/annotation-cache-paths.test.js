const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const test = require("node:test");
const {
  normalizeAnnotationCacheDirectory,
  portableAnnotationCacheFilename
} = require("../src/annotation-cache-paths");

const annotationIdentity = "GCF_034140825.1_ASM3414082v1_genomic.gff.gz_13399176_1782392344_desc-clean-v2.rds";
const stagedPrefix = "dataset-packages_work_oryza_sativa_ssp_japonica_gcf_034140825_1_asm3414082v1_genomic_annotations_";

test("dataset cache names discard the build-machine staging path", () => {
  const original = `gene_light__desc-clean-v2__${stagedPrefix}${annotationIdentity}`;
  const portable = portableAnnotationCacheFilename(original);
  assert.equal(portable, `gene_light__portable__${annotationIdentity}`);
  assert.ok(portable.length < original.length);
  assert.doesNotMatch(portable, /dataset-packages_work/i);
});

test("canonical cache names already short enough stay unchanged", () => {
  const canonical = `gene_light__desc-clean-v2__annotations_${annotationIdentity}`;
  assert.equal(portableAnnotationCacheFilename(canonical), canonical);
});

test("existing long Windows caches are repaired in place", () => {
  const cacheDir = fs.mkdtempSync(path.join(os.tmpdir(), "cgv-cache-path-test-"));
  try {
    const original = `autocomplete__desc-clean-v2__${stagedPrefix}${annotationIdentity}`;
    fs.writeFileSync(path.join(cacheDir, original), "portable-cache-fixture");
    const result = normalizeAnnotationCacheDirectory(cacheDir);
    const portable = `autocomplete__portable__${annotationIdentity}`;
    assert.deepEqual(result, { compacted: 1, duplicatesRemoved: 0, unchanged: 0 });
    assert.equal(fs.readFileSync(path.join(cacheDir, portable), "utf8"), "portable-cache-fixture");
    assert.equal(fs.existsSync(path.join(cacheDir, original)), false);
  } finally {
    fs.rmSync(cacheDir, { recursive: true, force: true });
  }
});
