#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-containers.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat
set -x

echo "INFO: Started kira network contianers monitor..."

timerStart
STATUS_SCAN_PATH="$KIRA_SCAN/status"
LATEST_STATUS_SCAN_PATH="$KIRA_SCAN/latest_status"
NETWORKS=$(globGet NETWORKS)
CONTAINERS=$(globGet CONTAINERS)

set +x
echoWarn "------------------------------------------------"
echoWarn "|     STARTING KIRA CONTAINER SCAN v0.2.2.3    |"
echoWarn "|-----------------------------------------------"
echoWarn "|        KIRA_SCAN: $KIRA_SCAN"
echoWarn "|           CONTAINERS: $CONTAINERS"
echoWarn "|             NETWORKS: $NETWORKS"
echoWarn "| INTERX REFERENCE DIR: $INTERX_REFERENCE_DIR"
echoWarn "------------------------------------------------"
set -x

[ -z "$(globGet LATEST_BLOCK)" ] && globSet LATEST_BLOCK "0"
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
        echo $(timeout 2 curl --fail 0.0.0.0:$KIRA_INTERX_PORT/api/kira/status 2>/dev/null || echo -n "") > $DESTINATION_STATUS_PATH
        echo $(timeout 2 curl --fail 0.0.0.0:$KIRA_INTERX_PORT/api/status 2>/dev/null || echo -n "") > $INTERX_STATUS_PATH
    fi
done

NEW_LATEST_BLOCK=0
NEW_LATEST_STATUS=0
for name in $CONTAINERS; do
    echoInfo "INFO: Waiting for '$name' scan processes to finalize"
    DESTINATION_PATH="$STATUS_SCAN_PATH/$name"
    STATUS_PATH="${DESTINATION_PATH}.sekaid.status"
    touch "${DESTINATION_PATH}.pid" "$STATUS_PATH"
    PIDX=$(tryCat "${DESTINATION_PATH}.pid" "")
    
    [ -z "$PIDX" ] && echoInfo "INFO: Process X not found" && continue
    wait $PIDX || { echoErr "ERROR: background pid failed: $?" >&2; exit 1;}
    cp -f -a -v "$DESTINATION_PATH.tmp" "$DESTINATION_PATH"

    if (! $(isFileEmpty "$STATUS_PATH")) ; then
        CATCHING_UP=$(jsonQuickParse "catching_up" $STATUS_PATH || echo "false")
        ($(isNullOrEmpty "$CATCHING_UP")) && CATCHING_UP="false"
        LATEST_BLOCK=$(jsonQuickParse "latest_block_height" $STATUS_PATH || echo "0")
        (! $(isNaturalNumber "$LATEST_BLOCK")) && LATEST_BLOCK=0
        if [[ "${name,,}" =~ ^(sentry|priv_sentry|seed)$ ]] ; then
            NODE_ID=$(jsonQuickParse "id" $STATUS_PATH 2> /dev/null  || echo "false")
            ($(isNodeId "$NODE_ID")) && echo "$NODE_ID" > "$INTERX_REFERENCE_DIR/${name,,}_node_id"
        fi

        if [[ $NEW_LATEST_BLOCK -lt $LATEST_BLOCK ]] ; then
            NEW_LATEST_BLOCK="$LATEST_BLOCK"
            NEW_LATEST_STATUS="$(tryCat $STATUS_PATH)"
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
OLD_LATEST_BLOCK=$(globGet LATEST_BLOCK) && (! $(isNaturalNumber "$OLD_LATEST_BLOCK")) && OLD_LATEST_BLOCK=0
if [[ $OLD_LATEST_BLOCK -lt $NEW_LATEST_BLOCK ]] ; then
    globSet LATEST_BLOCK $NEW_LATEST_BLOCK
    echo "$NEW_LATEST_BLOCK" > "$DOCKER_COMMON_RO/latest_block_height"
fi
# save latest known status
(! $(isNullOrEmpty "$NEW_LATEST_STATUS")) && echo "$NEW_LATEST_STATUS" > $LATEST_STATUS_SCAN_PATH

globSet SCAN_DONE true

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINERS MONITOR                 |"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x