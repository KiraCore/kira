#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
exec 2>&1

# Local Update Shortcut:
# (rm -fv $KIRA_SCRIPTS/container-delete.sh) && nano $KIRA_SCRIPTS/container-delete.sh && chmod 777 $KIRA_SCRIPTS/container-delete.sh

name=$1
id=$($KIRA_SCRIPTS/container-id.sh "$name")

# e.g. registry:2
if [ -z "$id" ] || [[ "$id" == *"sha256"* ]] ; then
    echo "INFO: Container $name does NOT exists"
else
    echo "INFO: Container $name ($id) was found, deleting..."

    docker container kill $id || echo "WARNING: Container $id is not running"
    docker rm $id
    sleep 1
    id=$($KIRA_SCRIPTS/container-id.sh "$name")

    if [ -z "$id" ] ; then
        echo "SUCCESS: Container $name was killed and removed"
        exit 0
    else
        
        echo "INFO: Failed to kill or delete container $name ($id)"
        exit 0
    fi
fi
