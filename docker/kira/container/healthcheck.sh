#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
set -x

echo "INFO: Health check => START"
sleep 30 # rate limit not to overextend the log files

HALT_CHECK="${COMMON_DIR}/halt"
EXIT_CHECK="${COMMON_DIR}/exit"
CFG_CHECK="${COMMON_DIR}/configuring"
EXCEPTION_COUNTER_FILE="$COMMON_DIR/exception_counter"
EXCEPTION_TOTAL_FILE="$COMMON_DIR/exception_total"
EXECUTED_CHECK="$COMMON_DIR/executed"

touch "$EXCEPTION_COUNTER_FILE" "$EXCEPTION_TOTAL_FILE"

EXCEPTION_COUNTER=$(cat $EXCEPTION_COUNTER_FILE || echo -n "")
EXCEPTION_TOTAL=$(cat $EXCEPTION_TOTAL_FILE || echo -n "")
(! $(isNaturalNumber "$EXCEPTION_COUNTER")) && EXCEPTION_COUNTER=0
(! $(isNaturalNumber "$EXCEPTION_TOTAL")) && EXCEPTION_TOTAL=0

if [ -f "$HALT_CHECK" ] || [ -f "$EXIT_CHECK" ] || [ -f "$CFG_CHECK" ] ; then
    if [ -f "$EXIT_CHECK" ]; then
        echo "INFO: Ensuring sekaid process is killed"
        touch $HALT_CHECK
        pkill -15 sekaid || echo "WARNING: Failed to kill sekaid"
        rm -fv $EXIT_CHECK
    elif [ -f "$CFG_CHECK" ] ; then
        echo "INFO: Waiting for container configuration to be finalized..."
    fi

    echo "INFO: health heck => STOP (halted)"
    echo "0" > $EXCEPTION_COUNTER_FILE
    exit 0
fi

find "/var/log/journal" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate journal"
find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate self logs"
find "$COMMON_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate common logs"

if [ ! -f "$EXECUTED_CHECK" ] ; then
    echoWarn "WARNING: Setup of the '$NODE_TYPE' node was not finalized yet, no health data available"
    exit 0
fi

FAILED="false"
if [ "${NODE_TYPE,,}" == "sentry" ] || [ "${NODE_TYPE,,}" == "priv_sentry" ] || [ "${NODE_TYPE,,}" == "seed" ]; then
  $SELF_CONTAINER/sentry/healthcheck.sh || FAILED="true"
elif [ "${NODE_TYPE,,}" == "snapshot" ]; then
  $SELF_CONTAINER/snapshot/healthcheck.sh || FAILED="true"
elif [ "${NODE_TYPE,,}" == "validator" ]; then
  $SELF_CONTAINER/validator/healthcheck.sh || FAILED="true"
else
  echo "ERROR: Unknown node type '$NODE_TYPE'"
  FAILED="true"
fi

if [ "${FAILED,,}" == "true" ] ; then
    EXCEPTION_COUNTER=$(($EXCEPTION_COUNTER + 1))
    EXCEPTION_TOTAL=$(($EXCEPTION_TOTAL + 1))
    echo "ERROR: $NODE_TYPE healthcheck failed ${EXCEPTION_COUNTER}/2 times, total $EXCEPTION_TOTAL"
    echo "$EXCEPTION_TOTAL" > $EXCEPTION_TOTAL_FILE

    if [[ $EXCEPTION_COUNTER -ge 3 ]] ; then
        echo "WARNINIG: Unhealthy status, node will reboot"
        echo "0" > $EXCEPTION_COUNTER_FILE
        pkill -15 sekaid || echo "WARNING: Failed to kill sekaid"
        sleep 5
    else
        echo "$EXCEPTION_COUNTER" > $EXCEPTION_COUNTER_FILE
    fi
    exit 1
    
else
    echo "0" > $EXCEPTION_COUNTER_FILE
    exit 0
fi
