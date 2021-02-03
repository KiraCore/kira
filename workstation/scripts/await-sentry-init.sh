#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
set -x

CONTAINER_NAME=$1
SENTRY_NODE_ID=$2
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
PREVIOUS_HEIGHT=0
HEIGHT=0

i=0
NODE_ID=""
IS_STARTED="false"
while [ $i -le 40 ]; do
    i=$((i + 1))

    echoInfo "INFO: Waiting for container $CONTAINER_NAME to start..."
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$CONTAINER_NAME" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true" ]; then
        sleep 12
        echoWarn "WARNING: $CONTAINER_NAME container does not exists yet, waiting..."
        continue
    else
        echoInfo "INFO: Success, container $CONTAINER_NAME was found"
    fi

    echoInfo "INFO: Awaiting $CONTAINER_NAME initialization..."
    IS_STARTED="false" && [ -f "$COMMON_PATH/executed" ] && IS_STARTED="true"
    if [ "${IS_STARTED,,}" != "true" ] ; then
        sleep 12
        echoWarn "WARNING: $CONTAINER_NAME is not initialized yet"
        continue
    else
        echoInfo "INFO: Success, container was initialized"

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
        echoInfo "INFO: Success, $CONTAINER_NAME container id found: $NODE_ID"
    fi

    echoInfo "INFO: Awaiting first blocks to be synced..."
    HEIGHT=$(echo "$STATUS" | jq -rc '.SyncInfo.latest_block_height' || echo "")
    ( [ -z "${HEIGHT}" ] || [ "${HEIGHT,,}" == "null" ] ) && HEIGHT=$(echo "$STATUS" | jq -rc '.sync_info.latest_block_height' || echo "")
    ( [ -z "$HEIGHT" ] || [ -z "${HEIGHT##*[!0-9]*}" ] ) && HEIGHT=0
    
    if [ $HEIGHT -le $PREVIOUS_HEIGHT ] ; then
        echoWarn "WARNING: New blocks are not beeing synced yet!"
        sleep 10
        PREVIOUS_HEIGHT=$HEIGHT
        continue
    else
        echoInfo "INFO: Success, $CONTAINER_NAME container id is syncing new blocks"
        break
    fi
done

echoInfo "INFO: Printing all $CONTAINER_NAME health logs..."
docker inspect --format "{{json .State.Health }}" $($KIRA_SCRIPTS/container-id.sh "$CONTAINER_NAME") | jq '.Log[-1].Output' | xargs | sed 's/\\n/\n/g' || echo "INFO: Failed to display $CONTAINER_NAME container health logs"

echoInfo "INFO: Printing $CONTAINER_NAME start logs..."
cat $COMMON_LOGS/start.log | tail -n 75 || echoWarn "WARNING: Failed to display $CONTAINER_NAME container start logs"

if [ "${IS_STARTED,,}" != "true" ] ; then
    echoErr "ERROR: $CONTAINER_NAME was not started sucessfully within defined time"
    exit 1
else
    echoInfo "INFO: $CONTAINER_NAME was started sucessfully"
fi

if [ "$NODE_ID" != "$SENTRY_NODE_ID" ] ; then
    echoErr "ERROR: $CONTAINER_NAME Node id check failed!"
    echoErr "ERROR: Expected '$SENTRY_NODE_ID', but got '$NODE_ID'"
    exit 1
else
    echoInfo "INFO: $CONTAINER_NAME node id check succeded '$NODE_ID' is a match"
fi

if [ $HEIGHT -le $PREVIOUS_HEIGHT ] ; then
    echoErr "ERROR: $CONTAINER_NAME node failed to start catching up new blocks, check node configuration, peers or if seed nodes function correctly."
    exit 1
fi

