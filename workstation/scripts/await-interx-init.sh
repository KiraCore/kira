#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

i=0
IS_STARTED="false"
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

    echo "INFO: Awaiting interx initalization..."
    IS_STARTED=$(docker exec -i "interx" [ -f /root/executed ] && echo "true" || echo "false")
    if [ "${IS_STARTED,,}" != "true" ]; then
        sleep 12
        echo "WARNING: INTERX is not initalized yet"
        continue
    else
        echo "INFO: Success, interx was initalized"
    fi

    echo "INFO: Awaiting interx build to test..."
    FAUCET_ADDR=$(docker exec -i "interx" curl http://127.0.0.1:11000/api/faucet 2>/dev/null | xargs || echo "")

    if [[ "${FAUCET_ADDR}" -eq "" ]]; then
        sleep 30
        echo "WARNING: INTERX is not built yet"
        continue
    else
        echo "INFO: Success, interx was built"
    fi

    echo "INFO: Awaiting interx build to finalize..."
    INTERX_STATUS_CODE=$(docker exec -i "interx" curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:11000/api/status 2>/dev/null | xargs || echo "")

    if [[ "${INTERX_STATUS_CODE}" -ne "200" ]]; then
        sleep 30
        echo "WARNING: INTERX is not built yet"
        continue
    else
        echo "INFO: Success, interx was built"
        break
    fi
done

INTERX_STATUS_CODE=$(docker exec -i "interx" curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:11000/api/status 2>/dev/null | xargs || echo "")
if [[ "$INTERX_STATUS_CODE" -ne "200" ]]; then
    echo "ERROR: INTERX was not started sucessfully within defined time"
    exit 1
else
    echo "INFO: INTERX was started sucessfully"
fi
