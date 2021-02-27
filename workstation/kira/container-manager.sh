#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/container-manager.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NAME=$1
COMMON_PATH="$DOCKER_COMMON/$NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"
START_LOGS="$COMMON_LOGS/start.log"

set +x
echo "INFO: Launching KIRA Container Manager..."

cd $KIRA_HOME
SCAN_DIR="$KIRA_HOME/kirascan"
SCAN_DONE="$SCAN_DIR/done"
CONTAINERS_SCAN_PATH="$SCAN_DIR/containers"
NETWORKS_SCAN_PATH="$SCAN_DIR/networks"
VALADDR_SCAN_PATH="$SCAN_DIR/valaddr"
VALSTATUS_SCAN_PATH="$SCAN_DIR/valstatus"
CONTAINER_STATUS="$SCAN_DIR/status/$NAME"
CONTAINER_DUMP="$KIRA_DUMP/kira/${NAME,,}"
WHITESPACE="                                                          "

SNAP_STATUS="$KIRA_SNAP/status"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_LATEST="$SNAP_STATUS/latest"

TMP_DIR="/tmp/kira-cnt-stats" # performance counters directory
LIP_PATH="$TMP_DIR/lip-$NAME"
KADDR_PATH="$TMP_DIR/kira-addr-$NAME" # kira address

echo "INFO: Cleanup, getting container manager ready..."

mkdir -p "$TMP_DIR" "$COMMON_LOGS" "$CONTAINER_DUMP"
rm -fv "$LIP_PATH" "$KADDR_PATH"
touch $LIP_PATH $KADDR_PATH

VALADDR=""
VALSTATUS=""
HOSTNAME=""
KIRA_NODE_BLOCK=""
LOADING="true"
while : ; do
    START_TIME="$(date -u +%s)"
    NETWORKS=$(cat $NETWORKS_SCAN_PATH 2> /dev/null || echo "")
    LIP=$(cat $LIP_PATH 2> /dev/null || echo "")
    KADDR=$(cat $KADDR_PATH 2> /dev/null || echo "")
    
    if [ "${NAME,,}" == "validator" ] ; then
        VALADDR=$(cat $VALADDR_SCAN_PATH 2> /dev/null || echo "")
        [ ! -z "$VALADDR" ] && VALSTATUS=$(cat $VALSTATUS_SCAN_PATH 2> /dev/null | jq -rc '.status' 2> /dev/null || echo "") || VALSTATUS=""
    fi

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

    if [ "${NAME,,}" == "interx" ] || [ "${NAME,,}" == "validator" ] || [ "${NAME,,}" == "sentry" ] || [ "${NAME,,}" == "priv_sentry" ] || [ "${NAME,,}" == "snapshot" ] ; then
        SEKAID_STATUS=$(cat "${CONTAINER_STATUS}.sekaid.status" 2> /dev/null | jq -r '.' 2>/dev/null || echo "")
        if [ "${NAME,,}" != "interx" ] ; then 
            KIRA_NODE_ID=$(echo "$SEKAID_STATUS" 2> /dev/null | jq -r '.NodeInfo.id' 2> /dev/null || echo "")
            ( [ -z "$KIRA_NODE_ID" ] || [ "${KIRA_NODE_ID,,}" == "null" ] ) && KIRA_NODE_ID=$(echo "$SEKAID_STATUS" 2> /dev/null | jq -r '.node_info.id' 2> /dev/null || echo "")
        fi
        KIRA_NODE_CATCHING_UP=$(echo "$SEKAID_STATUS" 2> /dev/null | jq -r '.SyncInfo.catching_up' 2> /dev/null || echo "")
        ( [ -z "$KIRA_NODE_CATCHING_UP" ] || [ "${KIRA_NODE_CATCHING_UP,,}" == "null" ] ) && KIRA_NODE_CATCHING_UP=$(echo "$SEKAID_STATUS" 2> /dev/null | jq -r '.sync_info.catching_up' 2> /dev/null || echo "")
        [ "${KIRA_NODE_CATCHING_UP,,}" != "true" ] && KIRA_NODE_CATCHING_UP="false"
        KIRA_NODE_BLOCK=$(echo "$SEKAID_STATUS" 2> /dev/null | jq -r '.SyncInfo.latest_block_height' 2> /dev/null || echo "0")
        ( [ -z "$KIRA_NODE_BLOCK" ] || [ "${KIRA_NODE_BLOCK,,}" == "null" ] ) && KIRA_NODE_BLOCK=$(echo "$SEKAID_STATUS" 2> /dev/null | jq -r '.sync_info.latest_block_height' 2> /dev/null || echo "0")
        [[ ! $KIRA_NODE_BLOCK =~ ^[0-9]+$ ]] && KIRA_NODE_BLOCK="0"
    fi

    printf "\033c"
    
    echo -e "\e[36;1m---------------------------------------------------------"
    echo "|            KIRA CONTAINER MANAGER v0.0.10             |"
    echo "|---------------- $(date '+%d/%m/%Y %H:%M:%S') ------------------|"

    if [ "${LOADING,,}" == "true" ] || [ ! -f "$CONTAINER_STATUS" ] ; then
        echo -e "|\e[0m\e[31;1m      PLEASE WAIT, LOADING CONTAINER STATUS ...        \e[36;1m|"
        while [ ! -f $SCAN_DONE ] || [ ! -f "$CONTAINER_STATUS" ] ; do
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
        printf "\033c"
        echo "WARNING: Container $NAME no longer exists, aborting container manager..."
        sleep 2
        break
    fi

    NAME_TMP="${NAME}${WHITESPACE}"
        echo "|     Name: ${NAME_TMP:0:43} : $(echo $ID | head -c 4)...$(echo $ID | tail -c 5)"

    if [ ! -z "$REPO" ] ; then
        VTMP=$(echo "$REPO" | sed -E 's/^\s*.*:\/\///g')
        VTMP="${VTMP}${WHITESPACE}"
        echo "|     Repo: ${VTMP:0:43} : $BRANCH"
    fi

    if [ "${NAME,,}" == "validator" ] && [ ! -z "$VALADDR" ]  ; then
        VALADDR_TMP="${VALADDR}${WHITESPACE}"
        echo "| Val.ADDR: ${VALADDR_TMP:0:43} : $VALSTATUS"
    elif [ "${NAME,,}" == "interx" ] && [ ! -z "$KADDR" ] ; then
        KADDR_TMP="${KADDR}${WHITESPACE}"
        echo "|   Faucet: ${KADDR_TMP:0:43} |"
    elif [ "${NAME,,}" == "snapshot" ] && [ -f "$SNAP_LATEST" ] ; then
        LAST_SNAP_FILE="$(cat $SNAP_LATEST)${WHITESPACE}"
        LAST_SNAP_PROGRESS="$(cat $SNAP_PROGRESS 2> /dev/null || echo "") %"
        [ -f "$SNAP_DONE" ] && LAST_SNAP_PROGRESS="done"
        echo "|     Snap: ${LAST_SNAP_FILE:0:43} : $LAST_SNAP_PROGRESS"
        echo "| Snap Dir: ${KIRA_SNAP}"
    fi

    if [ "${EXISTS,,}" == "true" ] ; then # container exists
        if [ ! -z "$PORTS" ] && [ "${PORTS,,}" != "null" ] ; then  
            for port in $(echo $PORTS | sed "s/,/ /g" | xargs) ; do
                port_tmp="${port}${WHITESPACE}"
                port_tmp=$(echo "$port_tmp" | grep -oP "^0.0.0.0:\K.*" || echo "$port_tmp")
                echo "| Port Map: ${port_tmp:0:43} |"
            done
        fi
        i=-1 ; for net in $NETWORKS ; do i=$((i+1))
            TMP_IP="IP_${NAME}_${net}" && TMP_IP="${!TMP_IP}"
            if [ ! -z "$TMP_IP" ] && [ "${TMP_IP,,}" != "null" ] ; then
                IP_TMP="${TMP_IP} ($net) ${WHITESPACE}"
                echo "| Local IP: ${IP_TMP:0:43} |"
            fi
        done
    fi

    ALLOWED_OPTIONS="x"
    [ "${RESTARTING,,}" == "true" ] && STATUS="restart"
    echo "|-------------------------------------------------------|"
    [ ! -z "$HOSTNAME" ] && v="${HOSTNAME}${WHITESPACE}"           && echo "|     Host: ${v:0:43} |"
    [ ! -z "$KIRA_NODE_ID" ]  && v="${KIRA_NODE_ID}${WHITESPACE}"  && echo "|  Node Id: ${v:0:43} |"
    if [ ! -z "$KIRA_NODE_BLOCK" ] ; then
        TMP_VAR="${KIRA_NODE_BLOCK}${WHITESPACE}"
        [ "${KIRA_NODE_CATCHING_UP,,}" == "true" ] && TMP_VAR="$KIRA_NODE_BLOCK (catching up) ${WHITESPACE}"
        echo "|    Block: ${TMP_VAR:0:43} |"
    fi
    [ "$STATUS" != "exited" ] && \
    echo "|   Status: $STATUS ($(echo $STARTED_AT | head -c 19))"
    [ "$STATUS" == "exited" ] && \
    echo "|   Status: $STATUS ($(echo $FINISHED_AT | head -c 19))"
    [ "$HEALTH" != "null" ] && [ ! -z "$HEALTH" ] && \
    echo "|   Health: $HEALTH"

                                      echo "|-------------------------------------------------------|"
    [ "${EXISTS,,}" == "true" ]    && echo "| [I] | Try INSPECT container                           |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}i"
    [ "${EXISTS,,}" == "true" ]    && echo "| [R] | RESTART container                               |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}r"
    [ "$STATUS" == "exited" ]      && echo "| [S] | START container                                 |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s"
    [ "$STATUS" == "running" ]     && echo "| [S] | STOP container                                  |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s"
    [ "$STATUS" == "running" ]     && echo "| [P] | PAUSE container                                 |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p"
    [ "$STATUS" == "paused" ]      && echo "| [P] | Un-PAUSE container                              |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p"
    [ -f "$HALT_FILE" ]            && echo "| [K] | Un-HALT (revive) all processes                  |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}k"
    [ ! -f "$HALT_FILE" ]          && echo "| [K] | KILL (halt) all processes                       |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}k"
                                      echo "|-------------------------------------------------------|"
    [ "${EXISTS,,}" == "true" ]    && echo "| [L] | Show container LOGS                             |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}l"
    [ "${EXISTS,,}" == "true" ]    && echo "| [H] | Show HEALTHCHECK logs                           |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}h"
    [ "${EXISTS,,}" == "true" ]    && echo "| [D] | DUMP all container logs                         |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}d"
    [ "${EXISTS,,}" == "true" ] && echo -e "| [X] | Exit __________________________________________ |\e[0m"

    read -s -n 1 -t 6 OPTION || continue
    [ -z "$OPTION" ] && continue
    [[ "${ALLOWED_OPTIONS,,}" != *"$OPTION"* ]] && continue

    if [ "${OPTION,,}" != "i" ] && [ "${OPTION,,}" != "l" ] && [ "${OPTION,,}" != "h" ] && [ "${OPTION,,}" != "x" ] && [[ $OPTION != ?(-)+([0-9]) ]] ; then
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
            ACCEPT="" && while [ "${ACCEPT,,}" != "y" ] && [ "${ACCEPT,,}" != "n" ] ; do echo -en "\e[36;1mPress [Y]es to halt all processes, reboot & retry or [N]o to cancel: \e[0m\c" && read  -d'' -s -n1 ACCEPT && echo "" ; done
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
        
        [ -f "$HALT_FILE" ] && echo "INFO: Applications running within your container were halted, you will have to choose Un-HALT option to start them again!"
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
    elif [ "${OPTION,,}" == "k" ] ; then
        if [ -f "$HALT_FILE" ] ; then
            echo "INFO: Removing halt file"
            rm -fv $HALT_FILE
        else
            echo "INFO: Creating halt file"
            touch $HALT_FILE
        fi
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
        rm -fv $HALT_FILE
        $KIRA_SCRIPTS/container-start.sh $NAME
        LOADING="true"
        EXECUTED="true"
    elif [ "${OPTION,,}" == "p" ] && [ "$STATUS" == "running" ] ; then
        echo "INFO: Pausing container..."
        rm -fv $HALT_FILE
        $KIRA_SCRIPTS/container-pause.sh $NAME
        LOADING="true"
        EXECUTED="true"
    elif [ "${OPTION,,}" == "p" ] && [ "$STATUS" == "paused" ] ; then
        echo "INFO: UnPausing container..."
        $KIRA_SCRIPTS/container-unpause.sh $NAME
        LOADING="true"
        EXECUTED="true"
    elif [ "${OPTION,,}" == "l" ] ; then
        LOG_LINES=10
        READ_HEAD=true
        SHOW_ALL=false
        TMP_DUMP=$CONTAINER_DUMP/tmp.log
        while : ; do
            printf "\033c"
            echo "INFO: Please wait, reading $NAME ($ID) container log..."
            rm -f $TMP_DUMP && touch $TMP_DUMP

            if [ ! -f "$START_LOGS" ] ; then
                docker logs --details --timestamps $ID > $TMP_DUMP 2> /dev/null || echo "WARNING: Failed to dump $NAME container logs"
            else
                cat $START_LOGS > $TMP_DUMP 2> /dev/null || echo "WARNING: Failed to read $NAME container logs"
            fi

            LINES_MAX=$(cat $TMP_DUMP 2> /dev/null | wc -l 2> /dev/null || echo "0")
            ( [ $LOG_LINES -gt $LINES_MAX ] || [ "${SHOW_ALL,,}" == "true" ] ) && LOG_LINES=$LINES_MAX
            [ $LOG_LINES -gt 10000 ] && LOG_LINES=10000
            [ $LOG_LINES -lt 10 ] && LOG_LINES=10
            echo -e "\e[36;1mINFO: Found $LINES_MAX log lines, printing $LOG_LINES...\e[0m"
            [ "${READ_HEAD,,}" == "true" ] && tac $TMP_DUMP | head -n $LOG_LINES && echo -e "\e[36;1mINFO: Printed LAST $LOG_LINES lines\e[0m"
            [ "${READ_HEAD,,}" != "true" ] && cat $TMP_DUMP | head -n $LOG_LINES && echo -e "\e[36;1mINFO: Printed FIRST $LOG_LINES lines\e[0m"

            ACCEPT="." && while ! [[ "${ACCEPT,,}" =~ ^(a|m|l|r|s|c|d)$ ]] ; do echoNErr "Show [A]ll, [M]ore, [L]ess, [R]efresh, [D]elete [S]wap or [C]lose: " && read  -d'' -s -n1 ACCEPT && echo "" ; done

            [ "${ACCEPT,,}" == "a" ] && SHOW_ALL="true"
            [ "${ACCEPT,,}" == "c" ] && echo -e "\nINFO: Closing log file...\n" && sleep 1 && break
            if [ "${ACCEPT,,}" == "d" ] ; then
                rm -fv "$START_LOGS"
                echo "" > $(docker inspect --format='{{.LogPath}}' $ID) || echo "INFO: Failed to delete docker logs"
                SHOW_ALL="false"
                LOG_LINES=10
                continue
            fi
            [ "${ACCEPT,,}" == "r" ] && continue
            [ "${ACCEPT,,}" == "m" ] && SHOW_ALL="false" && LOG_LINES=$(($LOG_LINES + 10))
            [ "${ACCEPT,,}" == "l" ] && SHOW_ALL="false" && [ $LOG_LINES -gt 5 ] && LOG_LINES=$(($LOG_LINES - 10))
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
        LOG_LINES=10
        READ_HEAD=true
        SHOW_ALL=false
        TMP_DUMP=$CONTAINER_DUMP/tmp.log
        while : ; do
            printf "\033c"
            echo "INFO: Please wait, reading $NAME ($ID) container healthcheck logs..."
            rm -f $TMP_DUMP && touch $TMP_DUMP 

            docker inspect --format "{{json .State.Health }}" "$ID" | jq '.Log[-1].Output' | xargs | sed 's/\\n/\n/g' > $TMP_DUMP || echo "WARNING: Failed to dump $NAME container healthcheck logs"

            LINES_MAX=$(cat $TMP_DUMP 2> /dev/null | wc -l 2> /dev/null || echo "0")
            [ $LOG_LINES -gt $LINES_MAX ] && LOG_LINES=$LINES_MAX
            [ $LOG_LINES -gt 10000 ] && LOG_LINES=10000
            [ $LOG_LINES -lt 10 ] && LOG_LINES=10
            echo -e "\e[36;1mINFO: Found $LINES_MAX log lines, printing $LOG_LINES...\e[0m"
            TMP_LOG_LINES=$LOG_LINES && [ "${SHOW_ALL,,}" == "true" ] && TMP_LOG_LINES=10000
            [ "${READ_HEAD,,}" == "true" ] && tac $TMP_DUMP | head -n $TMP_LOG_LINES && echo -e "\e[36;1mINFO: Printed LAST $TMP_LOG_LINES lines\e[0m"
            [ "${READ_HEAD,,}" != "true" ] && cat $TMP_DUMP | head -n $TMP_LOG_LINES && echo -e "\e[36;1mINFO: Printed FIRST $TMP_LOG_LINES lines\e[0m"
            ACCEPT="." && while ! [[ "${ACCEPT,,}" =~ ^(a|m|l|r|s|c)$ ]] ; do echoNErr "Show [A]ll, [M]ore, [L]ess, [R]efresh, [S]wap or [C]lose: " && read  -d'' -s -n1 ACCEPT && echo "" ; done
            [ "${ACCEPT,,}" == "a" ] && SHOW_ALL="true"
            [ "${ACCEPT,,}" == "c" ] && echo -e "\nINFO: Closing log file...\n" && sleep 1 && break
            [ "${ACCEPT,,}" == "r" ] && continue
            [ "${ACCEPT,,}" == "m" ] && SHOW_ALL="false" && LOG_LINES=$(($LOG_LINES + 10))
            [ "${ACCEPT,,}" == "l" ] && SHOW_ALL="false" && [ $LOG_LINES -gt 5 ] && LOG_LINES=$(($LOG_LINES - 10))
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

echo "INFO: Container Manager Stopped"
