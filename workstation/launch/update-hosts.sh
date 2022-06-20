#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/scripts/update-hosts.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE
set -x

START_TIME="$(date -u +%s)"
set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: HOSTS-UPDATE SCRIPT v0.2.2.4        |"
echoWarn "|-----------------------------------------------"
echoWarn "| RECONNECT: $RECONNECT"
echoWarn "|    TARGET: $TARGET"
echoWarn "------------------------------------------------"
set -x

declare -a networks=("sentrynet" "servicenet")
declare -a subnets=("$KIRA_SENTRY_SUBNET" "$KIRA_SERVICE_SUBNET")
len=${#networks[@]}

echo "INFO: Updating DNS names of all containers in the local hosts file"
for (( i=0; i<${len}; i++ )) ; do
    network=${networks[$i]}
    containers=$(timeout 8 docker network inspect -f '{{range .Containers}}{{.Name}} {{end}}' $network 2> /dev/null || echo -n "")
    ( [ -z "$containers" ] || [ "${containers,,}" == "null" ] ) && continue
      
    for container in $containers ; do
      echo "INFO: Checking $container network info"
      id=$($KIRA_COMMON/container-id.sh "$container")
      ip=$(timeout 8 docker inspect $id | jsonParse "0.NetworkSettings.Networks.${network}.IPAddress" || echo -n "")
      dns=$(echo "${container,,}.local" | tr _ -)

      currentDNS=$(getent hosts $dns | awk '{ print $1 }' || echo -n "")
      if [ "$currentDNS" == "$ip" ] ; then
        echo "INFO: IP did not changed, no point to update hosts!"
        continue
      fi

      echo "INFO: IP changed, hosts list must be updated"
      CDHelper text lineswap --insert="" --regex="$dns" --path=$HOSTS_PATH --prepend-if-found-not=True

      if [ ! -z "$ip" ] && [ "${ip,,}" != "null" ] ; then
          echo "INFO: IP Address '$ip' found, binding host..."
          CDHelper text lineswap --insert="$ip $dns" --regex="$dns" --path=$HOSTS_PATH --prepend-if-found-not=True
      fi
      sort -u $HOSTS_PATH -o $HOSTS_PATH
    done
done

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: UPDATE-HOSTS SCRIPT                |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x
