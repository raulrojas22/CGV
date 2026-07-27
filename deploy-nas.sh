#!/usr/bin/env bash
# ============================================================
# deploy-nas.sh — Sincroniza y despliega CGV en el NAS
# URL: https://cgvapp.com
# Uso: ./deploy-nas.sh
# ============================================================
set -euo pipefail

NAS_USER="${NAS_USER:-truenas_admin}"
NAS_HOST="${NAS_HOST:-192.168.1.200}"
NAS_PATH="${NAS_PATH:-/mnt/Datos4raro/cgv}"
LOCAL_APP="/Users/rarojas/Documents/A_FULLAPP/"
TUNNEL_NAME="cgv"
TUNNEL_CONFIG="${TUNNEL_CONFIG:-/home/${NAS_USER}/.cloudflared/config.yml}"
REMOTE_DOCKER="${REMOTE_DOCKER:-docker}"
CGV_DEPS_IMAGE="${CGV_DEPS_IMAGE:-cgv-deps:1.0.0}"
REBUILD_R_DEPS="${REBUILD_R_DEPS:-0}"
HEALTH_TIMEOUT_SECONDS="${HEALTH_TIMEOUT_SECONDS:-600}"
GUIDE_MEDIA_FILES=(
  guide-intro.mp4
  guide-multigene-01a-preloaded-organism.mp4
  guide-multigene-01b-ncbi-search.mp4
  guide-multigene-01c-upload-files.mp4
  guide-multigene-02a-add-one-gene.mp4
  guide-multigene-02b-add-batch-genes.mp4
  guide-multigene-03-generate-visualization.mp4
  guide-multigene-04a-compact-visualization.mp4
  guide-multigene-04b-detailed-visualization.mp4
  guide-multigene-05-alignment-optional.mp4
  guide-multigene-06a-export-figures.mp4
  guide-multigene-06b-export-tables-results.mp4
  guide-cross-01a-preloaded-organisms.mp4
  guide-cross-01b-ncbi-search.mp4
  guide-cross-01c-upload-files.mp4
  guide-cross-01d-mixed-sources.mp4
  guide-cross-02-search-gene.mp4
  guide-cross-03-generate-visualization.mp4
  guide-cross-03a-compact-visualization.mp4
  guide-cross-03b-detailed-visualization.mp4
  guide-cross-04-inspect-visualization.mp4
  guide-cross-05a-comparative-synteny-align.mp4
  guide-cross-05b-lastz-blocks.mp4
  guide-cross-05c-multipip.mp4
  guide-cross-06a-export-alignment-visual-figures.mp4
  guide-common-01-review-analytics-charts.mp4
  guide-common-02-review-tables-results.mp4
  guide-common-03-visualize-transcript-variants.mp4
  guide-common-04-inspect-gene-information.mp4
  guide-common-05-download-promoter-sequences.mp4
  guide-common-06-review-literature.mp4
  guide-common-07-review-organism-assembly-info.mp4
  guide-common-08-configure-external-alias-lookup.mp4
  guide-common-09a-save-work-session.mp4
  guide-common-09b-load-work-session.mp4
  guide-common-10-clear-visualizations.mp4
)

# --- SSH multiplexing: UNA sola autenticacion para todo ---
SSH_SOCK="/tmp/deploy-nas-ssh-$$"
ssh -fNM -S "$SSH_SOCK" "${NAS_USER}@${NAS_HOST}"
trap 'ssh -S "$SSH_SOCK" -O exit "${NAS_USER}@${NAS_HOST}" 2>/dev/null' EXIT
nssh() {
  if [[ "${REMOTE_DOCKER}" == sudo* ]]; then
    ssh -tt -S "$SSH_SOCK" "${NAS_USER}@${NAS_HOST}" "$@"
  else
    ssh -S "$SSH_SOCK" "${NAS_USER}@${NAS_HOST}" "$@"
  fi
}

ensure_remote_docker_access() {
  if nssh "${REMOTE_DOCKER} info >/dev/null 2>&1"; then
    return 0
  fi

  if [[ "${REMOTE_DOCKER}" == "docker" ]] && nssh "docker info 2>&1 | grep -qi 'permission denied'"; then
    echo "  Docker requiere permisos elevados en el NAS; usando sudo docker."
    REMOTE_DOCKER="sudo docker"
    nssh "${REMOTE_DOCKER} info >/dev/null"
    return 0
  fi

  echo "ERROR: no se pudo acceder a Docker en el NAS con '${REMOTE_DOCKER}'." >&2
  echo "Prueba en el NAS: docker info" >&2
  echo "Si muestra permission denied, agrega el usuario al grupo docker o ejecuta:" >&2
  echo "  REMOTE_DOCKER='sudo docker' ./deploy-nas.sh" >&2
  exit 1
}

echo "=============================="
echo "  CGV — Deploy to NAS"
echo "  https://cgvapp.com"
echo "  R dependencies: ${CGV_DEPS_IMAGE} (rebuild=${REBUILD_R_DEPS})"
echo "=============================="
echo ""

if [[ "${REBUILD_R_DEPS}" != "0" && "${REBUILD_R_DEPS}" != "1" ]]; then
  echo "ERROR: REBUILD_R_DEPS debe ser 0 o 1." >&2
  exit 1
fi
if ! [[ "${HEALTH_TIMEOUT_SECONDS}" =~ ^[1-9][0-9]*$ ]]; then
  echo "ERROR: HEALTH_TIMEOUT_SECONDS debe ser un entero positivo." >&2
  exit 1
fi

echo "Verificando acceso a Docker en el NAS..."
ensure_remote_docker_access
echo ""

# --- Paso 1: Sincronizar codigo ---
echo "[1/5] Sincronizando codigo al NAS..."
rsync -avz --progress --delete \
  -e "ssh -S $SSH_SOCK" \
  --exclude=annotations --exclude=genomes \
  --exclude=go_annotations --exclude=cache \
  --exclude=ncbi_downloads \
  --exclude=.git --exclude=.claude \
  --exclude=paper/node_modules --exclude=node_modules \
  --exclude=.Rapp.history --exclude=.Rhistory \
  --exclude=.codex_backups --exclude=.qodo \
  --exclude='*.docx' --exclude='.env.local' \
  "$LOCAL_APP" \
  "${NAS_USER}@${NAS_HOST}:${NAS_PATH}/app/"

echo ""
echo "  Verificando screencasts en NAS..."
nssh "
SC_DIR='${NAS_PATH}/app/www/screencasts'
MISSING=0
for video in ${GUIDE_MEDIA_FILES[*]}; do
  if [ -f \"\${SC_DIR}/\${video}\" ]; then
    ls -lh \"\${SC_DIR}/\${video}\"
  else
    echo \"ADVERTENCIA: falta www/screencasts/\${video} en el NAS\"
    MISSING=\$((MISSING + 1))
  fi
done
echo \"  Screencasts faltantes en NAS: \${MISSING}\"
"

# --- Paso 2: Detener tunel y despliegue ShinyProxy anterior ---
echo ""
echo "[2/5] Deteniendo tunel Cloudflare y servicios CGV anteriores..."
nssh "
pid=\$(cat ${NAS_PATH}/tunnel.pid 2>/dev/null || echo '')
if [ -n \"\$pid\" ] && kill -0 \"\$pid\" 2>/dev/null; then
  kill \"\$pid\"
  echo \"  Tunel PID \$pid detenido\"
else
  echo '  No habia tunel CGV activo'
fi
${REMOTE_DOCKER} stop cgv-shinyproxy cgv-nginx >/dev/null 2>&1 || true
${REMOTE_DOCKER} rm cgv-shinyproxy cgv-nginx >/dev/null 2>&1 || true
echo '  Despliegue ShinyProxy anterior retirado (si existia)'
"

# --- Paso 3: Reconstruir imagen Docker ---
echo ""
echo "[3/5] Reconstruyendo imagen Docker en el NAS..."
nssh "
  cd ${NAS_PATH}/app
  if [ '${REBUILD_R_DEPS}' = '1' ] || ! ${REMOTE_DOCKER} image inspect '${CGV_DEPS_IMAGE}' >/dev/null 2>&1; then
    echo '  Construyendo ${CGV_DEPS_IMAGE} (primera vez o actualización explícita de dependencias)...'
    ${REMOTE_DOCKER} build --pull=false -t '${CGV_DEPS_IMAGE}' -f Dockerfile.dependencies .
  else
    echo '  Reutilizando ${CGV_DEPS_IMAGE}; no se instalarán paquetes R.'
  fi
  CGV_DEPS_IMAGE='${CGV_DEPS_IMAGE}' ${REMOTE_DOCKER} compose up -d --build
"

# --- Paso 4: Esperar a que la app este healthy ---
echo ""
echo "[4/5] Esperando a que la app este healthy..."
nssh "
MAX=${HEALTH_TIMEOUT_SECONDS}; ELAPSED=0
while [ \$ELAPSED -lt \$MAX ]; do
  STATUS=\$(${REMOTE_DOCKER} inspect --format='{{.State.Health.Status}}' cgv 2>/dev/null || echo 'unknown')
  if [ \"\$STATUS\" = 'healthy' ]; then
    echo \"  App healthy despues de \${ELAPSED}s\"
    break
  fi
  echo \"  Estado: \${STATUS} (\${ELAPSED}s/\${MAX}s)...\"
  sleep 5
  ELAPSED=\$((ELAPSED + 5))
done
if [ \"\$STATUS\" != 'healthy' ]; then
  echo 'ERROR: CGV no alcanzo el estado healthy dentro del tiempo esperado.' >&2
  ${REMOTE_DOCKER} logs --tail 100 cgv >&2 || true
  exit 1
fi
HTTP=\$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3838 || echo '000')
echo \"  HTTP status: \$HTTP\"
if [ \"\$HTTP\" != '200' ]; then
  echo \"ERROR: CGV respondio con HTTP \$HTTP en el puerto 3838.\" >&2
  ${REMOTE_DOCKER} logs --tail 100 cgv >&2 || true
  exit 1
fi
echo '  Verificando montaje de índices de alias preloaded...'
${REMOTE_DOCKER} exec cgv Rscript /app/scripts/verify_preloaded_alias_indexes.R --root=/app
VIDEO_HTTP_FAILURES=0
VIDEO_RANGE_WARNINGS=0
for video in ${GUIDE_MEDIA_FILES[*]}; do
  VIDEO_HTTP=\$(curl -s -o /dev/null -w '%{http_code}' \"http://localhost:3838/screencasts/\${video}\" || echo '000')
  VIDEO_RANGE_HTTP=\$(curl -s -o /dev/null -H 'Range: bytes=0-1' -w '%{http_code}' \"http://localhost:3838/screencasts/\${video}\" || echo '000')
  echo \"  \${video}: http=\${VIDEO_HTTP} range=\${VIDEO_RANGE_HTTP}\"
  if [ \"\$VIDEO_HTTP\" != '200' ]; then
    VIDEO_HTTP_FAILURES=\$((VIDEO_HTTP_FAILURES + 1))
  fi
  if [ \"\$VIDEO_RANGE_HTTP\" != '206' ]; then
    VIDEO_RANGE_WARNINGS=\$((VIDEO_RANGE_WARNINGS + 1))
  fi
done
echo \"  Screencast HTTP failures: \${VIDEO_HTTP_FAILURES}\"
echo \"  Screencast range warnings: \${VIDEO_RANGE_WARNINGS}\"
if [ \"\$VIDEO_RANGE_WARNINGS\" != '0' ]; then
  echo \"  ADVERTENCIA: Safari suele necesitar HTTP 206/Range para reproducir MP4 desde produccion.\"
fi
${REMOTE_DOCKER} ps --filter name=cgv --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
"

# --- Paso 5: Lanzar named tunnel ---
echo ""
echo "[5/5] Lanzando tunel Cloudflare (${TUNNEL_NAME})..."
nssh "
if [ ! -f '${TUNNEL_CONFIG}' ]; then
  echo 'ERROR: no existe la configuracion del tunel: ${TUNNEL_CONFIG}' >&2
  exit 1
fi
cp '${TUNNEL_CONFIG}' '${TUNNEL_CONFIG}.deploy-nas.bak'
sed -i -E 's#service: http://(127\\.0\\.0\\.1|localhost):18080#service: http://127.0.0.1:3838#g' '${TUNNEL_CONFIG}'
if ! grep -qE 'service: http://(127\\.0\\.0\\.1|localhost):3838' '${TUNNEL_CONFIG}'; then
  echo 'ERROR: el tunel no apunta al puerto 3838; no se iniciara.' >&2
  exit 1
fi
${NAS_PATH}/cloudflared tunnel --config '${TUNNEL_CONFIG}' ingress validate
rm -f ${NAS_PATH}/tunnel.log
nohup ${NAS_PATH}/cloudflared --no-autoupdate tunnel --config '${TUNNEL_CONFIG}' --protocol http2 run ${TUNNEL_NAME} > ${NAS_PATH}/tunnel.log 2>&1 &
echo \$! > ${NAS_PATH}/tunnel.pid
echo \"Tunel PID: \$(cat ${NAS_PATH}/tunnel.pid)\"
sleep 3
if kill -0 \$(cat ${NAS_PATH}/tunnel.pid) 2>/dev/null; then
  echo 'Tunel corriendo OK'
else
  echo 'ERROR: Tunel no arranco'
  tail -20 ${NAS_PATH}/tunnel.log
  exit 1
fi
"

echo ""
echo "=============================="
echo "  Deploy completado!"
echo "  Local:   http://${NAS_HOST}:3838"
echo "  Publico: https://cgvapp.com"
echo "=============================="
