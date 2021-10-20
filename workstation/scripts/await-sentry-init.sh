#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/scripts/await-sentry-init.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

CONTAINER_NAME=$1
EXPECTED_NODE_ID=$2
SYNC_AWAIT=$3
[ -z "$SYNC_AWAIT" ] && SYNC_AWAIT="true"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"
EXIT_FILE="$COMMON_PATH/exit"
SNAP_HEIGHT_FILE="$COMMON_PATH/snap_height"
SNAP_NAME_FILE="$COMMON_PATH/snap_name"
IFACES_RESTARTED="false"
RPC_PORT="KIRA_${CONTAINER_NAME^^}_RPC_PORT" && RPC_PORT="${!RPC_PORT}"

TIMER_NAME="${CONTAINER_NAME^^}_INIT"
TIMEOUT=3600

set +x
echoWarn "--------------------------------------------------"
echoWarn "|  STARTING ${CONTAINER_NAME^^} INIT $KIRA_SETUP_VER"
echoWarn "|-------------------------------------------------"
echoWarn "| COMMON DIR: $COMMON_PATH"
echoWarn "|    TIMEOUT: $TIMEOUT seconds"
echoWarn "|   RPC PORT: $RPC_PORT"
echoWarn "|-------------------------------------------------"
set -x

retry=0
while : ; do
    PREVIOUS_HEIGHT=0
    HEIGHT=0
    STATUS=""
    NODE_ID=""

    globDel "${CONTAINER_NAME}_STATUS" "${CONTAINER_NAME}_EXISTS"
    timerStart $TIMER_NAME

    systemctl restart kirascan || echoWarn "WARNING: Could NOT restart kira scan service"
    
    while [[ $(timerSpan $TIMER_NAME) -lt $TIMEOUT ]] ; do
        echoInfo "INFO: Waiting for container $CONTAINER_NAME to start..."
        if [ "$(globGet ${CONTAINER_NAME}_EXISTS)" != "true" ] ; then
            echoWarn "WARNING: $CONTAINER_NAME container does not exists yet, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..." && sleep 30 && continue
        else echoInfo "INFO: Success, container $CONTAINER_NAME was found" ; fi

        echoInfo "INFO: Awaiting $CONTAINER_NAME initialization..."
        if [ "$(globGet ${CONTAINER_NAME}_STATUS)" != "running" ] ; then
            cat $COMMON_LOGS/start.log | tail -n 75 || echoWarn "WARNING: Failed to display '$CONTAINER_NAME' container start logs"
            echoWarn "WARNING: $CONTAINER_NAME is not initialized yet, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..." && sleep 30 && continue
        else echoInfo "INFO: Success, $CONTAINER_NAME was initialized" ; fi

        echoInfo "INFO: Awaiting node status..."
        STATUS=$(timeout 6 curl --fail 0.0.0.0:$RPC_PORT/status 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "") 
        NODE_ID=$(echo "$STATUS" | jsonQuickParse "id" || echo -n "")
        if (! $(isNodeId "$NODE_ID")) ; then
            sleep 20
            echoWarn "WARNING: Status and Node ID is not available"
            continue
        else
            echoInfo "INFO: Success, $CONTAINER_NAME container id found: $NODE_ID"
        fi

        echoInfo "INFO: Awaiting first blocks to be synced..."
        HEIGHT=$(echo "$STATUS" | jsonQuickParse "latest_block_height" || echo -n "")
        (! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0

        if [[ $HEIGHT -le $PREVIOUS_HEIGHT ]] ; then
            echoWarn "WARNING: New blocks are not beeing synced yet! Current height: $HEIGHT, previous height: $PREVIOUS_HEIGHT, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..."
            [ "$HEIGHT" != "0" ] && PREVIOUS_HEIGHT=$HEIGHT
            sleep 10
            continue
        else echoInfo "INFO: Success, $CONTAINER_NAME container id is syncing new blocks" && break ; fi
    done

    echoInfo "INFO: Printing all $CONTAINER_NAME health logs..."
    docker inspect --format "{{json .State.Health }}" $($KIRA_SCRIPTS/container-id.sh "$CONTAINER_NAME") | jq '.Log[-1].Output' | xargs | sed 's/\\n/\n/g' || echo "INFO: Failed to display $CONTAINER_NAME container health logs"

    echoInfo "INFO: Printing $CONTAINER_NAME start logs..."
    cat $COMMON_LOGS/start.log | tail -n 150 || echoWarn "WARNING: Failed to display $CONTAINER_NAME container start logs"

    FAILURE="false"
    if [ "$(globGet ${CONTAINER_NAME}_STATUS)" != "running" ] ; then
        echoErr "ERROR: $CONTAINER_NAME was not started sucessfully within defined time"
        FAILURE="true"
    else echoInfo "INFO: $CONTAINER_NAME was started sucessfully" ; fi

    if [ "$NODE_ID" != "$EXPECTED_NODE_ID" ] ; then
        echoErr "ERROR: $CONTAINER_NAME Node id check failed!"
        echoErr "ERROR: Expected '$EXPECTED_NODE_ID', but got '$NODE_ID'"
        FAILURE="true"
    else echoInfo "INFO: $CONTAINER_NAME node id check succeded '$NODE_ID' is a match" ; fi

    if [[ $HEIGHT -le $PREVIOUS_HEIGHT ]] ; then
        echoErr "ERROR: $CONTAINER_NAME node failed to start catching up new blocks, check node configuration, peers or if seed nodes function correctly."
        FAILURE="true"
    fi

    NETWORK=$(echo "$STATUS" | jsonQuickParse "network" || echo -n "")
    if [ "$NETWORK_NAME" != "$NETWORK" ] ; then
        echoErr "ERROR: Expected network name to be '$NETWORK_NAME' but got '$NETWORK'"
        FAILURE="true"
    fi

    if [ "${FAILURE,,}" == "true" ] ; then
        echoErr "ERROR: $CONTAINER_NAME node setup failed"
        retry=$((retry + 1))
        if [[ $retry -le 1 ]] ; then
            echoInfo "INFO: Attempting $CONTAINER_NAME restart ${retry}/1"
            $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart"
            continue
        fi
        sleep 30
        exit 1
    else echoInfo "INFO: $CONTAINER_NAME launched sucessfully" && break ; fi
done

if [ "${SYNC_AWAIT,,}" == "true" ] ; then
    echoInfo "INFO: $CONTAINER_NAME must be fully synced before setup can proceed..."

    HEIGHT=0
    BLOCKS_LEFT_OLD=0
    timerStart BLOCK_HEIGHT_SPAN
    globDel "${CONTAINER_NAME}_STATUS"
    while : ; do
        echoInfo "INFO: Awaiting node status..."

        timerStart STATUS_AWAIT
        STATUS_SPAN=$(timerSpan STATUS_AWAIT)
        [ "${STATUS,,}" != "running" ] && globDel "${CONTAINER_NAME}_STATUS"
        set +x
        while : ; do
            STATUS_SPAN=$(timerSpan STATUS_AWAIT)
            STATUS=$(globGet "${CONTAINER_NAME}_STATUS") && [ -z "$STATUS" ] && STATUS="undefined"
            [ "${STATUS,,}" == "running" ] && break
            echoInfo "INFO: Waiting for $CONTAINER_NAME container to change status from $STATUS to running, elapsed $STATUS_SPAN/900 seconds..."
            sleep 10
            if (! $(isServiceActive "kirascan")) || [[ $STATUS_SPAN -gt 900 ]] ; then
                echoErr "ERROR: Your 'kirascan' monitoring service is NOT running or timed out $STATUS_SPAN/900 seconds when awaiting status change."
                exit 1
            fi
        done
        set -x

        set -x
        PREVIOUS_HEIGHT=$HEIGHT
        HEIGHT=$(globGet "${CONTAINER_NAME}_BLOCK") && (! $(isNaturalNumber "$HEIGHT")) && HEIGHT="0"
        SYNCING=$(globGet "${CONTAINER_NAME}_SYNCING")
        LATEST_BLOCK_HEIGHT=$(globGet LATEST_BLOCK_HEIGHT)
        MIN_HEIGH=$(globGet MIN_HEIGHT)
        DELTA_TIME=$(timerSpan BLOCK_HEIGHT_SPAN)

        [[ $PREVIOUS_HEIGHT -lt $HEIGHT ]] && timerStart BLOCK_HEIGHT_SPAN
        [[ $LATEST_BLOCK_HEIGHT -gt $MIN_HEIGH ]] && MIN_HEIGH=$LATEST_BLOCK_HEIGHT
        
        if [[ $HEIGHT -ge $MIN_HEIGH ]] ; then
            echoInfo "INFO: Node finished catching up."
            break
        fi

        BLOCKS_LEFT=$(($MIN_HEIGH - $HEIGHT))
        DELTA_HEIGHT=$(($BLOCKS_LEFT_OLD - $BLOCKS_LEFT))
        BLOCKS_LEFT_OLD=$BLOCKS_LEFT

        if [[ $DELTA_TIME -gt $TIMEOUT ]] ; then
            cat $COMMON_LOGS/start.log | tail -n 75 || echoWarn "WARNING: Failed to display '$CONTAINER_NAME' container start logs"
            echoErr "ERROR: $CONTAINER_NAME failed to catch up new blocks for over $TIMEOUT seconds!"
            exit 1
        fi

        set +x
        if [[ $BLOCKS_LEFT -gt 0 ]] && [[ $DELTA_HEIGHT -gt 0 ]] && [[ $DELTA_TIME -gt 0 ]] ; then
            TIME_LEFT=$((($BLOCKS_LEFT * $DELTA_TIME) / $DELTA_HEIGHT))
            echoInfo "INFO: Estimated time left until catching up with min.height: $(prettyTime $TIME_LEFT)"
        fi
        echoInfo "INFO: Minimum height: $MIN_HEIGH, current height: $HEIGHT, catching up: $SYNCING ($DELTA_HEIGHT)"
        echoInfo "INFO: Do NOT close your terminal, waiting for '$CONTAINER_NAME' to finish catching up $DELTA_TIME/$TIMEOUT seconds ..."
        set -x
        sleep 30
    done
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: ${CONTAINER_NAME^^} INIT"
echoWarn "|  ELAPSED: $(timerSpan $TIMER_NAME) seconds"
echoWarn "------------------------------------------------"
set -x