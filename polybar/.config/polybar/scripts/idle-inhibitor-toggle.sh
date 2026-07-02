#!/usr/bin/env bash

STATE_FILE="$HOME/.cache/idle-inhibitor-state"

if [ -f "$STATE_FILE" ]; then
  rm "$STATE_FILE"
  xset s on +dpms
  notify-send "Idle inhibitor" "Screensaver/DPMS re-enabled"
else
  touch "$STATE_FILE"
  xset s off -dpms
  notif-send "Idle inhhibitor" "Screensaver/DPMS disabled"
fi
