#!/bin/sh
# signal.cgi — Signal quality read-only endpoints
# All actions are GET-only, no CSRF needed
echo "Content-Type: application/json"
echo ""

. /jrd-resource/resource/webrc/www/cgi-bin/lib/cgi-common.sh

# Seconds to hold the modem node open (see the `ca` action).
AT_READ_TIMEOUT=3

ACTION="${QUERY_STRING%%&*}"
ACTION="${ACTION#action=}"

case "$ACTION" in

current)
    # Read signal info from /tmp/signal_current.txt
    # Written by signal_poll helper (or traffic_stats)
    # Format: KEY=VALUE per line
    FILE="/tmp/signal_current.txt"
    if [ ! -f "$FILE" ]; then
        printf '{"error":"signal data not available"}'
        exit 0
    fi
    awk -F= '
        /^#/ { next }
        NF >= 2 {
            key = $1
            val = $2
            for (i = 3; i <= NF; i++) val = val "=" $i
            print key "\t" val
        }
    ' "$FILE" | jq -nR '
        [inputs | split("\t") |
            {(.[0]): (.[1] // "" | (tonumber? // .))}
        ] | add // {}'
    ;;

history)
    # Return signal history ring buffer
    FILE="/tmp/signal_history.json"
    if [ -f "$FILE" ]; then
        cat "$FILE"
    else
        echo "[]"
    fi
    ;;

ca)
    # Carrier aggregation info. Реальный опрос (AT$QCRSRP? + AT$QCCAINFO?)
    # делает фоновый signal_ca_poller — он пишет /tmp/signal_ca.json каждые
    # 5 секунд. CGI отдаёт кэш мгновенно; если кэш протух (>12с) или поллер
    # не запущен — делаем одиночный опрос синхронно (займёт ~2-4с).
    CACHE=/tmp/signal_ca.json
    NOW=$(date +%s 2>/dev/null || echo 0)
    MTIME=0
    [ -f "$CACHE" ] && MTIME=$(stat -c %Y "$CACHE" 2>/dev/null || echo 0)

    if [ -f "$CACHE" ] && [ $((NOW - MTIME)) -lt 12 ]; then
        cat "$CACHE"
        exit 0
    fi

    # Кэш протух — синхронный добор (bounded, webs не зависнет дольше ~8с)
    if [ -x /usr/bin/signal_ca_poller ]; then
        run_timeout 8 /usr/bin/signal_ca_poller once >/dev/null 2>&1
    fi

    if [ -f "$CACHE" ]; then
        cat "$CACHE"
    else
        printf '{"error":"CA data unavailable (poller missing?)"}'
    fi
    exit 0
    ;;

*)
    printf '{"error":"unknown action"}'
    ;;
esac
