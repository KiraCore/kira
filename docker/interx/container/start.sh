#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring INTERX..."
cd $SEKAI/INTERX

EXECUTED_CHECK="/root/executed"

if [ -f "$EXECUTED_CHECK" ]; then
  GRPC=dns:///$KIRA_SENTRY_IP:9090 RPC=http://$KIRA_SENTRY_IP:26657 make start
else
  mkdir -p cache

  rm -f $SEKAI/INTERX/config.json
  mv $COMMON_DIR/config.json $SEKAI/INTERX

  touch $EXECUTED_CHECK
  GRPC=dns:///$KIRA_SENTRY_IP:9090 RPC=http://$KIRA_SENTRY_IP:26657 make start
fi
