#!/bin/bash

set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_WORKSTATION/kira/container-manager.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NAME=$1
HALT_FILE="$DOCKER_COMMON/$NAME/halt"
WHITESPACE="                                                          "
echo "INFO: Launching KIRA Container Manager..."
echo "INFO: Wiping halt files of $NAME container..."
rm -fv $HALT_FILE

CONTAINER_DUMP="$KIRA_DUMP/kira/${NAME,,}"
mkdir -p $CONTAINER_DUMP

while : ; do
    START_TIME="$(date -u +%s)"
    source $KIRA_WORKSTATION/kira/container-status.sh "$NAME"

    if [ "${EXISTS,,}" != "true" ] ; then
        clear
        echo "WARNING: Container $NAME no longer exists, aborting container manager..."
        sleep 2
        break
    fi

    clear
    
    echo -e "\e[36;1m-------------------------------------------------"
    echo "|        KIRA CONTAINER MANAGER v0.0.4          |"
    echo "|------------ $(date '+%d/%m/%Y %H:%M:%S') --------------|"
    NAME_TMP="$NAME                                                  "
    echo "|        Name: ${NAME_TMP:0:32} : $(echo $ID | head -c 4)...$(echo $ID | tail -c 5)"

    if [ "${EXISTS,,}" == "true" ] ; then # container exists
        i=-1 ; for net in $NETWORKS ; do i=$((i+1))
            IP="IP_$net" && IP="${!IP}"
            if [ ! -z "$IP" ] && [ "${IP,,}" != "null" ] ; then
                IP_TMP="${IP}${WHITESPACE}"
                echo "|  Ip Address: ${IP_TMP:0:32} : $net"
            fi
        done
    fi

    if [ ! -z "$REPO" ] ; then
        REPO_TMP="${REPO}${WHITESPACE}"
        echo "| Repo: ${REPO_TMP:0:39} : $BRANCH"
    fi

    echo "|-----------------------------------------------|"
    echo "|     Status: $STATUS"
    echo "|     Health: $HEALTH"
    echo "| Restarting: $RESTARTING"
    echo "| Started At: $(echo $STARTED_AT | head -c 19)"
    echo "|-----------------------------------------------|"
    [ "${EXISTS,,}" == "true" ] && 
    echo "| [I] | Try INSPECT container                   |"
    [ "${EXISTS,,}" == "true" ] && 
    echo "| [L] | Show container LOGS                     |"
    [ "${EXISTS,,}" == "true" ] && 
    echo "| [D] | Dump all container LOGS                 |"
    [ "${EXISTS,,}" == "true" ] && 
    echo "| [R] | RESTART container                       |"
    [ "$STATUS" == "exited" ] && 
    echo "| [A] | START container                         |"
    [ "$STATUS" == "running" ] && 
    echo "| [S] | STOP container                          |"
    [ "$STATUS" == "running" ] && 
    echo "| [R] | RESTART container                       |"
    [ "$STATUS" == "running" ] && 
    echo "| [P] | PAUSE container                         |"
    [ "$STATUS" == "paused" ] && 
    echo "| [U] | UNPAUSE container                       |"
    [ "${EXISTS,,}" == "true" ] && 
    echo -e "| [X] | Exit __________________________________ |\e[0m"

    read -s -n 1 -t 6 OPTION || continue
    [ -z "$OPTION" ] && continue

    ACCEPT="" && while [ "${ACCEPT,,}" != "y" ] && [ "${ACCEPT,,}" != "n" ] ; do echo -en "\e[36;1mPress [Y]es to confirm option (${OPTION^^}) or [N]o to cancel: \e[0m\c" && read  -d'' -s -n1 ACCEPT && echo "" ; done
    [ "${ACCEPT,,}" == "n" ] && echo -e "\nWARINIG: Operation was cancelled\n" && sleep 1 && continue
    echo ""

    EXECUTED="false"
    if [ "${OPTION,,}" == "i" ] ; then
        echo "INFO: Entering container $NAME ($ID)..."
        echo "INFO: To exit the container type 'exit'"
        FAILURE="false"
        docker exec -it $ID bash || docker exec -it $ID sh || FAILURE="true"
        
        if [ "${FAILURE,,}" == "true" ] ; then
            ACCEPT="" && while [ "${ACCEPT,,}" != "y" ] && [ "${ACCEPT,,}" != "n" ] ; do echo -en "\e[36;1mPress [Y]es to reboot & retry or [N]o to cancel: \e[0m\c" && read  -d'' -s -n1 ACCEPT && echo "" ; done
            [ "${ACCEPT,,}" == "n" ] && echo -e "\nWARINIG: Operation was cancelled\n" && sleep 1 && continue
            echo "WARNING: Failed to inspect $NAME container"
            echo "INFO: Attempting to start & prevent node from restarting..."
            touch $HALT_FILE
            $KIRA_SCRIPTS/container-restart.sh $NAME
            echo "INFO: Waiting for container to start..."
            sleep 3
            echo "INFO: Entering container $NAME ($ID)..."
            echo "INFO: To exit the container type 'exit'"
            docker exec -it $ID bash || docker exec -it $ID sh || echo "WARNING: Failed to inspect $NAME container"
        fi
        rm -fv $HALT_FILE
        OPTION=""
        EXECUTED="true"
    elif [ "${OPTION,,}" == "d" ] ; then
        echo "INFO: Dumping all loggs..."
        $WORKSTATION_SCRIPTS/dump-logs.sh $NAME
        EXECUTED="true"
    elif [ "${OPTION,,}" == "r" ] ; then
        echo "INFO: Restarting container..."
        $KIRA_SCRIPTS/container-restart.sh $NAME
        EXECUTED="true"
    elif [ "${OPTION,,}" == "a" ] ; then
        echo "INFO: Staring container..."
        $KIRA_SCRIPTS/container-start.sh $NAME
        EXECUTED="true"
    elif [ "${OPTION,,}" == "s" ] ; then
        echo "INFO: Stopping container..."
        $KIRA_SCRIPTS/container-stop.sh $NAME
        EXECUTED="true"
    elif [ "${OPTION,,}" == "p" ] ; then
        echo "INFO: Pausing container..."
        $KIRA_SCRIPTS/container-pause.sh $NAME
        EXECUTED="true"
    elif [ "${OPTION,,}" == "u" ] ; then
        echo "INFO: UnPausing container..."
        $KIRA_SCRIPTS/container-unpause.sh $NAME
        EXECUTED="true"
    elif [ "${OPTION,,}" == "l" ] ; then
        LOG_LINES=5
        while : ; do
            echo "INFO: Attempting to display $NAME container log..."
            TMP_DUMP=$CONTAINER_DUMP/tmp.log && rm -f $TMP_DUMP && touch $TMP_DUMP
            docker container logs --details --timestamps $ID > $TMP_DUMP || echo "WARNING: Failed to dump $NAME container logs"
            MAX=$(cat $TMP_DUMP | wc -l)
            [ $LOG_LINES -gt $MAX ] && LOG_LINES=$MAX
            echo -e "\e[36;1mINFO: Found $LINES_MAX log lines, printing $LOG_LINES...\e[0m"
            tac $TMP_DUMP | head -n $LOG_LINES
            echo -e "\e[36;1mINFO: Printed last $LOG_LINES lines\e[0m"
            ACCEPT="" && while [ "${ACCEPT,,}" != "m" ] && [ "${ACCEPT,,}" != "c" ] && [ "${ACCEPT,,}" != "r" ] ; do echo -en "\e[36;1mTry to show [M]ore lines, [R]efresh or [C]lose: \e[0m\c" && read  -d'' -s -n1 ACCEPT && echo "" ; done
            [ "${ACCEPT,,}" == "c" ] && echo -e "\nINFO: Closing log file...\n" && sleep 1 && break
            [ "${ACCEPT,,}" == "r" ] && continue
            LOG_LINES=$(($LOG_LINES + 5))
        done
        OPTION=""
        EXECUTED="true"
    elif [ "${OPTION,,}" == "x" ] ; then
        echo -e "INFO: Stopping Container Manager...\n"
        OPTION=""
        EXECUTED="true"
        sleep 1
        break
    fi
    
    if [ "${EXECUTED,,}" == "true" ] && [ ! -z $OPTION ] ; then
        echo "INFO: Option ($OPTION) was executed, press any key to continue..."
        read -s -n 1 || continue
    fi
done

echo "INFO: Contianer Manager Stopped"
