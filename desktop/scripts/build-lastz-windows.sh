#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_PATH="$(cygpath -u "$1")"
OUTPUT_PATH="$(cygpath -u "$2")"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

export PATH="/mingw64/bin:${PATH}"
tar -xzf "${ARCHIVE_PATH}" -C "${WORK_DIR}"
SOURCE_DIR="$(find "${WORK_DIR}" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
if [[ -z "${SOURCE_DIR}" ]]; then
  echo "ERROR: LASTZ source directory was not extracted." >&2
  exit 1
fi

cd "${SOURCE_DIR}/src"
sed -i 's/ -lm -o \$@/ $(LDFLAGS) -lm -lmman -o \$@/g' Makefile
make clean
make lastz \
  CC=gcc \
  'definedForAll=-Wall -Wextra -DcompileForWindows -D_FILE_OFFSET_BITS=64 -D_LARGEFILE_SOURCE' \
  'LDFLAGS=-static -L/mingw64/lib'
make test

DEPENDENCIES="$(objdump -p lastz.exe | sed -n 's/^[[:space:]]*DLL Name: //p')"
if grep -Eiq 'msys-2\.0|cygwin1|libmman|libgcc|libstdc\+\+|libwinpthread' <<<"${DEPENDENCIES}"; then
  echo "ERROR: LASTZ has a non-portable runtime dependency:" >&2
  echo "${DEPENDENCIES}" >&2
  exit 1
fi

mkdir -p "$(dirname "${OUTPUT_PATH}")"
cp lastz.exe "${OUTPUT_PATH}"
VERSION_OUTPUT="$("${OUTPUT_PATH}" --version 2>&1 || true)"
grep -F "version 1.04.52" <<<"${VERSION_OUTPUT}"
