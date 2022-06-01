#!/usr/bin/env bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
exec 2>&1
set -x

KIRA_SETUP_VER=$(globGet KIRA_SETUP_VER "$GLOBAL_COMMON_RO")
PRIVATE_MODE=$(globGet PRIVATE_MODE)

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: KIRA ${NODE_TYPE^^} START SCRIPT $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "| SEKAI VERSION: $(sekaid version)"
echoWarn "|   BASH SOURCE: ${BASH_SOURCE[0]}"
echoWarn "|   SEKAID HOME: $SEKAID_HOME"
echoWarn "|  PRIVATE MODE: $PRIVATE_MODE"
echoWarn "------------------------------------------------"
set -x

SNAP_FILE_INPUT="$COMMON_READ/snap.tar"
SNAP_INFO="$SEKAID_HOME/data/snapinfo.json"

DATA_DIR="$SEKAID_HOME/data"
LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
COMMON_GENESIS="$COMMON_READ/genesis.json"
DATA_GENESIS="$DATA_DIR/genesis.json"

globSet EXTERNAL_STATUS "OFFLINE"

while [ "$(globGet INIT_DONE)" != "true" ] && ($(isFileEmpty "$SNAP_FILE_INPUT")) && ($(isFileEmpty "$COMMON_GENESIS")) ; do
    echoInfo "INFO: Waiting for genesis file to be provisioned... ($(date))"
    sleep 5
done

LOCAL_IP=$(globGet LOCAL_IP "$GLOBAL_COMMON_RO")
PUBLIC_IP=$(globGet PUBLIC_IP "$GLOBAL_COMMON_RO")
EXTERNAL_SYNC=$(globGet EXTERNAL_SYNC "$GLOBAL_COMMON_RO")
INFRA_MODE=$(globGet INFRA_MODE "$GLOBAL_COMMON_RO")

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

if [ "$(globGet INIT_DONE)" != "true" ]; then
    rm -rfv $SEKAID_HOME
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
    globSet INIT_DONE "true" 
    globSet RESTART_COUNTER 0
    globSet START_TIME "$(date -u +%s)"
fi

echoInfo "INFO: Loading configuration..."
$COMMON_DIR/configure.sh
set +e && source "$ETC_PROFILE" &>/dev/null && set -e
globSet CFG_TASK "false"
globSet RUNTIME_VERSION "sekaid $(sekaid version)"

echoInfo "INFO: Starting sekaid..."
EXIT_CODE=0 && sekaid start --home=$SEKAID_HOME --trace || EXIT_CODE="$?"
set +x
echoErr "ERROR: SEKAID process failed with the exit code $EXIT_CODE"
sleep 3
exit 1
