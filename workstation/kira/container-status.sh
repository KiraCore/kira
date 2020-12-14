#!/bin/bash

set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_WORKSTATION/kira/container-status.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NAME=$1
VARS_FILE=$2
NETWORKS=$3

ID=$(docker inspect --format="{{.Id}}" ${NAME} 2> /dev/null || echo "undefined")
if [ $ID != "undefined" ] && [ ! -z $ID ]; then 
    EXISTS="true" 
else 
    EXISTS="false" 
fi

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
    [ -z "$NETWORKS" ] && NETWORKS=$(docker network ls --format="{{.Name}}" || "")
    DOCKER_INSPECT=$(docker inspect $ID || echo "")
    STATUS=$(echo "$DOCKER_INSPECT" | jq -r '.[0].State.Status' || echo "Error")
    PAUSED=$(echo "$DOCKER_INSPECT" | jq -r '.[0].State.Paused' || echo "Error")
    HEALTH=$(echo "$DOCKER_INSPECT" | jq -r '.[0].State.Health.Status' || echo "Error")
    RESTARTING=$(echo "$DOCKER_INSPECT" | jq -r '.[0].State.Restarting' || echo "Error")
    STARTED_AT=$(echo "$DOCKER_INSPECT" | jq -r '.[0].State.StartedAt' || echo "Error")
    FINISHED_AT=$(echo "$DOCKER_INSPECT" | jq -r '.[0].State.FinishedAt' || echo "Error")

    i=-1 ; for net in $NETWORKS ; do i=$((i+1))
        IP_TMP=$(echo "$DOCKER_INSPECT" | jq -r ".[0].NetworkSettings.Networks.$net.IPAddress" || echo "")
        if [ ! -z "$IP_TMP" ] && [ "${IP_TMP,,}" != "null" ] ; then
            eval "IP_$net=$IP_TMP"
        else
            eval "IP_$net=\"\""
        fi
    done 

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
    FINISHED_AT="0"
    NETWORK="undefined"
fi

if [ ! -z "$VARS_FILE" ] ; then # save status variables to file if output was specified
    echo "ID_$NAME=\"$ID\"" >> $VARS_FILE
    echo "STATUS_$NAME=\"$STATUS\"" >> $VARS_FILE
    echo "PAUSED_$NAME=\"$PAUSED\"" >> $VARS_FILE
    echo "HEALTH_$NAME=\"$HEALTH\"" >> $VARS_FILE
    echo "RESTARTING_$NAME=\"$RESTARTING\"" >> $VARS_FILE
    echo "STARTED_AT_$NAME=\"$STARTED_AT\"" >> $VARS_FILE
    echo "FINISHED_AT_$NAME=\"$FINISHED_AT\"" >> $VARS_FILE
    echo "EXISTS_$NAME=\"$EXISTS\"" >> $VARS_FILE
    echo "BRANCH_$NAME=\"$BRANCH\"" >> $VARS_FILE
    echo "REPO_$NAME=\"$REPO\"" >> $VARS_FILE

    if [ "${EXISTS,,}" == "true" ] && [ ! -z "$NETWORKS" ] ; then # container exists
        echo "NETWORKS=\"$NETWORKS\"" >> $VARS_FILE
        i=-1 ; for net in $NETWORKS ; do i=$((i+1))
            IP_TMP=$(echo "$DOCKER_INSPECT" | jq -r ".[0].NetworkSettings.Networks.$net.IPAddress" || echo "")
            if [ ! -z "$IP_TMP" ] && [ "${IP_TMP,,}" != "null" ] ; then
                echo "IP_${NAME}_$net=\"$IP_TMP\"" >> $VARS_FILE
            else
                echo "IP_${NAME}_$net=\"\"" >> $VARS_FILE
            fi
        done
    fi
fi

# Example of variable recovery:
# source $VARS_FILE
# ID="ID_$NAME" && ID="${!ID}"