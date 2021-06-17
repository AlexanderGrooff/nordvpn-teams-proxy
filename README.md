# NordVPN Teams Docker proxy

This repo holds a Docker image, which is a ported version of the
[.deb file provided by NordVPN](https://nordvpnteams.com/download/linux/). This is combined with
[Privoxy](https://www.privoxy.org/) to expose it to the host via port 8118.

You can use this straight with Docker, or use it with the supplied [`docker-compose.yaml`](./docker-compose.yaml) file.
This expects an environment file called `vpn_secrets.env` that contain the following variables:

```
USER=myusername
PASS=mypass
ORGANIZATION=myorg
CONNECT=nl  # Mandatory, no autoconnect feature yet
```

## Credits

This project is largely based on these two projects:

- https://github.com/bubuntux/nordvpn
- https://github.com/Joentje/nordvpn-proxy
