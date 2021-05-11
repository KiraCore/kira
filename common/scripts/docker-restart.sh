#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_SCRIPTS/docker-restart.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE

if ! command "docker" 2> /dev/null ; then 
    echo "WARNING: Can NOT restart docker, command was NOT found"
    exit 0
fi

$KIRA_SCRIPTS/docker-stop.sh
systemctl daemon-reload  || echo "WARNING: Failed daemon-reload"
service docker restart || echo "ERROR: Failed to restart docker"
