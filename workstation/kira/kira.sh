#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_WORKSTATION/kira/kira.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

echo "INFO: Launching KIRA Network Manager..."

while : ; do
    START_TIME="$(date -u +%s)"
    CONTAINERS=$(docker ps -a | awk '{if(NR>1) print $NF}' | tac)  
    VARS_FILE="/tmp/kira_mgr_vars" # file contianing cached variables with details regarding individual containers

    rm -f $VARS_FILE && touch $VARS_FILE && chmod 777 $VARS_FILE
    i=-1 ; for name in $CONTAINERS ; do i=$((i+1))
        $KIRA_WORKSTATION/kira/container-status.sh $name $VARS_FILE &
    done

    CONTAINERS_COUNT=$((i+1))

    wait # wait for all subprocesses to finish
    source $VARS_FILE

    SUCCESS="true"
    IS_ANY_CONTAINER_RUNNING="false"
    IS_ANY_CONTAINER_PAUSED="false"
    ALL_CONTAINERS_PAUSED="true"
    ALL_CONTAINERS_STOPPED="true"
    ALL_CONTAINERS_HEALTHY="true"
    i=-1 ; for name in $CONTAINERS ; do i=$((i+1))
        STATUS_TMP="STATUS_$name" && STATUS_TMP="${!STATUS_TMP}"
        HEALTH_TMP="HEALTH_$name" && HEALTH_TMP="${!HEALTH_TMP}"
        [ "${STATUS_TMP,,}" != "running" ] && SUCCESS="false"
        [ "${name,,}" == "registry" ] && continue
        [ "${HEALTH_TMP,,}" != "healthy" ] && ALL_CONTAINERS_HEALTHY="false"
        [ "${STATUS_TMP,,}" != "exited" ] && ALL_CONTAINERS_STOPPED="false"
        [ "${STATUS_TMP,,}" != "paused" ] && ALL_CONTAINERS_PAUSED="false"
        [ "${STATUS_TMP,,}" == "running" ] && IS_ANY_CONTAINER_RUNNING="true"
        [ "${STATUS_TMP,,}" == "paused" ] && IS_ANY_CONTAINER_PAUSED="true"
        # TODO: show failed status if any of the healthchecks fails
    done

    [ $CONTAINERS_COUNT -le 4 ] && SUCCESS="false" # TODO: check required container count based on mode

    clear
    
    echo -e "\e[33;1m------------------------------------------------- [mode]"
    echo "|         KIRA NETWORK MANAGER v0.0.6           : $INFRA_MODE"
    echo "|             $(date '+%d/%m/%Y %H:%M:%S')               |"

    if [ "${SUCCESS,,}" != "true" ] ; then
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRA. IS NOT LAUNCHED       \e[33;1m|"
    elif [ "${ALL_CONTAINERS_HEALTHY,,}" != "true" ] ; then
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRASTRUCTURE IS UNHEALTHY  \e[33;1m|"
    elif [ "${SUCCESS,,}" == "true" ] && [ "${ALL_CONTAINERS_HEALTHY,,}" == "true" ] ; then
        echo -e "|\e[0m\e[32;1m     SUCCESS, INFRASTRUCTURE IS HEALTHY        \e[33;1m|"
    else
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRA. IS NOT OPERATIONAL    \e[33;1m|"
    fi

    echo "|-----------------------------------------------| [health]"
    i=-1 ; for name in $CONTAINERS ; do i=$((i+1))
        STATUS_TMP="STATUS_$name" && STATUS_TMP="${!STATUS_TMP}"
        HEALTH_TMP="HEALTH_$name" && HEALTH_TMP="${!HEALTH_TMP}"
        LABEL="| [$i] | Mange $name ($STATUS_TMP)                           "
        echo "${LABEL:0:47} : $HEALTH_TMP"
    done
    echo "|-----------------------------------------------|"
    if [ "$CONTAINERS_COUNT" != "0" ] ; then
        [ "${ALL_CONTAINERS_STOPPED,,}" == "false" ] && \
        echo "| [S] | STOP All Containers                     |"
        echo "| [R] | Re-START All Containers                 |"
        [ "${ALL_CONTAINERS_PAUSED,,}" == "false" ] && \
        echo "| [P] | PAUSE All Containers                    |"
        [ "${IS_ANY_CONTAINER_PAUSED,,}" == "true" ] && \
        echo "| [U] | Un-PAUSE All Containers                 |"
        echo "|-----------------------------------------------|"
    fi
    echo "| [D] | DUMP All Loggs                          |"
    echo "|-----------------------------------------------|"
    echo "| [X] | Exit | [W] | Refresh Window             |"
    echo -e "-------------------------------------------------\e[0m"
    
    read -s -n 1 -t 6 OPTION || continue
    [ -z "$OPTION" ] && continue

    ACCEPT="" && while [ "${ACCEPT,,}" != "y" ] && [ "${ACCEPT,,}" != "n" ] ; do echo -en "\e[33;1mPress [Y]es to confirm option (${OPTION^^}) or [N]o to cancel: \e[0m\c" && read  -d'' -s -n1 ACCEPT && echo "" ; done
    [ "${ACCEPT,,}" == "n" ] && echo -e "\nWARINIG: Operation was cancelled\n" && sleep 1 && continue
    echo ""

    EXECUTED="false"
    i=-1 ; for name in $CONTAINERS ; do i=$((i+1))
        if [ "$OPTION" == "$i" ] ; then
            source $KIRA_WORKSTATION/kira/container-manager.sh $name
            OPTION="" # reset option
            break
        elif [ "${OPTION,,}" == "l" ] ; then
           echo "INFO: Dumping all loggs from $name container..."
           $WORKSTATION_SCRIPTS/dump-logs.sh $name
           EXECUTED="true"
        elif [ "${OPTION,,}" == "r" ] ; then
           echo "INFO: Restarting $name container..."
           $KIRA_SCRIPTS/container-restart.sh $name
           EXECUTED="true"
        elif [ "${OPTION,,}" == "a" ] ; then
           echo "INFO: Staring $name container..."
           $KIRA_SCRIPTS/container-start.sh $NAME
           EXECUTED="true"
        elif [ "${OPTION,,}" == "s" ] ; then
           echo "INFO: Stopping $name container..."
           $KIRA_SCRIPTS/container-stop.sh $name
           EXECUTED="true"
        elif [ "${OPTION,,}" == "p" ] ; then
           echo "INFO: Pausing $name container..."
           $KIRA_SCRIPTS/container-pause.sh $name
           EXECUTED="true"
        elif [ "${OPTION,,}" == "u" ] ; then
           echo "INFO: UnPausing $name container..."
           $KIRA_SCRIPTS/container-unpause.sh $name
           EXECUTED="true"
        fi
    done

    if [ "${EXECUTED,,}" == "true" ] ; then
        echo "INFO: Option ($OPTION) was executed, press any key to continue..."
        read -s -n 1 || continue
    fi

    if [ "${OPTION,,}" == "w" ] ; then
        echo "INFO: Please wait, refreshing user interface..."
    elif [ "${OPTION,,}" == "x" ] ; then
        clear
        exit 0
    fi
done
