#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/kira.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
 
set +x
echoInfo "INFO: Launching KIRA Network Manager..."

if [ "${USER,,}" != root ]; then
    echoErr "ERROR: You have to run this application as root, try 'sudo -s' command first"
    exit 1
fi

$KIRA_MANAGER/kira/kira-setup-status.sh

cd $KIRA_HOME
LATEST_STATUS_SCAN_PATH="$KIRA_SCAN/latest_status"
VALSTATUS_SCAN_PATH="$KIRA_SCAN/valstatus"
VALOPERS_COMM_RO_PATH="$DOCKER_COMMON_RO/valopers"
CONSENSUS_COMM_RO_PATH="$DOCKER_COMMON_RO/consensus"
STATUS_SCAN_PATH="$KIRA_SCAN/status"
WHITESPACE="                                                          "
CONTAINERS=""
CONTAINERS_COUNT="0"
INTERX_SNAPSHOT_PATH="$INTERX_REFERENCE_DIR/snapshot.zip"

mkdir -p "$INTERX_REFERENCE_DIR"

echoInfo "INFO: Restarting network scanner..."
systemctl daemon-reload
systemctl restart kirascan || echoErr "ERROR: Failed to restart kirascan service"

globSet IS_SCAN_DONE "false"
PREVIOUS_BLOCK=0
while : ; do
    set +e && source "/etc/profile" &>/dev/null && set -e
    SNAP_STATUS="$KIRA_SNAP/status"
    SNAP_PROGRESS="$SNAP_STATUS/progress"
    SNAP_DONE="$SNAP_STATUS/done"
    SNAP_LATEST="$SNAP_STATUS/latest"
    SCAN_DONE=$(globGet IS_SCAN_DONE)
    SNAP_EXPOSE=$(globGet SNAP_EXPOSE)
    VALIDATOR_ADDR=$(globGet VALIDATOR_ADDR)
    GENESIS_SHA256=$(globGet GENESIS_SHA256)

    VALSTATUS=$(jsonQuickParse "status" $VALSTATUS_SCAN_PATH 2>/dev/null || echo -n "")
    ($(isNullOrEmpty "$VALSTATUS")) && VALSTATUS=""

    START_TIME="$(date -u +%s)"
    PROGRESS_SNAP="$(tryCat $SNAP_PROGRESS "0") %"
    SNAP_LATEST_FILE="$KIRA_SNAP/$(tryCat $SNAP_LATEST "")"
    KIRA_BLOCK=$(globGet LATEST_BLOCK)
    CONSENSUS_STOPPED="$(jsonQuickParse "consensus_stopped" $CONSENSUS_COMM_RO_PATH 2>/dev/null || echo -n "")" && ($(isNullOrEmpty "$CONSENSUS_STOPPED")) && CONSENSUS_STOPPED="???"
    
    if [ -f "$SNAP_DONE" ]; then
        PROGRESS_SNAP="done"                                                                       # show done progress
        [ -f "$SNAP_LATEST_FILE" ] && [ -f "$KIRA_SNAP_PATH" ] && KIRA_SNAP_PATH=$SNAP_LATEST_FILE # ensure latest snap is up to date
    fi

    if [ "${SCAN_DONE,,}" == "true" ]; then
        SUCCESS="true"
        ALL_CONTAINERS_PAUSED="true"
        ALL_CONTAINERS_STOPPED="true"
        ALL_CONTAINERS_HEALTHY="true"
        CATCHING_UP="false"
        VALIDATOR_RUNNING="false"
        CONTAINERS=$(globGet CONTAINERS)

        i=-1
        for name in $CONTAINERS; do
            EXISTS_TMP=$(globGet "${name}_EXISTS")

            [ "${EXISTS_TMP,,}" == "true" ] && i=$((i + 1)) || continue

            SYNCING_TMP=$(globGet "${name}_SYNCING")

            # if some other node then snapshot is syncig then infra is not ready
            [ "${name,,}" != "snapshot" ] && [ "${SYNCING_TMP,,}" == "true" ] && CATCHING_UP="true"

            STATUS_TMP=$(globGet "${name}_STATUS")
            HEALTH_TMP=$(globGet "${name}_HEALTH")
            [ "${STATUS_TMP,,}" != "running" ] && SUCCESS="false"
            [ "${STATUS_TMP,,}" != "exited" ] && ALL_CONTAINERS_STOPPED="false"
            [ "${STATUS_TMP,,}" != "paused" ] && ALL_CONTAINERS_PAUSED="false"
            [ "${name,,}" == "registry" ] && continue
            [ "${name,,}" == "snapshot" ] && continue
            [ "${HEALTH_TMP,,}" != "healthy" ] && ALL_CONTAINERS_HEALTHY="false"
            [ "${name,,}" == "validator" ] && [ "${STATUS_TMP,,}" == "running" ] && VALIDATOR_RUNNING="true"
            [ "${name,,}" == "validator" ] && [ "${STATUS_TMP,,}" != "running" ] && VALIDATOR_RUNNING="false"
        done
        CONTAINERS_COUNT=$((i + 1))
    fi

    printf "\033c"

    ALLOWED_OPTIONS="x"
    echo -e "\e[33;1m-------------------------------------------------"
    echo "|         KIRA NETWORK MANAGER $KIRA_SETUP_VER         : $INFRA_MODE mode"
    echo "|------------ $(date '+%d/%m/%Y %H:%M:%S') --------------: $DEPLOYMENT_MODE deployment"

    if [ "${SCAN_DONE,,}" == "true" ]; then
        RAM_UTIL=$(globGet RAM_UTIL) && [ -z "$RAM_UTIL" ] && RAM_UTIL="???" ; RAM_TMP="RAM: ${RAM_UTIL}${WHITESPACE}"
        CPU_UTIL=$(globGet CPU_UTIL) && [ -z "$CPU_UTIL" ] && CPU_UTIL="???" ; CPU_TMP="CPU: ${CPU_UTIL}${WHITESPACE}"
        DISK_UTIL=$(globGet DISK_UTIL) && [ -z "$DISK_UTIL" ] && DISK_UTIL="???" ; DISK_TMP="DISK: ${DISK_UTIL}${WHITESPACE}"
        echo -e "|\e[35;1m ${CPU_TMP:0:16}${RAM_TMP:0:16}${DISK_TMP:0:13} \e[33;1m: $(globGet DISK_CONS)"

        KIRA_NETWORK=$(jsonQuickParse "network" $LATEST_STATUS_SCAN_PATH 2>/dev/null || echo -n "")
        ($(isNullOrEmpty "$KIRA_NETWORK")) && KIRA_NETWORK="???"
        if (! $(isNaturalNumber "$KIRA_BLOCK")) || [ "$KIRA_BLOCK" == "0" ]; then
            KIRA_BLOCK="???"
        else
            SECONDS_PER_BLOCK="$(jsonQuickParse "average_block_time" $CONSENSUS_COMM_RO_PATH  2>/dev/null || echo -n "")" && (! $(isNumber "$SECONDS_PER_BLOCK")) && SECONDS_PER_BLOCK="???"
            ($(isNumber "$SECONDS_PER_BLOCK")) && SECONDS_PER_BLOCK=$(echo "scale=1; ( $SECONDS_PER_BLOCK / 1 ) " | bc) && KIRA_BLOCK="$KIRA_BLOCK ~${SECONDS_PER_BLOCK}s"
        fi

        KIRA_NETWORK_TMP="NETWORK: ${KIRA_NETWORK}${WHITESPACE}"
        KIRA_BLOCK_TMP="BLOCKS: ${KIRA_BLOCK}${WHITESPACE}"
        [ -z "$GENESIS_SHA256" ] && GENESIS_SHA256="????????????"
        echo -e "|\e[35;1m ${KIRA_NETWORK_TMP:0:24}${KIRA_BLOCK_TMP:0:21} \e[33;1m: $(echo "$GENESIS_SHA256" | head -c 4)...$(echo "$GENESIS_SHA256" | tail -c 5)"

        VALACTIVE="$(jsonQuickParse "active_validators" $VALOPERS_COMM_RO_PATH 2>/dev/null || echo -n "")" && ($(isNullOrEmpty "$VALACTIVE")) && VALACTIVE="???"
        VALTOTAL="$(jsonQuickParse "total_validators" $VALOPERS_COMM_RO_PATH 2>/dev/null || echo -n "")" && ($(isNullOrEmpty "$VALTOTAL")) && VALTOTAL="???"
        VALWAITING="$(jsonQuickParse "waiting_validators" $VALOPERS_COMM_RO_PATH 2>/dev/null || echo -n "")" && ($(isNullOrEmpty "$VALWAITING")) && VALWAITING="???"
        VALACTIVE="V.ACTIVE: ${VALACTIVE}${WHITESPACE}"
        VALTOTAL="V.TOTAL: ${VALTOTAL}${WHITESPACE}"
        VALWAITING="WAITING: ${VALWAITING}${WHITESPACE}"
        
        [ "$PREVIOUS_BLOCK" == "$KIRA_BLOCK" ] && [ "${CONSENSUS_STOPPED,,}" == "true" ] && echo -e "|\e[35;1m ${VALACTIVE:0:16}${VALTOTAL:0:16}${VALWAITING:0:13} \e[33;1m:\e[31;1m CONSENSUS HALTED\e[33;1m"
        [ "${CONSENSUS_STOPPED,,}" == "false" ] && echo -e "|\e[35;1m ${VALACTIVE:0:16}${VALTOTAL:0:16}${VALWAITING:0:13} \e[33;1m|"
        
        PREVIOUS_BLOCK="$KIRA_BLOCK"
    else
        KIRA_BLOCK="???"
    fi

    LOCAL_IP=$(globGet "LOCAL_IP") && PUBLIC_IP=$(globGet "PUBLIC_IP")
    LOCAL_IP="L.IP: $LOCAL_IP                                               "
    if [ "$PUBLIC_IP" == "0.0.0.0" ] || ( ! $(isDnsOrIp "$PUBLIC_IP")) ; then
        echo -e "|\e[35;1m ${LOCAL_IP:0:24}P.IP: \e[31;1mdisconnected\e[33;1m    : $IFACE $(globGet NET_PRIOR)"
    else
        PUBLIC_IP="$PUBLIC_IP                          "
        echo -e "|\e[35;1m ${LOCAL_IP:0:24}P.IP: ${PUBLIC_IP:0:15}\e[33;1m : $IFACE $(globGet NET_PRIOR)"
    fi

    if [ -f "$KIRA_SNAP_PATH" ]; then # snapshot is present
        SNAP_FILENAME="SNAPSHOT: $(basename -- "$KIRA_SNAP_PATH")${WHITESPACE}"
        [ -z "$KIRA_SNAP_SHA256" ] && KIRA_SNAP_SHA256="????????????"
        [ "${SNAP_EXPOSE,,}" == "true" ] &&
            echo -e "|\e[32;1m ${SNAP_FILENAME:0:45} \e[33;1m: $(echo $KIRA_SNAP_SHA256 | head -c 4)...$(echo $KIRA_SNAP_SHA256 | tail -c 5)" ||
            echo -e "|\e[31;1m ${SNAP_FILENAME:0:45} \e[33;1m: $(echo $KIRA_SNAP_SHA256 | head -c 4)...$(echo $KIRA_SNAP_SHA256 | tail -c 5)"
    fi

    if [ "${SCAN_DONE,,}" == "true" ]; then
        if [ ! -z "$VALIDATOR_ADDR" ]; then
            if [ "${VALSTATUS,,}" == "active" ] ; then
                echo -e "|\e[0m\e[32;1m    SUCCESS, VALIDATOR AND INFRA IS HEALTHY    \e[33;1m: $VALSTATUS"
            elif [ "${VALSTATUS,,}" == "inactive" ] ; then
                echo -e "|\e[0m\e[31;1m   VALIDATOR WAS STOPPED, ACTIVATE YOUR NODE   \e[33;1m: $VALSTATUS"
            elif [ "${VALSTATUS,,}" == "jailed" ] ; then
                echo -e "|\e[0m\e[31;1m    VALIDATOR COMMITED DOUBLE-SIGNING FAULT    \e[33;1m: $VALSTATUS"
            elif [ "${VALSTATUS,,}" == "paused" ] ; then
                echo -e "|\e[0m\e[36;1m      VALIDATOR ENTERED MAINTENANCE MODE       \e[33;1m: $VALSTATUS"
            elif [ "${VALSTATUS,,}" == "waiting" ] ; then
                echo -e "|\e[0m\e[33;1m  WHITELISTED, READY TO CLAIM VALIDATOR SEAT   \e[33;1m: $VALSTATUS"
            else
                echo -e "|\e[0m\e[31;1m    VALIDATOR NODE IS NOT PRODUCING BLOCKS     \e[33;1m: $VALSTATUS"
            fi
        fi

        if [ "${CATCHING_UP,,}" == "true" ]; then
            echo -e "|\e[0m\e[33;1m     PLEASE WAIT, NODES ARE CATCHING UP        \e[33;1m|"
        elif [[ $CONTAINERS_COUNT -lt $INFRA_CONTAINER_COUNT ]]; then
            echo -e "|\e[0m\e[31;1m ISSUES DETECTED, NOT ALL CONTAINERS LAUNCHED  \e[33;1m|"
        elif [ "${ALL_CONTAINERS_HEALTHY,,}" != "true" ]; then
            echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRASTRUCTURE IS UNHEALTHY  \e[33;1m|"
        elif [ "${SUCCESS,,}" == "true" ] && [ "${ALL_CONTAINERS_HEALTHY,,}" == "true" ]; then
            [ -z "$VALIDATOR_ADDR" ] && echo -e "|\e[0m\e[32;1m      SUCCESS, INFRASTRUCTURE IS HEALTHY       \e[33;1m|"
        else
            echo -e "|\e[0m\e[31;1m    INFRASTRUCTURE IS NOT FULLY OPERATIONAL    \e[33;1m|"
        fi
    fi

    [ "${PORTS_EXPOSURE,,}" == "enabled" ] && \
        echo -e "|\e[0m\e[31;1m   ALL PORTS ARE OPEN TO THE PUBLIC NETWORKS   \e[33;1m|"
    [ "${PORTS_EXPOSURE,,}" == "custom" ] && \
        echo -e "|\e[0m\e[32;1m      ALL PORTS USE CUSTOM CONFIGURATION       \e[33;1m|"
    [ "${PORTS_EXPOSURE,,}" == "disabled" ] && \
        echo -e "|\e[0m\e[31;1m        ACCESS TO ALL PORTS IS DISABLED        \e[33;1m|"

    if [ "${SCAN_DONE,,}" == "true" ]; then
        echo "|-----------------------------------------------| [health]"
        i=-1
        for name in $CONTAINERS; do
            i=$((i + 1))

            STATUS_TMP=$(globGet "${name}_STATUS")
            HEALTH_TMP=$(globGet "${name}_HEALTH")
            [ "${name,,}" == "snapshot" ] && [ "${STATUS_TMP,,}" == "running" ] && STATUS_TMP="$PROGRESS_SNAP"

            if [[ "${name,,}" =~ ^(validator|sentry|priv_sentry|seed|interx)$ ]] && [[ "${STATUS_TMP,,}" =~ ^(running|starting)$ ]]; then
                LATEST_BLOCK=$(globGet "${name}_BLOCK") && (! $(isNaturalNumber "$LATEST_BLOCK")) && LATEST_BLOCK=0
                CATCHING_UP=$(globGet "${name}_SYNCING") && ($(isNullOrEmpty $CATCHING_UP)) && CATCHING_UP="false"
                [ "${CATCHING_UP,,}" == "true" ] && STATUS_TMP="syncing : $LATEST_BLOCK" || STATUS_TMP="$STATUS_TMP : $LATEST_BLOCK"
            fi

            NAME_TMP="${name}${WHITESPACE}"
            STATUS_TMP="${STATUS_TMP}${WHITESPACE}"
            LABEL="| [$i] | Manage ${NAME_TMP:0:11} : ${STATUS_TMP:0:21}"
            echo "${LABEL:0:47} : $HEALTH_TMP" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}${i}"
        done
    else
        echo -e "|\e[0m\e[31;1m PLEASE WAIT, LOADING INFRASTRUCTURE STATUS... \e[33;1m|"
    fi

    echo "|-----------------------------------------------|"
    if [ "$CONTAINERS_COUNT" != "0" ] && [ "${SCAN_DONE,,}" == "true" ]; then
        [ "${ALL_CONTAINERS_PAUSED,,}" == "false" ] &&
            echo "| [P] | PAUSE All Containers                    |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p" ||
            echo "| [P] | Un-PAUSE All Containers                 |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p"
        [ "${ALL_CONTAINERS_STOPPED,,}" == "false" ] &&
            echo "| [R] | RESTART All Containers                  |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}r"
        [ "${ALL_CONTAINERS_STOPPED,,}" == "false" ] &&
            echo "| [S] | STOP All Containers                     |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s" ||
            echo "| [S] | START All Containers                    |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s"
        echo "|-----------------------------------------------|"
    fi

    if [ "${INFRA_MODE,,}" == "validator" ] || [ "${INFRA_MODE,,}" == "sentry" ] || [ "${INFRA_MODE,,}" == "seed" ] ; then
        if [ "$(globGet AUTO_BACKUP)" == "true" ]; then
            TIME_LEFT=$(timerSpan AUTO_BACKUP $(($AUTO_BACKUP_INTERVAL * 3600)))
            AUTO_BACKUP_TMP=": AUTO-SNAP ${TIME_LEFT}s${WHITESPACE}"
        else
            AUTO_BACKUP_TMP=": MANUAL-SNAP${WHITESPACE}"
        fi
        echo "| [B] | BACKUP Chain State ${AUTO_BACKUP_TMP:0:21}|" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}b"
    fi

    if [ ! -z "$KIRA_SNAP_PATH" ] && [ -f "$KIRA_SNAP_PATH" ]; then
        [ "${SNAP_EXPOSE,,}" == "false" ] &&
            echo "| [E] | EXPOSE Snapshot                         |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}e" ||
            echo "| [E] | Hide EXPOSED Snapshot                   |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}e"
    fi

    if [ "${VALIDATOR_RUNNING,,}" == "true" ] ; then
        [ "${VALSTATUS,,}" == "active" ]   && echo "| [M] | Enable MAINTENANCE Mode                 |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}m"
        [ "${VALSTATUS,,}" == "paused" ]   && echo "| [M] | Disable MAINTENANCE Mode                |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}m"
        [ "${VALSTATUS,,}" == "inactive" ] && echo "| [A] | Re-ACTIVATE Jailed Validator            |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}a"
    fi
    echo "| [D] | DUMP All Loggs                          |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}d"
    echo "| [N] | Manage NETWORKING & Firewall            |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}n"
    echo "| [I] | Re-INITALIZE Infrastructure             |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}i"
    echo -e "| [X] | Exit __________________________________ |\e[0m"

    OPTION="" && read -s -n 1 -t 15 OPTION || OPTION=""
    [ -z "$OPTION" ] && continue
    [[ "${ALLOWED_OPTIONS,,}" != *"$OPTION"* ]] && continue

    if ! [[ "${OPTION,,}" =~ ^(x|n)$ ]] && [[ $OPTION != ?(-)+([0-9]) ]]; then
        ACCEPT="" && while ! [[ "${ACCEPT,,}" =~ ^(y|n)$ ]]; do echoNErr "Press [Y]es to confirm option (${OPTION^^}) or [N]o to cancel: " && read -d'' -s -n1 ACCEPT && echo ""; done
        [ "${ACCEPT,,}" == "n" ] && echo -e "\nWARINIG: Operation was cancelled\n" && sleep 1 && continue
        echo -n ""
    fi

    if [ "${OPTION,,}" == "r" ]; then
        echoInfo "INFO: Restarting docker..."
        systemctl daemon-reload  || echoErr "ERROR: Failed to reload systemctl daemon"
        systemctl restart docker || echoErr "ERROR: Failed to restart docker service"
    fi

    FORCE_SCAN="false"
    EXECUTED="false"
    i=-1
    for name in $CONTAINERS; do
        i=$((i + 1))
        if [ "$OPTION" == "$i" ]; then
            source $KIRA_MANAGER/kira/container-manager.sh $name
            OPTION="" && EXECUTED="true" && break
        elif [ "${OPTION,,}" == "r" ]; then
            echoInfo "INFO: Re-starting $name container..."
            $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "restart"
            EXECUTED="true" && FORCE_SCAN="true"
        elif [ "${OPTION,,}" == "s" ]; then
            if [ "${ALL_CONTAINERS_STOPPED,,}" == "false" ]; then
                echoInfo "INFO: Stopping $name container..."
                $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "stop"
            else
                echoInfo "INFO: Staring $name container..."
                $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "start"
            fi
            FORCE_SCAN="true" && EXECUTED="true"
        elif [ "${OPTION,,}" == "p" ]; then
            if [ "${ALL_CONTAINERS_PAUSED,,}" == "false" ]; then
                echoInfo "INFO: Pausing $name container..."
                $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "pause"
            else
                echoInfo "INFO: UnPausing $name container..."
                $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "unpause"
            fi
            FORCE_SCAN="true" && EXECUTED="true"
        fi
    done

    if [ "${OPTION,,}" == "d" ]; then
        $KIRA_MANAGER/kira/kira-dump.sh || echoErr "ERROR: Failed logs dump"
        EXECUTED="true"
    elif [ "${OPTION,,}" == "s" ] && [ "${ALL_CONTAINERS_STOPPED,,}" != "false" ]; then
        echoInfo "INFO: Reinitalizing firewall..."
        $KIRA_MANAGER/networking.sh
    elif [ "${OPTION,,}" == "b" ]; then
        echoInfo "INFO: Backing up blockchain state..."
        $KIRA_MANAGER/kira/kira-backup.sh || echoErr "ERROR: Snapshot failed"
        FORCE_SCAN="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "n" ]; then
        echoInfo "INFO: Staring networking manager..."
        $KIRA_MANAGER/kira/kira-networking.sh || echoErr "ERROR: Network manager failed"
        EXECUTED="true" && OPTION=""
    elif [ "${OPTION,,}" == "e" ]; then
        if [ "${SNAP_EXPOSE,,}" == "false" ]; then
            echoInfo "INFO: Exposing latest snapshot '$KIRA_SNAP_PATH' via INTERX"
            globSet SNAP_EXPOSE "true"
            ln -fv "$KIRA_SNAP_PATH" "$INTERX_SNAPSHOT_PATH" && \
                echoInfo "INFO: Await few minutes and your snapshot will become available via 0.0.0.0:$KIRA_INTERX_PORT/download/snapshot.zip" || \
                echoErr "ERROR: Failed to create snapshot symlink"
        else
            echoInfo "INFO: Ensuring exposed snapshot will be removed..."
            globSet SNAP_EXPOSE "false"
            rm -fv "$INTERX_SNAPSHOT_PATH" && \
                echoInfo "INFO: Await few minutes and your snapshot will become unavailable" || \
                echoErr "ERROR: Failed to remove snapshot symlink"
        fi
        FORCE_SCAN="false" && EXECUTED="true"
    elif [ "${OPTION,,}" == "m" ]; then
        if [ "${VALSTATUS,,}" == "active" ]; then
            echoInfo "INFO: Attempting to change validator status from ACTIVE to PAUSED..."
            ( docker exec -i validator /bin/bash -c ". /etc/profile && sekaid tx customslashing pause --from validator --chain-id=\$NETWORK_NAME --keyring-backend=test --home=\$SEKAID_HOME --fees 100ukex --gas=1000000000 --yes --broadcast-mode=async --log_format=json | txAwait 180" || \
            echoErr "ERROR: Failed to confirm pause tx" ) && echoWarn "WARNINIG: Please be patient, it might take couple of minutes before your status changes in the KIRA Manager..."
            sleep 5
        elif [ "${VALSTATUS,,}" == "paused" ] ; then
            echoInfo "INFO: Attempting to change validator status from PAUSED to ACTIVE..."
            ( docker exec -i validator /bin/bash -c ". /etc/profile && sekaid tx customslashing unpause --from validator --chain-id=\$NETWORK_NAME --keyring-backend=test --home=\$SEKAID_HOME --fees 100ukex --gas=1000000000 --yes --broadcast-mode=async --log_format=json | txAwait 180" || \
            echoErr "ERROR: Failed to confirm pause tx" ) && echoWarn "WARNINIG: Please be patient, it might take couple of minutes before your status changes in the KIRA Manager..."
            sleep 5
        else
            echoWarn "WARNINIG: Unknown validator status '$VALSTATUS'"
        fi
        FORCE_SCAN="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "a" ]; then
        if [ "${VALSTATUS,,}" == "inactive" ] ; then
            echoInfo "INFO: Attempting to change validator status from INACTIVE to ACTIVE..."
            ( docker exec -i validator /bin/bash -c ". /etc/profile && sekaid tx customslashing activate --from validator --chain-id=\$NETWORK_NAME --keyring-backend=test --home=\$SEKAID_HOME --fees 1000ukex --gas=1000000000 --yes --broadcast-mode=async --log_format=json | txAwait 180" || \
            echoErr "ERROR: Failed to confirm pause tx" ) && echoWarn "WARNINIG: Please be patient, it might take couple of minutes before your status changes in the KIRA Manager..."
            sleep 5
        else
            echoWarn "WARNINIG: Unknown validator status '$VALSTATUS'"
        fi
        FORCE_SCAN="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "x" ]; then
        printf "\033c"
        echoInfo "INFO: Stopping kira network scanner..."
        rm -fv /dev/null && mknod -m 666 /dev/null c 1 3 || :
        exit 0
    fi

    # trigger re-scan if requested
    [ "${FORCE_SCAN,,}" == "true" ] && globSet IS_SCAN_DONE "false"
    [ "${EXECUTED,,}" == "true" ] && [ ! -z $OPTION ] && echoNErr "INFO: Option ($OPTION) was executed, press any key to continue..." && read -n 1 -s && echo ""

    if [ "${OPTION,,}" == "i" ]; then
        cd $KIRA_HOME
        systemctl stop kirascan || echoErr "ERROR: Failed to stop kirascan service"
        source $KIRA_MANAGER/kira/kira-reinitalize.sh
        source $KIRA_MANAGER/kira/kira.sh
        exit 0
    fi
done
