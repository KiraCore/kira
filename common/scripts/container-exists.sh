#!/bin/bash

exec 2>&1
set -e

# Local Update Shortcut:
# (rm -fv $KIRA_SCRIPTS/container-exists.sh) && nano $KIRA_SCRIPTS/container-exists.sh && chmod 777 $KIRA_SCRIPTS/container-exists.sh

name=$1
id=$(docker ps --no-trunc -aqf name="$name" 2> /dev/null || echo "")

# e.g. registry:2
if [ -z "$id" ] ; then
    echo "False"
else
    echo "True"
fi
