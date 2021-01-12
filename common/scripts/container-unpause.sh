#!/bin/bash

exec 2>&1
set -e

# Local Update Shortcut:
# (rm -fv $KIRA_SCRIPTS/container-unpause.sh) && nano $KIRA_SCRIPTS/container-unpause.sh && chmod 777 $KIRA_SCRIPTS/container-unpause.sh

name=$1
id=$(docker ps --no-trunc -aqf name="$name" 2> /dev/null || echo "")

if [ -z "$id" ] ; then
    echo "INFO: Container $name does NOT exists"
else
    echo "INFO: Container $name ($id) was found, unpausing..."
    docker container unpause $id || echo "WARNING: Container $id could NOT be unpaused"
fi
