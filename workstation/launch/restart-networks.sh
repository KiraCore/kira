#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/scripts/restart-networks.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE
set -x

RECONNECT=$1
TARGET=$2
RESTART=$3

[ -z "$RECONNECT" ] && RECONNECT="true"
[ -z "$RESTART" ] && RESTART="true"
( [ "$TARGET" == "null" ] || [ "$TARGET" == "*" ] ) && TARGET=""

START_TIME="$(date -u +%s)"
MTU=$(globGet MTU)

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: RESTART-NETWORKS SCRIPT             |"
echoWarn "|-----------------------------------------------"
echoWarn "| BASH SOURCE: ${BASH_SOURCE[0]}"
echoWarn "|   RECONNECT: $RECONNECT"
echoWarn "|     RESTART: $RESTART"
echoWarn "|      TARGET: $TARGET"
echoWarn "|         MTU: $MTU"
echoWarn "------------------------------------------------"
set -x

if [ -z "$TARGET" ] && [ "${RECONNECT,,}" != "true" ] ; then
    echoInfo "INFO: Pruning dangling networks..."
    docker network prune --force || echo "WARNING: Failed to prune dangling networks"
fi

declare -a networks=("sentrynet" "servicenet")
declare -a subnets=("$KIRA_SENTRY_SUBNET" "$KIRA_SERVICE_SUBNET")
len=${#networks[@]}

for (( i=0; i<${len}; i++ )) ; do
    network=${networks[$i]}
    subnet=${subnets[$i]}
    if [ ! -z "$TARGET" ] && [ "$network" != "$TARGET" ] ; then
        echoInfo "INFO: Target network is '$TARGET' the '$network' network will not be reconnected"
        continue
    fi
    echoInfo "INFO: Restarting $network ($subnet)"
    containers=$(timeout 8 docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' $network 2> /dev/null || echo -n "")
  
    if [ ! -z "$containers" ] && [ "${containers,,}" != "null" ] ; then
        for container in $containers ; do
            echoInfo "INFO: Disconnecting container '$container'"
            docker network disconnect -f $network $container || echoWarn "WARNING: Failed to disconnect container '$container' from network '$network'"
        done
    else
        echoInfo "INFO: No containers were found to be attached to $network network"
    fi
  
    sleep 1 && docker network rm $network || echoWarn "WARNING: Failed to remove $network network"
    sleep 1 && docker network create --opt com.docker.network.driver.mtu=$MTU --subnet=$subnet $network || echoWarn "WARNING: Failed to re-create $network network"
    
    if [ "${RECONNECT,,}" == "true" ] && [ ! -z "$containers" ] && [ "${containers,,}" != "null" ] ; then
        for container in $containers ; do
            echoInfo "INFO: Connecting container $container to $network"
            docker network connect $network $container
            sleep 1
        done
    else
        echoInfo "INFO: Containers will NOT be recconected to the '$network' network"
    fi
done

if [ "${RESTART,,}" == "true" ] ; then
    echoInfo "INFO: Restarting docker & networking..."
    $KIRA_MANAGER/scripts/update-ifaces.sh
    echoInfo "INFO: Waiting for containers to start..."
    sleep 120
    $KIRA_MANAGER/scripts/update-hosts.sh
else
    echoInfo "INFO: Network interfaces and hosts will NOT be restarted"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: RESTART-NETWORKS SCRIPT            |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x
