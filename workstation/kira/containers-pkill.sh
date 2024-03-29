#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e && set -x
# quick edit: FILE="$KIRA_MANAGER/kira/containers-pkill.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# e.g. $KIRA_MANAGER/kira/containers-pkill.sh "true" "pause"

AWAIT=$1
TASK=$2
UNHALT=$3

timerStart

[ -z "$AWAIT" ] && AWAIT="false"
[ -z "$UNHALT" ] && UNHALT="true"

if ($(isCommand "docker")) ; then
    CONTAINERS=$(docker ps -a | awk '{if(NR>1) print $NF}' | tac || echo -n "")
else
    echoErr "ERROR: Docker command not found!"
    CONTAINERS=""
fi

set +x
echoWarn "--------------------------------------------------"
echoWarn "|   STARTING: KIRA MULTI-CONTAINER TERMINATOR $KIRA_SETUP_VER"
echoWarn "|-------------------------------------------------"
echoWarn "| CONTAINERS: $CONTAINERS"
echoWarn "| AWAIT EXIT: $AWAIT"
echoWarn "|       TASK: $TASK"
echoWarn "|     UNHALT: $UNHALT"
echoWarn "--------------------------------------------------"
set -x

if [ ! -z "$CONTAINERS" ] ; then
    for NAME in $CONTAINERS; do
        echoInfo "INFO: Attempting to pkill container $NAME"
        $KIRA_MANAGER/kira/container-pkill.sh --name="$NAME" --await="$AWAIT" --task="$TASK" --unhalt="$UNHALT"
    done
else
    echoWarn "WARNING: NO containers found"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: KIRA MULTI-CONTAINER TERMINATOR"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x
