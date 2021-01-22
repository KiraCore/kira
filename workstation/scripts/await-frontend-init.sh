#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

i=0
IS_STARTED="false"
CONTAINER_NAME="frontend"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"

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
    if [ "${IS_STARTED,,}" != "true" ]; then
        sleep 12
        echo "WARNING: $CONTAINER_NAME is not initialized yet"
        continue
    else
        echo "INFO: Success, $CONTAINER_NAME was initialized"
        break
    fi
done

echo "INFO: Printing $CONTAINER_NAME health status..."
cat $COMMON_PATH/healthcheck_script_output.txt | tail -n 50 || echo "INFO: Failed to display $CONTAINER_NAME container health logs"

if [ "${IS_STARTED,,}" != "true" ]; then
    echo "ERROR: $CONTAINER_NAME was not started sucessfully within defined time"
    exit 1
else
    echo "INFO: $CONTAINER_NAME was started sucessfully"
fi
