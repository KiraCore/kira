#!/bin/bash

exec 2>&1
set -e
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
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  512;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';
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

    mkdir -p -v $NGINX_SERVICED_PATH
    printf "[Service]\nExecStartPost=/bin/sleep 0.1\n" > $NGINX_SERVICED_PATH/override.conf

    touch $EXECUTED_CHECK
fi

PUBLIC_IP=$(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com +time=1 +tries=1 2> /dev/null | awk -F'"' '{ print $2}' || echo "")
[ -z "$PUBLIC_IP" ] && PUBLIC_IP="0.0.0.0"
echo "{ \"api_url\": \"http://$PUBLIC_IP:11000/api\" }" > "${BUILD_DESTINATION}/assets/assets/config.json"

service nginx status
service nginx restart
sleep 1
nginx -g 'daemon off;'
service nginx status