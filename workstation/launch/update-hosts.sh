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

echoInfo "INFO: Updating DNS names of all containers in the local hosts file"
containers=$(timeout 8 docker ps -a | awk '{if(NR>1) print $NF}' | tac  2> /dev/null || echo -n "")
( [ -z "$containers" ] || [ "${containers,,}" == "null" ] ) && continue

for container in $containers ; do
  echoInfo "INFO: Checking $container network info"
  id=$($KIRA_COMMON/container-id.sh "$container")
  ip=$(timeout 8 docker inspect $id | jsonParse "0.NetworkSettings.Networks.${KIRA_DOCEKR_NETWORK}.IPAddress" || echo -n "")
  dns=$(echo "${container,,}.local" | tr _ -)

  currentDNS=$(getent hosts $dns | awk '{ print $1 }' || echo -n "")
  if [ "$currentDNS" == "$ip" ] ; then
    echoInfo "INFO: IP did not changed, no point to update hosts!"
    continue
  fi

  if [ ! -z "$ip" ] && [ "${ip,,}" != "null" ] ; then
      echoInfo "INFO: IP Address '$ip' of the '$container' container changed, binding new host..."
      setLastLineBySubStrOrAppend "$dns" "$ip $dns" $HOSTS_PATH
      sort -u $HOSTS_PATH -o $HOSTS_PATH
  fi
done

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: UPDATE-HOSTS SCRIPT                |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x
