#!/bin/bash

set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/container-manager.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NAME=$1
HALT_FILE="$DOCKER_COMMON/$NAME/halt"

set +x
echo "INFO: Launching KIRA Container Manager..."

TMP_DIR="/tmp/kira-cnt-stats" # performance counters directory
NETWORKS_PATH="$TMP_DIR/networks"
STATUS_PATH="$TMP_DIR/status-$NAME"
LIP_PATH="$TMP_DIR/lip-$NAME"

mkdir -p $TMP_DIR
rm -fv $NETWORKS_PATH
rm -fv $STATUS_PATH
rm -fv $LIP_PATH

touch $NETWORKS_PATH
touch $STATUS_PATH
touch $LIP_PATH

echo "INFO: Wiping halt files of $NAME container..."

rm -fv $HALT_FILE

WHITESPACE="                                                          "
CONTAINER_DUMP="$KIRA_DUMP/kira/${NAME,,}"

mkdir -p $CONTAINER_DUMP

HOSTNAME=""
LOADING="true"
while : ; do
    START_TIME="$(date -u +%s)"

    NETWORKS=$(cat $NETWORKS_PATH)
    LIP=$(cat $LIP_PATH)

    touch "${NETWORKS_PATH}.pid" && if ! kill -0 $(cat "${NETWORKS_PATH}.pid") 2> /dev/null ; then
        echo $(docker network ls --format="{{.Name}}" 2> /dev/null || "") > "$NETWORKS_PATH" &
        PID1="$!" && echo "$PID1" > "${NETWORKS_PATH}.pid"
    fi

    touch "${STATUS_PATH}.pid" && if ! kill -0 $(cat "${STATUS_PATH}.pid") 2> /dev/null ; then
        $KIRA_MANAGER/kira/container-status.sh "$NAME" "$STATUS_PATH" "$NETWORKS" &
        PID2="$!" && echo "$PID2" > "${STATUS_PATH}.pid"
    fi

    touch "${LIP_PATH}.pid" && if ! kill -0 $(cat "${LIP_PATH}.pid") 2> /dev/null && [ ! -z "$HOSTNAME" ] ; then
        echo $(getent hosts $HOSTNAME 2> /dev/null | awk '{print $1}' 2> /dev/null | xargs 2> /dev/null || echo "") > "$LIP_PATH" &
        PID3="$!" && echo "$PID3" > "${LIP_PATH}.pid"
    fi

    clear
    
    echo -e "\e[36;1m-------------------------------------------------"
    echo "|        KIRA CONTAINER MANAGER v0.0.4          |"
    echo "|------------ $(date '+%d/%m/%Y %H:%M:%S') --------------|"
    [ "${LOADING,,}" == "true" ] && echo -e "|\e[0m\e[31;1m PLEASE WAIT, LOADING CONTAINER STATUS ...     \e[36;1m|"
    [ "${LOADING,,}" == "true" ] && wait $PID1 && wait $PID2 && LOADING="false" && continue

    source "$STATUS_PATH"

    ID="ID_$NAME" && ID="${!ID}"
    EXISTS="EXISTS_$NAME" && EXISTS="${!EXISTS}"
    REPO="REPO_$NAME" && REPO="${!REPO}"
    STATUS="STATUS_$NAME" && STATUS="${!STATUS}"
    HEALTH="HEALTH_$NAME" && HEALTH="${!HEALTH}"
    RESTARTING="RESTARTING_$NAME" && RESTARTING="${!RESTARTING}"
    STARTED_AT="STARTED_AT_$NAME" && STARTED_AT="${!STARTED_AT}"
    FINISHED_AT="FINISHED_AT_$NAME" && FINISHED_AT="${!FINISHED_AT}"
    HOSTNAME="HOSTNAME_$NAME" && HOSTNAME="${!HOSTNAME}"
    EXPOSED_PORTS="EXPOSED_PORTS_$NAME" && EXPOSED_PORTS="${!EXPOSED_PORTS}"

    if [ "${EXISTS,,}" != "true" ] ; then
        clear
        echo "WARNING: Container $NAME no longer exists, aborting container manager..."
        sleep 2
        break
    fi

    NAME_TMP="${NAME}${WHITESPACE}"
    echo "|        Name: ${NAME_TMP:0:32} : $(echo $ID | head -c 4)...$(echo $ID | tail -c 5)"

    [ "${LOADING,,}" == "true" ] && wait && LOADING="false" && continue

    if [ "${EXISTS,,}" == "true" ] ; then # container exists
        PORTS=$(docker ps --format "{{.Ports}}" -aqf "name=sentry" 2> /dev/null || echo "")
        if [ ! -z "$PORTS" ] && [ "${PORTS,,}" != "null" ] ; then  
            for port in $(echo $PORTS | sed "s/,/ /g" | xargs) ; do
                echo "|    Port Map: ${port:0:32} |"
            done
        fi
        i=-1 ; for net in $NETWORKS ; do i=$((i+1))
            IP="IP_$NAME_$net" && IP="${!IP}"
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

    ALLOWED_OPTIONS="x"
    [ "${RESTARTING,,}" == "true" ] && STATUS="restart"
    echo "|-----------------------------------------------|"
    [ ! -z "$HOSTNAME0" ] && \
    echo "|   Hostname: ${HOSTNAME0:33} : $LIP"
    [ "$STATUS" != "exited" ] && \
    echo "|     Status: $STATUS ($(echo $STARTED_AT | head -c 19))"
    [ "$STATUS" == "exited" ] && \
    echo "|     Status: $STATUS ($(echo $FINISHED_AT | head -c 19))"
    echo "|     Health: $HEALTH"
    echo "|-----------------------------------------------|"
    [ "${EXISTS,,}" == "true" ]    && echo "| [I] | Try INSPECT container                   |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}i"
    [ "${EXISTS,,}" == "true" ]    && echo "| [L] | Show container LOGS                     |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}l"
    [ "${EXISTS,,}" == "true" ]    && echo "| [D] | Dump all container LOGS                 |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}d"
    [ "${EXISTS,,}" == "true" ]    && echo "| [R] | RESTART container                       |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}r"
    [ "$STATUS" == "exited" ]      && echo "| [S] | START container                         |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s"
    [ "$STATUS" == "running" ]     && echo "| [S] | STOP container                          |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s"
    [ "$STATUS" == "running" ]     && echo "| [R] | RESTART container                       |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}r"
    [ "$STATUS" == "running" ]     && echo "| [P] | PAUSE container                         |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p"
    [ "$STATUS" == "paused" ]      && echo "| [P] | Un-PAUSE container                      |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p"
    [ "${EXISTS,,}" == "true" ] && echo -e "| [X] | Exit __________________________________ |\e[0m"

    read -s -n 1 -t 6 OPTION || continue
    [ -z "$OPTION" ] && continue
    [[ "${ALLOWED_OPTIONS,,}" != *"$OPTION"* ]] && continue

    if [ "${OPTION,,}" != "x" ] && [[ $OPTION != ?(-)+([0-9]) ]] ; then
        ACCEPT="" && while [ "${ACCEPT,,}" != "y" ] && [ "${ACCEPT,,}" != "n" ] ; do echo -en "\e[36;1mPress [Y]es to confirm option (${OPTION^^}) or [N]o to cancel: \e[0m\c" && read  -d'' -s -n1 ACCEPT && echo "" ; done
        [ "${ACCEPT,,}" == "n" ] && echo -e "\nWARINIG: Operation was cancelled\n" && sleep 1 && continue
        echo ""
    fi

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
        $KIRAMGR_SCRIPTS/dump-logs.sh "$NAME" "true"
        EXECUTED="true"
    elif [ "${OPTION,,}" == "r" ] ; then
        echo "INFO: Restarting container..."
        $KIRA_SCRIPTS/container-restart.sh $NAME
        EXECUTED="true"
    elif [ "${OPTION,,}" == "s" ] && [ "$STATUS" == "running" ] ; then
        echo "INFO: Stopping container..."
        $KIRA_SCRIPTS/container-stop.sh $NAME
        EXECUTED="true"
    elif [ "${OPTION,,}" == "s" ] && [ "$STATUS" != "running" ] ; then
        echo "INFO: Starting container..."
        $KIRA_SCRIPTS/container-start.sh $NAME
        EXECUTED="true"
    elif [ "${OPTION,,}" == "p" ] && [ "$STATUS" == "running" ] ; then
        echo "INFO: Pausing container..."
        $KIRA_SCRIPTS/container-pause.sh $NAME
        EXECUTED="true"
    elif [ "${OPTION,,}" == "p" ] && [ "$STATUS" == "paused" ] ; then
        echo "INFO: UnPausing container..."
        $KIRA_SCRIPTS/container-unpause.sh $NAME
        EXECUTED="true"
    elif [ "${OPTION,,}" == "l" ] ; then
        LOG_LINES=5
        while : ; do
            clear
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
