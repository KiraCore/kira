#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring frontend..."

EXECUTED_CHECK="$COMMON_DIR/executed"
HALT_CHECK="${COMMON_DIR}/halt"

while [ -f "$HALT_CHECK" ]; do
  sleep 30
done

while ! ping -c1 interx &>/dev/null ; do
    echo "INFO: Waiting for ping response form INTERX container... (`date`)"
    sleep 5
done
echo "INFO: INTERX IP Found: $(getent hosts interx | awk '{ print $1 }')"

if [ ! -f "$EXECUTED_CHECK" ]; then
    sleep 1 # TODO: setup
    touch $EXECUTED_CHECK
fi

nginx -g 'daemon off;'
