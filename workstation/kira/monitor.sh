#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f
set -x

START_TIME="$(date -u +%s)"

echo "INFO: Started kira network scan"

SCAN_DIR="$KIRA_HOME/kirascan"
SCAN_LOGS="$SCAN_DIR/logs"
SCAN_DONE="$SCAN_DIR/done"
CONTAINERS_SCAN_PATH="$SCAN_DIR/containers"
NETWORKS_SCAN_PATH="$SCAN_DIR/networks"
DISK_SCAN_PATH="$SCAN_DIR/disk"
CPU_SCAN_PATH="$SCAN_DIR/cpu"
HOSTS_SCAN_PATH="$SCAN_DIR/hosts"
RAM_SCAN_PATH="$SCAN_DIR/ram"
LIP_SCAN_PATH="$SCAN_DIR/lip"
IP_SCAN_PATH="$SCAN_DIR/ip"
STATUS_SCAN_PATH="$SCAN_DIR/status"
VALINFO_SCAN_PATH="$SCAN_DIR/valinfo"
AUTO_BACKUP_SCAN_PATH="$SCAN_DIR/autobackup"

SNAP_STATUS="$KIRA_SNAP/status"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_LATEST="$SNAP_STATUS/latest"

SCAN_DONE_MISSING="false" && [ ! -f $SCAN_DONE ] && SCAN_DONE_MISSING="true"
[ -z "${MAX_SNAPS##*[!0-9]*}" ] && MAX_SNAPS=3

mkdir -p $SCAN_DIR $STATUS_SCAN_PATH $SCAN_LOGS $SNAP_STATUS
touch $CONTAINERS_SCAN_PATH "$NETWORKS_SCAN_PATH" "$DISK_SCAN_PATH" "$RAM_SCAN_PATH" "$CPU_SCAN_PATH" "$LIP_SCAN_PATH" "$IP_SCAN_PATH" "$VALINFO_SCAN_PATH"

echo $(docker network ls --format="{{.Name}}" || "") >$NETWORKS_SCAN_PATH &
PID1="$!"

echo $(docker ps -a | awk '{if(NR>1) print $NF}' | tac || "") >$CONTAINERS_SCAN_PATH &
PID2="$!"

touch "${HOSTS_SCAN_PATH}.pid" && if ! kill -0 $(cat "${HOSTS_SCAN_PATH}.pid") 2>/dev/null; then
    $KIRA_MANAGER/scripts/update-hosts.sh >"$HOSTS_SCAN_PATH.log" &
    echo "$!" >"${HOSTS_SCAN_PATH}.pid"
fi

touch "${CPU_SCAN_PATH}.pid" && if ! kill -0 $(cat "${CPU_SCAN_PATH}.pid") 2>/dev/null; then
    echo $(mpstat -o JSON -u 5 1 | jq '.sysstat.hosts[0].statistics[0]["cpu-load"][0].idle' | awk '{print 100 - $1"%"}') >$CPU_SCAN_PATH &
    echo "$!" >"${CPU_SCAN_PATH}.pid"
fi

touch "${IP_SCAN_PATH}.pid" && if ! kill -0 $(cat "${IP_SCAN_PATH}.pid") 2>/dev/null; then
    echo $(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com +time=5 +tries=1 2>/dev/null | awk -F'"' '{ print $2}') >$IP_SCAN_PATH && sleep 60 &
    echo "$!" >"${IP_SCAN_PATH}.pid"
fi

touch "${LIP_SCAN_PATH}.pid" && if ! kill -0 $(cat "${LIP_SCAN_PATH}.pid") 2>/dev/null; then
    echo $(/sbin/ifconfig $IFACE 2>/dev/null | grep -i mask 2>/dev/null | awk '{print $2}' 2>/dev/null | cut -f2 2>/dev/null || echo "0.0.0.0") >$LIP_SCAN_PATH && sleep 60 &
    echo "$!" >"${LIP_SCAN_PATH}.pid"
fi

touch "${RAM_SCAN_PATH}.pid" && if ! kill -0 $(cat "${RAM_SCAN_PATH}.pid") 2>/dev/null; then
    echo "$(awk '/MemFree/{free=$2} /MemTotal/{total=$2} END{print (100-((free*100)/total))}' /proc/meminfo)%" >$RAM_SCAN_PATH && sleep 60 &
    echo "$!" >"${RAM_SCAN_PATH}.pid"
fi

touch "${DISK_SCAN_PATH}.pid" && if ! kill -0 $(cat "${DISK_SCAN_PATH}.pid") 2>/dev/null; then
    echo "$(df --output=pcent / | tail -n 1 | tr -d '[:space:]|%')%" >$DISK_SCAN_PATH && sleep 60 &
    echo "$!" >"${DISK_SCAN_PATH}.pid"
fi

touch "${VALINFO_SCAN_PATH}.pid" && if ! kill -0 $(cat "${VALINFO_SCAN_PATH}.pid") 2>/dev/null; then
    $KIRA_MANAGER/kira/monitor-valinfo.sh &>"${VALINFO_SCAN_PATH}.logs" &
    echo "$!" >"${VALINFO_SCAN_PATH}.pid"
fi

echo "INFO: Updating IP addresses info..."
PUBLIC_IP=$(cat $IP_SCAN_PATH 2>/dev/null || echo "")
LOCAL_IP=$(cat $LIP_SCAN_PATH 2>/dev/null || echo "")

mkdir -p "$DOCKER_COMMON_RO"

($(isDnsOrIp "$PUBLIC_IP")) && echo "$PUBLIC_IP" >"$DOCKER_COMMON_RO/public_ip"
($(isDnsOrIp "$LOCAL_IP")) && echo "$LOCAL_IP" >"$DOCKER_COMMON_RO/local_ip"

echo "INFO: Local and Public IP addresses were updated"

wait $PID1
wait $PID2

echo "INFO: Starting container monitor..."
$KIRA_MANAGER/kira/monitor-containers.sh

[ "${SCAN_DONE_MISSING,,}" == true ] && touch $SCAN_DONE

echo "INFO: Starting snapshot monitor..."
$KIRA_MANAGER/kira/monitor-snapshot.sh

if [ -f $SCAN_DONE ] && [[ $AUTO_BACKUP_ENABLED = "Enabled" ]]; then
    ELAPSED_TIME=0
    if [ ! -z "$AUTO_BACKUP_EXECUTED_TIME" ]; then
        ELAPSED_TIME=$(($(date -u +%s) - $AUTO_BACKUP_EXECUTED_TIME))
    fi
    INTERVAL_AS_SECOND=$(($AUTO_BACKUP_INTERVAL * 3600))
    if [ -z "$AUTO_BACKUP_EXECUTED_TIME" ] || [ $ELAPSED_TIME -gt $INTERVAL_AS_SECOND ]; then
        AUTO_BACKUP_EXECUTED_TIME=$(date -u +%s)
        CDHelper text lineswap --insert="AUTO_BACKUP_EXECUTED_TIME=$AUTO_BACKUP_EXECUTED_TIME" --prefix="AUTO_BACKUP_EXECUTED_TIME=" --path=$ETC_PROFILE --append-if-found-not=True

        rm -fv $SCAN_DONE

        $KIRA_MANAGER/containers/start-snapshot.sh "" ""
    fi
fi

sleep 1
echo "INFO: Success, network scan was finalized, elapsed $(($(date -u +%s) - $START_TIME)) seconds"
