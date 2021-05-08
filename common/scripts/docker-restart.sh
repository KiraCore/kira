#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_SCRIPTS/docker-restart.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE

(! $(isCommand "docker")) && echo "WARNING: Can NOT restart docker, command was NOT found" && exit 0

$KIRA_SCRIPTS/docker-stop.sh
systemctl daemon-reload  || echoWarn "WARNING: Failed daemon-reload"
service docker restart || echoErr "ERROR: Failed to restart docker"
