#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-containers.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat
set -x

echo "INFO: Started kira network contianers monitor..."

timerStart MONITOR_CONTAINERS
STATUS_SCAN_PATH="$KIRA_SCAN/status"
SCAN_LOGS="$KIRA_SCAN/logs"
LATEST_STATUS_SCAN_PATH="$KIRA_SCAN/latest_status"
NETWORKS=$(globGet NETWORKS)
CONTAINERS=$(globGet CONTAINERS)

set +x
echoWarn "------------------------------------------------"
echoWarn "|        STARTING: KIRA CONTAINER SCAN $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "|       KIRA_SCAN: $KIRA_SCAN"
echoWarn "|      CONTAINERS: $CONTAINERS"
echoWarn "|        NETWORKS: $NETWORKS"
echoWarn "| INTERX REF. DIR: $INTERX_REFERENCE_DIR"
echoWarn "------------------------------------------------"
set -x

[ -z "$(globGet LATEST_BLOCK)" ] && globSet LATEST_BLOCK "0"
[ ! -f "$LATEST_STATUS_SCAN_PATH" ] && echo -n "" > $LATEST_STATUS_SCAN_PATH

mkdir -p "$INTERX_REFERENCE_DIR"

for name in $CONTAINERS; do
    echoInfo "INFO: Processing container $name"
    mkdir -p "$DOCKER_COMMON/$name"

    PIDX=$(globGet "${name}_STATUS_PID")

    if kill -0 "$PIDX" 2>/dev/null; then
        echoInfo "INFO: $name container status check is still running, see logs '$SCAN_LOGS/${name}-status.error.log' ..."
        continue
    fi

    # cat "$SCAN_LOGS/seed-status.error.log"
    timerStart "${name}_SCAN" 
    globSet "${name}_SCAN_DONE" "false"
    $KIRA_MANAGER/kira/container-status.sh "$name" "$NETWORKS" &> "$SCAN_LOGS/${name}-status.error.log" &
    globSet "${name}_STATUS_PID" "$!"

    if [[ "${name,,}" =~ ^(validator|sentry|snapshot|seed)$ ]] ; then
        RPC_PORT="KIRA_${name^^}_RPC_PORT" && RPC_PORT="${!RPC_PORT}"
        echo $(timeout 3 curl --fail 0.0.0.0:$RPC_PORT/status 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "") | globSet "${name}_SEKAID_STATUS"
    elif [ "${name,,}" == "interx" ] ; then 
        echo $(timeout 3 curl --fail 0.0.0.0:$KIRA_INTERX_PORT/api/kira/status 2>/dev/null || echo -n "") | globSet "${name}_SEKAID_STATUS"
        echo $(timeout 3 curl --fail 0.0.0.0:$KIRA_INTERX_PORT/api/status 2>/dev/null || echo -n "") | globSet "${name}_INTERX_STATUS"
    fi
done

NEW_LATEST_BLOCK=0
NEW_LATEST_STATUS=0
for name in $CONTAINERS; do
    echoInfo "INFO: Waiting for '$name' scan processes to finalize"
    PIDX=$(globGet "${name}_STATUS_PID")

    set +x
    while : ; do
        SCAN_SPAN=$(timerSpan "${name}_SCAN")
        SCAN_DONE=$(globGet "${name}_SCAN_DONE")
        [ "${SCAN_DONE}" == "true" ] && break
        echoInfo "INFO: Waiting for $name scan (PID $PIDX) to finlize, elapsed $SCAN_SPAN/60 seconds ..."
        [[ $SCAN_SPAN -gt 60 ]] && echoErr "ERROR: Timeout failed to scan $name container, see error logs '$SCAN_LOGS/${name}-status.error.log'" && exit 1
        if ! kill -0 "$PIDX" 2>/dev/null ; then
            [ "$(globSet ${name}_SCAN_DONE)" != "true" ] && \
                echoErr "ERROR: Background PID $PIDX failed for the $name container. See error logs: '$SCAN_LOGS/${name}-status.error.log'" && exit 1
        fi
        sleep 1
    done
    set -x

    STATUS_PATH=$(globFile "${name}_SEKAID_STATUS")

    if (! $(isFileEmpty "$STATUS_PATH")) ; then
        LATEST_BLOCK=$(jsonQuickParse "latest_block_height" $STATUS_PATH || echo "0")
        (! $(isNaturalNumber "$LATEST_BLOCK")) && LATEST_BLOCK=0
        CATCHING_UP=$(jsonQuickParse "catching_up" $STATUS_PATH || echo "false")
        ($(isNullOrEmpty "$CATCHING_UP")) && CATCHING_UP=false
        if [[ "${name,,}" =~ ^(sentry|seed|validator)$ ]] ; then
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
    PREVIOUS_BLOCK=$(globGet "${name}_BLOCK")
    globSet "${name}_BLOCK" "$LATEST_BLOCK"
    globSet "${name}_SYNCING" "$CATCHING_UP"
done

# save latest known block height
OLD_LATEST_BLOCK=$(globGet LATEST_BLOCK) && (! $(isNaturalNumber "$OLD_LATEST_BLOCK")) && OLD_LATEST_BLOCK=0
if [[ $OLD_LATEST_BLOCK -lt $NEW_LATEST_BLOCK ]] ; then

    globSet INTERNAL_BLOCK $NEW_LATEST_BLOCK
    globSet LATEST_BLOCK $NEW_LATEST_BLOCK
    globSet latest_block_height "$NEW_LATEST_BLOCK" "$GLOBAL_COMMON_RO"

    globSet MIN_HEIGHT $NEW_LATEST_BLOCK
    globSet MIN_HEIGHT $NEW_LATEST_BLOCK $GLOBAL_COMMON_RO
fi
# save latest known status
(! $(isNullOrEmpty "$NEW_LATEST_STATUS")) && echo "$NEW_LATEST_STATUS" > $LATEST_STATUS_SCAN_PATH

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: CONTAINERS MONITOR                 |"
echoWarn "|  ELAPSED: $(timerSpan MONITOR_CONTAINERS) seconds"
echoWarn "------------------------------------------------"
set -x