#!/bin/bash

set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/container-status.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NAME=$1
VARS_FILE=$2
NETWORKS=$3

ID=$(echo $(docker inspect --format="{{.Id}}" ${NAME} 2> /dev/null | xargs 2> /dev/null || echo "null"))
if [ "${ID,,}" != "null" ] && [ ! -z $ID ] ; then
    EXISTS="true"
else
    EXISTS="false"
fi

# define global variables
if [ "${NAME,,}" == "interx" ]; then
    BRANCH="$INTERX_BRANCH"
    REPO="$INTERX_REPO"
elif [ "${NAME,,}" == "sentry" ]; then
    BRANCH="$SEKAI_BRANCH"
    REPO="$SEKAI_REPO"
elif [ "${NAME,,}" == "validator" ]; then
    BRANCH="$SEKAI_BRANCH"
    REPO="$SEKAI_REPO"
elif [ "${NAME,,}" == "registry" ]; then
    BRANCH=""
    REPO=""
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
    EXPOSED_PORTS=$(echo "$DOCKER_INSPECT" | jq -r '.[0].Config.ExposedPorts' 2> /dev/null | jq 'keys'  2> /dev/null | jq -c '.[]' 2> /dev/null | tr '\n' ','  2> /dev/null | tr -d '"' 2> /dev/null | tr -d '/tcp'  2> /dev/null | sed 's/,$//g' 2> /dev/null || echo "")
    PORTS=$(docker ps --format "{{.Ports}}" -aqf "name=$NAME" 2> /dev/null || echo "")

    i=-1
    for net in $NETWORKS; do
        i=$((i + 1))
        IP_TMP=$(echo "$DOCKER_INSPECT" | jq -r ".[0].NetworkSettings.Networks.$net.IPAddress" || echo "")
        if [ ! -z "$IP_TMP" ] && [ "${IP_TMP,,}" != "null" ]; then
            eval "IP_$net=$IP_TMP"
        else
            eval "IP_$net=\"\""
        fi
    done

    if [ "${NAME,,}" == "interx" ]; then
        sleep 0 # custom handle interx
    elif [ "${NAME,,}" == "sentry" ]; then
        sleep 0 # custom handle sentry
    elif [ "${NAME,,}" == "validator" ]; then
        sleep 0 # custom handle validator
    elif [ "${NAME,,}" == "registry" ]; then
        sleep 0 # custom handle registry
    fi
else # container does NOT exists
    ID="undefined"
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
fi

if [ ! -z "$VARS_FILE" ]; then # save status variables to file if output was specified
    CDHelper text lineswap --insert="ID_$NAME=\"$ID\"" --prefix="ID_$NAME=" --path=$VARS_FILE --append-if-found-not=True > /dev/null
    CDHelper text lineswap --insert="STATUS_$NAME=\"$STATUS\"" --prefix="STATUS_$NAME=" --path=$VARS_FILE --append-if-found-not=True > /dev/null
    CDHelper text lineswap --insert="PAUSED_$NAME=\"$PAUSED\"" --prefix="PAUSED_$NAME=" --path=$VARS_FILE --append-if-found-not=True > /dev/null
    CDHelper text lineswap --insert="HEALTH_$NAME=\"$HEALTH\"" --prefix="HEALTH_$NAME=" --path=$VARS_FILE --append-if-found-not=True > /dev/null
    CDHelper text lineswap --insert="RESTARTING_$NAME=\"$RESTARTING\"" --prefix="RESTARTING_$NAME=" --path=$VARS_FILE --append-if-found-not=True > /dev/null
    CDHelper text lineswap --insert="STARTED_AT_$NAME=\"$STARTED_AT\"" --prefix="STARTED_AT_$NAME=" --path=$VARS_FILE --append-if-found-not=True > /dev/null
    CDHelper text lineswap --insert="FINISHED_AT_$NAME=\"$FINISHED_AT\"" --prefix="FINISHED_AT_$NAME=" --path=$VARS_FILE --append-if-found-not=True > /dev/null
    CDHelper text lineswap --insert="EXISTS_$NAME=\"$EXISTS\"" --prefix="EXISTS_$NAME=" --path=$VARS_FILE --append-if-found-not=True > /dev/null
    CDHelper text lineswap --insert="BRANCH_$NAME=\"$BRANCH\"" --prefix="BRANCH_$NAME=" --path=$VARS_FILE --append-if-found-not=True > /dev/null
    CDHelper text lineswap --insert="REPO_$NAME=\"$REPO\"" --prefix="REPO_$NAME=" --path=$VARS_FILE --append-if-found-not=True > /dev/null
    CDHelper text lineswap --insert="HOSTNAME_$NAME=\"$HOSTNAME\"" --prefix="HOSTNAME_$NAME=" --path=$VARS_FILE --append-if-found-not=True > /dev/null
    CDHelper text lineswap --insert="PORTS_$NAME=\"$PORTS\"" --prefix="PORTS_$NAME=" --path=$VARS_FILE --append-if-found-not=True > /dev/null

    if [ "${EXISTS,,}" == "true" ] && [ ! -z "$NETWORKS" ]; then # container exists
        i=-1
        for net in $NETWORKS; do
            i=$((i + 1))
            IP_TMP=$(echo "$DOCKER_INSPECT" | jq -r ".[0].NetworkSettings.Networks.$net.IPAddress" || echo "")
            if [ ! -z "$IP_TMP" ] && [ "${IP_TMP,,}" != "null" ]; then
                CDHelper text lineswap --insert="IP_${NAME}_$net=\"$IP_TMP\"" --prefix="IP_${NAME}_$net=" --path=$VARS_FILE --append-if-found-not=True > /dev/null
            else
                CDHelper text lineswap --insert="IP_${NAME}_$net=\"\"" --prefix="IP_${NAME}_$net=" --path=$VARS_FILE --append-if-found-not=True > /dev/null
            fi
        done
    fi

    CDHelper text lineswap --regex="^[^\"]*\"[^\"]*$" --insert="" --path=$VARS_FILE > /dev/null || :
fi
