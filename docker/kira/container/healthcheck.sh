#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
set -x

echo "INFO: Health check => START"
sleep 30 # rate limit not to overextend the log files

HALT_CHECK="${COMMON_DIR}/halt"
EXIT_CHECK="${COMMON_DIR}/exit"

if [ -f "$EXIT_CHECK" ]; then
  echo "INFO: Ensuring sekaid process is killed"
  touch $HALT_CHECK
  pkill -15 sekaid || echo "WARNING: Failed to kill sekaid"
  rm -fv $EXIT_CHECK
fi

if [ -f "$HALT_CHECK" ]; then
  echo "INFO: health heck => STOP (halted)"
  exit 0
fi

find "/var/log/journal" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate journal"
find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate self logs"
find "$COMMON_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate common logs"

FAILED="false"
if [ "${NODE_TYPE,,}" == "sentry" ] || [ "${NODE_TYPE,,}" == "priv_sentry" ] || [ "${NODE_TYPE,,}" == "seed" ]; then
  $SELF_CONTAINER/sentry/healthcheck.sh || FAILED="true"
elif [ "${NODE_TYPE,,}" == "snapshot" ]; then
  $SELF_CONTAINER/snapshot/healthcheck.sh || FAILED="true"
elif [ "${NODE_TYPE,,}" == "validator" ]; then
  $SELF_CONTAINER/validator/healthcheck.sh || FAILED="true"
else
  echo "ERROR: Unknown node type '$NODE_TYPE'"
  exit 1
fi

if [ "$FAILED" == "true" ] ; then
    echo "ERROR: $NODE_TYPE healthcheck failed"
    exit 1
else
    exit 0
fi

