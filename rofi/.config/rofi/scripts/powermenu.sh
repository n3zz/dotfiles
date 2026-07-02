#!/usr/bin/env bash

# Options with icons (requires a Nerd Font, which you already use)

lock=" Lock"
logout=" Logout"
suspend=" Suspend"
restart=" Restart"
shutdown=" Shutdown"

# Rofi menu
options="$lock\n$logout\n$suspend\n$restart\n$shutdown"

chosen=$(echo -e "$options" | rofi -dmenu -i -p "Power" -theme ~/.config/rofi/powermenu.rasi)

case $chosen in
"$lock")
  betterlockscreen -l
  ;;
"$logout")
  i3-msg exit
  ;;
"$suspend")
  betterlockscreen -l &
  systemctl suspend
  ;;
"$restart")
  systemctl reboot
  ;;
"$shutdown")
  systemctl poweroff
  ;;
esac
