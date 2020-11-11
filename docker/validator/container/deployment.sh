#!/bin/bash

exec 2>&1
set -e
set -x

echo "Building node..."

cd $SEKAI
sh ./sekaitestsetup.sh
