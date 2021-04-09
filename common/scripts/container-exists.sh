#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
exec 2>&1

# Local Update Shortcut:
# (rm -fv $KIRA_SCRIPTS/container-exists.sh) && nano $KIRA_SCRIPTS/container-exists.sh && chmod 777 $KIRA_SCRIPTS/container-exists.sh

name=$1
id=$($KIRA_SCRIPTS/container-id.sh "$name")

# e.g. registry:2
if [ -z "$id" ] ; then
    echo "false"
else
    echo "true"
fi
