#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
set -x

START_TIME="$(date -u +%s)"
echoInfo "INFO: [$NODE_TYPE] Started $NODE_TYPE health check"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: GENERIC HEALTHCHECK"
echoWarn "------------------------------------------------"
set -x

HALT_CHECK="${COMMON_DIR}/halt"
EXIT_CHECK="${COMMON_DIR}/exit"
CFG_CHECK="${COMMON_DIR}/configuring"
HEALTHCHECK_LOG="${COMMON_DIR}/healthcheck.log.txt"
STATUS_SCAN="${COMMON_DIR}/status"
EXCEPTION_COUNTER_FILE="$COMMON_DIR/exception_counter"
EXCEPTION_TOTAL_FILE="$COMMON_DIR/exception_total"
EXECUTED_CHECK="$COMMON_DIR/executed"
BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height"
COMMON_LATEST_BLOCK_HEIGHT="$COMMON_READ/latest_block_height"
COMMON_CONSENSUS="$COMMON_READ/consensus"

VALOPERS_FILE="$COMMON_READ/valopers"
CFG="$SEKAID_HOME/config/config.toml"

sleep 30 # rate limit not to overextend the log files
rm -rfv $STATUS_SCAN
touch "$EXCEPTION_COUNTER_FILE" "$EXCEPTION_TOTAL_FILE" "$BLOCK_HEIGHT_FILE"

EXCEPTION_COUNTER=$(cat $EXCEPTION_COUNTER_FILE || echo -n "")
EXCEPTION_TOTAL=$(cat $EXCEPTION_TOTAL_FILE || echo -n "")
(! $(isNaturalNumber "$EXCEPTION_COUNTER")) && EXCEPTION_COUNTER=0
(! $(isNaturalNumber "$EXCEPTION_TOTAL")) && EXCEPTION_TOTAL=0

if [ -f "$HALT_CHECK" ] || [ -f "$EXIT_CHECK" ] || [ -f "$CFG_CHECK" ] ; then
    if [ -f "$EXIT_CHECK" ]; then
        echoInfo "INFO: Ensuring sekaid process is killed"
        touch $HALT_CHECK
        pkill -15 sekaid || echoWarn "WARNING: Failed to kill sekaid"
        rm -fv $EXIT_CHECK
    elif [ -f "$CFG_CHECK" ] ; then
        echo "INFO: Waiting for container configuration to be finalized..."
    fi

    echoInfo "INFO: health heck => STOP (halted)"
    echo "0" > $EXCEPTION_COUNTER_FILE
    sleep 10
    exit 0
fi

find "/var/log/journal" -type f -size +256k -exec truncate --size=128k {} + || echoWarn "WARNING: Failed to truncate journal"
find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echoWarn "WARNING: Failed to truncate self logs"
find "$COMMON_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echoWarn "WARNING: Failed to truncate common logs"

if [ ! -f "$EXECUTED_CHECK" ] ; then
    echoWarn "WARNING: Setup of the '$NODE_TYPE' node was not finalized yet, no health data available"
    sleep 10
    exit 0
fi

LATEST_BLOCK_HEIGHT=$(tryCat $COMMON_LATEST_BLOCK_HEIGHT || echo -n "")
CONSENSUS_STOPPED=$(jsonQuickParse "consensus_stopped" $COMMON_CONSENSUS || echo -n "")
echo $(timeout 3 curl --fail 0.0.0.0:$INTERNAL_RPC_PORT/status 2>/dev/null || echo -n "") > $STATUS_SCAN
CATCHING_UP=$(jsonQuickParse "catching_up" $STATUS_SCAN || echo -n "")
HEIGHT=$(jsonQuickParse "latest_block_height" $STATUS_SCAN || echo -n "")
PREVIOUS_HEIGHT=$(tryCat $BLOCK_HEIGHT_FILE)
(! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0
(! $(isNaturalNumber "$PREVIOUS_HEIGHT")) && PREVIOUS_HEIGHT=0
(! $(isNaturalNumber "$LATEST_BLOCK_HEIGHT")) && LATEST_BLOCK_HEIGHT=0
[[ $HEIGHT -ge 1 ]] && echo "$HEIGHT" > $BLOCK_HEIGHT_FILE

FAILED="false"
if [ "${NODE_TYPE,,}" == "sentry" ] || [ "${NODE_TYPE,,}" == "priv_sentry" ] || [ "${NODE_TYPE,,}" == "seed" ]; then
    $SELF_CONTAINER/sentry/healthcheck.sh "$LATEST_BLOCK_HEIGHT" "$PREVIOUS_HEIGHT" "$HEIGHT" "$CATCHING_UP" "$CONSENSUS_STOPPED" &> $HEALTHCHECK_LOG || FAILED="true"
elif [ "${NODE_TYPE,,}" == "snapshot" ]; then
    $SELF_CONTAINER/snapshot/healthcheck.sh "$LATEST_BLOCK_HEIGHT" "$PREVIOUS_HEIGHT" "$HEIGHT" "$CATCHING_UP" "$CONSENSUS_STOPPED" &> $HEALTHCHECK_LOG || FAILED="true"
elif [ "${NODE_TYPE,,}" == "validator" ]; then
    $SELF_CONTAINER/validator/healthcheck.sh "$LATEST_BLOCK_HEIGHT" "$PREVIOUS_HEIGHT" "$HEIGHT" "$CATCHING_UP" "$CONSENSUS_STOPPED" &> $HEALTHCHECK_LOG || FAILED="true"
else
    echoErr "ERROR: Unknown node type '$NODE_TYPE'"
    FAILED="true"
fi

if [ "$PREVIOUS_HEIGHT" != "$HEIGHT" ]; then
    echoInfo "INFO: Success, node is catching up, previous block height was $PREVIOUS_HEIGHT, now $HEIGHT"
    echo "$HEIGHT" > $BLOCK_HEIGHT_FILE
    [ "${FAILED,,}" == "true" ] && exit 0
fi

if [ "${FAILED,,}" == "true" ] ; then
    EXCEPTION_COUNTER=$(($EXCEPTION_COUNTER + 1))
    EXCEPTION_TOTAL=$(($EXCEPTION_TOTAL + 1))
    echoErr "ERROR: $NODE_TYPE healthcheck failed ${EXCEPTION_COUNTER}/2 times, total $EXCEPTION_TOTAL"
    echo "$EXCEPTION_TOTAL" > $EXCEPTION_TOTAL_FILE

    if [[ $EXCEPTION_COUNTER -ge 3 ]] ; then
        echoWarn "WARNINIG: Unhealthy status, node will reboot"
        echo "0" > $EXCEPTION_COUNTER_FILE
        pkill -15 sekaid || echoWarn "WARNING: Failed to kill sekaid"
        sleep 5
    else
        echo "$EXCEPTION_COUNTER" > $EXCEPTION_COUNTER_FILE
    fi
    exit 1
else
    echoInfo "INFO: Updating commit timeout..."
    ACTIVE_VALIDATORS=$(jsonQuickParse "active_validators" $VALOPERS_FILE || echo "0")
    (! $(isNaturalNumber "$ACTIVE_VALIDATORS")) && ACTIVE_VALIDATORS=0
    if [ "${ACTIVE_VALIDATORS}" != "0" ] ; then
        TIMEOUT_COMMIT=$(echo "scale=3; ((( 5 / ( $ACTIVE_VALIDATORS + 1 ) ) * 1000 ) + 1000) " | bc)
        TIMEOUT_COMMIT=$(echo "scale=0; ( $TIMEOUT_COMMIT / 1 ) " | bc)
        (! $(isNaturalNumber "$TIMEOUT_COMMIT")) && TIMEOUT_COMMIT="5000"
        TIMEOUT_COMMIT="${TIMEOUT_COMMIT}ms"
        
        if [ "${TIMEOUT_COMMIT}" != "$CFG_timeout_commit" ] ; then
            echoInfo "INFO: Commit timeout will be changed to $TIMEOUT_COMMIT"
            CDHelper text lineswap --insert="CFG_timeout_commit=${TIMEOUT_COMMIT}" --prefix="CFG_timeout_commit=" --path=$ETC_PROFILE --append-if-found-not=True
            CDHelper text lineswap --insert="timeout_commit = \"${TIMEOUT_COMMIT}\"" --prefix="timeout_commit =" --path=$CFG
        fi
    fi
    echo "0" > $EXCEPTION_COUNTER_FILE  
fi

set +x
echoInfo "------------------------------------------------"
echoInfo "| FINISHED: GENERIC HEALTHCHECK                |"
echoInfo "|  ELAPSED: $(($(date -u +%s)-$START_TIME)) seconds"
echoInfo "------------------------------------------------"
set -x

sleep 10
exit 0