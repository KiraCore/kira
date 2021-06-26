#!/bin/bash
exec 2>&1
set +e && source $ETC_PROFILE &>/dev/null && set -e
set -x
# quick edit: FILE="${SELF_CONTAINER}/start.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

echo "INFO: Staring snapshot setup..."

HALT_CHECK="${COMMON_DIR}/halt"
EXIT_CHECK="${COMMON_DIR}/exit"
EXECUTED_CHECK="${COMMON_DIR}/executed"
CFG_CHECK="${COMMON_DIR}/configuring"
DONE_CHECK="${COMMON_DIR}/done"

SNAP_FILE_INPUT="$COMMON_DIR/snap.zip"

DATA_DIR="$SEKAID_HOME/data"
DATA_GENESIS="$DATA_DIR/genesis.json"

LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
COMMON_GENESIS="$COMMON_READ/genesis.json"
SNAP_INFO="$SEKAID_HOME/data/snapinfo.json"

SNAP_STATUS="$SNAP_DIR/status"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_FINALIZYNG="$SNAP_STATUS/finalizing"
SNAP_PROGRESS="$SNAP_STATUS/progress"
SNAP_LATEST="$SNAP_STATUS/latest"

DESTINATION_FILE="$SNAP_DIR/$SNAP_FILENAME"

echo "OFFLINE" > "$COMMON_DIR/external_address_status"

([ -z "$HALT_HEIGHT" ] || [[ $HALT_HEIGHT -le 0 ]]) && echo "ERROR: Invalid snapshot height, cant be less or equal to 0" && exit 1

echo "$SNAP_FILENAME" > $SNAP_LATEST

while [ -f "$SNAP_DONE" ] || [ -f "$DONE_CHECK" ]; do
    echoInfo "INFO: Snapshot was already finalized, nothing more to do here..."
    rm -fv $CFG_CHECK
    touch $DONE_CHECK
    sleep 600
done

while ! ping -c1 $PING_TARGET &>/dev/null; do
    echoInfo "INFO: Waiting for ping response form $PING_TARGET node... ($(date))"
    sleep 5
done
echoInfo "INFO: Sentry IP Found: $(getent hosts $PING_TARGET | awk '{ print $1 }')"

while [ ! -f "$EXECUTED_CHECK" ] && ($(isFileEmpty "$SNAP_FILE_INPUT")) && ($(isFileEmpty "$COMMON_GENESIS")) ; do
    echoInfo "INFO: Waiting for genesis file to be provisioned... ($(date))"
    sleep 5
done

echoInfo "INFO: Sucess, genesis file was found!"

if [ ! -f "$EXECUTED_CHECK" ]; then
    rm -rfv $SEKAID_HOME
    mkdir -p $SEKAID_HOME/config/

    sekaid init --chain-id="$NETWORK_NAME" "KIRA SNAPSHOT NODE" --home=$SEKAID_HOME

    $SELF_CONTAINER/configure.sh
    set +e && source "/etc/profile" &>/dev/null && set -e
    cp -afv $COMMON_DIR/node_key.json $SEKAID_HOME/config/node_key.json

    if ($(isFileJson "$COMMON_DIR/addrbook.json")) ; then
        echoInfo "INFO: Importing external addrbook file..."
        cp -afv "$COMMON_DIR/addrbook.json" $SEKAID_HOME/config/addrbook.json
    fi

    if (! $(isFileEmpty "$SNAP_FILE_INPUT")) ; then
        echoInfo "INFO: Snap file was found, attepting data recovery..."
        cd $DATA_DIR && timerStart SNAP_EXTRACT
        jar xvf $SNAP_FILE_INPUT || ( echoErr "ERROR: Failed extracting '$SNAP_FILE_INPUT'" && sleep 10 && exit 1 )
        echoInfo "INFO: Success, snapshot ($SNAP_FILE_INPUT) was extracted into data directory ($DATA_DIR), elapsed $(timerSpan SNAP_EXTRACT) seconds"
        cd $SEKAID_HOME
        
        if [ -f "$DATA_GENESIS" ]; then
            echoInfo "INFO: Genesis file was found within the snapshot folder, veryfying checksums..."
            SHA256_DATA_GENESIS=$(sha256 $DATA_GENESIS)
            SHA256_COMMON_GENESIS=$(sha256 $COMMON_GENESIS)
            if [ -z "$SHA256_DATA_GENESIS" ] || [ "$SHA256_DATA_GENESIS" != "$SHA256_COMMON_GENESIS" ]; then
                echoErr "ERROR: Expected genesis checksum of the snapshot to be '$SHA256_DATA_GENESIS' but got '$SHA256_COMMON_GENESIS'"
                exit 1
            else
                echoInfo "INFO: Genesis checksum '$SHA256_DATA_GENESIS' was verified sucessfully!"
            fi
        fi
    else
        echoWarn "WARNINIG: Node will launch in the slow sync mode"
    fi

    rm -rfv $LOCAL_GENESIS
    ln -sfv $COMMON_GENESIS $LOCAL_GENESIS
    echo "0" > $SNAP_PROGRESS
    globSet RESTART_COUNTER 0
    globSet START_TIME "$(date -u +%s)"
fi

echoInfo "INFO: External sync is expected from seed, sentry, priv_sentry or validator node"
while : ; do
    SENTRY_OPEN=$(isPortOpen sentry.local 26656)
    PRIV_SENTRY_OPEN=$(isPortOpen priv-sentry.local 26656)
    VALIDATOR_OPEN=$(isPortOpen validator.local 26656)
    SEED_OPEN=$(isPortOpen seed.local 26656)
    if [ "$SENTRY_OPEN" == "true" ] || [ "$PRIV_SENTRY_OPEN" == "true" ] || [ "$VALIDATOR_OPEN" == "true" ] || [ "$SEED_OPEN" == "true" ]  ; then
        echoInfo "INFO: Sentry, Private Sentry, Seed or Validator container is running!"
        break
    else
        echoWarn "WARNINIG: Waiting for sentry ($SENTRY_OPEN), private sentry ($PRIV_SENTRY_OPEN), seed ($SEED_OPEN) or validator ($VALIDATOR_OPEN) to start..."
        sleep 15
    fi
done

echoInfo "INFO: Loading configuration..."
$SELF_CONTAINER/configure.sh
set +e && source "$ETC_PROFILE" &>/dev/null && set -e
touch $EXECUTED_CHECK
rm -fv $CFG_CHECK

touch ./output.log
LAST_SNAP_BLOCK=0
TOP_SNAP_BLOCK=0
sekaid start --home="$SEKAID_HOME" --grpc.address="$GRPC_ADDRESS" --trace  &>./output.log &
PID1=$!
while :; do
    echoInfo "INFO: Checking node status..."
    SNAP_STATUS=$(sekaid status 2>&1 | jsonParse "" 2>/dev/null || echo -n "")
    SNAP_BLOCK=$(echo $SNAP_STATUS | jsonQuickParse "latest_block_height" 2>/dev/null || echo -n "")
    (! $(isNaturalNumber "$SNAP_BLOCK")) && SNAP_BLOCK="0"

    [[ $TOP_SNAP_BLOCK -lt $SNAP_BLOCK ]] && TOP_SNAP_BLOCK=$SNAP_BLOCK
    echoInfo "INFO: Latest Block Height: $TOP_SNAP_BLOCK"

    # save progress only if status is available or block is diffrent then 0
    if [[ $TOP_SNAP_BLOCK -gt 0 ]]; then
        echoInfo "INFO: Updating progress bar..."
        [[ $TOP_SNAP_BLOCK -lt $HALT_HEIGHT ]] && PERCENTAGE=$(echo "scale=2; ( ( 100 * $TOP_SNAP_BLOCK ) / $HALT_HEIGHT )" | bc)
        [[ $TOP_SNAP_BLOCK -ge $HALT_HEIGHT ]] && PERCENTAGE="100"
        echo "$PERCENTAGE" > $SNAP_PROGRESS
    fi

    if [[ "$TOP_SNAP_BLOCK" -ge "$HALT_HEIGHT" ]]; then
        echoInfo "INFO: Snap was compleated, height $TOP_SNAP_BLOCK was reached!"
        break
    elif [[ "$TOP_SNAP_BLOCK" -gt "$LAST_SNAP_BLOCK" ]]; then
        echoInfo "INFO: Success, block changed! ($LAST_SNAP_BLOCK -> $TOP_SNAP_BLOCK)"
        LAST_SNAP_BLOCK="$TOP_SNAP_BLOCK"
    else
        tryCat ./output.log | tail -n 50
        echoWarn "WARNING: Blocks are not changing..."
    fi

    if ps -p "$PID1" >/dev/null; then
        echoInfo "INFO: Waiting for snapshot node to sync  $TOP_SNAP_BLOCK/$HALT_HEIGHT ($PERCENTAGE %)"
    else
        echoWarn "WARNING: Node finished running, starting tracking and checking final height..."
        tryCat ./output.log | tail -n 100
        kill -15 "$PID1" || echoInfo "INFO: Failed to kill sekai PID $PID1 gracefully P1"
        sleep 5
        kill -9 "$PID1" || echoInfo "INFO: Failed to kill sekai PID $PID1 gracefully P2"
        sleep 10
        kill -2 "$PID1" || echoInfo "INFO: Failed to kill sekai PID $PID1"
        # invalidate all possible connections
        echoInfo "INFO: Starting block sync..."
        sekaid start --home="$SEKAID_HOME" --grpc.address="$GRPC_ADDRESS" --trace  &>./output.log &
        PID1=$!
    fi

    sleep 30
done

touch $SNAP_FINALIZYNG

kill -15 "$PID1" || echoInfo "INFO: Failed to kill sekai PID $PID1 gracefully P1"
sleep 5
kill -9 "$PID1" || echoInfo "INFO: Failed to kill sekai PID $PID1 gracefully P2"
sleep 10
kill -2 "$PID1" || echoInfo "INFO: Failed to kill sekai PID $PID1"

echoInfo "INFO: Printing latest output log..."
cat ./output.log | tail -n 100

echoInfo "INFO: Creating backup package..."
cp -afv "$COMMON_GENESIS" $DATA_DIR/genesis.json
echo "{\"height\":$TOP_SNAP_BLOCK}" >"$SNAP_INFO"

# to prevent appending root path we must zip all from within the target data folder
cd $DATA_DIR
zip -9 -r "$DESTINATION_FILE" . *

[ ! -f "$DESTINATION_FILE" ] && echoInfo "INFO: Failed to create snapshot, file $DESTINATION_FILE was not found" && exit 1

touch $SNAP_DONE $DONE_CHECK
