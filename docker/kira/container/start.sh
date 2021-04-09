#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
set -x

echoInfo "INFO: Staring $NODE_TYPE container..."

HALT_CHECK="${COMMON_DIR}/halt"

while [ -f "$HALT_CHECK" ]; do
  sleep 30
done

if [ "${NODE_TYPE,,}" == "sentry" ] || [ "${NODE_TYPE,,}" == "priv_sentry" ] || [ "${NODE_TYPE,,}" == "seed" ]; then
  $SELF_CONTAINER/sentry/start.sh
elif [ "${NODE_TYPE,,}" == "snapshot" ]; then
  $SELF_CONTAINER/snapshot/start.sh
elif [ "${NODE_TYPE,,}" == "validator" ]; then
  $SELF_CONTAINER/validator/start.sh
else
  echoErr "ERROR: Unknown node type '$NODE_TYPE'"
  exit 1
fi
