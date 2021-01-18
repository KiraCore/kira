#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

DOCKER_COMMON=$1
GENESIS_SOURCE=$2
GENESIS_DESTINATION=$3
VALIDATOR_NODE_ID=$4

i=0
IS_STARTED="false"
NODE_ID=""

rm -fv $GENESIS_DESTINATION

CONTAINER_NAME="validator"

while [ $i -le 40 ]; do
    i=$((i + 1))

    echo "INFO: Waiting for $CONTAINER_NAME container to start..."
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$CONTAINER_NAME" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true" ]; then
        sleep 12
        echo "WARNING: $CONTAINER_NAME container does not exists yet, waiting..."
        continue
    else
        echo "INFO: Success, $CONTAINER_NAME container was found"
    fi

    echo "INFO: Awaiting $CONTAINER_NAME initialization..."
    IS_STARTED=$(docker exec -i "$CONTAINER_NAME" [ -f /root/executed ] && echo "true" || echo "false")
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

echo "INFO: Printing health status..."
docker inspect --format "{{json .State.Health }}" "$CONTAINER_NAME" | jq || echo "INFO: Failed to display $CONTAINER_NAME container health status"

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