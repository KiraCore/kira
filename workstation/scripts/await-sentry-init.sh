#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/scripts/await-sentry-init.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

CONTAINER_NAME=$1
SENTRY_NODE_ID=$2
SAVE_SNAPSHOT=$3
SYNC_AWAIT=$4
[ -z "$SAVE_SNAPSHOT" ] && SAVE_SNAPSHOT="false"
[ -z "$SYNC_AWAIT" ] && SYNC_AWAIT="$SAVE_SNAPSHOT"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"
EXIT_FILE="$COMMON_PATH/exit"
SNAP_HEIGHT_FILE="$COMMON_PATH/snap_height"
SNAP_NAME_FILE="$COMMON_PATH/snap_name"
IFACES_RESTARTED="false"
DOCKER_SNAP_DESTINATION="$DOCKER_COMMON_RO/snap.zip"
RPC_PORT="KIRA_${CONTAINER_NAME^^}_RPC_PORT" && RPC_PORT="${!RPC_PORT}"

retry=0
while : ; do
    PREVIOUS_HEIGHT=0
    HEIGHT=0
    STATUS=""
    i=0
    NODE_ID=""
    IS_STARTED="false"
    while [[ $i -le 40 ]]; do
        i=$((i + 1))

        echoInfo "INFO: Waiting for container $CONTAINER_NAME to start..."
        CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$CONTAINER_NAME" || echo "error")
        if [ "${CONTAINER_EXISTS,,}" != "true" ]; then
            sleep 20
            echoWarn "WARNING: $CONTAINER_NAME container does not exists yet, waiting..."
            continue
        else
            echoInfo "INFO: Success, container $CONTAINER_NAME was found"
        fi

        echoInfo "INFO: Awaiting $CONTAINER_NAME initialization..."
        IS_STARTED="false" && [ -f "$COMMON_PATH/executed" ] && IS_STARTED="true"
        if [ "${IS_STARTED,,}" != "true" ] ; then
            sleep 20
            echoWarn "WARNING: $CONTAINER_NAME is not initialized yet"
            continue
        else
            echoInfo "INFO: Success, container was initialized"
        fi

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
            echoWarn "WARNING: New blocks are not beeing synced yet! Current height: $HEIGHT, previous height: $PREVIOUS_HEIGHT"
            [ "$HEIGHT" != "0" ] && PREVIOUS_HEIGHT=$HEIGHT
            sleep 10
            continue
        else
            echoInfo "INFO: Success, $CONTAINER_NAME container id is syncing new blocks"
            break
        fi
    done

    echoInfo "INFO: Printing all $CONTAINER_NAME health logs..."
    docker inspect --format "{{json .State.Health }}" $($KIRA_SCRIPTS/container-id.sh "$CONTAINER_NAME") | jq '.Log[-1].Output' | xargs | sed 's/\\n/\n/g' || echo "INFO: Failed to display $CONTAINER_NAME container health logs"

    echoInfo "INFO: Printing $CONTAINER_NAME start logs..."
    cat $COMMON_LOGS/start.log | tail -n 150 || echoWarn "WARNING: Failed to display $CONTAINER_NAME container start logs"

    FAILURE="false"
    if [ "${IS_STARTED,,}" != "true" ] ; then
        echoErr "ERROR: $CONTAINER_NAME was not started sucessfully within defined time"
        FAILURE="true"
    else
        echoInfo "INFO: $CONTAINER_NAME was started sucessfully"
    fi

    if [ "$NODE_ID" != "$SENTRY_NODE_ID" ] ; then
        echoErr "ERROR: $CONTAINER_NAME Node id check failed!"
        echoErr "ERROR: Expected '$SENTRY_NODE_ID', but got '$NODE_ID'"
        FAILURE="true"
    else
        echoInfo "INFO: $CONTAINER_NAME node id check succeded '$NODE_ID' is a match"
    fi

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
    else
        echoInfo "INFO: $CONTAINER_NAME launched sucessfully"
        break
    fi
done

if [ "${SYNC_AWAIT,,}" == "true" ] ; then
    echoInfo "INFO: $CONTAINER_NAME must be fully synced before setup can proceed"
    i=0
    BLOCKS_LEFT_OLD=0
    timerDel BLOCK_HEIGHT_SPAN
     
    while : ; do
        echoInfo "INFO: Awaiting node status..."
        sleep 10

        i=$((i + 1))
        STATUS=$(timeout 8 curl --fail 0.0.0.0:$RPC_PORT/status 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "") 
        if ($(isNullOrEmpty $STATUS)) ; then
            set +x
            echoInfo "INFO: Printing '$CONTAINER_NAME' start logs:"
            cat $COMMON_LOGS/start.log | tail -n 75 || echoWarn "WARNING: Failed to display '$CONTAINER_NAME' container start logs"
            echoErr "ERROR: Node failed or status could not be fetched ($i/3), your netwok connectivity might have been interrupted"

            [[ $i -le 3 ]] && sleep 10 && echoInfo "INFO: Next status check attempt in 10 seconds..." && continue

            echoErr "ERROR: $CONTAINER_NAME status check failed"
            sleep 30
            exit 1
        else
            i=0
        fi

        set -x
        #SYNCING=$(echo $STATUS | jsonQuickParse "catching_up" 2>/dev/null || echo -n "")
        #($(isNullOrEmpty "$SYNCING")) && SYNCING="false"
        #HEIGHT=$(echo "$STATUS" | jsonQuickParse "latest_block_height" 2>/dev/null || echo -n "")
        #(! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0
        HEIGHT=$(globGet "${CONTAINER_NAME}_BLOCK")
        SYNCING=$(globGet "${CONTAINER_NAME}_SYNCING")
        LATEST_BLOCK=$(globGet LATEST_BLOCK)
        MIN_HEIGH=$(globGet MIN_HEIGHT)
        DELTA_TIME=$(timerSpan BLOCK_HEIGHT_SPAN)

        timerStart BLOCK_HEIGHT_SPAN
        
        [[ $LATEST_BLOCK -gt $MIN_HEIGH ]] && MIN_HEIGH=$LATEST_BLOCK
        
        if [[ $HEIGHT -ge $MIN_HEIGH ]] ; then
            echoInfo "INFO: Node finished catching up."
            break
        fi

        [[ $DELTA_TIME -gt 600 ]] && echoErr "ERROR: $CONTAINER_NAME failed to catch up new blocks for over 10 minutes!" && exit 1

        BLOCKS_LEFT=$(($MIN_HEIGH - $HEIGHT))
        DELTA_HEIGHT=$(($BLOCKS_LEFT_OLD - $BLOCKS_LEFT))
        BLOCKS_LEFT_OLD=$BLOCKS_LEFT
        
        set +x
        if [[ $BLOCKS_LEFT -gt 0 ]] && [[ $DELTA_HEIGHT -gt 0 ]] && [[ $DELTA_TIME -gt 0 ]] ; then
            TIME_LEFT=$((($BLOCKS_LEFT * $DELTA_TIME) / $DELTA_HEIGHT))
            echoInfo "INFO: Estimated time left until catching up with min.height: $(prettyTime $TIME_LEFT)"
        fi
        echoInfo "INFO: Minimum height: $LATEST_BLOCK, current height: $HEIGHT, catching up: $SYNCING"
        echoInfo "INFO: Do NOT close your terminal, waiting for '$CONTAINER_NAME' to finish catching up..."
        set -x
        sleep 30
    done
fi

if [ "${SAVE_SNAPSHOT,,}" == "true" ] ; then
    echoInfo "INFO: Local snapshot must be created before network can be started"
    echoInfo "INFO: Halting $CONTAINER_NAME container"
    SNAP_NAME="${NETWORK_NAME}-${HEIGHT}-$(date -u +%s)"
    echo "$HEIGHT" >  $SNAP_HEIGHT_FILE
    echo "$SNAP_NAME" >  $SNAP_NAME_FILE
    $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart"

    echoInfo "INFO: Creating new snapshot..."
    i=0
    DESTINATION_DIR="$KIRA_SNAP/$SNAP_NAME"
    DESTINATION_FILE="${DESTINATION_DIR}.zip"
    while [ ! -d "$DESTINATION_DIR" ] || [ -f $SNAP_HEIGHT_FILE ] ; do
        i=$((i + 1))
        cat $COMMON_LOGS/start.log | tail -n 10 || echoWarn "WARNING: Failed to display '$CONTAINER_NAME' container start logs"
        echoInfo "INFO: Waiting for snapshot '$SNAP_NAME' to be created..."
        sleep 30
    done

    echoInfo "INFO: Packaging snapshot into '$DESTINATION_FILE' ..."
    cd $DESTINATION_DIR && zip -r "$DESTINATION_FILE" . *
    rm -rf "$DESTINATION_DIR"
    
    ls -1 "$KIRA_SNAP"
    [ ! -f "$DESTINATION_FILE" ] && echoErr "ERROR: Failed to create snpashoot, file $DESTINATION_FILE was not found." && exit 1
    echoInfo "INFO: New snapshot was created!"

    SNAP_STATUS="$KIRA_SNAP/status"
    mkdir -p $SNAP_STATUS
    echo "$SNAP_FILENAME" > "$SNAP_STATUS/latest"
    KIRA_SNAP_PATH=$DESTINATION_FILE
    CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$KIRA_SNAP_PATH\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
    [[ $HEIGHT -gt $MIN_HEIGH ]] && globSet MIN_HEIGHT $HEIGHT

    ln -fv "$KIRA_SNAP_PATH" "$DOCKER_SNAP_DESTINATION"
fi

