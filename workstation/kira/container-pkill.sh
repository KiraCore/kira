#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e && set -x
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/container-pkill.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NAME=$1
AWAIT=$2
TASK=$3
UNHALT=$4
COMMON_PATH="$DOCKER_COMMON/$NAME"
HALT_FILE="$COMMON_PATH/halt"
EXIT_FILE="$COMMON_PATH/exit"

timerStart

[ -z "$NAME" ] && echoErr "ERROR: Missing 'NAME' parameter (1)" && exit 1

if [ "${NAME,,}" == "interx" ]; then
    PROCESS="interxd"
    CODE="9"
elif [ "${NAME,,}" == "frontend" ]; then
    PROCESS="nginx"
    CODE="9"
elif [[ "${NAME,,}" =~ ^(validator|sentry|priv_sentry|snapshot|seed)$ ]] ; then
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
[ "${AWAIT,,}" == "true" ] && \
echoWarn "|      HALT FILE: $HALT_FILE" && \
echoWarn "|      EXIT FILE: $EXIT_FILE"
echoWarn "|-------------------------------------------------"
set -x

mkdir -p "$COMMON_PATH"
if [ ! -z "$NAME" ] && [ ! -z "$PROCESS" ] && ( [ "${TASK,,}" == "restart" ] || [ "${TASK,,}" == "stop" ] ) ; then
    touch $EXIT_FILE
    echoInfo "INFO: Sending pkill command to container..."
    docker exec -i $NAME /bin/bash -c "pkill -$CODE $PROCESS || echo 'WARNING: Failed to pkill $PROCESS ($CODE)'" || echoWarn "WARNING: Failed to pkill $PROCESS ($CODE)"
    
    RUNNING=$($KIRA_SCRIPTS/container-running.sh $NAME)
    if [ "${AWAIT,,}" == "true" ] && [ "${RUNNING,,}" == "true" ] ; then
        cntr=0
        while [ -f "$EXIT_FILE" ] && [[ $cntr -lt 30 ]] ; do
            cntr=$(($cntr + 1))
            echoInfo "INFO: Waiting for container '$NAME' to halt ($cntr/20) ..."
            sleep 5
            RUNNING=$($KIRA_SCRIPTS/container-running.sh $NAME)
            [ "${RUNNING,,}" == "false" ] && break
        done
        [ ! -f "$EXIT_FILE" ] && echoInfo "INFO: Container '$NAME' stopped sucessfully" || echoWarn "WARNING: Failed to gracefully stop container '$NAME'"
    fi
else
    echoWarn "WARNING: pkill signall was NOT sent to $NAME container "
fi

if [ "${TASK,,}" == "pause" ] ; then
    $KIRA_SCRIPTS/container-pause.sh $NAME || echoWarn "WARNING: Failed to $TASK contianer $NAME"
    [ "${UNHALT,,}" == "true" ] && rm -fv "$HALT_FILE" "$EXIT_FILE" && echoInfo "INFO: Container $NAME unhalted"
elif [ "${TASK,,}" == "unpause" ] ; then
    [ "${UNHALT,,}" == "true" ] && rm -fv "$HALT_FILE" "$EXIT_FILE" && echoInfo "INFO: Container $NAME unhalted"
    $KIRA_SCRIPTS/container-unpause.sh $NAME || echoWarn "WARNING: Failed to $TASK contianer $NAME"
elif [ "${TASK,,}" == "start" ] ; then
    [ "${UNHALT,,}" == "true" ] && rm -fv "$HALT_FILE" "$EXIT_FILE" && echoInfo "INFO: Container $NAME unhalted"
    $KIRA_SCRIPTS/container-start.sh $NAME || echoWarn "WARNING: Failed to $TASK contianer $NAME"
elif [ "${TASK,,}" == "stop" ] ; then
    $KIRA_SCRIPTS/container-stop.sh $NAME || echoWarn "WARNING: Failed to $TASK contianer $NAME"
    [ "${UNHALT,,}" == "true" ] && rm -fv "$HALT_FILE" "$EXIT_FILE" && echoInfo "INFO: Container $NAME unhalted"
elif [ "${TASK,,}" == "restart" ] ; then
    $KIRA_SCRIPTS/container-restart.sh $NAME || echoWarn "WARNING: Failed to $TASK contianer $NAME"
    [ "${UNHALT,,}" == "true" ] && rm -fv "$HALT_FILE" "$EXIT_FILE" && echoInfo "INFO: Container $NAME unhalted"
else
    echoInfo "INFO: No container execution tasks were requested"
    [ "${UNHALT,,}" == "true" ] && rm -fv "$HALT_FILE" "$EXIT_FILE" && echoInfo "INFO: Container $NAME unhalted"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINER PROCESS TERMINATOR"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x
