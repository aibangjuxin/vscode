# Shell Scripts Collection

Generated on: 2025-11-02 16:31:20
Directory: /Users/lex/git/vscode

## `download-vsix.sh`

```bash
#!/usr/bin/env bash
# download-vsix.sh
# Usage:
#   ./download-vsix.sh <publisher.extension> <version>
#   ./download-vsix.sh -f list.txt    # list.txt lines: publisher.extension@version
#
# Example:
#   ./download-vsix.sh GitHub.copilot 1.215.0
#   echo "GitHub.copilot@1.215.0" > list.txt
#   ./download-vsix.sh -f list.txt
#   ./download-vsix.sh GitHub.copilot 1.388.0

set -euo pipefail
IFS=$'\n\t'

USER_AGENT="vsix-downloader/1.0 (+https://example.com)"

download_one() {
  local item="$1" # publisher.extension
  local ver="$2"  # version
  local publisher extension url outname

  # parse publisher.extension (split on first dot)
  if [[ "$item" != *.* ]]; then
    echo "Invalid item name: '$item'. Expect format publisher.extension (e.g. GitHub.copilot)" >&2
    return 1
  fi

  publisher="${item%%.*}"
  extension="${item#*.}"

  outname="${publisher}.${extension}-${ver}.vsix"
  url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/${publisher}/vsextensions/${extension}/${ver}/vspackage"

  echo "Downloading ${publisher}.${extension} @ ${ver} ..."
  echo "  URL: ${url}"
  # Use curl with follow-redirects, show progress, and fail on HTTP errors
  if curl -fSL --progress-bar -A "$USER_AGENT" -o "${outname}" "${url}"; then
    echo "Saved -> ${outname}"
    return 0
  else
    echo "ERROR: failed to download ${item}@${ver}" >&2
    # remove partial file if exists
    rm -f "${outname}" || true
    return 2
  fi
}

print_usage() {
  cat <<EOF
Usage:
  $0 <publisher.extension> <version>
  $0 -f <file>
Examples:
  $0 GitHub.copilot 1.215.0
  echo "GitHub.copilot@1.215.0" > list.txt
  $0 -f list.txt
File format for -f: each non-empty line must be 'publisher.extension@version' (comments start with #)
EOF
}

# main
if [[ "${#@}" -eq 0 ]]; then
  print_usage
  exit 1
fi

if [[ "$1" == "-f" ]]; then
  if [[ "${#@}" -ne 2 ]]; then
    print_usage
    exit 1
  fi
  file="$2"
  if [[ ! -f "$file" ]]; then
    echo "File not found: $file" >&2
    exit 1
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"           # remove comment
    line="${line//[[:space:]]/}" # trim whitespace
    [[ -z "$line" ]] && continue
    if [[ "$line" != *@* ]]; then
      echo "Invalid line in $file: '$line'. Expect publisher.extension@version" >&2
      continue
    fi
    item="${line%@*}"
    ver="${line#*@}"
    download_one "$item" "$ver" || echo "Failed: $item@$ver" >&2
  done <"$file"
  exit 0
fi

# single mode
if [[ "${#@}" -ne 2 ]]; then
  print_usage
  exit 1
fi

item="$1"
ver="$2"
download_one "$item" "$ver"

```

## `pack-vsix.sh`

```bash
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

```

