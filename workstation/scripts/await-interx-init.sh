#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

i=0
IS_STARTED="false"
while [ $i -le 60 ]; do
    i=$((i + 1))

    echo "INFO: Waiting for interx container to start..."
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "interx" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true" ]; then
        sleep 3
        echo "WARNING: INTERX container does not exists yet, waiting..."
        continue
    else
        echo "INFO: Success, INTERX container was found"
    fi

    echo "INFO: Awaiting interx initalization..."
    IS_STARTED=$(docker exec -i "interx" [ -f /root/executed ] && echo "true" || echo "false")
    if [ "${IS_STARTED,,}" != "true" ]; then
        sleep 3
        echo "WARNING: INTERX is not initalized yet"
        continue
    else
        echo "INFO: Success, interx was initalized"
    fi

    echo "INFO: Awaiting interx build..."
    INTERX_STATUS_CODE="$(curl -s -o /dev/null -I -w '%{http_code}' http://10.4.0.2:11000/api/cosmos/status)"

    if [ "$INDEX_STATUS_CODE" -ne "200" ]; then
        sleep 3
        echo "WARNING: INTERX is not built yet"
        continue
    else
        echo "INFO: Success, interx was built"
    fi
done

INTERX_STATUS_CODE="$(curl -s -o /dev/null -I -w '%{http_code}' http://10.4.0.2:11000/api/cosmos/status)"
if [ "$INDEX_STATUS_CODE" -ne "200" ]; then
    echo "ERROR: INTERX was not started sucessfully within defined time"
    exit 1
else
    echo "INFO: INTERX was started sucessfully"
fi
