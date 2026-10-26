#!/bin/sh
# Copy the current wallpaper + wallust colours where the login screen (greeter user) can read them.
# Runs automatically via greeter-sync.path whenever the theme changes.
D=/var/lib/qs-greeter
[ -w "$D" ] || exit 0
W="$HOME/.cache/current-wallpaper"
C="$HOME/.cache/wal/Colours.qml"
if [ -e "$W" ]; then
	cp -fL "$W" "$D/.wallpaper.tmp" && mv -f "$D/.wallpaper.tmp" "$D/wallpaper"
fi
if [ -e "$C" ]; then
	cp -fL "$C" "$D/.Colours.tmp" && mv -f "$D/.Colours.tmp" "$D/Colours.qml"
fi
chmod 644 "$D/wallpaper" "$D/Colours.qml" 2>/dev/null
exit 0
