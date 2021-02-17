#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
set -x

DOCKER_COMMON=$1
GENESIS_SOURCE=$2
GENESIS_DESTINATION=$3
VALIDATOR_NODE_ID=$4

CONTAINER_NAME="validator"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
IS_STARTED="false"
NODE_ID=""
PREVIOUS_HEIGHT=0
HEIGHT=0
i=0

rm -fv $GENESIS_DESTINATION

while [ $i -le 40 ]; do
    i=$((i + 1))

    echoInfo "INFO: Waiting for $CONTAINER_NAME container to start..."
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$CONTAINER_NAME" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true" ] ; then
        sleep 12
        echoWarn "WARNING: $CONTAINER_NAME container does not exists yet, waiting..."
        continue
    else
        echoInfo "INFO: Success, $CONTAINER_NAME container was found"
    fi

    echoInfo "INFO: Awaiting $CONTAINER_NAME initialization..."
    IS_STARTED="false" && [ -f "$COMMON_PATH/executed" ] && IS_STARTED="true"
    if [ "${IS_STARTED,,}" != "true" ] ; then
        sleep 12
        echoWarn "WARNING: $CONTAINER_NAME is not initialized yet"
        continue
    else
        echoInfo "INFO: Success, $CONTAINER_NAME was initialized"
    fi

    # copy genesis from validator only if internal node syncing takes place
    if [ "${EXTERNAL_SYNC,,}" != "true" ] ; then 
        echoInfo "INFO: Attempting to access genesis file..."
        docker cp -a $CONTAINER_NAME:$GENESIS_SOURCE $GENESIS_DESTINATION || rm -fv $GENESIS_DESTINATION
    else
        echoInfo "INFO: Copying genesis from external resource..."
        cp -f -a -v "$KIRA_CONFIGS/genesis.json" "$GENESIS_DESTINATION"
    fi

    # make sure genesis is present in the destination path
    if [ ! -f "$GENESIS_DESTINATION" ] ; then
        sleep 12
        echoWarn "WARNING: Failed to copy genesis file from $CONTAINER_NAME"
        continue
    else
        echoInfo "INFO: Success, genesis file was copied to $GENESIS_DESTINATION"
    fi

    echoInfo "INFO: Awaiting node status..."
    STATUS=$(docker exec -i "$CONTAINER_NAME" sekaid status 2>&1 | jq -rc '.' 2> /dev/null || echo "")
    NODE_ID=$(echo "$STATUS" | jq -rc '.NodeInfo.id' 2>/dev/null | xargs || echo "")
    ( [ -z "$NODE_ID" ] || [ "$NODE_ID" == "null" ] ) && NODE_ID=$(echo "$STATUS" | jq -rc '.node_info.id' 2>/dev/null | xargs || echo "")
    if [ -z "$NODE_ID" ] || [ "$NODE_ID" == "null" ] ; then
        sleep 12
        echoWarn "WARNING: Status and Node ID is not available"
        continue
    else
        echoInfo "INFO: Success, $CONTAINER_NAME node id found: $NODE_ID"
    fi

    echoInfo "INFO: Awaiting first blocks to be synced or produced..."
    HEIGHT=$(echo "$STATUS" | jq -rc '.SyncInfo.latest_block_height' || echo "")
    ( [ -z "${HEIGHT}" ] || [ "${HEIGHT,,}" == "null" ] ) && HEIGHT=$(echo "$STATUS" | jq -rc '.sync_info.latest_block_height' || echo "")
    ( [ -z "$HEIGHT" ] || [ -z "${HEIGHT##*[!0-9]*}" ] ) && HEIGHT=0
    
    if [ $HEIGHT -le $PREVIOUS_HEIGHT ] ; then
        echoWarn "INFO: Please wait, new blocks are not beeing synced or produced yet!"
        sleep 10
        PREVIOUS_HEIGHT=$HEIGHT
        continue
    else
        echoInfo "INFO: Success, $CONTAINER_NAME container id is syncing or producing new blocks"
        break
    fi
done

echoInfo "INFO: Printing all $CONTAINER_NAME health logs..."
docker inspect --format "{{json .State.Health }}" $($KIRA_SCRIPTS/container-id.sh "$CONTAINER_NAME") | jq '.Log[-1].Output' | xargs | sed 's/\\n/\n/g' || echo "INFO: Failed to display $CONTAINER_NAME container health logs"

echoInfo "INFO: Printing $CONTAINER_NAME start logs..."
cat $COMMON_LOGS/start.log | tail -n 75 || echoWarn "WARNING: Failed to display $CONTAINER_NAME container start logs"

if [ ! -f "$GENESIS_DESTINATION" ] ; then
    echoErr "ERROR: Failed to copy genesis file from the $CONTAINER_NAME node"
    exit 1
fi

if [ "$NODE_ID" != "$VALIDATOR_NODE_ID" ]; then
    echoErr "ERROR: Check $CONTAINER_NAME Node id check failed!"
    echoErr "ERROR: Expected '$VALIDATOR_NODE_ID', but got '$NODE_ID'"
    exit 1
else
    echoInfo "INFO: $CONTAINER_NAME node id check succeded '$NODE_ID' is a match"
    exit 0
fi

if [ "${IS_STARTED,,}" != "true" ] ; then
    echoErr "ERROR: $CONTAINER_NAME was not started sucessfully within defined time"
    exit 1
else
    echoInfo "INFO: $CONTAINER_NAME was started sucessfully"
fi

if [ $HEIGHT -le $PREVIOUS_HEIGHT ] ; then
    echoErr "ERROR: $CONTAINER_NAME node failed to start catching up or prodcing new blocks, check node configuration, peers or if seed nodes function correctly."
    exit 1
fi
