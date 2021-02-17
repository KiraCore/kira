#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
exec 2>&1
set -x

HALT_CHECK="${COMMON_DIR}/halt"

if [ -f "$HALT_CHECK" ]; then
  exit 0
fi

echo "INFO: Healthcheck => START"
sleep 30 # rate limit

find "/var/log/journal" -type f -size +256k -exec truncate --size=128k {} +
find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} +
find "$COMMON_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate common logs"

BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height.txt" && touch $BLOCK_HEIGHT_FILE
HEIGHT=$(curl 127.0.0.1:11000/api/kira/status 2>/dev/null | jq -rc '.SyncInfo.latest_block_height' 2>/dev/null || echo "")
[ -z "${HEIGHT##*[!0-9]*}" ] && HEIGHT=$(curl 127.0.0.1:11000/api/kira/status 2>/dev/null | jq -rc '.sync_info.latest_block_height' 2>/dev/null || echo "")
[ -z "${HEIGHT##*[!0-9]*}" ] && HEIGHT=0

PREVIOUS_HEIGHT=$(cat $BLOCK_HEIGHT_FILE)
echo "$HEIGHT" >$BLOCK_HEIGHT_FILE
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
