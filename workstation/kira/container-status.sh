#!/bin/bash

set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_WORKSTATION/kira/container-status.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NAME=$1
VARS_FILE=$2
EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$NAME" || echo "Error")

# define global variables
if [ "${NAME,,}" == "interx" ] ; then
    BRANCH="$INTERX_BRANCH"
    REPO="$INTERX_REPO"
elif [ "${NAME,,}" == "sentry" ] ; then
    BRANCH="$SEKAI_BRANCH"
    REPO="$SEKAI_REPO"
elif [ "${NAME,,}" == "kms" ] ; then
    BRANCH="$KMS_BRANCH"
    REPO="$KMS_REPO"
elif [ "${NAME,,}" == "validator" ] ; then
    BRANCH="$SEKAI_BRANCH"
    REPO="$SEKAI_REPO"
elif [ "${NAME,,}" == "registry" ] ; then
    BRANCH=""
    REPO=""
fi

if [ "${EXISTS,,}" == "true" ] ; then # container exists
    # (docker ps --no-trunc -aqf name=$NAME) 
    ID=$(docker inspect --format="{{.Id}}" ${NAME} 2> /dev/null || echo "undefined")
    STATUS=$(docker inspect $ID | jq -r '.[0].State.Status' || echo "Error")
    PAUSED=$(docker inspect $ID | jq -r '.[0].State.Paused' || echo "Error")
    HEALTH=$(docker inspect $ID | jq -r '.[0].State.Health.Status' || echo "Error")
    RESTARTING=$(docker inspect $ID | jq -r '.[0].State.Restarting' || echo "Error")
    STARTED_AT=$(docker inspect $ID | jq -r '.[0].State.StartedAt' || echo "Error")
    IP=$(docker inspect $ID | jq -r '.[0].NetworkSettings.Networks.kiranet.IPAMConfig.IPv4Address' || echo "")
    if [ -z "$IP" ] || [ "$IP" == "null" ] ; then IP=$(docker inspect $ID | jq -r '.[0].NetworkSettings.Networks.regnet.IPAMConfig.IPv4Address' || echo "") ; fi

    if [ "${NAME,,}" == "interx" ] ; then
        sleep 0 # custom handle interx
    elif [ "${NAME,,}" == "sentry" ] ; then
        sleep 0 # custom handle sentry
    elif [ "${NAME,,}" == "kms" ] ; then
        sleep 0 # custom handle kms
    elif [ "${NAME,,}" == "validator" ] ; then
        sleep 0 # custom handle validator
    elif [ "${NAME,,}" == "registry" ] ; then
        sleep 0 # custom handle registry
    fi
else # container does NOT exists
    ID="undefined"
    STATUS="stopped"
    PAUSED="false"
    HEALTH="undefined"
    RESTARTING="false"
    STARTED_AT="0"
    IP="undefined"
fi

if [ ! -z "$VARS_FILE" ] ; then # save status variables to file if output was specified
    echo "ID_$NAME=$ID" > $VARS_FILE
    echo "STATUS_$NAME=$STATUS" >> $VARS_FILE
    echo "PAUSED_$NAME=$PAUSED" >> $VARS_FILE
    echo "HEALTH_$NAME=$HEALTH" >> $VARS_FILE
    echo "RESTARTING_$NAME=$RESTARTING" >> $VARS_FILE
    echo "STARTED_AT_$NAME=$STARTED_AT" >> $VARS_FILE
    echo "IP_$NAME=$IP" >> $VARS_FILE
    echo "EXISTS_$NAME=$EXISTS" >> $VARS_FILE
fi

# Example of variable recovery:
# source $VARS_FILE
# ID="ID_$NAME" && ID="${!ID}"