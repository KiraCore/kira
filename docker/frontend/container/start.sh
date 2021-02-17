#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
exec 2>&1
set -x

echo "INFO: Staring frontend v0.0.1"
echo "INFO: Build hash -> ${BUILD_HASH} -> Branch: ${BRANCH} -> Repo: ${REPO}"

EXECUTED_CHECK="$COMMON_DIR/executed"
HALT_CHECK="${COMMON_DIR}/halt"
BUILD_SOURCE="${FRONTEND_SRC}/build/web"
BUILD_DESTINATION="/usr/share/nginx/html"
CONFIG_DIRECTORY="${BUILD_DESTINATION}/assets/assets"
NGINX_CONFIG="/etc/nginx/nginx.conf"

while [ -f "$HALT_CHECK" ]; do
  sleep 30
done

while ! ping -c1 interx &>/dev/null ; do
    echo "INFO: Waiting for ping response form INTERX container... (`date`)"
    sleep 5
done
echo "INFO: INTERX IP Found: $(getent hosts interx | awk '{ print $1 }')"

if [ ! -f "$EXECUTED_CHECK" ]; then
    echo "INFO: Cloning fronted from '$BUILD_SOURCE' into '$BUILD_DESTINATION'..."
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
echo "INFO: Setting up default API configuration..."
echo "{ \"api_url\": \"http://0.0.0.0:11000/api\" }" > "$CONFIG_JSON"

i=0
while [ $i -le 4 ]; do
    PUBLIC_IP=$(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com +time=1 +tries=1 2> /dev/null | awk -F'"' '{ print $2}' || echo "")
    if [ ! -z "$PUBLIC_IP" ] ; then
        echo "INFO: Public IP addess '$PUBLIC_IP' was detected"
        INTEREX_AVAILABLE=$(curl http://$PUBLIC_IP:11000/api/status -s -f -o /dev/null && echo "true" || echo "false")
        if [ "${INTEREX_AVAILABLE,,}" == "true" ] ; then
            echo "INFO: INTEREX is available externally, defaulting to '$PUBLIC_IP'"
            echo "{ \"api_url\": \"http://$PUBLIC_IP:11000/api\" }" > "$CONFIG_JSON"
            break
        else
            echo "INFO: INTERX is NOT available yet over public network..."
            sleep 15
        fi
    else
        echo "INFO: Public IP is not avilable yet"
        sleep 15
    fi
done

echo "INFO: Current configuration:"
cat $CONFIG_JSON

netstat -nlp | grep 80 || echo "INFO: Bind to port 80 was not found"
echo "INFO: Testing NGINX configuration"
nginx -V
nginx -t

echo "INFO: Starting nginx in current process..."
nginx -g 'daemon off;'