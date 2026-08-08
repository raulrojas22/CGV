#!/usr/bin/env bash
# Collect existing NAS/ShinyProxy diagnostics after a manual performance run.
# This script does not start containers, deploy code, or execute application tests.
set -euo pipefail

RUN_LABEL="${1:-antes_nas_01}"
NAS_USER="${NAS_USER:-truenas_admin}"
NAS_HOST="${NAS_HOST:-192.168.1.200}"
NAS_PATH="${NAS_PATH:-/mnt/Datos4raro/cgv}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
DEST_DIR="${PROJECT_ROOT}/perf_logs_recibidos/${RUN_LABEL}"
REMOTE_TARGET="${NAS_USER}@${NAS_HOST}"

if ! [[ "${RUN_LABEL}" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "ERROR: la etiqueta solo puede contener letras, numeros, punto, guion y guion bajo." >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"

remote_read() {
  ssh "${REMOTE_TARGET}" "$@"
}

if [[ -n "${REMOTE_DOCKER:-}" ]]; then
  DOCKER_CMD="${REMOTE_DOCKER}"
elif remote_read "docker info >/dev/null 2>&1"; then
  DOCKER_CMD="docker"
else
  DOCKER_CMD="sudo docker"
fi

capture_remote() {
  local output_file="$1"
  shift
  if ! remote_read "$@" > "${output_file}" 2>&1; then
    printf '\n[collector] command failed or evidence unavailable\n' >> "${output_file}"
  fi
}

{
  echo "run_label=${RUN_LABEL}"
  echo "collected_local=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "remote=${REMOTE_TARGET}"
  echo "nas_path=${NAS_PATH}"
  echo "docker_command=${DOCKER_CMD}"
} > "${DEST_DIR}/collection_meta.txt"

REMOTE_PERF_DIR="${NAS_PATH}/app/cache/perf_runs/${RUN_LABEL}"
if remote_read "test -d '${REMOTE_PERF_DIR}'"; then
  rsync -az "${REMOTE_TARGET}:${REMOTE_PERF_DIR}/" "${DEST_DIR}/"
else
  echo "No existe ${REMOTE_PERF_DIR} en el NAS." > "${DEST_DIR}/perf_directory_missing.txt"
fi

capture_remote "${DEST_DIR}/perf_files_found.txt" \
  "find '${NAS_PATH}' -path '*/perf_runs/*' -type f -print 2>/dev/null | sort"
capture_remote "${DEST_DIR}/host_memory.txt" \
  "date -u; uptime; free -h 2>/dev/null || true"
capture_remote "${DEST_DIR}/docker_ps.txt" \
  "${DOCKER_CMD} ps -a --no-trunc"
capture_remote "${DEST_DIR}/docker_stats.txt" \
  "${DOCKER_CMD} stats --no-stream"
capture_remote "${DEST_DIR}/docker_events_2h.txt" \
  "${DOCKER_CMD} events --since 2h --until \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
capture_remote "${DEST_DIR}/kernel_oom_2h.txt" \
  "journalctl -k --since '2 hours ago' --no-pager 2>&1 | grep -Ei 'oom|out of memory|killed process' || true"

capture_remote "${DEST_DIR}/shinyproxy_state.txt" \
  "${DOCKER_CMD} inspect --format 'name={{.Name}} image={{.Config.Image}} status={{.State.Status}} oom={{.State.OOMKilled}} exit={{.State.ExitCode}} error={{.State.Error}} started={{.State.StartedAt}} finished={{.State.FinishedAt}}' cgv-shinyproxy"
capture_remote "${DEST_DIR}/shinyproxy.log" \
  "${DOCKER_CMD} logs --timestamps cgv-shinyproxy"

SESSION_IDS="$(remote_read "${DOCKER_CMD} ps -aq --filter name=sp-container-" 2>/dev/null || true)"
if [[ -z "${SESSION_IDS}" ]]; then
  echo "No quedaron contenedores sp-container-* disponibles para inspeccion." \
    > "${DEST_DIR}/session_containers_missing.txt"
else
  while IFS= read -r container_id; do
    [[ -n "${container_id}" ]] || continue
    container_name="$(remote_read "${DOCKER_CMD} inspect --format '{{.Name}}' '${container_id}'" 2>/dev/null || true)"
    container_name="${container_name#/}"
    container_name="${container_name//[^A-Za-z0-9._-]/_}"
    [[ -n "${container_name}" ]] || container_name="${container_id}"

    capture_remote "${DEST_DIR}/${container_name}_state.txt" \
      "${DOCKER_CMD} inspect --format 'name={{.Name}} image={{.Config.Image}} status={{.State.Status}} oom={{.State.OOMKilled}} exit={{.State.ExitCode}} error={{.State.Error}} started={{.State.StartedAt}} finished={{.State.FinishedAt}}' '${container_id}'"
    capture_remote "${DEST_DIR}/${container_name}_perf_env.txt" \
      "${DOCKER_CMD} inspect --format '{{range .Config.Env}}{{println .}}{{end}}' '${container_id}' | grep -E '^(APP_PERF_|APP_FUTURE_|APP_LASTZ_|APP_GFF_|APP_BUILD_REVISION=)' || true"
    capture_remote "${DEST_DIR}/${container_name}.log" \
      "${DOCKER_CMD} logs --timestamps '${container_id}'"
  done <<< "${SESSION_IDS}"
fi

echo "Logs recopilados en: ${DEST_DIR}"

