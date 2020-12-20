#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring INTERX..."

cd $SEKAI/INTERX

mkdir cache

rm -f $SEKAI/INTERX/config.json
mv $COMMON_DIR/interx/config.json $SEKAI/INTERX

GRPC=dns:///$KIRA_SENTRY_IP:9090 RPC=http://$KIRA_SENTRY_IP:26657 make start
