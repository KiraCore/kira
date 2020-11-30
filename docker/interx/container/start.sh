#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring INTERX..."

cd $SEKAI/INTERX

# rm -f /root/output.log
# touch /root/output.log

mkdir cache

rm -f $SEKAI/INTERX/config.json
mv /root/config.json $SEKAI/INTERX

GRPC=dns:///$KIRA_SENTRY_IP:9090 RPC=http://$KIRA_SENTRY_IP:26657 make start
