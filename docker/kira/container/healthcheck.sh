#!/bin/bash

exec 2>&1
set -x

echo "INFO: Health check => START"
sleep 30 # rate limit not to overextend the log files

set +e && source "/etc/profile" &>/dev/null && set -e
HALT_CHECK="${COMMON_DIR}/halt"

if [ -f "$HALT_CHECK" ]; then
  echo "INFO: Healtc heck => STOP (halted)"
  exit 0
fi

find "/var/log/journal" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate journal"
find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate self logs"
find "$COMMON_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate common logs"

if [ "${NODE_TYPE,,}" == "sentry" ] || [ "${NODE_TYPE,,}" == "priv_sentry" ] ; then
    $SELF_CONTAINER/sentry/healthcheck.sh
elif [ "${NODE_TYPE,,}" == "snapshoot" ] ; then
    $SELF_CONTAINER/snapshoot/healthcheck.sh
elif [ "${NODE_TYPE,,}" == "validator" ] ; then
    $SELF_CONTAINER/validator/healthcheck.sh
else
  echo "ERROR: Unknown node type '$NODE_TYPE'"
  exit 1
fi

exit 0