#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/kira.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

set +x
echo "INFO: Launching KIRA Network Manager..."

if [ "${USER,,}" != root ] ; then
    echo "ERROR: You have to run this application as root, try 'sudo -s' command first"
    exit 1
fi

cd $KIRA_HOME
SCAN_DIR="$KIRA_HOME/kirascan"
SCAN_DONE="$SCAN_DIR/done"
CONTAINERS_SCAN_PATH="$SCAN_DIR/containers"
NETWORKS_SCAN_PATH="$SCAN_DIR/networks"
DISK_SCAN_PATH="$SCAN_DIR/disk"
CPU_SCAN_PATH="$SCAN_DIR/cpu"
RAM_SCAN_PATH="$SCAN_DIR/ram"
LIP_SCAN_PATH="$SCAN_DIR/lip"
IP_SCAN_PATH="$SCAN_DIR/ip"
VALADDR_SCAN_PATH="$SCAN_DIR/valaddr"
VALSTATUS_SCAN_PATH="$SCAN_DIR/valstatus"
STATUS_SCAN_PATH="$SCAN_DIR/status"
GENESIS_JSON="$KIRA_CONFIGS/genesis.json"
WHITESPACE="                                                          "

echo "INFO: Restarting network scanner..."
systemctl daemon-reload
systemctl restart kirascan

LOADING="true"
while : ; do
    set +e && source "/etc/profile" &>/dev/null && set -e
    SNAP_STATUS="$KIRA_SNAP/status"
    SNAP_PROGRESS="$SNAP_STATUS/progress"
    SNAP_DONE="$SNAP_STATUS/done"
    SNAP_LATEST="$SNAP_STATUS/latest"

    VALADDR=$(cat $VALADDR_SCAN_PATH 2> /dev/null || echo "")
    [ ! -z "$VALADDR" ] && VALSTATUS=$(cat $VALSTATUS_SCAN_PATH 2> /dev/null | jq -rc '.status' 2> /dev/null || echo "") || VALSTATUS=""

    START_TIME="$(date -u +%s)"
    NETWORKS=$(cat $NETWORKS_SCAN_PATH 2> /dev/null || echo "")
    CONTAINERS=$(cat $CONTAINERS_SCAN_PATH 2> /dev/null || echo "")
    CPU_UTIL=$(cat $CPU_SCAN_PATH 2> /dev/null || echo "")
    RAM_UTIL=$(cat $RAM_SCAN_PATH 2> /dev/null || echo "")
    DISK_UTIL=$(cat $DISK_SCAN_PATH 2> /dev/null || echo "")
    LOCAL_IP=$(cat $LIP_SCAN_PATH 2> /dev/null || echo "0.0.0.0")
    PUBLIC_IP=$(cat $IP_SCAN_PATH 2> /dev/null || echo "")
    PROGRESS_SNAP="$(cat $SNAP_PROGRESS 2> /dev/null || echo "0") %"
    SNAP_LATEST_FILE="$KIRA_SNAP/$(cat $SNAP_LATEST 2> /dev/null || echo "")" 

    if [ -f "$SNAP_DONE" ] ; then
        PROGRESS_SNAP="done" # show done progress
        [ -f "$SNAP_LATEST_FILE" ] && [ -f "$KIRA_SNAP_PATH" ] && KIRA_SNAP_PATH=$SNAP_LATEST_FILE # ensure latest snap is up to date
    fi
    
    if [ "${LOADING,,}" == "false" ] ; then
        SUCCESS="true"
        ALL_CONTAINERS_PAUSED="true"
        ALL_CONTAINERS_STOPPED="true"
        ALL_CONTAINERS_HEALTHY="true"
        ESSENTIAL_CONTAINERS_COUNT=0
        KIRA_BLOCK=0
        CATCHING_UP="false"

        i=-1
        for name in $CONTAINERS; do
            SCAN_PATH_VARS="$STATUS_SCAN_PATH/$name"
            SEKAID_STATUS="${SCAN_PATH_VARS}.sekaid.status"

            if [ -f "$SCAN_PATH_VARS" ] ; then
                source "$SCAN_PATH_VARS"
                i=$((i + 1))
            else
                continue
            fi

            SEKAID_STATUS=$(cat "${SCAN_PATH_VARS}.sekaid.status" 2> /dev/null | jq -r '.' 2>/dev/null || echo "")
            KIRA_BLOCK_TMP=$(echo $SEKAID_STATUS | jq -r '.SyncInfo.latest_block_height' 2> /dev/null || echo "")
            [[ ! $KIRA_BLOCK_TMP =~ ^[0-9]+$ ]] && KIRA_BLOCK_TMP=$(echo $SEKAID_STATUS | jq -r '.sync_info.latest_block_height' 2> /dev/null || echo "")
            [[ ! $KIRA_BLOCK_TMP =~ ^[0-9]+$ ]] && KIRA_BLOCK_TMP="0"
            SYNCING_TMP=$(echo $SEKAID_STATUS | jq -r '.SyncInfo.catching_up' 2> /dev/null || echo "false")
            ( [ -z "$SYNCING_TMP" ] || [ "${SYNCING_TMP,,}" == "null" ] ) && SYNCING_TMP=$(echo $SEKAID_STATUS | jq -r '.sync_info.catching_up' 2> /dev/null || echo "false")

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

            if [ "${STATUS_TMP,,}" == "running" ] && [[ "${name,,}" =~ ^(validator|sentry)$ ]] ; then
                ESSENTIAL_CONTAINERS_COUNT=$((ESSENTIAL_CONTAINERS_COUNT + 1))
            fi

            if [ ! -z "$SEKAID_STATUS" ] && ( [ -z "$NETWORK_STATUS" ] || [ $KIRA_BLOCK_TMP -gt $KIRA_BLOCK ] ) ; then
                NETWORK_STATUS=$SEKAID_STATUS
                KIRA_BLOCK=$KIRA_BLOCK_TMP
            fi
        done
        CONTAINERS_COUNT=$((i + 1))
    fi

    [ "$LOCAL_IP" == "172.17.0.1" ] && LOCAL_IP="0.0.0.0"
    [ "$LOCAL_IP" == "172.16.0.1" ] && LOCAL_IP="0.0.0.0"
    [ -z "$LOCAL_IP" ] && LOCAL_IP="0.0.0.0"

    printf "\033c"

    ALLOWED_OPTIONS="x"
    echo -e "\e[33;1m------------------------------------------------- [mode]"
    echo "|         KIRA NETWORK MANAGER v0.0.8           : $INFRA_MODE mode"
    echo "|------------ $(date '+%d/%m/%Y %H:%M:%S') --------------|"
    CPU_TMP="CPU: ${CPU_UTIL}${WHITESPACE}"
    RAM_TMP="RAM: ${RAM_UTIL}${WHITESPACE}"
    DISK_TMP="DISK: ${DISK_UTIL}${WHITESPACE}"

    [ ! -z "$CPU_UTIL" ] && [ ! -z "$RAM_UTIL" ] && [ ! -z "$DISK_UTIL" ] && \
    echo -e "|\e[35;1m ${CPU_TMP:0:16}${RAM_TMP:0:18}${DISK_TMP:0:11} \e[33;1m|"

    if [ "${LOADING,,}" == "false" ] ; then
        KIRA_NETWORK=$(echo $NETWORK_STATUS | jq -r '.NodeInfo.network' 2> /dev/null || echo "???") && [ -z "$KIRA_NETWORK" ] && KIRA_NETWORK="???"
        ( [ -z "$NETWORK_STATUS" ] || [ "${NETWORK_STATUS,,}" == "null" ] ) && KIRA_NETWORK=$(echo $NETWORK_STATUS | jq -r '.node_info.network' 2> /dev/null || echo "???") && [ -z "$KIRA_NETWORK" ] && KIRA_NETWORK="???"
        KIRA_BLOCK=$(echo $NETWORK_STATUS | jq -r '.SyncInfo.latest_block_height' 2> /dev/null || echo "???") && [ -z "$KIRA_BLOCK" ] && KIRA_BLOCK="???"
        ( [ -z "$KIRA_BLOCK" ] || [ "${KIRA_BLOCK,,}" == "null" ] || [[ ! $KIRA_BLOCK =~ ^[0-9]+$ ]] ) && KIRA_BLOCK=$(echo $NETWORK_STATUS | jq -r '.sync_info.latest_block_height' 2> /dev/null || echo "???") && [ -z "$KIRA_BLOCK" ] && KIRA_BLOCK="???"
        [[ ! $KIRA_BLOCK =~ ^[0-9]+$ ]] && KIRA_BLOCK="???"

        if [ -f "$GENESIS_JSON" ] ; then
            GENESIS_SUM=$(sha256sum $GENESIS_JSON | awk '{ print $1 }')
            GENESIS_SUM="$(echo $GENESIS_SUM | head -c 4)...$(echo $GENESIS_SUM | tail -c 5)"
        else
            GENESIS_SUM="genesis not found"
        fi

        KIRA_NETWORK_TMP="NETWORK: ${KIRA_NETWORK}${WHITESPACE}"
        KIRA_BLOCK_TMP="BLOCKS: ${KIRA_BLOCK}${WHITESPACE}"
        echo -e "|\e[35;1m ${KIRA_NETWORK_TMP:0:22}${KIRA_BLOCK_TMP:0:23} \e[33;1m: $GENESIS_SUM"
    else
        KIRA_BLOCK="???"
    fi

    LOCAL_IP="L.IP: $LOCAL_IP                                               "
    [ ! -z "$PUBLIC_IP" ] && PUBLIC_IP="$PUBLIC_IP                          "
    [ -z "$PUBLIC_IP" ] && \
    echo -e "|\e[35;1m ${LOCAL_IP:0:22}PUB.IP: \e[31;1mdisconnected\e[33;1m    : $IFACE" || \
    echo -e "|\e[35;1m ${LOCAL_IP:0:22}PUB.IP: ${PUBLIC_IP:0:15}\e[33;1m : $IFACE"

    if [ -f "$KIRA_SNAP_PATH" ] ; then # snapshot is present 
        SNAP_FILENAME="SNAPSHOT: $(basename -- "$KIRA_SNAP_PATH")${WHITESPACE}"
        SNAP_SHA256=$(sha256sum $KIRA_SNAP_PATH | awk '{ print $1 }')
        [ "${SNAP_EXPOSE,,}" == "true" ] && \
        echo -e "|\e[32;1m ${SNAP_FILENAME:0:45} \e[33;1m: $(echo $SNAP_SHA256 | head -c 4)...$(echo $SNAP_SHA256 | tail -c 5)" || \
        echo -e "|\e[31;1m ${SNAP_FILENAME:0:45} \e[33;1m: $(echo $SNAP_SHA256 | head -c 4)...$(echo $SNAP_SHA256 | tail -c 5)"
    fi

    if [ "${LOADING,,}" == "true" ] ; then
        echo -e "|\e[0m\e[31;1m PLEASE WAIT, LOADING INFRASTRUCTURE STATUS... \e[33;1m|"
    elif [ $CONTAINERS_COUNT -lt $INFRA_CONTAINER_COUNT ]; then
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, NOT ALL CONTAINERS LAUNCHED  \e[33;1m|"
    elif [ "${ALL_CONTAINERS_HEALTHY,,}" != "true" ]; then
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRASTRUCTURE IS UNHEALTHY  \e[33;1m|"
    elif [ "${CATCHING_UP,,}" == "true" ] ; then
        echo -e "|\e[0m\e[33;1m     PLEASE WAIT, NODES ARE CATCHING UP        \e[33;1m|"
    elif [ "${SUCCESS,,}" == "true" ] && [ "${ALL_CONTAINERS_HEALTHY,,}" == "true" ] ; then
        if [ ! -z "$VALADDR" ] ; then
            [ "${VALSTATUS,,}" == "active" ] && \
            echo -e "|\e[0m\e[32;1m    SUCCESS, VALIDATOR AND INFRA IS HEALTHY    \e[33;1m: $VALSTATUS" || \
            echo -e "|\e[0m\e[31;1m   FAILURE, VALIDATOR NODE IS NOT OPERATIONAL  \e[33;1m: $VALSTATUS"
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

    if [ "${LOADING,,}" == "false" ] ; then
        echo "|-----------------------------------------------| [health]"
        i=-1
        for name in $CONTAINERS; do
            i=$((i + 1))
            STATUS_TMP="STATUS_$name" && STATUS_TMP="${!STATUS_TMP}"
            HEALTH_TMP="HEALTH_$name" && HEALTH_TMP="${!HEALTH_TMP}"
            [ "${HEALTH_TMP,,}" == "null" ] && HEALTH_TMP="" # do not display
            [ "${name,,}" == "snapshot" ] && [ "${STATUS_TMP,,}" == "running" ] && STATUS_TMP="$PROGRESS_SNAP"

            if [[ "${name,,}" =~ ^(validator|sentry|priv_sentry|interx)$ ]] && [[ "${STATUS_TMP,,}" =~ ^(running|starting)$ ]] ; then
                LATEST_BLOCK=$(cat "$STATUS_SCAN_PATH/${name}.sekaid.latest_block_height" 2> /dev/null || echo "")
                CATCHING_UP=$(cat "$STATUS_SCAN_PATH/${name}.sekaid.catching_up" 2> /dev/null || echo "false")
                ( [ -z "$LATEST_BLOCK" ] || [ -z "${LATEST_BLOCK##*[!0-9]*}" ] ) && LATEST_BLOCK=0

                if [ "${CATCHING_UP,,}" == "true" ] ; then
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
        while [ ! -f $SCAN_DONE ] ; do
            sleep 1
        done
        LOADING="false"
        continue
    fi
    
    echo "|-----------------------------------------------|"
    if [ "$CONTAINERS_COUNT" != "0" ] && [ "${LOADING,,}" == "false" ] ; then
        [ "${ALL_CONTAINERS_PAUSED,,}" == "false" ] && \
            echo "| [P] | PAUSE All Containers                    |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p" || \
            echo "| [P] | Un-PAUSE All Containers                 |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p"
        echo "| [R] | RESTART All Containers                  |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}r"
        [ "${ALL_CONTAINERS_STOPPED,,}" == "false" ] && \
            echo "| [S] | STOP All Containers                     |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s" || \
            echo "| [S] | START All Containers                    |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s"
        echo "|-----------------------------------------------|"
    fi
    
    [ $ESSENTIAL_CONTAINERS_COUNT -ge 2 ] && \
    echo "| [B] | BACKUP Chain State                      |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}b"

    if [ ! -z "$KIRA_SNAP_PATH" ] ; then
        [ "${SNAP_EXPOSE,,}" == "false" ] && \
        echo "| [E] | EXPOSE Snapshot                         |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}e" || \
        echo "| [E] | Hide EXPOSED Snapshot                   |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}e"
    fi

    echo "| [D] | DUMP All Loggs                          |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}d"
    echo "| [N] | Manage NETWORKING & Firewall            |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}n"
    echo "| [I] | Re-INITALIZE Infrastructure             |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}i"
    echo -e "| [X] | Exit __________________________________ |\e[0m"

    OPTION="" && read -s -n 1 -t 10 OPTION || OPTION=""
    [ -z "$OPTION" ] && continue
    [[ "${ALLOWED_OPTIONS,,}" != *"$OPTION"* ]] && continue

    if [ "${OPTION,,}" != "x" ] && [[ $OPTION != ?(-)+([0-9]) ]] ; then
        ACCEPT="" && while ! [[ "${ACCEPT,,}" =~ ^(y|n)$ ]] ; do echoNErr "Press [Y]es to confirm option (${OPTION^^}) or [N]o to cancel: " && read -d'' -s -n1 ACCEPT && echo ""; done
        [ "${ACCEPT,,}" == "n" ] && echo -e "\nWARINIG: Operation was cancelled\n" && sleep 1 && continue
        echo ""
    fi

    if [ "${OPTION,,}" == "r" ] ; then
        echo "INFO: Reconnecting all networks..."
        $KIRAMGR_SCRIPTS/restart-networks.sh "true"
    fi

    EXECUTED="false"
    i=-1
    for name in $CONTAINERS; do
        i=$((i + 1))
        if [ "$OPTION" == "$i" ]; then
            source $KIRA_MANAGER/kira/container-manager.sh $name
            OPTION="" # reset option
            EXECUTED="true"
            break
        elif [ "${OPTION,,}" == "d" ]; then
            echo "INFO: Dumping all loggs from $name container..."
            $KIRAMGR_SCRIPTS/dump-logs.sh $name "false"
            EXECUTED="true"
        elif [ "${OPTION,,}" == "r" ]; then
            echo "INFO: Re-starting $name container..."
            $KIRA_SCRIPTS/container-restart.sh $name
            EXECUTED="true"
            LOADING="true"
        elif [ "${OPTION,,}" == "s" ]; then
            if [ "${ALL_CONTAINERS_STOPPED,,}" == "false" ] ; then
                echo "INFO: Stopping $name container..."
                $KIRA_SCRIPTS/container-stop.sh $name
            else
                echo "INFO: Staring $name container..."
                $KIRA_SCRIPTS/container-start.sh $name
            fi
            LOADING="true"
            EXECUTED="true"
        elif [ "${OPTION,,}" == "p" ]; then
            if [ "${ALL_CONTAINERS_PAUSED,,}" == "false" ]; then
                echo "INFO: Stopping $name container..."
                $KIRA_SCRIPTS/container-pause.sh $name
            else
                echo "INFO: Staring $name container..."
                $KIRA_SCRIPTS/container-unpause.sh $name
            fi
            LOADING="true"
            EXECUTED="true"
        fi
    done

    if [ "${OPTION,,}" == "d" ]; then
        echo "INFO: Dumping firewal info..."
        ufw status verbose > "$KIRA_DUMP/ufw-status.txt" || echo "INFO: Failed to get firewal status"
        echo "INFO: Compresing all dumped files..."
        ZIP_FILE="$KIRA_DUMP/kira.zip"
        rm -fv $ZIP_FILE
        zip -9 -r -v $ZIP_FILE $KIRA_DUMP
        echo "INFO: All dump files were exported into $ZIP_FILE"
    elif [ "${OPTION,,}" == "s" ] && [ "${ALL_CONTAINERS_STOPPED,,}" != "false" ] ; then
        echo "INFO: Reconnecting all networks..."
        $KIRAMGR_SCRIPTS/restart-networks.sh "true"
        echo "INFO: Reinitalizing firewall..."
        $KIRA_MANAGER/networking.sh
    elif [ "${OPTION,,}" == "b" ] ; then
        echo "INFO: Backing up blockchain state..."
        $KIRA_MANAGER/kira/kira-backup.sh "$KIRA_BLOCK" || echo "ERROR: Snapshot failed"
        LOADING="true"
        EXECUTED="true"
    elif [ "${OPTION,,}" == "n" ] ; then
        echo "INFO: Staring networking manager..."
        $KIRA_MANAGER/kira/kira-networking.sh || echo "ERROR: Network manager failed"
        LOADING="true"
        EXECUTED="true"
        OPTION=""
    elif [ "${OPTION,,}" == "e" ] ; then
        if [ "${SNAP_EXPOSE,,}" == "false" ] ; then
            echo "INFO: Exposing latest snapshot '$KIRA_SNAP_PATH' via INTERX"
            CDHelper text lineswap --insert="SNAP_EXPOSE=\"true\"" --prefix="SNAP_EXPOSE=" --path=$ETC_PROFILE --append-if-found-not=True
            echoInfo "INFO: Await few minutes and your snapshot will become available via 0.0.0.0:$KIRA_INTERX_PORT/download/snapshot.zip"
        else
            echoInfo "INFO: Ensuring exposed snapshot will be removed..."
            CDHelper text lineswap --insert="SNAP_EXPOSE=\"false\"" --prefix="SNAP_EXPOSE=" --path=$ETC_PROFILE --append-if-found-not=True
            echoInfo "INFO: Await few minutes and your snapshot will become unavailable"
        fi
        LOADING="true"
        EXECUTED="true"
    elif [ "${OPTION,,}" == "x" ]; then
        printf "\033c"
        echo "INFO: Stopping kira network scanner..."
        systemctl stop kirascan
        exit 0
    fi

    [ "${LOADING,,}" == "true" ] && rm -fv $SCAN_DONE # trigger re-scan
    [ "${EXECUTED,,}" == "true" ] && [ ! -z $OPTION ] && echoNErr "INFO: Option ($OPTION) was executed, press any key to continue..." && read -n 1 -s && echo ""

    if [ "${OPTION,,}" == "i" ]; then
        cd $HOME
        systemctl stop kirascan
        source $KIRA_MANAGER/kira/kira-reinitalize.sh
        source $KIRA_MANAGER/kira/kira.sh
        exit 0
    fi
done
