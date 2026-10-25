#!/usr/bin/env bash
# theme-switcher.sh

WALLPAPER_DIR="$HOME/Wallpapers"

# --- Step 1: pick mode ---
MODE=$(printf "Wallpaper Only\nFixed Theme\nGenerate from Wallpaper" | wofi --dmenu --prompt "Theme Mode")

[ -z "$MODE" ] && exit 0

# --- Step 2: pick wallpaper ---
WALLPAPER=$(find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" \) |
  xargs -n1 basename |
  wofi --dmenu --prompt "Pick Wallpaper")

[ -z "$WALLPAPER" ] && exit 0

WALLPAPER_PATH="$WALLPAPER_DIR/$WALLPAPER"

# --- Step 3: apply wallpaper ---
hyprctl hyprpaper wallpaper ",$WALLPAPER_PATH,cover"

# --- Persist for next boot --- #
cat >"$HOME/.config/hypr/hyprpaper.conf" <<EOF
preload = $WALLPAPER_PATH
wallpaper = ,$WALLPAPER_PATH, cover
EOF

# --- Step 4: dispatch based on mode ---
case "$MODE" in
"Wallpaper Only")
  notify-send "Theme Switcher" "Wallpaper updated: $WALLPAPER" -i "$WALLPAPER_PATH"
  ;;

"Fixed Theme")
  THEME=$(printf "Tokyo Night Storm\nDracula" | wofi --dmenu --prompt "Pick Theme")
  [ -z "$THEME" ] && exit 0

  case "$THEME" in
  "Tokyo Night Storm")
    cp "$HOME/dotfiles/<path-to>/tokyonight-kitty.conf" "$HOME/.cache/wal/colors-kitty.conf"
    echo "tokyonight" >"$HOME/.cache/wal/nvim-colorscheme"
    ;;
  "Dracula")
    cp "$HOME/dotfiles/<path-to>/dracula-kitty.conf" "$HOME/.cache/wal/colors-kitty.conf"
    echo "dracula" >"$HOME/.cache/wal/nvim-colorscheme"
    ;;
  esac

  notify-send "Theme Switcher" "Applied fixed theme: $THEME" -i "$WALLPAPER_PATH"
  ;;
"Generate from Wallpaper")
  wal -i "$WALLPAPER_PATH" -n
  echo "neopywal" >"$HOME/.cache/wal/nvim-colorscheme"

  # Generate GTK-compatible color file for waybar/wofi
  {
    echo "@define-color background $(sed -n '1p' "$HOME/.cache/wal/colors");"
    echo "@define-color foreground $(sed -n '8p' "$HOME/.cache/wal/colors");"
    for i in $(seq 0 15); do
      line=$((i + 1))
      echo "@define-color color$i $(sed -n "${line}p" "$HOME/.cache/wal/colors");"
    done
  } >"$HOME/.cache/wal/colors-gtk.css"

  # Restart waybar to pick up new CSS
  pkill waybar
  waybar &

  notify-send "Theme Switcher" "Generated theme from wallpaper" -i "$WALLPAPER_PATH"
  ;;
esac
