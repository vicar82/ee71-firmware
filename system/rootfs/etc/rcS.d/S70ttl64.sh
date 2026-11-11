#! /bin/sh
# ttl64 - TTL/HL fix for EE71 (corrected: symlinks + watchdog + cron)
# Install:
#   push to /etc/init.d/ttl64
#   ln -sf ../init.d/ttl64 /etc/rcS.d/S70ttl64.sh
#   ln -sf ../init.d/ttl64 /etc/rc5.d/S99ttl64
#   echo 64 > /etc/rcS.d/ttl
# Run manually: sh /etc/init.d/ttl64 once
LOG=/tmp/ttlfix.log

apply() {
    ttl=$(cat /etc/rcS.d/ttl 2>/dev/null)
    case "$ttl" in ''|*[!0-9]*) ttl=64 ;; esac
    if [ 0$ttl -le 0 ] || [ 0$ttl -gt 255 ]; then ttl=64; fi
    {
        echo "=== ttl64 apply at $(date 2>/dev/null) (src=$1) ==="
        echo "ttl=$ttl"
        add() {
            chain=$1; shift
            if iptables -t mangle -C "$chain" "$@" 2>/dev/null; then
                echo "exists: $chain $*"
            elif iptables -t mangle -A "$chain" "$@" 2>/dev/null; then
                echo "added:  $chain $*"
            else
                echo "FAILED: iptables -A $chain $*"
            fi
        }
        add POSTROUTING -o rmnet+ -j TTL --ttl-set "$ttl"
        add OUTPUT      -o rmnet+ -j TTL --ttl-set "$ttl"
        add PREROUTING  -i rmnet+ -j TTL --ttl-set 201
        if command -v ip6tables >/dev/null 2>&1; then
            add6() {
                chain=$1; shift
                if ip6tables -t mangle -C "$chain" "$@" 2>/dev/null; then
                    echo "exists: $chain $*"
                elif ip6tables -t mangle -A "$chain" "$@" 2>/dev/null; then
                    echo "added:  $chain $*"
                else
                    echo "FAILED: ip6tables -A $chain $*"
                fi
            }
            add6 POSTROUTING '!' -p icmpv6 -o rmnet+ -j HL --hl-set "$ttl"
            add6 OUTPUT      '!' -p icmpv6 -o rmnet+ -j HL --hl-set "$ttl"
            add6 PREROUTING  '!' -p icmpv6 -i rmnet+ -j HL --hl-set 201
        else
            echo "no ip6tables - IPv6 rules skipped"
        fi
        echo "--- POSTROUTING -n -v (head) ---"
        iptables -t mangle -L POSTROUTING -n -v 2>/dev/null | head -4
    } >>$LOG 2>&1
}

# single shot (cron / manual)
if [ "$1" = "once" ]; then
    apply once
    exit 0
fi

# boot invocation
apply boot

# watchdog: re-apply periodically for the first ~15 minutes,
# survives firewall/qcmap wiping mangle rules during bring-up
( i=1; while [ $i -le 8 ]; do sleep 110; apply "watchdog-$i"; i=$((i+1)); done ) >/dev/null 2>&1 &

# self-healing via cron if crond exists on this firmware
if command -v crontab >/dev/null 2>&1; then
    crontab -l 2>/dev/null | grep -q 'init.d/ttl64' || \
        { crontab -l 2>/dev/null; echo '* * * * * sh /etc/init.d/ttl64 once >/dev/null 2>&1'; } | \
        crontab - 2>/dev/null && echo "cron entry added" >>$LOG 2>&1
fi

exit 0
