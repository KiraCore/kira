#!/bin/bash

exec 2>&1
set -x

set +e && source "/etc/profile" &>/dev/null && set -e

echo "INFO: Healthcheck => START"
sleep 30 # rate limit

find "/var/log/journal" -type f -size +256k -exec truncate --size=128k {} +
find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} +

RPC_STATUS="$(curl 127.0.0.1:11000/status 2>/dev/null)" || RPC_STATUS="{}"
RPC_CATCHING_UP="$(echo $RPC_STATUS | jq -r '.result.sync_info.catching_up')" || RPC_CATCHING_UP="true"
