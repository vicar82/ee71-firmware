#!/bin/sh
# power.cgi — питание и батарея: снимок + история разряда.
#
# GET action=snap -> {ok, ma, mv, mw, cap, status, on_battery, ts}
#   current_now fuel gauge в мкА (положительный = заряд/разряд по модели
#   PMIC, у данного устройства: на USB-питании +500мА; на батарее показывает
#   ток разряда со знаком плюс — сверено с фактом). voltage_now в мкВ.
# GET action=hist -> {ok, points: [[unixts, ma], ...]} — кольцевой буфер
#   /tmp/powerlog (cron: powerlog.sh раз в минуту, 720 точек = 12 ч).
echo "Content-Type: application/json"
echo ""

BATT=/sys/class/power_supply/battery
LOG=/tmp/powerlog

. /jrd-resource/resource/webrc/www/cgi-bin/lib/cgi-common.sh
csrf_check

ACTION=$(echo "$QUERY_STRING" | sed -n 's/.*action=\([^&]*\).*/\1/p')

now_ma() {
    c=$(cat "$BATT/current_now" 2>/dev/null)
    [ -z "$c" ] && c=0
    echo $((c / 1000))
}
now_mv() {
    v=$(cat "$BATT/voltage_now" 2>/dev/null)
    [ -z "$v" ] && v=0
    echo $((v / 1000))
}

case "$ACTION" in
    snap)
        MA=$(now_ma); MV=$(now_mv)
        MW=$((MA * MV / 1000))
        CAP=$(cat "$BATT/capacity" 2>/dev/null)
        ST=$(cat "$BATT/status" 2>/dev/null)
        ONBATT=0
        # usb supply offline => питаемся от батареи
        [ "$(cat /sys/class/power_supply/usb/online 2>/dev/null)" = "0" ] && ONBATT=1
        TS=$(date +%s)
        echo "{\"ok\":true,\"ma\":$MA,\"mv\":$MV,\"mw\":$MW,\"cap\":\"$CAP\",\"status\":\"$ST\",\"on_battery\":$ONBATT,\"ts\":$TS}"
        ;;
    hist)
        echo '{"ok":true,"points":['
        first=1
        [ -f "$LOG" ] && tail -n 720 "$LOG" | while read -r ts ma mv cap; do
            [ $first -eq 0 ] && printf ','
            first=0
            printf '[%s,%s]' "$ts" "$ma"
        done
        echo ']}'
        ;;
    *)
        echo '{"ok":false,"error":"unknown action"}'
        ;;
esac
