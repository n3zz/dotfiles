#!/usr/bin/env bash
# screenshot.sh region|window|output|all|edit
#   saves to ~/Pictures/Screenshots, copies to clipboard, notifies with Edit / Open
set -uo pipefail

dir="$HOME/Pictures/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
mode="${1:-region}"

case "$mode" in
  region | edit) geom=$(slurp -d -b 00000066 -c ffffffcc -w 2) || exit 0 ;;
  window) geom=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"') ;;
  output) out=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name') ;;
  all) ;;
  *) echo "usage: $0 region|window|output|all|edit" >&2; exit 1 ;;
esac

# straight into the editor
if [[ "$mode" == edit ]]; then
  grim -g "$geom" - | satty --filename - --output-filename "$file" --copy-command wl-copy --early-exit
  exit 0
fi

case "$mode" in
  region | window) grim -g "$geom" "$file" ;;
  output) grim -o "$out" "$file" ;;
  all) grim "$file" ;;
esac
[[ -s "$file" ]] || exit 1

wl-copy --type image/png <"$file"

# notification with actions; runs in the background so the keybind returns immediately
(
  action=$(notify-send -a Screenshot -i "$file" -e -A edit=Edit -A open=Open \
    "Screenshot saved" "$(basename "$file") · copied to clipboard")
  case "$action" in
    edit) satty --filename "$file" --output-filename "$file" --copy-command wl-copy ;;
    open) xdg-open "$file" ;;
  esac
) &
disown
