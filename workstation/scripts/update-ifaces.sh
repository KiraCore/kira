#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/scripts/update-ifaces.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

START_TIME_SCRIPT="$(date -u +%s)"
ifaces_iterate=$(ifconfig | cut -d ' ' -f1 | tr ':' '\n' | awk NF)

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: NETWORKING v0.0.7                   |"
echoWarn "------------------------------------------------"

echoInfo "INFO: Interfaces before cleanup:"
echoInfo "$(ifconfig | cut -d ' ' -f1 | tr ':' '\n' | awk NF || echo '')"

echoInfo "INFO: Stopping docker, then removing and recreating all docker-created network interfaces"
systemctl stop docker || echoWarn "WARNINIG: Failed to stop docker service"
ifaces=( $ifaces_iterate )

for f in $ifaces_iterate ; do
    if [ "$f" == "docker0" ] || [[ "$f" =~ ^br-.*$ ]]; then
        echoInfo "INFO: Found docker network interface $f, removing..."
        set -x
        ip link set $f down || echoWarn "WARNINIG: Failed ip link set down interface $f"
        brctl delbr $f || echoWarn "WARNINIG: Failed brctl delbr interface $f"
        set +x
    else
        echoInfo "INFO: Network interface $f does not belong to docker"
    fi
done

echoInfo "INFO: Interfaces before restart:"
echoInfo "$(ifconfig | cut -d ' ' -f1 | tr ':' '\n' | awk NF || echo '')"
systemctl start docker || echoWarn "WARNINIG: Failed to start docker service"
echoInfo "INFO: Interfaces after restart:"
echoInfo "$(ifconfig | cut -d ' ' -f1 | tr ':' '\n' | awk NF || echo '')"

echoWarn "------------------------------------------------"
echoWarn "| FINISHED: NETWORK INTERFACES FIX SCRIPT      |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $START_TIME_SCRIPT)) seconds"
echoWarn "------------------------------------------------"