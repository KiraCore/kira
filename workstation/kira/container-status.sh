#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e && set -x
# quick edit: FILE="$KIRA_MANAGER/kira/container-status.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

name=$1
NETWORKS=$2
timerStart "${name}-container-status"
[ -z "$NETWORKS" ] && NETWORKS=$(globGet NETWORKS)

set +x && echo ""
echoC ";whi;"  " =============================================================================="
echoC ";whi"  "|            STARTED:$(strFixL " KIRA '$name' CONTAINER STATUS SCAN $KIRA_SETUP_VER" 58)|"   
echoC ";whi"  "|------------------------------------------------------------------------------|"
echoC ";whi"  "|     CONTAINER NAME:$(strFixL " $name " 58)|"
echoC ";whi"  "|           NETWORKS:$(strFixL " $NETWORKS " 58)|"
echoC ";whi"  " =============================================================================="
echo "" && set -x 

DOCKER_INSPECT=$(globFile "${name}_DOCKER_INSPECT")
ID=$($KIRA_COMMON/container-id.sh "$name" 2> /dev/null || echo -n "")

if (! $(isNullOrEmpty "$ID")) ; then
    echo $(timeout 4 docker inspect "$ID" 2> /dev/null || echo -n "") | globSet "${name}_DOCKER_INSPECT"
    (! $(isFileEmpty $DOCKER_INSPECT)) && EXISTS="true" || EXISTS="false"
else
    EXISTS="false"
fi

globSet "${name}_ID" $ID
globSet "${name}_EXISTS" $EXISTS

if [ "${EXISTS,,}" == "true" ] ; then
    COMMON_PATH="$DOCKER_COMMON/$name"
    GLOBAL_COMMON="$COMMON_PATH/kiraglob"

    DOCKER_STATE=$(globFile "${name}_DOCKER_STATE")
    DOCKER_NETWORKS=$(globFile "${name}_DOCKER_NETWORKS")
    SNAPSHOT_TARGET=$(globGet SNAPSHOT_TARGET)
    SNAPSHOT_EXECUTE=$(globGet SNAPSHOT_EXECUTE)

    echoInfo "INFO: Sucessfully inspected '$name' container '$ID'"
    jsonParse "0.State" $DOCKER_INSPECT $DOCKER_STATE || echoErr "ERROR: Failed to parsing docker state"
    jsonParse "0.NetworkSettings.Networks" $DOCKER_INSPECT $DOCKER_NETWORKS || echoErr "ERROR: Failed to parsing docker networks"

    IS_SYNCING=$(globGet "${SNAPSHOT_TARGET}_SYNCING")
    CONTAINER_STATUS=$(toLower "$(jsonQuickParse "Status" $DOCKER_STATE 2> /dev/null || echo -n "")")

    if [ "$CONTAINER_STATUS" == "running" ] ; then
        if [ "${SNAPSHOT_EXECUTE,,}" == "true" ] && [ "${SNAPSHOT_TARGET}" == "$name" ] && ( [ "${IS_SYNCING,,}" != "true" ] || [ "$(globGet HALT_TASK $GLOBAL_COMMON)" == "true" ] ) ; then
            CONTAINER_STATUS="backing up"
        elif [ "$(globGet HALT_TASK $GLOBAL_COMMON)" == "true" ] ; then
            CONTAINER_STATUS="halted"
        elif [ "$(globGet CFG_TASK $GLOBAL_COMMON)" == "true" ] || ( [ "$(globGet INIT_DONE $GLOBAL_COMMON)" != "true" ] && [[ "$name" =~ ^(validator|sentry|seed|interx)$ ]] ) ; then 
            CONTAINER_STATUS="setting up"
        fi
    fi
    
    globSet "${name}_STATUS" "$CONTAINER_STATUS"
    
    #  echo -e $(jsonParse "Health.Log.[0].Output" $DOCKER_STATE)
    echo $(jsonParse "Health.Status" $DOCKER_STATE 2> /dev/null || echo -n "") | globSet "${name}_HEALTH"
    echo $(jsonQuickParse "Paused" $DOCKER_STATE 2> /dev/null || echo -n "")  | globSet "${name}_PAUSED"
    echo $(jsonQuickParse "Restarting" $DOCKER_STATE 2> /dev/null || echo -n "") | globSet "${name}_RESTARTING"
    echo $(jsonQuickParse "StartedAt" $DOCKER_STATE 2> /dev/null || echo -n "") | globSet "${name}_STARTED_AT"
    echo $(jsonQuickParse "FinishedAt" $DOCKER_STATE 2> /dev/null || echo -n "") | globSet "${name}_FINISHED_AT"
    echo $(jsonParse "0.Config.Hostname" $DOCKER_INSPECT 2> /dev/null || echo -n "") | globSet "${name}_HOSTNAME"
    echo $(docker ps --format "{{.Ports}}" -aqf "id=$ID" 2> /dev/null || echo -n "") | globSet "${name}_PORTS"
    
    for net in $NETWORKS; do
        sleep 0.1
        IP_TMP=$(jsonParse "$net.IPAddress" $DOCKER_NETWORKS 2> /dev/null || echo -n "")
        ($(isNullOrEmpty "$IP_TMP")) && globSet "${name}_IP_${net}" "" && continue
        echo "$IP_TMP" | globSet "${name}_IP_${net}"
    done
else
    echoErr "ERROR: Could not inspect '$name' container '$ID'"
    globSet "${name}_STATUS" "stopped"
    globSet "${name}_HEALTH" ""
    globSet "${name}_PAUSED" "false"
    globSet "${name}_RESTARTING" "false"
    globSet "${name}_STARTED_AT" "0"
    globSet "${name}_FINISHED_AT" "0"
    globSet "${name}_HOSTNAME" ""
    globSet "${name}_PORTS" ""
fi

globSet "${name}_SCAN_DONE" "true"

set +x && echo ""
echoC ";whi"  " =============================================================================="
echoC ";whi"  "|           FINISHED:$(strFixL " KIRA '$name' CONTAINER STATUS SCAN $KIRA_SETUP_VER" 58)|"   
echoC ";whi"  "|            ELAPSED:$(strFixL " $(timerSpan "${name}-container-status") " 58)|"
echoC ";whi"  " =============================================================================="
echo "" && set -x 
