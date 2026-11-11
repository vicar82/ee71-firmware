#!/bin/sh
# powerlog.sh — минутный снимок тока/напряжения в кольцевой буфер /tmp/powerlog.
# cron: * * * * * /usr/bin/powerlog.sh
BATT=/sys/class/power_supply/battery
LOG=/tmp/powerlog
MAX=720

[ -d "$BATT" ] || exit 0
c=$(cat "$BATT/current_now" 2>/dev/null) || exit 0
v=$(cat "$BATT/voltage_now" 2>/dev/null)
cap=$(cat "$BATT/capacity" 2>/dev/null)
[ -z "$c" ] && exit 0
echo "$(date +%s) $((c / 1000)) $((v / 1000)) $cap" >> "$LOG"
# обрезка сверху при переполнении
n=$(wc -l < "$LOG")
[ "$n" -gt "$MAX" ] && tail -n "$MAX" "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
