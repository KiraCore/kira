#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f
set -x

START_TIME="$(date -u +%s)"

echoInfo "INFO: Started kira network scan"

SCAN_DIR="$KIRA_HOME/kirascan"
SCAN_LOGS="$SCAN_DIR/logs"
SCAN_DONE="$SCAN_DIR/done"
CONTAINERS_SCAN_PATH="$SCAN_DIR/containers"
NETWORKS_SCAN_PATH="$SCAN_DIR/networks"
HOSTS_SCAN_PATH="$SCAN_DIR/hosts"
STATUS_SCAN_PATH="$SCAN_DIR/status"
VALINFO_SCAN_PATH="$SCAN_DIR/valinfo"
SNAPSHOT_SCAN_PATH="$SCAN_DIR/snapshot"
HARDWARE_SCAN_PATH="$SCAN_DIR/hardware"

SNAP_STATUS="$KIRA_SNAP/status"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_LATEST="$SNAP_STATUS/latest"

while : ; do
    sleep 1
    set +e && source "/etc/profile" &>/dev/null && set -e
    
    SCAN_DONE_MISSING="false" && [ ! -f $SCAN_DONE ] && SCAN_DONE_MISSING="true"
    [ -z "${MAX_SNAPS##*[!0-9]*}" ] && MAX_SNAPS=2
    
    mkdir -p $SCAN_DIR $STATUS_SCAN_PATH $SCAN_LOGS $SNAP_STATUS
    touch $CONTAINERS_SCAN_PATH "$NETWORKS_SCAN_PATH" "$VALINFO_SCAN_PATH" "$SNAPSHOT_SCAN_PATH"
    
    echo $(docker network ls --format="{{.Name}}" || "") >$NETWORKS_SCAN_PATH &
    PID1="$!"
    
    echo $(docker ps -a | awk '{if(NR>1) print $NF}' | tac || "") >$CONTAINERS_SCAN_PATH &
    PID2="$!"
    
    touch "${HOSTS_SCAN_PATH}.pid" && if ! kill -0 $(cat "${HOSTS_SCAN_PATH}.pid") 2>/dev/null; then
        $KIRA_MANAGER/scripts/update-hosts.sh >"$HOSTS_SCAN_PATH.log" &
        echo "$!" >"${HOSTS_SCAN_PATH}.pid"
    fi
    
    touch "${HARDWARE_SCAN_PATH}.pid" && if ! kill -0 $(cat "${HARDWARE_SCAN_PATH}.pid") 2>/dev/null; then
        echo "INFO: Starting hardware monitor..."
        $KIRA_MANAGER/kira/monitor-hardware.sh &>"${HARDWARE_SCAN_PATH}.logs" &
        echo "$!" >"${HARDWARE_SCAN_PATH}.pid"
    fi
    
    touch "${VALINFO_SCAN_PATH}.pid" && if ! kill -0 $(cat "${VALINFO_SCAN_PATH}.pid") 2>/dev/null; then
        $KIRA_MANAGER/kira/monitor-valinfo.sh &>"${VALINFO_SCAN_PATH}.logs" &
        echo "$!" >"${VALINFO_SCAN_PATH}.pid"
    fi
    
    touch "${SNAPSHOT_SCAN_PATH}.pid" && if ! kill -0 $(cat "${SNAPSHOT_SCAN_PATH}.pid") 2>/dev/null; then
        echo "INFO: Starting snapshot monitor..."
        $KIRA_MANAGER/kira/monitor-snapshot.sh &>"${SNAPSHOT_SCAN_PATH}.logs" &
        echo "$!" >"${SNAPSHOT_SCAN_PATH}.pid"
    fi
    
    echoInfo "INFO: Waiting for network and docker processes querry to finalize..."
    wait $PID1
    wait $PID2
    
    echoInfo "INFO: Starting container monitor..."
    $KIRA_MANAGER/kira/monitor-containers.sh
    
    [ "${SCAN_DONE_MISSING,,}" == true ] && touch $SCAN_DONE
    
    echoInfo "INFO: Success, network scan was finalized, elapsed $(($(date -u +%s) - $START_TIME)) seconds"
done