FROM ubuntu:18.04

LABEL maintainer="Alexander Grooff"
ARG NORDVPN_VERSION=1.2.1

ENV DEBIAN_FRONTEND=NONINTERACTIVE

HEALTHCHECK --start-period=20s --interval=5m \
	CMD if [[ $( nordvpnteams status | grep VPN | grep Connected ]]; then exit 1; fi

RUN apt-get update -y
RUN apt-get install -y curl jq iputils-ping tzdata iptables iproute2 privoxy
RUN curl https://downloads.nordteams.com/linux/latest/nordvpnteams-latest_1.0.0_all.deb --output /tmp/nordrepo.deb
RUN apt-get install -y /tmp/nordrepo.deb
RUN apt-get update -y
RUN apt-get install -y nordvpnteams${NORDVPN_VERSION:+=$NORDVPN_VERSION} || /bin/true
RUN rm -rf /var/lib/dpkg/info/nordvpnteams*  # This tries to start systemctl services, but Docker doesnt have systemctl
RUN apt-get install -f
RUN apt-get autoremove -y
RUN apt-get autoclean -y

# Copied from nordvpnteams.postinstall
# Allow the daemon executable to bind to port 500 and administer network
RUN setcap CAP_NET_BIND_SERVICE,CAP_NET_ADMIN,CAP_NET_RAW+eip /usr/sbin/nordvpnteamsd
RUN setcap CAP_NET_BIND_SERVICE,CAP_NET_ADMIN,CAP_NET_RAW+eip /usr/sbin/nordvpnteams-openvpn
RUN groupadd -r -f nordvpnteams
RUN usermod -aG nordvpnteams nordvpnteams -s /usr/sbin/nologin -c "Used for running NordVPN Teams" --home "/run/nordvpnteams"
RUN chmod 0770 -R /var/lib/nordvpnteams
RUN chown nordvpnteams:nordvpnteams -R /var/lib/nordvpnteams

RUN rm -rf \
 	/tmp/* \
 	/var/cache/apt/archives/* \
 	/var/lib/apt/lists/* \
 	/var/tmp/*

RUN mkdir project
COPY start_vpn.sh /project
COPY start_proxy.sh /project
COPY privoxy_config /project
CMD /project/start_vpn.sh
