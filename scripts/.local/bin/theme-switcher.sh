echo "SCRIPT STARTED: $(date)" >>/tmp/switcher-debug.log
#!/usr/bin/env bash
# Rofi-based theme switcher: fixed themes + pywal-generated wallpaper palettes

THEMES_DIR="$HOME/.config/themes"
WALLPAPERS_DIR="$HOME/Wallpapers"
CACHE_DIR="$HOME/.cache/wal"

declare -A display_map
menu=""

# Fixed themes — one entry per folder in ~/.config/themes/
while IFS= read -r dir; do
  name=$(basename "$dir")
  label="Theme: $name"
  display_map["$label"]="theme:$name"
  menu+="$label"$'\n'
done < <(find -L "$THEMES_DIR" -maxdepth 1 -mindepth 1 -type d)

# Wallpapers — one entry per image in ~/Wallpapers/
while IFS= read -r file; do
  name=$(basename "$file")
  label="Wallpaper: $name"
  display_map["$label"]="wallpaper:$file"
  menu+="$label"$'\n'
done < <(find -L "$WALLPAPERS_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \))

choice=$(printf '%s' "$menu" | rofi -dmenu -p "Theme" -i)
[ -z "$choice" ] && exit 0

selected="${display_map[$choice]}"
echo "CHOICE WAS: [$choice]" >>/tmp/switcher-debug.log
echo "SELECTED RESOLVED TO: [$selected]" >>/tmp/switcher-debug.log
[ -z "$selected" ] && exit 1

if [[ "$selected" == theme:* ]]; then
  theme_name="${selected#theme:}"
  cp "$THEMES_DIR/$theme_name"/colors-* "$CACHE_DIR"/ 2>/dev/null
  echo "tokyonight" >~/.cache/wal/nvim-colorscheme
  "$HOME/.config/wal/postrun"
  notify-send "Theme Switcher" "Switched to: $theme_name"

elif [[ "$selected" == wallpaper:* ]]; then
  wallpaper_path="${selected#wallpaper:}"
  wal -i "$wallpaper_path" -o "$HOME/.config/wal/postrun"
  echo "neopywal" >~/.cache/wal/nvim-colorscheme
  notify-send "Theme Switcher" "Applied Wallpaper: $(basename "$wallpaper_path")"
fi
