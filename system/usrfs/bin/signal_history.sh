#!/bin/sh
# signal_history.sh — минутный снимок сигнала в кольцевой буфер /tmp/signallog.
# Формат строки: "ts band rsrp ca cells" (band/rsrp — PCC, CA — 0/1).
# cron: * * * * * /usr/bin/signal_history.sh
JSON=/var/tmp/signal_ca.json
LOG=/tmp/signallog
MAX=720

[ -f "$JSON" ] || exit 0
line=$(tr -d ' \n' < "$JSON")
band=$(echo "$line" | sed -n 's/.*"type":"pcc","earfcn":[0-9]*,"band":\([0-9]*\).*/\1/p')
rsrp=$(echo "$line" | sed -n 's/.*"type":"pcc".*"rsrp":\([0-9.-]*\).*/\1/p')
ca=$(echo "$line" | sed -n 's/.*"ca":\([a-z]*\).*/\1/p')
cells=$(echo "$line" | grep -o '"type"' | wc -l)
[ -z "$band" ] && exit 0
[ -z "$rsrp" ] && rsrp=0
[ "$ca" = "true" ] && ca=1 || ca=0
echo "$(date +%s) $band $rsrp $ca $cells" >> "$LOG"
n=$(wc -l < "$LOG")
[ "$n" -gt "$MAX" ] && tail -n "$MAX" "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"

exit 0
