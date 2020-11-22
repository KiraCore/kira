#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring INTERX..."

cd $SEKAI/INTERX

GRPC=dns:///103.0.1.1:9090 RPC=http://103.0.1.1:26657 make start
