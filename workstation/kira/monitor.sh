#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/monitor.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
START_TIME="$(date -u +%s)"

echo "INFO: Started kira network scann"

SCAN_DIR="$KIRA_HOME/kirascan"
SCAN_LOGS="$SCAN_DIR/logs"
SCAN_DONE="$SCAN_DIR/done"
CONTAINERS_SCAN_PATH="$SCAN_DIR/containers"
NETWORKS_SCAN_PATH="$SCAN_DIR/networks"
DISK_SCAN_PATH="$SCAN_DIR/disk"
CPU_SCAN_PATH="$SCAN_DIR/cpu"
RAM_SCAN_PATH="$SCAN_DIR/ram"
LIP_SCAN_PATH="$SCAN_DIR/lip"
IP_SCAN_PATH="$SCAN_DIR/ip"
STATUS_SCAN_PATH="$SCAN_DIR/status"

SNAP_STATUS="$KIRA_SNAP/status"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_LATEST="$SNAP_STATUS/latest"

SCAN_DONE_MISSING="false" && [ ! -f $SCAN_DONE ] && SCAN_DONE_MISSING="true"

mkdir -p $SCAN_DIR $STATUS_SCAN_PATH $SCAN_LOGS
touch $CONTAINERS_SCAN_PATH "$NETWORKS_SCAN_PATH" "$DISK_SCAN_PATH" "$RAM_SCAN_PATH" "$CPU_SCAN_PATH" "$LIP_SCAN_PATH" "$IP_SCAN_PATH"

echo $(docker network ls --format="{{.Name}}" || "") > $NETWORKS_SCAN_PATH &
PID1="$!"

echo $(docker ps -a | awk '{if(NR>1) print $NF}' | tac || "") > $CONTAINERS_SCAN_PATH &
PID2="$!"


touch "${CPU_SCAN_PATH}.pid" && if ! kill -0 $(cat "${CPU_SCAN_PATH}.pid") 2> /dev/null ; then
    echo $(mpstat -o JSON -u 15 1 | jq '.sysstat.hosts[0].statistics[0]["cpu-load"][0].idle' | awk '{print 100 - $1"%"}') > $CPU_SCAN_PATH &
    echo "$!" > "${CPU_SCAN_PATH}.pid"
fi

touch "${IP_SCAN_PATH}.pid" && if ! kill -0 $(cat "${IP_SCAN_PATH}.pid") 2> /dev/null ; then
    echo $(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com +time=5 +tries=3 2> /dev/null | awk -F'"' '{ print $2}') > $IP_SCAN_PATH && sleep 60 &
    echo "$!" > "${IP_SCAN_PATH}.pid"
fi

touch "${LIP_SCAN_PATH}.pid" && if ! kill -0 $(cat "${LIP_SCAN_PATH}.pid") 2> /dev/null ; then
    echo $(/sbin/ifconfig $IFACE 2> /dev/null | grep -i mask 2> /dev/null | awk '{print $2}' 2> /dev/null | cut -f2 2> /dev/null || echo "0.0.0.0") > $LIP_SCAN_PATH && sleep 60 &
    echo "$!" > "${LIP_SCAN_PATH}.pid"
fi

touch "${RAM_SCAN_PATH}.pid" && if ! kill -0 $(cat "${RAM_SCAN_PATH}.pid") 2> /dev/null ; then
    echo "$(awk '/MemFree/{free=$2} /MemTotal/{total=$2} END{print (100-((free*100)/total))}' /proc/meminfo)%" > $RAM_SCAN_PATH && sleep 60 &
    echo "$!" > "${RAM_SCAN_PATH}.pid"
fi

touch "${DISK_SCAN_PATH}.pid" && if ! kill -0 $(cat "${DISK_SCAN_PATH}.pid") 2> /dev/null ; then
    echo "$(df --output=pcent / | tail -n 1 | tr -d '[:space:]|%')%" > $DISK_SCAN_PATH && sleep 60 &
    echo "$!" > "${DISK_SCAN_PATH}.pid"
fi

wait $PID1
NETWORKS=$(cat $NETWORKS_SCAN_PATH 2> /dev/null || echo "")

wait $PID2
CONTAINERS=$(cat $CONTAINERS_SCAN_PATH 2> /dev/null || echo "")

for name in $CONTAINERS; do
    echo "INFO: Processing container $name"
    DESTINATION_PATH="$STATUS_SCAN_PATH/$name"
    DESTINATION_STATUS_PATH="${DESTINATION_PATH}.sekaid.status"
    touch "$DESTINATION_PATH" "$DESTINATION_STATUS_PATH"

    rm -fv "$DESTINATION_PATH.tmp"

    ID=$($KIRA_SCRIPTS/container-id.sh "$name" 2> /dev/null || echo "")
    $KIRA_MANAGER/kira/container-status.sh "$name" "$DESTINATION_PATH.tmp" "$NETWORKS" "$ID" &> "$SCAN_LOGS/$name-status.error.log" &
    echo "$!" > "$DESTINATION_PATH.pid"
    
    if [ -z "$ID" ] ; then
        echo "INFO: Container '$name' is not alive"
        echo "" > $DESTINATION_STATUS_PATH
        continue
    else
        echo "INFO: Container ID found: $ID"
    fi
    
    if [ "${name,,}" == "sentry" ] || [ "${name,,}" == "priv_sentry" ] || [ "${name,,}" == "validator" ] || [ "${name,,}" == "snapshoot" ] ; then
        echo $(docker exec -i "$ID" sekaid status 2>&1 | jq -rc '.' 2> /dev/null || echo "") > $DESTINATION_STATUS_PATH &
    elif [ "${name,,}" == "interx" ] ; then 
        INTERX_STATUS_PATH="${DESTINATION_PATH}.interx.status"
        echo $(timeout 1 curl $KIRA_INTERX_DNS:$KIRA_INTERX_PORT/api/kira/status 2>/dev/null | jq -r '.' 2> /dev/null || echo "") > $DESTINATION_STATUS_PATH &
        echo $(timeout 1 curl $KIRA_INTERX_DNS:$KIRA_INTERX_PORT/api/status 2>/dev/null | jq -r '.' 2> /dev/null || echo "") > $INTERX_STATUS_PATH &
    fi
done

for name in $CONTAINERS; do
    echo "INFO: Waiting for '$name' scan processes to finalize"
    DESTINATION_PATH="$STATUS_SCAN_PATH/$name"
    touch "${DESTINATION_PATH}.pid"
    PIDX=$(cat "${DESTINATION_PATH}.pid" || echo "")
    
    wait $PIDX || { echo "background failed: $?" >&2; exit 1;}
    cp -f -a -v "$DESTINATION_PATH.tmp" "$DESTINATION_PATH"
done

[ "${SCAN_DONE_MISSING,,}" == true ] && touch $SCAN_DONE

if [ -f "$SNAP_LATEST" ] && [ -f "$SNAP_DONE" ] && [ ! -z "$KIRA_SNAP_PATH" ]; then
    SNAP_LATEST_FILE="$KIRA_SNAP/$(cat $SNAP_LATEST)" 
    if [ -f "$SNAP_LATEST_FILE" ] && [ "$SNAP_LATEST_FILE" != "$KIRA_SNAP_PATH" ] ; then
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$SNAP_LATEST_FILE\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
    fi
fi

sleep 1
echo "INFO: Success, network scan was finalized, elapsed $(($(date -u +%s) - $START_TIME)) seconds"
