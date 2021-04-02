#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
exec 2>&1
set -x

echoInfo "INFO: Staring frontend v0.0.1"
echoInfo "INFO: Build hash -> ${BUILD_HASH} -> Branch: ${BRANCH} -> Repo: ${REPO}"

EXECUTED_CHECK="$COMMON_DIR/executed"
HALT_CHECK="${COMMON_DIR}/halt"
LIP_FILE="$COMMON_READ/local_ip"
PIP_FILE="$COMMON_READ/public_ip"
BUILD_SOURCE="${FRONTEND_SRC}/build/web"
BUILD_DESTINATION="/usr/share/nginx/html"
CONFIG_DIRECTORY="${BUILD_DESTINATION}/assets/assets"
NGINX_CONFIG="/etc/nginx/nginx.conf"

while [ -f "$HALT_CHECK" ]; do
  sleep 30
done

while ! ping -c1 interx &>/dev/null ; do
    echoInfo "INFO: Waiting for ping response form INTERX container... (`date`)"
    sleep 5
done
echoInfo "INFO: INTERX IP Found: $(getent hosts interx | awk '{ print $1 }')"

while [ ! -f "$LIP_FILE" ] && [ ! -f "$PIP_FILE" ] ; do
    echoInfo "INFO: Waiting for local or public IP address discovery"
    sleep 10
done

LOCAL_IP=$(cat $LIP_FILE || echo "")
PUBLIC_IP=$(cat $PIP_FILE || echo "")

echoInfo "INFO: Local IP: $LOCAL_IP"
echoInfo "INFO: Public IP: $PUBLIC_IP"

if [ ! -f "$EXECUTED_CHECK" ]; then
    echoInfo "INFO: Cloning fronted from '$BUILD_SOURCE' into '$BUILD_DESTINATION'..."
    mkdir -p "$BUILD_DESTINATION/assets/assets"
    cp -rfv "$BUILD_SOURCE/." "$BUILD_DESTINATION"

cat >$NGINX_CONFIG <<EOL
worker_processes  1;
error_log  $COMMON_LOGS/nginx.log debug;
pid        /var/run/nginx.pid;
events {
    worker_connections  512;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status $body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log  /var/log/nginx/access.log  main;
    server {
        listen 80;
         location / {
            root /usr/share/nginx/html/;
            index  index.html;
        }
        location ~* \.(js|jpg|png|css)$ {
            root /usr/share/nginx/html/;
        }
    } 
    sendfile        on;
    keepalive_timeout  65;
}
EOL

    touch $EXECUTED_CHECK
fi

CONFIG_JSON="${BUILD_DESTINATION}/assets/assets/config.json"
DEFAULT_INTERX_PORT=11000
echoInfo "INFO: Printing current config file:"
cat $CONFIG_JSON || echoWarn "WARNINIG: Failed to print config file"
echoInfo "INFO: Setting up default API configuration..."
echo "{ \"api_url\": \"http://0.0.0.0:$DEFAULT_INTERX_PORT/api\" }" >"$CONFIG_JSON"

i=0
while [ $i -le 5 ]; do
    i=$((i + 1))

    if [ ! -z "$PUBLIC_IP" ] && timeout 2 nc -z $PUBLIC_IP $DEFAULT_INTERX_PORT ; then EXTERNAL_IP="$PUBLIC_IP" ; fi
    if [ -z "$EXTERNAL_IP" ] && timeout 2 nc -z $LOCAL_IP $DEFAULT_INTERX_PORT ; then EXTERNAL_IP="$LOCAL_IP" ; fi

    if [ ! -z "$EXTERNAL_IP" ] && timeout 2 nc -z $EXTERNAL_IP $DEFAULT_INTERX_PORT ; then
        echoInfo "INFO: Public IP addess '$EXTERNAL_IP' was detected"
        INTEREX_AVAILABLE=$(curl http://$EXTERNAL_IP:$DEFAULT_INTERX_PORT/api/status -s -f -o /dev/null && echo "true" || echo "false")
        if [ "${INTEREX_AVAILABLE,,}" == "true" ]; then
            echo "INFO: INTEREX is available externally, defaulting to '$EXTERNAL_IP'"
            echo "{ \"api_url\": \"http://$EXTERNAL_IP:$DEFAULT_INTERX_PORT/api\" }" >"$CONFIG_JSON"
            break
        else
            echoInfo "INFO: INTERX is NOT available yet over public network..."
            sleep 15
        fi
    else
        EXTERNAL_IP="0.0.0.0"
        echoInfo "INFO: Public IP is not avilable yet"
        sleep 15
    fi
done

echoInfo "INFO: Current configuration:"
cat $CONFIG_JSON

netstat -nlp | grep 80 || echoWarn "WARNINIG: Bind to port 80 was not found"
echoInfo "INFO: Testing NGINX configuration"
nginx -V
nginx -t

echoInfo "INFO: Starting nginx in current process..."
nginx -g 'daemon off;'