#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring INTERX..."

cd $SEKAI/INTERX

mkdir cache

rm -f $SEKAI/INTERX/config.json
mv /root/config.json $SEKAI/INTERX

GRPC=dns:///10.3.0.2:9090 RPC=http://10.3.0.2:26657 make start
