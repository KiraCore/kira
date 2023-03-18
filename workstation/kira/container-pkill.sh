#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e && set -x
# quick edit: FILE="$KIRA_MANAGER/kira/container-pkill.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# e.g: $KIRA_MANAGER/kira/container-pkill.sh --name="" --await="" --task="" --unhalt="" 
getArgs "$1" "$2" "$3" "$4"
COMMON_PATH="$DOCKER_COMMON/$name"
GLOBAL_COMMON="$COMMON_PATH/kiraglob"

timerStart

($(isNullOrWhitespaces "$name")) && echoErr "ERROR: Missing 'name' parameter (1)" && exit 1
($(isNullOrWhitespaces "$task")) && task=""
(! $(isBoolean "$await")) && await="false"
(! $(isBoolean "$unhalt")) && unhalt="false"

if [ "$name" == "interx" ]; then
    PROCESS="interx"
    CODE="9"
elif [[ "$name" =~ ^(validator|sentry|seed)$ ]] ; then
    PROCESS="sekaid"
    CODE="15"
else
    PROCESS=""
    CODE=""
fi

set +x
echoWarn "--------------------------------------------------"
echoWarn "| STARTING KIRA PROCESS TERMINATOR $KIRA_SETUP_VER"
echoWarn "|-------------------------------------------------"
echoWarn "| CONTAINER NAME: $name"
echoWarn "|     AWAIT EXIT: $await"
echoWarn "|        PROCESS: $PROCESS"
echoWarn "|           CODE: $CODE"
echoWarn "|           TASK: $task"
echoWarn "|         UNHALT: $unhalt"
echoWarn "|   HALT(ING/ED): $(globGet HALT_TASK $GLOBAL_COMMON)"
echoWarn "|   EXIT(ING/ED): $(globGet EXIT_TASK $GLOBAL_COMMON)"
echoWarn "|-------------------------------------------------"
set -x

mkdir -p "$COMMON_PATH"
if [ ! -z "$name" ] && [ ! -z "$PROCESS" ] && ( [ "$task" == "restart" ] || [ "$task" == "stop" ] ) ; then
    globSet EXIT_TASK "true" $GLOBAL_COMMON
    echoInfo "INFO: Sending pkill command to container..."
    docker exec -i $name /bin/bash -c "pkill -$CODE $PROCESS || echo 'WARNING: Failed to pkill $PROCESS ($CODE)'" || echoWarn "WARNING: Failed to pkill $PROCESS ($CODE)"
    
    RUNNING=$($KIRA_COMMON/container-running.sh $name)
    if [ "$await" == "true" ] && [ "$RUNNING" == "true" ] ; then
        cntr=0
        while [ "$(globGet EXIT_TASK $GLOBAL_COMMON)" == "true" ] && [[ $cntr -lt 30 ]] ; do
            cntr=$(($cntr + 1))
            echoInfo "INFO: Waiting for container '$name' to halt ($cntr/30) ..."
            sleep 5
            RUNNING=$($KIRA_COMMON/container-running.sh $name)
            [ "${RUNNING}" == "false" ] && break
        done
        [ "$(globGet EXIT_TASK $GLOBAL_COMMON)" == "false" ] && echoInfo "INFO: Container '$name' stopped sucessfully" || echoWarn "WARNING: Failed to gracefully stop container '$name'"
    fi
else
    echoWarn "WARNING: pkill signall was NOT sent to $name container "
fi

if [ "$task" == "unpause" ] && [ "$unhalt" == "true" ]  ; then
    globSet HALT_TASK "false" $GLOBAL_COMMON
    globSet EXIT_TASK "false" $GLOBAL_COMMON
    echoInfo "INFO: Container $name unhalted"
fi

if [ "$task" == "pause" ] ; then
    $KIRA_COMMON/container-pause.sh $name || echoWarn "WARNING: Failed to $task contianer $name"
elif [ "$task" == "unpause" ] ; then
    $KIRA_COMMON/container-unpause.sh $name || echoWarn "WARNING: Failed to $task contianer $name"
elif [ "$task" == "start" ] ; then
    $KIRA_COMMON/container-start.sh $name || echoWarn "WARNING: Failed to $task contianer $name"
elif [ "$task" == "stop" ] ; then
    $KIRA_COMMON/container-stop.sh $name || echoWarn "WARNING: Failed to $task contianer $name"
elif [ "$task" == "restart" ] ; then
    $KIRA_COMMON/container-restart.sh $name || echoWarn "WARNING: Failed to $task contianer $name"
else
    echoInfo "INFO: No container execution tasks were requested"
fi

if [ "$task" != "unpause" ] && [ "$unhalt" == "true" ] ; then
    globSet HALT_TASK "false" $GLOBAL_COMMON
    globSet EXIT_TASK "false" $GLOBAL_COMMON
    echoInfo "INFO: Container $name unhalted"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINER PROCESS TERMINATOR"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x
