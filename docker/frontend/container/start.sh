#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
exec 2>&1
set -x
# quick edit: FILE="${SELF_CONTAINER}/start.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

echoInfo "INFO: Staring frontend $KIRA_SETUP_VER setup..."
echoInfo "INFO: Build hash -> ${BUILD_HASH} -> Branch: ${BRANCH} -> Repo: ${REPO}"

mkdir -p $GLOB_STORE_DIR

EXECUTED_CHECK="$COMMON_DIR/executed"
HALT_CHECK="${COMMON_DIR}/halt"
EXIT_CHECK="${COMMON_DIR}/exit"
LIP_FILE="$COMMON_READ/local_ip"
PIP_FILE="$COMMON_READ/public_ip"
BUILD_SOURCE="${FRONTEND_SRC}/build/web"
BUILD_DESTINATION="/usr/share/nginx/html"
CONFIG_DIRECTORY="${BUILD_DESTINATION}/assets/assets"
NGINX_CONFIG="/etc/nginx/nginx.conf"
CFG_CHECK="${COMMON_DIR}/configuring"

touch $CFG_CHECK

echo "OFFLINE" > "$COMMON_DIR/external_address_status"

RESTART_COUNTER=$(globGet RESTART_COUNTER)
if ($(isNaturalNumber $RESTART_COUNTER)) ; then
    globSet RESTART_COUNTER "$(($RESTART_COUNTER+1))"
    globSet RESTART_TIME "$(date -u +%s)"
fi

while [ -f "$HALT_CHECK" ] || [ -f "$EXIT_CHECK" ]; do
    if [ -f "$EXIT_CHECK" ]; then
        echoInfo "INFO: Ensuring nginx process is killed"
        touch $HALT_CHECK
        pkill -9 interxd || echoWarn "WARNING: Failed to kill nginx"
        rm -fv $EXIT_CHECK
    fi
    echoInfo "INFO: Container halted (`date`)"
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

LOCAL_IP=$(cat $LIP_FILE || echo -n "")
PUBLIC_IP=$(cat $PIP_FILE || echo -n "")

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
    globSet RESTART_COUNTER 0
    globSet START_TIME "$(date -u +%s)"
fi

CONFIG_JSON="${BUILD_DESTINATION}/assets/assets/config.json"
echoInfo "INFO: Printing current config file:"
cat $CONFIG_JSON || echoWarn "WARNINIG: Failed to print config file"
echoInfo "INFO: Setting up default API configuration..."
[ -z "$PUBLIC_IP" ] && PUBLIC_IP="0.0.0.0"
[ -z "$LOCAL_IP" ] && LOCAL_IP="127.0.0.1"
echo "{ \"api_url\": [\"0.0.0.0:$DEFAULT_INTERX_PORT\", \"127.0.0.1:$DEFAULT_INTERX_PORT\", \"interx.local:$DEFAULT_INTERX_PORT\", \"$PUBLIC_IP:$KIRA_INTERX_PORT\", \"$LOCAL_IP:$KIRA_INTERX_PORT\"], \"autoconnect\": false }" >"$CONFIG_JSON"

echoInfo "INFO: Current configuration:"
cat $CONFIG_JSON

netstat -nlp | grep $INTERNAL_HTTP_PORT || echoWarn "WARNINIG: Bind to port $INTERNAL_HTTP_PORT was not found"
echoInfo "INFO: Testing NGINX configuration"
nginx -V
nginx -t

echoInfo "INFO: Starting nginx in current process..."
rm -fv $CFG_CHECK
EXIT_CODE=0 && nginx -g 'daemon off;' || EXIT_CODE="$?"

echoErr "ERROR: NGINX failed with the exit code $EXIT_CODE"
sleep 3
exit 1
