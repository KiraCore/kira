#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
set -x

COMMON_CONSENSUS="$COMMON_READ/consensus"
COMMON_LATEST_BLOCK_HEIGHT="$COMMON_READ/latest_block_height"
BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height" 

touch $BLOCK_HEIGHT_FILE

HEIGHT=$(sekaid status 2>&1 | jq -rc '.SyncInfo.latest_block_height' || echo "")
[ -z "${HEIGHT##*[!0-9]*}" ] && HEIGHT=$(sekaid status 2>&1 | jq -rc '.sync_info.latest_block_height' || echo "")
[ -z "${HEIGHT##*[!0-9]*}" ] && HEIGHT=0

PREVIOUS_HEIGHT=$(cat $BLOCK_HEIGHT_FILE)
echo "$HEIGHT" > $BLOCK_HEIGHT_FILE
[ -z "${PREVIOUS_HEIGHT##*[!0-9]*}" ] && PREVIOUS_HEIGHT=0

if [ $PREVIOUS_HEIGHT -ge $HEIGHT ]; then
  echo "WARNING: Blocks are not beeing produced or synced, current height: $HEIGHT, previous height: $PREVIOUS_HEIGHT"
  exit 1
else
  echo "SUCCESS: New blocks were created or synced: $HEIGHT"
fi

echo "INFO: Latest Block Height: $HEIGHT"
exit 0