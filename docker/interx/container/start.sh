#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring interx..."

cd $SEKAI/INTERX
make install
make start
