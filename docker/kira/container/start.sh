#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
set -x

echoInfo "INFO: Staring $NODE_TYPE container $KIRA_SETUP_VER ..."

mkdir -p $GLOB_STORE_DIR

HALT_CHECK="${COMMON_DIR}/halt"
EXIT_CHECK="${COMMON_DIR}/exit"
CFG_CHECK="${COMMON_DIR}/configuring"
timerStart "catching_up"
timerStart "success"

RESTART_COUNTER=$(globGet RESTART_COUNTER)
if ($(isNaturalNumber $RESTART_COUNTER)) ; then
    globSet RESTART_COUNTER "$(($RESTART_COUNTER+1))"
    globSet RESTART_TIME "$(date -u +%s)"
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

touch $CFG_CHECK
FAILED="false"
if [ "${NODE_TYPE,,}" == "sentry" ] || [ "${NODE_TYPE,,}" == "priv_sentry" ] || [ "${NODE_TYPE,,}" == "seed" ]; then
    $SELF_CONTAINER/sentry/start.sh || FAILED="true"
elif [ "${NODE_TYPE,,}" == "snapshot" ]; then
    $SELF_CONTAINER/snapshot/start.sh || FAILED="true"
elif [ "${NODE_TYPE,,}" == "validator" ]; then
    $SELF_CONTAINER/validator/start.sh || FAILED="true"
else
    echoErr "ERROR: Unknown node type '$NODE_TYPE'"
    FAILED="true"
fi

rm -fv $CFG_CHECK
if [ "${FAILED,,}" == "true" ] ; then
    echoErr "ERROR: $NODE_TYPE node startup failed"
    exit 1
fi