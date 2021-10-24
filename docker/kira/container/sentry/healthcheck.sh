#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
# quick edit: FILE="${SELF_CONTAINER}/sentry/healthcheck.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

LATEST_BLOCK_HEIGHT=$1
PREVIOUS_HEIGHT=$2
HEIGHT=$3
CATCHING_UP=$4
CONSENSUS_STOPPED=$5

START_TIME="$(date -u +%s)"

set +x
echoInfo "------------------------------------------------"
echoInfo "| STARTED: ${NODE_TYPE^^} HEALTHCHECK"
echoInfo "|    DATE: $(date)"
echoInfo "|-----------------------------------------------"
echoInfo "| LATEST BLOCK HEIGHT: $LATEST_BLOCK_HEIGHT"
echoInfo "|     PREVIOUS HEIGHT: $PREVIOUS_HEIGHT"
echoInfo "|              HEIGHT: $HEIGHT"
echoInfo "|         CATCHING UP: $CATCHING_UP"
echoInfo "|   CONSENSUS STOPPED: $CONSENSUS_STOPPED"
echoInfo "------------------------------------------------"
set -x

if [[ $PREVIOUS_HEIGHT -ge $HEIGHT ]]; then
    set +x
    echoWarn "WARNING: Blocks are not beeing synced by $NODE_TYPE"
    echoWarn "WARNING: Current height: $HEIGHT"
    echoWarn "WARNING: Previous height: $PREVIOUS_HEIGHT"
    echoWarn "WARNING: Latest height: $LATEST_BLOCK_HEIGHT"
    echoWarn "WARNING: Consensus Stopped: $CONSENSUS_STOPPED"
      
    TIME_SPAN=$(timerSpan catching_up) && (! $(isNaturalNumber $TIME_SPAN)) && TIME_SPAN=0
    echoErr "ERROR: Block production or sync stopped more than $TIME_SPAN seconds ago"
    sleep 60
    [[ $TIME_SPAN -gt 1800 ]] && exit 1
else
    echoInfo "INFO, Success, new blocks were created or synced: $HEIGHT"
fi

set +x
echoInfo "------------------------------------------------"
echoInfo "| FINISHED: ${NODE_TYPE^^} HEALTHCHECK"
echoInfo "|  ELAPSED: $(($(date -u +%s)-$START_TIME)) seconds"
echoInfo "|    DATE: $(date)"
echoInfo "------------------------------------------------"
set -x