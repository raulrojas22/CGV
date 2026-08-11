#!/usr/bin/env bash
# Safe application-only deployment for CGV on Colors.
#
# This script preserves ShinyProxy, nginx, the socket proxy, their Compose file,
# and persistent biological data. It builds a versioned CGV image, adds only
# allow-listed runtime flags to the backed-up ShinyProxy config, and switches
# the already-hardened stack to the new release.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_TARGET="${REMOTE_TARGET:-colors}"
REMOTE_PATH="${REMOTE_PATH:-/home/rarojas/cgv}"
APP_DIR="${REMOTE_PATH}/app"
PUBLIC_HOSTNAME="${PUBLIC_HOSTNAME:-cgv.mobilomics.org}"
COMPOSE_FILE="${APP_DIR}/docker-compose.shinyproxy.colors.yml"
BACKGROUND_WORKER_NAME="cgv-background-report-worker"
BACKGROUND_REPORT_MEMORY="${BACKGROUND_REPORT_MEMORY:-4g}"
APP_LASTZ_GLOBAL_WORKERS="${APP_LASTZ_GLOBAL_WORKERS:-2}"
COLORS_INLINE_FAST_SEQUENCE_PREFETCH="${COLORS_INLINE_FAST_SEQUENCE_PREFETCH:-1}"
COLORS_HOMO_DEFER_SEQUENCE="${COLORS_HOMO_DEFER_SEQUENCE:-0}"
COLORS_DEFER_FEATURE_GC="${COLORS_DEFER_FEATURE_GC:-0}"
LOCAL_EMAIL_ENV="${SCRIPT_DIR}/.env.local"
REMOTE_EMAIL_ENV="${APP_DIR}/.env.background-reports"
EMAIL_ENV_STAGING=""
CGV_DEPS_IMAGE="${CGV_DEPS_IMAGE:-cgv-deps:1.0.0}"
SHINYPROXY_IMAGE="${SHINYPROXY_IMAGE:-docker.io/openanalytics/shinyproxy:3.2.4@sha256:281dfddd3c8c54ea2dfa74390480d0f7769b53fd0bbef6d57f272574fd10fa3c}"
SHINYPROXY_DIGEST="${SHINYPROXY_IMAGE##*@}"
SHINYPROXY_RUNTIME_IMAGE="docker.io/openanalytics/shinyproxy@${SHINYPROXY_DIGEST}"
REBUILD_R_DEPS="${REBUILD_R_DEPS:-0}"
PERF_RUN_LABEL="${PERF_RUN_LABEL:-manual}"
MODE="deploy"
SKIP_TESTS=0
SSH_SOCK="/tmp/cgv-colors-deploy-$$.sock"

usage() {
  cat <<'USAGE'
Uso:
  ./deploy-colors-shinyproxy.sh [--check] [--skip-tests]

Opciones:
  --check       Audita Git y la infraestructura remota sin cambiar Colors.
  --skip-tests  Omite las pruebas R. Úsalo sólo ante una emergencia conocida.
  -h, --help    Muestra esta ayuda.

Variables opcionales:
  REMOTE_TARGET=colors
  REMOTE_PATH=/home/rarojas/cgv
  CGV_DEPS_IMAGE=cgv-deps:1.0.0
  REBUILD_R_DEPS=1   Reconstruye explícitamente la base de dependencias R.
  BACKGROUND_REPORT_MEMORY=4g
  APP_LASTZ_GLOBAL_WORKERS=2
  COLORS_INLINE_FAST_SEQUENCE_PREFETCH=1
  COLORS_HOMO_DEFER_SEQUENCE=0
  COLORS_DEFER_FEATURE_GC=0
  PERF_RUN_LABEL=antes_colors_01

El deploy normal exige que Git esté limpio y crea una imagen inmutable con
la forma localhost/cgv:release-<commit>-<fecha UTC>.
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

for arg in "$@"; do
  case "$arg" in
    --check) MODE="check" ;;
    --skip-tests) SKIP_TESTS=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "opción desconocida: ${arg}" ;;
  esac
done

[[ "$REBUILD_R_DEPS" == "0" || "$REBUILD_R_DEPS" == "1" ]] || \
  die "REBUILD_R_DEPS debe ser 0 o 1"
for tuning_value in \
  "$COLORS_INLINE_FAST_SEQUENCE_PREFETCH" \
  "$COLORS_HOMO_DEFER_SEQUENCE" \
  "$COLORS_DEFER_FEATURE_GC"; do
  [[ "$tuning_value" == "0" || "$tuning_value" == "1" ]] || \
    die "Los flags de first-paint de Colors deben ser 0 o 1"
done
[[ "$PERF_RUN_LABEL" =~ ^[A-Za-z0-9._-]+$ ]] || \
  die "PERF_RUN_LABEL solo puede contener letras, numeros, punto, guion y guion bajo"
[[ "$BACKGROUND_REPORT_MEMORY" =~ ^[1-9][0-9]*[mMgG]$ ]] || \
  die "BACKGROUND_REPORT_MEMORY debe usar un valor como 2048m o 4g"
[[ "$APP_LASTZ_GLOBAL_WORKERS" =~ ^[1-9][0-9]*$ ]] && \
  (( APP_LASTZ_GLOBAL_WORKERS <= 16 )) || \
  die "APP_LASTZ_GLOBAL_WORKERS debe ser un entero entre 1 y 16"
[[ "$PUBLIC_HOSTNAME" =~ ^[A-Za-z0-9.-]+$ ]] || \
  die "PUBLIC_HOSTNAME no es válido"

for command_name in curl git ssh rsync shasum; do
  command -v "$command_name" >/dev/null 2>&1 || die "falta el comando local '${command_name}'"
done

[[ -f "$LOCAL_EMAIL_ENV" ]] || \
  die "falta ${LOCAL_EMAIL_ENV}; se necesita para enviar reportes desde Colors"
for email_key in FEEDBACK_RESEND_API_KEY FEEDBACK_TO_EMAIL FEEDBACK_FROM_EMAIL; do
  grep -Eq "^${email_key}=.+$" "$LOCAL_EMAIL_ENV" || \
    die "falta ${email_key} en ${LOCAL_EMAIL_ENV}"
done

git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
  die "${SCRIPT_DIR} no es un repositorio Git"

SOURCE_REV="$(git -C "$SCRIPT_DIR" rev-parse --short=12 HEAD)"
SOURCE_BRANCH="$(git -C "$SCRIPT_DIR" branch --show-current)"
SOURCE_BRANCH="${SOURCE_BRANCH:-detached}"
DEPLOY_CHANGES="$(
  git -C "$SCRIPT_DIR" status --porcelain=v1 --untracked-files=all |
    grep -vE '^\?\? \.codex_work/' || true
)"

if [[ -n "$DEPLOY_CHANGES" ]]; then
  if [[ "$MODE" == "deploy" ]]; then
    echo "El árbol de trabajo contiene cambios no confirmados:" >&2
    printf '%s\n' "$DEPLOY_CHANGES" >&2
    die "haz commit de los cambios que deseas publicar antes del deploy"
  fi
  echo "AVISO: Git no está limpio; --check continuará sin desplegar."
fi

cleanup() {
  ssh -S "$SSH_SOCK" -O exit "$REMOTE_TARGET" >/dev/null 2>&1 || true
  rm -f "$SSH_SOCK"
  if [[ -n "$EMAIL_ENV_STAGING" ]]; then
    rm -f "$EMAIL_ENV_STAGING"
  fi
}
trap cleanup EXIT

rssh() {
  ssh -o BatchMode=yes -S "$SSH_SOCK" "$REMOTE_TARGET" "$@"
}

echo "============================================"
echo "  CGV Colors — deploy seguro de aplicación"
echo "  Modo:       ${MODE}"
echo "  Fuente:     ${SOURCE_BRANCH}@${SOURCE_REV}"
echo "  Destino:    ${REMOTE_TARGET}:${APP_DIR}"
echo "  URL:        https://${PUBLIC_HOSTNAME}"
echo "  Captura:    ${PERF_RUN_LABEL}"
echo "============================================"
echo ""

ssh -o BatchMode=yes -o ConnectTimeout=10 -o ControlMaster=yes \
  -o ControlPersist=60 -S "$SSH_SOCK" -fN "$REMOTE_TARGET"

echo "[preflight] Auditando infraestructura segura en Colors..."
rssh "command -v podman >/dev/null && command -v podman-compose >/dev/null"
rssh "podman info >/dev/null"
rssh "test -s '${COMPOSE_FILE}' && test -s '${APP_DIR}/shinyproxy/application.yml' && test -s '${APP_DIR}/.env'"
rssh "grep -q 'docker-socket-proxy' '${COMPOSE_FILE}'"
rssh "grep -q 'openanalytics/shinyproxy:3.2.4' '${COMPOSE_FILE}'"
rssh "grep -q 'url: http://docker-socket-proxy:2375' '${APP_DIR}/shinyproxy/application.yml'"
rssh "podman container exists cgv-docker-socket-proxy && podman container exists cgv-shinyproxy && podman container exists cgv-nginx"

ACTUAL_SP_IMAGE="$(rssh "podman inspect cgv-shinyproxy --format '{{.ImageName}}'")"
[[ "$ACTUAL_SP_IMAGE" == "$SHINYPROXY_IMAGE" || "$ACTUAL_SP_IMAGE" == "$SHINYPROXY_RUNTIME_IMAGE" ]] || \
  die "Colors usa '${ACTUAL_SP_IMAGE}', no el ShinyProxy 3.2.4 fijado"

PROXY_MOUNTS="$(rssh "podman inspect cgv-shinyproxy --format '{{range .Mounts}}{{println .Destination}}{{end}}'")"
if grep -qx '/var/run/docker.sock' <<<"$PROXY_MOUNTS"; then
  die "ShinyProxy monta directamente el socket; se aborta antes de tocar producción"
fi

SOCKET_STATE="$(rssh "podman inspect cgv-docker-socket-proxy --format '{{.State.Health.Status}}'")"
[[ "$SOCKET_STATE" == "healthy" ]] || die "docker-socket-proxy no está saludable: ${SOCKET_STATE}"

CONTROL_INTERNAL="$(rssh "podman network inspect sp-control --format '{{.Internal}}'")"
[[ "$CONTROL_INTERNAL" == "true" ]] || die "la red sp-control no está marcada como interna"

CURRENT_IMAGE="$(
  rssh "podman inspect cgv-shinyproxy --format '{{range .Config.Env}}{{println .}}{{end}}'" |
    sed -n 's/^CGV_IMAGE=//p' | tail -1
)"
[[ "$CURRENT_IMAGE" == localhost/cgv:release-* ]] || \
  die "la imagen activa no es una release versionada: '${CURRENT_IMAGE:-vacía}'"
rssh "podman image exists '${CURRENT_IMAGE}'"
ENV_IMAGE="$(rssh "sed -n 's/^CGV_IMAGE=//p' '${APP_DIR}/.env' | tail -1")"
[[ "$ENV_IMAGE" == "$CURRENT_IMAGE" ]] || \
  die "la imagen de .env (${ENV_IMAGE:-vacía}) no coincide con la imagen activa (${CURRENT_IMAGE})"
rssh "for d in annotations genomes go_annotations data cache; do test -d '${APP_DIR}'/\"\$d\" || exit 1; done; test -s '${APP_DIR}/annotations/registry.tsv'"

read -r PROXY_CODE NGINX_CODE < <(
  rssh "python3 - <<'PY'
import http.client
codes=[]
for port in (18081, 3838):
    try:
        c=http.client.HTTPConnection('127.0.0.1', port, timeout=8)
        c.request('HEAD', '/')
        codes.append(str(c.getresponse().status))
        c.close()
    except Exception:
        codes.append('000')
print(' '.join(codes))
PY"
)
[[ "$PROXY_CODE" =~ ^[23][0-9][0-9]$ ]] || die "ShinyProxy no responde correctamente: HTTP ${PROXY_CODE}"
[[ "$NGINX_CODE" =~ ^[23][0-9][0-9]$ ]] || die "nginx no responde correctamente: HTTP ${NGINX_CODE}"

echo "  ShinyProxy: 3.2.4 fijado"
echo "  Socket API: ${SOCKET_STATE}, aislado en sp-control"
echo "  Imagen CGV activa: ${CURRENT_IMAGE}"
echo "  HTTP interno: proxy=${PROXY_CODE}, nginx=${NGINX_CODE}"

if [[ "$MODE" == "check" ]]; then
  WORKER_STATE="$(rssh "podman inspect '${BACKGROUND_WORKER_NAME}' --format '{{.State.Status}}' 2>/dev/null || true")"
  WORKER_IMAGE="$(rssh "podman inspect '${BACKGROUND_WORKER_NAME}' --format '{{.ImageName}}' 2>/dev/null || true")"
  [[ "$WORKER_STATE" == "running" ]] || die "el worker de reportes no está activo: ${WORKER_STATE:-ausente}"
  [[ "$WORKER_IMAGE" == "$CURRENT_IMAGE" ]] || die "el worker usa ${WORKER_IMAGE:-ninguna}, no ${CURRENT_IMAGE}"
  rssh "podman exec '${BACKGROUND_WORKER_NAME}' test -s /app/cache/background_reports/worker.ready" || \
    die "el worker no completó el preflight headless; los reportes por correo fallarán"
  rssh "podman exec '${BACKGROUND_WORKER_NAME}' grep -q '^browser=Chrome/' /app/cache/background_reports/worker.ready" || \
    die "el worker no registró un arranque headless correcto en su marcador"
  echo "  Worker:     ${WORKER_STATE}, preflight headless OK"
  echo ""
  echo "CHECK OK: no se realizaron cambios en Colors."
  exit 0
fi

if [[ "$SKIP_TESTS" == "0" ]]; then
  command -v Rscript >/dev/null 2>&1 || die "Rscript no está disponible para ejecutar las pruebas"
  echo ""
  echo "[1/7] Validando sintaxis y pruebas R..."
  (
    cd "$SCRIPT_DIR"
    Rscript -e "invisible(parse(file='global.R')); invisible(parse(file='ui.R')); invisible(parse(file='server.R'))"
    Rscript -e "if (!requireNamespace('testthat', quietly=TRUE)) stop('testthat no está instalado'); testthat::test_dir('tests/testthat', reporter='summary')"
    Rscript scripts/test_background_report_jobs.R
  )
else
  echo ""
  echo "[1/7] Pruebas omitidas explícitamente con --skip-tests."
fi

DEPLOY_UTC="$(date -u +%Y%m%dT%H%M%SZ)"
NEW_IMAGE="${CGV_IMAGE:-localhost/cgv:release-${SOURCE_REV}-${DEPLOY_UTC}}"
[[ "$NEW_IMAGE" == localhost/cgv:release-* ]] || \
  die "CGV_IMAGE debe usar una etiqueta versionada localhost/cgv:release-*"
[[ "$NEW_IMAGE" != "$CURRENT_IMAGE" ]] || die "la nueva imagen coincide con la release activa"
BACKUP_DIR="${REMOTE_PATH}/rollback/${DEPLOY_UTC}-pre-app-deploy"

echo ""
echo "[2/7] Respaldando configuración y estado actual..."
rssh "set -e
  mkdir -p '${BACKUP_DIR}'
  cp -p '${APP_DIR}/.env' '${BACKUP_DIR}/app.env'
  cp -p '${COMPOSE_FILE}' '${BACKUP_DIR}/docker-compose.shinyproxy.colors.yml'
  cp -p '${APP_DIR}/shinyproxy/application.yml' '${BACKUP_DIR}/application.yml'
  cp -p '${APP_DIR}/deploy/nginx/cgv-shinyproxy-colors.conf' '${BACKUP_DIR}/cgv-shinyproxy-colors.conf'
  if [ -f '${REMOTE_EMAIL_ENV}' ]; then
    cp -p '${REMOTE_EMAIL_ENV}' '${BACKUP_DIR}/background-report-email.env'
  else
    : > '${BACKUP_DIR}/background-report-email.absent'
  fi
  podman inspect cgv-docker-socket-proxy cgv-shinyproxy cgv-nginx > '${BACKUP_DIR}/infrastructure.inspect.json'
  if podman container exists '${BACKGROUND_WORKER_NAME}'; then
    podman inspect '${BACKGROUND_WORKER_NAME}' > '${BACKUP_DIR}/background-worker.inspect.json'
  fi
  podman ps -a --no-trunc > '${BACKUP_DIR}/podman-ps.txt'
"

echo ""
echo "[3/7] Sincronizando sólo el código de aplicación..."
rsync -az --delete-delay --itemize-changes \
  -e "ssh -S $SSH_SOCK" \
  --exclude='/.git' \
  --exclude='/.env' --exclude='/.env.local' --exclude='/.env.background-reports' --exclude='/.Renviron' \
  --exclude='/.codex_work' --exclude='/.codex_backups' --exclude='/.claude' --exclude='/.qodo' \
  --exclude='/.Rproj.user' --exclude='/.Rhistory' --exclude='/.Rapp.history' \
  --exclude='/annotations' --exclude='/genomes' --exclude='/go_annotations' \
  --exclude='/data' --exclude='/cache' --exclude='/ncbi_downloads' \
  --exclude='/build_sources' --exclude='/outputs' --exclude='/logs' --exclude='/tmp' \
  --exclude='/desktop' --exclude='/INSTALABLES-FINALES' \
  --exclude='/node_modules' --exclude='/paper' \
  --exclude='/deploy-colors-shinyproxy.sh' \
  --exclude='/docker-compose.shinyproxy.yml' \
  --exclude='/docker-compose.shinyproxy.colors.yml' \
  --exclude='/shinyproxy/application.yml' \
  --exclude='/deploy/nginx/cgv-shinyproxy.conf' \
  --exclude='/deploy/nginx/cgv-shinyproxy-colors.conf' \
  "${SCRIPT_DIR}/" "${REMOTE_TARGET}:${APP_DIR}/"

# Copy only the allow-listed mail variables. The minimal file is never tracked,
# is mode 0600 on Colors, and is mounted only into the background worker.
EMAIL_ENV_STAGING="$(mktemp "${TMPDIR:-/tmp}/cgv-colors-report-email.XXXXXX")"
awk '
  BEGIN { single_quote = sprintf("%c", 39) }
  /^(FEEDBACK_RESEND_API_KEY|FEEDBACK_TO_EMAIL|FEEDBACK_FROM_EMAIL|REPORT_FROM_EMAIL|REPORT_REPLY_TO_EMAIL|REPORT_LOGO_PATH)=/ {
    separator = index($0, "=")
    key = substr($0, 1, separator - 1)
    value = substr($0, separator + 1)
    first = substr(value, 1, 1)
    last = substr(value, length(value), 1)
    if (length(value) >= 2 && ((first == "\"" && last == "\"") || (first == single_quote && last == single_quote))) {
      value = substr(value, 2, length(value) - 2)
    }
    print key "=" value
  }
' "$LOCAL_EMAIL_ENV" > "$EMAIL_ENV_STAGING"
chmod 600 "$EMAIL_ENV_STAGING"
rsync -az --chmod=Fu=rw,Fgo= \
  -e "ssh -S $SSH_SOCK" \
  "$EMAIL_ENV_STAGING" "${REMOTE_TARGET}:${REMOTE_EMAIL_ENV}"
rssh "chmod 600 '${REMOTE_EMAIL_ENV}' && test \"\$(stat -c '%a' '${REMOTE_EMAIL_ENV}')\" = 600"

# Colors keeps its hardened ShinyProxy configuration on the server. Add only
# the allow-listed flags required by background reports and manual performance
# capture; the complete file was backed up above and is restored verbatim by
# rollback_release().
rssh "set -e
  config='${APP_DIR}/shinyproxy/application.yml'
  if ! grep -q 'APP_BACKGROUND_REPORTS_ENABLED:' \"\$config\"; then
    staged=\"\${config}.background.\$\$\"
    awk '
      { print }
      /APP_PERF_TIMING:/ {
        print \"        APP_BACKGROUND_REPORTS_ENABLED: \\\"\${SP_BACKGROUND_REPORTS_ENABLED:1}\\\"\"
        print \"        APP_LASTZ_GLOBAL_WORKERS: \\\"\${SP_LASTZ_GLOBAL_WORKERS:1}\\\"\"
        print \"        APP_LASTZ_GLOBAL_QUEUE_WAIT_SECONDS: \\\"\${SP_LASTZ_GLOBAL_QUEUE_WAIT_SECONDS:1800}\\\"\"
      }
    ' \"\$config\" > \"\$staged\"
    chmod --reference=\"\$config\" \"\$staged\"
    mv \"\$staged\" \"\$config\"
  fi
  if ! grep -q 'APP_PERF_LOG_DIR:' \"\$config\"; then
    staged=\"\${config}.perf.\$\$\"
    awk '
      { print }
      /APP_PERF_TIMING:/ {
        print \"        APP_PERF_LOG_DIR: \\\"/app/cache/perf_runs\\\"\"
        print \"        APP_PERF_RUN_LABEL: \\\"manual\\\"\"
        print \"        APP_BUILD_REVISION: \\\"unknown\\\"\"
      }
    ' \"\$config\" > \"\$staged\"
    chmod --reference=\"\$config\" \"\$staged\"
    mv \"\$staged\" \"\$config\"
  fi
  if ! grep -q 'APP_PERF_RUN_LABEL:' \"\$config\"; then
    sed -i '/APP_PERF_LOG_DIR:/a\        APP_PERF_RUN_LABEL: \"manual\"' \"\$config\"
  fi
  if ! grep -q 'APP_BUILD_REVISION:' \"\$config\"; then
    sed -i '/APP_PERF_RUN_LABEL:/a\        APP_BUILD_REVISION: \"unknown\"' \"\$config\"
  fi
  sed -i -E 's|^        APP_PERF_TIMING:.*|        APP_PERF_TIMING: \"1\"|' \"\$config\"
  sed -i -E 's|^        APP_PERF_RUN_LABEL:.*|        APP_PERF_RUN_LABEL: \"${PERF_RUN_LABEL}\"|' \"\$config\"
  sed -i -E 's|^        APP_BUILD_REVISION:.*|        APP_BUILD_REVISION: \"${NEW_IMAGE}\"|' \"\$config\"
  grep -q 'APP_BACKGROUND_REPORTS_ENABLED: \"\${SP_BACKGROUND_REPORTS_ENABLED:1}\"' \"\$config\"
  grep -q 'APP_LASTZ_GLOBAL_WORKERS:' \"\$config\"
  grep -q 'APP_PERF_TIMING: \"1\"' \"\$config\"
  grep -q 'APP_PERF_LOG_DIR: \"/app/cache/perf_runs\"' \"\$config\"
  grep -q 'APP_PERF_RUN_LABEL: \"${PERF_RUN_LABEL}\"' \"\$config\"
  grep -q 'APP_BUILD_REVISION: \"${NEW_IMAGE}\"' \"\$config\"
  grep -q 'CGV_PUBLIC_BASE_URL: \"https://${PUBLIC_HOSTNAME}\"' \"\$config\"
"

rssh "set -e
  config='${APP_DIR}/shinyproxy/application.yml'
  if grep -q '^        APP_INLINE_FAST_SEQUENCE_PREFETCH:' \"\$config\"; then
    sed -i -E 's|^        APP_INLINE_FAST_SEQUENCE_PREFETCH:.*|        APP_INLINE_FAST_SEQUENCE_PREFETCH: \"\${SP_INLINE_FAST_SEQUENCE_PREFETCH:${COLORS_INLINE_FAST_SEQUENCE_PREFETCH}}\"|' \"\$config\"
  else
    sed -i '/APP_PERF_TIMING:/a\        APP_INLINE_FAST_SEQUENCE_PREFETCH: \"\${SP_INLINE_FAST_SEQUENCE_PREFETCH:${COLORS_INLINE_FAST_SEQUENCE_PREFETCH}}\"' \"\$config\"
  fi
  if grep -q '^        APP_HOMO_DEFER_SEQUENCE:' \"\$config\"; then
    sed -i -E 's|^        APP_HOMO_DEFER_SEQUENCE:.*|        APP_HOMO_DEFER_SEQUENCE: \"\${SP_HOMO_DEFER_SEQUENCE:${COLORS_HOMO_DEFER_SEQUENCE}}\"|' \"\$config\"
  else
    sed -i '/APP_INLINE_FAST_SEQUENCE_PREFETCH:/a\        APP_HOMO_DEFER_SEQUENCE: \"\${SP_HOMO_DEFER_SEQUENCE:${COLORS_HOMO_DEFER_SEQUENCE}}\"' \"\$config\"
  fi
  if grep -q '^        APP_DEFER_FEATURE_GC:' \"\$config\"; then
    sed -i -E 's|^        APP_DEFER_FEATURE_GC:.*|        APP_DEFER_FEATURE_GC: \"\${SP_DEFER_FEATURE_GC:${COLORS_DEFER_FEATURE_GC}}\"|' \"\$config\"
  else
    sed -i '/APP_HOMO_DEFER_SEQUENCE:/a\        APP_DEFER_FEATURE_GC: \"\${SP_DEFER_FEATURE_GC:${COLORS_DEFER_FEATURE_GC}}\"' \"\$config\"
  fi
  grep -q 'APP_INLINE_FAST_SEQUENCE_PREFETCH: \"\${SP_INLINE_FAST_SEQUENCE_PREFETCH:${COLORS_INLINE_FAST_SEQUENCE_PREFETCH}}\"' \"\$config\"
  grep -q 'APP_HOMO_DEFER_SEQUENCE: \"\${SP_HOMO_DEFER_SEQUENCE:${COLORS_HOMO_DEFER_SEQUENCE}}\"' \"\$config\"
  grep -q 'APP_DEFER_FEATURE_GC: \"\${SP_DEFER_FEATURE_GC:${COLORS_DEFER_FEATURE_GC}}\"' \"\$config\"
"

rssh "set -e
  config='${APP_DIR}/shinyproxy/application.yml'
  sed -i -E 's|^        APP_LASTZ_GLOBAL_WORKERS:.*|        APP_LASTZ_GLOBAL_WORKERS: \"\${SP_LASTZ_GLOBAL_WORKERS:${APP_LASTZ_GLOBAL_WORKERS}}\"|' \"\$config\"
  grep -q 'APP_LASTZ_GLOBAL_WORKERS: \"\${SP_LASTZ_GLOBAL_WORKERS:${APP_LASTZ_GLOBAL_WORKERS}}\"' \"\$config\"
"

echo ""
echo "[4/7] Construyendo imagen inmutable ${NEW_IMAGE}..."
DEPS_HAVE_REPORT_RUNTIME=0
if rssh "podman image exists '${CGV_DEPS_IMAGE}' && podman run --rm --entrypoint /usr/bin/google-chrome '${CGV_DEPS_IMAGE}' --version >/dev/null && podman run --rm --entrypoint Rscript '${CGV_DEPS_IMAGE}' -e \"quit(status=if(requireNamespace('chromote', quietly=TRUE)) 0 else 1)\" >/dev/null"; then
  DEPS_HAVE_REPORT_RUNTIME=1
fi
if [[ "$REBUILD_R_DEPS" == "1" || "$DEPS_HAVE_REPORT_RUNTIME" == "0" ]]; then
  if [[ "$DEPS_HAVE_REPORT_RUNTIME" == "0" ]]; then
    echo "  La base no contiene Google Chrome/chromote; se reconstruirá automáticamente."
  fi
  rssh "cd '${APP_DIR}' && podman build --pull=never -t '${CGV_DEPS_IMAGE}' -f Dockerfile.dependencies ."
else
  echo "  Google Chrome y chromote ya están disponibles en ${CGV_DEPS_IMAGE}."
fi
rssh "podman run --rm --entrypoint /usr/bin/google-chrome '${CGV_DEPS_IMAGE}' --version >/dev/null"
rssh "cd '${APP_DIR}' && podman build --pull=never \
  --build-arg CGV_DEPS_IMAGE='${CGV_DEPS_IMAGE}' \
  --label org.opencontainers.image.revision='${SOURCE_REV}' \
  --label org.opencontainers.image.created='${DEPLOY_UTC}' \
  -t '${NEW_IMAGE}' -f Dockerfile ."

LOCAL_HASHES="$(
  cd "$SCRIPT_DIR"
  shasum -a 256 \
    ui.R server.R global.R \
    R/background_report_jobs.R scripts/background_report_worker.R scripts/verify_headless_chrome.R \
    www/js/reproducible_report.js \
    www/home_preview_cgv.html www/css/cgv_compiled.css |
    awk '{print $1}' | paste -sd: -
)"
REMOTE_HASHES="$(
  rssh "podman run --rm --user 10001:10001 --entrypoint sha256sum '${NEW_IMAGE}' \
    /app/ui.R /app/server.R /app/global.R \
    /app/R/background_report_jobs.R /app/scripts/background_report_worker.R /app/scripts/verify_headless_chrome.R \
    /app/www/js/reproducible_report.js \
    /app/www/home_preview_cgv.html /app/www/css/cgv_compiled.css" |
    awk '{print $1}' | paste -sd: -
)"
[[ "$LOCAL_HASHES" == "$REMOTE_HASHES" ]] || die "los hashes de la imagen no coinciden con el commit local"
echo "  Hashes app/worker/reporte/home/CSS y lectura con UID 10001: OK"

echo ""
echo "[5/7] Precalentando índices y preparando permisos persistentes..."
rssh "set -e
  cd '${APP_DIR}'
  DOCKER_BIN=podman CGV_IMAGE='${NEW_IMAGE}' bash docker/setup-prewarm.sh
  cache_dir=\$(readlink -f '${APP_DIR}/cache')
  ncbi_dir=\$(readlink -f '${REMOTE_PATH}/ncbi_downloads')
  mkdir -p \"\$cache_dir\" \"\$ncbi_dir\"
  podman unshare chown -R 10001:10001 \"\$cache_dir\" \"\$ncbi_dir\"
"

teardown_stack_command="
  podman rm -f ${BACKGROUND_WORKER_NAME} >/dev/null 2>&1 || true
  podman stop cgv-shinyproxy >/dev/null 2>&1 || true
  session_ids=\$(podman ps -aq --filter name=sp-container- 2>/dev/null || true)
  if [ -n \"\$session_ids\" ]; then podman rm -f \$session_ids >/dev/null; fi
  podman pod rm -f pod_app >/dev/null 2>&1 || true
  podman rm -f cgv-shinyproxy cgv-nginx cgv-docker-socket-proxy >/dev/null 2>&1 || true
  podman network rm sp-control >/dev/null 2>&1 || true
  podman network rm sp-net >/dev/null 2>&1 || true
"

start_background_worker() {
  local expected_image="$1"
  rssh "set -e
    podman rm -f '${BACKGROUND_WORKER_NAME}' >/dev/null 2>&1 || true
    rm -f '${APP_DIR}/cache/background_reports/worker.ready'
    podman run -d \\
      --name '${BACKGROUND_WORKER_NAME}' \\
      --restart unless-stopped \\
      --init \\
      --no-healthcheck \\
      --user 10001:10001 \\
      --network sp-net \\
      --read-only \\
      --security-opt no-new-privileges \\
      --cap-drop all \\
      --memory '${BACKGROUND_REPORT_MEMORY}' \\
      --pids-limit 512 \\
      --shm-size 512m \\
      --tmpfs /tmp:rw,nosuid,nodev,noexec,size=1g,mode=1777 \\
      --env-file '${REMOTE_EMAIL_ENV}' \\
      --env APP_DIR=/app \\
      --env HOME=/tmp/cgv-worker \\
      --env CGV_DATA_ROOT=/app \\
      --env CGV_CACHE_DIR=/app/cache \\
      --env CGV_NCBI_DOWNLOADS_DIR=/app/ncbi_downloads \\
      --env CGV_PUBLIC_BASE_URL='https://${PUBLIC_HOSTNAME}' \\
      --env APP_SHARED_REPORTS_ENABLED=1 \\
      --env APP_BACKGROUND_REPORTS_ENABLED=1 \\
      --env APP_BACKGROUND_REPORT_POLL_SECONDS=3 \\
      --env APP_BACKGROUND_REPORT_TIMEOUT_MINUTES=30 \\
      --env APP_BACKGROUND_REPORT_FUTURE_WORKERS=2 \\
      --env APP_BACKGROUND_REPORT_LASTZ_WORKERS=1 \\
      --env APP_LASTZ_GLOBAL_WORKERS='${APP_LASTZ_GLOBAL_WORKERS}' \\
      --env APP_LASTZ_GLOBAL_QUEUE_WAIT_SECONDS=1800 \\
      --env APP_PREWARM_ON_START=0 \\
      --env APP_PREWARM_BLOCK_START=0 \\
      --env APP_SESSION_METRICS=0 \\
      --env CHROMOTE_CHROME=/usr/bin/google-chrome \\
      --volume '${APP_DIR}/annotations:/app/annotations:ro' \\
      --volume '${APP_DIR}/genomes:/app/genomes:ro' \\
      --volume '${APP_DIR}/go_annotations:/app/go_annotations:ro' \\
      --volume '${APP_DIR}/data:/app/data:ro' \\
      --volume '${APP_DIR}/cache:/app/cache' \\
      --volume '${REMOTE_PATH}/ncbi_downloads:/app/ncbi_downloads' \\
      '${expected_image}' \\
      Rscript /app/scripts/background_report_worker.R >/dev/null
  "
}

wait_for_release() {
  local expected_image="$1"
  local require_worker="${2:-1}"
  rssh "set -e
    for i in \$(seq 1 120); do
      socket_state=\$(podman inspect cgv-docker-socket-proxy --format '{{.State.Health.Status}}' 2>/dev/null || true)
      running=\$(podman ps --filter ancestor='${expected_image}' -q | wc -l | tr -d ' ')
      worker_state=\$(podman inspect '${BACKGROUND_WORKER_NAME}' --format '{{.State.Status}}' 2>/dev/null || true)
      worker_image=\$(podman inspect '${BACKGROUND_WORKER_NAME}' --format '{{.ImageName}}' 2>/dev/null || true)
      codes=\$(python3 - <<'PY'
import http.client
out=[]
for port in (18081, 3838):
    try:
        c=http.client.HTTPConnection('127.0.0.1', port, timeout=3)
        c.request('HEAD', '/')
        out.append(str(c.getresponse().status))
        c.close()
    except Exception:
        out.append('000')
print(' '.join(out))
PY
)
      proxy_code=\$(printf '%s' \"\$codes\" | awk '{print \$1}')
      nginx_code=\$(printf '%s' \"\$codes\" | awk '{print \$2}')
      worker_ok=0
      if [ '${require_worker}' = 0 ]; then
        worker_ok=1
      elif [ \"\$worker_state\" = running ] && [ \"\$worker_image\" = '${expected_image}' ] && \
           podman logs --tail 80 '${BACKGROUND_WORKER_NAME}' 2>&1 | grep -q '\[background-report-worker\] ready'; then
        if podman exec '${BACKGROUND_WORKER_NAME}' grep -q 'worker.ready' /app/scripts/background_report_worker.R 2>/dev/null; then
          if podman exec '${BACKGROUND_WORKER_NAME}' test -s /app/cache/background_reports/worker.ready 2>/dev/null; then worker_ok=1; fi
        else
          worker_ok=1
        fi
      fi
      if [ \"\$socket_state\" = healthy ] && [ \"\$worker_ok\" = 1 ] && printf '%s' \"\$proxy_code\" | grep -Eq '^[23][0-9][0-9]$' && printf '%s' \"\$nginx_code\" | grep -Eq '^[23][0-9][0-9]$' && [ \"\$running\" -ge 1 ]; then
        echo \"ready: socket=\$socket_state proxy=\$proxy_code nginx=\$nginx_code app_instances=\$running worker=\${worker_state:-not-required} wait=\${i}s\"
        exit 0
      fi
      sleep 1
    done
    podman ps -a --format '{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}' >&2
    podman logs --tail 120 cgv-shinyproxy >&2 || true
    podman logs --tail 120 '${BACKGROUND_WORKER_NAME}' >&2 || true
    exit 1
  "
}

rollback_release() {
  echo "ROLLBACK: restaurando ${CURRENT_IMAGE}..." >&2
  if ! rssh "set -e
    cd '${APP_DIR}'
    cp -p '${BACKUP_DIR}/app.env' .env
    cp -p '${BACKUP_DIR}/docker-compose.shinyproxy.colors.yml' docker-compose.shinyproxy.colors.yml
    cp -p '${BACKUP_DIR}/application.yml' shinyproxy/application.yml
    cp -p '${BACKUP_DIR}/cgv-shinyproxy-colors.conf' deploy/nginx/cgv-shinyproxy-colors.conf
    if [ -f '${BACKUP_DIR}/background-report-email.env' ]; then
      cp -p '${BACKUP_DIR}/background-report-email.env' '${REMOTE_EMAIL_ENV}'
    else
      rm -f '${REMOTE_EMAIL_ENV}'
    fi
    ${teardown_stack_command}
    CGV_IMAGE='${CURRENT_IMAGE}' SHINYPROXY_IMAGE='${SHINYPROXY_IMAGE}' \
      podman-compose -f docker-compose.shinyproxy.colors.yml up -d
  "; then
    return 1
  fi
  start_background_worker "$CURRENT_IMAGE" && wait_for_release "$CURRENT_IMAGE" 1
}

echo ""
echo "[6/7] Cambiando producción a ${NEW_IMAGE}..."
set +e
rssh "set -e
  cd '${APP_DIR}'
  grep -q '^CGV_IMAGE=' .env
  sed -i -E 's|^CGV_IMAGE=.*|CGV_IMAGE=${NEW_IMAGE}|' .env
  ${teardown_stack_command}
  CGV_IMAGE='${NEW_IMAGE}' SHINYPROXY_IMAGE='${SHINYPROXY_IMAGE}' \
    podman-compose -f docker-compose.shinyproxy.colors.yml up -d
"
CUTOVER_STATUS=$?
if [[ "$CUTOVER_STATUS" -eq 0 ]]; then
  start_background_worker "$NEW_IMAGE"
  CUTOVER_STATUS=$?
fi
set -e

if [[ "$CUTOVER_STATUS" -ne 0 ]] || ! wait_for_release "$NEW_IMAGE" 1; then
  echo "ERROR: la nueva release no superó la validación; se inicia rollback." >&2
  if rollback_release; then
    die "deploy revertido correctamente a ${CURRENT_IMAGE}"
  fi
  die "deploy y rollback fallaron; respaldo disponible en ${BACKUP_DIR}"
fi

echo ""
echo "[7/7] Verificación final..."
set +e
rssh "set -e
  fail_guard() { echo \"FINAL_GUARD_FAILED: \$1\" >&2; exit 1; }
  test \"\$(podman inspect cgv-shinyproxy --format '{{.ImageName}}')\" = '${SHINYPROXY_RUNTIME_IMAGE}' || fail_guard shinyproxy-image
  if podman inspect cgv-shinyproxy --format '{{range .Mounts}}{{println .Destination}}{{end}}' | grep -qx '/var/run/docker.sock'; then fail_guard direct-docker-socket; fi
  test \"\$(podman network inspect sp-control --format '{{.Internal}}')\" = true || fail_guard sp-control-not-internal
  legacy=\$(podman ps --filter ancestor=localhost/cgv:1.0.0 -q | wc -l | tr -d ' ')
  test \"\$legacy\" = 0 || fail_guard legacy-cgv-container
  podman logs --since 5m cgv-shinyproxy 2>&1 | grep -q 'Started ShinyProxy 3.2.4' || fail_guard shinyproxy-start-log
  test \"\$(podman inspect '${BACKGROUND_WORKER_NAME}' --format '{{.State.Status}}')\" = running || fail_guard worker-not-running
  test \"\$(podman inspect '${BACKGROUND_WORKER_NAME}' --format '{{.ImageName}}')\" = '${NEW_IMAGE}' || fail_guard worker-image
  podman logs --tail 80 '${BACKGROUND_WORKER_NAME}' 2>&1 | grep -q '\[background-report-worker\] ready' || fail_guard worker-ready-log
  podman exec '${BACKGROUND_WORKER_NAME}' test -s /app/cache/background_reports/worker.ready || fail_guard worker-ready-marker
  podman exec '${BACKGROUND_WORKER_NAME}' grep -q '^browser=Chrome/' /app/cache/background_reports/worker.ready || fail_guard worker-browser-marker
  podman ps --format '{{.Names}}|{{.Image}}|{{.Status}}|{{.Networks}}'
"
FINAL_STATUS=$?
set -e

if [[ "$FINAL_STATUS" -ne 0 ]]; then
  echo "ERROR: falló una guarda final de seguridad; se inicia rollback." >&2
  if rollback_release; then
    die "deploy revertido correctamente a ${CURRENT_IMAGE}"
  fi
  die "falló la guarda final y también el rollback; usa ${BACKUP_DIR}"
fi

PUBLIC_CODE="000"
for public_attempt in 1 2 3 4 5 6; do
  PUBLIC_CODE="$(curl -sS -I --max-time 15 -o /dev/null -w '%{http_code}' "https://${PUBLIC_HOSTNAME}/" 2>/dev/null || true)"
  if [[ "$PUBLIC_CODE" =~ ^[23][0-9][0-9]$ ]]; then
    break
  fi
  sleep 5
done
if [[ ! "$PUBLIC_CODE" =~ ^[23][0-9][0-9]$ ]]; then
  echo "ERROR: la URL pública respondió HTTP ${PUBLIC_CODE:-000}; se inicia rollback." >&2
  if rollback_release; then
    die "deploy revertido correctamente a ${CURRENT_IMAGE}"
  fi
  die "falló la URL pública y también el rollback; usa ${BACKUP_DIR}"
fi

echo ""
echo "============================================"
echo "  Deploy completado"
echo "  Release:  ${NEW_IMAGE}"
echo "  Anterior: ${CURRENT_IMAGE}"
echo "  Respaldo: ${BACKUP_DIR}"
echo "  Público:  HTTP ${PUBLIC_CODE}"
echo "  Reportes: worker activo (${BACKGROUND_WORKER_NAME})"
echo "============================================"
