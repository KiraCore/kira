#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e && set -x
# quick edit: FILE="$KIRA_MANAGER/kira/container-status.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

echo "INFO: Started '$1' container status scan v0.0.3"

NAME=$1
VARS_FILE=$2
NETWORKS=$3
ID=$4

[ -z "$ID" ] && ID=$($KIRA_SCRIPTS/container-id.sh "$NAME" 2> /dev/null || echo "")
EXISTS="true" && [ -z "$ID" ] && EXISTS="false"

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

if [ "${EXISTS,,}" == "true" ]; then # container exists
    # (docker ps --no-trunc -aqf name=$NAME)
    [ -z "$NETWORKS" ] && NETWORKS=$(docker network ls --format="{{.Name}}" || "")

    DOCKER_INSPECT="$VARS_FILE.inspect"
    echo $(docker inspect "$ID" 2> /dev/null | jq -r '.[0]' || echo "") > $DOCKER_INSPECT

    STATUS=$(cat "$DOCKER_INSPECT" | jq -r '.State.Status' 2> /dev/null || echo "")
    PAUSED=$(cat "$DOCKER_INSPECT" | jq -r '.State.Paused'  2> /dev/null || echo "")
    RESTARTING=$(cat "$DOCKER_INSPECT" | jq -r '.State.Restarting' 2> /dev/null || echo "")
    STARTED_AT=$(cat "$DOCKER_INSPECT" | jq -r '.State.StartedAt' 2> /dev/null || echo "")
    FINISHED_AT=$(cat "$DOCKER_INSPECT" | jq -r '.State.FinishedAt' 2> /dev/null || echo "")
    HOSTNAME=$(cat "$DOCKER_INSPECT" | jq -r '.Config.Hostname' 2> /dev/null || echo "")
    EXPOSED_PORTS=$(cat "$DOCKER_INSPECT" | jq -r '.Config.ExposedPorts' 2> /dev/null | jq 'keys'  2> /dev/null | jq -r '.[]' 2> /dev/null | tr '\n' ','  2> /dev/null | tr -d '"' 2> /dev/null | tr -d '/tcp'  2> /dev/null | sed 's/,$//g' 2> /dev/null || echo "")
    PORTS=$(docker ps --format "{{.Ports}}" -aqf "id=$ID" 2> /dev/null || echo "")
    NETWORK_SETTINGS=$(cat "$DOCKER_INSPECT" 2> /dev/null | jq -r ".NetworkSettings.Networks" 2> /dev/null || echo "")

    [ -f "$HALT_FILE" ] && HEALTH="halted"
    [ ! -f "$HALT_FILE" ] && HEALTH=$(cat "$DOCKER_INSPECT" | jq -r '.State.Health.Status' 2> /dev/null || echo "")

    i=-1
    for net in $NETWORKS; do
        i=$((i + 1))
        IP_TMP=$(echo "$NETWORK_SETTINGS" 2> /dev/null | jq -r ".$net.IPAddress" 2> /dev/null || echo "")
        if [ ! -z "$IP_TMP" ] && [ "${IP_TMP,,}" != "null" ]; then
            eval "IP_$net=$IP_TMP"
        else
            eval "IP_$net=\"\""
        fi
    done
fi

[ -z "$STATUS" ] && STATUS="stopped"
[ -z "$PAUSED" ] && PAUSED="false"
[ -z "$HEALTH" ] && HEALTH="undefined"
[ -z "$RESTARTING" ] && RESTARTING="false"
[ -z "$STARTED_AT" ] && STARTED_AT="0"
[ -z "$FINISHED_AT" ] && FINISHED_AT="0"

echo "INFO: Output file was specified, dumpiung data into '$VARS_FILE'"

echo "ID_$NAME=\"$ID\"" > $VARS_FILE
echo "STATUS_$NAME=\"$STATUS\"" >> $VARS_FILE
echo "PAUSED_$NAME=\"$PAUSED\"" >> $VARS_FILE
echo "HEALTH_$NAME=\"$HEALTH\"" >> $VARS_FILE
echo "RESTARTING_$NAME=\"$RESTARTING\"" >> $VARS_FILE
echo "STARTED_AT_$NAME=\"$STARTED_AT\"" >> $VARS_FILE
echo "FINISHED_AT_$NAME=\"$FINISHED_AT\"" >> $VARS_FILE
echo "EXISTS_$NAME=\"$EXISTS\"" >> $VARS_FILE
echo "BRANCH_$NAME=\"$BRANCH\"" >> $VARS_FILE
echo "REPO_$NAME=\"$REPO\"">> $VARS_FILE
echo "HOSTNAME_$NAME=\"$HOSTNAME\"" >> $VARS_FILE
echo "PORTS_$NAME=\"$PORTS\"" >> $VARS_FILE

if [ ! -z "${NETWORK_SETTINGS,,}" ] && [ ! -z "$NETWORKS" ]; then # container exists
    echo "INFO: Network settings of the $NAME container were found, duming data..."
    i=-1
    for net in $NETWORKS; do
        i=$((i + 1))
        IP_TMP=$(echo "$NETWORK_SETTINGS" 2> /dev/null | jq -r ".$net.IPAddress" 2> /dev/null || echo "")
        if [ ! -z "$IP_TMP" ] && [ "${IP_TMP,,}" != "null" ]; then
            echo "IP_${NAME}_$net=\"$IP_TMP\"" >> $VARS_FILE
        else
            echo "IP_${NAME}_$net=\"\"" >> $VARS_FILE
        fi
    done
else
    echo "INFO: Network settings of the $NAME container were NOT found"
fi


echo "INFO: Stopped '$1' container status scan"