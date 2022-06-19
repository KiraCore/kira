#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

CONTAINER_NAME=$1
EXPECTED_NODE_ID=$2
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
IFACES_RESTARTED="false"
RPC_PORT="KIRA_${CONTAINER_NAME^^}_RPC_PORT" && RPC_PORT="${!RPC_PORT}"
TIMER_NAME="${CONTAINER_NAME^^}_INIT"
TIMEOUT=3600

set +x
echoWarn "--------------------------------------------------"
echoWarn "|  STARTING ${CONTAINER_NAME^^} INIT $KIRA_SETUP_VER"
echoWarn "|-------------------------------------------------"
echoWarn "|       COMMON DIR: $COMMON_PATH"
echoWarn "|          TIMEOUT: $TIMEOUT seconds"
echoWarn "|         RPC PORT: $RPC_PORT"
echoWarn "| EXPECTED NODE ID: $EXPECTED_NODE_ID"
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
        if [ "$(globGet ${CONTAINER_NAME}_STATUS)" == "configuring" ] ; then
            timerPause $TIMER_NAME
            cat $COMMON_LOGS/start.log | tail -n 75 || echoWarn "WARNING: Failed to display '$CONTAINER_NAME' container start logs"
            echoWarn "WARNING: $CONTAINER_NAME is still being configured, please wait ..." && sleep 30 && continue
        else
            timerUnpause $TIMER_NAME
        fi

        if [ "$(globGet ${CONTAINER_NAME}_STATUS)" != "running" ] ; then
            cat $COMMON_LOGS/start.log | tail -n 75 || echoWarn "WARNING: Failed to display '$CONTAINER_NAME' container start logs"
            echoWarn "WARNING: $CONTAINER_NAME is not initialized yet, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..." && sleep 30 && continue
        else echoInfo "INFO: Success, $CONTAINER_NAME was initialized" ; fi

        echoInfo "INFO: Awaiting node status..."
        STATUS=$(timeout 6 curl 0.0.0.0:$RPC_PORT/status 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "") 
        NODE_ID=$(echo "$STATUS" | jsonQuickParse "id" 2> /dev/null || echo -n "")
        if (! $(isNodeId "$NODE_ID")) ; then
            sleep 30 && echoWarn "WARNING: Status and Node ID is not available, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..." && continue
        else echoInfo "INFO: Success, $CONTAINER_NAME container id found: $NODE_ID" ; fi

        echoInfo "INFO: Awaiting first blocks to be synced..."
        HEIGHT=$(echo "$STATUS" | jsonQuickParse "latest_block_height" || echo -n "")

        if (! $(isNaturalNumber "$HEIGHT")) ; then
            echoWarn "INFO: New blocks are not beeing synced or produced yet, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..."
            sleep 10 && continue
        else echoInfo "INFO: Success, $CONTAINER_NAME container id is syncing new blocks" && break ; fi

        #if [[ $HEIGHT -le $PREVIOUS_HEIGHT ]] ; then
        #    echoWarn "WARNING: New blocks are not beeing synced yet! Current height: $HEIGHT, previous height: $PREVIOUS_HEIGHT, waiting up to $(timerSpan $TIMER_NAME $TIMEOUT) seconds ..."
        #    [ "$HEIGHT" != "0" ] && PREVIOUS_HEIGHT=$HEIGHT
        #    sleep 30 && continue
        #else echoInfo "INFO: Success, $CONTAINER_NAME container id is syncing new blocks" && break ; fi
    done

    echoInfo "INFO: Printing all $CONTAINER_NAME health logs..."
    docker inspect --format "{{json .State.Health }}" $($KIRA_SCRIPTS/container-id.sh "$CONTAINER_NAME") | jq '.Log[-1].Output' | xargs | sed 's/\\n/\n/g' || echo "INFO: Failed to display $CONTAINER_NAME container health logs"

    echoInfo "INFO: Printing $CONTAINER_NAME start logs..."
    cat $COMMON_LOGS/start.log | tail -n 150 || echoWarn "WARNING: Failed to display $CONTAINER_NAME container start logs"

    FAILURE="false"
    if [ "$(globGet ${CONTAINER_NAME}_STATUS)" != "running" ] ; then
        echoErr "ERROR: $CONTAINER_NAME did NOT acheive running status"
        FAILURE="true"
    else echoInfo "INFO: $CONTAINER_NAME was started sucessfully" ; fi

    if [ "$NODE_ID" != "$EXPECTED_NODE_ID" ] ; then
        echoErr "ERROR: $CONTAINER_NAME Node id check failed!"
        echoErr "ERROR: Expected '$EXPECTED_NODE_ID', but got '$NODE_ID'"
        FAILURE="true"
    else echoInfo "INFO: $CONTAINER_NAME node id check succeded '$NODE_ID' is a match" ; fi

    NETWORK=$(echo $STATUS | jsonQuickParse "network" 2>/dev/null || echo -n "")
    [ "$NETWORK_NAME" != "$NETWORK" ] && \
        echoErr "ERROR: Expected network name to be '$NETWORK_NAME' but got '$NETWORK'" && FAILURE="true"

    if [ "${FAILURE,,}" == "true" ] ; then
        echoErr "ERROR: $CONTAINER_NAME node setup failed"
        retry=$((retry + 1))
        if [[ $retry -le 2 ]] ; then
            echoInfo "INFO: Attempting $CONTAINER_NAME restart ${retry}/2"
            $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart"
            continue
        fi
        sleep 30 && exit 1
    else echoInfo "INFO: $CONTAINER_NAME launched sucessfully" && break ; fi
done

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: ${CONTAINER_NAME^^} INIT"
echoWarn "|  ELAPSED: $(timerSpan $TIMER_NAME) seconds"
echoWarn "------------------------------------------------"
set -x