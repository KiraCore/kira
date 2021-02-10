#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

SNAP_STATUS="$SNAP_DIR/status"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_FINALIZYNG="$SNAP_STATUS/finalizing"

if [ -f "$SNAP_DONE" ] ; then
  echo "INFO: Success, snapshot done!"
  exit 0
fi

if [ -f "$SNAP_FINALIZYNG" ] ; then
  echo "INFO: Success, snapshot is finalizing!"
  exit 0
fi

BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height" && touch $BLOCK_HEIGHT_FILE
HEIGHT=$(sekaid status 2>&1 | jq -rc '.SyncInfo.latest_block_height' || echo "")
[ -z "${HEIGHT##*[!0-9]*}" ] && HEIGHT=$(sekaid status 2>&1 | jq -rc '.sync_info.latest_block_height' || echo "")
[ -z "${HEIGHT##*[!0-9]*}" ] && HEIGHT=0

if [ ! -z "$HALT_HEIGHT" ] && [ $HALT_HEIGHT -le $HEIGHT ] ; then
    echo "INFO: Success, target height reached!"
    exit 0
fi

PREVIOUS_HEIGHT=$(cat $BLOCK_HEIGHT_FILE)
echo "$HEIGHT" > $BLOCK_HEIGHT_FILE
[ -z "${PREVIOUS_HEIGHT##*[!0-9]*}" ] && PREVIOUS_HEIGHT=0

BLOCK_CHANGED="True"
if [ $PREVIOUS_HEIGHT -ge $HEIGHT ]; then
  echo "WARNING: Blocks are not beeing produced or synced, current height: $HEIGHT, previous height: $PREVIOUS_HEIGHT"
  BLOCK_CHANGED="False"
  exit 1
else
  echo "SUCCESS: New blocks were created or synced: $HEIGHT"
fi

echo "INFO: Latest Block Height: $HEIGHT"
