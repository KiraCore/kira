#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/scripts/update-hosts.sh" && rm -fv $FILE && nano $FILE && chmod 555 $FILE
set -x

START_TIME="$(date -u +%s)"
KIRA_DOCKER_NETWORK=$(globGet KIRA_DOCKER_NETWORK)
HOSTS_PATH="/etc/hosts" 

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: HOSTS-UPDATE SCRIPT v0.2.2.4        |"
echoWarn "|-----------------------------------------------"
echoWarn "|           RECONNECT: $RECONNECT"
echoWarn "|              TARGET: $TARGET"
echoWarn "|          HOSTS PATH: $HOSTS_PATH"
echoWarn "| KIRA DOCEKR NETWORK: $KIRA_DOCKER_NETWORK"
echoWarn "------------------------------------------------"
set -x

echoInfo "INFO: Updating DNS names of all containers in the local hosts file"
containers=$(timeout 8 docker ps -a | awk '{if(NR>1) print $NF}' | tac  2> /dev/null || echo -n "")
( [ -z "$containers" ] || [ "${containers,,}" == "null" ] ) && continue

for container in $containers ; do
    echoInfo "INFO: Checking $container network info"
    
    id=$($KIRA_COMMON/container-id.sh "$container")
    ip=$(timeout 8 docker inspect $id | jsonParse "0.NetworkSettings.Networks.${KIRA_DOCKER_NETWORK}.IPAddress" || echo -n "")
  
    if [ -z "$ip" ] || [ "${ip,,}" == "null" ] ; then
      echoWarn "WARNING: Ip address of the container '$container' is NOT known, can't bind DNS!"
      continue
    fi
  
    dns=$(echo "${container,,}.local" | tr _ -)
    currentDNS=$(getent hosts $dns | awk '{ print $1 }' || echo -n "")
    globDNS=$(globGet "${container,,}.local" $GLOBAL_COMMON_RO)
    if [ "$currentDNS" == "$ip" ] && [ "$globDNS" == "$ip" ] ; then
      echoInfo "INFO: IP did not changed, no point to update hosts!"
      continue
    fi
  
    echoInfo "INFO: IP Address '$ip' of the '$container' container changed, binding new host..."
    # delete existing record that maps the IP address
    setLastLineBySubStrOrAppend "$ip" "" $HOSTS_PATH
    # update or append new record to map the IP address
    setLastLineBySubStrOrAppend "$dns" "$ip $dns" $HOSTS_PATH
    sort -u $HOSTS_PATH -o $HOSTS_PATH
    # publish gobl dns
    globSet "${container,,}.local" "$ip" $GLOBAL_COMMON_RO
done

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: UPDATE-HOSTS SCRIPT                |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x
