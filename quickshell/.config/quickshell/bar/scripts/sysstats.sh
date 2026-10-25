#!/usr/bin/env bash
# Emits one JSON line every 2s for the Quickshell bar; disk usage every ~30s.

# find the CPU temperature sensor once (AMD k10temp/zenpower or Intel coretemp)
ctemp_file=""
for h in /sys/class/hwmon/hwmon*; do
  case "$(cat "$h/name" 2>/dev/null)" in
    k10temp | zenpower | coretemp) ctemp_file="$h/temp1_input"; break ;;
  esac
done

disks_json() {
  # one entry per real device (btrfs subvolume mounts are de-duplicated)
  df -BG --output=source,target,pcent,used,size -x tmpfs -x devtmpfs -x efivarfs -x overlay 2>/dev/null |
    tail -n +2 |
    awk '!seen[$1]++ {
      gsub(/%/, "", $3); gsub(/G/, "", $4); gsub(/G/, "", $5)
      printf "%s{\"mount\":\"%s\",\"pct\":%d,\"used\":%d,\"size\":%d}", (n++ ? "," : ""), $2, $3, $4, $5
    }'
}

prev_total=0
prev_idle=0
i=0
while true; do
  # CPU usage from /proc/stat deltas
  read -r _ u n s id io irq sirq st _ </proc/stat
  idle=$((id + io))
  total=$((u + n + s + id + io + irq + sirq + st))
  dt=$((total - prev_total))
  di=$((idle - prev_idle))
  cpu=0
  ((dt > 0 && prev_total > 0)) && cpu=$((100 * (dt - di) / dt))
  prev_total=$total
  prev_idle=$idle

  mem=$(awk '/^MemTotal/ {t=$2} /^MemAvailable/ {a=$2} END {printf "%d", (t - a) * 100 / t}' /proc/meminfo)

  gutil=0 gtemp=0 vram=0
  if command -v nvidia-smi >/dev/null 2>&1; then
    IFS=', ' read -r gutil gtemp gmu gmt < <(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total \
      --format=csv,noheader,nounits 2>/dev/null | head -n1)
    [[ "$gmt" =~ ^[0-9]+$ ]] && ((gmt > 0)) && vram=$((100 * gmu / gmt))
  fi
  [[ "$gutil" =~ ^[0-9]+$ ]] || gutil=0
  [[ "$gtemp" =~ ^[0-9]+$ ]] || gtemp=0

  ctemp=0
  [[ -n "$ctemp_file" ]] && ctemp=$(($(cat "$ctemp_file") / 1000))

  net=$(nmcli -t -f TYPE,STATE device 2>/dev/null |
    awk -F: '$2 == "connected" && ($1 == "ethernet" || $1 == "wifi") {print $1; exit}')

  rec=0
  pgrep -f '^gpu-screen-recorder ' >/dev/null 2>&1 && rec=1

  printf '{"cpu":%d,"ctemp":%d,"mem":%d,"gpu":%d,"gtemp":%d,"vram":%d,"net":"%s","rec":%d}\n' \
    "$cpu" "$ctemp" "$mem" "$gutil" "$gtemp" "$vram" "$net" "$rec"

  if ((i % 15 == 0)); then
    echo "{\"disks\":[$(disks_json)]}"
  fi
  i=$((i + 1))
  sleep 2
done
