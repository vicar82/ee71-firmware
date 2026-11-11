#!/bin/sh
# ussd.cgi — USSD запросы через AT+CUSD
# POST {action:"send", cmd:"*102#"} → {ok, response}
# USSD-ответ может прийти с задержкой до ~10с (сеть гоняет сессию),
# поэтому окно чтения больше, чем у at.cgi.
echo "Content-Type: application/json"
echo ""

AT_DEV="/dev/smd7"
[ ! -c "$AT_DEV" ] && AT_DEV="/dev/smd11"
AT_READ_TIMEOUT=12

. /jrd-resource/resource/webrc/www/cgi-bin/lib/cgi-common.sh

case "$REQUEST_METHOD" in
POST)
    csrf_check
    read -r BODY
    ACTION=$(echo "$BODY" | jq -r '.action // empty')
    ;;
*)
    json_err "POST only"
    exit 0
    ;;
esac

case "$ACTION" in
send)
    CMD=$(echo "$BODY" | jq -r '.cmd // empty')
    # Только цифры, * и # — USSD-код, не произвольный AT
    case "$CMD" in
        *[!0-9\*#]*) json_err "invalid USSD code"; exit 0 ;;
    esac
    if [ ${#CMD} -lt 3 ] || [ ${#CMD} -gt 20 ]; then
        json_err "invalid USSD code length"
        exit 0
    fi

    if [ ! -c "$AT_DEV" ]; then
        json_err "AT device not found ($AT_DEV)"
        exit 0
    fi

    AT_OUT="/tmp/ussd_cgi_$$.out"
    # AT+CUSD=1,"код",15 — 15 = GSM-7 default alphabet dcs
    run_timeout "$AT_READ_TIMEOUT" sh -c '
        exec 3<>"$1" || exit 1
        printf "AT+CUSD=1,\"%s\",15\r" "$2" >&3
        exec cat <&3
    ' ussd_read "$AT_DEV" "$CMD" > "$AT_OUT" 2>/dev/null

    # Собираем все +CUSD: строки (ответ может прийти частями),
    # отсекаем служебный мусор (echo команды, OK, промпт)
    RESP=$(tr -d '\r' < "$AT_OUT" 2>/dev/null \
        | grep '^+CUSD:' \
        | sed 's/^+CUSD:[[:space:]]*[0-9]*\(,"\(.*\)"\)\{0,1\}.*/\2/' \
        | tr '\n' ' ' \
        | sed 's/[[:space:]]*$//')
    rm -f "$AT_OUT"

    if [ -z "$RESP" ]; then
        # Возможно сеть ответила "OK" без текста или сессия не открылась
        jq -n --arg cmd "$CMD" \
            '{"ok":true,"cmd":$cmd,"response":"(no USSD text in response)"}'
        exit 0
    fi

    jq -n --arg cmd "$CMD" --arg resp "$RESP" \
        '{"ok":true,"cmd":$cmd,"response":$resp}'
    ;;

*)
    json_err "unknown action"
    ;;
esac
