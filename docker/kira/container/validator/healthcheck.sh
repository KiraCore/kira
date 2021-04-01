#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
set -x

VALOPERS_FILE="$COMMON_READ/valopers"
COMMON_CONSENSUS="$COMMON_READ/consensus"
COMMON_LATEST_BLOCK_HEIGHT="$COMMON_READ/latest_block_height"
BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height"
CFG="$SEKAID_HOME/config/config.toml"

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

# block time should vary from minimum of 5.1s to 100ms depending on the validator count. The more vlaidators, the shorter the block time
echo "INFO: Updating commit timeout..."
ACTIVE_VALIDATORS=$(cat $VALOPERS_FILE | jq -rc '.status.active_validators' || echo "0")
([ -z "$ACTIVE_VALIDATORS" ] || [ "${ACTIVE_VALIDATORS,,}" == "null" ]) && ACTIVE_VALIDATORS=0
TIMEOUT_COMMIT=$(echo "scale=3; ((( 5 / ( $ACTIVE_VALIDATORS + 1 ) ) * 1000 ) + 100) " | bc)
TIMEOUT_COMMIT=$(echo "scale=0; ( $TIMEOUT_COMMIT / 1 ) " | bc)

if [ "${ACTIVE_VALIDATORS}" != "0" ] && [ "${TIMEOUT_COMMIT}" != "$CFG_timeout_commit" ] ; then
    echo "INFO: Commit timeout changed to $TIMEOUT_COMMIT"
    CDHelper text lineswap --insert="CFG_timeout_commit=${TIMEOUT_COMMIT}ms" --prefix="CFG_timeout_commit=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="timeout_commit = \"$TIMEOUT_COMMIT\"" --prefix="timeout_commit =" --path=$CFG
fi

exit 0