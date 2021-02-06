#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/scripts/restart-networks.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE
set -x

RECONNECT=$1
TARGET=$2
RESTART=$3

[ -z "$RECONNECT" ] && RECONNECT="true"
[ -z "$RESTART" ] && RESTART="true"
( [ "$TARGET" == "null" ] || [ "$TARGET" == "*" ] ) && TARGET=""

START_TIME="$(date -u +%s)"
set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: RESTART-NETWORKS SCRIPT             |"
echoWarn "|-----------------------------------------------"
echoWarn "| RECONNECT: $RECONNECT"
echoWarn "|    TARGET: $TARGET"
echoWarn "------------------------------------------------"
set -x

if [ -z "$TARGET" ] && [ "${RECONNECT,,}" != "true" ] ; then
    echo "INFO: Pruning dangling networks..."
    docker network prune --force || echo "WARNING: Failed to prune dangling networks"
fi

declare -a networks=("kiranet" "sentrynet" "servicenet" "regnet")
declare -a subnets=("$KIRA_VALIDATOR_SUBNET" "$KIRA_SENTRY_SUBNET" "$KIRA_SERVICE_SUBNET" "$KIRA_REGISTRY_SUBNET")
len=${#networks[@]}

for (( i=0; i<${len}; i++ )) ; do
  network=${networks[$i]}
  subnet=${subnets[$i]}
  if [ ! -z "$TARGET" ] && [ "$network" != "$TARGET" ] ; then
    echo "INFO: Target network is '$TARGET' the '$network' network will not be reconnected"
    continue
  fi
  echo "INFO: Restarting $network ($subnet)"
  containers=$(docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' $network 2> /dev/null || echo "")

  if [ ! -z "$containers" ] && [ "${containers,,}" != "null" ] ; then
      for container in $containers ; do
         echo "INFO: Disconnecting container '$container'"
         docker network disconnect -f $network $container || echo "INFO: Failed to disconnect container '$container' from network '$network'"
      done
  else
    echo "INFO: No containers were found to be attached to $network network"
  fi

  sleep 1 && docker network rm $network || echo "INFO: Failed to remove $network network"
  sleep 1 && docker network create --subnet=$subnet $network || echo "INFO: Failed to create $network network"

  if [ "${RECONNECT,,}" == "true" ] && [ ! -z "$containers" ] && [ "${containers,,}" != "null" ] ; then
    for container in $containers ; do
      echo "INFO: Connecting container $container to $network"
      docker network connect $network $container
      sleep 1
    done
  else
    echo "INFO: Containers will NOT be recconected to the '$network' network"
  fi
done

echo "INFO: Restarting docker networking..."

systemctl daemon-reload
systemctl restart docker || ( journalctl -u docker | tail -n 10 && systemctl restart docker )
systemctl restart NetworkManager docker || echo "WARNING: Failed to restart network manager"

$KIRA_MANAGER/scripts/update-hosts.sh

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: RESTART-NETWORKS SCRIPT            |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x

# 