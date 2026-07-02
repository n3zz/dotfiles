#!/usr/bin/env bash
# Shows REC + active monitor while gpu-screen-recorder replay buffer is running
if pgrep -f "gpu-screen-recorder" > /dev/null 2>&1; then
    MONITOR=$(ps -eo args= | grep "gpu-screen-recorder" | grep -oP '(?<=-w )\S+')
    printf '\uf03d REC:%s\n' "$MONITOR"
fi
