# Creates a new container under specified port.
# Usage:
# ./create 8888 7dfeaac661e4

PORT=$1
IMAGE=$2

docker run \
--env-file vpn_secrets.env \
-e PORT=$PORT \
--expose $PORT \
-p $PORT:$PORT \
--cap-add "NET_ADMIN" \
--dns 1.1.1.1 \
$IMAGE
