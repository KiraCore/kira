#!/bin/bash

exec 2>&1
set -x

set +e && source "/etc/profile" &>/dev/null && set -e
HALT_CHECK="${COMMON_DIR}/halt"

if [ -f "$HALT_CHECK" ]; then
  exit 0
fi

echo "INFO: Healthcheck => START"
sleep 30 # rate limit

find "/var/log/journal" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate journal"
find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate self logs"


if [ "${HALT_CHECK,,}" == "sentry" ] || [ "${HALT_CHECK,,}" == "priv_sentry" ] ; then
    source $SELF_CONTAINER/sentry/healthcheck.sh
elif [ "${HALT_CHECK,,}" == "snapshoot" ] ; then
    source $SELF_CONTAINER/snapshoot/healthcheck.sh
elif [ "${HALT_CHECK,,}" == "validator" ] ; then
    source $SELF_CONTAINER/validator/healthcheck.sh
else
  echo "ERROR: Unknown node type '$NODE_TYPE'"
  exit 1
fi