#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
exec 2>&1

# Local Update Shortcut:
# (rm -fv $KIRA_SCRIPTS/container-pause.sh) && nano $KIRA_SCRIPTS/container-pause.sh && chmod 777 $KIRA_SCRIPTS/container-pause.sh

name=$1
id=$($KIRA_SCRIPTS/container-id.sh "$name")

if [ -z "$id" ] ; then
    echo "INFO: Container $name does NOT exists"
else
    echo "INFO: Container $name ($id) was found, halting..."
    docker container pause $id || echo "WARNING: Container $id could NOT be halted"
fi
