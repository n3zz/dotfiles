#!/usr/bin/env bash
# Run by gpu-screen-recorder after a clip is saved: "$1" = file path
file="$1"
[[ -f "$file" ]] || exit 0

# thumbnail from the last frame, if ffmpeg is around
icon="video-x-generic"
if command -v ffmpeg >/dev/null; then
  thumb="${XDG_CACHE_HOME:-$HOME/.cache}/clip-thumbs/$(basename "$file").jpg"
  mkdir -p "$(dirname "$thumb")"
  ffmpeg -loglevel error -y -sseof -1 -i "$file" -frames:v 1 -vf scale=480:-1 "$thumb" && icon="$thumb"
fi

action=$(notify-send -a Clips -i "$icon" \
  -A default=Open -A folder="Show folder" -A copy="Copy to share" \
  "Clip saved" "$(basename "$file")")

case "$action" in
  default) xdg-open "$file" ;;
  folder) xdg-open "$(dirname "$file")" ;;
  copy) printf 'file://%s\n' "$file" | wl-copy -t text/uri-list ;;   # paste into Discord to upload
esac
