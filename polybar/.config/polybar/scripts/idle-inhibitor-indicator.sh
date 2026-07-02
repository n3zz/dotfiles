#!/usr/bin/env bash

STATE_FILE="$HOME/.cache/idle-inhibitor-state"

if [ -f "$STATE_FILE" ]; then
  printf '\uf023\n'
else
  printf '%%{F#565f89}\uf09c%%{F-}\n'
fi
