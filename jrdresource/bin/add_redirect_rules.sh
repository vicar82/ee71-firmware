#!/bin/sh
# EE71: DNS redirect disabled; client DNS must go to dnsmasq:53

iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-port 54
#EE71_DISABLED: iptables -t nat -A PREROUTING -p udp --dport 53 -j REDIRECT --to-port 54


