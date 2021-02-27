#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-containers.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f
set -x

echo "INFO: Started kira network contianers monitor..."

SCAN_DIR="$KIRA_HOME/kirascan"
CONTAINERS_SCAN_PATH="$SCAN_DIR/containers"
NETWORKS_SCAN_PATH="$SCAN_DIR/networks"
STATUS_SCAN_PATH="$SCAN_DIR/status"

NETWORKS=$(cat $NETWORKS_SCAN_PATH 2> /dev/null || echo "")
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
    
    if [[ "${name,,}" =~ ^(validator|sentry|priv_sentry|snapshot|seed)$ ]] ; then
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

echo "INFO: Finished kira contianers monitor"