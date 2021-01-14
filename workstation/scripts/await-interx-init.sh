#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

i=0
IS_STARTED="false"
FAUCET_ADDR=""
INTERX_STATUS_CODE=""
while [ $i -le 20 ]; do
    i=$((i + 1))

    echo "INFO: Waiting for interx container to start..."
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "interx" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true" ]; then
        sleep 12
        echo "WARNING: INTERX container does not exists yet, waiting..."
        continue
    else
        echo "INFO: Success, INTERX container was found"
    fi

    echo "INFO: Awaiting interx initialization..."
    IS_STARTED=$(docker exec -i "interx" [ -f /root/executed ] && echo "true" || echo "false")
    if [ "${IS_STARTED,,}" != "true" ]; then
        sleep 12
        echo "WARNING: INTERX is not initialized yet"
        continue
    else
        echo "INFO: Success, interx was initialized"
    fi

    echo "INFO: Awaiting interx service to start..."
    INTERX_STATUS_CODE=$(docker exec -i "interx" curl -s -o /dev/null -w '%{http_code}' 0.0.0.0:$DEFAULT_INTERX_PORT/api/status 2>/dev/null | xargs || echo "")

    if [[ "${INTERX_STATUS_CODE}" -ne "200" ]]; then
        sleep 30
        echo "WARNING: INTERX is not started yet"
        continue
    fi

    echo "INFO: Awaiting interx faucet to initalize..."
    FAUCET_ADDR=$(docker exec -i "interx" curl 0.0.0.0:$DEFAULT_INTERX_PORT/api/faucet 2>/dev/null | jq -r '.address' || echo "")

    if [ -z "${FAUCET_ADDR}" ] ; then
        sleep 30
        echo "WARNING: INTERX faucet is initalized yet"
        continue
    else
        echo "INFO: Success, faucet was found"
        break
    fi
done

if [[ "$INTERX_STATUS_CODE" -ne "200" ]] || [ -z "$FAUCET_ADDR" ] ; then
    echo "ERROR: INTERX was not started sucessfully within defined time"
    exit 1
else
    echo "INFO: INTERX was started sucessfully"
fi
