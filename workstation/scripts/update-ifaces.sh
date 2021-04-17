#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/scripts/update-ifaces.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

START_TIME_SCRIPT="$(date -u +%s)"
ifaces_iterate=$(ifconfig | cut -d ' ' -f1 | tr ':' '\n' | awk NF)

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: NETWORKING v0.0.7                   |"
echoWarn "|-----------------------------------------------"
echoWarn "| NETWORK INTERFACES: $ifaces_iterate"
echoWarn "------------------------------------------------"
set -x

echoInfo "INFO: Stopping docker, then removing and recreating all docker-created network interfaces"
systemctl stop docker || echoWarn "WARNINIG: Failed to stop docker service"
ifaces=( $ifaces_iterate )
for f in $ifaces_iterate ; do
    if [ "$f" == "docker0" ] || [[ "$f" =~ ^br-.*$ ]]; then
        echoInfo "INFO: Found docker network interface $f, removing..."
        ip link set $f || echoWarn "WARNINIG: Failed ip link set interface $f"
        brctl delbr $f || echoWarn "WARNINIG: Failed brctl delbr interface $f"
    else
        echoInfo "INFO: Network interface $f does not belong to docker"
    fi
done
systemctl start docker || echoWarn "WARNINIG: Failed to start docker service"

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: NETWORK INTERFACES FIX SCRIPT      |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $START_TIME_SCRIPT)) seconds"
echoWarn "------------------------------------------------"
set -x