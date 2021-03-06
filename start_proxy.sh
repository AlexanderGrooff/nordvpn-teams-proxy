#!/bin/sh
# Return traffic that went through OpenVPN works.
gw=$(ip route | awk '/default/ {print $3}')
if [ -n "$LOCAL_NETWORK" ]; then
	ip route add to ${LOCAL_NETWORK} via $gw dev eth0
fi
ip route add to 192.168.1.0/24 via $gw dev eth0

# Start privoxy
echo "Starting proxy"
privoxy --no-daemon /project/privoxy_config
