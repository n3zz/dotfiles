#!/usr/bin/env bash
# Rofi-based theme switcher: wallpaper-only, fixed themes (dark/light aware),
# or pywal generation (dark/light aware)

THEMES_DIR="$HOME/.config/themes"
WALLPAPERS_DIR="$HOME/Wallpapers"
CACHE_DIR="$HOME/.cache/wal"

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

pick_mode() {
  local choice
  choice=$(printf 'Light\nDark' | rofi -dmenu -p "Light or Dark side?")
  [ -z "$choice" ] && return 1
  echo "${choice,,}"
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
  requested_mode=$(pick_mode) || exit 0

  theme_mode=$(cat "$THEMES_DIR/$theme_name/mode" 2>/dev/null)

  if [ "$theme_mode" != "$requested_mode" ]; then
    notify-send "Theme Switcher" "$theme_name is $theme_mode-only, not $requested_mode"
    exit 1
  fi

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
  requested_mode=$(pick_mode) || exit 0

  if [ "$requested_mode" = "light" ]; then
    wal -l -n -i "$wallpaper_path" -o "$HOME/.config/wal/postrun"
  else
    wal -n -i "$wallpaper_path" -o "$HOME/.config/wal/postrun"
  fi

  feh --bg-fill "$wallpaper_path"

  echo "neopywal" >"$CACHE_DIR/nvim-colorscheme"
  notify-send "Theme Switcher" "Applied wallpaper: $(basename "$wallpaper_path") ($requested_mode)"
  ;;
esac
