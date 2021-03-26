#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
set -x

SNAP_STATUS="$SNAP_DIR/status"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_FINALIZYNG="$SNAP_STATUS/finalizing"
COMMON_CONSENSUS="$COMMON_READ/consensus"
COMMON_LATEST_BLOCK_HEIGHT="$COMMON_READ/latest_block_height"
BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height"

touch $BLOCK_HEIGHT_FILE

if [ -f "$SNAP_DONE" ] ; then
  echo "INFO: Success, snapshot done!"
  exit 0
fi

if [ -f "$SNAP_FINALIZYNG" ] ; then
  echo "INFO: Success, snapshot is finalizing!"
  exit 0
fi

LATEST_BLOCK_HEIGHT=$(cat $COMMON_LATEST_BLOCK_HEIGHT || echo "")
CONSENSUS=$(cat $COMMON_CONSENSUS | jq -rc || echo "")
CONSENSUS_STOPPED=$(echo "$CONSENSUS" | jq -rc '.consensus_stopped' || echo "")
HEIGHT=$(sekaid status 2>&1 | jq -rc '.SyncInfo.latest_block_height' || echo "")

[ -z "${HEIGHT##*[!0-9]*}" ] && HEIGHT=$(sekaid status 2>&1 | jq -rc '.sync_info.latest_block_height' || echo "")
[ -z "${HEIGHT##*[!0-9]*}" ] && HEIGHT=0
[ -z "${LATEST_BLOCK_HEIGHT##*[!0-9]*}" ] && LATEST_BLOCK_HEIGHT=0

if [ ! -z "$HALT_HEIGHT" ] && [ $HALT_HEIGHT -le $HEIGHT ] ; then
    echo "INFO: Success, target height reached!"
    exit 0
fi

PREVIOUS_HEIGHT=$(cat $BLOCK_HEIGHT_FILE)
echo "$HEIGHT" > $BLOCK_HEIGHT_FILE
[ -z "${PREVIOUS_HEIGHT##*[!0-9]*}" ] && PREVIOUS_HEIGHT=0

if [ $PREVIOUS_HEIGHT -ge $HEIGHT ]; then
    echo "WARNING: Blocks are not beeing produced or synced"
    echo "WARNING: Current height: $HEIGHT"
    echo "WARNING: Previous height: $PREVIOUS_HEIGHT"
    echo "WARNING: Latest height: $LATEST_BLOCK_HEIGHT"
    echo "WARNING: Consensus Stopped: $CONSENSUS_STOPPED"
     
    if [ $LATEST_BLOCK_HEIGHT -ge 1 ] && [ $LATEST_BLOCK_HEIGHT -le $HEIGHT ] && [ "$CONSENSUS_STOPPED" == "true" ] ; then
        echo "WARNINIG: Cosnensus halted, lack of block production is not result of the issue with the node"
    else
        exit 1
    fi
else
  echo "SUCCESS: New blocks were created or synced: $HEIGHT"
fi

echo "INFO: Latest Block Height: $HEIGHT"
exit 0