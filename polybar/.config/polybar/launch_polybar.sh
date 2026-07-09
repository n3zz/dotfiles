#!/usr/bin/env bash
killall -q polybar
while pgrep -x polybar >/dev/null; do sleep 0.2; done

# Wait for xrandr to report at least one connected monitor
for i in $(seq 1 10); do
  MONITORS=$(xrandr --query | grep " connected" | cut -d" " -f1)
  [ -n "$MONITORS" ] && break
  sleep 0.3
done

if [ -n "$MONITORS" ]; then
  for m in $MONITORS; do
    MONITOR=$m polybar main &
  done
else
  polybar --reload main &
fi
