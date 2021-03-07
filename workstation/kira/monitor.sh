#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f
set -x

START_TIME="$(date -u +%s)"

echo "INFO: Started kira network scann"

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
VALADDR_SCAN_PATH="$SCAN_DIR/valaddr"
VALSTATUS_SCAN_PATH="$SCAN_DIR/valstatus"
VALOPERS_SCAN_PATH="$SCAN_DIR/valopers"

SNAP_STATUS="$KIRA_SNAP/status"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_LATEST="$SNAP_STATUS/latest"

SCAN_DONE_MISSING="false" && [ ! -f $SCAN_DONE ] && SCAN_DONE_MISSING="true"
[ -z "${MAX_SNAPS##*[!0-9]*}" ] && MAX_SNAPS=3

mkdir -p $SCAN_DIR $STATUS_SCAN_PATH $SCAN_LOGS $SNAP_STATUS
touch $CONTAINERS_SCAN_PATH "$NETWORKS_SCAN_PATH" "$DISK_SCAN_PATH" "$RAM_SCAN_PATH" "$CPU_SCAN_PATH" "$LIP_SCAN_PATH" "$IP_SCAN_PATH" "$VALADDR_SCAN_PATH" "$VALSTATUS_SCAN_PATH" "$VALOPERS_SCAN_PATH"

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

echo "INFO: Saving valopers info..."
TMPVAL=$(timeout 5 wget -qO- "$KIRA_INTERX_DNS:$KIRA_INTERX_PORT/api/valopers?all=true" | jq -rc || echo "") && echo $TMPVAL >$VALOPERS_SCAN_PATH

if [[ "${INFRA_MODE,,}" =~ ^(validator|local)$ ]] ; then
    VALADDR=$(docker exec -i validator sekaid keys show validator -a --keyring-backend=test || echo "")
    [ ! -z "$VALADDR" ] && VALSTATUS=$(docker exec -i validator sekaid query validator --addr=$VALADDR --output=json || echo "") || VALSTATUS=""

    echo "$VALADDR" >$VALADDR_SCAN_PATH
    echo "$VALSTATUS" >$VALSTATUS_SCAN_PATH
else
    echo "" >$VALADDR_SCAN_PATH
    echo "" >$VALSTATUS_SCAN_PATH
fi

echo "INFO: Updating IP addresses info..."
PUBLIC_IP=$(cat $IP_SCAN_PATH 2>/dev/null || echo "")
LOCAL_IP=$(cat $LIP_SCAN_PATH 2>/dev/null || echo "")

mkdir -p "$DOCKER_COMMON_RO"

($(isDnsOrIp "$PUBLIC_IP")) && echo "$PUBLIC_IP" > "$DOCKER_COMMON_RO/public_ip"
($(isDnsOrIp "$LOCAL_IP")) && echo "$LOCAL_IP" > "$DOCKER_COMMON_RO/local_ip"

echo "INFO: Local and Public IP addresses were updated"

wait $PID1
wait $PID2

echo "INFO: Starting container monitor..."
$KIRA_MANAGER/kira/monitor-containers.sh

[ "${SCAN_DONE_MISSING,,}" == true ] && touch $SCAN_DONE

echo "INFO: Starting snapshot monitor..."
$KIRA_MANAGER/kira/monitor-snapshot.sh

sleep 1
echo "INFO: Success, network scan was finalized, elapsed $(($(date -u +%s) - $START_TIME)) seconds"
