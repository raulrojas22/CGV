#!/usr/bin/env bash
#
# regenerar-instalables.sh
#
# Limpia INSTALABLES-FINALES/ y regenera TODOS los instalables de CGeV Desktop:
#   🍎 Mac arm64 + x64        (compilación local)
#   🐧 Linux AppImage + DEB   (GitHub Actions)
#   🪟 Windows Setup.exe      (GitHub Actions; firmado si SignPath ya está configurado)
#
# Al final genera SHA256SUMS.txt y firma todo con GPG (pide tu frase de contraseña).
#
# Requisitos previos:
#   - Estar en master, con master local == origin/master (haz push antes)
#   - gh autenticado (gh auth login)
#   - Runtimes Mac ya construidos en desktop/resources/r/
#     (si no: cd desktop && npm run runtime:mac:arm64 && npm run runtime:mac:x64)
#
# Uso:
#   ./regenerar-instalables.sh
#
# Omitir partes (opcional):
#   SKIP_MAC=1 SKIP_LINUX=1 SKIP_WINDOWS=1 SKIP_SIGN=1 ./regenerar-instalables.sh
#   CREATE_RELEASE_DRAFT=1 ./regenerar-instalables.sh  # publica Windows en un draft
#
# NOTA: para una versión NUEVA, primero cambia "version" en desktop/package.json,
#       commitea y haz push. El script crea y sube el tag desktop-vX.Y.Z solo.

set -euo pipefail

REPO="raulrojas22/CGV"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$ROOT_DIR/desktop"
FINAL_DIR="$ROOT_DIR/INSTALABLES-FINALES"
LOGS_DIR="$FINAL_DIR/logs"
cd "$ROOT_DIR"

say()  { printf "\n\033[1;36m== %s ==\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m✓ %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m⚠ %s\033[0m\n" "$*"; }
die()  { printf "\033[1;31m✗ %s\033[0m\n" "$*" >&2; exit 1; }

FAILURES=()

# ---------- 0. Verificaciones previas ----------
say "0. Verificaciones previas"

command -v gh   >/dev/null || die "Falta GitHub CLI (gh)."
command -v node >/dev/null || die "Falta node."
command -v npm  >/dev/null || die "Falta npm."
gh auth status >/dev/null 2>&1 || die "Ejecuta 'gh auth login' primero."

[ "$(git branch --show-current)" = "master" ] || die "Debes estar en la rama master."

VERSION=$(node -p "require('./desktop/package.json').version")
TAG="desktop-v$VERSION"

git fetch origin master --quiet
git fetch origin --tags --quiet
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/master)" ] \
  || die "master local y remoto difieren. Haz 'git push origin master' primero (Linux/Windows se construyen desde GitHub)."

if [ -n "$(git status --porcelain)" ]; then
  warn "Tienes cambios sin commitear. Linux/Windows se construyen desde el master REMOTO y NO los incluirán (Mac sí)."
  read -r -p "¿Continuar de todas formas? [y/N] " ans
  case "${ans:-}" in y|Y) ;; *) die "Abortado por el usuario." ;; esac
fi

ok "Repo listo. Versión a construir: $VERSION"

# ---------- 1. Limpiar carpeta final ----------
say "1. Limpiando INSTALABLES-FINALES"
rm -rf "$FINAL_DIR"
mkdir -p "$FINAL_DIR" "$LOGS_DIR"
ok "Carpeta limpia: $FINAL_DIR"

# ---------- helpers: identificar el run nuevo de este commit ----------
latest_workflow_run_id() {
  local workflow="$1" run_id
  run_id=$(gh run list --workflow "$workflow" --repo "$REPO" --limit 1 \
             --json databaseId --jq '.[0].databaseId // 0')
  [[ "$run_id" =~ ^[0-9]+$ ]] \
    || die "GitHub devolvió un ID de run inválido para $workflow: $run_id"
  printf '%s\n' "$run_id"
}

wait_for_run_id() {
  local workflow="$1" sha="$2" after_id="${3:-0}" run_id=""
  [[ "$after_id" =~ ^[0-9]+$ ]] || after_id=0

  for _ in $(seq 1 36); do
    run_id=$(gh run list --workflow "$workflow" --repo "$REPO" \
               --commit "$sha" --event workflow_dispatch --limit 1 \
               --json databaseId --jq '.[0].databaseId // empty') \
      || return 1
    if [[ "$run_id" =~ ^[0-9]+$ ]] && (( run_id > after_id )); then
      printf '%s\n' "$run_id"
      return 0
    fi
    sleep 5
  done
  return 1
}

HEAD_SHA=$(git rev-parse HEAD)
LINUX_RUN_ID=""
WINDOWS_RUN_ID=""

# ---------- 2. Lanzar Linux en GitHub Actions ----------
if [ "${SKIP_LINUX:-0}" != "1" ]; then
  say "2. Lanzando build de Linux en GitHub Actions"
  LINUX_PREVIOUS_RUN_ID=$(latest_workflow_run_id desktop-linux.yml)
  gh workflow run desktop-linux.yml --repo "$REPO" --ref master
  LINUX_RUN_ID=$(wait_for_run_id desktop-linux.yml "$HEAD_SHA" "$LINUX_PREVIOUS_RUN_ID") \
    || die "No apareció el run de Linux en GitHub."
  ok "Run Linux: https://github.com/$REPO/actions/runs/$LINUX_RUN_ID"
fi

# ---------- 3. Tag + lanzar Windows en GitHub Actions ----------
if [ "${SKIP_WINDOWS:-0}" != "1" ]; then
  say "3. Preparando tag $TAG y lanzando build de Windows"
  if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
    if [ "$(git rev-list -n 1 "$TAG")" = "$HEAD_SHA" ]; then
      git push origin "$TAG" --quiet 2>/dev/null || true
      ok "Tag $TAG ya existía y apunta a este commit."
    else
      die "El tag inmutable $TAG ya apunta a otro commit. Incrementa desktop/package.json y crea una versión nueva."
    fi
  else
    git tag "$TAG"
    git push origin "$TAG"
    ok "Tag $TAG creado y subido."
  fi
  WINDOWS_PREVIOUS_RUN_ID=$(latest_workflow_run_id desktop-windows-release.yml)
  DRAFT_INPUT=false
  [ "${CREATE_RELEASE_DRAFT:-0}" = "1" ] && DRAFT_INPUT=true
  gh workflow run desktop-windows-release.yml --repo "$REPO" --ref "$TAG" \
    -f create_release_draft="$DRAFT_INPUT"
  WINDOWS_RUN_ID=$(wait_for_run_id desktop-windows-release.yml "$HEAD_SHA" "$WINDOWS_PREVIOUS_RUN_ID") \
    || die "No apareció el run de Windows en GitHub."
  ok "Run Windows: https://github.com/$REPO/actions/runs/$WINDOWS_RUN_ID"
fi

# ---------- 4. Mac (local, mientras GitHub trabaja en paralelo) ----------
if [ "${SKIP_MAC:-0}" != "1" ]; then
  say "4. Compilando Mac arm64 + x64 (local, tarda ~30-40 min)"
  rm -rf "$DESKTOP_DIR/dist"
  mkdir -p "$DESKTOP_DIR/dist"
  if ! (cd "$DESKTOP_DIR" && npm run build:mac:arm64) 2>&1 \
       | tee "$LOGS_DIR/build-mac-arm64-$VERSION.log"; then
    FAILURES+=("mac-arm64"); warn "Falló el build mac-arm64 (ver log en $LOGS_DIR)."
  fi
  if ! (cd "$DESKTOP_DIR" && npm run build:mac:x64) 2>&1 \
       | tee "$LOGS_DIR/build-mac-x64-$VERSION.log"; then
    FAILURES+=("mac-x64"); warn "Falló el build mac-x64 (ver log en $LOGS_DIR)."
  fi
  for arch in arm64 x64; do
    for ext in dmg zip; do
      src="$DESKTOP_DIR/dist/CGeV-Desktop-$VERSION-macOS-$arch.$ext"
      if [ -f "$src" ]; then
        cp "$src" "$FINAL_DIR/"
        ok "Copiado $(basename "$src")"
      else
        FAILURES+=("missing:mac-$arch.$ext")
        warn "No se generó $(basename "$src")."
      fi
    done
  done
fi

# ---------- 5. Esperar Linux y descargar ----------
if [ -n "$LINUX_RUN_ID" ]; then
  say "5. Esperando build de Linux"
  if gh run watch "$LINUX_RUN_ID" --repo "$REPO" --exit-status --interval 30; then
    gh run download "$LINUX_RUN_ID" --repo "$REPO" \
      --name "CGeV-Desktop-Linux-x64-$VERSION" --dir "$FINAL_DIR"
    gh run view "$LINUX_RUN_ID" --repo "$REPO" --log > "$LOGS_DIR/build-linux-$VERSION.log" 2>/dev/null || true
    ok "Linux descargado (AppImage + DEB)."
  else
    FAILURES+=("linux")
    warn "El run de Linux falló: https://github.com/$REPO/actions/runs/$LINUX_RUN_ID"
  fi
fi

# ---------- 6. Esperar Windows y descargar ----------
if [ -n "$WINDOWS_RUN_ID" ]; then
  say "6. Esperando build de Windows (tarda ~35 min)"
  SIGNED=0
  if gh run watch "$WINDOWS_RUN_ID" --repo "$REPO" --exit-status --interval 60; then
    SIGNED=1
  else
    warn "El workflow de Windows terminó con fallo. Si SignPath aún no está configurado es ESPERADO: el instalador sin firmar igual se generó."
  fi
  gh run view "$WINDOWS_RUN_ID" --repo "$REPO" --log > "$LOGS_DIR/build-windows-$VERSION.log" 2>/dev/null || true

  if [ "$SIGNED" = "1" ]; then
    if gh run download "$WINDOWS_RUN_ID" --repo "$REPO" \
         --name "cgv-desktop-windows-signed-$VERSION" --dir "$FINAL_DIR"; then
      ok "Windows FIRMADO descargado."
    else
      FAILURES+=("windows"); warn "No se pudo descargar el artefacto firmado de Windows."
    fi
  else
    ART=$(gh api "repos/$REPO/actions/runs/$WINDOWS_RUN_ID/artifacts" \
          --jq '.artifacts[].name' 2>/dev/null | grep '^cgv-desktop-windows-unsigned-' | head -1 || true)
    if [ -n "$ART" ] && gh run download "$WINDOWS_RUN_ID" --repo "$REPO" --name "$ART" --dir "$FINAL_DIR"; then
      warn "Windows SIN FIRMA descargado (configura SignPath para obtener el firmado)."
    else
      FAILURES+=("windows"); warn "No se encontró instalador de Windows en el run."
    fi
  fi
fi

# ---------- 7. Checksums + firma GPG ----------
if [ "${SKIP_SIGN:-0}" != "1" ]; then
  say "7. Generando checksums y firmas GPG (pedirá tu frase de contraseña)"
  cd "$FINAL_DIR"
  shopt -s nullglob
  INSTALLABLES=(CGeV-Desktop-*.dmg CGeV-Desktop-*.zip CGeV-Desktop-*.AppImage CGeV-Desktop-*.deb CGeV-Desktop-*.exe)
  if [ "${#INSTALLABLES[@]}" -eq 0 ]; then
    warn "No hay instalables para firmar."
  else
    shasum -a 256 "${INSTALLABLES[@]}" > SHA256SUMS.txt
    for f in "${INSTALLABLES[@]}" SHA256SUMS.txt; do
      if gpg --armor --detach-sign "$f"; then
        ok "Firmado $f"
      else
        FAILURES+=("gpg:$f"); warn "Falló la firma de $f"
      fi
    done
    gpg --armor --export raulrojas22@icloud.com > CGV-GPG-public-key.asc 2>/dev/null || true
  fi
  cd "$ROOT_DIR"
fi

# ---------- 8. Resumen ----------
say "8. Resumen"
ls -lh "$FINAL_DIR"
echo
if [ "${#FAILURES[@]}" -eq 0 ]; then
  ok "TODO LISTO: instalables en $FINAL_DIR"
  ok "Logs de build guardados en $LOGS_DIR"
else
  warn "Completado con fallos en: ${FAILURES[*]}"
  warn "Revisa los logs en $LOGS_DIR"
  exit 1
fi
