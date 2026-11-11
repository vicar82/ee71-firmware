#!/bin/sh

iptables -t nat -D PREROUTING -p udp --dport 53 -j REDIRECT --to-port 54


