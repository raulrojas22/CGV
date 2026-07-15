#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${DESKTOP_DIR}/.." && pwd)"

REGISTRY="${PROJECT_ROOT}/annotations/registry.tsv"
VERSION="${1:-2026.09}"

if [[ ! -f "$REGISTRY" ]]; then
  echo "ERROR: Registry not found at ${REGISTRY}" >&2
  exit 1
fi

SPECIES_LIST=()
while IFS=$'\t' read -r species_id label organism taxid rest; do
  [[ "$species_id" == "species_id" ]] && continue
  SPECIES_LIST+=("$species_id")
done < "$REGISTRY"

TOTAL=${#SPECIES_LIST[@]}
echo "=== Generating ${TOTAL} dataset packages ==="
echo "=== Version: ${VERSION} ==="
echo ""

OK=0
FAIL=0

for i in "${!SPECIES_LIST[@]}"; do
  species="${SPECIES_LIST[$i]}"
  num=$((i + 1))
  echo "[${num}/${TOTAL}] Building package for: ${species}"

  package_id="$(printf '%s' "$species" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/_/g')"
  package_path="${DESKTOP_DIR}/dataset-packages/${package_id}-${VERSION}.zip"
  manifest_path="${DESKTOP_DIR}/dataset-packages/${package_id}.manifest.json"

  if (cd "$DESKTOP_DIR" &&
      node scripts/build-dataset-package.js --species="$species" --version="$VERSION" 2>&1 | tail -5) &&
      node "${DESKTOP_DIR}/scripts/verify-dataset-package.js" \
        --package="$package_path" \
        --manifest="$manifest_path"; then
    OK=$((OK + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  FAILED: ${species}"
  fi
  echo ""
done

echo "============================================================"
echo "Done! Generated: ${OK}, Failed: ${FAIL}"
echo "============================================================"
echo ""
echo "Packages are in: ${DESKTOP_DIR}/dataset-packages/"
echo ""
echo "Next step: build and inspect the ${VERSION} catalog, upload the new ZIP files"
echo "to Oracle Object Storage, and publish catalog.json last."
echo "  cd ${DESKTOP_DIR}"
echo "  CGV_DATASET_CATALOG_VERSION=${VERSION} npm run dataset:catalog"
