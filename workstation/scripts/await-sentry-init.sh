#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

CONTAINER_NAME=$1
SENTRY_NODE_ID=$2

i=0
NODE_ID=""
IS_STARTED="false"
while [ $i -le 40 ]; do
    i=$((i + 1))

    echo "INFO: Waiting for container $CONTAINER_NAME to start..."
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$CONTAINER_NAME" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true" ]; then
        sleep 12
        echo "WARNING: $CONTAINER_NAME container does not exists yet, waiting..."
        continue
    else
        echo "INFO: Success, container $CONTAINER_NAME was found"
    fi

    echo "INFO: Awaiting $CONTAINER_NAME initialization..."
    IS_STARTED=$(docker exec -i "$CONTAINER_NAME" [ -f /root/executed ] && echo "true" || echo "false")
    if [ "${IS_STARTED,,}" != "true" ] ; then
        sleep 12
        echo "WARNING: $CONTAINER_NAME is not initialized yet"
        continue
    else
        echo "INFO: Success, container was initialized"
    fi

    echo "INFO: Awaiting node status..."
    NODE_ID=$(docker exec -i "$CONTAINER_NAME" sekaid status | jq -r '.node_info.id' 2>/dev/null | xargs || echo "")
    if [ -z "$NODE_ID" ]; then
        sleep 12
        echo "WARNING: Status and Node ID is not available"
        continue
    else
        echo "INFO: Success, $CONTAINER_NAME container id found: $NODE_ID"
        break
    fi
done

echo "INFO: Printing $CONTAINER_NAME health status..."
docker exec -i $CONTAINER_NAME cat /common/healthcheck_script_output.txt | tail -n 50 || echo "INFO: Failed to display $CONTAINER_NAME container health logs"

if [ "${IS_STARTED,,}" != "true" ] ; then
    echo "ERROR: $CONTAINER_NAME was not started sucessfully within defined time"
    exit 1
else
    echo "INFO: $CONTAINER_NAME was started sucessfully"
fi


if [ "$NODE_ID" != "$SENTRY_NODE_ID" ] ; then
    echo "ERROR: $CONTAINER_NAME Node id check failed!"
    echo "ERROR: Expected '$SENTRY_NODE_ID', but got '$NODE_ID'"
    exit 1
else
    echo "INFO: $CONTAINER_NAME node id check succeded '$NODE_ID' is a match"
fi

