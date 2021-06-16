#!/bin/bash

NORD_USER="nordvpnteams"
NORD_GROUP="nordvpnteams"
NORD_CMD="/usr/bin/nordvpnteams"
NORD_SERVER_CMD="/usr/sbin/nordvpnteamsd"
NORD_SOCKET="/run/nordvpnteams/nordvpnteams.sock"
NORD_SOCKET_DIR=$(dirname $NORD_SOCKET)

[[ -z ${USER} ]] && echo "USER variable not set. Exiting.." && exit 2
[[ -z ${PASS} ]] && echo "PASS variable not set. Exiting.." && exit 2
[[ -z ${ORGANIZATION} ]] && echo "ORGANIZATION variable not set. Exiting.." && exit 2

iptables -P OUTPUT DROP
iptables -P INPUT DROP
iptables -P FORWARD DROP
ip6tables -P OUTPUT DROP 2>/dev/null
ip6tables -P INPUT DROP 2>/dev/null
ip6tables -P FORWARD DROP 2>/dev/null
iptables -F
iptables -X
ip6tables -F 2>/dev/null
ip6tables -X 2>/dev/null

[[ "${DEBUG,,}" = "trace"  ]] && set -x

if [ "$(cat /etc/timezone)" != "${TZ}" ]; then
  if [ -d "/usr/share/zoneinfo/${TZ}" ] || [ ! -e "/usr/share/zoneinfo/${TZ}" ] || [ -z "${TZ}" ]; then
    TZ="Etc/UTC"
  fi
  ln -fs "/usr/share/zoneinfo/${TZ}" /etc/localtime
  dpkg-reconfigure -f noninteractive tzdata 2> /dev/null
fi

echo "[$(date -Iseconds)] Firewall is up, everything has to go through the vpn"
docker_network="$(ip -o addr show dev eth0 | awk '$3 == "inet" {print $4}')"
docker6_network="$(ip -o addr show dev eth0 | awk '$3 == "inet6" {print $4; exit}')"

echo "[$(date -Iseconds)] Enabling connection to secure interfaces"
if [[ -n ${docker_network} ]]; then
  iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A FORWARD -i lo -j ACCEPT
  iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  iptables -A OUTPUT -o lo -j ACCEPT
  iptables -A OUTPUT -o tap+ -j ACCEPT
  iptables -A OUTPUT -o tun+ -j ACCEPT
  iptables -A OUTPUT -o nordlynx+ -j ACCEPT
  iptables -t nat -A POSTROUTING -o tap+ -j MASQUERADE
  iptables -t nat -A POSTROUTING -o tun+ -j MASQUERADE
  iptables -t nat -A POSTROUTING -o nordlynx+ -j MASQUERADE
fi
if [[ -n ${docker6_network} ]]; then
  ip6tables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  ip6tables -A INPUT -p icmp -j ACCEPT
  ip6tables -A INPUT -i lo -j ACCEPT
  ip6tables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  ip6tables -A FORWARD -p icmp -j ACCEPT
  ip6tables -A FORWARD -i lo -j ACCEPT
  ip6tables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
  ip6tables -A OUTPUT -o lo -j ACCEPT
  ip6tables -A OUTPUT -o tap+ -j ACCEPT
  ip6tables -A OUTPUT -o tun+ -j ACCEPT
  ip6tables -A OUTPUT -o nordlynx+ -j ACCEPT
  ip6tables -t nat -A POSTROUTING -o tap+ -j MASQUERADE
  ip6tables -t nat -A POSTROUTING -o tun+ -j MASQUERADE
  ip6tables -t nat -A POSTROUTING -o nordlynx+ -j MASQUERADE
fi

echo "[$(date -Iseconds)] Enabling connection to nordvpn group"
if [[ -n ${docker_network} ]]; then
  iptables -A OUTPUT -m owner --gid-owner $NORD_GROUP -j ACCEPT || {
    echo "[$(date -Iseconds)] group match failed, fallback to open necessary ports"
    iptables -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT
    iptables -A OUTPUT -p udp -m udp --dport 51820 -j ACCEPT
    iptables -A OUTPUT -p tcp -m tcp --dport 1194 -j ACCEPT
    iptables -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT
    iptables -A OUTPUT -p tcp -m tcp --dport 443 -j ACCEPT
  }
fi
if [[ -n ${docker6_network} ]]; then
  ip6tables -A OUTPUT -m owner --gid-owner $NORD_GROUP -j ACCEPT || {
    echo "[$(date -Iseconds)] ip6 group match failed, fallback to open necessary ports"
    ip6tables -A OUTPUT -p udp -m udp --dport 53 -j ACCEPT
    ip6tables -A OUTPUT -p udp -m udp --dport 51820 -j ACCEPT
    ip6tables -A OUTPUT -p tcp -m tcp --dport 1194 -j ACCEPT
    ip6tables -A OUTPUT -p udp -m udp --dport 1194 -j ACCEPT
    ip6tables -A OUTPUT -p tcp -m tcp --dport 443 -j ACCEPT
  }
fi

echo "[$(date -Iseconds)] Enabling connection to docker network"
if [[ -n ${docker_network} ]]; then
  iptables -A INPUT -s "${docker_network}" -j ACCEPT
  iptables -A FORWARD -d "${docker_network}" -j ACCEPT
  iptables -A FORWARD -s "${docker_network}" -j ACCEPT
  iptables -A OUTPUT -d "${docker_network}" -j ACCEPT
fi
if [[ -n ${docker6_network} ]]; then
  ip6tables -A INPUT -s "${docker6_network}" -j ACCEPT 2>/dev/null
  ip6tables -A FORWARD -d "${docker6_network}" -j ACCEPT 2>/dev/null
  ip6tables -A FORWARD -s "${docker6_network}" -j ACCEPT 2>/dev/null
  ip6tables -A OUTPUT -d "${docker6_network}" -j ACCEPT 2>/dev/null
fi

if [[ -n ${docker_network} && -n ${NETWORK} ]]; then
  gw=$(ip route | awk '/default/ {print $3}')
  for net in ${NETWORK//[;,]/ }; do
    echo "[$(date -Iseconds)] Enabling connection to network ${net}"
    ip route | grep -q "$net" || ip route add to "$net" via "$gw" dev eth0
    iptables -A INPUT -s "$net" -j ACCEPT
    iptables -A FORWARD -d "$net" -j ACCEPT
    iptables -A FORWARD -s "$net" -j ACCEPT
    iptables -A OUTPUT -d "$net" -j ACCEPT
  done
fi
if [[ -n ${docker6_network} && -n ${NETWORK6} ]]; then
  gw6=$(ip -6 route | awk '/default/{print $3}')
  for net6 in ${NETWORK6//[;,]/ }; do
    echo "[$(date -Iseconds)] Enabling connection to network ${net6}"
    ip -6 route | grep -q "$net6" || ip -6 route add to "$net6" via "$gw6" dev eth0
    ip6tables -A INPUT -s "$net6" -j ACCEPT
    ip6tables -A FORWARD -d "$net6" -j ACCEPT
    ip6tables -A FORWARD -s "$net6" -j ACCEPT
    ip6tables -A OUTPUT -d "$net6" -j ACCEPT
  done
fi

if [[ -n ${WHITELIST} ]]; then
  for domain in ${WHITELIST//[;,]/ }; do
    domain=$(echo "$domain" | sed 's/^.*:\/\///;s/\/.*$//')
    echo "[$(date -Iseconds)] Enabling connection to host ${domain}"
    sg nordvpn -c "iptables  -A OUTPUT -o eth0 -d ${domain} -j ACCEPT"
    sg nordvpn -c "ip6tables -A OUTPUT -o eth0 -d ${domain} -j ACCEPT 2>/dev/null"
  done
fi

mkdir -p /dev/net
[[ -c /dev/net/tun ]] || mknod -m 0666 /dev/net/tun c 10 200

restart_daemon() {
  mkdir -p $NORD_SOCKET_DIR
  chown -R $NORD_USER:$NORD_GROUP $NORD_SOCKET_DIR
  chmod -R 0777 $NORD_SOCKET_DIR
  echo "[$(date -Iseconds)] Restarting the service"
  pkill $(basename $NORD_SERVER_CMD)
  rm -rf $NORD_SOCKET
  su - $NORD_USER -s $(which bash) -c "$NORD_SERVER_CMD -socket "$NORD_SOCKET" &"

  echo "[$(date -Iseconds)] Waiting for the service to start"
  attempt_counter=0
  max_attempts=50
  until [ -S $NORD_SOCKET ]; do
    if [ ${attempt_counter} -eq ${max_attempts} ]; then
      echo "[$(date -Iseconds)] Max attempts reached"
      exit 1
    fi
    attempt_counter=$((attempt_counter + 1))
    sleep 0.1
  done
  chown $NORD_USER:$NORD_GROUP $NORD_SOCKET
  chmod 0770 $NORD_SOCKET
}
restart_daemon

[[ -z "${PASS}" ]] && [[ -f "${PASSFILE}" ]] && PASS="$(head -n 1 "${PASSFILE}")"

echo "[$(date -Iseconds)] Logging in"
# Pick option 1: email + pass combination
echo "1" | $NORD_CMD login --organization "${ORGANIZATION}" --email "${USER}" --password "${PASS}" || {
  echo "[$(date -Iseconds)] Invalid Username or password."
  exit 1
}

# Dump all connection info and parse out the countrycodes
AVAILABLE_GATEWAYS=$($NORD_CMD gateways --format '{{ . }}' | egrep -o ' ([a-z]{2}) \[' | awk '{print$1}' | xargs echo)
[[ -z ${CONNECT} ]] && echo "No country specified, pick one of the following: $AVAILABLE_GATEWAYS" && exit 2

echo "[$(date -Iseconds)] Setting up $($NORD_CMD version)"
[[ -n ${CYBER_SEC} ]] && $NORD_CMD settings set cybersec ${CYBER_SEC}
[[ -n ${DNS} ]] && $NORD_CMD settings set dns ${DNS//[;,]/ }
[[ -n ${FIREWALL} ]] && $NORD_CMD settings set firewall ${FIREWALL}
[[ -n ${KILLSWITCH} ]] && $NORD_CMD settings set killswitch ${KILLSWITCH}
[[ -n ${OBFUSCATE} ]] && $NORD_CMD settings set obfuscate ${OBFUSCATE}
[[ -n ${PROTOCOL} ]] && $NORD_CMD settings set protocol ${PROTOCOL}
[[ -n ${TECHNOLOGY} ]] && $NORD_CMD settings set technology ${TECHNOLOGY}

if [[ -n ${docker_network} ]];then
  $NORD_CMD whitelist add subnet ${docker_network}
  [[ -n ${NETWORK} ]] && for net in ${NETWORK//[;,]/ }; do $NORD_CMD whitelist add subnet "${net}"; done
fi
if [[ -n ${docker6_network} ]];then
  $NORD_CMD settings set ipv6 on
  $NORD_CMD whitelist add subnet ${docker6_network}
  [[ -n ${NETWORK6} ]] && for net in ${NETWORK6//[;,]/ }; do $NORD_CMD whitelist add subnet "${net}"; done
fi
[[ -n ${PORTS} ]] && for port in ${PORTS//[;,]/ }; do $NORD_CMD whitelist add port "${port}"; done
[[ -n ${PORT_RANGE} ]] && $NORD_CMD whitelist add ports ${PORT_RANGE}
[[ -n ${DEBUG} ]] && $NORD_CMD settings settings

connect() {
  echo "[$(date -Iseconds)] Connecting..."
  attempt_counter=0
  max_attempts=15
  until $NORD_CMD connect ${CONNECT} --socket "$NORD_SOCKET"; do
    if [ ${attempt_counter} -eq ${max_attempts} ]; then
      tail -n 200 /var/log/nordvpn/daemon.log
      echo "[$(date -Iseconds)] Unable to connect."
      exit 1
    fi
    attempt_counter=$((attempt_counter + 1))
    sleep 5
  done
}
connect
[[ -n ${DEBUG} ]] && tail -n 1 -f /var/log/nordvpn/daemon.log &

cleanup() {
  $NORD_CMD status
  $NORD_CMD disconnect
  pkill $NORD_SERVER_CMD
  trap - SIGTERM SIGINT EXIT # https://bash.cyberciti.biz/guide/How_to_clear_trap
  exit 0
}
trap cleanup SIGTERM SIGINT EXIT # https://www.ctl.io/developers/blog/post/gracefully-stopping-docker-containers/

while true; do
  sleep "${RECONNECT:-300}"
  if [ "$(curl -m 30 -s https://api.nordvpn.com/v1/helpers/ips/insights | jq -r '.["protected"]')" != "true" ]; then
    echo "[$(date -Iseconds)] Unstable connection detected!"
    $NORD_CMD status
    restart_daemon
    connect
  fi
done
