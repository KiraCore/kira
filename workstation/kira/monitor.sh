#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
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

SNAP_STATUS="$KIRA_SNAP/status"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_LATEST="$SNAP_STATUS/latest"

SCAN_DONE_MISSING="false" && [ ! -f $SCAN_DONE ] && SCAN_DONE_MISSING="true"
[ -z "${MAX_SNAPS##*[!0-9]*}" ] && MAX_SNAPS=3

mkdir -p $SCAN_DIR $STATUS_SCAN_PATH $SCAN_LOGS $SNAP_STATUS
touch $CONTAINERS_SCAN_PATH "$NETWORKS_SCAN_PATH" "$DISK_SCAN_PATH" "$RAM_SCAN_PATH" "$CPU_SCAN_PATH" "$LIP_SCAN_PATH" "$IP_SCAN_PATH" "$VALADDR_SCAN_PATH" "$VALSTATUS_SCAN_PATH"

echo $(docker network ls --format="{{.Name}}" || "") > $NETWORKS_SCAN_PATH &
PID1="$!"

echo $(docker ps -a | awk '{if(NR>1) print $NF}' | tac || "") > $CONTAINERS_SCAN_PATH &
PID2="$!"

touch "${HOSTS_SCAN_PATH}.pid" && if ! kill -0 $(cat "${HOSTS_SCAN_PATH}.pid") 2> /dev/null ; then
    $KIRA_MANAGER/scripts/update-hosts.sh > "$HOSTS_SCAN_PATH.log" &
    echo "$!" > "${HOSTS_SCAN_PATH}.pid"
fi

touch "${CPU_SCAN_PATH}.pid" && if ! kill -0 $(cat "${CPU_SCAN_PATH}.pid") 2> /dev/null ; then
    echo $(mpstat -o JSON -u 5 1 | jq '.sysstat.hosts[0].statistics[0]["cpu-load"][0].idle' | awk '{print 100 - $1"%"}') > $CPU_SCAN_PATH &
    echo "$!" > "${CPU_SCAN_PATH}.pid"
fi

touch "${IP_SCAN_PATH}.pid" && if ! kill -0 $(cat "${IP_SCAN_PATH}.pid") 2> /dev/null ; then
    echo $(dig TXT +short o-o.myaddr.l.google.com @ns1.google.com +time=5 +tries=1 2> /dev/null | awk -F'"' '{ print $2}') > $IP_SCAN_PATH && sleep 60 &
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

if [ "${INFRA_MODE,,}" == "validator" ] ; then
    VALADDR=$(docker exec -i validator sekaid keys show validator -a --keyring-backend=test || echo "")
    [ ! -z "$VALADDR" ] && VALSTATUS=$(docker exec -i validator sekaid query validator --addr=$VALADDR --output=json || echo "") || VALSTATUS=""

    echo "$VALADDR" > $VALADDR_SCAN_PATH
    echo "$VALSTATUS" > $VALSTATUS_SCAN_PATH
else
    echo "" > $VALADDR_SCAN_PATH
    echo "" > $VALSTATUS_SCAN_PATH
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
    
    if [[ "${name,,}" =~ ^(validator|sentry|priv_sentry|snapshot)$ ]] ; then
        echo $(docker exec -i "$ID" sekaid status 2>&1 | jq -rc '.' 2> /dev/null || echo "") > $DESTINATION_STATUS_PATH &
        echo "$!" > "$DESTINATION_PATH.sekaid.status.pid"
    elif [ "${name,,}" == "interx" ] ; then 
        INTERX_STATUS_PATH="${DESTINATION_PATH}.interx.status"
        echo $(timeout 1 curl $KIRA_INTERX_DNS:$KIRA_INTERX_PORT/api/kira/status 2>/dev/null | jq -r '.' 2> /dev/null || echo "") > $DESTINATION_STATUS_PATH &
        echo "$!" > "$DESTINATION_PATH.sekaid.status.pid"
        echo $(timeout 1 curl $KIRA_INTERX_DNS:$KIRA_INTERX_PORT/api/status 2>/dev/null | jq -r '.' 2> /dev/null || echo "") > $INTERX_STATUS_PATH &
    fi
done

for name in $CONTAINERS; do
    echo "INFO: Waiting for '$name' scan processes to finalize"
    DESTINATION_PATH="$STATUS_SCAN_PATH/$name"
    STATUS_PATH="${DESTINATION_PATH}.sekaid.status"
    touch "${DESTINATION_PATH}.pid" "${DESTINATION_PATH}.sekaid.status.pid" "$STATUS_PATH"
    PIDX=$(cat "${DESTINATION_PATH}.pid" || echo "")
    PIDY=$(cat "${DESTINATION_PATH}.sekaid.status.pid" || echo "")
    
    [ -z "$PIDX" ] && echo "INFO: Process X not found" && continue
    wait $PIDX || { echo "background pid failed: $?" >&2; exit 1;}
    cp -f -a -v "$DESTINATION_PATH.tmp" "$DESTINATION_PATH"
    
    [ -z "$PIDY" ] && echo "INFO: Process Y not found" && continue
    wait $PIDY || { echo "background status pid failed: $?" >&2; exit 1;}

    SEKAID_STATUS=$(cat $STATUS_PATH)
    if [ ! -z "$SEKAID_STATUS" ] && [ "${SEKAID_STATUS,,}" != "null" ] ; then
        CATCHING_UP=$(echo "$SEKAID_STATUS" | jq -r '.SyncInfo.catching_up' 2>/dev/null || echo "false")
        ( [ -z "$CATCHING_UP" ] || [ "${CATCHING_UP,,}" == "null" ] ) && CATCHING_UP=$(echo "$SEKAID_STATUS" | jq -r '.sync_info.catching_up' 2>/dev/null || echo "false")
        ( [ -z "$CATCHING_UP" ] || [ "${CATCHING_UP,,}" != "true" ] ) && CATCHING_UP="false"
        LATEST_BLOCK=$(echo "$SEKAID_STATUS" | jq -r '.SyncInfo.latest_block_height' 2>/dev/null || echo "0")
        ( [ -z "$LATEST_BLOCK" ] || [ -z "${LATEST_BLOCK##*[!0-9]*}" ] ) && LATEST_BLOCK=$(echo "$SEKAID_STATUS" | jq -r '.sync_info.latest_block_height' 2>/dev/null || echo "0")
        ( [ -z "$LATEST_BLOCK" ] || [ -z "${LATEST_BLOCK##*[!0-9]*}" ] ) && LATEST_BLOCK=0
    else
        LATEST_BLOCK="0"
        CATCHING_UP="false"
    fi
    
    echo "INFO: Saving status props..."
    echo "$LATEST_BLOCK" > "${DESTINATION_PATH}.sekaid.latest_block_height"
    echo "$CATCHING_UP" > "${DESTINATION_PATH}.sekaid.catching_up"
done

[ "${SCAN_DONE_MISSING,,}" == true ] && touch $SCAN_DONE

if [ -f "$SNAP_LATEST" ] && [ -f "$SNAP_DONE" ] ; then
    SNAP_LATEST_FILE="$KIRA_SNAP/$(cat $SNAP_LATEST)" 
    if [ -f "$SNAP_LATEST_FILE" ] && [ "$KIRA_SNAP_PATH" != "$SNAP_LATEST_FILE" ] ; then
        KIRA_SNAP_PATH=$SNAP_LATEST_FILE
        CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$KIRA_SNAP_PATH\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
    fi
fi

INTERX_REDERENCE_DIR="$DOCKER_COMMON/interx/cache/reference"
INTERX_SNAPSHOT_PATH="$INTERX_REDERENCE_DIR/snapshot.zip"
if [ -f "$KIRA_SNAP_PATH" ] && [ "${SNAP_EXPOSE,,}" == "true" ] ; then
    HASH1=$(sha256sum "$KIRA_SNAP_PATH" | awk '{ print $1 }' || echo "")
    HASH2=$(sha256sum "$INTERX_SNAPSHOT_PATH" | awk '{ print $1 }' || echo "")

    if [ "$HASH1" != "$HASH2" ] ; then
        echo "INFO: Latest snapshot is NOT exposed yet"
        mkdir -p $INTERX_REDERENCE_DIR
        cp -f -v -a "$KIRA_SNAP_PATH" "$INTERX_SNAPSHOT_PATH"
    else
        echo "INFO: Latest snapshot was already exposed, no need for updates"
    fi
elif [ -f "$INTERX_SNAPSHOT_PATH" ] && ( [ "${SNAP_EXPOSE,,}" == "false" ] || [ -z "$KIRA_SNAP_PATH" ] ) ; then
    echo "INFO: Removing publicly exposed snapshot..."
    rm -f -v $INTERX_SNAPSHOT_PATH
fi

if [ -d $KIRA_SNAP ] ; then
    echo "INFO: Directory '$KIRA_SNAP' found, clenaing up to $MAX_SNAPS snaps..."
    find $KIRA_SNAP/*.zip -maxdepth 1 -type f | xargs -x ls -t | awk "NR>$MAX_SNAPS" | xargs -L1 rm -fv || echo "ERROR: Faile dto remove excessive snapshots"
    echo "INFO: Success, all excessive snaps were removed"
fi

sleep 1
echo "INFO: Success, network scan was finalized, elapsed $(($(date -u +%s) - $START_TIME)) seconds"
