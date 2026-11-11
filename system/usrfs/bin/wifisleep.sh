#!/bin/sh
# wifisleep.sh — ночное отключение Wi-Fi радио по расписанию.
# Конфиг /jrd-resource/wifisleep.conf:
#   ENABLED=1
#   START=01:00
#   END=07:00        (END <= START пересекает полночь — поддерживается)
# Механика: ifconfig wlan0 down/up — hostapd продолжает работать,
# клиенты отваливаются, радио молчит. Маркер /tmp/wifisleep.off
# защищает от повторных вызовов.
# Вызывается из cron ежеминутно; wifi.cgi вызывает сразу после сохранения.
CONF=/jrd-resource/wifisleep.conf
MARK=/tmp/wifisleep.off
IFACE=wlan0

ENABLED=0
START=01:00
END=07:00
[ -f "$CONF" ] && . "$CONF"

in_window() {
    [ "$ENABLED" = "1" ] || return 1
    now=$(date +%H:%M)
    if [ "$START" -le "$END" ] 2>/dev/null; then
        # ash: строки "HH:MM" сравниваются лексикографически корректно
        [ "$now" \> "$START" ] && [ ! "$now" \> "$END" ] && return 0
        [ "$now" = "$START" ] && return 0
    else
        [ "$now" \> "$START" ] && return 0
        [ ! "$now" \> "$END" ] && return 0
    fi
    return 1
}

if in_window; then
    if [ ! -f "$MARK" ]; then
        ifconfig "$IFACE" down 2>/dev/null
        touch "$MARK"
        logger -t wifisleep "radio off (schedule $START-$END)"
    fi
else
    if [ -f "$MARK" ]; then
        rm -f "$MARK"
        ifconfig "$IFACE" up 2>/dev/null
        logger -t wifisleep "radio on (schedule end)"
    fi
fi
exit 0
