#!/usr/bin/env bash
# theme-hypr.sh — wallpaper + theme switcher (awww edition)
#
#   theme-hypr.sh            interactive: pick mode, then wallpaper
#   theme-hypr.sh --random   random wallpaper + generate theme from it
#   theme-hypr.sh --set FILE set FILE as wallpaper + generate theme from it

set -uo pipefail

WALLPAPER_DIR="$HOME/Wallpapers"
WAL_CACHE="$HOME/.cache/wal"
THEMES_DIR="$HOME/.config/themes" # stowed from ~/dotfiles/themes
PICKER_THEME="$HOME/.config/rofi/wallpick.rasi"

TRANSITION=(--transition-type wipe --transition-angle 30
  --transition-duration 1.0 --transition-fps 144)

mkdir -p "$WAL_CACHE"

# ---------- helpers ----------

have() { command -v "$1" >/dev/null 2>&1; }

menu() { # menu "Prompt"  (reads options from stdin)
  if have rofi; then rofi -dmenu -i -p "$1"; else wofi --dmenu --prompt "$1"; fi
}

list_wallpapers() {
  find "$WALLPAPER_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' \
    -o -iname '*.png' -o -iname '*.webp' \) -printf '%f\n' | sort
}

pick_wallpaper() { # thumbnail grid with rofi, plain list with wofi
  if have rofi; then
    local theme_arg=()
    [[ -f "$PICKER_THEME" ]] && theme_arg=(-theme "$PICKER_THEME")
    list_wallpapers | while IFS= read -r f; do
      printf '%s\0icon\x1f%s\n' "$f" "$WALLPAPER_DIR/$f"
    done | rofi -dmenu -i -show-icons -p "" "${theme_arg[@]}"
  else
    list_wallpapers | wofi --dmenu --prompt "Pick Wallpaper"
  fi
}

ensure_daemon() {
  if ! awww query >/dev/null 2>&1; then
    awww-daemon >/dev/null 2>&1 &
    disown
    sleep 0.5
  fi
}

set_wallpaper() { # awww remembers the last image itself, no conf to persist
  ensure_daemon
  awww img "$1" "${TRANSITION[@]}"
  ln -sf "$1" "$HOME/.cache/current-wallpaper"
}

reload_waybar() { pgrep -x waybar >/dev/null && pkill -SIGUSR2 waybar; true; }

generate_theme() {
  wallust run -q "$1"
  echo "neopywal" >"$WAL_CACHE/nvim-colorscheme"

  # GTK-compatible colours for waybar/wofi/rofi
  {
    echo "@define-color background $(sed -n '1p' "$WAL_CACHE/colors");"
    echo "@define-color foreground $(sed -n '8p' "$WAL_CACHE/colors");"
    for i in $(seq 0 15); do
      echo "@define-color color$i $(sed -n "$((i + 1))p" "$WAL_CACHE/colors");"
    done
  } >"$WAL_CACHE/colors-gtk.css"

  reload_waybar
}

apply_fixed() {
  case "$1" in
  "Tokyo Night Storm")
    cp "$THEMES_DIR/tokyo-night-storm/colors-kitty.conf" "$WAL_CACHE/colors-kitty.conf"
    echo "tokyonight" >"$WAL_CACHE/nvim-colorscheme"
    ;;
  "Dracula")
    cp "$THEMES_DIR/dracula/colors-kitty.conf" "$WAL_CACHE/colors-kitty.conf"
    echo "dracula" >"$WAL_CACHE/nvim-colorscheme"
    ;;
  esac
}

notify() { notify-send "Theme Switcher" "$1" -i "$WALLPAPER_PATH"; }

# ---------- non-interactive ----------

if [[ "${1:-}" == "--random" ]]; then
  WALLPAPER_PATH="$WALLPAPER_DIR/$(list_wallpapers | shuf -n1)"
  set_wallpaper "$WALLPAPER_PATH"
  generate_theme "$WALLPAPER_PATH"
  notify "Random wallpaper + generated theme"
  exit 0
fi

if [[ "${1:-}" == "--set" && -f "${2:-}" ]]; then # used by the Quickshell picker
  WALLPAPER_PATH="$2"
  set_wallpaper "$WALLPAPER_PATH"
  generate_theme "$WALLPAPER_PATH"
  notify "Wallpaper + theme updated"
  exit 0
fi

# ---------- interactive ----------

MODE=$(printf "Wallpaper Only\nFixed Theme\nGenerate from Wallpaper" | menu "Theme Mode")
[[ -z "$MODE" ]] && exit 0

WALLPAPER=$(pick_wallpaper)
[[ -z "$WALLPAPER" ]] && exit 0
WALLPAPER_PATH="$WALLPAPER_DIR/$WALLPAPER"

set_wallpaper "$WALLPAPER_PATH"

case "$MODE" in
"Wallpaper Only")
  notify "Wallpaper updated: $WALLPAPER"
  ;;
"Fixed Theme")
  THEME=$(printf "Tokyo Night Storm\nDracula" | menu "Pick Theme")
  [[ -z "$THEME" ]] && exit 0
  apply_fixed "$THEME"
  notify "Applied fixed theme: $THEME"
  ;;
"Generate from Wallpaper")
  generate_theme "$WALLPAPER_PATH"
  notify "Generated theme from wallpaper"
  ;;
esac
