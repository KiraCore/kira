#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

DOCKER_COMMON=$1
SENTRY_NODE_ID=$2

i=0
SEKAID_VERSION="error"
while [ $i -le 18 ]; do
    i=$((i + 1))

    echo "INFO: Waiting for sentry container to start..."
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "sentry" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" != "true" ]; then
        sleep 3
        echo "WARNING: Sentry container does not exists yet, waiting..."
        continue
    else
        echo "INFO: Success, sentry container was found"
    fi

    echo "INFO: Checking if sekai was installed..."
    SEKAID_VERSION=$(docker exec -i "sentry" sekaid version || echo "error")
    if [ "${SEKAID_VERSION,,}" == "error" ]; then
        sleep 3
        echo "WARNING: sekaid was not installed yet, waiting..."
        continue
    else
        echo "INFO: Success, sekaid $SEKAID_VERSIO is present"
    fi

    if [ ! -f "$DOCKER_COMMON/sentry/started" ]; then
        sleep 3
        echo "WARNING: Sentry is not started yet"
        continue
    else
        echo "INFO: Success, sentry is started"
        break
    fi

done

CHECK_SENTRY_NODE_ID=$(docker exec -i "sentry" sekaid status | jq -r '.node_info.id' 2>/dev/null | xargs || echo "")

if [ "$CHECK_SENTRY_NODE_ID" != "$SENTRY_NODE_ID" ]; then
    echo
    echo "ERROR: Check Sentry Node id check failed!"
    echo "ERROR: Expected '$SENTRY_NODE_ID', but got '$CHECK_SENTRY_NODE_ID'"
    exit 1
else
    echo "INFO: Sentry node id check succeded '$CHECK_SENTRY_NODE_ID' is a match"
    exit 0
fi
