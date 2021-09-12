#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
exec 2>&1
set -x

echoInfo "INFO: Staring $NODE_TYPE setup..."

EXECUTED_CHECK="$COMMON_DIR/executed"
CFG_CHECK="${COMMON_DIR}/configuring"

SNAP_FILE_INPUT="$COMMON_READ/snap.zip"
SNAP_INFO="$SEKAID_HOME/data/snapinfo.json"

DATA_DIR="$SEKAID_HOME/data"
LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
COMMON_GENESIS="$COMMON_READ/genesis.json"
DATA_GENESIS="$DATA_DIR/genesis.json"

globSet EXTERNAL_STATUS "OFFLINE"

while [ ! -f "$EXECUTED_CHECK" ] && ($(isFileEmpty "$SNAP_FILE_INPUT")) && ($(isFileEmpty "$COMMON_GENESIS")) ; do
    echoInfo "INFO: Waiting for genesis file to be provisioned... ($(date))"
    sleep 5
done

LOCAL_IP=$(globGet LOCAL_IP "$GLOBAL_COMMON_RO")
PUBLIC_IP=$(globGet PUBLIC_IP "$GLOBAL_COMMON_RO")
EXTERNAL_SYNC=$(globGet EXTERNAL_SYNC "$GLOBAL_COMMON_RO")
INFRA_MODE=$(globGet INFRA_MODE "$GLOBAL_COMMON_RO")
NEW_NETWORK=$(globGet NEW_NETWORK "$GLOBAL_COMMON_RO")

PRIVATE_MODE=$(globGet PRIVATE_MODE)

while [ -z "$LOCAL_IP" ] && [ "${PRIVATE_MODE,,}" == "true" ] ; do
   echoInfo "INFO: Waiting for Local IP to be provisioned... ($(date))"
   LOCAL_IP=$(globGet LOCAL_IP "$GLOBAL_COMMON_RO")
   PRIVATE_MODE=$(globGet PRIVATE_MODE)
   sleep 5
done

while [ -z "$PUBLIC_IP" ] && [ "${PRIVATE_MODE,,}" != "true" ] ; do
    echoInfo "INFO: Waiting for Public IP to be provisioned... ($(date))"
    PUBLIC_IP=$(globGet PUBLIC_IP "$GLOBAL_COMMON_RO")
    PRIVATE_MODE=$(globGet PRIVATE_MODE)
    sleep 5
done

echoInfo "INFO: Sucess, genesis file was found!"

if [ ! -f "$EXECUTED_CHECK" ]; then
    rm -rfv $SEKAID_HOME
    mkdir -p $SEKAID_HOME/config/  
    sekaid init --chain-id="$NETWORK_NAME" "KIRA SENTRY NODE" --home=$SEKAID_HOME

    if (! $(isFileEmpty "$SNAP_FILE_INPUT")); then
        echoInfo "INFO: Snap file was found, attepting integrity verification and data recovery..."
        cd $DATA_DIR && timerStart SNAP_EXTRACT
        jar xvf $SNAP_FILE_INPUT || ( echoErr "ERROR: Failed extracting '$SNAP_FILE_INPUT'" && sleep 10 && exit 1 )
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
    touch $EXECUTED_CHECK
    globSet RESTART_COUNTER 0
    globSet START_TIME "$(date -u +%s)"
fi

echoInfo "INFO: Loading configuration..."
$SELF_CONTAINER/configure.sh
set +e && source "$ETC_PROFILE" &>/dev/null && set -e
rm -fv $CFG_CHECK

echoInfo "INFO: Starting sekaid..."
sekaid start --home=$SEKAID_HOME --trace 
