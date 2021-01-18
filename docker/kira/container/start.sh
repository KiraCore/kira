#!/bin/bash

exec 2>&1
set -e
set -x

echo "INFO: Staring $NODE_TYPE container..."

HALT_CHECK="${COMMON_DIR}/halt"

while [ -f "$HALT_CHECK" ]; do
  sleep 30
done

if [ "${NODE_TYPE,,}" == "sentry" ] || [ "${NODE_TYPE,,}" == "priv-sentry" ] ; then
    source $SELF_CONTAINER/sentry/start.sh
elif [ "${NODE_TYPE,,}" == "snapshoot" ] ; then
    source $SELF_CONTAINER/snapshoot/start.sh
elif [ "${NODE_TYPE,,}" == "validator" ] ; then
    source $SELF_CONTAINER/validator/start.sh
else
  echo "ERROR: Unknown node type '$NODE_TYPE'"
  exit 1
fi
