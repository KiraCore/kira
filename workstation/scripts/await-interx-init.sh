#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

i=0
IS_STARTED="false"
FAUCET_ADDR=""
INTERX_STATUS_CODE=""
CONTAINER_NAME="interx"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"

while [ $i -le 20 ]; do
    i=$((i + 1))

    echo "INFO: Waiting for interx container to start..."
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "interx" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true" ]; then
        sleep 12
        echo "WARNING: $CONTAINER_NAME container does not exists yet, waiting..."
        continue
    else
        echo "INFO: Success, $CONTAINER_NAME container was found"
    fi

    echo "INFO: Awaiting interx initialization..."
    IS_STARTED=$(docker exec -i "interx" [ -f /root/executed ] && echo "true" || echo "false")
    if [ "${IS_STARTED,,}" != "true" ]; then
        sleep 12
        echo "WARNING: $CONTAINER_NAME is not initialized yet"
        continue
    else
        echo "INFO: Success, interx was initialized"
    fi

    echo "INFO: Awaiting interx service to start..."
    INTERX_STATUS_CODE=$(docker exec -i "interx" curl -s -o /dev/null -w '%{http_code}' 0.0.0.0:$DEFAULT_INTERX_PORT/api/status 2>/dev/null | xargs || echo "")

    if [[ "${INTERX_STATUS_CODE}" -ne "200" ]]; then
        sleep 30
        echo "WARNING: $CONTAINER_NAME is not started yet"
        continue
    fi

    echo "INFO: Awaiting interx faucet to initalize..."
    FAUCET_ADDR=$(docker exec -i "interx" curl 0.0.0.0:$DEFAULT_INTERX_PORT/api/faucet 2>/dev/null | jq -r '.address' || echo "")

    if [ -z "${FAUCET_ADDR}" ] ; then
        sleep 30
        echo "WARNING: $CONTAINER_NAME faucet is initalized yet"
        continue
    else
        echo "INFO: Success, faucet was found"
        break
    fi
done

echo "INFO: Printing $CONTAINER_NAME health status..."
cat $COMMON_PATH/healthcheck_script_output.txt | tail -n 50 || echo "INFO: Failed to display $CONTAINER_NAME container health logs"

if [[ "$INTERX_STATUS_CODE" -ne "200" ]] || [ -z "$FAUCET_ADDR" ] ; then
    echo "ERROR: $CONTAINER_NAME was not started sucessfully within defined time"
    exit 1
else
    echo "INFO: $CONTAINER_NAME was started sucessfully"
fi
