#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/monitor.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && fileFollow $KIRA_LOGS/kirascan.log
# systemctl status kirascan, systemctl stop kirascan
set -x

echoInfo "INFO: Started kira network scan $KIRA_SETUP_VER"
SCAN_DUMP="$KIRA_DUMP/kirascan"

timerDel "DISK_CONS" "NET_CONS"
globDel "DISK_USED" "DISK_UTIL" "RAM_UTIL" "CPU_UTIL" "NETWORKS" "CONTAINERS" "IS_SCAN_DONE" "DISK_CONS" "NET_RECEIVED" "NET_TRANSMITTED" "NET_OUT" "NET_IN" "NET_PRIOR"
globDel "HOSTS_SCAN_PID" "HARDWARE_SCAN_PID" "PEERS_SCAN_PID" "SNAPSHOT_SCAN_PID" "VALINFO_SCAN_PID"

while : ; do
    timerStart MONITOR
    SNAPSHOT_EXECUTE=$(globGet SNAPSHOT_EXECUTE)

    set +x
    echoWarn "------------------------------------------------"
    echoWarn "|   STARTED: MONITOR                           |"
    echoWarn "|----------------------------------------------|"
    echoWarn "|        SCAN DONE: $(globGet IS_SCAN_DONE) "
    echoWarn "|    SNAN DUMP DIR: $SCAN_DUMP"
    echoWarn "| SNAPSHOT EXECUTE: $SNAPSHOT_EXECUTE"
    echoWarn "------------------------------------------------"
    set -x

    if (! $(isCommand "docker")) ; then
        echoErr "ERROR: Docker is not installed, monitor can NOT continue!"
        globSet IS_SCAN_DONE "true"
        sleep 10
        continue
    fi
    
    tryMkDir "$KIRA_SNAP" "$KIRA_SCAN" "$SCAN_DUMP"

    set +e && source "/etc/profile" &>/dev/null && set -e

    echo $(docker network ls --format="{{.Name}}" || docker network ls --format="{{.Name}}" || echo -n "") | globSet "NETWORKS" &
    PID1="$!"

    echo $(docker ps -a | awk '{if(NR>1) print $NF}' | tac || docker ps -a | awk '{if(NR>1) print $NF}' | tac || echo -n "") | globSet "CONTAINERS" &
    PID2="$!"

    if ! kill -0 $(globGet HOSTS_SCAN_PID) 2>/dev/null; then
        echoInfo "INFO: Starting hosts update..."
        LOG_FILE="$(globFile HOSTS_SCAN_LOG)"
        (! $(isFileEmpty $LOG_FILE)) && cp -Tafv "$LOG_FILE" "$SCAN_DUMP/hosts.log" || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
        timeout 600 $KIRA_MANAGER/launch/update-hosts.sh &> $LOG_FILE &
        globSet HOSTS_SCAN_PID "$!"
    else
        sleep 1
    fi
    
    if ! kill -0 $(globGet HARDWARE_SCAN_PID) 2>/dev/null; then
        echoInfo "INFO: Starting hardware monitor..."
        LOG_FILE="$(globFile HARDWARE_SCAN_LOG)"
        (! $(isFileEmpty $LOG_FILE)) && cp -Tafv "$LOG_FILE" "$SCAN_DUMP/hardware.log" || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
        timeout 600 $KIRA_MANAGER/kira/monitor-hardware.sh &> $LOG_FILE &
        globSet HARDWARE_SCAN_PID "$!"
    else
        sleep 1
    fi

    if ! kill -0 $(globGet VALINFO_SCAN_PID) 2>/dev/null; then
        echo "INFO: Starting valinfo monitor..."
        LOG_FILE="$(globFile VALINFO_SCAN_LOG)"
        (! $(isFileEmpty $LOG_FILE)) && cp -Tafv "$LOG_FILE" "$SCAN_DUMP/valinfo.log" || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
        timeout 3600 $KIRA_MANAGER/kira/monitor-valinfo.sh &> $LOG_FILE &
        globSet VALINFO_SCAN_PID "$!"
    else
        sleep 1
    fi

    if ! kill -0 $(globGet SNAPSHOT_SCAN_PID) 2>/dev/null && ( [ "${SNAPSHOT_EXECUTE,,}" == "true" ] || ( [ -f "$KIRA_SNAP_PATH" ] && [ -z "$KIRA_SNAP_SHA256" ] ) ) ; then
        echoInfo "INFO: Starting snapshot monitor..."
        LOG_FILE="$(globFile SNAPSHOT_SCAN_LOG)"
        (! $(isFileEmpty $LOG_FILE)) && cp -Tafv "$LOG_FILE" "$SCAN_DUMP/snapshot.log" || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
        timeout 86400 $KIRA_MANAGER/kira/monitor-snapshot.sh &> $LOG_FILE &
        globSet SNAPSHOT_SCAN_PID "$!"
    else
        sleep 1
    fi

    if ! kill -0 $(globGet PEERS_SCAN_PID) 2>/dev/null; then
        echoInfo "INFO: Starting peers monitor..."
        LOG_FILE="$(globFile PEERS_SCAN_LOG)"
        (! $(isFileEmpty $LOG_FILE)) && cp -Tafv "$LOG_FILE" "$SCAN_DUMP/peers.log" || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
        timeout 86400 $KIRA_MANAGER/kira/monitor-peers.sh &> $LOG_FILE &
        globSet PEERS_SCAN_PID "$!"
    else
        sleep 1
    fi

    echoInfo "INFO: Waiting for network and docker processes querry to finalize..."
    wait $PID1
    PID1_EXIT_CODE="$?"
    globGet "NETWORKS" > $SCAN_DUMP/networks || echoWarn "WARNING: Failed to dump networks info"
    wait $PID2
    PID2_EXIT_CODE="$?"
    globGet "CONTAINERS" > $SCAN_DUMP/containers || echoWarn "WARNING: Failed to dump containers info"

    echoInfo "INFO: Starting container monitor..."
    LOG_FILE="$(globFile CONTAINERS_SCAN_LOG)"
    (! $(isFileEmpty $LOG_FILE)) && cp -Tafv "$LOG_FILE" "$SCAN_DUMP/containers.log" || echoWarn "WARNING: Log file was not found or could not be saved the dump directory"
    timeout 600 $KIRA_MANAGER/kira/monitor-containers.sh &> $LOG_FILE &
    globSet CONTAINERS_SCAN_PID "$!"

    echoInfo "INFO: Waiting for container scan to finalize running..."
    wait $(globGet CONTAINERS_SCAN_PID)
    PID3_EXIT_CODE="$?"

     if [ "${PID3_EXIT_CODE}" != "0" ] ; then
        echoErr "ERROR: Containers monitor failed!, expected exit code to be 0, but got '$PID3_EXIT_CODE' "
        globSet IS_SCAN_DONE "false"
        sleep 5
    else
        globSet IS_SCAN_DONE "true"
    fi

    set +x
    echoWarn "------------------------------------------------"
    echoWarn "| FINISHED: MONITOR                            |"
    echoWarn "|----------------------------------------------|"
    echoWarn "| SCAN DONE: $(globGet IS_SCAN_DONE)"
    echoWarn "|   ELAPSED: $(timerSpan MONITOR) seconds"
    echoWarn "------------------------------------------------"
    set -x
done