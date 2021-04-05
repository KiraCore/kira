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

if [ ! -f "$KIRA_SETUP/rebooted" ]; then
    echoInfo "INFO: Your machine recently rebooted, continuing setup process..."
    systemctl stop kirascan || echoWarn "WARNING: Could NOT stop kirascan service it was propably already stopped, starting new setup..."
    sleep 1
    $KIRA_MANAGER/start.sh "true"
    echoNErr "Press any key to open KIRA Network Manager or Ctrl+C to abort." && read -n 1 -s && echo ""
fi

if [ ! -f "$KIRA_SETUP/setup_complete" ]; then
    echoWarn "WARNING: Your node setup failed, do not worry, this can happen due to issues with network connectivity."
    VSEL="" && while ! [[ "${VSEL,,}" =~ ^(i|r|k)$ ]]; do echoNErr "Choose to continue [I]nstalation process, fully [R]initalize new node or open [K]ira Manager and investigate issues: " && read -d'' -s -n1 VSEL && echo ""; done
    
    if [ "${VSEL,,}" != "k" ] ; then
        systemctl stop kirascan
        if [ "${VSEL,,}" == "i" ] ; then
            sleep 1
            $KIRA_MANAGER/start.sh "false"
            echoNErr "Press any key to open KIRA Network Manager or Ctrl+C to abort." && read -n 1 -s && echo ""
        else
            cd $HOME
            source $KIRA_MANAGER/kira/kira-reinitalize.sh
            source $KIRA_MANAGER/kira/kira.sh
        fi
    fi
fi

cd $KIRA_HOME
SCAN_DIR="$KIRA_HOME/kirascan"
SCAN_DONE="$SCAN_DIR/done"
CONTAINERS_SCAN_PATH="$SCAN_DIR/containers"
NETWORKS_SCAN_PATH="$SCAN_DIR/networks"
DISK_SCAN_PATH="$SCAN_DIR/disk"
CPU_SCAN_PATH="$SCAN_DIR/cpu"
RAM_SCAN_PATH="$SCAN_DIR/ram"
LATEST_BLOCK_SCAN_PATH="$SCAN_DIR/latest_block"
LATEST_STATUS_SCAN_PATH="$SCAN_DIR/latest_status"
VALADDR_SCAN_PATH="$SCAN_DIR/valaddr"
VALSTATUS_SCAN_PATH="$SCAN_DIR/valstatus"
VALOPERS_SCAN_PATH="$SCAN_DIR/valopers"
CONSENSUS_SCAN_PATH="$SCAN_DIR/consensus"
STATUS_SCAN_PATH="$SCAN_DIR/status"
WHITESPACE="                                                          "
CONTAINERS_COUNT="0"

echoInfo "INFO: Restarting network scanner..."
systemctl daemon-reload
systemctl restart kirascan || echoErr "ERROR: Failed to restart kirascan service"

LOADING="true"
while :; do
    set +e && source "/etc/profile" &>/dev/null && set -e
    SNAP_STATUS="$KIRA_SNAP/status"
    SNAP_PROGRESS="$SNAP_STATUS/progress"
    SNAP_DONE="$SNAP_STATUS/done"
    SNAP_LATEST="$SNAP_STATUS/latest"

    VALADDR=$(cat $VALADDR_SCAN_PATH 2>/dev/null || echo "")
    [ ! -z "$VALADDR" ] && VALSTATUS=$(cat $VALSTATUS_SCAN_PATH 2>/dev/null | jq -rc '.status' 2>/dev/null || echo "") || VALSTATUS=""
    [ "${VALSTATUS,,}" == "null" ] && VALSTATUS=""

    START_TIME="$(date -u +%s)"
    NETWORKS=$(cat $NETWORKS_SCAN_PATH 2>/dev/null || echo "")
    CONTAINERS=$(cat $CONTAINERS_SCAN_PATH 2>/dev/null || echo "")
    CPU_UTIL=$(cat $CPU_SCAN_PATH 2>/dev/null || echo "")
    RAM_UTIL=$(cat $RAM_SCAN_PATH 2>/dev/null || echo "")
    DISK_UTIL=$(cat $DISK_SCAN_PATH 2>/dev/null || echo "")
    LOCAL_IP=$(cat $DOCKER_COMMON_RO/local_ip 2>/dev/null || echo "0.0.0.0")
    PUBLIC_IP=$(cat $DOCKER_COMMON_RO/public_ip 2>/dev/null || echo "")
    VALOPERS=$(cat $VALOPERS_SCAN_PATH 2>/dev/null || echo "")
    PROGRESS_SNAP="$(cat $SNAP_PROGRESS 2>/dev/null || echo "0") %"
    SNAP_LATEST_FILE="$KIRA_SNAP/$(cat $SNAP_LATEST 2>/dev/null || echo "")"
    KIRA_BLOCK=$(cat $LATEST_BLOCK_SCAN_PATH 2>/dev/null || echo "0")
    KIRA_STATUS=$(cat $LATEST_STATUS_SCAN_PATH 2>/dev/null || echo "")
    CONSENSUS=$(cat $CONSENSUS_SCAN_PATH 2>/dev/null || echo "")

    CONSENSUS_STOPPED="$(echo "$CONSENSUS" | jq -rc '.consensus_stopped' 2>/dev/null || echo "")" && ([ -z "$CONSENSUS_STOPPED" ] || [ "${CONSENSUS_STOPPED,,}" == "null" ]) && CONSENSUS_STOPPED="???"
    
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
            SEKAID_STATUS="${SCAN_PATH_VARS}.sekaid.status"

            if [ -f "$SCAN_PATH_VARS" ]; then
                source "$SCAN_PATH_VARS"
                i=$((i + 1))
            else
                continue
            fi

            SEKAID_STATUS=$(cat "${SCAN_PATH_VARS}.sekaid.status" 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
            SYNCING_TMP=$(echo $SEKAID_STATUS | jq -r '.SyncInfo.catching_up' 2>/dev/null || echo "false")
            ([ -z "$SYNCING_TMP" ] || [ "${SYNCING_TMP,,}" == "null" ]) && SYNCING_TMP=$(echo $SEKAID_STATUS | jq -r '.sync_info.catching_up' 2>/dev/null || echo "false")

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
    echo "|         KIRA NETWORK MANAGER v0.2.1           : $INFRA_MODE mode"
    echo "|------------ $(date '+%d/%m/%Y %H:%M:%S') --------------|"
    CPU_TMP="CPU: ${CPU_UTIL}${WHITESPACE}"
    RAM_TMP="RAM: ${RAM_UTIL}${WHITESPACE}"
    DISK_TMP="DISK: ${DISK_UTIL}${WHITESPACE}"

    [ ! -z "$CPU_UTIL" ] && [ ! -z "$RAM_UTIL" ] && [ ! -z "$DISK_UTIL" ] &&
        echo -e "|\e[35;1m ${CPU_TMP:0:16}${RAM_TMP:0:16}${DISK_TMP:0:13} \e[33;1m|"
    
    if [ "${LOADING,,}" == "false" ]; then
        KIRA_NETWORK=$(echo $KIRA_STATUS | jq -r '.NodeInfo.network' 2>/dev/null || echo "???") && [ -z "$KIRA_NETWORK" ] && KIRA_NETWORK="???"
        ([ -z "$KIRA_STATUS" ] || [ "${KIRA_STATUS,,}" == "null" ]) && KIRA_NETWORK=$(echo $KIRA_STATUS | jq -r '.node_info.network' 2>/dev/null || echo "???") && [ -z "$KIRA_NETWORK" ] && KIRA_NETWORK="???"
        if (! $(isNaturalNumber "$KIRA_BLOCK")) || [ "$KIRA_BLOCK" == "0" ]; then
            KIRA_BLOCK="???"
        else
            SECONDS_PER_BLOCK="$(echo "$CONSENSUS" | jq -rc '.average_block_time' 2>/dev/null || echo "")" && (! $(isNumber "$SECONDS_PER_BLOCK")) && SECONDS_PER_BLOCK="???"
            ($(isNumber "$SECONDS_PER_BLOCK")) && SECONDS_PER_BLOCK=$(echo "scale=1; ( $SECONDS_PER_BLOCK / 1 ) " | bc) && KIRA_BLOCK="$KIRA_BLOCK (${SECONDS_PER_BLOCK}s)"
        fi

        if [ -f "$LOCAL_GENESIS_PATH" ]; then
            GENESIS_SUM=$(sha256sum $LOCAL_GENESIS_PATH | awk '{ print $1 }')
            GENESIS_SUM="$(echo $GENESIS_SUM | head -c 4)...$(echo $GENESIS_SUM | tail -c 5)"
        else
            GENESIS_SUM="genesis not found"
        fi

        KIRA_NETWORK_TMP="NETWORK: ${KIRA_NETWORK}${WHITESPACE}"
        KIRA_BLOCK_TMP="BLOCKS: ${KIRA_BLOCK}${WHITESPACE}"
        echo -e "|\e[35;1m ${KIRA_NETWORK_TMP:0:22}${KIRA_BLOCK_TMP:0:23} \e[33;1m: $GENESIS_SUM"

        VALACTIVE="$(echo "$VALOPERS" | jq -rc '.status.active_validators' 2>/dev/null || echo "")" && ([ -z "$VALACTIVE" ] || [ "${VALACTIVE,,}" == "null" ]) && VALACTIVE="???"
        VALTOTAL="$(echo "$VALOPERS" | jq -rc '.status.total_validators' 2>/dev/null || echo "")" && ([ -z "$VALTOTAL" ] || [ "${VALTOTAL,,}" == "null" ]) && VALTOTAL="???"
        VALWAITING="$(echo "$VALOPERS" | jq -rc '.status.waiting_validators' 2>/dev/null || echo "???")" && ([ -z "$VALWAITING" ] || [ "${VALWAITING,,}" == "null" ]) && VALWAITING="???"
        VALACTIVE="VAL.ACTIVE: ${VALACTIVE}${WHITESPACE}"
        VALTOTAL="VAL.TOTAL: ${VALTOTAL}${WHITESPACE}"
        VALWAITING="WAITING: ${VALWAITING}${WHITESPACE}"
        [ "${CONSENSUS_STOPPED,,}" == "true" ] && echo -e "|\e[35;1m ${VALACTIVE:0:16}${VALTOTAL:0:16}${VALWAITING:0:13} \e[33;1m:\e[31;1m CONSENSUS HALTED\e[33;1m"
        [ "${CONSENSUS_STOPPED,,}" == "false" ] && echo -e "|\e[35;1m ${VALACTIVE:0:16}${VALTOTAL:0:16}${VALWAITING:0:13} \e[33;1m|"
    else
        KIRA_BLOCK="???"
    fi

    LOCAL_IP="L.IP: $LOCAL_IP                                               "
    if [ "$PUBLIC_IP" == "0.0.0.0" ] || ( ! $(isDnsOrIp "$PUBLIC_IP")) ; then
        echo -e "|\e[35;1m ${LOCAL_IP:0:22}PUB.IP: \e[31;1mdisconnected\e[33;1m    : $IFACE"
    else
        PUBLIC_IP="$PUBLIC_IP                          "
        echo -e "|\e[35;1m ${LOCAL_IP:0:22}PUB.IP: ${PUBLIC_IP:0:15}\e[33;1m : $IFACE"
    fi

    if [ -f "$KIRA_SNAP_PATH" ]; then # snapshot is present
        SNAP_FILENAME="SNAPSHOT: $(basename -- "$KIRA_SNAP_PATH")${WHITESPACE}"
        SNAP_SHA256=$(sha256sum $KIRA_SNAP_PATH | awk '{ print $1 }')
        [ "${SNAP_EXPOSE,,}" == "true" ] &&
            echo -e "|\e[32;1m ${SNAP_FILENAME:0:45} \e[33;1m: $(echo $SNAP_SHA256 | head -c 4)...$(echo $SNAP_SHA256 | tail -c 5)" ||
            echo -e "|\e[31;1m ${SNAP_FILENAME:0:45} \e[33;1m: $(echo $SNAP_SHA256 | head -c 4)...$(echo $SNAP_SHA256 | tail -c 5)"
    fi

    if [ "${LOADING,,}" == "true" ]; then
        echo -e "|\e[0m\e[31;1m PLEASE WAIT, LOADING INFRASTRUCTURE STATUS... \e[33;1m|"
    elif [ $CONTAINERS_COUNT -lt $INFRA_CONTAINER_COUNT ]; then
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, NOT ALL CONTAINERS LAUNCHED  \e[33;1m|"
    elif [ "${ALL_CONTAINERS_HEALTHY,,}" != "true" ]; then
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRASTRUCTURE IS UNHEALTHY  \e[33;1m|"
    elif [ "${CATCHING_UP,,}" == "true" ]; then
        echo -e "|\e[0m\e[33;1m     PLEASE WAIT, NODES ARE CATCHING UP        \e[33;1m|"
    elif [ "${SUCCESS,,}" == "true" ] && [ "${ALL_CONTAINERS_HEALTHY,,}" == "true" ]; then
        if [ ! -z "$VALADDR" ]; then
            [ "${VALSTATUS,,}" == "active" ] &&
                echo -e "|\e[0m\e[32;1m    SUCCESS, VALIDATOR AND INFRA IS HEALTHY    \e[33;1m: $VALSTATUS" ||
                echo -e "|\e[0m\e[31;1m    VALIDATOR NODE IS NOT PRODUCING BLOCKS     \e[33;1m: $VALSTATUS"
        else
            echo -e "|\e[0m\e[32;1m     SUCCESS, INFRASTRUCTURE IS HEALTHY        \e[33;1m|"
        fi
    else
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRA. IS NOT OPERATIONAL    \e[33;1m|"
    fi

    [ "${PORTS_EXPOSURE,,}" == "enabled" ] &&
        echo -e "|\e[0m\e[31;1m   ALL PORTS ARE OPEN TO THE PUBLIC NETWORKS   \e[33;1m|"
    [ "${PORTS_EXPOSURE,,}" == "custom" ] &&
        echo -e "|\e[0m\e[32;1m      ALL PORTS USE CUSTOM CONFIGURATION       \e[33;1m|"
    [ "${PORTS_EXPOSURE,,}" == "disabled" ] &&
        echo -e "|\e[0m\e[31;1m        ACCESS TO ALL PORTS IS DISABLED        \e[33;1m|"

    if [ "${LOADING,,}" == "false" ]; then
        echo "|-----------------------------------------------| [health]"
        i=-1
        for name in $CONTAINERS; do
            i=$((i + 1))
            STATUS_TMP="STATUS_$name" && STATUS_TMP="${!STATUS_TMP}"
            HEALTH_TMP="HEALTH_$name" && HEALTH_TMP="${!HEALTH_TMP}"
            [ "${HEALTH_TMP,,}" == "null" ] && HEALTH_TMP="" # do not display
            [ "${name,,}" == "snapshot" ] && [ "${STATUS_TMP,,}" == "running" ] && STATUS_TMP="$PROGRESS_SNAP"

            if [[ "${name,,}" =~ ^(validator|sentry|priv_sentry|seed|interx)$ ]] && [[ "${STATUS_TMP,,}" =~ ^(running|starting)$ ]]; then
                LATEST_BLOCK=$(cat "$STATUS_SCAN_PATH/${name}.sekaid.latest_block_height" 2>/dev/null || echo "")
                CATCHING_UP=$(cat "$STATUS_SCAN_PATH/${name}.sekaid.catching_up" 2>/dev/null || echo "false")
                ([ -z "$LATEST_BLOCK" ] || [ -z "${LATEST_BLOCK##*[!0-9]*}" ]) && LATEST_BLOCK=0

                if [ "${CATCHING_UP,,}" == "true" ]; then
                    STATUS_TMP="syncing : $LATEST_BLOCK"
                else
                    STATUS_TMP="$STATUS_TMP : $LATEST_BLOCK"
                fi
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

    if ([ "${INFRA_MODE,,}" == "validator" ] && [ $ESSENTIAL_CONTAINERS_COUNT -ge 2 ]) || [ "${INFRA_MODE,,}" == "sentry" ] && [ $ESSENTIAL_CONTAINERS_COUNT -ge 1 ]; then
        if [ "${AUTO_BACKUP_ENABLED,,}" == "true" ]; then
            [ -z "$AUTO_BACKUP_EXECUTED_TIME" ] && AUTO_BACKUP_EXECUTED_TIME=$(date -u +%s)
            ELAPSED_TIME=$(($(date -u +%s) - $AUTO_BACKUP_EXECUTED_TIME))
            INTERVAL_AS_SECOND=$(($AUTO_BACKUP_INTERVAL * 3600))
            TIME_LEFT=$(($INTERVAL_AS_SECOND - $ELAPSED_TIME))
            [ $TIME_LEFT -lt 0 ] && TIME_LEFT=0
            AUTO_BACKUP_TMP=": AUTO-SNAP ${TIME_LEFT}s${WHITESPACE}"
        else
            AUTO_BACKUP_TMP=": MANUAL-SNAP${WHITESPACE}"
        fi
        echo "| [B] | BACKUP Chain State ${AUTO_BACKUP_TMP:0:21}|" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}b"
    fi

    if [ ! -z "$KIRA_SNAP_PATH" ]; then
        [ "${SNAP_EXPOSE,,}" == "false" ] &&
            echo "| [E] | EXPOSE Snapshot                         |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}e" ||
            echo "| [E] | Hide EXPOSED Snapshot                   |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}e"
    fi

    if [ "${VALIDATOR_RUNNING,,}" == "true" ] ; then
        [ "${VALSTATUS,,}" == "active" ] && echo "| [M] | Enable MAITENANCE Mode                  |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}m"
        [ "${VALSTATUS,,}" == "paused" ] && echo "| [M] | Disable MAITENANCE Mode                 |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}m"
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
        echo ""
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
        if [ "$OPTION" == "$i" ]; then
            source $KIRA_MANAGER/kira/container-manager.sh $name
            OPTION="" && EXECUTED="true" && break
        elif [ "${OPTION,,}" == "d" ]; then
            echoInfo "INFO: Dumping all loggs from $name container..."
            $KIRAMGR_SCRIPTS/dump-logs.sh $name "false"
            EXECUTED="true"
        elif [ "${OPTION,,}" == "r" ]; then
            echoInfo "INFO: Re-starting $name container..."
            $KIRA_SCRIPTS/container-restart.sh $name
            EXECUTED="true" && LOADING="true"
        elif [ "${OPTION,,}" == "s" ]; then
            if [ "${ALL_CONTAINERS_STOPPED,,}" == "false" ]; then
                echoInfo "INFO: Stopping $name container..."
                $KIRA_SCRIPTS/container-stop.sh $name
            else
                echoInfo "INFO: Staring $name container..."
                $KIRA_SCRIPTS/container-start.sh $name
            fi
            LOADING="true" && EXECUTED="true"
        elif [ "${OPTION,,}" == "p" ]; then
            if [ "${ALL_CONTAINERS_PAUSED,,}" == "false" ]; then
                echoInfo "INFO: Pausing $name container..."
                $KIRA_SCRIPTS/container-pause.sh $name
            else
                echoInfo "INFO: UnPausing $name container..."
                $KIRA_SCRIPTS/container-unpause.sh $name
            fi
            LOADING="true" && EXECUTED="true"
        fi
    done

    if [ "${OPTION,,}" == "r" ]; then
        echoInfo "INFO: Reconnecting all networks..."
        $KIRAMGR_SCRIPTS/restart-networks.sh "true"
    fi

    if [ "${OPTION,,}" == "d" ]; then
        echoInfo "INFO: Dumping firewal info..."
        ufw status verbose >"$KIRA_DUMP/ufw-status.txt" || echoErr "ERROR: Failed to get firewal status"
        echoInfo "INFO: Compresing all dumped files..."
        ZIP_FILE="$KIRA_DUMP/kira.zip"
        rm -fv $ZIP_FILE
        zip -9 -r -v $ZIP_FILE $KIRA_DUMP
        echoInfo "INFO: All dump files were exported into $ZIP_FILE"
    elif [ "${OPTION,,}" == "s" ] && [ "${ALL_CONTAINERS_STOPPED,,}" != "false" ]; then
        echoInfo "INFO: Reconnecting all networks..."
        $KIRAMGR_SCRIPTS/restart-networks.sh "true"
        echoInfo "INFO: Reinitalizing firewall..."
        $KIRA_MANAGER/networking.sh
    elif [ "${OPTION,,}" == "b" ]; then
        echoInfo "INFO: Backing up blockchain state..."
        $KIRA_MANAGER/kira/kira-backup.sh "$KIRA_BLOCK" || echoErr "ERROR: Snapshot failed"
        LOADING="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "n" ]; then
        echoInfo "INFO: Staring networking manager..."
        $KIRA_MANAGER/kira/kira-networking.sh || echoErr "ERROR: Network manager failed"
        LOADING="false" && EXECUTED="true" && OPTION=""
    elif [ "${OPTION,,}" == "e" ]; then
        if [ "${SNAP_EXPOSE,,}" == "false" ]; then
            echoInfo "INFO: Exposing latest snapshot '$KIRA_SNAP_PATH' via INTERX"
            CDHelper text lineswap --insert="SNAP_EXPOSE=\"true\"" --prefix="SNAP_EXPOSE=" --path=$ETC_PROFILE --append-if-found-not=True
            echoInfo "INFO: Await few minutes and your snapshot will become available via 0.0.0.0:$KIRA_INTERX_PORT/download/snapshot.zip"
        else
            echoInfo "INFO: Ensuring exposed snapshot will be removed..."
            CDHelper text lineswap --insert="SNAP_EXPOSE=\"false\"" --prefix="SNAP_EXPOSE=" --path=$ETC_PROFILE --append-if-found-not=True
            echoInfo "INFO: Await few minutes and your snapshot will become unavailable"
        fi
        LOADING="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "m" ]; then
        if [ "${VALSTATUS,,}" == "active" ]; then
            echoInfo "INFO: Attempting to changing validator status to PAUSED..."
            docker exec -i validator sekaid tx customslashing pause --from validator --chain-id="$NETWORK_NAME" --keyring-backend=test --home=$SEKAID_HOME --fees 100ukex --yes | jq || echoErr "ERROR: Failed to enter maitenance mode"
        elif [ "${VALSTATUS,,}" == "paused" ] ; then
            echoInfo "INFO: Attempting to change validator status to ACTIVE..."
            docker exec -i validator sekaid tx customslashing unpause --from validator --chain-id="$NETWORK_NAME" --keyring-backend=test --home=$SEKAID_HOME --fees 100ukex --yes | jq || echoErr "ERROR: Failed to exit maitenance mode"
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
        cd $HOME
        systemctl stop kirascan || echoErr "ERROR: Failed to stop kirascan service"
        source $KIRA_MANAGER/kira/kira-reinitalize.sh
        source $KIRA_MANAGER/kira/kira.sh
        exit 0
    fi
done
