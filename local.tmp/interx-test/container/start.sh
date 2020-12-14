#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring INTERX..."

cd $SEKAI/INTERX

mkdir cache

rm -f $SEKAI/INTERX/config.json
mv /root/config.json $SEKAI/INTERX

GRPC=dns:///sentry:9090 RPC=http://sentry:26657 make start
