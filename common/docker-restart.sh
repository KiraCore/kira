#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_COMMON/docker-restart.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE

if (! $(isCommand "docker")) ; then 
    echo "WARNING: Can NOT restart docker, command was NOT found"
    exit 0
fi

$KIRA_COMMON/docker-stop.sh
systemctl daemon-reload  || echoWarn "WARNING: Failed daemon-reload"
service docker restart || echoWarn "WARNING: Failed to restart docker"
systemctl status docker -l --no-pager || echoWarn "WARNING: Docker service status check failed"

