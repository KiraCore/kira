#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

i=0
CHECK_SENTRY_NODE_ID=""
while [ $i -le 18 ]; do
    i=$((i + 1))
    echo "INFO: Awaiting node status..."
    CHECK_SENTRY_NODE_ID=$(docker exec -i "sentry" sekaid status | jq -r '.node_info.id' 2>/dev/null | xargs || echo "")
    if [ -z "$CHECK_SENTRY_NODE_ID" ]; then
        sleep 3
        echo "WARNING: Status and Node ID is not available"
        continue
    else
        echo "INFO: Success, sentry node id found: $CHECK_SENTRY_NODE_ID"
        break
    fi
done

if [ -z "$CHECK_SENTRY_NODE_ID" ]; then
    echo "ERROR: sentry node error"
    exit 1
fi