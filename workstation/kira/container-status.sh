#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/container-status.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

echo "INFO: Started '$1' container status scan"

set -x

NAME=$1
VARS_FILE=$2
NETWORKS=$3

ID=$($KIRA_SCRIPTS/container-id.sh "$NAME")
if [ -z "$ID" ] ; then
    EXISTS="false"
else
    EXISTS="true"
fi

# define global variables
if [ "${NAME,,}" == "interx" ]; then
    BRANCH="$INTERX_BRANCH"
    REPO="$INTERX_REPO"
elif [ "${NAME,,}" == "sentry" ] || [ "${NAME,,}" == "priv_sentry" ] || [ "${NAME,,}" == "snapshoot" ] ; then
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
    DOCKER_INSPECT=$(docker inspect $ID || echo "")
    STATUS=$(echo "$DOCKER_INSPECT" | jq -r '.[0].State.Status' 2> /dev/null || echo "")
    PAUSED=$(echo "$DOCKER_INSPECT" | jq -r '.[0].State.Paused'  2> /dev/null || echo "")
    HEALTH=$(echo "$DOCKER_INSPECT" | jq -r '.[0].State.Health.Status'  2> /dev/null || echo "")
    RESTARTING=$(echo "$DOCKER_INSPECT" | jq -r '.[0].State.Restarting'  2> /dev/null || echo "")
    STARTED_AT=$(echo "$DOCKER_INSPECT" | jq -r '.[0].State.StartedAt'  2> /dev/null || echo "")
    FINISHED_AT=$(echo "$DOCKER_INSPECT" | jq -r '.[0].State.FinishedAt'  2> /dev/null || echo "")
    HOSTNAME=$(echo "$DOCKER_INSPECT" | jq -r '.[0].Config.Hostname'  2> /dev/null || echo "")
    EXPOSED_PORTS=$(echo "$DOCKER_INSPECT" | jq -r '.[0].Config.ExposedPorts' 2> /dev/null | jq 'keys'  2> /dev/null | jq -r '.[]' 2> /dev/null | tr '\n' ','  2> /dev/null | tr -d '"' 2> /dev/null | tr -d '/tcp'  2> /dev/null | sed 's/,$//g' 2> /dev/null || echo "")
    PORTS=$(docker ps --format "{{.Ports}}" -aqf "id=$ID" 2> /dev/null || echo "")
    NETWORK_SETTINGS=$(echo "$DOCKER_INSPECT" 2> /dev/null | jq -r ".[0].NetworkSettings.Networks" 2> /dev/null || echo "")

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
else # container does NOT exists
    ID=""
    STATUS="stopped"
    PAUSED="false"
    HEALTH="undefined"
    RESTARTING="false"
    STARTED_AT="0"
    FINISHED_AT="0"
    NETWORK="undefined"
    HOSTNAME="undefined"
    LIP="undefined"
    PORTS=""
    NETWORK_SETTINGS=""
fi

if [ ! -z "$VARS_FILE" ]; then # save status variables to file if output was specified
    echo "INFO: Output file was specified, dumpiung data into '$VARS_FILE'"
    VARS_FILE_TMP="${VARS_FILE}.tmp"
    rm -fv $VARS_FILE_TMP && touch $VARS_FILE_TMP

    echo "ID_$NAME=\"$ID\"" > $VARS_FILE_TMP
    echo "STATUS_$NAME=\"$STATUS\"" >> $VARS_FILE_TMP
    echo "PAUSED_$NAME=\"$PAUSED\"" >> $VARS_FILE_TMP
    echo "HEALTH_$NAME=\"$HEALTH\"" >> $VARS_FILE_TMP
    echo "RESTARTING_$NAME=\"$RESTARTING\"" >> $VARS_FILE_TMP
    echo "STARTED_AT_$NAME=\"$STARTED_AT\"" >> $VARS_FILE_TMP
    echo "FINISHED_AT_$NAME=\"$FINISHED_AT\"" >> $VARS_FILE_TMP
    echo "EXISTS_$NAME=\"$EXISTS\"" >> $VARS_FILE_TMP
    echo "BRANCH_$NAME=\"$BRANCH\"" >> $VARS_FILE_TMP
    echo "REPO_$NAME=\"$REPO\"">> $VARS_FILE_TMP
    echo "HOSTNAME_$NAME=\"$HOSTNAME\"" >> $VARS_FILE_TMP
    echo "PORTS_$NAME=\"$PORTS\"" >> $VARS_FILE_TMP

    if [ ! -z "${NETWORK_SETTINGS,,}" ] && [ ! -z "$NETWORKS" ]; then # container exists
        echo "INFO: Network settings of the $NAME container were found, duming data..."
        i=-1
        for net in $NETWORKS; do
            i=$((i + 1))
            IP_TMP=$(echo "$NETWORK_SETTINGS" 2> /dev/null | jq -r ".$net.IPAddress" 2> /dev/null || echo "")
            if [ ! -z "$IP_TMP" ] && [ "${IP_TMP,,}" != "null" ]; then
                echo "IP_${NAME}_$net=\"$IP_TMP\"" >> $VARS_FILE_TMP
            else
                echo "IP_${NAME}_$net=\"\"" >> $VARS_FILE_TMP
            fi
        done
    else
        echo "INFO: Network settings of the $NAME container were NOT found"
    fi

    cp -f -a -v $VARS_FILE_TMP $VARS_FILE
fi

echo "INFO: Stopped '$1' container status scan"