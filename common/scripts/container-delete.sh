#!/bin/bash

exec 2>&1
set -e

# Local Update Shortcut:
# (rm -fv $KIRA_SCRIPTS/container-delete.sh) && nano $KIRA_SCRIPTS/container-delete.sh && chmod 777 $KIRA_SCRIPTS/container-delete.sh

name=$1

# e.g. registry:2
if [[ $(docker ps -a --format '{{.Names}}' | grep -Eq "^${name}\$" || echo False) == "False" ]] ; then
    echo "INFO: Container $name does NOT exists"
else
    id=$(docker inspect --format="{{.Id}}" ${name} 2> /dev/null)
    echo "INFO: Container $name ($id) was found, deleting..."

    docker container kill $id || echo "WARNING: Container $id is not running"
    docker rm $id
    echo "SUCCESS: Container $name was killed and removed"
fi
