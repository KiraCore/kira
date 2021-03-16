#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

LIP_FILE="$COMMON_READ/local_ip"
PIP_FILE="$COMMON_READ/public_ip"

BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height" && touch $BLOCK_HEIGHT_FILE
HEIGHT=$(sekaid status 2>&1 | jq -rc '.SyncInfo.latest_block_height' || echo "")
[ -z "${HEIGHT##*[!0-9]*}" ] && HEIGHT=$(sekaid status 2>&1 | jq -rc '.sync_info.latest_block_height' || echo "")
[ -z "${HEIGHT##*[!0-9]*}" ] && HEIGHT=0

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

if [ ! -z "$EXTERNAL_ADDR" ] ; then
  echo "INFO: Checking availability of the external address '$EXTERNAL_ADDR'"

  LOCAL_IP=$(cat $LIP_FILE || echo "")
  PUBLIC_IP=$(cat $PIP_FILE || echo "")

  echo "INFO: Local IP: $LOCAL_IP"
  echo "INFO: Public IP: $PUBLIC_IP"

  if timeout 2 nc -z $EXTERNAL_ADDR $EXTERNAL_P2P_PORT ; then 
      echo "INFO: Success, your node external address '$EXTERNAL_ADDR' is exposed"
      echo "ONLINE" > "$COMMON_DIR/external_address_status"
  else
    echo "ERROR: Your node external address is not visible to other nodes, failed to diall '$EXTERNAL_ADDR:$EXTERNAL_P2P_PORT'"
    echo "OFFLINE" > "$COMMON_DIR/external_address_status"
    exit 1
  fi
else
    echo "WARNING: This node is NOT advertising its it's public or local external address to other nodes in the network!"
    echo "OFFLINE" > "$COMMON_DIR/external_address_status"
fi