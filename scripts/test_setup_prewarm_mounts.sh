#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_ROOT="$(mktemp -d)"
trap 'rm -rf "${FIXTURE_ROOT}"' EXIT

mkdir -p \
  "${FIXTURE_ROOT}/relative/annotations" \
  "${FIXTURE_ROOT}/relative/genomes" \
  "${FIXTURE_ROOT}/relative/go_annotations" \
  "${FIXTURE_ROOT}/relative/data" \
  "${FIXTURE_ROOT}/relative/cache"
printf 'species_id\nfixture_species\n' > "${FIXTURE_ROOT}/relative/annotations/registry.tsv"

cat > "${FIXTURE_ROOT}/fake-docker" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
  exit 0
fi
printf '%s\0' "$@" > "${PREWARM_DOCKER_ARGS_FILE}"
EOF
chmod +x "${FIXTURE_ROOT}/fake-docker"

PREWARM_DOCKER_ARGS_FILE="${FIXTURE_ROOT}/docker.args" \
CGV_IMAGE="sha256:fixture-image" \
CGV_ANNOTATIONS_DIR="${FIXTURE_ROOT}/relative/annotations" \
CGV_GENOMES_DIR="${FIXTURE_ROOT}/relative/genomes" \
CGV_GO_ANNOTATIONS_DIR="${FIXTURE_ROOT}/relative/go_annotations" \
CGV_DATA_DIR="${FIXTURE_ROOT}/relative/data" \
CGV_CACHE_DIR="${FIXTURE_ROOT}/relative/cache" \
DOCKER_BIN="${FIXTURE_ROOT}/fake-docker" \
bash "${REPO_ROOT}/docker/setup-prewarm.sh" >/dev/null

joined_args="$(tr '\0' '\n' < "${FIXTURE_ROOT}/docker.args")"

for expected in \
  "${FIXTURE_ROOT}/relative/annotations:/app/annotations" \
  "${FIXTURE_ROOT}/relative/genomes:/app/genomes" \
  "${FIXTURE_ROOT}/relative/go_annotations:/app/go_annotations" \
  "${FIXTURE_ROOT}/relative/data:/app/data" \
  "${FIXTURE_ROOT}/relative/cache:/app/cache" \
  "sha256:fixture-image"; do
  grep -Fxq "${expected}" <<< "${joined_args}" || {
    echo "missing prewarm argument: ${expected}" >&2
    exit 1
  }
done

grep -Fq "Rscript scripts/build_alias_index_sqlite.R --root=/app --all" <<< "${joined_args}"
grep -Fq "Rscript scripts/verify_preloaded_alias_indexes.R --root=/app" <<< "${joined_args}"
if grep -Fq "build_alias_index_sqlite.R --root=/app --all ||" <<< "${joined_args}"; then
  echo "alias index build errors must remain fatal" >&2
  exit 1
fi

echo "setup-prewarm mount forwarding tests passed"
