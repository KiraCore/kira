#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
exec 2>&1

# Local Update Shortcut:
# (rm -fv $KIRA_SCRIPTS/container-stop.sh) && nano $KIRA_SCRIPTS/container-stop.sh && chmod 777 $KIRA_SCRIPTS/container-stop.sh

name=$1
id=$($KIRA_SCRIPTS/container-id.sh "$name")

if [ -z "$id" ] ; then
    echo "INFO: Container $name does NOT exists"
else
    echo "INFO: Container $name ($id) was found, stopping..."
    docker container stop $id || echo "WARNING: Container $id could NOT be stopped"
fi
