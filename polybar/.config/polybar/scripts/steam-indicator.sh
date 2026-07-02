#!/usr/bin/env bash
# Shows Steam icon when the Steam client is running
if pgrep -f "ubuntu12_32/steam" > /dev/null 2>&1; then
    printf '\uf1b6\n'
fi
