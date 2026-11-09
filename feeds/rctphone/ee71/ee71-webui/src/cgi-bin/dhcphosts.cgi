#!/bin/sh
# dhcphosts.cgi — статические DHCP-аренды (dnsmasq --dhcp-hostsfile=/etc/dhcp_hosts).
#
# GET  action=list -> {ok, static:[{mac,ip,name}], leases:[{mac,ip,name}]}
# POST action=add mac=xx:xx:xx:xx:xx:xx ip=192.168.8.N name=optional
# POST action=del mac=xx:xx:xx:xx:xx:xx
# POST action=save static=[...] (полная замена списка — из UI)
# После записи: SIGHUP dnsmasq (перечитывает dhcp-hosts без разрыва leases).
echo "Content-Type: application/json"
echo ""

HOSTS=/etc/dhcp_hosts
LEASES=/var/lib/misc/dnsmasq.leases

. /jrd-resource/resource/webrc/www/cgi-bin/lib/cgi-common.sh
csrf_check

is_mac() {
    case "$1" in
        [0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]:[0-9a-f][0-9a-f]) return 0 ;;
        *) return 1 ;;
    esac
}
is_ipv4() {
    case "$1" in *[!0-9.]*|"") return 1 ;; esac
    OLDIFS=$IFS; IFS=.
    set -- $1; IFS=$OLDIFS
    [ "$#" -eq 4 ] || return 1
    for p in "$@"; do [ "$p" -le 255 ] 2>/dev/null || return 1; done
    return 0
}

json_str() { echo "$1" | sed -n 's/.*"'"$2"'"[ :]*"\([^"]*\)".*/\1/p'; }

ACTION=""
BODY=""
[ "$REQUEST_METHOD" = "POST" ] && BODY=$(cat 2>/dev/null)
ACTION=$(json_str "$BODY" action)
[ -z "$ACTION" ] && ACTION=$(echo "$QUERY_STRING" | sed -n 's/.*action=\([^&]*\).*/\1/p')

emit_list() {
    S="["; first=1
    if [ -f "$HOSTS" ]; then
        while IFS=, read -r mac ip name rest; do
            [ -n "$mac" ] || continue
            case "$mac" in \#*) continue ;; esac
            [ $first -eq 0 ] && S="$S,"
            first=0
            S="$S{\"mac\":\"$mac\",\"ip\":\"$ip\",\"name\":\"$name\"}"
        done < "$HOSTS"
    fi
    S="$S]"
    L="["; first=1
    if [ -f "$LEASES" ]; then
        while read -r exp mac ip name rest; do
            [ $first -eq 0 ] && L="$L,"
            first=0
            L="$L{\"mac\":\"$mac\",\"ip\":\"$ip\",\"name\":\"$name\"}"
        done < "$LEASES"
    fi
    L="$L]"
    echo "{\"ok\":true,\"static\":$S,\"leases\":$L}"
}

case "$ACTION" in
    list) emit_list ;;
    add)
        MAC=$(json_str "$BODY" mac | tr 'A-F' 'a-f')
        IP=$(json_str "$BODY" ip)
        NAME=$(json_str "$BODY" name | tr -cd 'A-Za-z0-9_-')
        is_mac "$MAC" || { echo '{"ok":false,"error":"bad mac"}'; exit 0; }
        is_ipv4 "$IP" || { echo '{"ok":false,"error":"bad ip"}'; exit 0; }
        # IP вне LAN-подсети роутера отсекаем (bridge0 = 192.168.8.1/24)
        case "$IP" in
            192.168.8.[2-9]|192.168.8.[1-9][0-9]|192.168.8.1[0-9][0-9]|192.168.8.2[0-4][0-9]|192.168.8.25[0-4]) ;;
            *) echo '{"ok":false,"error":"ip must be in 192.168.8.2-254 (router address and broadcast excluded)"}'; exit 0 ;;
        esac
        # дубликат MAC -> замена
        if [ -f "$HOSTS" ]; then
            grep -v -i "^$MAC," "$HOSTS" > /tmp/dh.$$ 2>/dev/null || touch /tmp/dh.$$
        else
            touch /tmp/dh.$$
        fi
        echo "$MAC,$IP${NAME:+,$NAME}" >> /tmp/dh.$$
        sort -o /tmp/dh.$$ /tmp/dh.$$ 2>/dev/null
        mv /tmp/dh.$$ "$HOSTS"
        kill -HUP "$(pidof dnsmasq | awk '{print $1}')" 2>/dev/null
        echo '{"ok":true}'
        ;;
    del)
        MAC=$(json_str "$BODY" mac | tr 'A-F' 'a-f')
        is_mac "$MAC" || { echo '{"ok":false,"error":"bad mac"}'; exit 0; }
        if [ -f "$HOSTS" ]; then
            # grep -v выходит с 1, если не осталось ни одной строки —
            # не давать этому прервать удаление последней записи
            grep -v -i "^$MAC," "$HOSTS" > /tmp/dh.$$ 2>/dev/null || true
            mv /tmp/dh.$$ "$HOSTS"
        fi
        kill -HUP "$(pidof dnsmasq | awk '{print $1}')" 2>/dev/null
        echo '{"ok":true}'
        ;;
    *)
        echo '{"ok":false,"error":"unknown action"}'
        ;;
esac
