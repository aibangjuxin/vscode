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
