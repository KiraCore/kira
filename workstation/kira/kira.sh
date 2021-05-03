#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/kira.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
 
set +x
echoInfo "INFO: Launching KIRA Network Manager..."
rm -fv /dev/null && mknod -m 666 /dev/null c 1 3 || :

if [ "${USER,,}" != root ]; then
    echoErr "ERROR: You have to run this application as root, try 'sudo -s' command first"
    exit 1
fi

UPDATE_DONE_FILE="$KIRA_UPDATE/done"
UPDATE_FAIL_FILE="$KIRA_UPDATE/fail"

while [ ! -f "$UPDATE_DONE_FILE" ] || [ -f $UPDATE_FAIL_FILE ] ; do
    if [ -f $UPDATE_FAIL_FILE ] ; then
        echoWarn "WARNING: Your node setup FAILED, its reccomended that you [D]ump all logs"
        echoWarn "WARNING: Make sure to investigate issues before reporting them to relevant gitub repository"
        VSEL="" && while ! [[ "${VSEL,,}" =~ ^(v|r|k|d)$ ]]; do echoNErr "Choose to [V]iew setup logs, [R]initalize new node, [D]ump logs or force open [K]IRA Manager: " && read -d'' -s -n1 VSEL && echo ""; done
    else
        echoWarn "WARNING: Your node setup is NOT compleated yet"
        VSEL="" && while ! [[ "${VSEL,,}" =~ ^(v|r|k|d)$ ]]; do echoNErr "Choose to [V]iew setup progress, [R]initalize new node, [D]ump logs or force open [K]IRA Manager: " && read -d'' -s -n1 VSEL && echo ""; done
    fi
    
    if [ "${VSEL,,}" == "r" ] ; then
        source $KIRA_MANAGER/kira/kira-reinitalize.sh
    elif [ "${VSEL,,}" == "v" ] ; then
        if [ -z "$SETUP_END_DT" ] ; then
            echoInfo "INFO: Starting setup logs preview, to exit type Ctrl+c"
            sleep 2 && journalctl --since "$SETUP_START_DT" -u kiraup -f --output cat
        else
            echoInfo "INFO: Printing setup logs:"
            sleep 2 && journalctl --since "$SETUP_START_DT" --until "$SETUP_END_DT" -u kiraup -b --no-pager --output cat
        fi
    elif [ "${VSEL,,}" == "d" ] ; then
        $KIRA_MANAGER/kira/kira-dump.sh || echoErr "ERROR: Failed logs dump"
    else
        break
    fi
done

cd $KIRA_HOME
SCAN_DONE="$KIRA_SCAN/done"
CONTAINERS_SCAN_PATH="$KIRA_SCAN/containers"
NETWORKS_SCAN_PATH="$KIRA_SCAN/networks"
LATEST_BLOCK_SCAN_PATH="$KIRA_SCAN/latest_block"
LATEST_STATUS_SCAN_PATH="$KIRA_SCAN/latest_status"
VALADDR_SCAN_PATH="$KIRA_SCAN/valaddr"
VALSTATUS_SCAN_PATH="$KIRA_SCAN/valstatus"
VALOPERS_COMM_RO_PATH="$DOCKER_COMMON_RO/valopers"
CONSENSUS_COMM_RO_PATH="$DOCKER_COMMON_RO/consensus"
STATUS_SCAN_PATH="$KIRA_SCAN/status"
WHITESPACE="                                                          "
CONTAINERS_COUNT="0"
INTERX_SNAPSHOT_PATH="$INTERX_REFERENCE_DIR/snapshot.zip"

mkdir -p "$INTERX_REFERENCE_DIR"

echoInfo "INFO: Restarting network scanner..."
systemctl daemon-reload
systemctl restart kirascan || echoErr "ERROR: Failed to restart kirascan service"

LOADING="true"
PREVIOUS_BLOCK=0
while :; do
    set +e && source "/etc/profile" &>/dev/null && set -e
    SNAP_STATUS="$KIRA_SNAP/status"
    SNAP_PROGRESS="$SNAP_STATUS/progress"
    SNAP_DONE="$SNAP_STATUS/done"
    SNAP_LATEST="$SNAP_STATUS/latest"

    VALADDR=$(tryCat $VALADDR_SCAN_PATH "")
    VALSTATUS=$(jsonQuickParse "status" $VALSTATUS_SCAN_PATH 2>/dev/null || echo -n "")
    ($(isNullOrEmpty "$VALSTATUS")) && VALSTATUS=""

    START_TIME="$(date -u +%s)"
    NETWORKS=$(tryCat $NETWORKS_SCAN_PATH "")
    CONTAINERS=$(tryCat $CONTAINERS_SCAN_PATH "")
    PROGRESS_SNAP="$(tryCat $SNAP_PROGRESS "0") %"
    SNAP_LATEST_FILE="$KIRA_SNAP/$(tryCat $SNAP_LATEST "")"
    KIRA_BLOCK=$(tryCat $LATEST_BLOCK_SCAN_PATH "0")
    CONSENSUS_STOPPED="$(jsonQuickParse "consensus_stopped" $CONSENSUS_COMM_RO_PATH 2>/dev/null || echo -n "")" && ($(isNullOrEmpty "$CONSENSUS_STOPPED")) && CONSENSUS_STOPPED="???"
    
    if [ -f "$SNAP_DONE" ]; then
        PROGRESS_SNAP="done"                                                                       # show done progress
        [ -f "$SNAP_LATEST_FILE" ] && [ -f "$KIRA_SNAP_PATH" ] && KIRA_SNAP_PATH=$SNAP_LATEST_FILE # ensure latest snap is up to date
    fi

    if [ "${LOADING,,}" == "false" ]; then
        SUCCESS="true"
        ALL_CONTAINERS_PAUSED="true"
        ALL_CONTAINERS_STOPPED="true"
        ALL_CONTAINERS_HEALTHY="true"
        CATCHING_UP="false"
        ESSENTIAL_CONTAINERS_COUNT=0
        VALIDATOR_RUNNING="false"

        i=-1
        for name in $CONTAINERS; do
            SCAN_PATH_VARS="$STATUS_SCAN_PATH/$name"
            SEKAID_STATUS_FILE="${SCAN_PATH_VARS}.sekaid.status"

            if [ -f "$SCAN_PATH_VARS" ]; then
                source "$SCAN_PATH_VARS"
                i=$((i + 1))
            else
                continue
            fi

            SYNCING_TMP=$(jsonQuickParse "catching_up" $SEKAID_STATUS_FILE 2>/dev/null || echo "false")

            # if some other node then snapshot is syncig then infra is not ready
            [ "${name,,}" != "snapshot" ] && [ "${SYNCING_TMP,,}" == "true" ] && CATCHING_UP="true"

            STATUS_TMP="STATUS_$name" && STATUS_TMP="${!STATUS_TMP}"
            HEALTH_TMP="HEALTH_$name" && HEALTH_TMP="${!HEALTH_TMP}"
            [ "${STATUS_TMP,,}" != "running" ] && SUCCESS="false"
            [ "${STATUS_TMP,,}" != "exited" ] && ALL_CONTAINERS_STOPPED="false"
            [ "${STATUS_TMP,,}" != "paused" ] && ALL_CONTAINERS_PAUSED="false"
            [ "${name,,}" == "registry" ] && continue
            [ "${name,,}" == "snapshot" ] && continue
            [ "${HEALTH_TMP,,}" != "healthy" ] && ALL_CONTAINERS_HEALTHY="false"
            [ "${name,,}" == "validator" ] && [ "${STATUS_TMP,,}" == "running" ] && VALIDATOR_RUNNING="true"
            [ "${name,,}" == "validator" ] && [ "${STATUS_TMP,,}" != "running" ] && VALIDATOR_RUNNING="false"

            if [ "${STATUS_TMP,,}" == "running" ] && [[ "${name,,}" =~ ^(validator|sentry)$ ]]; then
                ESSENTIAL_CONTAINERS_COUNT=$((ESSENTIAL_CONTAINERS_COUNT + 1))
            fi
        done
        CONTAINERS_COUNT=$((i + 1))
    fi

    printf "\033c"

    ALLOWED_OPTIONS="x"
    echo -e "\e[33;1m-------------------------------------------------"
    echo "|         KIRA NETWORK MANAGER $KIRA_SETUP_VER         : $INFRA_MODE mode"
    echo "|------------ $(date '+%d/%m/%Y %H:%M:%S') --------------|"

    RAM_UTIL=$(globGet RAM_UTIL) && RAM_TMP="RAM: ${RAM_UTIL}${WHITESPACE}"
    CPU_UTIL=$(globGet CPU_UTIL) && CPU_TMP="CPU: ${CPU_UTIL}${WHITESPACE}"
    DISK_UTIL=$(globGet DISK_UTIL) && DISK_TMP="DISK: ${DISK_UTIL}${WHITESPACE}"

    [ ! -z "$CPU_UTIL" ] && [ ! -z "$RAM_UTIL" ] && [ ! -z "$DISK_UTIL" ] &&
        echo -e "|\e[35;1m ${CPU_TMP:0:16}${RAM_TMP:0:16}${DISK_TMP:0:13} \e[33;1m: $(globGet DISK_CONS)"
    
    if [ "${LOADING,,}" == "false" ]; then
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
        echo -e "|\e[35;1m ${LOCAL_IP:0:24}P.IP: \e[31;1mdisconnected\e[33;1m    : $IFACE"
    else
        PUBLIC_IP="$PUBLIC_IP                          "
        echo -e "|\e[35;1m ${LOCAL_IP:0:24}P.IP: ${PUBLIC_IP:0:15}\e[33;1m : $IFACE"
    fi

    if [ -f "$KIRA_SNAP_PATH" ]; then # snapshot is present
        SNAP_FILENAME="SNAPSHOT: $(basename -- "$KIRA_SNAP_PATH")${WHITESPACE}"
        [ -z "$KIRA_SNAP_SHA256" ] && KIRA_SNAP_SHA256="????????????"
        [ "${SNAP_EXPOSE,,}" == "true" ] &&
            echo -e "|\e[32;1m ${SNAP_FILENAME:0:45} \e[33;1m: $(echo $KIRA_SNAP_SHA256 | head -c 4)...$(echo $KIRA_SNAP_SHA256 | tail -c 5)" ||
            echo -e "|\e[31;1m ${SNAP_FILENAME:0:45} \e[33;1m: $(echo $KIRA_SNAP_SHA256 | head -c 4)...$(echo $KIRA_SNAP_SHA256 | tail -c 5)"
    fi

    if [ "${LOADING,,}" == "true" ]; then
        echo -e "|\e[0m\e[31;1m PLEASE WAIT, LOADING INFRASTRUCTURE STATUS... \e[33;1m|"
    elif [ "${CATCHING_UP,,}" == "true" ]; then
        echo -e "|\e[0m\e[33;1m     PLEASE WAIT, NODES ARE CATCHING UP        \e[33;1m|"
    elif [[ $CONTAINERS_COUNT -lt $INFRA_CONTAINER_COUNT ]]; then
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, NOT ALL CONTAINERS LAUNCHED  \e[33;1m|"
    elif [ "${ALL_CONTAINERS_HEALTHY,,}" != "true" ]; then
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRASTRUCTURE IS UNHEALTHY  \e[33;1m|"
    elif [ "${SUCCESS,,}" == "true" ] && [ "${ALL_CONTAINERS_HEALTHY,,}" == "true" ]; then
        if [ ! -z "$VALADDR" ]; then
            if [ "${VALSTATUS,,}" == "active" ] ; then
                echo -e "|\e[0m\e[32;1m    SUCCESS, VALIDATOR AND INFRA IS HEALTHY    \e[33;1m: $VALSTATUS"
            elif [ "${VALSTATUS,,}" == "inactive" ] ; then
                echo -e "|\e[0m\e[31;1m    VALIDATOR IS JAILED, ACTIVATE YOUR NODE    \e[33;1m: $VALSTATUS"
            elif [ "${VALSTATUS,,}" == "paused" ] ; then
                echo -e "|\e[0m\e[36;1m      VALIDATOR ENTERED MAINTENANCE MODE       \e[33;1m: $VALSTATUS"
            elif [ "${VALSTATUS,,}" == "waiting" ] ; then
                echo -e "|\e[0m\e[33;1m  WHITELISTED, READY TO CLAIM VALIDATOR SEAT   \e[33;1m: $VALSTATUS"
            else
                echo -e "|\e[0m\e[31;1m    VALIDATOR NODE IS NOT PRODUCING BLOCKS     \e[33;1m: $VALSTATUS"
            fi
        else
            echo -e "|\e[0m\e[32;1m     SUCCESS, INFRASTRUCTURE IS HEALTHY        \e[33;1m|"
        fi
    else
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRA. IS NOT OPERATIONAL    \e[33;1m|"
    fi

    [ "${PORTS_EXPOSURE,,}" == "enabled" ] && \
        echo -e "|\e[0m\e[31;1m   ALL PORTS ARE OPEN TO THE PUBLIC NETWORKS   \e[33;1m|"
    [ "${PORTS_EXPOSURE,,}" == "custom" ] && \
        echo -e "|\e[0m\e[32;1m      ALL PORTS USE CUSTOM CONFIGURATION       \e[33;1m|"
    [ "${PORTS_EXPOSURE,,}" == "disabled" ] && \
        echo -e "|\e[0m\e[31;1m        ACCESS TO ALL PORTS IS DISABLED        \e[33;1m|"

    if [ "${LOADING,,}" == "false" ]; then
        echo "|-----------------------------------------------| [health]"
        i=-1
        for name in $CONTAINERS; do
            i=$((i + 1))
            STATUS_TMP="STATUS_$name" && STATUS_TMP="${!STATUS_TMP}"
            HEALTH_TMP="HEALTH_$name" && HEALTH_TMP="${!HEALTH_TMP}" && ($(isNullOrEmpty "$HEALTH_TMP")) && HEALTH_TMP=""
            [ "${name,,}" == "snapshot" ] && [ "${STATUS_TMP,,}" == "running" ] && STATUS_TMP="$PROGRESS_SNAP"

            if [[ "${name,,}" =~ ^(validator|sentry|priv_sentry|seed|interx)$ ]] && [[ "${STATUS_TMP,,}" =~ ^(running|starting)$ ]]; then
                LATEST_BLOCK=$(tryCat "$STATUS_SCAN_PATH/${name}.sekaid.latest_block_height" "") && (! $(isNaturalNumber "$LATEST_BLOCK")) && LATEST_BLOCK=0
                CATCHING_UP=$(tryCat "$STATUS_SCAN_PATH/${name}.sekaid.catching_up" "false")
                [ "${CATCHING_UP,,}" == "true" ] && STATUS_TMP="syncing : $LATEST_BLOCK" || STATUS_TMP="$STATUS_TMP : $LATEST_BLOCK"
            fi

            NAME_TMP="${name}${WHITESPACE}"
            STATUS_TMP="${STATUS_TMP}${WHITESPACE}"
            LABEL="| [$i] | Manage ${NAME_TMP:0:11} : ${STATUS_TMP:0:21}"
            echo "${LABEL:0:47} : $HEALTH_TMP" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}${i}"
        done
    else
        while [ ! -f $SCAN_DONE ]; do
            sleep 1
        done
        LOADING="false"
        continue
    fi

    echo "|-----------------------------------------------|"
    if [ "$CONTAINERS_COUNT" != "0" ] && [ "${LOADING,,}" == "false" ]; then
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

    if ([ "${INFRA_MODE,,}" == "validator" ] && [[ $ESSENTIAL_CONTAINERS_COUNT -ge 2 ]]) || [ "${INFRA_MODE,,}" == "sentry" ] && [[ $ESSENTIAL_CONTAINERS_COUNT -ge 1 ]]; then
        if [ "${AUTO_BACKUP_ENABLED,,}" == "true" ]; then
            [ -z "$AUTO_BACKUP_EXECUTED_TIME" ] && AUTO_BACKUP_EXECUTED_TIME=$(date -u +%s)
            ELAPSED_TIME=$(($(date -u +%s) - $AUTO_BACKUP_EXECUTED_TIME))
            INTERVAL_AS_SECOND=$(($AUTO_BACKUP_INTERVAL * 3600))
            TIME_LEFT=$(($INTERVAL_AS_SECOND - $ELAPSED_TIME))
            [[ $TIME_LEFT -lt 0 ]] && TIME_LEFT=0
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

    EXECUTED="false"
    i=-1
    for name in $CONTAINERS; do
        i=$((i + 1))
        COMMON_PATH="$DOCKER_COMMON/$name"
        mkdir -p "$COMMON_PATH"
        HALT_FILE="$COMMON_PATH/halt"
        EXIT_FILE="$COMMON_PATH/exit"
        if [ "$OPTION" == "$i" ]; then
            source $KIRA_MANAGER/kira/container-manager.sh $name
            OPTION="" && EXECUTED="true" && break
        elif [ "${OPTION,,}" == "r" ]; then
            echoInfo "INFO: Re-starting $name container..."
            $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "restart"
            EXECUTED="true" && LOADING="true"
        elif [ "${OPTION,,}" == "s" ]; then
            if [ "${ALL_CONTAINERS_STOPPED,,}" == "false" ]; then
                echoInfo "INFO: Stopping $name container..."
                $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "stop"
            else
                echoInfo "INFO: Staring $name container..."
                $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "start"
            fi
            LOADING="true" && EXECUTED="true"
        elif [ "${OPTION,,}" == "p" ]; then
            if [ "${ALL_CONTAINERS_PAUSED,,}" == "false" ]; then
                echoInfo "INFO: Pausing $name container..."
                $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "pause"
            else
                echoInfo "INFO: UnPausing $name container..."
                $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "unpause"
            fi
            LOADING="true" && EXECUTED="true"
        fi
    done

    # if [ "${OPTION,,}" == "r" ]; then
    #     echoInfo "INFO: Reconnecting all networks..."
    #     # $KIRAMGR_SCRIPTS/restart-networks.sh "true"
    #     $KIRA_MANAGER/scripts/update-ifaces.sh
    # fi

    if [ "${OPTION,,}" == "d" ]; then
        $KIRA_MANAGER/kira/kira-dump.sh || echoErr "ERROR: Failed logs dump"
        LOADING="false" && EXECUTED="true"
    elif [ "${OPTION,,}" == "s" ] && [ "${ALL_CONTAINERS_STOPPED,,}" != "false" ]; then
        echoInfo "INFO: Reconnecting all networks..."
        # $KIRAMGR_SCRIPTS/restart-networks.sh "true"
        # $KIRA_MANAGER/scripts/update-ifaces.sh
        echoInfo "INFO: Reinitalizing firewall..."
        $KIRA_MANAGER/networking.sh
    elif [ "${OPTION,,}" == "b" ]; then
        echoInfo "INFO: Backing up blockchain state..."
        $KIRA_MANAGER/kira/kira-backup.sh || echoErr "ERROR: Snapshot failed"
        LOADING="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "n" ]; then
        echoInfo "INFO: Staring networking manager..."
        $KIRA_MANAGER/kira/kira-networking.sh || echoErr "ERROR: Network manager failed"
        LOADING="false" && EXECUTED="true" && OPTION=""
    elif [ "${OPTION,,}" == "e" ]; then
        if [ "${SNAP_EXPOSE,,}" == "false" ]; then
            echoInfo "INFO: Exposing latest snapshot '$KIRA_SNAP_PATH' via INTERX"
            CDHelper text lineswap --insert="SNAP_EXPOSE=\"true\"" --prefix="SNAP_EXPOSE=" --path=$ETC_PROFILE --append-if-found-not=True
            ln -fv "$KIRA_SNAP_PATH" "$INTERX_SNAPSHOT_PATH" && \
                echoInfo "INFO: Await few minutes and your snapshot will become available via 0.0.0.0:$KIRA_INTERX_PORT/download/snapshot.zip" || \
                echoErr "ERROR: Failed to create snapshot symlink"
        else
            echoInfo "INFO: Ensuring exposed snapshot will be removed..."
            CDHelper text lineswap --insert="SNAP_EXPOSE=\"false\"" --prefix="SNAP_EXPOSE=" --path=$ETC_PROFILE --append-if-found-not=True
            rm -fv "$INTERX_SNAPSHOT_PATH" && \
                echoInfo "INFO: Await few minutes and your snapshot will become unavailable" || \
                echoErr "ERROR: Failed to remove snapshot symlink"
        fi
        LOADING="true" && EXECUTED="true"
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
        LOADING="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "a" ]; then
        if [ "${VALSTATUS,,}" == "inactive" ] ; then
            echoInfo "INFO: Attempting to change validator status from INACTIVE to ACTIVE..."
            ( docker exec -i validator /bin/bash -c ". /etc/profile && sekaid tx customslashing activate --from validator --chain-id=\$NETWORK_NAME --keyring-backend=test --home=\$SEKAID_HOME --fees 1000ukex --gas=1000000000 --yes --broadcast-mode=async --log_format=json | txAwait 180" || \
            echoErr "ERROR: Failed to confirm pause tx" ) && echoWarn "WARNINIG: Please be patient, it might take couple of minutes before your status changes in the KIRA Manager..."
            sleep 5
        else
            echoWarn "WARNINIG: Unknown validator status '$VALSTATUS'"
        fi
        LOADING="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "x" ]; then
        printf "\033c"
        echoInfo "INFO: Stopping kira network scanner..."
        rm -fv /dev/null && mknod -m 666 /dev/null c 1 3 || :
        exit 0
    fi

    [ "${LOADING,,}" == "true" ] && rm -fv $SCAN_DONE # trigger re-scan
    [ "${EXECUTED,,}" == "true" ] && [ ! -z $OPTION ] && echoNErr "INFO: Option ($OPTION) was executed, press any key to continue..." && read -n 1 -s && echo ""

    if [ "${OPTION,,}" == "i" ]; then
        cd $KIRA_HOME
        systemctl stop kirascan || echoErr "ERROR: Failed to stop kirascan service"
        source $KIRA_MANAGER/kira/kira-reinitalize.sh
        source $KIRA_MANAGER/kira/kira.sh
        exit 0
    fi
done
