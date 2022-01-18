#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
# quick edit: FILE="${SELF_CONTAINER}/snapshot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

echoInfo "INFO: Staring snapshot..."

# snap filename override
SNAP_FILENAME=$1

HALT_CHECK="${COMMON_DIR}/halt"
[ ! -f $HALT_CHECK ] && echoErr "ERROR: Full node (sekaid) process must be gracefully halted before snapshot can proceed!"

echoInfo "INFO: Ensuring sekaid process is killed..."
pkill -15 sekaid || echoWarn "WARNING: Failed to kill sekaid, process might have already been stopped"
sleep 5

DATA_GENESIS="$SEKAID_DATA/genesis.json"
LOCAL_GENESIS="$SEKAID_CONFIG/genesis.json"
LOCAL_STATE="$SEKAID_DATA/priv_validator_state.json"
SNAP_INFO="$SEKAID_DATA/snapinfo.json"

LATEST_BLOCK_HEIGHT=$(globGet latest_block_height "$GLOBAL_COMMON_RO") && (! $(isNaturalNumber "$LATEST_BLOCK_HEIGHT")) && LATEST_BLOCK_HEIGHT="0"
STATE_HEIGHT=$(jsonQuickParse "height" $LOCAL_STATE || echo "") && (! $(isNaturalNumber "$STATE_HEIGHT")) && MIN_BLOCK="0"
[[ $LATEST_BLOCK_HEIGHT -lt $STATE_HEIGHT ]] && LATEST_BLOCK_HEIGHT=$STATE_HEIGHT

($(isNullOrWhitespaces $SNAP_FILENAME)) && SNAP_FILENAME="${NETWORK_NAME}-${LATEST_BLOCK_HEIGHT}-$(date -u +%s).zip"
SNAP_DESTINATION_FILE="$SNAP_DIR/$SNAP_FILENAME"

echoInfo "INFO: Creating '$SNAP_FILENAME' backup package..."
cp -afv "$LOCAL_GENESIS" $DATA_GENESIS
echo "{\"height\":$LATEST_BLOCK_HEIGHT}" >"$SNAP_INFO"

# to prevent appending root path we must zip all from within the target data folder
echoInfo "INFO: Please wait compressing chain state..."
cd $SEKAID_DATA
zip -0 -r "$SNAP_DESTINATION_FILE" . *
[ ! -f "$SNAP_DESTINATION_FILE" ] && echoInfo "INFO: Failed to create snapshot, file '$SNAP_DESTINATION_FILE' was not found" && exit 1

echoInfo "INFO: Finished snapshot"