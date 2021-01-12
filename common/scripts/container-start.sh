#!/bin/bash

exec 2>&1
set -e

# Local Update Shortcut:
# (rm -fv $KIRA_SCRIPTS/container-start.sh) && nano $KIRA_SCRIPTS/container-start.sh && chmod 777 $KIRA_SCRIPTS/container-start.sh

name=$1
id=$(docker ps --no-trunc -aqf name="$name" 2> /dev/null || echo "")

if [ -z "$id" ] ; then
    echo "INFO: Container $name does NOT exists"
else
    echo "INFO: Container $name ($id) was found, staring..."
    docker container start $id || echo "WARNING: Container $name ($id) could NOT be started"
fi
