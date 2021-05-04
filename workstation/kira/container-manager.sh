#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/container-manager.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

NAME=$1
COMMON_PATH="$DOCKER_COMMON/$NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"
EXIT_FILE="$COMMON_PATH/exit"
START_LOGS="$COMMON_LOGS/start.log"
HEALTH_LOGS="$COMMON_LOGS/health.log"

set +x
echoInfo "INFO: Launching KIRA Container Manager..."

cd $KIRA_HOME
VALINFO_SCAN_PATH="$KIRA_SCAN/valinfo"
VALADDR_SCAN_PATH="$KIRA_SCAN/valaddr"
LATEST_BLOCK_SCAN_PATH="$KIRA_SCAN/latest_block"
CONTAINER_STATUS="$KIRA_SCAN/status/$NAME"
CONTAINER_DUMP="$KIRA_DUMP/${NAME,,}"
WHITESPACE="                                                          "

SNAP_STATUS="$KIRA_SNAP/status"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_LATEST="$SNAP_STATUS/latest"
TMP_DIR="/tmp/kira-cnt-stats" # performance counters directory
KADDR_PATH="$TMP_DIR/kira-addr-$NAME" # kira address

echoInfo "INFO: Cleanup, getting container manager ready..."

mkdir -p "$TMP_DIR" "$COMMON_LOGS" "$CONTAINER_DUMP"
rm -fv "$KADDR_PATH"
touch $KADDR_PATH

VALADDR=""
VALINFO=""
HOSTNAME=""
KIRA_NODE_BLOCK=""
LOADING="true"
while : ; do
    START_TIME="$(date -u +%s)"
    NETWORKS=$(globGet "NETWORKS")
    KADDR=$(tryCat $KADDR_PATH "")
    LATEST_BLOCK=$(tryCat $LATEST_BLOCK_SCAN_PATH "0")
    [ "${NAME,,}" == "validator" ] && VALADDR=$(tryCat $VALADDR_SCAN_PATH "")

    touch "${KADDR_PATH}.pid" && if ! kill -0 $(tryCat "${KADDR_PATH}.pid") 2> /dev/null ; then
        if [ "${NAME,,}" == "interx" ] ; then
            echo $(curl $KIRA_INTERX_DNS:$KIRA_INTERX_PORT/api/faucet 2>/dev/null 2> /dev/null | jsonQuickParse "address" 2> /dev/null  || echo -n "") > "$KADDR_PATH" &
            PID2="$!" && echo "$PID2" > "${KADDR_PATH}.pid"
        fi
    fi

    if [[ "${NAME,,}" =~ ^(interx|validator|sentry|priv_sentry|snapshot|seed)$ ]] ; then
        SEKAID_STATUS_FILE="${CONTAINER_STATUS}.sekaid.status"
        if [ "${NAME,,}" != "interx" ] ; then 
            KIRA_NODE_ID=$(jsonQuickParse "id" $SEKAID_STATUS_FILE 2> /dev/null | awk '{print $1;}' 2> /dev/null || echo -n "")
            (! $(isNodeId "$KIRA_NODE_ID")) && KIRA_NODE_ID=""
        fi
        KIRA_NODE_CATCHING_UP=$(jsonQuickParse "catching_up" $SEKAID_STATUS_FILE 2>/dev/null || echo -n "")
        [ "${KIRA_NODE_CATCHING_UP,,}" != "true" ] && KIRA_NODE_CATCHING_UP="false"
        KIRA_NODE_BLOCK=$(jsonQuickParse "latest_block_height" $SEKAID_STATUS_FILE 2> /dev/null || echo "0")
        (! $(isNaturalNumber "$KIRA_NODE_BLOCK")) && KIRA_NODE_BLOCK="0"
    fi

    printf "\033c"
    
    echo -e "\e[36;1m---------------------------------------------------------"
    echo "|            KIRA CONTAINER MANAGER $KIRA_SETUP_VER            |"
    echo "|---------------- $(date '+%d/%m/%Y %H:%M:%S') ------------------|"

    if [ "${LOADING,,}" == "true" ] || [ ! -f "$CONTAINER_STATUS" ] ; then
        echo -e "|\e[0m\e[31;1m      PLEASE WAIT, LOADING CONTAINER STATUS ...        \e[36;1m|"
        while [ "$(globGet SCAN_DONE)" != "true" ] || [ ! -f "$CONTAINER_STATUS" ] ; do
            sleep 1
        done
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

    if [ "${EXISTS,,}" != "true" ] ; then
        printf "\033c"
        echo "WARNING: Container $NAME no longer exists, aborting container manager..."
        sleep 2
        break
    fi

    NAME_TMP="${NAME} $(echo $ID | head -c 8)...$(echo $ID | tail -c 9)${WHITESPACE}"
        echo "| Con.Name: ${NAME_TMP:0:43} |"

    if [ ! -z "$REPO" ] ; then
        VTMP=$(echo "$REPO" | sed -E 's/^\s*.*:\/\///g')
        VTMP="${VTMP}${WHITESPACE}"
        echo "|     Repo: ${VTMP:0:43} : $BRANCH"
    fi

    [ ! -z "$HOSTNAME" ] && v="${HOSTNAME}${WHITESPACE}" && \
        echo "|     Host: ${v:0:43} |"

    i=-1 ; for net in $NETWORKS ; do i=$((i+1))
        TMP_IP="IP_${NAME}_${net}" && TMP_IP="${!TMP_IP}"
        if (! $(isNullOrEmpty "$TMP_IP")) ; then
            IP_TMP="${TMP_IP} ($net) ${WHITESPACE}"
            echo "| Local IP: ${IP_TMP:0:43} |"
        fi
    done

    if (! $(isNullOrEmpty "$PORTS")) ; then  
        for port in $(echo $PORTS | sed "s/,/ /g" | xargs) ; do
            port_tmp="${port}${WHITESPACE}"
            port_tmp=$(echo "$port_tmp" | grep -oP "^0.0.0.0:\K.*" || echo "$port_tmp")
            echo "| Port Map: ${port_tmp:0:43} |"
        done
    fi

    [ "${RESTARTING,,}" == "true" ] && STATUS="restart"
    [ "$STATUS" != "exited" ] && TMPVAR="$STATUS ($(echo $STARTED_AT | head -c 19))${WHITESPACE}" && \
    echo "|   Status: ${TMPVAR:0:43} |"
    [ "$STATUS" == "exited" ] && TMPVAR="$STATUS ($(echo $FINISHED_AT | head -c 19))${WHITESPACE}" && \
    echo "|   Status: ${TMPVAR:0:43} |"
    (! $(isNullOrEmpty "$HEALTH")) && TMPVAR="${HEALTH}${WHITESPACE}" && \
    echo "|   Health: ${TMPVAR:0:43} |"
    echo "|-------------------------------------------------------|"

    if [ "${NAME,,}" == "validator" ] && [ ! -z "$VALADDR" ] ; then
        VSTATUS="" && VTOP="" && VRANK="" && VSTREAK="" && VMISSED="" && VPRODUCED=""
        if (! $(isFileEmpty "$VALINFO_SCAN_PATH")) ; then
            VSTATUS=$(jsonQuickParse "status" $VALINFO_SCAN_PATH 2> /dev/null || echo -n "")
            VTOP=$(jsonQuickParse "top" $VALINFO_SCAN_PATH 2> /dev/null || echo -n "???") && VTOP="${VTOP}${WHITESPACE}"
            VRANK=$(jsonQuickParse "rank" $VALINFO_SCAN_PATH 2> /dev/null || echo "???") && VRANK="${VRANK}${WHITESPACE}"
            VSTREAK=$(jsonQuickParse "streak" $VALINFO_SCAN_PATH 2> /dev/null || echo "???") && VSTREAK="${VSTREAK}${WHITESPACE}"
            VMISSCHANCE=$(jsonQuickParse "mischance" $VALINFO_SCAN_PATH 2> /dev/null || echo "???") && VMISSCHANCE="${VMISSCHANCE}${WHITESPACE}"
            VMISS_CONF=$(jsonQuickParse "mischance_confidence" $VALINFO_SCAN_PATH 2> /dev/null || echo "???") && VMISS_CONF="${VMISS_CONF}${WHITESPACE}"
            VMISSED=$(jsonQuickParse "missed_blocks_counter" $VALINFO_SCAN_PATH 2> /dev/null || echo "???") && VMISSED="${VMISSED}${WHITESPACE}"
            VPRODUCED=$(jsonQuickParse "produced_blocks_counter" $VALINFO_SCAN_PATH 2> /dev/null || echo "???") && VPRODUCED="${VPRODUCED}${WHITESPACE}"
            echo "|   Streak: ${VSTREAK:0:12}Rank: ${VRANK:0:10}Mischance: ${VMISSCHANCE:0:5}: TOP: ${VTOP:0:6}"  
            echo "| Produced: ${VPRODUCED:0:10}Missed: ${VMISSED:0:10}Miss.Conf: ${VMISS_CONF:0:5}|"  
        fi
        VALADDR_TMP="${VALADDR}${WHITESPACE}"
        echo "| Val.ADDR: ${VALADDR_TMP:0:43} : $VSTATUS"        
    elif [ "${NAME,,}" == "interx" ] && [ ! -z "$KADDR" ] ; then
        KADDR_TMP="${KADDR}${WHITESPACE}"
        echo "|   Faucet: ${KADDR_TMP:0:43} |"
    elif [ "${NAME,,}" == "snapshot" ] && [ -f "$SNAP_LATEST" ] ; then
        LAST_SNAP_FILE="$(tryCat $SNAP_LATEST)${WHITESPACE}"
        LAST_SNAP_PROGRESS="$(tryCat $SNAP_PROGRESS 2> /dev/null || echo -n "") %"
        [ -f "$SNAP_DONE" ] && LAST_SNAP_PROGRESS="done"
        echo "|     Snap: ${LAST_SNAP_FILE:0:43} : $LAST_SNAP_PROGRESS"
        echo "| Snap Dir: ${KIRA_SNAP}"
    fi

    if [ "$STATUS" != "exited" ] && [[ "${NAME,,}" =~ ^(sentry|seed|priv_sentry)$ ]] ; then
        EX_ADDR=$(tryCat "$COMMON_PATH/external_address" 2> /dev/null || echo -n "")
        EX_ADDR_STATUS=$(tryCat "$COMMON_PATH/external_address_status" 2> /dev/null || echo "OFFLINE")
        EX_ADDR="${EX_ADDR} (P2P) ${WHITESPACE}"
        [ "${EX_ADDR_STATUS,,}" == "online" ] && EX_ADDR_STATUS="\e[32;1m$EX_ADDR_STATUS\e[36;1m" || EX_ADDR_STATUS="\e[31;1m$EX_ADDR_STATUS\e[36;1m"
        echo -e "| Ext.Addr: ${EX_ADDR:0:43} : $EX_ADDR_STATUS"
    fi
    
    [ ! -z "$KIRA_NODE_ID" ] && v="${KIRA_NODE_ID}${WHITESPACE}"  && echo "|  Node Id: ${v:0:43} |"
    if [ ! -z "$KIRA_NODE_BLOCK" ] ; then
        KIRA_NODE_BLOCK_TMP="${KIRA_NODE_BLOCK}${WHITESPACE}"
        LATEST_BLOCK_TMP="${LATEST_BLOCK}${WHITESPACE}"
        [ "${KIRA_NODE_CATCHING_UP,,}" == "true" ] && CATCHUP_TMP="catching up" || CATCHUP_TMP=""
        echo "|    Block: ${KIRA_NODE_BLOCK_TMP:0:11} Latest: ${LATEST_BLOCK_TMP:0:23} : $CATCHUP_TMP"
    fi

    ALLOWED_OPTIONS="x"
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
            $KIRA_MANAGER/kira/container-pkill.sh "$NAME" "true" "restart" "false"
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
        $KIRA_MANAGER/kira/container-pkill.sh "$NAME" "true" "restart"
        LOADING="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "k" ] ; then
        if [ -f "$HALT_FILE" ] ; then
            echo "INFO: Removing halt file"
            $KIRA_MANAGER/kira/container-pkill.sh "$NAME" "true" "restart" "true"
        else
            echo "INFO: Creating halt file"
            $KIRA_MANAGER/kira/container-pkill.sh "$NAME" "true" "restart" "false"
        fi
        LOADING="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "s" ] && [ "$STATUS" == "running" ] ; then
        echo "INFO: Stopping container..."
        $KIRA_MANAGER/kira/container-pkill.sh "$NAME" "true" "stop"
        LOADING="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "s" ] && [ "$STATUS" != "running" ] ; then
        echo "INFO: Starting container..."
        $KIRA_MANAGER/kira/container-pkill.sh "$NAME" "true" "start"
        LOADING="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "p" ] && [ "$STATUS" == "running" ] ; then
        echo "INFO: Pausing container..."
        rm -fv $HALT_FILE
        $KIRA_SCRIPTS/container-pause.sh $NAME
        LOADING="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "p" ] && [ "$STATUS" == "paused" ] ; then
        echo "INFO: UnPausing container..."
        $KIRA_SCRIPTS/container-unpause.sh $NAME
        LOADING="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "l" ] ; then
        LOG_LINES=10
        READ_HEAD=true
        SHOW_ALL=false
        TMP_DUMP=$CONTAINER_DUMP/logs.txt.tmp
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
            ( [[ $LOG_LINES -gt $LINES_MAX ]] || [ "${SHOW_ALL,,}" == "true" ] ) && LOG_LINES=$LINES_MAX
            [[ $LOG_LINES -gt 10000 ]] && LOG_LINES=10000
            [[ $LOG_LINES -lt 10 ]] && LOG_LINES=10
            echo -e "\e[36;1mINFO: Found $LINES_MAX log lines, printing $LOG_LINES...\e[0m"
            [ "${READ_HEAD,,}" == "true" ] && tac $TMP_DUMP | head -n $LOG_LINES && echo -e "\e[36;1mINFO: Printed LAST $LOG_LINES lines\e[0m"
            [ "${READ_HEAD,,}" != "true" ] && cat $TMP_DUMP | head -n $LOG_LINES && echo -e "\e[36;1mINFO: Printed FIRST $LOG_LINES lines\e[0m"

            ACCEPT="." && while ! [[ "${ACCEPT,,}" =~ ^(a|m|l|r|s|c|d)$ ]] ; do echoNErr "Show [A]ll, [M]ore, [L]ess, [R]efresh, [D]elete [S]wap or [C]lose: " && read  -d'' -s -n1 ACCEPT && echo "" ; done

            [ "${ACCEPT,,}" == "a" ] && SHOW_ALL="true"
            [ "${ACCEPT,,}" == "c" ] && echo -e "\nINFO: Closing log file...\n" && sleep 1 && break
            if [ "${ACCEPT,,}" == "d" ] ; then
                rm -fv "$START_LOGS"
                echo -n "" > $(docker inspect --format='{{.LogPath}}' $ID) || echo "INFO: Failed to delete docker logs"
                SHOW_ALL="false"
                LOG_LINES=10
                continue
            fi
            [ "${ACCEPT,,}" == "r" ] && continue
            [ "${ACCEPT,,}" == "m" ] && SHOW_ALL="false" && LOG_LINES=$(($LOG_LINES + 10))
            [ "${ACCEPT,,}" == "l" ] && SHOW_ALL="false" && [[ $LOG_LINES -gt 5 ]] && LOG_LINES=$(($LOG_LINES - 10))
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
        TMP_DUMP=$CONTAINER_DUMP/healthcheck.txt.tmp
        while : ; do
            printf "\033c"
            echo "INFO: Please wait, reading $NAME ($ID) container healthcheck logs..."
            rm -f $TMP_DUMP && touch $TMP_DUMP 

            if [ ! -f "$HEALTH_LOGS" ] ; then
                docker inspect --format "{{json .State.Health }}" "$ID" | jq '.Log[-1].Output' | sed 's/\\n/\n/g' > $TMP_DUMP || echoWarn "WARNING: Failed to dump $NAME container healthcheck logs"
            else
                cat $HEALTH_LOGS > $TMP_DUMP 2> /dev/null || echo "WARNING: Failed to read $NAME container logs"
            fi

            LINES_MAX=$(tryCat $TMP_DUMP | wc -l 2> /dev/null || echo "0")
            [[ $LOG_LINES -gt $LINES_MAX ]] && LOG_LINES=$LINES_MAX
            [[ $LOG_LINES -gt 10000 ]] && LOG_LINES=10000
            [[ $LOG_LINES -lt 10 ]] && LOG_LINES=10
            echoInfo "INFO: Found $LINES_MAX log lines, printing $LOG_LINES..."
            TMP_LOG_LINES=$LOG_LINES && [ "${SHOW_ALL,,}" == "true" ] && TMP_LOG_LINES=10000
            [ "${READ_HEAD,,}" == "true" ] && tac $TMP_DUMP | head -n $TMP_LOG_LINES && echoInfo "INFO: Printed LAST $TMP_LOG_LINES lines"
            [ "${READ_HEAD,,}" != "true" ] && cat $TMP_DUMP | head -n $TMP_LOG_LINES && echoInfo "INFO: Printed FIRST $TMP_LOG_LINES lines"
            ACCEPT="." && while ! [[ "${ACCEPT,,}" =~ ^(a|m|l|r|s|c)$ ]] ; do echoNErr "Show [A]ll, [M]ore, [L]ess, [R]efresh, [D]elete, [S]wap or [C]lose: " && read  -d'' -s -n1 ACCEPT && echo "" ; done
            [ "${ACCEPT,,}" == "a" ] && SHOW_ALL="true"
            [ "${ACCEPT,,}" == "c" ] && echoInfo "INFO: Closing log file..." && sleep 1 && break
            if [ "${ACCEPT,,}" == "d" ] ; then
                rm -fv "$HEALTH_LOGS"
                SHOW_ALL="false"
                LOG_LINES=10
                continue
            fi
            [ "${ACCEPT,,}" == "r" ] && continue
            [ "${ACCEPT,,}" == "m" ] && SHOW_ALL="false" && LOG_LINES=$(($LOG_LINES + 10))
            [ "${ACCEPT,,}" == "l" ] && SHOW_ALL="false" && [[ $LOG_LINES -gt 5 ]] && LOG_LINES=$(($LOG_LINES - 10))
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
        echoInfo "INFO: Stopping Container Manager..."
        OPTION=""
        EXECUTED="true"
        sleep 1
        break
    fi

    # trigger re-scan if loading requested
    [ "${LOADING,,}" == "true" ] && globSet SCAN_DONE false
    [ "${EXECUTED,,}" == "true" ] && [ ! -z $OPTION ] && echoNErr "Option ($OPTION) was executed, press any key to continue..." && read -n 1 -s && echo ""
done

echoInfo "INFO: Container Manager Stopped"
