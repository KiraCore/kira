#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring INTERX..."

cd $SEKAI/INTERX

RPC=http://103.0.1.1:26657 make start
