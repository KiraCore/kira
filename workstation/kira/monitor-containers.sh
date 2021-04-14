#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-containers.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat
set -x

echo "INFO: Started kira network contianers monitor..."

SCRIPT_START_TIME="$(date -u +%s)"
SCAN_DIR="$KIRA_HOME/kirascan"
CONTAINERS_SCAN_PATH="$SCAN_DIR/containers"
NETWORKS_SCAN_PATH="$SCAN_DIR/networks"
STATUS_SCAN_PATH="$SCAN_DIR/status"
LATEST_BLOCK_SCAN_PATH="$SCAN_DIR/latest_block"
LATEST_STATUS_SCAN_PATH="$SCAN_DIR/latest_status"
INTERX_REFERENCE_DIR="$DOCKER_COMMON/interx/cache/reference"
NETWORKS=$(cat $NETWORKS_SCAN_PATH 2> /dev/null || echo -n "")
CONTAINERS=$(cat $CONTAINERS_SCAN_PATH 2> /dev/null || echo -n "")

set +x
echoWarn "------------------------------------------------"
echoWarn "|     STARTING KIRA CONTAINER SCAN v0.2.2.3    |"
echoWarn "|-----------------------------------------------"
echoWarn "|             SCAN_DIR: $SCAN_DIR"
echoWarn "|           CONTAINERS: $CONTAINERS"
echoWarn "|             NETWORKS: $NETWORKS"
echoWarn "| INTERX_REFERENCE_DIR: $INTERX_REFERENCE_DIR"
echoWarn "------------------------------------------------"
set -x

[ ! -f "$LATEST_BLOCK_SCAN_PATH" ] && echo "0" > $LATEST_BLOCK_SCAN_PATH
[ ! -f "$LATEST_STATUS_SCAN_PATH" ] && echo -n "" > $LATEST_STATUS_SCAN_PATH

mkdir -p "$INTERX_REFERENCE_DIR"

for name in $CONTAINERS; do
    echoInfo "INFO: Processing container $name"
    DESTINATION_PATH="$STATUS_SCAN_PATH/$name"
    DESTINATION_STATUS_PATH="${DESTINATION_PATH}.sekaid.status"
    mkdir -p "$DOCKER_COMMON/$name"
    touch "$DESTINATION_PATH" "$DESTINATION_STATUS_PATH"

    rm -fv "$DESTINATION_PATH.tmp"

    ID=$($KIRA_SCRIPTS/container-id.sh "$name" 2> /dev/null || echo -n "")
    $KIRA_MANAGER/kira/container-status.sh "$name" "$DESTINATION_PATH.tmp" "$NETWORKS" "$ID" &> "$SCAN_LOGS/${name}-status.error.log" &
    echo "$!" > "$DESTINATION_PATH.pid"

    if [[ "${name,,}" =~ ^(validator|sentry|priv_sentry|snapshot|seed)$ ]] ; then
        RPC_PORT="KIRA_${name^^}_RPC_PORT" && RPC_PORT="${!RPC_PORT}"
        echo $(timeout 2 curl 0.0.0.0:$RPC_PORT/status 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "") > $DESTINATION_STATUS_PATH
    elif [ "${name,,}" == "interx" ] ; then 
        INTERX_STATUS_PATH="${DESTINATION_PATH}.interx.status"
        echo $(timeout 1 curl --fail 0.0.0.0:$KIRA_INTERX_PORT/api/kira/status 2>/dev/null || echo -n "") > $DESTINATION_STATUS_PATH
        echo $(timeout 1 curl --fail 0.0.0.0:$KIRA_INTERX_PORT/api/status 2>/dev/null || echo -n "") > $INTERX_STATUS_PATH
    fi
done

NEW_LATEST_BLOCK=0
NEW_LATEST_STATUS=0
for name in $CONTAINERS; do
    echoInfo "INFO: Waiting for '$name' scan processes to finalize"
    DESTINATION_PATH="$STATUS_SCAN_PATH/$name"
    STATUS_PATH="${DESTINATION_PATH}.sekaid.status"
    touch "${DESTINATION_PATH}.pid" "$STATUS_PATH"
    PIDX=$(cat "${DESTINATION_PATH}.pid" || echo -n "")
    
    [ -z "$PIDX" ] && echoInfo "INFO: Process X not found" && continue
    wait $PIDX || { echoErr "ERROR: background pid failed: $?" >&2; exit 1;}
    cp -f -a -v "$DESTINATION_PATH.tmp" "$DESTINATION_PATH"

    if (! $(isFileEmpty "$STATUS_PATH")) ; then
        CATCHING_UP=$(cat $STATUS_PATH | jsonQuickParse "catching_up" || echo "false")
        ($(isNullOrEmpty "$CATCHING_UP")) && CATCHING_UP="false"
        LATEST_BLOCK=$(cat $STATUS_PATH | jsonQuickParse "latest_block_height" || echo "0")
        (! $(isNaturalNumber "$LATEST_BLOCK")) && LATEST_BLOCK=0
        if [[ "${name,,}" =~ ^(sentry|priv_sentry|seed)$ ]] ; then
            NODE_ID=$(car $STATUS_PATH | jsonQuickParse "id" 2> /dev/null  || echo "false")
            ($(isNodeId "$NODE_ID")) && echo "$NODE_ID" > "$INTERX_REFERENCE_DIR/${name,,}_node_id"
        fi

        if [ $NEW_LATEST_BLOCK -lt $LATEST_BLOCK ] ; then
            NEW_LATEST_BLOCK="$LATEST_BLOCK"
            NEW_LATEST_STATUS="$(cat $STATUS_PATH)"
        fi
    else
        LATEST_BLOCK="0"
        CATCHING_UP="false"
    fi
    
    echoInfo "INFO: Saving status props..."
    echo "$LATEST_BLOCK" > "${DESTINATION_PATH}.sekaid.latest_block_height"
    echo "$CATCHING_UP" > "${DESTINATION_PATH}.sekaid.catching_up"
done

# save latest known block height
OLD_LATEST_BLOCK=$(cat $LATEST_BLOCK_SCAN_PATH || echo "0") && (! $(isNaturalNumber "$OLD_LATEST_BLOCK")) && OLD_LATEST_BLOCK=0
if [ $OLD_LATEST_BLOCK -lt $NEW_LATEST_BLOCK ] ; then
    echo "$NEW_LATEST_BLOCK" > $LATEST_BLOCK_SCAN_PATH
    echo "$NEW_LATEST_BLOCK" > "$DOCKER_COMMON_RO/latest_block_height"
fi
# save latest known status
(! $(isNullOrEmpty "$NEW_LATEST_STATUS")) && echo "$NEW_LATEST_STATUS" > $LATEST_STATUS_SCAN_PATH

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINERS MONITOR                 |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x