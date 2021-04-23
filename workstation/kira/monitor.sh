#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat
set -x

SCRIPT_START_TIME="$(date -u +%s)"
echoInfo "INFO: Started kira network scan $KIRA_SETUP_VER"

SCAN_LOGS="$KIRA_SCAN/logs"
SCAN_DONE="$KIRA_SCAN/done"
CONTAINERS_SCAN_PATH="$KIRA_SCAN/containers"
NETWORKS_SCAN_PATH="$KIRA_SCAN/networks"
HOSTS_SCAN_PATH="$KIRA_SCAN/hosts"
STATUS_SCAN_PATH="$KIRA_SCAN/status"
VALINFO_SCAN_PATH="$KIRA_SCAN/valinfo"
SNAPSHOT_SCAN_PATH="$KIRA_SCAN/snapshot"
HARDWARE_SCAN_PATH="$KIRA_SCAN/hardware"
PEERS_SCAN_PATH="$KIRA_SCAN/peers"

SNAP_STATUS="$KIRA_SNAP/status"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_LATEST="$SNAP_STATUS/latest"

SCAN_DUMP="$KIRA_DUMP/kirascan"

while : ; do

    TIME_ELAPSED=$(($(date -u +%s) - $SCRIPT_START_TIME))
    [[ $TIME_ELAPSED -gt 300 ]] && echoErr "ERROR: Scan service was not finalized for the last 5 minutes" && sleep 10 && exit 1

    START_TIME="$(date -u +%s)"
    if ! kill -0 $(tryCat "${CONTAINERS_SCAN_PATH}.pid") 2>/dev/null; then
        mkdir -p $KIRA_SCAN $STATUS_SCAN_PATH $SCAN_LOGS $SNAP_STATUS $SCAN_DUMP
        touch $CONTAINERS_SCAN_PATH "$NETWORKS_SCAN_PATH" "$VALINFO_SCAN_PATH" "$SNAPSHOT_SCAN_PATH" "$CONTAINERS_SCAN_PATH"

        set +e && source "/etc/profile" &>/dev/null && set -e

        echo $(docker network ls --format="{{.Name}}" || echo -n "") > $NETWORKS_SCAN_PATH &
        PID1="$!"

        echo $(docker ps -a | awk '{if(NR>1) print $NF}' | tac || echo -n "") > $CONTAINERS_SCAN_PATH &
        PID2="$!"

        if ! kill -0 $(tryCat "${HOSTS_SCAN_PATH}.pid") 2>/dev/null; then
            echoInfo "INFO: Starting hosts update..."
            LOG_FILE="$HOSTS_SCAN_PATH.log"
            (! $(isFileEmpty $LOG_FILE)) && cp -afv $LOG_FILE $SCAN_DUMP || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
            $KIRA_MANAGER/scripts/update-hosts.sh &> $LOG_FILE &
            echo "$!" >"${HOSTS_SCAN_PATH}.pid"
        else
            sleep 1
        fi

        if ! kill -0 $(tryCat "${HARDWARE_SCAN_PATH}.pid") 2>/dev/null; then
            echoInfo "INFO: Starting hardware monitor..."
            LOG_FILE="$HARDWARE_SCAN_PATH.log"
            (! $(isFileEmpty $LOG_FILE)) && cp -afv $LOG_FILE $SCAN_DUMP || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
            $KIRA_MANAGER/kira/monitor-hardware.sh &> $LOG_FILE &
            echo "$!" >"${HARDWARE_SCAN_PATH}.pid"
        else
            sleep 1
        fi

        if ! kill -0 $(tryCat "${VALINFO_SCAN_PATH}.pid") 2>/dev/null; then
            echo "INFO: Starting valinfo monitor..."
            LOG_FILE="$VALINFO_SCAN_PATH.log"
            (! $(isFileEmpty $LOG_FILE)) && cp -afv $LOG_FILE $SCAN_DUMP || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
            $KIRA_MANAGER/kira/monitor-valinfo.sh &> $LOG_FILE &
            echo "$!" >"${VALINFO_SCAN_PATH}.pid"
        else
            sleep 1
        fi

        if ! kill -0 $(tryCat "${SNAPSHOT_SCAN_PATH}.pid") 2>/dev/null; then
            echo "INFO: Starting snapshot monitor..."
            LOG_FILE="$SNAPSHOT_SCAN_PATH.log"
            (! $(isFileEmpty $LOG_FILE)) && cp -afv $LOG_FILE $SCAN_DUMP || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
            $KIRA_MANAGER/kira/monitor-snapshot.sh &> $LOG_FILE &
            echo "$!" >"${SNAPSHOT_SCAN_PATH}.pid"
        else
            sleep 1
        fi

        if ! kill -0 $(tryCat "${PEERS_SCAN_PATH}.pid") 2>/dev/null; then
            echo "INFO: Starting peers monitor..."
            LOG_FILE="$PEERS_SCAN_PATH.log"
            (! $(isFileEmpty $LOG_FILE)) && cp -afv $LOG_FILE $SCAN_DUMP || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
            $KIRA_MANAGER/kira/monitor-peers.sh &> $LOG_FILE &
            echo "$!" >"${PEERS_SCAN_PATH}.pid"
        else
            sleep 1
        fi

        echoInfo "INFO: Waiting for network and docker processes querry to finalize..."
        wait $PID1
        (! $(isFileEmpty $NETWORKS_SCAN_PATH)) && cp -afv $NETWORKS_SCAN_PATH $SCAN_DUMP || echoWarn "WARNING: Failed to dump networks info"
        wait $PID2
        (! $(isFileEmpty $CONTAINERS_SCAN_PATH)) && cp -afv $CONTAINERS_SCAN_PATH $SCAN_DUMP || echoWarn "WARNING: Failed to dump networks info"
    
        echo "INFO: Starting container monitor..."
        LOG_FILE="$CONTAINERS_SCAN_PATH.log"
        (! $(isFileEmpty $LOG_FILE)) && cp -afv $LOG_FILE $SCAN_DUMP || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
        $KIRA_MANAGER/kira/monitor-containers.sh &> $LOG_FILE &
        echo "$!" >"${CONTAINERS_SCAN_PATH}.pid"
        SCRIPT_START_TIME="$(date -u +%s)"
    else
        sleep 1
    fi

    echoInfo "INFO: Scan was finalized, elapsed $(($(date -u +%s) - $START_TIME)) seconds"
done