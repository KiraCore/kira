#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_SCRIPTS/docker-stop.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE

if ! command "docker" 2> /dev/null ; then 
    echo "INFO: No need to stop docker, command was NOT found" 
    exit 0
fi

STATUS=$(systemctl is-active docker || echo -n "") && [ -z "$STATUS" ] && STATUS="undefined"

if [ "${STATUS,,}" == "inactive" ] ; then
    echo "INFO: Doceker service was already stopped ($STATUS)"
    exit 0
else
    echo "INFO: Stopping docker service ($STATUS)..."
fi

set +e
while true; do
    pkill -9 $(pidof containerd) && pkill -9 $(pidof dockerd)
    if [[ ! "$?" = "0" ]]; then
        break
    fi
done
set -e

FAIL="false"
timeout 120 systemctl stop docker || FAIL="true"
STATUS=$(systemctl is-active docker || echo -n "") && [ -z "$STATUS" ] && STATUS="undefined"
[ "${FAIL,,}" == "true"  ] && echo "ERROR: Failed to stop docker service ($STATUS)" && exit 1
echo "INFO: Success docker service was stopped ($STATUS)..."
exit 0