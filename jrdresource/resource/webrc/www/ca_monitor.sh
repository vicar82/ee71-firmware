#!/bin/sh
WEBROOT="/jrd-resource/resource/webrc/www"
OUT="$WEBROOT/ca.html"
ATPORT="/dev/smd7"
TMP=/tmp/ca_monitor
CELL_CACHE="/tmp/ca_cell_cache"
CACHE_ITER=0

# Kill any existing instances to avoid duplicates
for pid in $(pgrep -f ca_monitor.sh); do
  [ "$pid" = "$$" ] && continue
  kill "$pid" 2>/dev/null
done

get_band() {
  e=$(echo "$1" | sed 's/^0*//')
  [ -z "$e" ] && e=0
  if [ "$e" -ge 0 ] && [ "$e" -le 599 ]; then echo "B1"
  elif [ "$e" -ge 1200 ] && [ "$e" -le 1949 ]; then echo "B3"
  elif [ "$e" -ge 2750 ] && [ "$e" -le 3449 ]; then echo "B7"
  elif [ "$e" -ge 3450 ] && [ "$e" -le 3799 ]; then echo "B8"
  elif [ "$e" -ge 6150 ] && [ "$e" -le 6449 ]; then echo "B20"
  elif [ "$e" -ge 7500 ] && [ "$e" -le 7849 ]; then echo "B28"
  elif [ "$e" -ge 37750 ] && [ "$e" -le 38249 ]; then echo "B38"
  elif [ "$e" -ge 38650 ] && [ "$e" -le 39649 ]; then echo "B40"
  else echo "B?($1)"
  fi
}

get_bw() {
  earfcn=$1
  band=$(get_band "$earfcn")
  case "$band" in
    B1)  echo "~10 MHz" ;;
    B3)  echo "~20 MHz" ;;
    B7)  echo "~20 MHz" ;;
    B8)  echo "~10 MHz" ;;
    B20) echo "~10 MHz" ;;
    B28) echo "~10 MHz" ;;
    B38) echo "~20 MHz" ;;
    B40) echo "~20 MHz" ;;
    *)   echo "~?"      ;;
  esac
}

# Collect cell info (TAC, Cell ID, MCC/MNC) - cached every 60 iterations (~3 min)
collect_cell_info() {
  if [ $CACHE_ITER -gt 0 ] && [ $CACHE_ITER -lt 60 ]; then
    CACHE_ITER=$((CACHE_ITER + 1))
    return
  fi
  CACHE_ITER=1

  # CEREG for TAC and Cell ID
  rm -f /var/lock/LCK..smd7
  cereg=$(echo -e 'AT+CEREG=2\r' | microcom -d3000 -t1000 $ATPORT 2>/dev/null)
  rm -f /var/lock/LCK..smd7
  cereg=$(echo -e 'AT+CEREG?\r' | microcom -d3000 -t1000 $ATPORT 2>/dev/null)

  tac_hex=""
  cellid_hex=""
  tac_dec=""
  cellid_dec=""
  mcc=""
  mnc=""

  # Parse: +CEREG: 2,1,"234D","8","290CFAB",7
  line=$(echo "$cereg" | grep '+CEREG:' | head -1)
  if [ -n "$line" ]; then
    tac_hex=$(echo "$line" | sed -n 's/.*,"\([0-9A-Fa-f]*\)","\([0-9A-Fa-f]*\)","\([0-9A-Fa-f]*\)".*/\1/p')
    cellid_hex=$(echo "$line" | sed -n 's/.*,"\([0-9A-Fa-f]*\)","\([0-9A-Fa-f]*\)","\([0-9A-Fa-f]*\)".*/\3/p')
    if [ -n "$tac_hex" ]; then
      tac_dec=$(printf '%d' 0x$tac_hex 2>/dev/null)
    fi
    if [ -n "$cellid_hex" ]; then
      cellid_dec=$(printf '%d' 0x$cellid_hex 2>/dev/null)
    fi
  fi

  # CIMI for MCC/MNC
  rm -f /var/lock/LCK..smd7
  cimi=$(echo -e 'AT+CIMI\r' | microcom -d3000 -t1000 $ATPORT 2>/dev/null)
  cimi_line=$(echo "$cimi" | grep -E '^[0-9]{10,}' | head -1)
  if [ -n "$cimi_line" ]; then
    mcc=${cimi_line:0:3}
    mnc=${cimi_line:3:2}
  fi

  # Operator name from network (COPS)
  op_name=""
  rm -f /var/lock/LCK..smd7
  echo -e 'AT+COPS=3,0\r' | microcom -d3000 -t1000 $ATPORT >/dev/null 2>&1
  rm -f /var/lock/LCK..smd7
  cops=$(echo -e 'AT+COPS?\r' | microcom -d3000 -t1000 $ATPORT 2>/dev/null)
  cops_line=$(echo "$cops" | grep '+COPS:' | head -1)
  if [ -n "$cops_line" ]; then
    # Берём все кавыченные поля по очереди; первое не-цифровое — имя оператора
    for q in $(echo "$cops_line" | grep -o '"[^"]*"'); do
      v=$(echo "$q" | tr -d '"')
      case "$v" in
        ''|*[!0-9]*)
          if [ -z "$op_name" ]; then
            op_name="$v"
          elif [ "$v" != "$op_name" ] && [ -z "$(echo "$op_name" | grep -F -- "$v")" ]; then
            op_name="$op_name $v"
          fi
          ;;
      esac
    done
  fi

  # Try to get coordinates via wget or curl
  loc_str=""
  if [ -n "$mcc" ] && [ -n "$mnc" ] && [ -n "$cellid_dec" ]; then
    api_url="https://api.mylnikov.org/geolocation/cell?v=1.1&data=open&mcc=$mcc&mnc=$mnc&lac=$tac_dec&cellid=$cellid_dec"
    result=""
    if command -v wget >/dev/null 2>&1; then
      result=$(wget -q -O - --no-check-certificate --timeout=10 "$api_url" 2>/dev/null)
    elif command -v curl >/dev/null 2>&1; then
      result=$(curl -k -s --max-time 10 "$api_url" 2>/dev/null)
    fi
    if [ -n "$result" ]; then
      lat=$(echo "$result" | sed -n 's/.*"lat": *\([0-9.]*\).*/\1/p')
      lon=$(echo "$result" | sed -n 's/.*"lon": *\([0-9.]*\).*/\1/p')
      if [ -n "$lat" ] && [ -n "$lon" ]; then
        loc_str="<br><a href=\"https://yandex.ru/maps/?ll=$lon,$lat&z=16&pt=$lon,$lat\">Location: $lat, $lon</a>"
      fi
    fi
  fi

  # Write cache
  cat > "$CELL_CACHE" << CEEOF
$tac_hex|$tac_dec|$cellid_hex|$cellid_dec|$mcc|$mnc|$loc_str|$op_name
CEEOF
}

while true; do
  # Collect cell info (cached)
  collect_cell_info

  # Read cached cell info
  if [ -f "$CELL_CACHE" ]; then
    cache_line=$(cat "$CELL_CACHE")
    tac_hex=$(echo "$cache_line" | cut -d'|' -f1)
    tac_dec=$(echo "$cache_line" | cut -d'|' -f2)
    cellid_hex=$(echo "$cache_line" | cut -d'|' -f3)
    cellid_dec=$(echo "$cache_line" | cut -d'|' -f4)
    mcc=$(echo "$cache_line" | cut -d'|' -f5)
    mnc=$(echo "$cache_line" | cut -d'|' -f6)
    loc_str=$(echo "$cache_line" | cut -d'|' -f7)
    op_name=$(echo "$cache_line" | cut -d'|' -f8)
  else
    tac_hex=""; tac_dec=""; cellid_hex=""; cellid_dec=""; mcc=""; mnc=""; loc_str=""; op_name=""
  fi

  rm -f /var/lock/LCK..smd7
  rsrp_raw=$(echo -e 'AT$QCRSRP?\r' | microcom -d3000 -t1000 $ATPORT 2>/dev/null)
  rm -f /var/lock/LCK..smd7
  rsrq_raw=$(echo -e 'AT$QCRSRQ?\r' | microcom -d3000 -t1000 $ATPORT 2>/dev/null)

  rsrp_data=$(echo "$rsrp_raw" | grep 'QCRSRP:' | sed 's/.*QCRSRP: //' | tr -d '"' | tr -d ' ')
  rsrq_data=$(echo "$rsrq_raw" | grep 'QCRSRQ:' | sed 's/.*QCRSRQ: //' | tr -d '"' | tr -d ' ')

  if [ -z "$rsrp_data" ]; then
    sleep 5
    continue
  fi

  echo "$rsrp_data" | awk -F, '{
    for (i=1; i<=NF; i+=3) {
      e=$(i+1)
      if (!(e in seen)) {
        seen[e]=1
        print $i, $(i+1), $(i+2)
      }
    }
  }' > $TMP.rsrp

  echo "$rsrq_data" | awk -F, '{
    for (i=1; i<=NF; i+=3) {
      e=$(i+1)
      if (!(e in seen)) {
        seen[e]=1
        print $(i+2)
      }
    }
  }' > $TMP.rsrq

  ncells=$(wc -l < $TMP.rsrp)
  ncells=$(echo $ncells | tr -d ' ')

  ca_detail=""
  i=0
  rows=""
  while [ $i -lt $ncells ]; do
    line=$(sed -n "$((i+1))p" $TMP.rsrp)
    pci=$(echo "$line" | cut -d' ' -f1)
    earfcn=$(echo "$line" | cut -d' ' -f2)
    rsrp=$(echo "$line" | cut -d' ' -f3)
    rsrq=$(sed -n "$((i+1))p" $TMP.rsrq)
    [ -z "$rsrq" ] && rsrq="N/A"
    band=$(get_band "$earfcn")
    bw=$(get_bw "$earfcn")

    if [ $i -eq 0 ]; then
      label="PCell"
      ca_detail="$band"
    else
      label="SCell"
      ca_detail="$ca_detail + $band"
    fi

    rows="${rows}<tr><td>${label}</td><td><b>${band}</b></td><td>${pci}</td><td>${earfcn}</td><td>${rsrp} dBm</td><td>${rsrq} dB</td><td>${bw}</td></tr>"
    i=$((i+1))
  done

  if [ "$ncells" -gt 1 ]; then
    ca_status="AGGREGATION ACTIVE"
  else
    ca_status="NO AGGREGATION"
  fi

  now=$(date '+%H:%M:%S')

  # Build cell info line
  cell_info=""
  if [ -n "$tac_hex" ]; then
    cell_info="${cell_info}TAC: ${tac_hex} (${tac_dec})"
  fi
  if [ -n "$cellid_hex" ]; then
    cell_info="${cell_info} | Cell ID: ${cellid_hex} (${cellid_dec})"
  fi
  if [ -n "$mcc" ] && [ -n "$mnc" ]; then
    if [ -n "$op_name" ]; then
      cell_info="${cell_info} | Operator: ${op_name} (${mcc}/${mnc})"
    else
      cell_info="${cell_info} | MCC/MNC: ${mcc}/${mnc}"
    fi
  fi
  if [ -n "$loc_str" ]; then
    cell_info="${cell_info}${loc_str}"
  fi

  TMPHTML="${TMP}_html_tmp"
  cat > $TMPHTML << HTMLEOF
<!DOCTYPE html>
<html><head><meta charset="utf-8">
<meta http-equiv="refresh" content="5">
<meta name="viewport" content="width=device-width,initial-scale=1">
</head><body>
<h2>Alcatel EE71 - CA Monitor</h2>
<p><b>${ca_status}</b></p>
<p>${ca_detail}</p>
<table border="1" cellpadding="6" style="border-collapse:collapse">
<tr><th>Type</th><th>Band</th><th>PCI</th><th>EARFCN</th><th>RSRP</th><th>RSRQ</th><th>BW</th></tr>
${rows}
</table>
<p><small>${cell_info}</small></p>
<p><small>Updated: ${now} | Refresh: 5s</small></p>
<p><small>BW - approximate estimate by band (modem does not report bandwidth via AT)</small></p>
</body></html>
HTMLEOF
  mv $TMPHTML $OUT

  sleep 3
done
