#!/bin/bash

exec 2>&1
set -e

# Local Update Shortcut:
# (rm -fv $KIRA_SCRIPTS/container-pause.sh) && nano $KIRA_SCRIPTS/container-pause.sh && chmod 777 $KIRA_SCRIPTS/container-pause.sh

name=$1
id=$(docker ps --no-trunc -aqf name="$name" 2> /dev/null || echo "")

if [ -z "$id" ] ; then
    echo "INFO: Container $name does NOT exists"
else
    echo "INFO: Container $name ($id) was found, halting..."
    docker container pause $id || echo "WARNING: Container $id could NOT be halted"
fi
