#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/container-manager.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# $KIRA_MANAGER/kira/container-manager.sh --name=validator
set +x

# Force console colour to be black and text gray
tput setab 0
tput setaf 7

getArgs "$1" 

echoInfo "INFO: Launching KIRA Container Manager..."

COMMON_PATH="$DOCKER_COMMON/$name"
GLOBAL_COMMON="$COMMON_PATH/kiraglob"
COMMON_LOGS="$COMMON_PATH/logs"
START_LOGS="$COMMON_LOGS/start.log"
HEALTH_LOGS="$COMMON_LOGS/health.log"
CONTAINER_STATUS="$KIRA_SCAN/status/$name"
CONTAINER_DUMP="$KIRA_DUMP/${name}"

VALIDATOR_ADDR=""
VALINFO=""
HOSTNAME=""
KIRA_NODE_BLOCK=""

cd "$(globGet KIRA_HOME)"
mkdir -p  "$COMMON_LOGS" "$CONTAINER_DUMP"

while : ; do

    SCAN_DONE=$(globGet IS_SCAN_DONE)
    declare -l SNAPSHOT_EXECUTE=$(globGet SNAPSHOT_EXECUTE)
    declare -l SNAPSHOT_TARGET=$(globGet SNAPSHOT_TARGET)
    KIRA_DOCKER_NETWORK=$(globGet KIRA_DOCKER_NETWORK)
    
    [ "$name" == "validator" ] && VALIDATOR_ADDR=$(globGet VALIDATOR_ADDR)

    if [[ "$name" =~ ^(interx|validator|sentry|seed)$ ]] ; then
        SEKAID_STATUS_FILE=$(globFile "${name}_SEKAID_STATUS")
        if [ "$name" != "interx" ] ; then 
            KIRA_NODE_ID=$(jsonQuickParse "id" $SEKAID_STATUS_FILE 2> /dev/null | awk '{print $1;}' 2> /dev/null || echo -n "")
            (! $(isNodeId "$KIRA_NODE_ID")) && KIRA_NODE_ID=""
        fi
        declare -l KIRA_NODE_CATCHING_UP=$(jsonQuickParse "catching_up" $SEKAID_STATUS_FILE 2>/dev/null || echo -n "")
        [ "$KIRA_NODE_CATCHING_UP" != "true" ] && KIRA_NODE_CATCHING_UP="false"
        KIRA_NODE_BLOCK=$(jsonQuickParse "latest_block_height" $SEKAID_STATUS_FILE 2> /dev/null || echo "0")
        (! $(isNaturalNumber "$KIRA_NODE_BLOCK")) && KIRA_NODE_BLOCK="0"
    fi

    ##########################################################
    echoInfo "LOADING CONTAINER STATISTICS..."
    ##########################################################

    if [[ "$name" =~ ^(interx|validator|sentry|seed)$ ]] ; then
        STATUS_FILE=$(globFile "${name}_SEKAID_STATUS")
    elif [[ "$name" =~ ^(interx)$ ]] ; then
        STATUS_FILE=$(globFile "${name}_INTERX_STATUS")
    else
        STATUS_FILE=""
    fi

    if (! $(isFileEmpty "$STATUS_FILE")) ; then
        NODE_ID=$(jsonQuickParse "id" $STATUS_FILE 2> /dev/null || echo -n "")

        CATCHING_UP=$(toLower "$(jsonQuickParse "catching_up" $STATUS_FILE 2>/dev/null || echo -n "")")
        [ "$CATCHING_UP" != "true" ] && CATCHING_UP="false"

        NODE_BLOCK=$(jsonQuickParse "latest_block_height" $STATUS_FILE 2> /dev/null || echo "0")
        (! $(isNaturalNumber "$NODE_BLOCK")) && NODE_BLOCK="0"
    else
        NODE_ID=""
        NODE_BLOCK=""
        CATCHING_UP=""
    fi

    CONTAINER_EXISTS=$(globGet "${name}_EXISTS")
    CONTAINER_PORTS=$(globGet "${name}_PORTS")
    CONTAINER_ID=$(globGet "${name}_ID")
    CONTAINER_STATUS="$(globGet "${name}_STATUS")"
    CONTAINER_HEALTH="$(globGet "${name}_HEALTH")"
    CONTAINER_HOSTNAME=$(globGet "${name}_HOSTNAME")
    CONTAINER_IP=$(globGet "${name}_IP_${KIRA_DOCKER_NETWORK}")

    PROCESSES_HALTED=$(globGet HALT_TASK "$GLOBAL_COMMON")
    PRIVATE_MODE=$(globGet PRIVATE_MODE "$GLOBAL_COMMON")
    EXTERNAL_STATUS=$(toLower "$(globGet EXTERNAL_STATUS "$GLOBAL_COMMON")")
    RUNTIME_VERSION=$(globGet RUNTIME_VERSION "$GLOBAL_COMMON")
    EXTERNAL_ADDRESS=$(globGet EXTERNAL_ADDRESS "$GLOBAL_COMMON" | grep --color=never -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}:[0-9]{1,5}\b' 2> /dev/null || echo "")
    LATEST_BLOCK=$(globGet LATEST_BLOCK_HEIGHT "$GLOBAL_COMMON_RO")

    NOW_TIME="$(date -u +%s)"
    RESTART_TIME=$(globGet RESTART_TIME "$GLOBAL_COMMON")
    (! $(isNaturalNumber "$RESTART_TIME")) && RESTART_TIME="$NOW_TIME"
    UPTIME=$(prettyTimeSlim $(($(date -u +%s) - $RESTART_TIME)))

    CONTAINER_PORTS_MAP=""
    if (! $(isNullOrEmpty "$CONTAINER_PORTS")) ; then  
        for port in $(echo $CONTAINER_PORTS | sed "s/,/ /g" | xargs) ; do
            port_tmp=$(echo "$port" | grep -oP "^0.0.0.0:\K.*" || echo "$port")
            [[ $port_tmp == *":::"* ]] && continue
            map=$(strSplitTakeN / 0 "$port_tmp")

            proto=$(strSplitTakeN / 1 "$port_tmp")
            [ "$proto" != "tcp" ] && continue
            CONTAINER_PORTS_MAP="${CONTAINER_PORTS_MAP}${map}, "
        done
    fi
    CONTAINER_PORTS_MAP=$(strFirstN "$CONTAINER_PORTS_MAP" $(($(strLength "$CONTAINER_PORTS_MAP") - 2)))

    colNID="whi"
    colBloc="whi"
    colLBlo="whi"
    colCID="whi"
    colCSta="whi"
    colCHel="whi"
    colCHos="whi"
    colCLIP="whi"
    colExSt="whi"
    colExAd="whi"
    colRunt="whi"

    (! $(isNodeId "$NODE_ID")) && NODE_ID="???" && colNID="bla"
    (! $(isBoolean "$CATCHING_UP")) && CATCHING_UP="???"
    (! $(isNaturalNumber "$NODE_BLOCK")) && NODE_BLOCK="???" && colBloc="bla"
    (! $(isNaturalNumber "$LATEST_BLOCK")) && LATEST_BLOCK="???" && colLBlo="bla"
    ($(isNullOrWhitespaces "$CONTAINER_ID")) && CONTAINER_ID="???" && colCID="bla"
    ($(isNullOrWhitespaces "$CONTAINER_STATUS")) && CONTAINER_STATUS="???" && colCSta="bla"
    ($(isNullOrWhitespaces "$CONTAINER_HEALTH")) && CONTAINER_HEALTH="???" && colCHel="bla"
    ($(isNullOrWhitespaces "$CONTAINER_HOSTNAME")) && CONTAINER_HOSTNAME="???" && colCHos="bla"
    ($(isNullOrWhitespaces "$CONTAINER_IP")) && CONTAINER_IP="???" && colCLIP="bla"
    ($(isNullOrWhitespaces "$EXTERNAL_STATUS")) && EXTERNAL_STATUS="???" && colExSt="bla"
    ($(isNullOrWhitespaces "$EXTERNAL_ADDRESS")) && EXTERNAL_ADDRESS="???" && colExAd="bla"
    (! $(isVersion "$RUNTIME_VERSION")) && RUNTIME_VERSION="???" && colRunt="bla"

    [ "$CONTAINER_STATUS" != "running" ] && EXTERNAL_STATUS="offilne"
    [ "$EXTERNAL_STATUS" == "offline" ] && colExSt="red"
    [[ "$CONTAINER_STATUS" =~ ^(created|restarting|"setting up"|"backing up"|halted)$ ]] && colCSta="yel"
    [[ "$CONTAINER_STATUS" =~ ^(exited|dead)$ ]] && colCSta="red"
    [[ "$CONTAINER_HEALTH" =~ ^(starting)$ ]] && colCHel="yel"
    [[ "$CONTAINER_HEALTH" =~ ^(unhealthy|none|unknown)$ ]] && colCHel="red"

    SHOW_VALIDATOR_STATS="false"
    VALINFO_SCAN_PATH="$KIRA_SCAN/valinfo"
    NETPROPS_SCAN_PATH="$KIRA_SCAN/netprops"
    if [ "$name" == "validator" ] ; then
        ##########################################################
        echoInfo "LOADING VALIDATOR STATISTICS..."
        ##########################################################

        NODE_ADDR=$(globGet VALIDATOR_ADDR)

        VTOP=$(jsonQuickParse "top" $VALINFO_SCAN_PATH 2> /dev/null || echo -n "")
        VSTREAK=$(jsonQuickParse "streak" $VALINFO_SCAN_PATH 2> /dev/null || echo -n "")
        VSTATUS=$(jsonQuickParse "status" $VALINFO_SCAN_PATH 2> /dev/null || echo -n "")
        VMISSCHANCE=$(jsonQuickParse "mischance" $VALINFO_SCAN_PATH 2> /dev/null || echo -n "")
        VMISSMAX=$(jsonQuickParse "mischance_confidence" $NETPROPS_SCAN_PATH 2> /dev/null || echo -n "")
        VPRODUCED=$(jsonQuickParse "produced_blocks_counter" $VALINFO_SCAN_PATH 2> /dev/null || echo -n "")
        VMISSED=$(jsonQuickParse "missed_blocks_counter" $VALINFO_SCAN_PATH 2> /dev/null || echo -n "")

        (! $(isKiraAddress "$NODE_ADDR")) && NODE_ADDR="???" && colNAdr="bla"
        (! $(isNaturalNumber "$VTOP")) && VTOP="???" && colVTop="bla"
        (! $(isNaturalNumber "$VSTREAK")) && VSTREAK="???" && colVStr="bla"
        ($(isNullOrWhitespaces "$VSTATUS")) && VSTATUS="???" && colVSta="bla"
        (! $(isNaturalNumber "$VMISSCHANCE")) && VMISSCHANCE="???" && colVMCh="bla"
        (! $(isNaturalNumber "$VMISSMAX")) && VMISSMAX="???" && colVMCh="bla"
        VMISSCHANCE="${VMISSCHANCE}/${VMISSMAX}"
        (! $(isNaturalNumber "$VPRODUCED")) && VPRODUCED="???" && colVPro="bla"
        (! $(isNaturalNumber "$VMISSED")) && VMISSED="???" && colVMis="bla"

        SHOW_VALIDATOR_STATS="true"
    elif [ "$name" == "interx" ] ; then
        ##########################################################
        echoInfo "LOADING INTERX STATISTICS..."
        ##########################################################

        FAUCET_ADDR_PATH=$(globFile FAUCET_ADDR)
        touch "${FAUCET_ADDR_PATH}.pid" && if ! kill -0 $(tryCat "${FAUCET_ADDR_PATH}.pid") 2> /dev/null ; then
            if [ "${name}" == "interx" ] ; then
                echo $(curl interx.local:$(globGet CUSTOM_INTERX_PORT)/api/faucet 2>/dev/null 2> /dev/null | jsonQuickParse "address" 2> /dev/null  || echo -n "") > "$FAUCET_ADDR_PATH" &
                PID2="$!" && echo "$PID2" > "${FAUCET_ADDR_PATH}.pid"
            fi
        fi

        FAUCET_ADDR=$(globGet FAUCET_ADDR)
        (! $(isKiraAddress "$FAUCET_ADDR")) && FAUCET_ADDR="???" && colFAdr="bla"
    fi
    
    ##########################################################
    echoInfo "FORMATTING NAVIGATION FIELDS..."
    ##########################################################

    selI="i"
    selM="d"
    selK="k"

    selR="r"
    selP="p"
    selS="t"
    
    selL="l"
    selH="h"
    selX="x"

    colI="whi"
    colM="whi"
    colK="whi"

    colR="whi"
    colP="whi"
    colS="whi"
    
    colL="whi"
    colH="whi"
    colX="whi"

    OPTION_RESTART=$(strFixL " [R] Restart Container" 25)
      OPTION_PAUSE=$(strFixL " [P] Pause Container" 25)
      OPTION_START=$(strFixL " [T] Terminate Container" 26)

    OPTION_INSPECT=$(strFixL " [I] Inspect Container" 25)
    if [ "$PRIVATE_MODE" == "true" ] ; then
        [ "$EXTERNAL_STATUS" == "online" ] && EXTERNAL_STATUS="LOCAL NET."
        OPTION_PRIVACY=$(strFixL " [D] Disable Priv. Mode" 25)
    else
        [ "$EXTERNAL_STATUS" == "online" ] && EXTERNAL_STATUS="PUBLIC NET"
        selM="e" && OPTION_PRIVACY=$(strFixL " [E] Enable Privacy Mode" 25)
    fi
    OPTION_KILL=$(strFixL " [K] Kill App Process " 26)

    OPTION_LOGS=$(strFixL " [L] Show Logs" 25)
      OPTION_HEALTH=$(strFixL " [H] Show Health Logs" 25)
      OPTION_EXIT=$(strFixL " [X] Exit" 26)

    if [ "$CONTAINER_EXISTS" != "true" ] || [ "$SCAN_DONE" != "true" ] || [ "$CONTAINER_STATUS" != "running" ] ; then
        selI=""
        selM=""
        selK=""

        selR=""
        selP=""
        selS=""
        
        selL=""
        selH=""

        colI="bla"
        colM="bla"
        colK="bla"

        colR="bla"
        colP="bla"
        colS="bla"

        colL="bla"
        colH="bla"
    fi

    ##########################################################
    echoInfo "FORMATTING DATA FIELDS..."
    ##########################################################

    
    if [ "$SCAN_DONE" != "true" ] ; then
        # CONTAINER STATISTICS
        CONTAINER_ID="loading..." && colCID="bla"
        NODE_ID="loading..." && colNID="bla"
        NODE_BLOCK="loading..." && colBloc="bla"
        CATCHING_UP="loading..."
        CONTAINER_STATUS="loading..." && colCSta="bla"
        CONTAINER_HEALTH="loading..." && colCHel="bla"
        EXTERNAL_STATUS="loading..."&& colExSt="bla"
        RUNTIME_VERSION="loading..." && colRunt="bla"
        CONTAINER_IP="loading..." && colCLIP="bla"
        CONTAINER_HOSTNAME="loading..." && colCHos="bla"
        EXTERNAL_ADDRESS="loading..." && colExAd="bla"
        # VALIDATOR STATISTICS
        VTOP="loading..."
        VSTREAK="loading..."
        VSTATUS="loading..."
        VMISSCHANCE="loading..."
        VPRODUCED="loading..."
        VMISSED="loading..."
        # INTERX STATISTICS
        FAUCET_ADDR="loading..."
    else
        if [ "$CONTAINER_STATUS" == "paused" ] ; then
            selP="u" && colP="whi"
            selL="l" && colL="whi"
            OPTION_PAUSE=$(strFixL " [U] Unpause Container" 25)
        elif [ "$CONTAINER_STATUS" == "halted" ] ; then
            selI="i" && colI="whi"
            selK="w" && colK="yel"
            selR="r" && colR="whi"
            selP="p" && colP="whi"
            selS="t" && colS="whi"
            selL="l" && colL="whi"
            selH="h" && colH="whi"
            OPTION_KILL=$(strFixL " [W] Wake Up App Process " 26)
        elif [[ "$CONTAINER_STATUS" =~ ^("setting up"|"backing up")$ ]] ; then
            selI="i" && colI="whi"
            selL="l" && colL="whi"
            selH="h" && colH="whi"
        elif [ "$CONTAINER_STATUS" == "exited" ] ; then
            selS="s" && colS="red"
            selL="l" && colL="whi"
            OPTION_START=$(strFixL " [S] Start Container" 26)
        fi

        CONTAINER_IP="$CONTAINER_IP ($KIRA_DOCKER_NETWORK)"
    fi

    P_NODE_BLOCK=$(strFixC "$NODE_BLOCK" 12)
    P_LATEST_BLOCK=$(strFixC "$LATEST_BLOCK" 12)
    # ensure lowercase characters when printing out "loading..." info
    [ "$SCAN_DONE" == "true" ] && P_CONTAINER_STATUS=$(strFixC "$(toUpper "$CONTAINER_STATUS")" 12) || P_CONTAINER_STATUS=$(strFixC "loading..." 12) 
    [ "$SCAN_DONE" == "true" ] && P_CONTAINER_HEALTH=$(strFixC "$(toUpper "$CONTAINER_HEALTH")" 12) || P_CONTAINER_HEALTH=$(strFixC "loading..." 12) 
    [ "$SCAN_DONE" == "true" ] && P_EXTERNAL_STATUS=$(strFixC "$(toUpper "$EXTERNAL_STATUS")" 12)   || P_EXTERNAL_STATUS=$(strFixC "loading..." 12) 
    P_RUNTIME_VERSION=$(strFixC "$RUNTIME_VERSION" 13)

    P_VTOP=$(strFixC "$VTOP" 12)
    P_VSTREAK=$(strFixC "$VSTREAK" 12)
    P_VSTATUS=$(strFixC "$VSTATUS" 12)
    P_VMISSCHANCE=$(strFixC "$VMISSCHANCE" 12)
    P_VPRODUCED=$(strFixC "$VPRODUCED" 12)
    P_VMISSED=$(strFixC "$VMISSED" 13)

    P_CONTAINER_IP=$(strFixC " $CONTAINER_IP " 25)
    P_CONTAINER_HOSTNAME=$(strFixC " $CONTAINER_HOSTNAME " 25)
    P_EXTERNAL_ADDRESS=$(strFixC " $EXTERNAL_ADDRESS " 26)

    P_CONTAINER_ID=$(strFixC " $CONTAINER_ID " 25)
    P_NODE_ID=$(strFixC " $NODE_ID " 25)
    P_UPTIME=$(strFixC " $UPTIME " 26)

    set +x && printf "\033c" && clear
    echoC ";whi" " =============================================================================="
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "KIRA $(toUpper $name) CONTAINER MANAGER $KIRA_SETUP_VER" 78)")|"
    echoC ";whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
    echoC ";whi" "| NODE BLOCK | LAST BLOCK | CON.STATUS |   HEALTH   | VISIBILITY |   RUNTIME   |"
    echoC ";whi" "|$(echoC "res;$colBloc" "$P_NODE_BLOCK")|$(echoC "res;$colLBlo" "$P_LATEST_BLOCK")|$(echoC "res;$colCSta" "$P_CONTAINER_STATUS")|$(echoC "res;$colCHel" "$P_CONTAINER_HEALTH")|$(echoC "res;$colExSt" "$P_EXTERNAL_STATUS")|$(echoC "res;$colRunt" "$P_RUNTIME_VERSION")|"
    [ "$SHOW_VALIDATOR_STATS" == "true" ] && \
    echoC ";whi" "|    TOP     |   STREAK   | VAL.STATUS | MISSCHANCE | B.PRODUCED | BLOC.MISSED |" && \
    echoC ";whi" "|$(echoC "res;$colVTop" "$P_VTOP")|$(echoC "res;$colVStr" "$P_VSTREAK")|$(echoC "res;$colVSta" "$P_VSTATUS")|$(echoC "res;$colVMCh" "$P_VMISSCHANCE")|$(echoC "res;$colVPro" "$P_VPRODUCED")|$(echoC "res;$colVMis" "$P_VMISSED")|"

    echoC ";whi" "|------- LOCAL IP --------|------ LOCAL HOST -------|---- EXTERNAL ADDRESS ----|"
    echoC ";whi" "|$(echoC "res;$colCLIP" "$P_CONTAINER_IP")|$(echoC "res;$colCHos" "$P_CONTAINER_HOSTNAME")|$(echoC "res;$colExAd" "$P_EXTERNAL_ADDRESS")|"
    echoC ";whi" "|      CONTAINER ID       |        NODE ID          |          UPTIME          |"
    echoC ";whi" "|$(echoC "res;$colCID" "$P_CONTAINER_ID")|$(echoC "res;$colNID" "$P_NODE_ID")|$(echoC "res;whi" "$P_UPTIME")|"

    echoC ";whi" "|$(echoC "res;bla" "$(strFixC "-" 78 "." "-")")|"

    (! $(isNullOrEmpty "$CONTAINER_PORTS_MAP")) && \
    echoC ";whi" "|$(strFixC "TCP Ports Mapping" 25 ): $(strFixL "$CONTAINER_PORTS_MAP" 50) |"
    [ "$name" == "validator" ] && \
          echoC ";whi" "|$(strFixC "Validator Address" 25 ): $(echoC "res;$colNAdr" "$(strFixL $NODE_ADDR 50 )") |"
    [ "$name" == "interx" ] && \
             echoC ";whi" "|$(strFixC "Faucet Address" 25 ): $(echoC "res;$colFAdr" "$(strFixL $FAUCET_ADDR 50 )") |"

    echoC ";whi" "|$(echoC "res;bla" "$(strFixC "-" 78 "." "-")")|"
    echoC ";whi" "|$(echoC "res;$colI" "$OPTION_INSPECT")|$(echoC "res;$colM" "$OPTION_PRIVACY")|$(echoC "res;$colK" "$OPTION_KILL")|"
    echoC ";whi" "|$(echoC "res;$colR" "$OPTION_RESTART")|$(echoC "res;$colP" "$OPTION_PAUSE")|$(echoC "res;$colS" "$OPTION_START")|"
    echoC ";whi" "|$(echoC "res;$colL" "$OPTION_LOGS")|$(echoC "res;$colH" "$OPTION_HEALTH")|$(echoC "res;$colX" "$OPTION_EXIT")|"
    echoNC ";whi" " ------------------------------------------------------------------------------"

    if [ "$SCAN_DONE" != "true" ] ; then
        timeout=10
    else
        case $CONTAINER_STATUS in
        "running") timeout=300 ;;
        "halted") timeout=300 ;;
        "exited") timeout=300 ;;
        "dead") timeout=300 ;;
        "starting") timeout=15 ;;
        "setting up") timeout=15 ;;
        "backing up") timeout=30 ;;
        *) timeout=15 ;;
        esac

        case $CONTAINER_HEALTH in
        "starting") timeout=60 ;;
        *) ;;
        esac
    fi

    pressToContinue --timeout=$timeout --cursor=false "$selR" "$selP" "$selS" "$selI" "$selM" "$selK" "$selL" "$selH" "$selX"  && VSEL=$(toLower "$(globGet OPTION)") || VSEL="r"

    clear
    [ "$VSEL" != "r" ] && echoInfo "INFO: Option '$VSEL' was selected, processing request..."
    
    FORCE_RESCAN="false"
    EXECUTED="false"

    if [ "$VSEL" == "i" ] ; then
        echo "INFO: Entering container $name ($CONTAINER_ID)..."
        echo "INFO: To exit the container type 'exit'"
        FAILURE="false"
        # NOTE: It might be considered to instead of ..it $CONTAINER_ID bash use ...it $CONTAINER_ID sh, this might be required for base images that do not have bash (e.g. docker registry)
        docker exec -it $CONTAINER_ID bash || FAILURE="true"
        
        if [ "$FAILURE" == "true" ] ; then
            echoNC "bli;whi" "\nPress [Y]es to halt all processes, reboot & retry or [N]o to cancel: " && pressToContinue y n && YNO=$(toLower "$(globGet OPTION)")
            [ "$YNO" != "y" ] && echo -e "\nWARINIG: Operation was cancelled\n" && sleep 1 && continue
            echo "WARNING: Failed to inspect $name container"
            echo "INFO: Attempting to start & prevent node from restarting..."
            $KIRA_MANAGER/kira/container-pkill.sh --name="$name" --await="true" --task="restart" --unhalt="false"
            echo "INFO: Waiting for container to start..."
            sleep 3
            echo "INFO: Entering container $name ($CONTAINER_ID)..."
            echo "INFO: To exit the container type 'exit'"
            docker exec -it $CONTAINER_ID bash || echo "WARNING: Failed to inspect $name container"
        fi
        
        [ "$IS_HALTING" == "true" ] && echo "INFO: Applications running within your container were halted, you will have to choose Un-HALT option to start them again!"
        VSEL="" && EXECUTED="true"
    elif [ "$VSEL" == "r" ] ; then
        echo "INFO: Restarting container..."
        [ "$PROCESSES_HALTED" == "true" ] && unhalt="false" || unhalt="true"
        $KIRA_MANAGER/kira/container-pkill.sh --name="$name" --await="true" --task="restart" --unhalt="$unhalt"
        FORCE_RESCAN="true" && EXECUTED="true"
    elif [ "$VSEL" == "w" ] ; then
        echo "INFO: Removing halt file"
        $KIRA_MANAGER/kira/container-pkill.sh --name="$name" --await="true" --task="restart" --unhalt="true"
        FORCE_RESCAN="true" && EXECUTED="true"
    elif [ "$VSEL" == "k" ] ; then
        echo "INFO: Creating halt file"
        $KIRA_MANAGER/kira/container-pkill.sh --name="$name" --await="true" --task="restart" --unhalt="false"
        FORCE_RESCAN="true" && EXECUTED="true"
    elif [ "$VSEL" == "d" ] ; then
        echoInfo "INFO: Disabling private mode..."
        globSet PRIVATE_MODE "false" "$GLOBAL_COMMON"
        globSet PRIVATE_MODE "false"
        echoInfo "INFO: Restarting container..."
        [ "$PROCESSES_HALTED" == "true" ] && unhalt="false" || unhalt="true"
        $KIRA_MANAGER/kira/container-pkill.sh --name="$name" --await="true" --task="restart" --unhalt="$unhalt"
        FORCE_RESCAN="true" && EXECUTED="true"
    elif [ "$VSEL" == "e" ] ; then
        echoInfo "INFO: Enabling private mode..."
        globSet PRIVATE_MODE "true" "$GLOBAL_COMMON"
        globSet PRIVATE_MODE "true"
        echoInfo "INFO: Restarting container..."
        [ "$PROCESSES_HALTED" == "true" ] && unhalt="false" || unhalt="true"
        $KIRA_MANAGER/kira/container-pkill.sh --name="$name" --await="true" --task="restart" --unhalt="$unhalt"
        FORCE_RESCAN="true" && EXECUTED="true"
    elif [ "$VSEL" == "t" ] ; then
        echo "INFO: Stopping container..."
        $KIRA_MANAGER/kira/container-pkill.sh --name="$name" --await="true" --task="stop"
        FORCE_RESCAN="true" && EXECUTED="true"
    elif [ "$VSEL" == "s" ] ; then
        echo "INFO: Starting container..."
        $KIRA_MANAGER/kira/container-pkill.sh --name="$name" --await="true" --task="start" --unhalt="true"
        FORCE_RESCAN="true" && EXECUTED="true"
    elif [ "$VSEL" == "p" ] ; then
        echo "INFO: Pausing container..."
        globSet HALT_TASK "false" $GLOBAL_COMMON
        $KIRA_COMMON/container-pause.sh $name
        FORCE_RESCAN="true" && EXECUTED="true"
    elif [ "$VSEL" == "u" ] ; then
        echo "INFO: UnPausing container..."
        $KIRA_COMMON/container-unpause.sh $name
        FORCE_RESCAN="true" && EXECUTED="true"
    elif [ "$VSEL" == "l" ] ; then
        LOG_LINES=10
        READ_HEAD=true
        SHOW_ALL=false
        TMP_DUMP=$CONTAINER_DUMP/logs.txt.tmp
        while : ; do
            printf "\033c"
            echoInfo "INFO: Please wait, reading $name ($CONTAINER_ID) container log..."
            rm -f $TMP_DUMP && touch $TMP_DUMP
            timeout 10 docker logs --details --timestamps $CONTAINER_ID > $TMP_DUMP 2> /dev/null || echoWarn "WARNING: Failed to dump $name container logs"

            if (! $(isFileEmpty $TMP_DUMP)) ; then
                cat $START_LOGS > $TMP_DUMP 2> /dev/null || echoWarn "WARNING: Failed to read $name container logs"
            fi

            if [ "$SNAPSHOT_TARGET" == "${name}" ] && [ "$SNAPSHOT_EXECUTE" == "true" ] ; then
                echoWarn "WARNING: Snapshot is ongoing, output logs will be included"
                echo "--- SNAPSHOT LOG START ---" >> $TMP_DUMP
                cat "$KIRA_SCAN/snapshot.log" >> $TMP_DUMP 2> /dev/null || echoWarn "WARNING: Failed to read $name container snapshot logs" >> $TMP_DUMP
                echo "--- SNAPSHOT LOG END ---" >> $TMP_DUMP
            fi

            LINES_MAX=$(cat $TMP_DUMP 2> /dev/null | wc -l 2> /dev/null || echo "0")
            ( [[ $LOG_LINES -gt $LINES_MAX ]] || [ "$SHOW_ALL" == "true" ] ) && LOG_LINES=$LINES_MAX
            [[ $LOG_LINES -gt 10000 ]] && LOG_LINES=10000
            [[ $LOG_LINES -lt 10 ]] && LOG_LINES=10
            echo -e "\e[36;1mINFO: Found $LINES_MAX log lines, printing $LOG_LINES...\e[0m"
            [ "$READ_HEAD" == "true" ] && tac $TMP_DUMP | head -n $LOG_LINES && echo -e "\e[36;1mINFO: Printed LAST $LOG_LINES lines\e[0m"
            [ "$READ_HEAD" != "true" ] && cat $TMP_DUMP | head -n $LOG_LINES && echo -e "\e[36;1mINFO: Printed FIRST $LOG_LINES lines\e[0m"

            echoNErr "Show [A]ll, [M]ore, [L]ess, [R]efresh, [D]elete, [S]wap, [F]ollow or [C]lose: " && pressToContinue a m l r d s f c && OPTION=$(toLower "$(globGet OPTION)")

            if [ "$OPTION" == "f" ] ; then
                echoInfo "INFO: Attempting to follow $name logs..."
                cmdFollow "docker logs --follow --details --timestamps $CONTAINER_ID" || echoErr "ERROR: Failed to follow $name logs"
                echoNC "bli;whi" "\nPress any key to continue..." && pressToContinue
            fi

            [ "$OPTION" == "a" ] && SHOW_ALL="true"
            [ "$OPTION" == "c" ] && echo -e "\nINFO: Closing log file...\n" && sleep 1 && break
            if [ "$OPTION" == "d" ] ; then
                rm -fv "$START_LOGS"
                echo -n "" > $(docker inspect --format='{{.LogPath}}' $CONTAINER_ID) || echoErr "ERROR: Failed to delete docker logs"
                SHOW_ALL="false"
                LOG_LINES=10
                continue
            fi
            [ "$OPTION" == "r" ] && continue
            [ "$OPTION" == "m" ] && SHOW_ALL="false" && LOG_LINES=$(($LOG_LINES + 10))
            [ "$OPTION" == "l" ] && SHOW_ALL="false" && [[ $LOG_LINES -gt 5 ]] && LOG_LINES=$(($LOG_LINES - 10))
            if [ "$OPTION" == "s" ] ; then
                if [ "$READ_HEAD" == "true" ] ; then
                    READ_HEAD="false"
                else
                    READ_HEAD="true"
                fi
            fi
        done
        VSEL=""
        EXECUTED="true"
    elif [ "$VSEL" == "h" ] ; then
        LOG_LINES=10
        READ_HEAD=true
        SHOW_ALL=false
        TMP_DUMP=$CONTAINER_DUMP/healthcheck.txt.tmp
        while : ; do
            printf "\033c"
            echo "INFO: Please wait, reading $name ($CONTAINER_ID) container healthcheck logs..."
            rm -f $TMP_DUMP && touch $TMP_DUMP 

            echo -e $(docker inspect --format "{{json .State.Health }}" "$CONTAINER_ID" 2> /dev/null | jq '.Log[-1].Output' 2> /dev/null) > $TMP_DUMP || echo "" > $TMP_DUMP
            
            if [ -f "$HEALTH_LOGS" ]; then
                echo "--- HEALTH LOGS ---" >> $TMP_DUMP 
                cat $HEALTH_LOGS >> $TMP_DUMP 2> /dev/null || echo "WARNING: Failed to read $name container logs"
            fi

            LINES_MAX=$(tryCat $TMP_DUMP | wc -l 2> /dev/null || echo "0")
            [[ $LOG_LINES -gt $LINES_MAX ]] && LOG_LINES=$LINES_MAX
            [[ $LOG_LINES -gt 10000 ]] && LOG_LINES=10000
            [[ $LOG_LINES -lt 10 ]] && LOG_LINES=10
            echoInfo "INFO: Found $LINES_MAX log lines, printing $LOG_LINES..."
            TMP_LOG_LINES=$LOG_LINES 
            [ "$SHOW_ALL" == "true" ] && TMP_LOG_LINES=10000
            [ "$READ_HEAD" == "true" ] && tac $TMP_DUMP | head -n $TMP_LOG_LINES && echoInfo "INFO: Printed LAST $TMP_LOG_LINES lines"
            [ "$READ_HEAD" != "true" ] && cat $TMP_DUMP | head -n $TMP_LOG_LINES && echoInfo "INFO: Printed FIRST $TMP_LOG_LINES lines"

            echoNErr "Show [A]ll, [M]ore, [L]ess, [R]efresh, [D]elete, [S]wap or [C]lose: " && pressToContinue a m l r d s c && OPTION=$(toLower "$(globGet OPTION)")

            [ "$OPTION" == "a" ] && SHOW_ALL="true"
            [ "$OPTION" == "c" ] && echoInfo "INFO: Closing log file..." && sleep 1 && break
            if [ "$OPTION" == "d" ] ; then
                rm -fv "$HEALTH_LOGS"
                SHOW_ALL="false"
                LOG_LINES=10
                continue
            fi
            [ "$OPTION" == "r" ] && continue
            [ "$OPTION" == "m" ] && SHOW_ALL="false" && LOG_LINES=$(($LOG_LINES + 10))
            [ "$OPTION" == "l" ] && SHOW_ALL="false" && [[ $LOG_LINES -gt 5 ]] && LOG_LINES=$(($LOG_LINES - 10))
            if [ "$OPTION" == "s" ] ; then
                if [ "$READ_HEAD" == "true" ] ; then
                    READ_HEAD="false"
                else
                    READ_HEAD="true"
                fi
            fi
        done
        VSEL=""
        EXECUTED="true"
    elif [ "$VSEL" == "x" ] ; then
        echoInfo "INFO: Stopping Container Manager..."
        VSEL="" && EXECUTED="true"
        sleep 1
        break
    fi

    # trigger re-scan if requested
    [ "$FORCE_RESCAN" == "true" ] && globSet IS_SCAN_DONE "false"
    ( [ "$EXECUTED" == "true" ] && [ ! -z "$VSEL" ] ) && echoNC "bli;whi" "\nOption ($VSEL) was executed, press any key to continue..." && pressToContinue

done

echoInfo "INFO: Container Manager Stopped"
