#!/usr/bin/env bash
# Rofi-based theme switcher: wallpaper-only, fixed themes, or pywal generation

THEMES_DIR="$HOME/.config/themes"
WALLPAPERS_DIR="$HOME/Wallpapers"
CACHE_DIR="$HOME/.cache/wal"

# Builds a rofi menu from a find command + prefix, returns the selected raw path/name
pick_wallpaper() {
  local file
  file=$(find -L "$WALLPAPERS_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -printf '%f\n' | rofi -dmenu -p "Wallpaper" -i)
  [ -z "$file" ] && return 1
  echo "$WALLPAPERS_DIR/$file"
}

pick_theme() {
  local name
  name=$(find -L "$THEMES_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | rofi -dmenu -p "Theme" -i)
  [ -z "$name" ] && return 1
  echo "$name"
}

main_choice=$(printf 'Wallpaper Only\nFixed Theme\nGenerate from Wallpaper' | rofi -dmenu -p "Switcher" -i)
[ -z "$main_choice" ] && exit 0

case "$main_choice" in
"Wallpaper Only")
  wallpaper_path=$(pick_wallpaper) || exit 0
  feh --bg-fill "$wallpaper_path"
  notify-send "Theme Switcher" "Wallpaper set: $(basename "$wallpaper_path")"
  ;;

"Fixed Theme")
  theme_name=$(pick_theme) || exit 0
  cp "$THEMES_DIR/$theme_name"/colors-* "$CACHE_DIR"/ 2>/dev/null
  case "$theme_name" in
  tokyo-night-storm) nvim_theme="tokyonight" ;;
  dracula) nvim_theme="dracula" ;;
  *) nvim_theme="tokyonight" ;;
  esac
  echo "$nvim_theme" >"$CACHE_DIR/nvim-colorscheme"
  "$HOME/.config/wal/postrun"
  notify-send "Theme Switcher" "Switched to: $theme_name"
  ;;

"Generate from Wallpaper")
  wallpaper_path=$(pick_wallpaper) || exit 0
  wal -i "$wallpaper_path" -o "$HOME/.config/wal/postrun"
  echo "neopywal" >"$CACHE_DIR/nvim-colorscheme"
  notify-send "Theme Switcher" "Applied wallpaper: $(basename "$wallpaper_path")"
  ;;
esac
