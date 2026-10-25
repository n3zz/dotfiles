#!/usr/bin/env bash
# Save the replay buffer (last REPLAYDURATION seconds) to ~/Videos/Clips
if pgrep -f '^gpu-screen-recorder ' >/dev/null; then
  pkill -SIGUSR1 -f '^gpu-screen-recorder '
else
  notify-send -a Clips -i media-record "Replay buffer is off" "Turn on Clips in the notification centre"
fi
