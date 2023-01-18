#!/usr/bin/env bash
set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="${COMMON_DIR}/defaultcheck.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# quick edit: FILE="/common/validator/healthcheck.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

timerStart DEFAULT_HEALTHCHECK

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: ${NODE_TYPE^^} SEKAI HEALTHCHECK"
echoWarn "|    DATE: $(date)"
echoWarn "------------------------------------------------"
set -x

STATUS_SCAN="${COMMON_DIR}/status"
COMMON_CONSENSUS="$COMMON_READ/consensus"
VALOPERS_FILE="$COMMON_READ/valopers"
CFG="$SEKAID_HOME/config/config.toml"
PREVIOUS_HEIGHT=$(globGet previous_height)
FAILED="false"

rm -rfv $STATUS_SCAN

echoInfo "INFO: Checking node status..."
CONSENSUS_STOPPED=$(jsonQuickParse "consensus_stopped" $COMMON_CONSENSUS || echo -n "")
echo $(timeout 6 curl --fail 0.0.0.0:$INTERNAL_RPC_PORT/status 2>/dev/null || echo -n "") > $STATUS_SCAN
CATCHING_UP=$(jsonQuickParse "catching_up" $STATUS_SCAN || echo -n "")
HEIGHT=$(jsonQuickParse "latest_block_height" $STATUS_SCAN || echo -n "")
(! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0
(! $(isNaturalNumber "$PREVIOUS_HEIGHT")) && PREVIOUS_HEIGHT=0
[[ $HEIGHT -ge 1 ]] && globSet previous_height "$HEIGHT"

echoWarn "------------------------------------------------"
echoWarn "|    Current height: $HEIGHT"
echoWarn "|   Previous height: $PREVIOUS_HEIGHT"
echoWarn "|     Latest height: $(globGet latest_block_height $GLOBAL_COMMON_RO)"
echoWarn "| Consensus Stopped: $CONSENSUS_STOPPED"
echoWarn "------------------------------------------------"

if [ "$PREVIOUS_HEIGHT" != "$HEIGHT" ] ; then
    echoInfo "INFO: Success, node is catching up ($CATCHING_UP), previous block height was $PREVIOUS_HEIGHT, now $HEIGHT"
    timerStart "catching_up"
    globSet previous_height "$HEIGHT"
else
    if [[ $PREVIOUS_HEIGHT -ge $HEIGHT ]]; then
        echoWarn "WARNING: Blocks are not beeing produced or synced"
        TIME_SPAN=$(timerSpan catching_up) && (! $(isNaturalNumber $TIME_SPAN)) && TIME_SPAN=0
        echoErr "ERROR: Block production or sync stopped more than $TIME_SPAN seconds ago"
        [[ $TIME_SPAN -gt 900 ]] && FAILED="true"
    else
        echoInfo "INFO: Success, new blocks were created or synced: $HEIGHT"
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
