#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e && set -x
# quick edit: FILE="$KIRA_MANAGER/kira/container-pkill.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NAME=$1
AWAIT=$2
TASK=$3
UNHALT=$4
COMMON_PATH="$DOCKER_COMMON/$NAME"
GLOBAL_COMMON="$COMMON_PATH/kiraglob"

timerStart

[ -z "$NAME" ] && echoErr "ERROR: Missing 'NAME' parameter (1)" && exit 1

if [ "${NAME,,}" == "interx" ]; then
    PROCESS="interx"
    CODE="9"
elif [[ "${NAME,,}" =~ ^(validator|sentry|seed)$ ]] ; then
    PROCESS="sekaid"
    CODE="15"
else
    PROCESS=""
    CODE=""
fi

[ -z "$AWAIT" ] && AWAIT="false"
[ -z "$UNHALT" ] && UNHALT="true"

set +x
echoWarn "--------------------------------------------------"
echoWarn "| STARTING KIRA PROCESS TERMINATOR $KIRA_SETUP_VER"
echoWarn "|-------------------------------------------------"
echoWarn "| CONTAINER NAME: $NAME"
echoWarn "|     AWAIT EXIT: $AWAIT"
echoWarn "|        PROCESS: $PROCESS"
echoWarn "|           CODE: $CODE"
echoWarn "|           TASK: $TASK"
echoWarn "|         UNHALT: $UNHALT"
echoWarn "|   HALT(ING/ED): $(globGet HALT_TASK $GLOBAL_COMMON)"
echoWarn "|   EXIT(ING/ED): $(globGet EXIT_TASK $GLOBAL_COMMON)"
echoWarn "|-------------------------------------------------"
set -x

mkdir -p "$COMMON_PATH"
if [ ! -z "$NAME" ] && [ ! -z "$PROCESS" ] && ( [ "${TASK,,}" == "restart" ] || [ "${TASK,,}" == "stop" ] ) ; then
    globSet EXIT_TASK "true" $GLOBAL_COMMON
    echoInfo "INFO: Sending pkill command to container..."
    docker exec -i $NAME /bin/bash -c "pkill -$CODE $PROCESS || echo 'WARNING: Failed to pkill $PROCESS ($CODE)'" || echoWarn "WARNING: Failed to pkill $PROCESS ($CODE)"
    
    RUNNING=$($KIRA_SCRIPTS/container-running.sh $NAME)
    if [ "${AWAIT,,}" == "true" ] && [ "${RUNNING,,}" == "true" ] ; then
        cntr=0
        while [ "$(globGet EXIT_TASK $GLOBAL_COMMON)" == "true" ] && [[ $cntr -lt 30 ]] ; do
            cntr=$(($cntr + 1))
            echoInfo "INFO: Waiting for container '$NAME' to halt ($cntr/30) ..."
            sleep 5
            RUNNING=$($KIRA_SCRIPTS/container-running.sh $NAME)
            [ "${RUNNING,,}" == "false" ] && break
        done
        [ "$(globGet EXIT_TASK $GLOBAL_COMMON)" == "false" ] && echoInfo "INFO: Container '$NAME' stopped sucessfully" || echoWarn "WARNING: Failed to gracefully stop container '$NAME'"
    fi
else
    echoWarn "WARNING: pkill signall was NOT sent to $NAME container "
fi

if [ "${TASK,,}" == "unpause" ] && [ "${UNHALT,,}" == "true" ]  ; then
    globSet HALT_TASK "false" $GLOBAL_COMMON
    globSet EXIT_TASK "false" $GLOBAL_COMMON
    echoInfo "INFO: Container $NAME unhalted"
fi

if [ "${TASK,,}" == "pause" ] ; then
    $KIRA_SCRIPTS/container-pause.sh $NAME || echoWarn "WARNING: Failed to $TASK contianer $NAME"
elif [ "${TASK,,}" == "unpause" ] ; then
    $KIRA_SCRIPTS/container-unpause.sh $NAME || echoWarn "WARNING: Failed to $TASK contianer $NAME"
elif [ "${TASK,,}" == "start" ] ; then
    $KIRA_SCRIPTS/container-start.sh $NAME || echoWarn "WARNING: Failed to $TASK contianer $NAME"
elif [ "${TASK,,}" == "stop" ] ; then
    $KIRA_SCRIPTS/container-stop.sh $NAME || echoWarn "WARNING: Failed to $TASK contianer $NAME"
elif [ "${TASK,,}" == "restart" ] ; then
    $KIRA_SCRIPTS/container-restart.sh $NAME || echoWarn "WARNING: Failed to $TASK contianer $NAME"
else
    echoInfo "INFO: No container execution tasks were requested"
fi

if [ "${TASK,,}" != "unpause" ] && [ "${UNHALT,,}" == "true" ] ; then
    globSet HALT_TASK "false" $GLOBAL_COMMON
    globSet EXIT_TASK "false" $GLOBAL_COMMON
    echoInfo "INFO: Container $NAME unhalted"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINER PROCESS TERMINATOR"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x
