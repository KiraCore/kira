#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
# quick edit: FILE="${SELF_CONTAINER}/defaultcheck.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

timerStart DEFAULT_HEALTHCHECK

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: DEFAULT SEKAI HEALTHCHECK"
echoWarn "|    DATE: $(date)"
echoWarn "------------------------------------------------"
set -x

HALT_CHECK="${COMMON_DIR}/halt"
EXIT_CHECK="${COMMON_DIR}/exit"
CFG_CHECK="${COMMON_DIR}/configuring"
STATUS_SCAN="${COMMON_DIR}/status"
EXECUTED_CHECK="$COMMON_DIR/executed"
COMMON_CONSENSUS="$COMMON_READ/consensus"

VALOPERS_FILE="$COMMON_READ/valopers"
CFG="$SEKAID_HOME/config/config.toml"

rm -rfv $STATUS_SCAN

LATEST_BLOCK_HEIGHT=$(globGet latest_block_height "$GLOBAL_COMMON_RO")
PREVIOUS_HEIGHT=$(globGet previous_height)

echoInfo "INFO: Logs cleanup..."
find "$SELF_LOGS" -type f -size +16M -exec truncate --size=8M {} + || echoWarn "WARNING: Failed to truncate self logs"
find "$COMMON_LOGS" -type f -size +16M -exec truncate --size=8M {} + || echoWarn "WARNING: Failed to truncate common logs"
journalctl --vacuum-time=3d --vacuum-size=32M || echoWarn "WARNING: journalctl vacuum failed"
find "/var/log" -type f -size +64M -exec truncate --size=8M {} + || echoWarn "WARNING: Failed to truncate system logs"
echoInfo "INFO: Logs cleanup finalized"

FAILED="false"
if [ -f "$HALT_CHECK" ] || [ -f "$EXIT_CHECK" ] || [ -f "$CFG_CHECK" ] ; then
    if [ -f "$EXIT_CHECK" ]; then
        echoInfo "INFO: Ensuring sekaid process is killed"
        touch $HALT_CHECK
        pkill -15 sekaid || echoWarn "WARNING: Failed to kill sekaid"
        rm -fv $EXIT_CHECK
    elif [ -f "$CFG_CHECK" ] ; then
        echoInfo "INFO: Waiting for container configuration to be finalized..."
    else
        echoInfo "INFO: Health check => STOP (halted)"
    fi
elif [ ! -f "$EXECUTED_CHECK" ] ; then
    echoWarn "WARNING: Setup of the '$NODE_TYPE' node was not finalized yet, no health data available"
else
    echoInfo "INFO: Checking node status..."
    CONSENSUS_STOPPED=$(jsonQuickParse "consensus_stopped" $COMMON_CONSENSUS || echo -n "")
    echo $(timeout 6 curl --fail 0.0.0.0:$INTERNAL_RPC_PORT/status 2>/dev/null || echo -n "") > $STATUS_SCAN
    CATCHING_UP=$(jsonQuickParse "catching_up" $STATUS_SCAN || echo -n "")
    HEIGHT=$(jsonQuickParse "latest_block_height" $STATUS_SCAN || echo -n "")
    (! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0
    (! $(isNaturalNumber "$PREVIOUS_HEIGHT")) && PREVIOUS_HEIGHT=0
    (! $(isNaturalNumber "$LATEST_BLOCK_HEIGHT")) && LATEST_BLOCK_HEIGHT=0
    [[ $HEIGHT -ge 1 ]] && globSet previous_height "$HEIGHT"

    if [ "$PREVIOUS_HEIGHT" != "$HEIGHT" ] ; then
        echoInfo "INFO: Success, node is catching up ($CATCHING_UP), previous block height was $PREVIOUS_HEIGHT, now $HEIGHT"
        timerStart "catching_up"
        globSet previous_height "$HEIGHT"
    else
        echoInfo "INFO: Starting healthcheck..."
        if [ "${NODE_TYPE,,}" == "sentry" ] || [ "${NODE_TYPE,,}" == "seed" ]; then
            $SELF_CONTAINER/sentry/healthcheck.sh "$LATEST_BLOCK_HEIGHT" "$PREVIOUS_HEIGHT" "$HEIGHT" "$CATCHING_UP" "$CONSENSUS_STOPPED" || FAILED="true"
        elif [ "${NODE_TYPE,,}" == "snapshot" ]; then
            $SELF_CONTAINER/snapshot/healthcheck.sh "$LATEST_BLOCK_HEIGHT" "$PREVIOUS_HEIGHT" "$HEIGHT" "$CATCHING_UP" "$CONSENSUS_STOPPED" || FAILED="true"
        elif [ "${NODE_TYPE,,}" == "validator" ]; then
            $SELF_CONTAINER/validator/healthcheck.sh "$LATEST_BLOCK_HEIGHT" "$PREVIOUS_HEIGHT" "$HEIGHT" "$CATCHING_UP" "$CONSENSUS_STOPPED" || FAILED="true"
        else
            echoErr "ERROR: Unknown node type '$NODE_TYPE'"
            FAILED="true"
        fi
    fi
fi

EXTERNAL_DNS=$(globGet EXTERNAL_DNS)
EXTERNAL_PORT=$(globGet EXTERNAL_PORT)

if [ ! -z "$EXTERNAL_DNS" ] && [ ! -z "$EXTERNAL_PORT" ] ; then
    echoInfo "INFO: Checking availability of the external address '$EXTERNAL_DNS:$EXTERNAL_PORT'"
    if timeout 15 nc -z $EXTERNAL_DNS $EXTERNAL_PORT ; then 
        echoInfo "INFO: Success, your node external address '$EXTERNAL_DNS' is exposed"
        globSet EXTERNAL_STATUS "ONLINE"
    else
        echoWarn "WARNING: Your node external address is NOT visible to other nodes"
        globSet EXTERNAL_STATUS "OFFLINE"
    fi
else
    echoWarn "WARNING: This node is NOT advertising its port ('$EXTERNAL_PORT') or external address ('$EXTERNAL_DNS') to other nodes in the network!"
    globSet EXTERNAL_STATUS "OFFLINE"
fi

if [ "${FAILED,,}" == "true" ] ; then
    SUCCESS_ELAPSED=$(timerSpan "success")
    echoErr "ERROR: $NODE_TYPE healthcheck failed for over ${SUCCESS_ELAPSED} out of max 300 seconds"
    if [ $SUCCESS_ELAPSED -gt 300 ] ; then
        echoErr "ERROR: Unhealthy status, node will reboot"
        pkill -15 sekaid || echoWarn "WARNING: Failed to kill sekaid"
        sleep 5
    fi

    set +x
    echoErr "------------------------------------------------"
    echoErr "|  FAILURE: DEFAULT SEKAI HEALTHCHECK          |"
    echoErr "|  ELAPSED: $(timerSpan DEFAULT_HEALTHCHECK) seconds"
    echoErr "|    DATE: $(date)"
    echoErr "------------------------------------------------"
    set -x
    sleep 10
    exit 1
else
    timerStart "success"
    set +x
    echoWarn "------------------------------------------------"
    echoWarn "|  SUCCESS: DEFAULT SEKAI HEALTHCHECK          |"
    echoWarn "|  ELAPSED: $(timerSpan DEFAULT_HEALTHCHECK) seconds"
    echoWarn "|    DATE: $(date)"
    echoWarn "------------------------------------------------"
    set -x
fi
