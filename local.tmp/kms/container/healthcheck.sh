#!/bin/bash

exec 2>&1
set -x

set +e && source "/etc/profile" &>/dev/null && set -e

echo "INFO: Healthcheck => START"
sleep 30 # rate limit

find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} +
