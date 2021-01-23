#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

DOCKER_COMMON=$1
GENESIS_SOURCE=$2
GENESIS_DESTINATION=$3
VALIDATOR_NODE_ID=$4

i=0
IS_STARTED="false"
NODE_ID=""

rm -fv $GENESIS_DESTINATION

CONTAINER_NAME="validator"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"

while [ $i -le 40 ]; do
    i=$((i + 1))

    echo "INFO: Waiting for $CONTAINER_NAME container to start..."
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$CONTAINER_NAME" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true" ] ; then
        sleep 12
        echo "WARNING: $CONTAINER_NAME container does not exists yet, waiting..."
        continue
    else
        echo "INFO: Success, $CONTAINER_NAME container was found"
    fi

    echo "INFO: Awaiting $CONTAINER_NAME initialization..."
    IS_STARTED="false" && [ -f "$COMMON_PATH/executed" ] && IS_STARTED="true"
    if [ "${IS_STARTED,,}" != "true" ] ; then
        sleep 12
        echo "WARNING: $CONTAINER_NAME is not initialized yet"
        continue
    else
        echo "INFO: Success, $CONTAINER_NAME was initialized"
    fi

    echo "INFO: Attempting to access genesis file..."
    docker cp -a $CONTAINER_NAME:$GENESIS_SOURCE $GENESIS_DESTINATION || rm -fv $GENESIS_DESTINATION

    if [ ! -f "$GENESIS_DESTINATION" ]; then
        sleep 12
        echo "WARNING: Failed to copy genesis file from $CONTAINER_NAME"
        continue
    else
        echo "INFO: Success, genesis file was copied to $GENESIS_DESTINATION"
    fi

    echo "INFO: Awaiting node status..."
    NODE_ID=$(docker exec -i "$CONTAINER_NAME" sekaid status | jq -r '.node_info.id' 2>/dev/null | xargs || echo "")
    if [ -z "$NODE_ID" ]; then
        sleep 12
        echo "WARNING: Status and Node ID is not available"
        continue
    else
        echo "INFO: Success, $CONTAINER_NAME node id found: $NODE_ID"
        break
    fi
done

echo "INFO: Printing $CONTAINER_NAME health logs..."
cat $COMMON_LOGS/healthcheck.log | tail -n 75 || echo "INFO: Failed to display $CONTAINER_NAME container health logs"
echo "INFO: Printing $CONTAINER_NAME start logs..."
cat $COMMON_LOGS/start.log | tail -n 75 || echo "INFO: Failed to display $CONTAINER_NAME container start logs"

if [ ! -f "$GENESIS_DESTINATION" ] ; then
    echo "ERROR: Failed to copy genesis file from the $CONTAINER_NAME node"
    exit 1
fi

if [ "$NODE_ID" != "$VALIDATOR_NODE_ID" ]; then
    echo "ERROR: Check $CONTAINER_NAME Node id check failed!"
    echo "ERROR: Expected '$VALIDATOR_NODE_ID', but got '$NODE_ID'"
    exit 1
else
    echo "INFO: $CONTAINER_NAME node id check succeded '$NODE_ID' is a match"
    exit 0
fi

if [ "${IS_STARTED,,}" != "true" ] ; then
    echo "ERROR: $CONTAINER_NAME was not started sucessfully within defined time"
    exit 1
else
    echo "INFO: $CONTAINER_NAME was started sucessfully"
fi