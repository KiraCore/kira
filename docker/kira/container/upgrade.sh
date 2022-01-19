#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
# quick edit: FILE="${SELF_CONTAINER}/upgrade.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

echoInfo "INFO: Staring container upgrade sequence..."

INSTATE_UPGRADE=$1 && (! $(isBoolean "$INSTATE_UPGRADE")) && INSTATE_UPGRADE="true"
MIN_BLOCK=$2 && (! $(isNaturalNumber "$MIN_BLOCK")) && MIN_BLOCK="0"
SNAP_FILENAME=$3 && [ -z "$SNAP_FILENAME" ] && echoErr "ERROR: Snapshot filename was not defined" && sleep 5 && exit 1

HALT_CHECK="${COMMON_DIR}/halt" && touch $HALT_CHECK

echoInfo "INFO: Ensuring sekaid process is killed..."
pkill -15 sekaid || echoWarn "WARNING: Failed to kill sekaid"
sleep 15

DATA_GENESIS="$SEKAID_DATA/genesis.json"
LOCAL_GENESIS="$SEKAID_CONFIG/genesis.json"
LOCAL_ADDRBOOK="$SEKAID_CONFIG/addrbook.json"
LOCAL_STATE="$SEKAID_DATA/priv_validator_state.json"
SNAP_INFO="$SEKAID_DATA/snapinfo.json"

SNAP_DESTINATION_FILE="$SNAP_DIR/$SNAP_FILENAME"
ADDRBOOK_DESTINATION_FILE="${COMMON_DIR}/upgrade-addrbook.json"

STATE_HEIGHT=$(jsonQuickParse "height" $LOCAL_STATE || echo "") && (! $(isNaturalNumber "$STATE_HEIGHT")) && MIN_BLOCK="0"
[[ $MIN_BLOCK -lt $STATE_HEIGHT ]] && MIN_BLOCK=$STATE_HEIGHT
 
echoInfo "INFO: Creating backup package..."
cp -afv "$LOCAL_GENESIS" $DATA_GENESIS

echo "{\"height\":$MIN_BLOCK}" >"$SNAP_INFO"

cp -afv "$LOCAL_ADDRBOOK" $ADDRBOOK_DESTINATION_FILE
[ ! -f "$ADDRBOOK_DESTINATION_FILE" ] && echoErr "ERROR: Failed to save addr, file '$ADDRBOOK_DESTINATION_FILE' was not found" && sleep 5 && exit 1

# to prevent appending root path we must package  all from within the target data folder
cd $SEKAID_DATA
timerStart SNAPSHOT
echoInfo "INFO: Please wait, backing up '$SEKAID_DATA' -> '$SNAP_DESTINATION_FILE' ..."
tar -cf "$SNAP_DESTINATION_FILE" ./ && SUCCESS="true" || SUCCESS="false"
echoInfo "INFO: Elapsed: $(timerSpan SNAPSHOT) seconds"

( [ ! -f "$SNAP_DESTINATION_FILE" ] || [ "${SUCCESS,,}" != "true" ] ) && echoInfo "INFO: Failed to create snapshot, file '$SNAP_DESTINATION_FILE' was not found" && exit 1

echoInfo "INFO: Finished container upgrade sequence..."