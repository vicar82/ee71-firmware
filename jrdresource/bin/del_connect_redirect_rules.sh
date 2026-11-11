#!/bin/sh

#iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-port 54
gateway_ip_addr=$(cat /etc/gateway_ip)
if [ ! -n "$gateway_ip_addr" ]
then
	gateway_ip_addr=192.168.0.0
fi
CUST_IP_addr=$(cat /etc/timinternet_ip)
iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-port 54
iptables -t nat -D PREROUTING -d "$gateway_ip_addr"/16 -j ACCEPT
if [ -n "$CUST_IP_addr" ]
then
	iptables -t nat -D PREROUTING -p tcp --dport 80 -j DNAT --to-destination "$CUST_IP_addr":80
fi
