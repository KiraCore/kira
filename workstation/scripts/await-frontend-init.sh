#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

i=0
IS_STARTED="false"

while [ $i -le 40 ]; do
    i=$((i + 1))

    echo "INFO: Waiting for frontend container to start..."
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "frontend" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true" ]; then
        sleep 6
        echo "WARNING: frontend container does not exists yet, waiting..."
        continue
    else
        echo "INFO: Success, frontend container was found"
    fi

    echo "INFO: Awaiting frontend initalization..."
    IS_STARTED=$(docker exec -i "frontend" [ -f /root/executed ] && echo "true" || echo "false")
    if [ "${IS_STARTED,,}" != "true" ]; then
        sleep 6
        echo "WARNING: Frontend is not initalized yet"
        continue
    else
        echo "INFO: Success, frontend was initalized"
        break
    fi
done

if [ "${IS_STARTED,,}" != "true" ]; then
    echo "ERROR: Frontend was not started sucessfully within defined time"
    exit 1
else
    echo "INFO: Frontend was started sucessfully"
fi
