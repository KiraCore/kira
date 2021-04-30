#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e && set -x
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/containers-pkill.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# e.g. $KIRA_MANAGER/kira/containers-pkill.sh "true" "pause"

SCRIPT_START_TIME="$(date -u +%s)"

AWAIT=$1
TASK=$2
UNHALT=$3

[ -z "$AWAIT" ] && AWAIT="false"
[ -z "$UNHALT" ] && UNHALT="true"

if command -v docker ; then
    CONTAINERS=$(docker ps -a | awk '{if(NR>1) print $NF}' | tac || echo -n "")
else
    echoErr "ERROR: Docker command not found!"
    CONTAINERS=""
fi

set +x
echoWarn "--------------------------------------------------"
echoWarn "| STARTING KIRA MULTI-CONTAINER TERMINATOR $KIRA_SETUP_VER"
echoWarn "|-------------------------------------------------"
echoWarn "|     CONTAINERS: $CONTAINERS"
echoWarn "|     AWAIT EXIT: $AWAIT"
echoWarn "|           TASK: $TASK"
echoWarn "|         UNHALT: $UNHALT"
echoWarn "|-------------------------------------------------"
set -x

if [ ! -z "$CONTAINERS" ] ; then
    for NAME in $CONTAINERS; do
        echoInfo "INFO: Attempting to pkill container $NAME"
        $KIRA_MANAGER/kira/container-pkill.sh "$NAME" "true" "$TASK" "$UNHALT"
    done
else
    echoWarn "WARNING: NO containers found"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: KIRA MULTI-CONTAINER TERMINATOR"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x
