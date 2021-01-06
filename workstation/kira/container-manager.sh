#!/bin/bash

set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/container-manager.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NAME=$1
HALT_DIR="$DOCKER_COMMON/$NAME"
HALT_FILE="$HALT_DIR/halt"

set +x
echo "INFO: Launching KIRA Container Manager..."

SCAN_DIR="$KIRA_HOME/kirascan"
NETWORKS_SCAN_PATH="$SCAN_DIR/networks"

TMP_DIR="/tmp/kira-cnt-stats" # performance counters directory
NETWORKS_PATH="$TMP_DIR/networks"
STATUS_PATH="$TMP_DIR/status-$NAME"
LIP_PATH="$TMP_DIR/lip-$NAME"
PORTS_PATH="$TMP_DIR/ports-$NAME"

mkdir -p $TMP_DIR
rm -fv $NETWORKS_PATH
rm -fv $STATUS_PATH
rm -fv $LIP_PATH
rm -fv $PORTS_PATH

touch $NETWORKS_PATH
touch $STATUS_PATH
touch $LIP_PATH
touch $PORTS_PATH

echo "INFO: Wiping halt files of $NAME container..."

rm -fv $HALT_FILE
mkdir -p $HALT_DIR

WHITESPACE="                                                          "
CONTAINER_DUMP="$KIRA_DUMP/kira/${NAME,,}"

mkdir -p $CONTAINER_DUMP

HOSTNAME=""
LOADING="true"
while : ; do
    START_TIME="$(date -u +%s)"

    NETWORKS=$(cat $NETWORKS_SCAN_PATH 2> /dev/null || echo "")
    LIP=$(cat $LIP_PATH)
    PORTS=$(cat $PORTS_PATH)

    touch "${STATUS_PATH}.pid" && if ! kill -0 $(cat "${STATUS_PATH}.pid") 2> /dev/null ; then
        [ "${LOADING,,}" == "true" ] && rm -f "$STATUS_PATH-$NAME" && touch "$STATUS_PATH-$NAME"
        $KIRA_MANAGER/kira/container-status.sh "$NAME" "$STATUS_PATH-$NAME" "$NETWORKS" &
        PID2="$!" && echo "$PID2" > "${STATUS_PATH}.pid"
    fi

    touch "${LIP_PATH}.pid" && if ! kill -0 $(cat "${LIP_PATH}.pid") 2> /dev/null ; then
        if [ ! -z "$HOSTNAME" ] ; then
            echo $(getent hosts $HOSTNAME 2> /dev/null | awk '{print $1}' 2> /dev/null | xargs 2> /dev/null || echo "") > "$LIP_PATH" &
            PID3="$!" && echo "$PID3" > "${LIP_PATH}.pid"
        fi
    fi

    touch "${PORTS_PATH}.pid" && if ! kill -0 $(cat "${PORTS_PATH}.pid") 2> /dev/null ; then
        echo $(docker ps --format "{{.Ports}}" -aqf "name=$NAME" 2> /dev/null || echo "") > "$PORTS_PATH" &
        PID4="$!" && echo "$PID4" > "${PORTS_PATH}.pid"
    fi

    clear
    
    echo -e "\e[36;1m-------------------------------------------------"
    echo "|        KIRA CONTAINER MANAGER v0.0.6          |"
    echo "|------------ $(date '+%d/%m/%Y %H:%M:%S') --------------|"
    [ "${LOADING,,}" == "true" ] && echo -e "|\e[0m\e[31;1m PLEASE WAIT, LOADING CONTAINER STATUS ...     \e[36;1m|"
    [ "${LOADING,,}" == "true" ] && wait $PID2 && wait $PID4 && LOADING="false" && continue

    source "$STATUS_PATH-$NAME"

    ID="ID_$NAME" && ID="${!ID}"
    EXISTS="EXISTS_$NAME" && EXISTS="${!EXISTS}"
    REPO="REPO_$NAME" && REPO="${!REPO}"
    BRANCH="BRANCH_$NAME" && BRANCH="${!BRANCH}"
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
    echo "|     Name: ${NAME_TMP:0:35} : $(echo $ID | head -c 4)...$(echo $ID | tail -c 5)"

    [ "${LOADING,,}" == "true" ] && wait && LOADING="false" && continue

    if [ ! -z "$REPO" ] ; then
        REPO_TMP=$(echo "$REPO" | grep -oP "^https://\K.*")
        REPO_TMP="${REPO}${WHITESPACE}"
        echo "|     Repo: ${REPO_TMP:0:35} : $BRANCH"
    fi

    if [ "${EXISTS,,}" == "true" ] ; then # container exists
        if [ ! -z "$PORTS" ] && [ "${PORTS,,}" != "null" ] ; then  
            for port in $(echo $PORTS | sed "s/,/ /g" | xargs) ; do
                port_tmp="${port}${WHITESPACE}"
                port_tmp=$(echo "$port_tmp" | grep -oP "^0.0.0.0:\K.*")
                echo "| Port Map: ${port_tmp:0:35} |"
            done
        fi
        i=-1 ; for net in $NETWORKS ; do i=$((i+1))
            TMP_IP="IP_${NAME}_${net}" && TMP_IP="${!TMP_IP}"
            if [ ! -z "$TMP_IP" ] && [ "${TMP_IP,,}" != "null" ] ; then
                IP_TMP="${TMP_IP} ($net) ${WHITESPACE}"
                echo "| Local IP: ${IP_TMP:0:35} |"
            fi
        done
    fi

    ALLOWED_OPTIONS="x"
    [ "${RESTARTING,,}" == "true" ] && STATUS="restart"
    echo "|-----------------------------------------------|"
    if [ ! -z "$HOSTNAME" ] ; then
        [ ! -z "$LIP" ] && TMP_HOSTNAME="${HOSTNAME} ($LIP) ${WHITESPACE}" || TMP_HOSTNAME="${HOSTNAME}${WHITESPACE}"
        echo "|   Host: ${TMP_HOSTNAME:0:37} |"
    fi
    [ "$STATUS" != "exited" ] && \
    echo "| Status: $STATUS ($(echo $STARTED_AT | head -c 19))"
    [ "$STATUS" == "exited" ] && \
    echo "| Status: $STATUS ($(echo $FINISHED_AT | head -c 19))"
    [ "$HEALTH" != "null" ] && [ ! -z "$HEALTH" ] && \
    echo "| Health: $HEALTH"
    echo "|-----------------------------------------------|"
    [ "${EXISTS,,}" == "true" ]    && echo "| [I] | Try INSPECT container                   |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}i"
    [ "${EXISTS,,}" == "true" ]    && echo "| [L] | Show container LOGS                     |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}l"
    [ "${EXISTS,,}" == "true" ]    && echo "| [D] | DUMP all container logs                 |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}d"
    [ "${EXISTS,,}" == "true" ]    && echo "| [R] | RESTART container                       |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}r"
    [ "$STATUS" == "exited" ]      && echo "| [S] | START container                         |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s"
    [ "$STATUS" == "running" ]     && echo "| [S] | STOP container                          |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s"
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
        LOADING="true"
        EXECUTED="true"
    elif [ "${OPTION,,}" == "s" ] && [ "$STATUS" == "running" ] ; then
        echo "INFO: Stopping container..."
        $KIRA_SCRIPTS/container-stop.sh $NAME
        LOADING="true"
        EXECUTED="true"
    elif [ "${OPTION,,}" == "s" ] && [ "$STATUS" != "running" ] ; then
        echo "INFO: Starting container..."
        $KIRA_SCRIPTS/container-start.sh $NAME
        LOADING="true"
        EXECUTED="true"
    elif [ "${OPTION,,}" == "p" ] && [ "$STATUS" == "running" ] ; then
        echo "INFO: Pausing container..."
        $KIRA_SCRIPTS/container-pause.sh $NAME
        LOADING="true"
        EXECUTED="true"
    elif [ "${OPTION,,}" == "p" ] && [ "$STATUS" == "paused" ] ; then
        echo "INFO: UnPausing container..."
        $KIRA_SCRIPTS/container-unpause.sh $NAME
        LOADING="true"
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
            ACCEPT="" && while [ "${ACCEPT,,}" != "m" ] && [ "${ACCEPT,,}" != "l" ] && [ "${ACCEPT,,}" != "c" ] && [ "${ACCEPT,,}" != "r" ] ; do echo -en "\e[36;1mTry to show [M]ore, [L]ess, [R]efresh or [C]lose: \e[0m\c" && read  -d'' -s -n1 ACCEPT && echo "" ; done
            [ "${ACCEPT,,}" == "c" ] && echo -e "\nINFO: Closing log file...\n" && sleep 1 && break
            [ "${ACCEPT,,}" == "r" ] && continue
            [ "${ACCEPT,,}" == "m" ] && LOG_LINES=$(($LOG_LINES + 5))
            [ "${ACCEPT,,}" == "l" ] && [ $LOG_LINES -gt 5 ] && LOG_LINES=$(($LOG_LINES - 5))
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
        echo -en "\e[31;1mINFO: Option ($OPTION) was executed, press any key to continue...\e[0m" && read -n 1 -s && echo ""
    fi
done

echo "INFO: Contianer Manager Stopped"
