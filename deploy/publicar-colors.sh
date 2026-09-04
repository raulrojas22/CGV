#!/usr/bin/env bash
# Commit every local project change and deploy that exact commit to Colors.
set -euo pipefail

DEPLOY_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${DEPLOY_DIR}/.." && pwd)"

usage() {
  cat <<'USAGE'
Uso:
  ./deploy/publicar-colors.sh
  ./deploy/publicar-colors.sh "Descripción opcional del cambio"

Añade todos los cambios del proyecto, crea un commit y ejecuta el deploy seguro
de Colors. Si no hay cambios, despliega el commit actual sin crear uno vacío.
USAGE
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

COMMIT_MESSAGE="${*:-Actualización CGV $(date '+%Y-%m-%d %H:%M:%S')}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || \
  die "${REPO_ROOT} no es un repositorio Git"

CURRENT_BRANCH="$(git -C "$REPO_ROOT" branch --show-current)"
[[ -n "$CURRENT_BRANCH" ]] || \
  die "Git está en modo detached HEAD; cambia a una rama antes de publicar"

echo "[git] Añadiendo todos los cambios del proyecto..."
git -C "$REPO_ROOT" add -A
git -C "$REPO_ROOT" diff --cached --check

if git -C "$REPO_ROOT" diff --cached --quiet; then
  echo "[git] No hay cambios nuevos; se desplegará el commit actual."
else
  echo "[git] Creando commit: ${COMMIT_MESSAGE}"
  git -C "$REPO_ROOT" commit -m "$COMMIT_MESSAGE"
fi

echo "[deploy] Publicando el commit confirmado en Colors..."
exec "$DEPLOY_DIR/deploy-colors-shinyproxy.sh"
