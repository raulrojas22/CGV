#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/cgv-static-publish.XXXXXX")"
cleanup() {
  chmod -R u+w "${TEST_ROOT}" 2>/dev/null || true
  rm -rf "${TEST_ROOT}"
}
trap cleanup EXIT

SOURCE_DIR="${TEST_ROOT}/www"
STATIC_ROOT="${TEST_ROOT}/cache/static_assets"
REV_A="$(printf 'a%.0s' {1..64})"
REV_B="$(printf 'b%.0s' {1..64})"
mkdir -p "${SOURCE_DIR}/js" "${SOURCE_DIR}/screencasts"
printf '%s\n' 'console.log("release-a");' > "${SOURCE_DIR}/js/version probe.js"
dd if=/dev/zero of="${SOURCE_DIR}/screencasts/guide-intro.mp4" bs=1024 count=2 2>/dev/null

publish() {
  CGV_STATIC_SOURCE_DIR="${SOURCE_DIR}" \
  CGV_STATIC_ROOT_DIR="${STATIC_ROOT}" \
  CGV_STATIC_REVISION="$1" \
    bash "${ROOT}/docker/publish-static-assets.sh"
}

publish "${REV_A}"
test -r "${STATIC_ROOT}/releases/${REV_A}/js/version probe.js"
test -s "${STATIC_ROOT}/manifests/${REV_A}.sha256"
test "$(find "${STATIC_ROOT}/releases/${REV_A}" -type f | wc -l | tr -d ' ')" = 2

# A second publication is a verified no-op, not an overwrite.
MANIFEST_BEFORE="$(cksum "${STATIC_ROOT}/manifests/${REV_A}.sha256")"
publish "${REV_A}"
test "${MANIFEST_BEFORE}" = "$(cksum "${STATIC_ROOT}/manifests/${REV_A}.sha256")"

# Reusing an image Id for different bytes must fail and preserve the release.
printf '%s\n' 'console.log("tampered");' > "${SOURCE_DIR}/js/version probe.js"
if publish "${REV_A}" >/dev/null 2>&1; then
  echo "ERROR: accepted different bytes for an existing revision" >&2
  exit 1
fi
grep -q 'release-a' "${STATIC_ROOT}/releases/${REV_A}/js/version probe.js"

# A different immutable revision coexists with the previous snapshot.
publish "${REV_B}"
grep -q 'release-a' "${STATIC_ROOT}/releases/${REV_A}/js/version probe.js"
grep -q 'tampered' "${STATIC_ROOT}/releases/${REV_B}/js/version probe.js"

if CGV_STATIC_SOURCE_DIR="${SOURCE_DIR}" \
   CGV_STATIC_ROOT_DIR="${STATIC_ROOT}" \
   CGV_STATIC_REVISION=bad \
   bash "${ROOT}/docker/publish-static-assets.sh" >/dev/null 2>&1; then
  echo "ERROR: accepted an invalid revision" >&2
  exit 1
fi

ln -s "${SOURCE_DIR}/js/version probe.js" "${SOURCE_DIR}/linked.js"
REV_C="$(printf 'c%.0s' {1..64})"
if publish "${REV_C}" >/dev/null 2>&1; then
  echo "ERROR: accepted a symbolic link in the public tree" >&2
  exit 1
fi
test ! -e "${STATIC_ROOT}/releases/${REV_C}"

echo "static snapshot publication: OK"
