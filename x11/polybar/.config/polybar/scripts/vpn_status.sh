#!/bin/sh

# nmcli -t connection show --active | awk -F ':' '/tun0/{vpn="On"} /vpn/{name=$1} END{if(vpn) printf("%s %s", name, vpn)}'

printf " " && (pgrep -a openvpn$ | head -n 1 | awk '{print $NF }' | cut -d '.' -f 1 && echo down) | head -n 1
