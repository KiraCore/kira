#!/bin/bash

exec 2>&1
set -e

# Local Update Shortcut:
# (rm -fv $KIRA_SCRIPTS/container-stop.sh) && nano $KIRA_SCRIPTS/container-stop.sh && chmod 777 $KIRA_SCRIPTS/container-stop.sh

name=$1

if [[ $(docker ps -a --format '{{.Names}}' | grep -Eq "^${name}\$" || echo False) == "False" ]] ; then
    echo "INFO: Container $name does NOT exists"
else
    id=$(docker inspect --format="{{.Id}}" ${name} 2> /dev/null)
    echo "INFO: Container $name ($id) was found, stopping..."
    docker container stop $id || echo "WARNING: Container $id could NOT be stopped"
fi
