#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

set +x
echo "INFO: Launching KIRA Network Manager..."
cd $KIRA_HOME
SCAN_DIR="$KIRA_HOME/kirascan"
CONTAINERS_SCAN_PATH="$SCAN_DIR/containers"
NETWORKS_SCAN_PATH="$SCAN_DIR/networks"
DISK_SCAN_PATH="$SCAN_DIR/disk"
CPU_SCAN_PATH="$SCAN_DIR/cpu"
RAM_SCAN_PATH="$SCAN_DIR/ram"
LIP_SCAN_PATH="$SCAN_DIR/lip"
IP_SCAN_PATH="$SCAN_DIR/ip"

TMP_DIR="/tmp/kira-stats" # performance counters directory
PID_DIR="$TMP_DIR/pid"
VARSMGR_PATH="$TMP_DIR/varsmgr" # file contianing cached variables with details regarding individual containers
WHITESPACE="                                                          "

rm -fvr $PID_DIR # wipe all process id's

mkdir -p "$TMP_DIR" "$PID_DIR"

rm -fv $VARSMGR_PATH
rm -fv "${VARSMGR_PATH}.lock"

touch $VARSMGR_PATH && chmod 777 $VARSMGR_PATH

echo "INFO: Wiping halt files of all containers..."
rm -fv $DOCKER_COMMON/validator/halt
rm -fv $DOCKER_COMMON/sentry/halt
rm -fv $DOCKER_COMMON/interx/halt
rm -fv $DOCKER_COMMON/frontend/halt

LOADING="true"
while :; do
    START_TIME="$(date -u +%s)"
    NETWORKS=$(cat $NETWORKS_SCAN_PATH 2> /dev/null || echo "")
    CONTAINERS=$(docker ps -a | awk '{if(NR>1) print $NF}' | tac)

    i=-1
    for name in $CONTAINERS; do
        i=$((i + 1))
        touch "$PID_DIR/${name}.pid" && if ! kill -0 $(cat "$PID_DIR/${name}.pid") 2> /dev/null ; then
            [ "${LOADING,,}" == "true" ] && rm -f "$VARSMGR_PATH-$name" && touch "$VARSMGR_PATH-$name"
            $KIRA_MANAGER/kira/container-status.sh $name "$VARSMGR_PATH-$name" $NETWORKS & 
            echo "$!" > "$PID_DIR/${name}.pid"
        fi
    done

    CPU_UTIL=$(cat $CPU_SCAN_PATH 2> /dev/null || echo "")
    RAM_UTIL=$(cat $RAM_SCAN_PATH 2> /dev/null || echo "")
    DISK_UTIL=$(cat $DISK_SCAN_PATH 2> /dev/null || echo "")
    LOCAL_IP=$(cat $LIP_SCAN_PATH 2> /dev/null || echo "0.0.0.0")
    PUBLIC_IP=$(cat $IP_SCAN_PATH 2> /dev/null || echo "")

    CONTAINERS_COUNT=$((i + 1))
    STATUS_SOURCE="validator"
    NETWORK_STATUS=$(docker exec -i "$STATUS_SOURCE" sekaid status 2> /dev/null | jq -r '.' 2> /dev/null || echo "")

    for name in $CONTAINERS; do
        if [ -f "$VARSMGR_PATH-$name" ] ; then
            source "$VARSMGR_PATH-$name"
        fi
    done

    if [ "${LOADING,,}" == "false" ] ; then
        SUCCESS="true"
        IS_ANY_CONTAINER_RUNNING="false"
        IS_ANY_CONTAINER_PAUSED="false"
        ALL_CONTAINERS_PAUSED="true"
        ALL_CONTAINERS_STOPPED="true"
        ALL_CONTAINERS_HEALTHY="true"
        i=-1
        for name in $CONTAINERS; do
            i=$((i + 1))
            STATUS_TMP="STATUS_$name" && STATUS_TMP="${!STATUS_TMP}"
            HEALTH_TMP="HEALTH_$name" && HEALTH_TMP="${!HEALTH_TMP}"
            [ "${STATUS_TMP,,}" != "running" ] && SUCCESS="false"
            [ "${name,,}" == "registry" ] && continue
            [ "${HEALTH_TMP,,}" != "healthy" ] && ALL_CONTAINERS_HEALTHY="false"
            [ "${STATUS_TMP,,}" != "exited" ] && ALL_CONTAINERS_STOPPED="false"
            [ "${STATUS_TMP,,}" != "paused" ] && ALL_CONTAINERS_PAUSED="false"
            [ "${STATUS_TMP,,}" == "running" ] && IS_ANY_CONTAINER_RUNNING="true"
            [ "${STATUS_TMP,,}" == "paused" ] && IS_ANY_CONTAINER_PAUSED="true"
            # TODO: show failed status if any of the healthchecks fails
    
            # if block height check fails via validator then try via interx
            if [ "${name,,}" == "interx" ] && [ "${STATUS_TMP,,}" == "running" ] && [ -z "${NETWORK_STATUS,,}" ]; then
                STATUS_SOURCE="$name"
                NETWORK_STATUS=$(curl -s -m 1 http://$KIRA_INTERX_DNS:$KIRA_INTERX_PORT/api/status 2>/dev/null || echo "")
            fi
    
            # if block height check fails via validator then try via sentry
            if [ "${name,,}" == "sentry" ] && [ "${STATUS_TMP,,}" == "running" ] && [ -z "${NETWORK_STATUS,,}" ]; then
                STATUS_SOURCE="$name"
                NETWORK_STATUS=$(docker exec -i "$name" sekaid status 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
            fi
        done
    fi

    KIRA_NETWORK=$(echo $NETWORK_STATUS | jq -r '.node_info.network' 2> /dev/null || echo "???") && [ -z "$KIRA_NETWORK" ] && KIRA_NETWORK="???"
    KIRA_BLOCK=$(echo $NETWORK_STATUS | jq -r '.sync_info.latest_block_height' 2> /dev/null || echo "???") && [ -z "$KIRA_BLOCK" ] && KIRA_BLOCK="???"
    [ "$LOCAL_IP" == "172.17.0.1" ] && LOCAL_IP="0.0.0.0"
    [ "$LOCAL_IP" == "172.16.0.1" ] && LOCAL_IP="0.0.0.0"
    [ -z "$LOCAL_IP" ] && LOCAL_IP="0.0.0.0"

    clear

    ALLOWED_OPTIONS="x"
    echo -e "\e[33;1m------------------------------------------------- [mode]"
    echo "|         KIRA NETWORK MANAGER v0.0.6           : $INFRA_MODE"
    echo "|------------ $(date '+%d/%m/%Y %H:%M:%S') --------------|"
    CPU_TMP="CPU: ${CPU_UTIL}${WHITESPACE}"
    RAM_TMP="RAM: ${RAM_UTIL}${WHITESPACE}"
    DISK_TMP="DISK: ${DISK_UTIL}${WHITESPACE}"
    echo -e "|\e[34;1m ${CPU_TMP:0:16}${RAM_TMP:0:18}${DISK_TMP:0:11} \e[33;1m|"

    KIRA_NETWORK="NETWORK: ${KIRA_NETWORK}${WHITESPACE}"
    KIRA_BLOCK="BLOCKS: ${KIRA_BLOCK}${WHITESPACE}"
    echo -e "|\e[35;1m ${KIRA_NETWORK:0:22}${KIRA_BLOCK:0:23} \e[33;1m: $STATUS_SOURCE"

    LOCAL_IP="L.IP: $LOCAL_IP                                               "
    [ ! -z "$PUBLIC_IP" ] && PUBLIC_IP="$PUBLIC_IP                          "
    [ -z "$PUBLIC_IP" ] && echo -e "|\e[35;1m ${LOCAL_IP:0:22}PUB.IP: \e[31;1mdisconnected\e[33;1m    : $IFACE"
    [ ! -z "$PUBLIC_IP" ] && echo -e "|\e[35;1m ${LOCAL_IP:0:22}PUB.IP: ${PUBLIC_IP:0:15}\e[33;1m : $IFACE"

    if [ "${LOADING,,}" == "true" ] ; then
        echo -e "|\e[0m\e[31;1m PLEASE WAIT, LOADING INFRASTRUCTURE STATUS... \e[33;1m|"
    elif [ $CONTAINERS_COUNT -lt $INFRA_CONTAINER_COUNT ]; then
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, NOT ALL CONTAINERS LAUNCHED  \e[33;1m|"
    elif [ "${ALL_CONTAINERS_HEALTHY,,}" != "true" ]; then
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRASTRUCTURE IS UNHEALTHY  \e[33;1m|"
    elif [ "${SUCCESS,,}" == "true" ] && [ "${ALL_CONTAINERS_HEALTHY,,}" == "true" ]; then
        echo -e "|\e[0m\e[32;1m     SUCCESS, INFRASTRUCTURE IS HEALTHY        \e[33;1m|"
    else
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRA. IS NOT OPERATIONAL    \e[33;1m|"
    fi

    if [ "${LOADING,,}" == "false" ] ; then
        echo "|-----------------------------------------------| [health]"
        i=-1
        for name in $CONTAINERS; do
            i=$((i + 1))
            STATUS_TMP="STATUS_$name" && STATUS_TMP="${!STATUS_TMP}"
            HEALTH_TMP="HEALTH_$name" && HEALTH_TMP="${!HEALTH_TMP}"
            [ "${HEALTH_TMP,,}" == "null" ] && HEALTH_TMP="" # do not display
            LABEL="| [$i] | Manage $name ($STATUS_TMP)                           "
            echo "${LABEL:0:47} : $HEALTH_TMP" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}${i}"
        done
    fi

    [ "${LOADING,,}" == "true" ] && wait && LOADING="false" && continue
   
    echo "|-----------------------------------------------|"
    if [ "$CONTAINERS_COUNT" != "0" ] && [ "${LOADING,,}" == "false" ] ; then
        [ "${ALL_CONTAINERS_PAUSED,,}" == "false" ] && \
            echo "| [P] | PAUSE All Containers                    |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p"
        [ "${ALL_CONTAINERS_PAUSED,,}" == "true" ] && \
            echo "| [P] | Un-PAUSE All Containers                 |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p"
        echo "| [R] | RESTART All Containers                  |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}r"
        [ "${ALL_CONTAINERS_STOPPED,,}" == "false" ] && \
            echo "| [S] | STOP All Containers                     |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s"
        [ "${ALL_CONTAINERS_STOPPED,,}" == "true" ] && \
            echo "| [S] | START All Containers                    |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s"
        echo "|-----------------------------------------------|"
    fi
    echo "| [D] | DUMP All Loggs                          |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}d"
    echo "| [I] | Re-INITALIZE Infrastructure             |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}i"
    echo -e "| [X] | Exit __________________________________ |\e[0m"

    OPTION="" && read -s -n 1 -t 5 OPTION || OPTION=""
    [ -z "$OPTION" ] && continue
    [[ "${ALLOWED_OPTIONS,,}" != *"$OPTION"* ]] && continue

    if [ "${OPTION,,}" != "x" ] && [[ $OPTION != ?(-)+([0-9]) ]] ; then
        ACCEPT="" && while [ "${ACCEPT,,}" != "y" ] && [ "${ACCEPT,,}" != "n" ]; do echo -en "\e[33;1mPress [Y]es to confirm option (${OPTION^^}) or [N]o to cancel: \e[0m\c" && read -d'' -s -n1 ACCEPT && echo ""; done
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
            rm -fv $VARSMGR_PATH && touch $VARSMGR_PATH && LOADING="true" # reload
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
        zip -r -q $ZIP_FILE $KIRA_DUMP
        echo "INFO: All dump files were exported into $ZIP_FILE"
    elif [ "${OPTION,,}" == "s" ] && [ "${ALL_CONTAINERS_STOPPED,,}" != "false" ] ; then
        echo "INFO: Reconnecting all networks..."
        $KIRAMGR_SCRIPTS/restart-networks.sh "true"
        echo "INFO: Reinitalizing firewall..."
        $KIRA_MANAGER/networking.sh
    elif [ "${OPTION,,}" == "x" ]; then
        clear
        exit 0
    fi

    if [ "${EXECUTED,,}" == "true" ] && [ ! -z $OPTION ]; then
        echo -en "\e[31;1mINFO: Option ($OPTION) was executed, press any key to continue...\e[0m" && read -n 1 -s && echo ""
    fi

    if [ "${OPTION,,}" == "i" ]; then
        cd $HOME
        source $KIRA_MANAGER/kira/kira-reinitalize.sh
        source $KIRA_MANAGER/kira/kira.sh
        exit 0
    fi
done
