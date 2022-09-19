#!/usr/bin/env bash
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
STATE_FILE="$SEKAID_DATA/priv_validator_state.json"
SNAP_INFO="$SEKAID_DATA/snapinfo.json"

LATEST_BLOCK_HEIGHT=$(globGet latest_block_height "$GLOBAL_COMMON_RO") && (! $(isNaturalNumber "$LATEST_BLOCK_HEIGHT")) && LATEST_BLOCK_HEIGHT="0"
STATE_HEIGHT=$(jsonQuickParse "height" $STATE_FILE || echo "") && (! $(isNaturalNumber "$STATE_HEIGHT")) && MIN_BLOCK="0"
[[ $LATEST_BLOCK_HEIGHT -lt $STATE_HEIGHT ]] && LATEST_BLOCK_HEIGHT=$STATE_HEIGHT

($(isNullOrWhitespaces $SNAP_FILENAME)) && SNAP_FILENAME="${NETWORK_NAME}-${LATEST_BLOCK_HEIGHT}-$(date -u +%s).tar"
SNAP_DESTINATION_FILE="$SNAP_DIR/$SNAP_FILENAME"

echoInfo "INFO: Creating '$SNAP_FILENAME' backup package..."
rm -fv "$DATA_GENESIS"
# dereference symlink
cp -fL "$LOCAL_GENESIS" $DATA_GENESIS
echo "{\"height\":$LATEST_BLOCK_HEIGHT}" >"$SNAP_INFO"
chmod -v 666 "$DATA_GENESIS" "$SNAP_INFO"

# to prevent appending root path we must package all from within the target data folder
cd $SEKAID_DATA
timerStart SNAPSHOT
echoInfo "INFO: Please wait, this might take a while, backing up '$SEKAID_DATA' -> '$SNAP_DESTINATION_FILE' ..."
tar -cf "$SNAP_DESTINATION_FILE" ./ && SUCCESS="true" || SUCCESS="false"
echoInfo "INFO: Elapsed: $(timerSpan SNAPSHOT) seconds"
( [ ! -f "$SNAP_DESTINATION_FILE" ] || [ "${SUCCESS,,}" != "true" ] ) && echoInfo "INFO: Failed to create snapshot, file '$SNAP_DESTINATION_FILE' was not found" && exit 1

echoInfo "INFO: Success, snapshot compleated!"