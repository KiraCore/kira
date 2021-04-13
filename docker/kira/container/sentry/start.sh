#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
exec 2>&1
set -x

echoInfo "INFO: Staring sentry setup v0.0.4"

EXECUTED_CHECK="$COMMON_DIR/executed"
SNAP_HEIGHT_FILE="$COMMON_DIR/snap_height"
SNAP_NAME_FILE="$COMMON_DIR/snap_name"

SNAP_DIR_INPUT="$COMMON_READ/snap"
SNAP_FILE_INPUT="$COMMON_READ/snap.zip"
SNAP_INFO="$SEKAID_HOME/data/snapinfo.json"

LIP_FILE="$COMMON_READ/local_ip"
PIP_FILE="$COMMON_READ/public_ip"
DATA_DIR="$SEKAID_HOME/data"
LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
COMMON_GENESIS="$COMMON_READ/genesis.json"
DATA_GENESIS="$DATA_DIR/genesis.json"

echo "OFFLINE" > "$COMMON_DIR/external_address_status"

while [ ! -f "$EXECUTED_CHECK" ] && ($(isFileEmpty "$SNAP_FILE_INPUT")) && ($(isDirEmpty "$SNAP_DIR_INPUT")) && ($(isFileEmpty "$COMMON_GENESIS")) ; do
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

LOCAL_IP=$(cat $LIP_FILE || echo -n "")
PUBLIC_IP=$(cat $PIP_FILE || echo -n "")
SNAP_HEIGHT=$(cat $SNAP_HEIGHT_FILE || echo -n "")
SNAP_NAME=$(cat $SNAP_NAME_FILE || echo -n "")
SNAP_OUTPUT="/snap/$SNAP_NAME"

echoInfo "INFO: Sucess, genesis file was found!"
echoInfo "INFO:    Local IP: $LOCAL_IP"
echoInfo "INFO:   Public IP: $PUBLIC_IP"
echoInfo "INFO: Snap Height: $SNAP_HEIGHT"
echoInfo "INFO:   Snap Name: $SNAP_NAME"

if [ ! -f "$EXECUTED_CHECK" ]; then
    rm -rfv $SEKAID_HOME
    mkdir -p $SEKAID_HOME/config/
  
    sekaid init --chain-id="$NETWORK_NAME" "KIRA SENTRY NODE" --home=$SEKAID_HOME
  
    rm -fv $SEKAID_HOME/config/node_key.json
    cp $COMMON_DIR/node_key.json $SEKAID_HOME/config/

    if (! $(isFileEmpty "$SNAP_FILE_INPUT")) || (! $(isDirEmpty "$SNAP_DIR_INPUT")) ; then
        echoInfo "INFO: Snap file was found, attepting integrity verification adn data recovery..."
        if (! $(isFileEmpty "$SNAP_FILE_INPUT")) ; then 
            cd $DATA_DIR
            jar xvf $SNAP_FILE_INPUT
            cd $SEKAID_HOME
        elif (! $(isDirEmpty "$SNAP_DIR_INPUT")) ; then
            cp -rfv "$SNAP_DIR_INPUT/." "$DATA_DIR"
        else
            echoErr "ERROR: Snap file or directory was not found"
            exit 1
        fi
    
        if [ -f "$DATA_GENESIS" ] ; then
            echoInfo "INFO: Genesis file was found within the snapshot folder, attempting recovery..."
            SHA256_DATA_GENESIS=$(sha256sum $DATA_GENESIS | awk '{ print $1 }' | xargs || echo -n "")
            SHA256_COMMON_GENESIS=$(sha256sum $COMMON_GENESIS | awk '{ print $1 }' | xargs || echo -n "")
            if [ -z "$SHA256_DATA_GENESIS" ] || [ "$SHA256_DATA_GENESIS" != "$SHA256_COMMON_GENESIS" ] ; then
                echoErr "ERROR: Expected genesis checksum of the snapshot to be '$SHA256_DATA_GENESIS' but got '$SHA256_COMMON_GENESIS'"
                exit 1
            else
                echoInfo "INFO: Genesis checksum '$SHA256_DATA_GENESIS' was verified sucessfully!"
            fi
        fi
    else
        echoInfo "INFO: Snap file is NOT present, starting new sync..."
        sekaid unsafe-reset-all --home=$SEKAID_HOME
    fi
fi

if [ "${NODE_TYPE,,}" == "priv_sentry" ] ; then
    EXTERNAL_ADDR="$LOCAL_IP"
elif [ "${NODE_TYPE,,}" == "sentry" ] || [ "${NODE_TYPE,,}" == "seed" ] ; then
    EXTERNAL_ADDR="$PUBLIC_IP"
else
    echoErr "ERROR: Unknown node type '$NODE_TYPE'"
    exit 1
fi

CFG_external_address="tcp://$EXTERNAL_ADDR:$EXTERNAL_P2P_PORT"
echo "$CFG_external_address" > "$COMMON_DIR/external_address"
CDHelper text lineswap --insert="EXTERNAL_ADDR=\"$EXTERNAL_ADDR\"" --prefix="EXTERNAL_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="CFG_external_address=\"$CFG_external_address\"" --prefix="CFG_external_address=" --path=$ETC_PROFILE --append-if-found-not=True

rm -fv $LOCAL_GENESIS
cp -a -v -f $COMMON_GENESIS $LOCAL_GENESIS # recover genesis from common folder
$SELF_CONTAINER/configure.sh
set +e && source "$ETC_PROFILE" &>/dev/null && set -e

touch $EXECUTED_CHECK

if ($(isNaturalNumber $SNAP_HEIGHT)) && [ $SNAP_HEIGHT -gt 0 ] && [ ! -z "$SNAP_NAME_FILE" ] ; then
    echoInfo "INFO: Snapshot was requested at height $SNAP_HEIGHT, executing..."
    rm -frv $SNAP_OUTPUT
    sekaid start --home="$SEKAID_HOME" --grpc.address="$GRPC_ADDRESS" --trace --halt-height="$SNAP_HEIGHT" || echoWarn "WARNING: Snapshot done"
  
    echoInfo "INFO: Creating backup package '$SNAP_OUTPUT' ..."
    cp -afv "$LOCAL_GENESIS" $SEKAID_HOME/data
    echo "{\"height\":$SNAP_HEIGHT}" > "$SNAP_INFO"

    # to prevent appending root path we must zip all from within the target data folder
    cp -rfv "$SEKAID_HOME/data/." "$SNAP_OUTPUT"
    [ ! -d "$SNAP_OUTPUT" ] && echo "INFO: Failed to create snapshot, directory $SNAP_OUTPUT was not found" && exit 1
    rm -fv "$SNAP_HEIGHT_FILE" "$SNAP_NAME_FILE"
fi

echoInfo "INFO: Starting sekaid..."
sekaid start --home=$SEKAID_HOME --grpc.address="$GRPC_ADDRESS" --trace 

