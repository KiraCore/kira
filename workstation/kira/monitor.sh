#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat
set -x

echoInfo "INFO: Started kira network scan $KIRA_SETUP_VER"

SCAN_LOGS="$KIRA_SCAN/logs"
SCAN_DONE="$KIRA_SCAN/done"
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

globDel "DISK_AVAIL" "DISK_UTIL" "RAM_UTIL" "CPU_UTIL" "NETWORKS"

while : ; do
    timerStart -v
    if ! command -v docker ; then
        echoErr "ERROR: Docker is not installed, monitor can NOT continue!"
        sleep 10
        continue
    fi
    
    tryMkDir $KIRA_SCAN $STATUS_SCAN_PATH $SCAN_LOGS $SNAP_STATUS $SCAN_DUMP
    touch "$VALINFO_SCAN_PATH" "$SNAPSHOT_SCAN_PATH"

    set +e && source "/etc/profile" &>/dev/null && set -e

    echo $(docker network ls --format="{{.Name}}" || echo -n "") | globSet "NETWORKS" &
    PID1="$!"

    echo $(docker ps -a | awk '{if(NR>1) print $NF}' | tac || echo -n "") | globSet "CONTAINERS" &
    PID2="$!"

    if ! kill -0 $(tryCat "${HOSTS_SCAN_PATH}.pid") 2>/dev/null; then
        echoInfo "INFO: Starting hosts update..."
        LOG_FILE="$HOSTS_SCAN_PATH.log"
        (! $(isFileEmpty $LOG_FILE)) && cp -afv $LOG_FILE $SCAN_DUMP || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
        timeout 600 $KIRA_MANAGER/scripts/update-hosts.sh &> $LOG_FILE &
        echo "$!" >"${HOSTS_SCAN_PATH}.pid"
    else
        sleep 1
    fi

    if ! kill -0 $(tryCat "${HARDWARE_SCAN_PATH}.pid") 2>/dev/null; then
        echoInfo "INFO: Starting hardware monitor..."
        LOG_FILE="$HARDWARE_SCAN_PATH.log"
        (! $(isFileEmpty $LOG_FILE)) && cp -afv $LOG_FILE $SCAN_DUMP || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
        timeout 600 $KIRA_MANAGER/kira/monitor-hardware.sh &> $LOG_FILE &
        echo "$!" >"${HARDWARE_SCAN_PATH}.pid"
    else
        sleep 1
    fi

    if ! kill -0 $(tryCat "${VALINFO_SCAN_PATH}.pid") 2>/dev/null; then
        echo "INFO: Starting valinfo monitor..."
        LOG_FILE="$VALINFO_SCAN_PATH.log"
        (! $(isFileEmpty $LOG_FILE)) && cp -afv $LOG_FILE $SCAN_DUMP || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
        timeout 600 $KIRA_MANAGER/kira/monitor-valinfo.sh &> $LOG_FILE &
        echo "$!" >"${VALINFO_SCAN_PATH}.pid"
    else
        sleep 1
    fi

    if ! kill -0 $(tryCat "${SNAPSHOT_SCAN_PATH}.pid") 2>/dev/null; then
        echo "INFO: Starting snapshot monitor..."
        LOG_FILE="$SNAPSHOT_SCAN_PATH.log"
        (! $(isFileEmpty $LOG_FILE)) && cp -afv $LOG_FILE $SCAN_DUMP || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
        timeout 600 $KIRA_MANAGER/kira/monitor-snapshot.sh &> $LOG_FILE &
        echo "$!" >"${SNAPSHOT_SCAN_PATH}.pid"
    else
        sleep 1
    fi

    if ! kill -0 $(tryCat "${PEERS_SCAN_PATH}.pid") 2>/dev/null; then
        echo "INFO: Starting peers monitor..."
        LOG_FILE="$PEERS_SCAN_PATH.log"
        (! $(isFileEmpty $LOG_FILE)) && cp -afv $LOG_FILE $SCAN_DUMP || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
        timeout 3600 $KIRA_MANAGER/kira/monitor-peers.sh &> $LOG_FILE &
        echo "$!" >"${PEERS_SCAN_PATH}.pid"
    else
        sleep 1
    fi

    echoInfo "INFO: Waiting for network and docker processes querry to finalize..."
    wait $PID1
    globGet "NETWORKS" > $SCAN_DUMP/networks || echoWarn "WARNING: Failed to dump networks info"
    wait $PID2
    globGet "CONTAINERS" > $SCAN_DUMP/containers || echoWarn "WARNING: Failed to dump containers info"
    
    timeout 600 $KIRA_MANAGER/kira/monitor-containers.sh
    echoInfo "INFO: Scan was finalized, elapsed $(timerSpan) seconds"
done