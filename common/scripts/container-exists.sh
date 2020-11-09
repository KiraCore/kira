#!/bin/bash

exec 2>&1
set -e

# Local Update Shortcut:
# (rm -fv $KIRA_SCRIPTS/container-exists.sh) && nano $KIRA_SCRIPTS/container-exists.sh && chmod 777 $KIRA_SCRIPTS/container-exists.sh

name=$1

# e.g. registry:2
if [[ $(docker ps -a --format '{{.Names}}' | grep -Eq "^${name}\$" || echo False) == "False" ]] ; then
    echo "False"
else
    echo "True"
fi
