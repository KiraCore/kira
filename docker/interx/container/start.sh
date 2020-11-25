#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring INTERX..."

cd $SEKAI/INTERX

# rm -f /root/output.log
# touch /root/output.log

rm -f $SEKAI/INTERX/config.json
mv /root/config.json $SEKAI/INTERX

GRPC=dns:///103.0.1.1:9090 RPC=http://103.0.1.1:26657 make start
