#!/bin/bash

exec 2>&1
set -e
set -x

echo "INFO: Staring frontend v0.0.1"
echo "INFO: Build hash -> ${BUILD_HASH} -> Branch: ${BRANCH} -> Repo: ${REPO}"

EXECUTED_CHECK="$COMMON_DIR/executed"
HALT_CHECK="${COMMON_DIR}/halt"
BUILD_SOURCE="/root/kira-frontend/src/build/web"
BUILD_DESTINATION="/usr/share/nginx/html"
FRONTEND_SRC="/root/kira-frontend/src"

while [ -f "$HALT_CHECK" ]; do
  sleep 30
done

while ! ping -c1 interx &>/dev/null ; do
    echo "INFO: Waiting for ping response form INTERX container... (`date`)"
    sleep 5
done
echo "INFO: INTERX IP Found: $(getent hosts interx | awk '{ print $1 }')"

if [ ! -f "$EXECUTED_CHECK" ]; then
    echo "INFO: Building fronted from $REPO..."
    cd /root
    git clone ${REPO}
    cd $FRONTEND_SRC
    git checkout ${BRANCH}
    
    cat > $FRONTEND_SRC/assets/config.json << EOL
{
  "api_url": "http://0.0.0.0:11000/api"
}
EOL

    flutter pub get
    flutter build web --release

    mkdir -p "$BUILD_DESTINATION"
    cp -v -f "$BUILD_SOURCE" "$BUILD_DESTINATION"

    touch $EXECUTED_CHECK
fi

service nginx restart
sleep 1
nginx -g 'daemon off;'
