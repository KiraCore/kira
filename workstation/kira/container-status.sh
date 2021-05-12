#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e && set -x
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/container-status.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NAME=$1
NETWORKS=$2
ID=$3
timerStart

set +x
echoWarn "--------------------------------------------------"
echoWarn "|  STARTING KIRA CONTAINER STATUS SCAN $KIRA_SETUP_VER  |"
echoWarn "|-------------------------------------------------"
echoWarn "| CONTAINER NAME: $NAME"
echoWarn "|       NETWORKS: $NETWORKS"
echoWarn "|             ID: $ID"
echoWarn "|-------------------------------------------------"
set -x

# define global variables
if [ "${NAME,,}" == "interx" ]; then
    BRANCH="$INTERX_BRANCH"
    REPO="$INTERX_REPO"
elif [ "${NAME,,}" == "frontend" ]; then
    BRANCH="$FRONTEND_BRANCH"
    REPO="$FRONTEND_REPO"
elif [ "${NAME,,}" == "sentry" ] || [ "${NAME,,}" == "priv_sentry" ] || [ "${NAME,,}" == "snapshot" ] ; then
    BRANCH="$SEKAI_BRANCH"
    REPO="$SEKAI_REPO"
elif [ "${NAME,,}" == "validator" ]; then
    BRANCH="$SEKAI_BRANCH"
    REPO="$SEKAI_REPO"
elif [ "${NAME,,}" == "registry" ]; then
    BRANCH="https://github.com/docker/distribution"
    REPO="master"
fi

DOCKER_INSPECT=$(globGetFile "${NAME}_DOCKER_INSPECT")

if (! $(isNullOrEmpty "$ID")) ; then
    EXISTS="true"
    echo $(timeout 4 docker inspect "$ID" 2> /dev/null || echo -n "") > $DOCKER_INSPECT
else
    EXISTS="false"
fi

globSet "${NAME}_ID" $ID
globSet "${NAME}_EXISTS" $EXISTS
globSet "${NAME}_REPO" $REPO
globSet "${NAME}_BRANCH" $BRANCH

if [ "${EXISTS,,}" == "true" ] ; then
    COMMON_PATH="$DOCKER_COMMON/$NAME"
    HALT_FILE="$COMMON_PATH/halt"
    CONFIG_FILE="$COMMON_PATH/configuring"
    
    DOCKER_STATE=$(globGetFile "${NAME}_DOCKER_STATE")
    DOCKER_NETWORKS=$(globGetFile "${NAME}_DOCKER_NETWORKS")

    echoInfo "INFO: Sucessfully inspected '$NAME' container '$ID'"
    jsonParse "0.State" $DOCKER_INSPECT $DOCKER_STATE || echo -n "" > $DOCKER_STATE
    jsonParse "0.NetworkSettings.Networks" $DOCKER_INSPECT $DOCKER_NETWORKS || echo -n "" > $DOCKER_NETWORKS

    if [ -f "$HALT_FILE" ] ; then
        globSet "${NAME}_STATUS" "halted"
    elif [ -f "$CONFIG_FILE" ] ; then 
        globSet "${NAME}_STATUS" "configuring"
    else
        echo $(jsonQuickParse "Status" $DOCKER_STATE 2> /dev/null || echo -n "") | globSet "${NAME}_STATUS"
    fi

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

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINER '$NAME' STATUS SCAN"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x

# Examples:
# cat "$SCAN_LOGS/sentry-status.error.log"