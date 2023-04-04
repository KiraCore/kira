#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e && set -x
# quick edit: FILE="$KIRA_MANAGER/kira/container-pkill.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# e.g: $KIRA_MANAGER/kira/container-pkill.sh --name="" --await="" --task="" --unhalt="" 
getArgs "$1" "$2" "$3" "$4"
COMMON_PATH="$DOCKER_COMMON/$name"
GLOBAL_COMMON="$COMMON_PATH/kiraglob"

timerStart "container-pkill"

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

set +x && echo ""
echoC ";whi"  "================================================================================"
echoC ";whi"  "|            STARTED:$(strFixL " KIRA PROCESS TERMINATOR $KIRA_SETUP_VER" 58)|"   
echoC ";whi"  "================================================================================"
echoC ";whi"  "|     CONTAINER NAME:$(strFixL " $name " 58)|"
echoC ";whi"  "|         AWAIT EXIT:$(strFixL " $await " 58)|"
echoC ";whi"  "|            PROCESS:$(strFixL " $PROCESS " 58)|"
echoC ";whi"  "|               CODE:$(strFixL " $CODE " 58)|"
echoC ";whi"  "|               TASK:$(strFixL " $task " 58)|"
echoC ";whi"  "|             UNHALT:$(strFixL " $unhalt " 58)|"
echoC ";whi"  "|       HALT(ING/ED):$(strFixL " $(globGet HALT_TASK $GLOBAL_COMMON) " 58)|"
echoC ";whi"  "|       EXIT(ING/ED):$(strFixL " $(globGet EXIT_TASK $GLOBAL_COMMON) " 58)|"
echoC ";whi"  "================================================================================"
echo "" && set -x

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

case $task in
    "pause")    $KIRA_COMMON/container-pause.sh $name   || echoWarn "WARNING: Failed to $task contianer $name" ;;
    "unpause")  $KIRA_COMMON/container-unpause.sh $name || echoWarn "WARNING: Failed to $task contianer $name" ;;
    "start")    $KIRA_COMMON/container-start.sh $name   || echoWarn "WARNING: Failed to $task contianer $name" ;;
    "stop")     $KIRA_COMMON/container-stop.sh $name    || echoWarn "WARNING: Failed to $task contianer $name" ;;
    "restart")  $KIRA_COMMON/container-restart.sh $name || echoWarn "WARNING: Failed to $task contianer $name" ;;
            *)  echoInfo "INFO: No container execution tasks were requested"                                   ;;
esac

if [ "$task" != "unpause" ] && [ "$unhalt" == "true" ] ; then
    globSet HALT_TASK "false" $GLOBAL_COMMON
    globSet EXIT_TASK "false" $GLOBAL_COMMON
    echoInfo "INFO: Container $name unhalted"
fi

set +x && echo ""
echoC ";whi"  " =============================================================================="
echoC ";whi"  "|           FINISHED:$(strFixL " KIRA PROCESS TERMINATOR $KIRA_SETUP_VER" 58)|"   
echoC ";whi"  "|            ELAPSED:$(strFixL " $(timerSpan container-pkill) " 58)|"
echoC ";whi"  " =============================================================================="
echo "" && set -x 
