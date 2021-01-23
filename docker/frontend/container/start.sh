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
    mkdir -p "$BUILD_DESTINATION"
    cp -rfv "$BUILD_SOURCE/." "$BUILD_DESTINATION"
    touch $EXECUTED_CHECK
fi

service nginx restart
sleep 1
nginx -g 'daemon off;'
