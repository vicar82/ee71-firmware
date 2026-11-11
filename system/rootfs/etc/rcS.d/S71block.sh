iptables -A OUTPUT -p udp --dport 53 -m string --string msftncsi --algo bm -j REJECT
iptables -A OUTPUT -p udp --dport 53 -m string --string captive.apple --algo bm -j REJECT
iptables -A OUTPUT -p tcp --dport 80 -m string --string msftncsi.com --algo bm -j REJECT
iptables -A OUTPUT -p tcp --dport 80 -m string --string captive.apple.com --algo bm -j REJECT
