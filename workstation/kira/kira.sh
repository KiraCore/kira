#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

set +x
echo "INFO: Launching KIRA Network Manager..."
PERF_DIR="/tmp/performance" # performance counters directory
PERF_CPU="$PERF_DIR/cpu"
mkdir -p $PERF_DIR
echo "0%" >$PERF_CPU

echo "INFO: Wiping halt files of all containers..."
rm -fv $DOCKER_COMMON/validator/halt
rm -fv $DOCKER_COMMON/sentry/halt
rm -fv $DOCKER_COMMON/interx/halt
rm -fv $DOCKER_COMMON/frontend/halt

while :; do
    START_TIME="$(date -u +%s)"
    CONTAINERS=$(docker ps -a | awk '{if(NR>1) print $NF}' | tac)
    VARS_FILE="/tmp/kira_mgr_vars" # file contianing cached variables with details regarding individual containers
    NETWORKS=$(docker network ls --format="{{.Name}}" || "")

    #free -m | grep "Mem:"
    mpstat -o JSON -u 1 2 | jq '.sysstat.hosts[0].statistics[0]["cpu-load"][0].idle' | awk '{print 100 - $1"%"}' >$PERF_CPU &
    rm -f $VARS_FILE && touch $VARS_FILE && chmod 777 $VARS_FILE
    i=-1
    for name in $CONTAINERS; do
        i=$((i + 1))
        $KIRA_MANAGER/kira/container-status.sh $name $VARS_FILE $NETWORKS &
    done

    CONTAINERS_COUNT=$((i + 1))
    RAM_UTIL="$(awk '/MemFree/{free=$2} /MemTotal/{total=$2} END{print (100-((free*100)/total))}' /proc/meminfo)%"
    DISK_UTIL="$(df --output=pcent / | tail -n 1 | tr -d '[:space:]|%')%"

    STATUS_SOURCE="validator"
    NETWORK_STATUS=$(docker exec -i "$STATUS_SOURCE" sekaid status 2>/dev/null | jq -r '.' 2>/dev/null || echo "Error")

    wait # wait for all subprocesses to finish
    source $VARS_FILE
    CPU_UTIL=$(cat $PERF_CPU)

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
        if [ "${name,,}" == "interx" ] && [ "${STATUS_TMP,,}" == "running" ] && [ "${NETWORK_STATUS,,}" == "error" ]; then
            STATUS_SOURCE="$name"
            NETWORK_STATUS=$(curl -s -m 1 http://10.4.0.2:11000/api/status || echo "Error")
        fi

        # if block height check fails via validator then try via sentry
        if [ "${name,,}" == "sentry" ] && [ "${STATUS_TMP,,}" == "running" ] && [ "${NETWORK_STATUS,,}" == "error" ]; then
            STATUS_SOURCE="$name"
            NETWORK_STATUS=$(docker exec -i "$name" sekaid status 2>/dev/null | jq -r '.' 2>/dev/null || echo "Error")
        fi
    done

    KIRA_NETWORK=$(echo $NETWORK_STATUS | jq -r '.node_info.network' 2>/dev/null || echo "???") && [ -z "$KIRA_NETWORK" ] && KIRA_NETWORK="???"
    KIRA_BLOCK=$(echo $NETWORK_STATUS | jq -r '.sync_info.latest_block_height' 2>/dev/null || echo "???") && [ -z "$KIRA_BLOCK" ] && KIRA_BLOCK="???"

    clear

    ALLOWED_OPTIONS="x"
    echo -e "\e[33;1m------------------------------------------------- [mode]"
    echo "|         KIRA NETWORK MANAGER v0.0.6           : $INFRA_MODE"
    echo "|------------ $(date '+%d/%m/%Y %H:%M:%S') --------------|"
    CPU_UTIL="CPU: $CPU_UTIL                                                 "
    RAM_UTIL="RAM: $RAM_UTIL                                                 "
    DISK_UTIL="DISK: $DISK_UTIL                                                 "
    echo -e "|\e[34;1m ${CPU_UTIL:0:16}${RAM_UTIL:0:18}${DISK_UTIL:0:11} \e[33;1m|"

    KIRA_NETWORK="NETWORK: $KIRA_NETWORK                                               "
    KIRA_BLOCK="BLOCK HEIGHT: $KIRA_BLOCK                                              "
    echo -e "|\e[35;1m ${KIRA_NETWORK:0:23}${KIRA_BLOCK:0:22} \e[33;1m: $STATUS_SOURCE"

    if [ $CONTAINERS_COUNT -lt $INFRA_CONTAINER_COUNT ]; then
        SUCCESS="false"
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, NOT ALL CONTAINERS LAUNCHED  \e[33;1m|"
    elif [ "${ALL_CONTAINERS_HEALTHY,,}" != "true" ]; then
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRASTRUCTURE IS UNHEALTHY  \e[33;1m|"
    elif [ "${SUCCESS,,}" == "true" ] && [ "${ALL_CONTAINERS_HEALTHY,,}" == "true" ]; then
        echo -e "|\e[0m\e[32;1m     SUCCESS, INFRASTRUCTURE IS HEALTHY        \e[33;1m|"
    else
        echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRA. IS NOT OPERATIONAL    \e[33;1m|"
    fi

    echo "|-----------------------------------------------| [health]"
    i=-1
    for name in $CONTAINERS; do
        i=$((i + 1))
        STATUS_TMP="STATUS_$name" && STATUS_TMP="${!STATUS_TMP}"
        HEALTH_TMP="HEALTH_$name" && HEALTH_TMP="${!HEALTH_TMP}"
        [ "${HEALTH_TMP,,}" == "null" ] && HEALTH_TMP="" # do not display
        LABEL="| [$i] | Mange $name ($STATUS_TMP)                           "
        echo "${LABEL:0:47} : $HEALTH_TMP" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}${i}"
    done
    echo "|-----------------------------------------------|"
    if [ "$CONTAINERS_COUNT" != "0" ]; then
        [ "${ALL_CONTAINERS_PAUSED,,}" == "false" ] && \
            echo "| [P] | PAUSE All Containers                    |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p"
        [ "${IS_ANY_CONTAINER_PAUSED,,}" == "true" ] && \
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

    read -s -n 1 -t 6 OPTION || continue
    [ -z "$OPTION" ] && continue
    [[ "${ALLOWED_OPTIONS,,}" != *"$OPTION"* ]] && continue

    ACCEPT="" && while [ "${ACCEPT,,}" != "y" ] && [ "${ACCEPT,,}" != "n" ]; do echo -en "\e[33;1mPress [Y]es to confirm option (${OPTION^^}) or [N]o to cancel: \e[0m\c" && read -d'' -s -n1 ACCEPT && echo ""; done
    [ "${ACCEPT,,}" == "n" ] && echo -e "\nWARINIG: Operation was cancelled\n" && sleep 1 && continue
    echo ""

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
            $KIRAMGR_SCRIPTS/dump-logs.sh $name
            EXECUTED="true"
        elif [ "${OPTION,,}" == "r" ]; then
            echo "INFO: Re-starting $name container..."
            $KIRA_SCRIPTS/container-restart.sh $name
            EXECUTED="true"
        elif [ "${OPTION,,}" == "s" ]; then
            if [ "${ALL_CONTAINERS_STOPPED,,}" == "false" ] ; then
                echo "INFO: Stopping $name container..."
                $KIRA_SCRIPTS/container-stop.sh $name
            else
                echo "INFO: Staring $name container..."
                $KIRA_SCRIPTS/container-start.sh $name
            fi
            EXECUTED="true"
        elif [ "${OPTION,,}" == "p" ]; then
            if [ "${ALL_CONTAINERS_PAUSED,,}" == "false" ]; then
                echo "INFO: Stopping $name container..."
                $KIRA_SCRIPTS/container-pause.sh $name
            else
                echo "INFO: Staring $name container..."
                $KIRA_SCRIPTS/container-unpause.sh $name
            fi
            EXECUTED="true"
        fi
    done

    if [ "${OPTION,,}" == "d" ]; then
        echo "INFO: Compresing all dumped files..."
        ZIP_FILE="$KIRA_DUMP/kira.zip"
        rm -fv $ZIP_FILE
        zip -r -q $ZIP_FILE $KIRA_DUMP
        echo "INFO: All dump files were exported into $ZIP_FILE"
    elif [ "${OPTION,,}" == "r" ] || ([ "${OPTION,,}" == "s" ] && [ "${ALL_CONTAINERS_STOPPED,,}" != "false" ]) ; then
        echo "INFO: Reconnecting all networks..."
        $KIRAMGR_SCRIPTS/restart-networks.sh
    fi

    if [ "${EXECUTED,,}" == "true" ] && [ ! -z $OPTION ]; then
        echo "INFO: Option ($OPTION) was executed, press any key to continue..."
        read -s -n 1 || continue
    fi

    if [ "${OPTION,,}" == "i" ]; then
        cd $HOME
        source $KIRA_MANAGER/kira/kira-reinitalize.sh
        source $KIRA_MANAGER/kira/kira.sh
        exit 0
    elif [ "${OPTION,,}" == "x" ]; then
        clear
        exit 0
    fi
done
