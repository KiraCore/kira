#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
exec 2>&1
set -x

START_TIME="$(date -u +%s)"
echoInfo "INFO: Starting healthcheck $START_TIME"

BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height"
COMMON_CONSENSUS="$COMMON_READ/consensus"
COMMON_LATEST_BLOCK_HEIGHT="$COMMON_READ/latest_block_height"
touch $BLOCK_HEIGHT_FILE

HALT_CHECK="${COMMON_DIR}/halt"
EXIT_CHECK="${COMMON_DIR}/exit"

if [ -f "$EXIT_CHECK" ]; then
  echo "INFO: Ensuring nginx process is killed"
  touch $HALT_CHECK
  pkill -15 nginx || echo "WARNING: Failed to kill nginx"
  rm -fv $EXIT_CHECK
fi

if [ -f "$HALT_CHECK" ]; then
  exit 0
fi

echoInfo "INFO: Healthcheck => START"
sleep 30 # rate limit

find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} +
find "$COMMON_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echoInfo "INFO: Failed to truncate common logs"

STATUS_NGINX="$(service nginx status)"
SUB_STR="nginx is running"
if [[ "$STATUS_NGINX" != *"$SUB_STR"* ]]; then
  echoInfo "Nginx is not running."
  nginx -t
  service nginx restart
  exit 1
fi

INDEX_HTML="$(curl http://127.0.0.1:80)"

SUB_STR="<!DOCTYPE html>"
if [[ "$INDEX_HTML" != *"$SUB_STR"* ]]; then
  echoInfo "HTML page is not rendering."
  exit 1
fi

INDEX_STATUS_CODE="$(curl -s -o /dev/null -I -w '%{http_code}' 127.0.0.1:80)"

if [ "$INDEX_STATUS_CODE" -ne "200" ]; then
  echoInfo "Index page returns ${INDEX_STATUS_CODE}"
  exit 1
fi

HEIGHT=$(curl http://interx:11000/api/kira/status 2>/dev/null | jq -rc '.SyncInfo.latest_block_height' 2>/dev/null || echo -n "")
(! $(isNaturalNumber "$HEIGHT")) && HEIGHT=$(curl http://interx:11000/api/kira/status 2>/dev/null | jq -rc '.sync_info.latest_block_height' 2>/dev/null || echo -n "")
(! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0

PREVIOUS_HEIGHT=$(cat $BLOCK_HEIGHT_FILE)
echo "$HEIGHT" > $BLOCK_HEIGHT_FILE
(! $(isNaturalNumber "$PREVIOUS_HEIGHT")) && PREVIOUS_HEIGHT=0

if [ $PREVIOUS_HEIGHT -ge $HEIGHT ]; then
  echoWarn "WARNING: Blocks are not beeing produced or synced, current height: $HEIGHT, previous height: $PREVIOUS_HEIGHT"
  exit 1
else
  echoInfo "INFO: Success, new blocks were created or synced: $HEIGHT"
fi

echo "------------------------------------------------"
echo "| FINISHED: HEALTHCHECK                        |"
echo "|  ELAPSED: $(($(date -u +%s)-$START_TIME)) seconds"
echo "------------------------------------------------"
exit 0
