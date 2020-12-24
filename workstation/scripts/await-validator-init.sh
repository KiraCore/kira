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

while [ $i -le 40 ]; do
    i=$((i + 1))

    echo "INFO: Waiting for validator container to start..."
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "validator" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true" ]; then
        sleep 3
        echo "WARNING: Validator container does not exists yet, waiting..."
        continue
    else
        echo "INFO: Success, validator container was found"
    fi

    echo "INFO: Awaiting validator initalization..."
    IS_STARTED=$(docker exec -i "validator" [ -f /root/executed ] && echo "true" || echo "false")
    if [ "${IS_STARTED,,}" != "true" ] ; then
        sleep 3
        echo "WARNING: Validator is not initalized yet"
        continue
    else
        echo "INFO: Success, validator was initalized"
    fi

    echo "INFO: Attempting to access genesis file..."
    docker cp -a validator:$GENESIS_SOURCE $GENESIS_DESTINATION || rm -fv $GENESIS_DESTINATION

    if [ ! -f "$GENESIS_DESTINATION" ]; then
        sleep 3
        echo "WARNING: Failed to copy genesis file from validator"
        continue
    else
        echo "INFO: Success, genesis file was copied to $GENESIS_DESTINATION"
    fi

    echo "INFO: Awaiting node status..."
    NODE_ID=$(docker exec -i "validator" sekaid status | jq -r '.node_info.id' 2>/dev/null | xargs || echo "")
    if [ -z "$NODE_ID" ]; then
        sleep 3
        echo "WARNING: Status and Node ID is not available"
        continue
    else
        echo "INFO: Success, validator node id found: $NODE_ID"
        break
    fi
done

if [ ! -f "$GENESIS_DESTINATION" ] ; then
    echo "ERROR: Failed to copy copy genesis file from the validator node"
    exit 1
fi

if [ "$NODE_ID" != "$VALIDATOR_NODE_ID" ]; then
    echo "ERROR: Check Validator Node id check failed!"
    echo "ERROR: Expected '$VALIDATOR_NODE_ID', but got '$NODE_ID'"
    exit 1
else
    echo "INFO: Validator node id check succeded '$NODE_ID' is a match"
    exit 0
fi

if [ "${IS_STARTED,,}" != "true" ] ; then
    echo "ERROR: Validator was not started sucessfully within defined time"
    exit 1
else
    echo "INFO: Validator was started sucessfully"
fi