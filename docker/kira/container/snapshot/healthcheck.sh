#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
set -x

START_TIME="$(date -u +%s)"
echoInfo "INFO: Starting healthcheck $START_TIME"

SNAP_STATUS="$SNAP_DIR/status"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_FINALIZYNG="$SNAP_STATUS/finalizing"
COMMON_CONSENSUS="$COMMON_READ/consensus"
COMMON_LATEST_BLOCK_HEIGHT="$COMMON_READ/latest_block_height"
BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height"

touch $BLOCK_HEIGHT_FILE

if [ -f "$SNAP_DONE" ] ; then
  echoInfo "INFO: Success, snapshot done!"
  exit 0
fi

if [ -f "$SNAP_FINALIZYNG" ] ; then
  echoInfo "INFO: Success, snapshot is finalizing!"
  exit 0
fi

LATEST_BLOCK_HEIGHT=$(cat $COMMON_LATEST_BLOCK_HEIGHT || echo -n "")
CONSENSUS_STOPPED=$(jsonQuickParse "consensus_stopped" $COMMON_CONSENSUS || echo -n "")
HEIGHT=$(sekaid status 2>&1 | jsonQuickParse "latest_block_height" || echo -n "")
(! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0
(! $(isNaturalNumber "$LATEST_BLOCK_HEIGHT")) && LATEST_BLOCK_HEIGHT=0

if [ ! -z "$HALT_HEIGHT" ] && [ $HALT_HEIGHT -le $HEIGHT ] ; then
    echoInfo "INFO: Success, target height reached!"
    exit 0
fi

PREVIOUS_HEIGHT=$(cat $BLOCK_HEIGHT_FILE)
echo "$HEIGHT" > $BLOCK_HEIGHT_FILE
(! $(isNaturalNumber "$PREVIOUS_HEIGHT")) && PREVIOUS_HEIGHT=0

if [ $PREVIOUS_HEIGHT -ge $HEIGHT ]; then
    echoWarn "WARNING: Blocks are not beeing produced or synced"
    echoWarn "WARNING: Current height: $HEIGHT"
    echoWarn "WARNING: Previous height: $PREVIOUS_HEIGHT"
    echoWarn "WARNING: Latest height: $LATEST_BLOCK_HEIGHT"
    echoWarn "WARNING: Consensus Stopped: $CONSENSUS_STOPPED"
     
    if [ $LATEST_BLOCK_HEIGHT -ge 1 ] && [ $LATEST_BLOCK_HEIGHT -le $HEIGHT ] && [ "$CONSENSUS_STOPPED" == "true" ] ; then
        echoWarn "WARNINIG: Cosnensus halted, lack of block production is not result of the issue with the node"
    else
        echoErr "ERROR: Block production stopped"
        sleep 3
        exit 1
    fi
else
  echoInfo "INFO: Success, new blocks were created or synced: $HEIGHT"
fi

echo "------------------------------------------------"
echo "| FINISHED: HEALTHCHECK                        |"
echo "|  ELAPSED: $(($(date -u +%s)-$START_TIME)) seconds"
echo "------------------------------------------------"
exit 0