FROM ubuntu:18.04

LABEL maintainer="Alexander Grooff"
ARG NORDVPN_VERSION=1.2.1

ENV DEBIAN_FRONTEND=NONINTERACTIVE

HEALTHCHECK --start-period=1m --interval=10m \
	CMD if test "$( curl -m 25 -s https://api.nordvpn.com/v1/helpers/ips/insights | jq -r '.["protected"]' )" != "true" ; then exit 1; fi

RUN apt-get update -y
RUN apt-get install -y curl jq iputils-ping tzdata iptables iproute2 privoxy
RUN curl https://downloads.nordteams.com/linux/latest/nordvpnteams-latest_1.0.0_all.deb --output /tmp/nordrepo.deb
RUN apt-get install -y /tmp/nordrepo.deb
RUN apt-get update -y
RUN apt-get install -y nordvpnteams${NORDVPN_VERSION:+=$NORDVPN_VERSION} || /bin/true
RUN rm -rf /var/lib/dpkg/info/nordvpnteams*  # This tries to start systemctl services, but Docker doesnt have systemctl
RUN apt-get install -f
#RUN apt-get remove -y nordvpnteams-latest
RUN apt-get autoremove -y
RUN apt-get autoclean -y

# Copied from nordvpnteams.postinstall
# Allow the daemon executable to bind to port 500 and administer network
RUN setcap CAP_NET_BIND_SERVICE,CAP_NET_ADMIN,CAP_NET_RAW+eip /usr/sbin/nordvpnteamsd
RUN setcap CAP_NET_BIND_SERVICE,CAP_NET_ADMIN,CAP_NET_RAW+eip /usr/sbin/nordvpnteams-openvpn
RUN groupadd -r -f nordvpnteams
RUN usermod -aG nordvpnteams nordvpnteams -s /usr/sbin/nologin -c "Used for running NordVPN Teams" --home "/run/nordvpnteams"
#RUN useradd -s /usr/sbin/nologin -c "Used for running NordVPN Teams" \
#    -r -M -d /run/nordvpnteams -g nordvpnteams nordvpnteams
RUN chmod 0770 -R /var/lib/nordvpnteams
RUN chown nordvpnteams:nordvpnteams -R /var/lib/nordvpnteams

RUN rm -rf \
 	/tmp/* \
 	/var/cache/apt/archives/* \
 	/var/lib/apt/lists/* \
 	/var/tmp/*
RUN echo '#!/bin/bash\nservice nordvpnteams start\nsleep 1\nnordvpn countries' > /usr/bin/countries
RUN echo '#!/bin/bash\nservice nordvpnteams start\nsleep 1\nnordvpn cities $1' > /usr/bin/cities
RUN echo '#!/bin/bash\nservice nordvpnteams start\nsleep 1\nnordvpn groups' > /usr/bin/n_groups
RUN chmod +x /usr/bin/countries
RUN chmod +x /usr/bin/cities
RUN chmod +x /usr/bin/n_groups

RUN mkdir project
COPY start_vpn.sh /project
COPY start_proxy.sh /project
COPY privoxy_config /project
CMD /project/start_vpn.sh
