#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring INTERX..."
cd $SEKAI/INTERX

EXECUTED_CHECK="$COMMON_DIR/executed"
HALT_CHECK="${COMMON_DIR}/halt"

while [ -f "$HALT_CHECK" ]; do
  sleep 30
done

while ! ping -c1 sentry &>/dev/null; do
  echo "INFO: Waiting for ping response form sentry node... ($(date))"
  sleep 5
done

if [ ! -f "$EXECUTED_CHECK" ]; then
  mkdir -p cache

  rm -f $SEKAI/INTERX/config.json
  mv $COMMON_DIR/config.json $SEKAI/INTERX

  touch $EXECUTED_CHECK
fi

GRPC=dns:///sentry:9090 RPC=http://sentry:26657 make start
