#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

i=0
IS_STARTED="false"
CONTAINER_NAME="frontend"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"

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
    IS_STARTED="false" && [ -f "$COMMON_PATH/executed" ] && IS_STARTED="true"
    if [ "${IS_STARTED,,}" != "true" ]; then
        sleep 12
        echo "WARNING: $CONTAINER_NAME is not initialized yet"
        continue
    else
        echo "INFO: Success, $CONTAINER_NAME was initialized"
        break
    fi
done

echo "INFO: Printing all $CONTAINER_NAME health logs..."
cat $COMMON_LOGS/healthcheck.log | tail -n 75 || echo "INFO: Failed to display $CONTAINER_NAME container health logs"
echo "INFO: Printing all $CONTAINER_NAME start logs..."
cat $COMMON_LOGS/start.log | tail -n 75 || echo "INFO: Failed to display $CONTAINER_NAME container start logs"

if [ "${IS_STARTED,,}" != "true" ]; then
    echo "ERROR: $CONTAINER_NAME was not started sucessfully within defined time"
    exit 1
else
    echo "INFO: $CONTAINER_NAME was started sucessfully"
fi
