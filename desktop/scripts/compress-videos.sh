#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROJECT_ROOT="$(cd "${DESKTOP_DIR}/.." && pwd)"

SCREENCAST_DIR="${PROJECT_ROOT}/www/screencasts"
CTV_VIDEO="${PROJECT_ROOT}/www/CTV_Animated.mp4"
BACKUP_DIR="${SCREENCAST_DIR}.orig"
CTV_BACKUP="${PROJECT_ROOT}/www/ctv_backup/CTV_Animated.mp4"

SCREENCAST_CRF="${CGV_VIDEO_CRF:-20}"
CTV_CRF="${CGV_CTV_CRF:-20}"
SCREENCAST_WIDTH="${CGV_VIDEO_WIDTH:-960}"
CTV_WIDTH="${CGV_CTV_WIDTH:-960}"

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ERROR: ffmpeg is required. Install with: brew install ffmpeg" >&2
  exit 1
fi

compress_video() {
  local input="$1"
  local output="$2"
  local width="$3"
  local fps="$4"
  local crf="$5"
  local label="$6"

  local orig_size
  orig_size=$(du -h "$input" | cut -f1)

  ffmpeg -y -loglevel error -i "$input" \
    -vf "scale=${width}:-2,fps=${fps}" \
    -c:v libx264 -crf "$crf" -preset medium \
    -an -movflags +faststart \
    "$output"

  local new_size
  new_size=$(du -h "$output" | cut -f1)

  local orig_bytes new_bytes pct
  orig_bytes=$(stat -f%z "$input" 2>/dev/null || stat -c%s "$input" 2>/dev/null)
  new_bytes=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
  if (( new_bytes >= orig_bytes )); then
    cp "$input" "$output"
    printf "  %-55s %6s -> %6s  (kept smaller original)\n" "$label" "$orig_size" "$orig_size"
    return
  fi
  pct=$(echo "scale=1; 100 - ($new_bytes * 100 / $orig_bytes)" | bc 2>/dev/null || echo "?")

  printf "  %-55s %6s -> %6s  (-%s%%)\n" "$label" "$orig_size" "$new_size" "$pct"
}

echo ""
echo "=== CGV Video Compression ==="
echo "  Screencast: ${SCREENCAST_WIDTH}w, 15fps, CRF ${SCREENCAST_CRF}"
echo "  CTV:        ${CTV_WIDTH}w, 24fps, CRF ${CTV_CRF}"
echo ""

# Restore originals from backup before compressing
if [[ -d "$BACKUP_DIR" ]]; then
  echo "[0/3] Restoring originals from backup ..."
  for video in "$BACKUP_DIR"/*.mp4; do
    [[ -f "$video" ]] || continue
    cp "$video" "$SCREENCAST_DIR/"
  done
else
  echo "[0/3] Creating backup ..."
  mkdir -p "$BACKUP_DIR"
  for video in "$SCREENCAST_DIR"/*.mp4; do
    [[ -f "$video" ]] || continue
    cp "$video" "$BACKUP_DIR/"
  done
fi

if [[ -f "$CTV_BACKUP" ]]; then
  cp "$CTV_BACKUP" "$CTV_VIDEO"
elif [[ -f "$CTV_VIDEO" ]]; then
  mkdir -p "$(dirname "$CTV_BACKUP")"
  cp "$CTV_VIDEO" "$CTV_BACKUP"
fi

echo ""
echo "[1/3] Compressing screencasts (${SCREENCAST_WIDTH}w, 15fps, CRF ${SCREENCAST_CRF}) ..."

screencast_count=0
for video in "$SCREENCAST_DIR"/*.mp4; do
  [[ -f "$video" ]] || continue
  filename=$(basename "$video")
  tmp_output="${video}.tmp.mp4"

  compress_video "$video" "$tmp_output" "$SCREENCAST_WIDTH" 15 "$SCREENCAST_CRF" "$filename"
  mv "$tmp_output" "$video"
  screencast_count=$((screencast_count + 1))
done

echo ""
echo "[2/3] Compressing CTV_Animated.mp4 (${CTV_WIDTH}w, 24fps, CRF ${CTV_CRF}) ..."

if [[ -f "$CTV_VIDEO" ]]; then
  ctv_tmp="${CTV_VIDEO}.tmp.mp4"
  compress_video "$CTV_VIDEO" "$ctv_tmp" "$CTV_WIDTH" 24 "$CTV_CRF" "CTV_Animated.mp4"
  mv "$ctv_tmp" "$CTV_VIDEO"
else
  echo "  WARNING: CTV_Animated.mp4 not found, skipping."
fi

echo ""
echo "=== Summary ==="

total_orig=0
total_new=0
for video in "$SCREENCAST_DIR"/*.mp4; do
  [[ -f "$video" ]] || continue
  total_new=$((total_new + $(stat -f%z "$video" 2>/dev/null || stat -c%s "$video" 2>/dev/null)))
done
if [[ -f "$CTV_VIDEO" ]]; then
  total_new=$((total_new + $(stat -f%z "$CTV_VIDEO" 2>/dev/null || stat -c%s "$CTV_VIDEO" 2>/dev/null)))
fi

total_orig_mb=$(echo "scale=1; $(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1 | sed 's/M//') " | bc 2>/dev/null || echo "?")
total_new_mb=$(echo "scale=1; $total_new / 1024 / 1024" | bc)

echo "  Screencasts compressed: ${screencast_count}"
echo "  Total compressed size:  ${total_new_mb} MB"
echo "  Originals backed up to: ${BACKUP_DIR}"
echo "  Restore with: cp -R ${BACKUP_DIR}/*.mp4 ${SCREENCAST_DIR}/"
echo ""
echo "Done."
