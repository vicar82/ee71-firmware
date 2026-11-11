#!/bin/sh
# bandpref.cgi — LTE-диапазоны: правдивое отображение.
#
# История: кастомная блокировка (QMI NAS set_syspref 0x33, слот lte_band_pref)
# оказалась неэффективной — набор диапазонов поставляет карьерный конфиг
# модема (mcfg autoselect по ICCID, NV /nv/item_files/modem/mmode/lte_bandpref),
# который перезаписывает любые записи при загрузке модема. Это установлено
# экспериментально: запись в NV напрямую переживала read-back, но после
# батарейки NV возвращался к стоковому значению (mcfg re-apply).
#
# Поэтому страница показывает РЕАЛЬНО используемые диапазоны из данных
# кэмпинга (/var/tmp/signal_ca.json, пишет signal_ca_poller раз в 5 с).
#
# GET action=get -> {ok, live:[bands...], ca:bool, cells:N, cells_list:[...]}
# POST set       -> ok:false (блокировка недоступна, см. выше)
echo "Content-Type: application/json"
echo ""

JSON=/var/tmp/signal_ca.json

. /jrd-resource/resource/webrc/www/cgi-bin/lib/cgi-common.sh
csrf_check

ACTION=""
MASK=""
if [ "$REQUEST_METHOD" = "POST" ]; then
    BODY=$(cat 2>/dev/null)
    ACTION=$(echo "$BODY" | sed -n 's/.*"action"[ :]*"\([^"]*\)".*/\1/p')
    MASK=$(echo "$BODY" | sed -n 's/.*"mask"[ :]*"\([^"]*\)".*/\1/p' | tr 'A-F' 'a-f' | tr -d 'x ')
else
    ACTION=$(echo "$QUERY_STRING" | sed -n 's/.*action=\([^&]*\).*/\1/p')
fi

case "$ACTION" in
    get)
        # если кэш протух (нет поллера — например сразу после загрузки),
        # делаем одиночный снимок
        if [ ! -f "$JSON" ] || [ -z "$(find "$JSON" -mmin -2 2>/dev/null)" ]; then
            run_timeout 10 /usr/bin/signal_ca_poller once >/dev/null 2>&1
        fi
        [ -f "$JSON" ] || { echo '{"ok":false,"error":"signal cache missing"}'; exit 0; }
        # разбор JSON средствами shell: bands и cells
        LIVE=$(tr -d ' \n' < "$JSON" | sed -n 's/.*"bands":\[\([^]]*\)\].*/\1/p' | tr ',' ' ')
        CA=$(tr -d ' \n' < "$JSON" | sed -n 's/.*"ca":\([a-z]*\).*/\1/p')
        CELLS=$(tr -d ' \n' < "$JSON" | sed -n 's/.*"cells":\[\(.*\)\],"bands".*/\1/p')
        N=0
        for b in $LIVE; do N=$((N+1)); done
        CALIST=""
        # каждая ячейка: {"type":"pcc","earfcn":X,"band":Y,"pci":Z,"rsrp":R}
        echo "$CELLS" | sed 's/},{/}\n{/g' | while read -r cell; do
            TYPE=$(echo "$cell" | sed -n 's/.*"type":"\([^"]*\)".*/\1/p')
            BAND=$(echo "$cell" | sed -n 's/.*"band":\([0-9]*\).*/\1/p')
            RSRP=$(echo "$cell" | sed -n 's/.*"rsrp":\([0-9.-]*\).*/\1/p')
            printf '{"type":"%s","band":%s,"rsrp":%s},' "$TYPE" "${BAND:-0}" "${RSRP:-null}"
        done > /tmp/bandpref_cells.tmp
        CALIST=$(cat /tmp/bandpref_cells.tmp 2>/dev/null)
        rm -f /tmp/bandpref_cells.tmp
        CALIST=${CALIST%,}
        CABOOL=false
        [ "$CA" = "true" ] && CABOOL=true
        echo "{\"ok\":true,\"live\":[$(echo $LIVE | tr ' ' ',')],\"ca\":$CABOOL,\"cells\":$N,\"cells_list\":[$CALIST]}"
        ;;
    set)
        echo '{"ok":false,"error":"Custom band lock unavailable: carrier config (mcfg) controls the band set and overwrites any value at modem boot."}'
        ;;
    *)
        echo '{"ok":false,"error":"unknown action"}'
        ;;
esac
