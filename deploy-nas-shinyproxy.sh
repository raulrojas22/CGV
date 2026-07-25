#!/usr/bin/env bash
# ============================================================
# deploy-nas-shinyproxy.sh — Despliega CGV con ShinyProxy en el NAS
# URL: https://cgvapp.com
# Soporta 3-5 usuarios simultaneos con contenedores por usuario.
# ShinyProxy queda sin login y limitado por SP_MAX_TOTAL_INSTANCES.
# ============================================================
set -euo pipefail

NAS_USER="${NAS_USER:-truenas_admin}"
NAS_HOST="${NAS_HOST:-192.168.1.200}"
NAS_PATH="${NAS_PATH:-/mnt/Datos4raro/cgv}"
LOCAL_APP="/Users/rarojas/Documents/A_FULLAPP/"
TUNNEL_NAME="cgv"
REMOTE_DOCKER="${REMOTE_DOCKER:-docker}"
NAS_APP_DIR="${NAS_PATH}/app"
local_env_value() {
  local key="$1"
  local fallback="$2"
  local env_file="${LOCAL_APP}/.env"
  local val=""
  if [[ -f "${env_file}" ]]; then
    val="$(grep -E "^${key}=" "${env_file}" | tail -1 | cut -d= -f2- || true)"
    val="${val%\"}"
    val="${val#\"}"
    val="${val%\'}"
    val="${val#\'}"
  fi
  if [[ -n "${val}" ]]; then
    printf '%s' "${val}"
  else
    printf '%s' "${fallback}"
  fi
}

ENV_CGV_IMAGE=""
if [[ -f "${LOCAL_APP}/.env" ]]; then
  ENV_CGV_IMAGE="$(grep -E '^CGV_IMAGE=' "${LOCAL_APP}/.env" | tail -1 | cut -d= -f2- || true)"
  ENV_CGV_IMAGE="${ENV_CGV_IMAGE%\"}"
  ENV_CGV_IMAGE="${ENV_CGV_IMAGE#\"}"
  ENV_CGV_IMAGE="${ENV_CGV_IMAGE%\'}"
  ENV_CGV_IMAGE="${ENV_CGV_IMAGE#\'}"
fi
CGV_IMAGE="${CGV_IMAGE:-${ENV_CGV_IMAGE:-cgv:1.0.0}}"
CGV_DEPS_IMAGE="${CGV_DEPS_IMAGE:-$(local_env_value CGV_DEPS_IMAGE cgv-deps:1.0.0)}"
REBUILD_R_DEPS="${REBUILD_R_DEPS:-0}"
CGV_NGINX_PORT="${CGV_NGINX_PORT:-$(local_env_value CGV_NGINX_PORT 18080)}"

SSH_SOCK="/tmp/deploy-nas-sp-ssh-$$"
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
  exit 1
}

echo "============================================"
echo "  CGV ShinyProxy — Deploy to NAS"
echo "  https://cgvapp.com"
echo "  Modo: multiusuario (1 contenedor/usuario)"
echo "  R dependencies: ${CGV_DEPS_IMAGE} (rebuild=${REBUILD_R_DEPS})"
echo "============================================"
echo ""

if [[ "${REBUILD_R_DEPS}" != "0" && "${REBUILD_R_DEPS}" != "1" ]]; then
  echo "ERROR: REBUILD_R_DEPS debe ser 0 o 1." >&2
  exit 1
fi

echo "Verificando acceso a Docker en el NAS..."
ensure_remote_docker_access
echo ""

# --- Paso 1: Sincronizar codigo ---
echo "[1/7] Sincronizando codigo al NAS..."
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
  "${NAS_USER}@${NAS_HOST}:${NAS_APP_DIR}/"
echo ""

# --- Paso 1b: Verificar datos grandes en el NAS ---
echo "[1b/7] Verificando datos biologicos persistentes en el NAS..."
nssh "
  set -e
  mkdir -p ${NAS_PATH}
	  for d in annotations genomes go_annotations cache ncbi_downloads; do
	    app_dir='${NAS_APP_DIR}'/\$d
	    shared_dir='${NAS_PATH}'/\$d
	    if [ "\$d" = "ncbi_downloads" ]; then
	      mkdir -p "\$shared_dir"
	    fi
	    if [ ! -e \"\$app_dir\" ] && [ -e \"\$shared_dir\" ]; then
      ln -s \"\$shared_dir\" \"\$app_dir\"
      echo \"  Enlace creado: \$app_dir -> \$shared_dir\"
    elif [ -d \"\$shared_dir\" ] && [ ! -L \"\$app_dir\" ]; then
      needs_link=0
      if [ \"\$d\" = 'annotations' ] && [ -s \"\$shared_dir/registry.tsv\" ] && [ ! -s \"\$app_dir/registry.tsv\" ]; then
        needs_link=1
      elif [ \"\$d\" = 'genomes' ] && [ -s \"\$shared_dir/registry.tsv\" ] && [ ! -s \"\$app_dir/registry.tsv\" ]; then
        needs_link=1
      elif [ \"\$d\" = 'go_annotations' ] && [ -z \"\$(find \"\$app_dir\" -mindepth 1 -maxdepth 1 2>/dev/null | head -1)\" ]; then
        needs_link=1
      elif [ \"\$d\" = 'cache' ] && [ -d \"\$shared_dir/annotation_index\" ] && [ ! -d \"\$app_dir/annotation_index\" ]; then
        needs_link=1
      fi

      if [ \"\$needs_link\" = '1' ]; then
        if [ -z \"\$(find \"\$app_dir\" -mindepth 1 -maxdepth 1 2>/dev/null | head -1)\" ]; then
          rmdir \"\$app_dir\"
          ln -s \"\$shared_dir\" \"\$app_dir\"
          echo \"  Enlace reparado: \$app_dir -> \$shared_dir\"
        else
          echo \"ERROR: \$app_dir existe pero no apunta a los datos persistentes de \$shared_dir\" >&2
          echo \"Para reparar sin borrar datos, revisa en el NAS:\" >&2
          echo \"  ls -la \$app_dir \$shared_dir\" >&2
          echo \"Si \$app_dir esta vacio o incompleto, ejecuta:\" >&2
          echo \"  rmdir \$app_dir && ln -s \$shared_dir \$app_dir\" >&2
          exit 1
        fi
      fi
    fi
  done

  missing=''
  for d in annotations genomes go_annotations; do
    app_dir='${NAS_APP_DIR}'/\$d
    if [ ! -d \"\$app_dir\" ]; then
      missing=\"\$missing \$d\"
    fi
  done
  if [ -n \"\$missing\" ]; then
    echo \"ERROR: faltan directorios de datos en el NAS:\${missing}\" >&2
    echo \"\" >&2
    echo \"Copia los datos una sola vez desde tu Mac al NAS:\" >&2
    echo \"  rsync -avz --progress annotations genomes go_annotations ${NAS_USER}@${NAS_HOST}:${NAS_PATH}/\" >&2
    echo \"  rsync -avz --progress cache ${NAS_USER}@${NAS_HOST}:${NAS_PATH}/\" >&2
    echo \"\" >&2
    echo \"Luego vuelve a correr ./deploy-nas-shinyproxy.sh\" >&2
    exit 1
  fi

  if [ ! -s '${NAS_APP_DIR}/annotations/registry.tsv' ]; then
    echo \"ERROR: falta ${NAS_APP_DIR}/annotations/registry.tsv\" >&2
    echo \"Si tus datos estan en otro lugar, mueve o enlaza annotations/ hacia ${NAS_APP_DIR}/annotations.\" >&2
    exit 1
  fi
	  echo \"  Datos OK: annotations, genomes, go_annotations, ncbi_downloads\"
	"
echo ""

# --- Paso 2: Detener servicios anteriores ---
echo "[2/7] Deteniendo tunel Cloudflare y servicios anteriores..."
nssh "
  pid=\$(cat ${NAS_PATH}/tunnel.pid 2>/dev/null || echo '')
  if [ -n \"\$pid\" ] && kill -0 \$pid 2>/dev/null; then
    kill \$pid && echo '  Tunel PID '\$pid' detenido'
  else
    echo '  No habia tunel activo'
  fi
"
nssh "
  echo '  Deteniendo contenedores anteriores...'
  ${REMOTE_DOCKER} stop cgv 2>/dev/null || echo '  (no habia cgv)'
  ${REMOTE_DOCKER} stop cgv-shinyproxy 2>/dev/null || echo '  (no habia shinyproxy)'
  ${REMOTE_DOCKER} stop cgv-nginx 2>/dev/null || echo '  (no habia nginx)'
  ${REMOTE_DOCKER} rm cgv cgv-shinyproxy cgv-nginx 2>/dev/null || true
  stale=\$(${REMOTE_DOCKER} ps -aq --filter ancestor=${CGV_IMAGE} 2>/dev/null || true)
  if [ -n \"\$stale\" ]; then
    echo '  Deteniendo contenedores CGV dinamicos de ShinyProxy...'
    ${REMOTE_DOCKER} stop \$stale >/dev/null 2>&1 || true
    ${REMOTE_DOCKER} rm \$stale >/dev/null 2>&1 || true
  fi
  echo '  Contenedores detenidos y eliminados.'
"

echo ""
echo "Verificando puerto web ${CGV_NGINX_PORT} en el NAS..."
nssh "
  port='${CGV_NGINX_PORT}'
  if command -v ss >/dev/null 2>&1 && ss -ltn 2>/dev/null | awk '{print \$4}' | grep -Eq '(^|:)'\${port}'$'; then
    echo \"ERROR: el puerto \${port} ya esta ocupado en el NAS.\" >&2
    echo \"Prueba otro puerto editando CGV_NGINX_PORT en ${NAS_APP_DIR}/.env o en tu .env local.\" >&2
    exit 1
  fi
  if ${REMOTE_DOCKER} ps --format '{{.Ports}}' | grep -Eq '0\\.0\\.0\\.0:'\"\${port}\"'->|:'\"\${port}\"'->'; then
    echo \"ERROR: Docker ya tiene un contenedor publicando el puerto \${port}.\" >&2
    ${REMOTE_DOCKER} ps --format 'table {{.Names}}\t{{.Ports}}' >&2
    exit 1
  fi
  echo \"  Puerto \${port} disponible.\"
"

# --- Paso 3: Construir imagen CGV ---
echo ""
echo "[3/7] Preparando dependencias de R y construyendo '${CGV_IMAGE}' en el NAS..."
nssh "
  cd ${NAS_APP_DIR}
  if [ '${REBUILD_R_DEPS}' = '1' ] || ! ${REMOTE_DOCKER} image inspect '${CGV_DEPS_IMAGE}' >/dev/null 2>&1; then
    echo '  Construyendo ${CGV_DEPS_IMAGE} (primera vez o actualización explícita de dependencias)...'
    ${REMOTE_DOCKER} build --pull=false -t '${CGV_DEPS_IMAGE}' -f Dockerfile.dependencies .
  else
    echo '  Reutilizando ${CGV_DEPS_IMAGE}; no se instalarán paquetes R.'
  fi
  CGV_DEPS_IMAGE='${CGV_DEPS_IMAGE}' ${REMOTE_DOCKER} compose build
"

# --- Paso 4: Prewarming (indices SQLite) ---
echo ""
echo "[4/7] Ejecutando prewarming (indices SQLite y caches)..."
nssh "
  cd ${NAS_APP_DIR}
  chmod +x docker/setup-prewarm.sh
  DOCKER_BIN='${REMOTE_DOCKER}' bash docker/setup-prewarm.sh ${NAS_APP_DIR}
"

# --- Paso 5: Iniciar ShinyProxy ---
echo ""
echo "[5/7] Iniciando ShinyProxy + nginx..."
nssh "
  cd ${NAS_APP_DIR}
  ${REMOTE_DOCKER} compose -f docker-compose.shinyproxy.yml up -d
"

# --- Paso 6: Verificar salud ---
echo ""
echo "[6/7] Verificando servicios..."
echo "  Esperando a que ShinyProxy este listo..."
nssh "
  cd ${NAS_APP_DIR}
  MAX=180; ELAPSED=0
  while [ \$ELAPSED -lt \$MAX ]; do
    if curl -s -o /dev/null -w '%{http_code}' http://localhost:8080 2>/dev/null | grep -q '200\|302'; then
      echo \"  ShinyProxy responde despues de \${ELAPSED}s\"
      break
    fi
    echo \"  Esperando... (\${ELAPSED}s/\${MAX}s)\"
    sleep 5
    ELAPSED=\$((ELAPSED + 5))
  done
  curl -s -o /dev/null -w '  ShinyProxy HTTP: %{http_code}\n' http://localhost:8080 || echo '  ShinyProxy: sin respuesta'
  ${REMOTE_DOCKER} ps --filter name=cgv-nginx --filter name=cgv-shinyproxy --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
"

# --- Paso 7: Lanzar Cloudflare tunnel ---
echo ""
echo "[7/7] Lanzando tunel Cloudflare (${TUNNEL_NAME})..."
echo "  IMPORTANTE: El tunel debe apuntar a localhost:${CGV_NGINX_PORT} (nginx -> ShinyProxy)"
echo "  Si antes apuntaba a localhost:3838 o localhost:80, actualiza la config en Cloudflare Dashboard."
echo ""
nssh "
  rm -f ${NAS_PATH}/tunnel.log
  nohup ${NAS_PATH}/cloudflared tunnel --protocol http2 run ${TUNNEL_NAME} > ${NAS_PATH}/tunnel.log 2>&1 &
  echo \$! > ${NAS_PATH}/tunnel.pid
  echo \"  Tunel PID: \$(cat ${NAS_PATH}/tunnel.pid)\"
  sleep 3
  if kill -0 \$(cat ${NAS_PATH}/tunnel.pid) 2>/dev/null; then
    echo '  Tunel corriendo OK'
  else
    echo '  ERROR: Tunel no arranco'
    tail -5 ${NAS_PATH}/tunnel.log
  fi
"

echo ""
echo "============================================"
echo "  ShinyProxy Deploy completado!"
echo ""
echo "  Local NAS:   http://${NAS_HOST}:8080"
echo "  Proxy web:   http://${NAS_HOST}:${CGV_NGINX_PORT}"
echo "  Publico:     https://cgvapp.com"
echo ""
echo "  Login:       desactivado (acceso directo, limitado por capacidad)"
echo ""
echo "  Usuarios simultaneos: $(local_env_value SP_MAX_TOTAL_INSTANCES 5) max (2GB RAM c/u por defecto)"
echo ""
echo "  RECUERDA actualizar Cloudflare Tunnel:"
echo "    Zero Trust -> Networks -> Tunnels -> cgv"
echo "    Public Hostname -> apuntar a localhost:${CGV_NGINX_PORT}"
echo "============================================"
