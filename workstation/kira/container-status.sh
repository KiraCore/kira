#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e && set -x
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/container-status.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NAME=$1
VARS_FILE=$2
NETWORKS=$3
ID=$4
SCRIPT_START_TIME="$(date -u +%s)"

set +x
echoWarn "--------------------------------------------------"
echoWarn "|  STARTING KIRA CONTAINER STATUS SCAN v0.2.4.02 |"
echoWarn "|-------------------------------------------------"
echoWarn "| CONTAINER NAME: $NAME"
echoWarn "|      VARS_FILE: $VARS_FILE"
echoWarn "|       NETWORKS: $NETWORKS"
echoWarn "|             ID: $ID"
echoWarn "|-------------------------------------------------"
set -x

COMMON_PATH="$DOCKER_COMMON/$NAME"
HALT_FILE="$COMMON_PATH/halt"

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

DOCKER_INSPECT="$VARS_FILE.inspect"
DOCKER_STATE="$DOCKER_INSPECT.state"
DOCKER_CONFIG="$DOCKER_INSPECT.config"
DOCKER_NETWORKS="$DOCKER_INSPECT.networks"

if (! $(isNullOrEmpty "$ID")) ; then
    EXISTS="true"
    echo $(timeout 4 docker inspect "$ID" 2> /dev/null || echo -n "") > $DOCKER_INSPECT
else
    EXISTS="false"
fi

echo "ID_$NAME=\"$ID\"" > $VARS_FILE
echo "EXISTS_$NAME=\"$EXISTS\"" >> $VARS_FILE

if [ "${EXISTS,,}" == "true" ] ; then
    echoInfo "INFO: Sucessfully inspected '$NAME' container '$ID'"
    (jsonParse "0.State" $DOCKER_INSPECT || echo -n "") > $DOCKER_STATE
    (jsonParse "0.NetworkSettings.Networks" $DOCKER_INSPECT || echo -n "") > $DOCKER_NETWORKS

    STATUS=$(jsonQuickParse "Status" $DOCKER_STATE 2> /dev/null || echo -n "")
    PAUSED=$(jsonQuickParse "Paused" $DOCKER_STATE 2> /dev/null || echo -n "")
    RESTARTING=$(jsonQuickParse "Restarting" $DOCKER_STATE 2> /dev/null || echo -n "")
    STARTED_AT=$(jsonQuickParse "StartedAt" $DOCKER_STATE 2> /dev/null || echo -n "")
    FINISHED_AT=$(jsonQuickParse "FinishedAt" $DOCKER_STATE 2> /dev/null || echo -n "")
    HOSTNAME=$(jsonParse "0.Config.Hostname" $DOCKER_INSPECT 2> /dev/null || echo -n "")
    PORTS=$(docker ps --format "{{.Ports}}" -aqf "id=$ID" 2> /dev/null || echo -n "")
    [ -f "$HALT_FILE" ] && HEALTH="halted" || HEALTH=$(jsonParse "Health.Status" $DOCKER_STATE 2> /dev/null || echo -n "")

    for net in $NETWORKS; do
        sleep 0.1
        IP_TMP=$(jsonParse "$net.IPAddress" $DOCKER_NETWORKS 2> /dev/null || echo -n "")
        (! $(isNullOrEmpty "$IP_TMP")) && echo "IP_${NAME}_$net=\"$IP_TMP\"" >> $VARS_FILE || echo "IP_${NAME}_$net=\"\"" >> $VARS_FILE
    done
else
    echoErr "ERROR: Could not inspect '$NAME' container '$ID'"
    STATUS=""
    PAUSED=""
    HEALTH=""
    RESTARTING=""
    STARTED_AT=""
    FINISHED_AT=""
    rm -fv $DOCKER_STATE $DOCKER_CONFIG $DOCKER_NETWORKS
fi

[ -z "$STATUS" ] && STATUS="stopped"
[ -z "$PAUSED" ] && PAUSED="false"
[ -z "$HEALTH" ] && HEALTH="undefined"
[ -z "$RESTARTING" ] && RESTARTING="false"
[ -z "$STARTED_AT" ] && STARTED_AT="0"
[ -z "$FINISHED_AT" ] && FINISHED_AT="0"

echoInfo "INFO: Dumpiung data into '$VARS_FILE'"

echo "STATUS_$NAME=\"$STATUS\"" >> $VARS_FILE
echo "PAUSED_$NAME=\"$PAUSED\"" >> $VARS_FILE
echo "HEALTH_$NAME=\"$HEALTH\"" >> $VARS_FILE
echo "RESTARTING_$NAME=\"$RESTARTING\"" >> $VARS_FILE
echo "STARTED_AT_$NAME=\"$STARTED_AT\"" >> $VARS_FILE
echo "FINISHED_AT_$NAME=\"$FINISHED_AT\"" >> $VARS_FILE
echo "BRANCH_$NAME=\"$BRANCH\"" >> $VARS_FILE
echo "REPO_$NAME=\"$REPO\"">> $VARS_FILE
echo "HOSTNAME_$NAME=\"$HOSTNAME\"" >> $VARS_FILE
echo "PORTS_$NAME=\"$PORTS\"" >> $VARS_FILE

echoInfo "INFO: Printing scan results: "
cat $VARS_FILE

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINER '$NAME' STATUS SCAN"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x

# Examples:
# VARS_FILE=/home/ubuntu/kirascan/status/sentry.tmp
# cat "$SCAN_LOGS/sentry-status.error.log"