# Creates a new container under specified port.
# Usage:
# ./create 8888

PORT=$1

docker run \
--env-file vpn_secrets.env \
-e PORT=$PORT \
--expose $PORT \
-p $PORT:$PORT \
--cap-add "NET_ADMIN" \
--dns 1.1.1.1 \
7dfeaac661e4
