#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
exec 2>&1
set -x

echoInfo "INFO: Staring sentry setup..."

EXECUTED_CHECK="$COMMON_DIR/executed"
CFG_CHECK="${COMMON_DIR}/configuring"

SNAP_HEIGHT_FILE="$COMMON_DIR/snap_height"
SNAP_NAME_FILE="$COMMON_DIR/snap_name"
SNAP_FILE_INPUT="$COMMON_READ/snap.zip"
SNAP_INFO="$SEKAID_HOME/data/snapinfo.json"

LIP_FILE="$COMMON_READ/local_ip"
PIP_FILE="$COMMON_READ/public_ip"
DATA_DIR="$SEKAID_HOME/data"
LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
COMMON_GENESIS="$COMMON_READ/genesis.json"
DATA_GENESIS="$DATA_DIR/genesis.json"

echo "OFFLINE" > "$COMMON_DIR/external_address_status"

while [ ! -f "$EXECUTED_CHECK" ] && ($(isFileEmpty "$SNAP_FILE_INPUT")) && ($(isFileEmpty "$COMMON_GENESIS")) ; do
    echoInfo "INFO: Waiting for genesis file to be provisioned... ($(date))"
    sleep 5
done

while ($(isFileEmpty "$LIP_FILE")) && [ "${NODE_TYPE,,}" == "priv_sentry" ] ; do
   echoInfo "INFO: Waiting for Local IP to be provisioned... ($(date))"
   sleep 5
done

while ($(isFileEmpty "$PIP_FILE")) && ( [ "${NODE_TYPE,,}" == "sentry" ] || [ "${NODE_TYPE,,}" == "seed" ] ); do
    echoInfo "INFO: Waiting for Public IP to be provisioned... ($(date))"
    sleep 5
done

SNAP_HEIGHT=$(cat $SNAP_HEIGHT_FILE || echo -n "")
SNAP_NAME=$(cat $SNAP_NAME_FILE || echo -n "")
SNAP_OUTPUT="/snap/$SNAP_NAME"

echoInfo "INFO: Sucess, genesis file was found!"
echoInfo "INFO: Snap Height: $SNAP_HEIGHT"
echoInfo "INFO:   Snap Name: $SNAP_NAME"

if [ ! -f "$EXECUTED_CHECK" ]; then
    rm -rfv $SEKAID_HOME
    mkdir -p $SEKAID_HOME/config/  
    sekaid init --chain-id="$NETWORK_NAME" "KIRA SENTRY NODE" --home=$SEKAID_HOME

    if (! $(isFileEmpty "$SNAP_FILE_INPUT")); then
        echoInfo "INFO: Snap file was found, attepting integrity verification and data recovery..."
        cd $DATA_DIR
        jar xvf $SNAP_FILE_INPUT
        cd $SEKAID_HOME
    
        if [ -f "$DATA_GENESIS" ] ; then
            echoInfo "INFO: Genesis file was found within the snapshot folder, attempting recovery..."
            SHA256_DATA_GENESIS=$(sha256 $DATA_GENESIS)
            SHA256_COMMON_GENESIS=$(sha256 $COMMON_GENESIS)
            if [ -z "$SHA256_DATA_GENESIS" ] || [ "$SHA256_DATA_GENESIS" != "$SHA256_COMMON_GENESIS" ] ; then
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
    touch $EXECUTED_CHECK
fi

if [ "${EXTERNAL_SYNC,,}" == "true" ] && [ "${NODE_TYPE,,}" == "seed" ] ; then
    echoInfo "INFO: External sync is expected from sentry or priv_sentry"
    while : ; do
        SENTRY_OPEN=$(isPortOpen sentry.sentrynet.local 26656)
        PRIV_SENTRY_OPEN=$(isPortOpen priv-sentry.sentrynet.local 26656)
        if [ "$SENTRY_OPEN" == "true" ] || [ "$PRIV_SENTRY_OPEN" == "true" ] ; then
            echoInfo "INFO: Sentry or Private Sentry container is running!"
            break
        else
            echoWarn "WARNINIG: Waiting for sentry ($SENTRY_OPEN) or private sentry ($PRIV_SENTRY_OPEN) to start..."
            sleep 15
        fi
    done
elif [ "${NEW_NETWORK,,}" == "true" ] && [[ "${NODE_TYPE,,}" =~ ^(sentry|priv_sentry)$ ]] ; then
    echoInfo "INFO: External sync is expected from sentry or priv_sentry"
    while : ; do
        VALIDATOR_OPEN=$(isPortOpen validator.kiranet.local 26656)
        if [ "$VALIDATOR_OPEN" == "true" ] ; then
            echoInfo "INFO: Validator node is started"
            break
        else
            echoWarn "WARNINIG: Waiting for validator ($VALIDATOR_OPEN) to start..."
            sleep 15
        fi
    done
fi

echoInfo "INFO: Loading configuration..."
$SELF_CONTAINER/configure.sh
set +e && source "$ETC_PROFILE" &>/dev/null && set -e
rm -fv $CFG_CHECK

if ($(isNaturalNumber $SNAP_HEIGHT)) && [[ $SNAP_HEIGHT -gt 0 ]] && [ ! -z "$SNAP_NAME_FILE" ] ; then
    echoInfo "INFO: Snapshot was requested at height $SNAP_HEIGHT, executing..."
    rm -frv $SNAP_OUTPUT

    touch ./output.log
    LAST_SNAP_BLOCK=0
    TOP_SNAP_BLOCK=0
    sekaid start --home="$SEKAID_HOME" --grpc.address="$GRPC_ADDRESS" --trace  &>./output.log &
    PID1=$!
    sleep 30
    while :; do
        echoInfo "INFO: Checking node status..."
        SNAP_STATUS=$(sekaid status 2>&1 | jsonParse "" 2>/dev/null || echo -n "")
        SNAP_BLOCK=$(echo $SNAP_STATUS | jsonQuickParse "latest_block_height" 2>/dev/null || echo -n "")
        (! $(isNaturalNumber "$SNAP_BLOCK")) && SNAP_BLOCK="0"

        [[ $TOP_SNAP_BLOCK -lt $SNAP_BLOCK ]] && TOP_SNAP_BLOCK=$SNAP_BLOCK
        echoInfo "INFO: Latest Block Height: $TOP_SNAP_BLOCK"

        if [[ "$TOP_SNAP_BLOCK" -ge "$SNAP_HEIGHT" ]]; then
            echoInfo "INFO: Snap was compleated, height $TOP_SNAP_BLOCK was reached!"
            break
        elif [[ "$TOP_SNAP_BLOCK" -gt "$LAST_SNAP_BLOCK" ]]; then
            echoInfo "INFO: Success, block changed! ($LAST_SNAP_BLOCK -> $TOP_SNAP_BLOCK)"
            LAST_SNAP_BLOCK="$TOP_SNAP_BLOCK"
        else
            echoWarn "WARNING: Blocks are not changing..."
        fi

        if ps -p "$PID1" >/dev/null; then
            echoInfo "INFO: Waiting for snapshot node to sync  $TOP_SNAP_BLOCK/$SNAP_HEIGHT"
        else
            echoWarn "WARNING: Node finished running, starting tracking and checking final height..."
            cat ./output.log | tail -n 100
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

    kill -15 "$PID1" || echoInfo "INFO: Failed to kill sekai PID $PID1 gracefully P1"
    sleep 5
    kill -9 "$PID1" || echoInfo "INFO: Failed to kill sekai PID $PID1 gracefully P2"
    sleep 10
    kill -2 "$PID1" || echoInfo "INFO: Failed to kill sekai PID $PID1"

    echoInfo "INFO: Printing latest output log..."
    cat ./output.log | tail -n 100

    echoInfo "INFO: Creating backup package '$SNAP_OUTPUT' ..."
    # make sure healthcheck will not interrupt configuration
    touch $CFG_CHECK
    cp -afv "$LOCAL_GENESIS" $SEKAID_HOME/data
    echo "{\"height\":$SNAP_HEIGHT}" > "$SNAP_INFO"

    # to prevent appending root path we must zip all from within the target data folder
    cp -rfv "$SEKAID_HOME/data/." "$SNAP_OUTPUT"
    [ ! -d "$SNAP_OUTPUT" ] && echo "INFO: Failed to create snapshot, directory $SNAP_OUTPUT was not found" && exit 1
    rm -fv "$SNAP_HEIGHT_FILE" "$SNAP_NAME_FILE" "$CFG_CHECK"
fi

echoInfo "INFO: Starting sekaid..."
sekaid start --home=$SEKAID_HOME --grpc.address="$GRPC_ADDRESS" --trace 
