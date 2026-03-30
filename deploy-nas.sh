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

# --- SSH multiplexing: UNA sola autenticacion para todo ---
SSH_SOCK="/tmp/deploy-nas-ssh-$$"
ssh -fNM -S "$SSH_SOCK" "${NAS_USER}@${NAS_HOST}"
trap 'ssh -S "$SSH_SOCK" -O exit "${NAS_USER}@${NAS_HOST}" 2>/dev/null' EXIT
nssh() { ssh -S "$SSH_SOCK" "${NAS_USER}@${NAS_HOST}" "$@"; }

echo "=============================="
echo "  CGV — Deploy to NAS"
echo "  https://cgvapp.com"
echo "=============================="
echo ""

# --- Paso 1: Sincronizar codigo ---
echo "[1/5] Sincronizando codigo al NAS..."
rsync -avz --progress --delete \
  -e "ssh -S $SSH_SOCK" \
  --exclude=annotations --exclude=genomes \
  --exclude=go_annotations --exclude=cache \
  --exclude=.git --exclude=.claude \
  --exclude=.codex_backups --exclude=.qodo \
  --exclude='*.docx' --exclude='.env.local' \
  "$LOCAL_APP" \
  "${NAS_USER}@${NAS_HOST}:${NAS_PATH}/app/"

# --- Paso 2: Detener tunel ---
echo ""
echo "[2/5] Deteniendo tunel Cloudflare..."
nssh "pid=\$(cat ${NAS_PATH}/tunnel.pid 2>/dev/null || echo ''); if [ -n \"\$pid\" ] && kill -0 \$pid 2>/dev/null; then kill \$pid && echo 'Tunel PID '\$pid' detenido'; else echo 'No habia tunel activo'; fi"

# --- Paso 3: Reconstruir imagen Docker ---
echo ""
echo "[3/5] Reconstruyendo imagen Docker en el NAS..."
nssh "cd ${NAS_PATH} && docker compose up -d --build"

# --- Paso 4: Esperar a que la app este healthy ---
echo ""
echo "[4/5] Esperando a que la app este healthy..."
nssh "
MAX=120; ELAPSED=0
while [ \$ELAPSED -lt \$MAX ]; do
  STATUS=\$(docker inspect --format='{{.State.Health.Status}}' cgv 2>/dev/null || echo 'unknown')
  if [ \"\$STATUS\" = 'healthy' ]; then
    echo \"  App healthy despues de \${ELAPSED}s\"
    break
  fi
  echo \"  Estado: \${STATUS} (\${ELAPSED}s/\${MAX}s)...\"
  sleep 5
  ELAPSED=\$((ELAPSED + 5))
done
HTTP=\$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3838 || echo '000')
echo \"  HTTP status: \$HTTP\"
docker ps --filter name=cgv --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
"

# --- Paso 5: Lanzar named tunnel ---
echo ""
echo "[5/5] Lanzando tunel Cloudflare (${TUNNEL_NAME})..."
nssh "
rm -f ${NAS_PATH}/tunnel.log
nohup ${NAS_PATH}/cloudflared tunnel run ${TUNNEL_NAME} > ${NAS_PATH}/tunnel.log 2>&1 &
echo \$! > ${NAS_PATH}/tunnel.pid
echo \"Tunel PID: \$(cat ${NAS_PATH}/tunnel.pid)\"
sleep 3
if kill -0 \$(cat ${NAS_PATH}/tunnel.pid) 2>/dev/null; then
  echo 'Tunel corriendo OK'
else
  echo 'ERROR: Tunel no arranco'
  tail -5 ${NAS_PATH}/tunnel.log
fi
"

echo ""
echo "=============================="
echo "  Deploy completado!"
echo "  Local:   http://${NAS_HOST}:3838"
echo "  Publico: https://cgvapp.com"
echo "=============================="
