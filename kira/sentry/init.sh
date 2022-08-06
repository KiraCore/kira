#!/usr/bin/env bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
# quick edit: FILE="${SELF_CONTAINER}/sekai-init.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

echoInfo "INFO: Started SEKAI init..."

SNAP_FILE_INPUT="$COMMON_READ/snap.tar"
DATA_DIR="$SEKAID_HOME/data"
LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
COMMON_GENESIS="$COMMON_READ/genesis.json"
DATA_GENESIS="$DATA_DIR/genesis.json"

rm -rfv $SEKAID_HOME/*
mkdir -p $SEKAID_HOME/config/  
sekaid init --chain-id="$NETWORK_NAME" "KIRA SENTRY NODE" --home=$SEKAID_HOME

if (! $(isFileEmpty "$SNAP_FILE_INPUT")); then
    echoInfo "INFO: Snap file was found, attepting integrity verification and data recovery..."
    cd $DATA_DIR && timerStart SNAP_EXTRACT
    tar -xvf $SNAP_FILE_INPUT -C ./ || ( echoErr "ERROR: Failed extracting '$SNAP_FILE_INPUT'" && sleep 10 && exit 1 )
    echoInfo "INFO: Success, snapshot ($SNAP_FILE_INPUT) was extracted into data directory ($DATA_DIR), elapsed $(timerSpan SNAP_EXTRACT) seconds"
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

echoInfo "INFO: Finished SEKAI init"