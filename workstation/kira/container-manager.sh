#!/bin/bash

set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/container-manager.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NAME=$1
HALT_DIR="$DOCKER_COMMON/$NAME"
HALT_FILE="$HALT_DIR/halt"

set +x
echo "INFO: Launching KIRA Container Manager..."

cd $KIRA_HOME
SCAN_DIR="$KIRA_HOME/kirascan"
SCAN_DONE="$SCAN_DIR/done"
CONTAINERS_SCAN_PATH="$SCAN_DIR/containers"
NETWORKS_SCAN_PATH="$SCAN_DIR/networks"
CONTAINER_STATUS="$SCAN_DIR/status/$NAME"

SNAP_STATUS="$KIRA_SNAP/status"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_LATEST="$SNAP_STATUS/latest"

TMP_DIR="/tmp/kira-cnt-stats" # performance counters directory
LIP_PATH="$TMP_DIR/lip-$NAME"
KADDR_PATH="$TMP_DIR/kira-addr-$NAME" # kira address 
NODE_ID_PATH="$TMP_DIR/node-id-$NAME" # kira address 

mkdir -p $TMP_DIR
rm -fv $LIP_PATH $KADDR_PATH $NODE_ID_PATH
touch $LIP_PATH $KADDR_PATH $NODE_ID_PATH

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
    KADDR=$(cat $KADDR_PATH)
    NODE_ID=$(cat $NODE_ID_PATH)

    touch "${LIP_PATH}.pid" && if ! kill -0 $(cat "${LIP_PATH}.pid") 2> /dev/null ; then
        if [ ! -z "$HOSTNAME" ] ; then
            echo $(getent hosts $HOSTNAME 2> /dev/null | awk '{print $1}' 2> /dev/null | xargs 2> /dev/null || echo "") > "$LIP_PATH" &
            PID1="$!" && echo "$PID1" > "${LIP_PATH}.pid"
        fi
    fi

    touch "${KADDR_PATH}.pid" && if ! kill -0 $(cat "${KADDR_PATH}.pid") 2> /dev/null ; then
        if [ "${NAME,,}" == "interx" ] ; then
            echo $(curl $KIRA_INTERX_DNS:$KIRA_INTERX_PORT/api/faucet 2>/dev/null 2> /dev/null | jq -r '.address' 2> /dev/null || echo "") > "$KADDR_PATH" &
            PID2="$!" && echo "$PID2" > "${KADDR_PATH}.pid"
        fi
    fi

    touch "${NODE_ID_PATH}.pid" && if ! kill -0 $(cat "${NODE_ID_PATH}.pid") 2> /dev/null ; then
        if [ "${NAME,,}" == "sentry" ] || [ "${NAME,,}" == "priv_sentry" ] || [ "${NAME,,}" == "snapshoot" ] || [ "${NAME,,}" == "validator" ] ; then
            echo $(docker exec -i $NAME sekaid status 2> /dev/null | jq -c '.node_info.id' 2> /dev/null | xargs 2> /dev/null || echo "") > "$NODE_ID_PATH" &
            PID3="$!" && echo "$PID3" > "${NODE_ID_PATH}.pid"
        fi
    fi

    clear
    
    echo -e "\e[36;1m-----------------------------------------------------"
    echo "|          KIRA CONTAINER MANAGER v0.0.9            |"
    echo "|-------------- $(date '+%d/%m/%Y %H:%M:%S') ----------------|"

    if [ "${LOADING,,}" == "true" ] ; then
        echo -e "|\e[0m\e[31;1m PLEASE WAIT, LOADING CONTAINER STATUS ...         \e[36;1m|"
        while [ ! -f $SCAN_DONE ] ; do
            sleep 1
        done
        wait $PID1 
        LOADING="false"
        continue
    fi

    source "$CONTAINER_STATUS"

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
    PORTS="PORTS_$NAME" && PORTS="${!PORTS}"
    EXPOSED_PORTS="EXPOSED_PORTS_$NAME" && EXPOSED_PORTS="${!EXPOSED_PORTS}"

    if [ "${EXISTS,,}" != "true" ] ; then
        clear
        echo "WARNING: Container $NAME no longer exists, aborting container manager..."
        sleep 2
        break
    fi

    NAME_TMP="${NAME}${WHITESPACE}"
        echo "|      Name: ${NAME_TMP:0:38} : $(echo $ID | head -c 4)...$(echo $ID | tail -c 5)"

    if [ ! -z "$REPO" ] ; then
        REPO_TMP=$(echo "$REPO" | grep -oP "^https://\K.*")
        REPO_TMP="${REPO}${WHITESPACE}"
        echo "|      Repo: ${REPO_TMP:0:38} : $BRANCH"
    fi

    if [ "${NAME,,}" == "snapshoot" ] && [ -f "$SNAP_LATEST" ] ; then
        LAST_SNAP_FILE="$(cat $SNAP_LATEST)${WHITESPACE}"
        LAST_SNAP_PROGRESS="$(cat $SNAP_PROGRESS 2> /dev/null || echo "") %"
        [ -f "$SNAP_DONE" ] && LAST_SNAP_PROGRESS="done"
        echo "| Last Snap: ${LAST_SNAP_FILE:0:38} : $LAST_SNAP_PROGRESS"
        echo "|  Snap Dir: ${KIRA_SNAP}"
    fi

    if [ "${NAME,,}" == "interx" ] && [ ! -z "$KADDR" ] ; then
        KADDR_TMP="${KADDR}${WHITESPACE}"
        echo "|    Faucet: ${KADDR_TMP:0:38} "
    fi

    if [ "${EXISTS,,}" == "true" ] ; then # container exists
        if [ ! -z "$PORTS" ] && [ "${PORTS,,}" != "null" ] ; then  
            for port in $(echo $PORTS | sed "s/,/ /g" | xargs) ; do
                port_tmp="${port}${WHITESPACE}"
                port_tmp=$(echo "$port_tmp" | grep -oP "^0.0.0.0:\K.*" || echo "$port_tmp")
                echo "| Port Map: ${port_tmp:0:39} |"
            done
        fi
        i=-1 ; for net in $NETWORKS ; do i=$((i+1))
            TMP_IP="IP_${NAME}_${net}" && TMP_IP="${!TMP_IP}"
            if [ ! -z "$TMP_IP" ] && [ "${TMP_IP,,}" != "null" ] ; then
                IP_TMP="${TMP_IP} ($net) ${WHITESPACE}"
                echo "| Local IP: ${IP_TMP:0:39} |"
            fi
        done
    fi

    ALLOWED_OPTIONS="x"
    [ "${RESTARTING,,}" == "true" ] && STATUS="restart"
    echo "|---------------------------------------------------|"
    [ ! -z "$HOSTNAME" ] && v="${HOSTNAME}${WHITESPACE}" && echo "|    Host: ${v:0:40} |"
    [ ! -z "$NODE_ID" ]  && v="${NODE_ID}${WHITESPACE}"  && echo "| Node Id: ${v:0:40} |"
    [ "$STATUS" != "exited" ] && \
    echo "|  Status: $STATUS ($(echo $STARTED_AT | head -c 19))"
    [ "$STATUS" == "exited" ] && \
    echo "|  Status: $STATUS ($(echo $FINISHED_AT | head -c 19))"
    [ "$HEALTH" != "null" ] && [ ! -z "$HEALTH" ] && \
    echo "|  Health: $HEALTH"

                                      echo "|---------------------------------------------------|"
    [ "${EXISTS,,}" == "true" ]    && echo "| [I] | Try INSPECT container                       |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}i"
    [ "${EXISTS,,}" == "true" ]    && echo "| [L] | Show container LOGS                         |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}l"
    [ "${EXISTS,,}" == "true" ]    && echo "| [H] | Show HEALTHCHECK logs                       |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}l"
    [ "${EXISTS,,}" == "true" ]    && echo "| [D] | DUMP all container logs                     |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}d"
    [ "${EXISTS,,}" == "true" ]    && echo "| [R] | RESTART container                           |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}r"
    [ "$STATUS" == "exited" ]      && echo "| [S] | START container                             |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s"
    [ "$STATUS" == "running" ]     && echo "| [S] | STOP container                              |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s"
    [ "$STATUS" == "running" ]     && echo "| [P] | PAUSE container                             |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p"
    [ "$STATUS" == "paused" ]      && echo "| [P] | Un-PAUSE container                          |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p"
    [ "${EXISTS,,}" == "true" ] && echo -e "| [X] | Exit ______________________________________ |\e[0m"

    read -s -n 1 -t 6 OPTION || continue
    [ -z "$OPTION" ] && continue
    [[ "${ALLOWED_OPTIONS,,}" != *"$OPTION"* ]] && continue

    if [ "${OPTION,,}" != "i" ] && [ "${OPTION,,}" != "l" ] && [ "${OPTION,,}" != "x" ] && [[ $OPTION != ?(-)+([0-9]) ]] ; then
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
        READ_HEAD=true
        SHOW_ALL=false
        while : ; do
            clear
            echo "INFO: Attempting to display $NAME container log..."
            TMP_DUMP=$CONTAINER_DUMP/tmp.log && rm -f $TMP_DUMP && touch $TMP_DUMP
            docker logs --details --timestamps $ID > $TMP_DUMP || echo "WARNING: Failed to dump $NAME container logs"
            MAX=$(cat $TMP_DUMP | wc -l)
            [ $LOG_LINES -gt $MAX ] && LOG_LINES=$MAX
            echo -e "\e[36;1mINFO: Found $LINES_MAX log lines, printing $LOG_LINES...\e[0m"
            TMP_LOG_LINES=$LOG_LINES && [ "${SHOW_ALL,,}" == "true" ] && TMP_LOG_LINES=10000
            [ "${READ_HEAD,,}" == "true" ] && tac $TMP_DUMP | head -n $TMP_LOG_LINES && echo -e "\e[36;1mINFO: Printed LAST $TMP_LOG_LINES lines\e[0m"
            [ "${READ_HEAD,,}" != "true" ] && cat $TMP_DUMP | head -n $TMP_LOG_LINES && echo -e "\e[36;1mINFO: Printed FIRST $TMP_LOG_LINES lines\e[0m"
            ACCEPT="" && while [ "${ACCEPT,,}" != "a" ] && [ "${ACCEPT,,}" != "s" ] && [ "${ACCEPT,,}" != "m" ] && [ "${ACCEPT,,}" != "l" ] && [ "${ACCEPT,,}" != "c" ] && [ "${ACCEPT,,}" != "r" ] ; do echo -en "\e[36;1mShow [A]ll, [M]ore, [L]ess, [R]efresh, [S]wap or [C]lose: \e[0m\c" && read  -d'' -s -n1 ACCEPT && echo "" ; done
            [ "${ACCEPT,,}" == "a" ] && SHOW_ALL="true"
            [ "${ACCEPT,,}" == "c" ] && echo -e "\nINFO: Closing log file...\n" && sleep 1 && break
            [ "${ACCEPT,,}" == "r" ] && continue
            [ "${ACCEPT,,}" == "m" ] && SHOW_ALL="false" && LOG_LINES=$(($LOG_LINES + 10))
            [ "${ACCEPT,,}" == "l" ] && SHOW_ALL="false" && [ $LOG_LINES -gt 5 ] && LOG_LINES=$(($LOG_LINES - 5))
            if [ "${ACCEPT,,}" == "s" ] ; then
                if [ "${READ_HEAD,,}" == "true" ] ; then
                    READ_HEAD="false"
                else
                    READ_HEAD="true"
                fi
            fi
        done
        OPTION=""
        EXECUTED="true"
    elif [ "${OPTION,,}" == "h" ] ; then
        LOG_LINES=5
        READ_HEAD=true
        SHOW_ALL=false
        while : ; do
            clear
            echo "INFO: Attempting to display $NAME container healthcheck logs..."
            TMP_DUMP=$CONTAINER_DUMP/tmp.log && rm -f $TMP_DUMP && touch $TMP_DUMP
            docker exec -i $ID cat /self/logs/latest_block_height.txt > $TMP_DUMP || echo "WARNING: Failed to dump $NAME container healthcheck logs"
            MAX=$(cat $TMP_DUMP | wc -l)
            [ $LOG_LINES -gt $MAX ] && LOG_LINES=$MAX
            echo -e "\e[36;1mINFO: Found $LINES_MAX log lines, printing $LOG_LINES...\e[0m"
            TMP_LOG_LINES=$LOG_LINES && [ "${SHOW_ALL,,}" == "true" ] && TMP_LOG_LINES=10000
            [ "${READ_HEAD,,}" == "true" ] && tac $TMP_DUMP | head -n $TMP_LOG_LINES && echo -e "\e[36;1mINFO: Printed LAST $TMP_LOG_LINES lines\e[0m"
            [ "${READ_HEAD,,}" != "true" ] && cat $TMP_DUMP | head -n $TMP_LOG_LINES && echo -e "\e[36;1mINFO: Printed FIRST $TMP_LOG_LINES lines\e[0m"
            ACCEPT="" && while [ "${ACCEPT,,}" != "a" ] && [ "${ACCEPT,,}" != "s" ] && [ "${ACCEPT,,}" != "m" ] && [ "${ACCEPT,,}" != "l" ] && [ "${ACCEPT,,}" != "c" ] && [ "${ACCEPT,,}" != "r" ] ; do echo -en "\e[36;1mShow [A]ll, [M]ore, [L]ess, [R]efresh, [S]wap or [C]lose: \e[0m\c" && read  -d'' -s -n1 ACCEPT && echo "" ; done
            [ "${ACCEPT,,}" == "a" ] && SHOW_ALL="true"
            [ "${ACCEPT,,}" == "c" ] && echo -e "\nINFO: Closing log file...\n" && sleep 1 && break
            [ "${ACCEPT,,}" == "r" ] && continue
            [ "${ACCEPT,,}" == "m" ] && SHOW_ALL="false" && LOG_LINES=$(($LOG_LINES + 10))
            [ "${ACCEPT,,}" == "l" ] && SHOW_ALL="false" && [ $LOG_LINES -gt 5 ] && LOG_LINES=$(($LOG_LINES - 5))
            if [ "${ACCEPT,,}" == "s" ] ; then
                if [ "${READ_HEAD,,}" == "true" ] ; then
                    READ_HEAD="false"
                else
                    READ_HEAD="true"
                fi
            fi
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

    [ "${LOADING,,}" == "true" ] && rm -fv $SCAN_DONE # trigger re-scan
    
    if [ "${EXECUTED,,}" == "true" ] && [ ! -z $OPTION ] ; then
        echo -en "\e[31;1mINFO: Option ($OPTION) was executed, press any key to continue...\e[0m" && read -n 1 -s && echo ""
    fi
done

echo "INFO: Contianer Manager Stopped"
