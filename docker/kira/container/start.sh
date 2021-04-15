#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
set -x

echoInfo "INFO: Staring $NODE_TYPE container..."

HALT_CHECK="${COMMON_DIR}/halt"
EXIT_CHECK="${COMMON_DIR}/exit"
CFG_CHECK="${COMMON_DIR}/configuring"

if [ -f "$CFG_CHECK" ] ; then
    echoInfo "INFO: Waiting for container configuration to be finalized..."
    sleep 30
    exit 0
fi

while [ -f "$HALT_CHECK" ] || [ -f "$EXIT_CHECK" ]; do
    if [ -f "$EXIT_CHECK" ]; then
        echoInfo "INFO: Ensuring sekaid process is killed"
        touch $HALT_CHECK
        pkill -15 sekaid || echoWarn "WARNING: Failed to kill sekaid"
        rm -fv $EXIT_CHECK
    fi
    echoInfo "INFO: Waiting for container to be unhalted..."
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
