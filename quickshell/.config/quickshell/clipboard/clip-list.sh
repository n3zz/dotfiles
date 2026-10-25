#!/usr/bin/env bash
# Emits one JSON object per clipboard entry (newest first) for the Quickshell clipboard picker.
# Image entries are decoded once into a thumbnail cache.
set -uo pipefail

cache="${XDG_CACHE_HOME:-$HOME/.cache}/qs-clipboard"
mkdir -p "$cache"

cliphist list | head -n 200 | while IFS=$'\t' read -r id preview; do
  if [[ "$preview" == "[[ binary data"* ]]; then
    f="$cache/$id.png"
    [[ -s "$f" ]] || printf '%s\t\n' "$id" | cliphist decode >"$f" 2>/dev/null
    jq -nc --arg id "$id" --arg img "$f" --arg info "$preview" '{id: $id, img: $img, info: $info}'
  else
    jq -nc --arg id "$id" --arg text "$preview" '{id: $id, text: $text}'
  fi
done

# drop thumbnails for entries that no longer exist
find "$cache" -name '*.png' -mtime +7 -delete 2>/dev/null
