#!/bin/sh
# dns.cgi — DNS settings без перезагрузки роутера.
#
# В отличие от SetLanSettings (который ВСЕГДА перезагружает устройство,
# проверено опытом: даже с неизменными значениями), этот CGI пишет
# /jrd-resource/dns.conf и мгновенно перезапускает dnsmasq через
# /usr/bin/dnsmasq-apply. dnswatch остаётся страховочной сетью.
#
# Формат dns.conf (sh):
#   UPSTREAM="1.1.1.1 8.8.8.8"   # пусто = DNS оператора из /etc/resolv.conf
#   LAN_MODE="router"            # router | custom
#   LAN_DNS1="" LAN_DNS2=""      # при LAN_MODE=custom выдаются клиентам по DHCP
#
# GET/POST JSON:
#   action=get  -> {ok, upstream:"...", lan_mode:"...", lan_dns1:"", lan_dns2:""}
#   action=set upstream="1.1.1.1 8.8.8.8" lan_mode=router|custom lan_dns1=.. lan_dns2=..
#             -> валидирует, пишет conf, dnsmasq-apply, {ok:true}
echo "Content-Type: application/json"
echo ""

CONF=/jrd-resource/dns.conf

. /jrd-resource/resource/webrc/www/cgi-bin/lib/cgi-common.sh
csrf_check

is_ipv4() {
    case "$1" in
        *[!0-9.]*|"") return 1 ;;
    esac
    OLDIFS=$IFS; IFS=.
    set -- $1
    IFS=$OLDIFS
    [ "$#" -eq 4 ] || return 1
    for p in "$@"; do
        [ "$p" = "$(echo "$p" | sed 's/^0*//;s/^$/0/')" ] || return 1
        [ "$p" -le 255 ] 2>/dev/null || return 1
    done
    return 0
}

# вытащить строковое поле из JSON-тела
json_str() { # $1=body $2=key
    echo "$1" | sed -n 's/.*"'"$2"'"[ :]*"\([^"]*\)".*/\1/p'
}

ACTION=""
BODY=""
[ "$REQUEST_METHOD" = "POST" ] && BODY=$(cat 2>/dev/null)
[ -z "$ACTION" ] && ACTION=$(echo "$BODY$QUERY_STRING" | sed -n 's/.*"action"[ :]*"\([^"]*\)".*/\1/p')
[ -z "$ACTION" ] && ACTION=$(echo "$QUERY_STRING" | sed -n 's/.*action=\([^&]*\).*/\1/p')

case "$ACTION" in
    get)
        UPSTREAM=""; LAN_MODE="router"; LAN_DNS1=""; LAN_DNS2=""
        [ -f "$CONF" ] && . "$CONF"
        echo "{\"ok\":true,\"upstream\":\"$UPSTREAM\",\"lan_mode\":\"$LAN_MODE\",\"lan_dns1\":\"$LAN_DNS1\",\"lan_dns2\":\"$LAN_DNS2\"}"
        ;;
    set)
        UPSTREAM=$(json_str "$BODY" upstream | tr -s ' ')
        LAN_MODE=$(json_str "$BODY" lan_mode)
        LAN_DNS1=$(json_str "$BODY" lan_dns1 | tr -d ' ')
        LAN_DNS2=$(json_str "$BODY" lan_dns2 | tr -d ' ')
        case "$LAN_MODE" in router|custom) ;; *) echo '{"ok":false,"error":"lan_mode must be router|custom"}'; exit 0 ;; esac
        # валидация upstream-списка
        for ip in $UPSTREAM; do
            is_ipv4 "$ip" || { echo "{\"ok\":false,\"error\":\"bad upstream ip: $ip\"}"; exit 0; }
        done
        # не более 2 upstream
        [ "$(echo $UPSTREAM | wc -w)" -gt 2 ] && { echo '{"ok":false,"error":"max 2 upstream dns"}'; exit 0; }
        if [ "$LAN_MODE" = "custom" ]; then
            is_ipv4 "$LAN_DNS1" || { echo '{"ok":false,"error":"lan_dns1 invalid"}'; exit 0; }
            [ -n "$LAN_DNS2" ] && { is_ipv4 "$LAN_DNS2" || { echo '{"ok":false,"error":"lan_dns2 invalid"}'; exit 0; }; }
        else
            LAN_DNS1=""; LAN_DNS2=""
        fi
        {
            echo "UPSTREAM=\"$UPSTREAM\""
            echo "LAN_MODE=\"$LAN_MODE\""
            echo "LAN_DNS1=\"$LAN_DNS1\""
            echo "LAN_DNS2=\"$LAN_DNS2\""
        } > "$CONF"
        OUT=$(/usr/bin/dnsmasq-apply 2>&1)
        if [ $? -eq 0 ]; then
            echo "{\"ok\":true,\"applied\":true,\"detail\":\"$(echo "$OUT" | tail -1 | sed 's/"/'"'"'/g')\"}"
        else
            echo "{\"ok\":false,\"error\":\"apply failed: $(echo "$OUT" | tail -1 | sed 's/"/'"'"'/g')\"}"
        fi
        ;;
    *)
        echo '{"ok":false,"error":"unknown action"}'
        ;;
esac
