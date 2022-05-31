#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e && set -x
# quick edit: FILE="$KIRA_MANAGER/kira/container-status.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NAME=$1
NETWORKS=$2

timerStart "${NAME}_CONTAINER_STATUS"

[ -z "$NETWORKS" ] && NETWORKS=$(globGet NETWORKS)

set +x
echoWarn "--------------------------------------------------"
echoWarn "|  STARTING KIRA CONTAINER STATUS SCAN $KIRA_SETUP_VER"
echoWarn "|-------------------------------------------------"
echoWarn "| CONTAINER NAME: $NAME"
echoWarn "|       NETWORKS: $NETWORKS"
echoWarn "|-------------------------------------------------"
set -x

DOCKER_INSPECT=$(globFile "${NAME}_DOCKER_INSPECT")
ID=$($KIRA_SCRIPTS/container-id.sh "$NAME" 2> /dev/null || echo -n "")

if (! $(isNullOrEmpty "$ID")) ; then
    echo $(timeout 4 docker inspect "$ID" 2> /dev/null || echo -n "") | globSet "${NAME}_DOCKER_INSPECT"
    (! $(isFileEmpty $DOCKER_INSPECT)) && EXISTS="true" || EXISTS="false"
else
    EXISTS="false"
fi

globSet "${NAME}_ID" $ID
globSet "${NAME}_EXISTS" $EXISTS

if [ "${EXISTS,,}" == "true" ] ; then
    COMMON_PATH="$DOCKER_COMMON/$NAME"
    GLOBAL_COMMON="$COMMON_PATH/kiraglob"

    DOCKER_STATE=$(globFile "${NAME}_DOCKER_STATE")
    DOCKER_NETWORKS=$(globFile "${NAME}_DOCKER_NETWORKS")
    SNAPSHOT_TARGET=$(globGet SNAPSHOT_TARGET)
    SNAPSHOT_EXECUTE=$(globGet SNAPSHOT_EXECUTE)

    echoInfo "INFO: Sucessfully inspected '$NAME' container '$ID'"
    jsonParse "0.State" $DOCKER_INSPECT $DOCKER_STATE || echoErr "ERROR: Failed to parsing docker state"
    jsonParse "0.NetworkSettings.Networks" $DOCKER_INSPECT $DOCKER_NETWORKS || echoErr "ERROR: Failed to parsing docker networks"

    IS_SYNCING=$(globGet "${SNAPSHOT_TARGET}_SYNCING")
    if [ "${SNAPSHOT_EXECUTE,,}" == "true" ] && [ "${SNAPSHOT_TARGET}" == "${NAME,,}" ] && ( [ "${IS_SYNCING,,}" != "true" ] || [ "$(globGet HALT_TASK $GLOBAL_COMMON)" == "true" ] ) ; then
        globSet "${NAME}_STATUS" "backing up"
    elif [ "$(globGet HALT_TASK $GLOBAL_COMMON)" == "true" ] ; then
        globSet "${NAME}_STATUS" "halted"
    elif [ "$(globGet CFG_TASK $GLOBAL_COMMON)" == "true" ] || ( [ "$(globGet INIT_DONE $GLOBAL_COMMON)" != "true" ] && [[ "${NAME,,}" =~ ^(validator|sentry|seed|interx)$ ]] ) ; then 
        globSet "${NAME}_STATUS" "configuring"
    else
        echo $(jsonQuickParse "Status" $DOCKER_STATE 2> /dev/null || echo -n "") | globSet "${NAME}_STATUS"
    fi

    #  echo -e $(jsonParse "Health.Log.[0].Output" $DOCKER_STATE)
    echo $(jsonParse "Health.Status" $DOCKER_STATE 2> /dev/null || echo -n "") | globSet "${NAME}_HEALTH"
    echo $(jsonQuickParse "Paused" $DOCKER_STATE 2> /dev/null || echo -n "")  | globSet "${NAME}_PAUSED"
    echo $(jsonQuickParse "Restarting" $DOCKER_STATE 2> /dev/null || echo -n "") | globSet "${NAME}_RESTARTING"
    echo $(jsonQuickParse "StartedAt" $DOCKER_STATE 2> /dev/null || echo -n "") | globSet "${NAME}_STARTED_AT"
    echo $(jsonQuickParse "FinishedAt" $DOCKER_STATE 2> /dev/null || echo -n "") | globSet "${NAME}_FINISHED_AT"
    echo $(jsonParse "0.Config.Hostname" $DOCKER_INSPECT 2> /dev/null || echo -n "") | globSet "${NAME}_HOSTNAME"
    echo $(docker ps --format "{{.Ports}}" -aqf "id=$ID" 2> /dev/null || echo -n "") | globSet "${NAME}_PORTS"
    
    for net in $NETWORKS; do
        sleep 0.1
        IP_TMP=$(jsonParse "$net.IPAddress" $DOCKER_NETWORKS 2> /dev/null || echo -n "")
        ($(isNullOrEmpty "$IP_TMP")) && globSet "${NAME}_IP_${net}" "" && continue
        echo "$IP_TMP" | globSet "${NAME}_IP_${net}"
    done
else
    echoErr "ERROR: Could not inspect '$NAME' container '$ID'"
    globSet "${NAME}_STATUS" "stopped"
    globSet "${NAME}_HEALTH" ""
    globSet "${NAME}_PAUSED" "false"
    globSet "${NAME}_RESTARTING" "false"
    globSet "${NAME}_STARTED_AT" "0"
    globSet "${NAME}_FINISHED_AT" "0"
    globSet "${NAME}_HOSTNAME" ""
    globSet "${NAME}_PORTS" ""
fi

globSet "${NAME}_SCAN_DONE" "true"

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINER '$NAME' STATUS SCAN"
echoWarn "|-----------------------------------------------"
echoWarn "| SCAN DONE: $(globGet ${NAME}_SCAN_DONE)"
echoWarn "|  ELAPSED: $(timerSpan ${NAME}_CONTAINER_STATUS) seconds"
echoWarn "------------------------------------------------"
set -x
