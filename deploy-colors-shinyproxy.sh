#!/usr/bin/env bash
# Safe application-only deployment for CGV on Colors.
#
# This script deliberately does not deploy or rewrite ShinyProxy, nginx, the
# socket proxy, their Compose file, or persistent biological data. It only
# builds a versioned CGV image and switches the already-hardened stack to it.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REMOTE_TARGET="${REMOTE_TARGET:-colors}"
REMOTE_PATH="${REMOTE_PATH:-/home/rarojas/cgv}"
APP_DIR="${REMOTE_PATH}/app"
PUBLIC_HOSTNAME="${PUBLIC_HOSTNAME:-cgv.mobilomics.org}"
COMPOSE_FILE="${APP_DIR}/docker-compose.shinyproxy.colors.yml"
CGV_DEPS_IMAGE="${CGV_DEPS_IMAGE:-cgv-deps:1.0.0}"
SHINYPROXY_IMAGE="${SHINYPROXY_IMAGE:-docker.io/openanalytics/shinyproxy:3.2.4@sha256:281dfddd3c8c54ea2dfa74390480d0f7769b53fd0bbef6d57f272574fd10fa3c}"
SHINYPROXY_DIGEST="${SHINYPROXY_IMAGE##*@}"
SHINYPROXY_RUNTIME_IMAGE="docker.io/openanalytics/shinyproxy@${SHINYPROXY_DIGEST}"
REBUILD_R_DEPS="${REBUILD_R_DEPS:-0}"
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

for command_name in curl git ssh rsync shasum; do
  command -v "$command_name" >/dev/null 2>&1 || die "falta el comando local '${command_name}'"
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
  podman inspect cgv-docker-socket-proxy cgv-shinyproxy cgv-nginx > '${BACKUP_DIR}/infrastructure.inspect.json'
  podman ps -a --no-trunc > '${BACKUP_DIR}/podman-ps.txt'
"

echo ""
echo "[3/7] Sincronizando sólo el código de aplicación..."
rsync -az --delete-delay --itemize-changes \
  -e "ssh -S $SSH_SOCK" \
  --exclude='/.git' \
  --exclude='/.env' --exclude='/.env.local' --exclude='/.Renviron' \
  --exclude='/.codex_work' --exclude='/.codex_backups' --exclude='/.claude' --exclude='/.qodo' \
  --exclude='/.Rproj.user' --exclude='/.Rhistory' --exclude='/.Rapp.history' \
  --exclude='/annotations' --exclude='/genomes' --exclude='/go_annotations' \
  --exclude='/data' --exclude='/cache' --exclude='/ncbi_downloads' \
  --exclude='/build_sources' --exclude='/outputs' --exclude='/logs' --exclude='/tmp' \
  --exclude='/desktop' --exclude='/node_modules' --exclude='/paper' \
  --exclude='/deploy-colors-shinyproxy.sh' \
  --exclude='/docker-compose.shinyproxy.yml' \
  --exclude='/docker-compose.shinyproxy.colors.yml' \
  --exclude='/shinyproxy/application.yml' \
  --exclude='/deploy/nginx/cgv-shinyproxy.conf' \
  --exclude='/deploy/nginx/cgv-shinyproxy-colors.conf' \
  "${SCRIPT_DIR}/" "${REMOTE_TARGET}:${APP_DIR}/"

echo ""
echo "[4/7] Construyendo imagen inmutable ${NEW_IMAGE}..."
if [[ "$REBUILD_R_DEPS" == "1" ]]; then
  rssh "cd '${APP_DIR}' && podman build --pull=never -t '${CGV_DEPS_IMAGE}' -f Dockerfile.dependencies ."
else
  rssh "podman image exists '${CGV_DEPS_IMAGE}'" || \
    die "falta ${CGV_DEPS_IMAGE}; usa REBUILD_R_DEPS=1 de forma explícita"
fi
rssh "cd '${APP_DIR}' && podman build --pull=never \
  --build-arg CGV_DEPS_IMAGE='${CGV_DEPS_IMAGE}' \
  --label org.opencontainers.image.revision='${SOURCE_REV}' \
  --label org.opencontainers.image.created='${DEPLOY_UTC}' \
  -t '${NEW_IMAGE}' -f Dockerfile ."

LOCAL_HASHES="$(
  cd "$SCRIPT_DIR"
  shasum -a 256 \
    ui.R server.R global.R \
    www/home_preview_cgv.html www/css/cgv_compiled.css |
    awk '{print $1}' | paste -sd: -
)"
REMOTE_HASHES="$(
  rssh "podman run --rm --user 10001:10001 --entrypoint sha256sum '${NEW_IMAGE}' \
    /app/ui.R /app/server.R /app/global.R \
    /app/www/home_preview_cgv.html /app/www/css/cgv_compiled.css" |
    awk '{print $1}' | paste -sd: -
)"
[[ "$LOCAL_HASHES" == "$REMOTE_HASHES" ]] || die "los hashes de la imagen no coinciden con el commit local"
echo "  Hashes ui/server/global/home/CSS y lectura con UID 10001: OK"

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
  podman stop cgv-shinyproxy >/dev/null 2>&1 || true
  session_ids=\$(podman ps -aq --filter name=sp-container- 2>/dev/null || true)
  if [ -n \"\$session_ids\" ]; then podman rm -f \$session_ids >/dev/null; fi
  podman pod rm -f pod_app >/dev/null 2>&1 || true
  podman rm -f cgv-shinyproxy cgv-nginx cgv-docker-socket-proxy >/dev/null 2>&1 || true
  podman network rm sp-control >/dev/null 2>&1 || true
  podman network rm sp-net >/dev/null 2>&1 || true
"

wait_for_release() {
  local expected_image="$1"
  rssh "set -e
    for i in \$(seq 1 120); do
      socket_state=\$(podman inspect cgv-docker-socket-proxy --format '{{.State.Health.Status}}' 2>/dev/null || true)
      running=\$(podman ps --filter ancestor='${expected_image}' -q | wc -l | tr -d ' ')
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
      if [ \"\$socket_state\" = healthy ] && printf '%s' \"\$proxy_code\" | grep -Eq '^[23][0-9][0-9]$' && printf '%s' \"\$nginx_code\" | grep -Eq '^[23][0-9][0-9]$' && [ \"\$running\" -ge 1 ]; then
        echo \"ready: socket=\$socket_state proxy=\$proxy_code nginx=\$nginx_code app_instances=\$running wait=\${i}s\"
        exit 0
      fi
      sleep 1
    done
    podman ps -a --format '{{.Names}}|{{.Image}}|{{.Status}}|{{.Ports}}' >&2
    podman logs --tail 120 cgv-shinyproxy >&2 || true
    exit 1
  "
}

rollback_release() {
  echo "ROLLBACK: restaurando ${CURRENT_IMAGE}..." >&2
  rssh "set -e
    cd '${APP_DIR}'
    cp -p '${BACKUP_DIR}/app.env' .env
    cp -p '${BACKUP_DIR}/docker-compose.shinyproxy.colors.yml' docker-compose.shinyproxy.colors.yml
    cp -p '${BACKUP_DIR}/application.yml' shinyproxy/application.yml
    cp -p '${BACKUP_DIR}/cgv-shinyproxy-colors.conf' deploy/nginx/cgv-shinyproxy-colors.conf
    ${teardown_stack_command}
    CGV_IMAGE='${CURRENT_IMAGE}' SHINYPROXY_IMAGE='${SHINYPROXY_IMAGE}' \
      podman-compose -f docker-compose.shinyproxy.colors.yml up -d
  " && wait_for_release "$CURRENT_IMAGE"
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
set -e

if [[ "$CUTOVER_STATUS" -ne 0 ]] || ! wait_for_release "$NEW_IMAGE"; then
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
  test \"\$(podman inspect cgv-shinyproxy --format '{{.ImageName}}')\" = '${SHINYPROXY_RUNTIME_IMAGE}'
  ! podman inspect cgv-shinyproxy --format '{{range .Mounts}}{{println .Destination}}{{end}}' | grep -qx '/var/run/docker.sock'
  test \"\$(podman network inspect sp-control --format '{{.Internal}}')\" = true
  legacy=\$(podman ps --filter ancestor=localhost/cgv:1.0.0 -q | wc -l | tr -d ' ')
  test \"\$legacy\" = 0
  podman logs --since 5m cgv-shinyproxy 2>&1 | grep -q 'Started ShinyProxy 3.2.4'
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
echo "============================================"
