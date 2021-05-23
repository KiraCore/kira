#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
# quick edit: FILE="${SELF_CONTAINER}/snapshot/healthcheck.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

LATEST_BLOCK_HEIGHT=$1
PREVIOUS_HEIGHT=$2
HEIGHT=$3
CATCHING_UP=$4
CONSENSUS_STOPPED=$5

START_TIME="$(date -u +%s)"
SNAP_STATUS="$SNAP_DIR/status"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_FINALIZYNG="$SNAP_STATUS/finalizing"

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

if [ -f "$SNAP_DONE" ] || [ -f "$SNAP_FINALIZYNG" ]; then
    echoInfo "INFO: Success, snapshot done or finalizing!"
    exit 0
fi

if [ ! -z "$HALT_HEIGHT" ] && [[ $HALT_HEIGHT -le $HEIGHT ]] ; then
    echoInfo "INFO: Success, target height reached!"
    exit 0
fi

if [[ $PREVIOUS_HEIGHT -ge $HEIGHT ]]; then
    set +x
    echoWarn "WARNING: Blocks are not beeing synced by $NODE_TYPE"
    echoWarn "WARNING: Current height: $HEIGHT"
    echoWarn "WARNING: Previous height: $PREVIOUS_HEIGHT"
    echoWarn "WARNING: Latest height: $LATEST_BLOCK_HEIGHT"
    echoWarn "WARNING: Consensus Stopped: $CONSENSUS_STOPPED"
     
    if [[ $LATEST_BLOCK_HEIGHT -ge 1 ]] && [[ $LATEST_BLOCK_HEIGHT -le $HEIGHT ]] && [ "$CONSENSUS_STOPPED" == "true" ] ; then
        echoWarn "WARNINIG: Cosnensus halted, lack of block production is not result of the issue with the node"
    else
        echoErr "ERROR: Block production or sync stopped more than $(timerSpan catching_up) seconds ago"
        sleep 10
        exit 1
    fi
else
    echoInfo "INFO: Success, new blocks were created or synced: $HEIGHT"
fi

set +x
echoInfo "------------------------------------------------"
echoInfo "| FINISHED: ${NODE_TYPE^^} HEALTHCHECK"
echoInfo "|  ELAPSED: $(($(date -u +%s)-$START_TIME)) seconds"
echoInfo "|    DATE: $(date)"
echoInfo "------------------------------------------------"
set -x