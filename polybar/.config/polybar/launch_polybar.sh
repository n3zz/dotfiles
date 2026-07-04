#!/usr/bin/env bash

# Kill any existing polybar instances before launching fresh ones
killall -q polybar
while pgrep -x polybar >/dev/null; do sleep 0.2; done

if type "xrandr"; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    MONITOR=$m polybar main &
  done
else
  polybar --reload main &
fi
