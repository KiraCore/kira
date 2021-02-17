#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
exec 2>&1

# Local Update Shortcut:
# (rm -fv $KIRA_SCRIPTS/container-restart.sh) && nano $KIRA_SCRIPTS/container-restart.sh && chmod 777 $KIRA_SCRIPTS/container-restart.sh

name=$1
id=$($KIRA_SCRIPTS/container-id.sh "$name")

if [ -z "$id" ] ; then
    echo "INFO: Container $name does NOT exists"
else
    # NOTE: THIS IS REQUIRED TO TERMINATE TENDERMINT PROCESSES CORRECTLY, WIHTOUT CORRUPTING BLOCCHAIN STATE !!!
    echo "INFO: Container $name ($id) was found, stopping gracefully before restarting..."
    docker container stop $id || echo "WARNING: Container $name ($id) could NOT be restarted"
    echo "INFO: Container $name ($id) was found, restarting..."
    docker container restart $id || echo "WARNING: Container $name ($id) could NOT be restarted"
fi
