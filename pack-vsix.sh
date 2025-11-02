#!/usr/bin/env bash
# pack-vsix.sh
# Pack downloaded .vsix files into a timestamped zip for offline distribution.
# Usage:
#   ./pack-vsix.sh                 # pack ./*.vsix -> vscode-extensions-<ts>.zip
#   ./pack-vsix.sh /path/to/dir    # pack /path/to/dir/*.vsix
#   ./pack-vsix.sh /path/to/dir out.zip
#   ./pack-vsix.sh /path/to/dir out.zip --rm-source   # remove .vsix after creating zip
#
set -euo pipefail
IFS=$'\n\t'

usage() {
  cat <<EOF
Usage:
  $0 [src_dir] [out_zip] [--rm-source]
Examples:
  $0
  $0 ./downloads
  $0 ./downloads my-plugins.zip
  $0 ./downloads my-plugins.zip --rm-source
EOF
  exit 1
}

# defaults
SRC_DIR="."
OUT_ZIP=""
RM_SOURCE=0

# parse args
if [[ ${#@} -gt 3 ]]; then
  usage
fi

if [[ ${#@} -ge 1 ]]; then
  case "$1" in
  -h | --help) usage ;;
  --*) usage ;;
  *)
    if [[ -d "$1" ]]; then
      SRC_DIR="$1"
      shift || true
    elif [[ "$1" == "--rm-source" ]]; then
      RM_SOURCE=1
      shift || true
    else
      # if first arg is not a dir but file (rare), treat as dir anyway
      SRC_DIR="$1"
      shift || true
    fi
    ;;
  esac
fi

if [[ ${#@} -ge 1 ]]; then
  if [[ "$1" == "--rm-source" ]]; then
    RM_SOURCE=1
    shift || true
  else
    OUT_ZIP="$1"
    shift || true
  fi
fi

if [[ ${#@} -ge 1 ]]; then
  if [[ "$1" == "--rm-source" ]]; then
    RM_SOURCE=1
    shift || true
  fi
fi

# normalize SRC_DIR
SRC_DIR="$(cd "$SRC_DIR" && pwd)"

# find vsix files (non-recursive). If you want recursive, change -maxdepth to larger
mapfile -t VSIX_FILES < <(find "$SRC_DIR" -maxdepth 1 -type f -name "*.vsix" -print)

if [[ ${#VSIX_FILES[@]} -eq 0 ]]; then
  echo "No .vsix files found in ${SRC_DIR}" >&2
  exit 2
fi

# default out zip if not provided
if [[ -z "$OUT_ZIP" ]]; then
  ts=$(date -u +"%Y%m%dT%H%M%SZ")
  OUT_ZIP="vscode-extensions-${ts}.zip"
fi

# create temp workdir to avoid storing full paths inside zip
TMPDIR=$(mktemp -d)
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

# copy vsix files (preserve filename)
for f in "${VSIX_FILES[@]}"; do
  cp -p "$f" "$TMPDIR/"
done

# create zip (overwrite if exists)
if command -v zip >/dev/null 2>&1; then
  (cd "$TMPDIR" && zip -r -q "$OLDPWD/$OUT_ZIP" .)
else
  # fallback to python zip (portable)
  python3 - - "$TMPDIR" "$OUT_ZIP" <<PY
import sys, os, zipfile
tmp = sys.argv[1]
out = sys.argv[2]
with zipfile.ZipFile(out, 'w', compression=zipfile.ZIP_DEFLATED) as z:
    for name in os.listdir(tmp):
        path = os.path.join(tmp, name)
        if os.path.isfile(path):
            z.write(path, arcname=name)
print(out)
PY
fi

OUT_ABS="$(
  cd "$(dirname "$OUT_ZIP")" 2>/dev/null || true
  pwd
)/$(basename "$OUT_ZIP")"
echo "Created zip: ${OUT_ABS}"

if [[ "$RM_SOURCE" -eq 1 ]]; then
  echo "Removing source .vsix files from ${SRC_DIR}..."
  for f in "${VSIX_FILES[@]}"; do
    rm -f "$f"
  done
  echo "Source files removed."
fi

exit 0
