#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
exec 2>&1
set -x

echoInfo "INFO: Staring sentry setup v0.0.4"

EXECUTED_CHECK="$COMMON_DIR/executed"
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

while [ ! -f "$SNAP_FILE_INPUT" ] && [ ! -f "$COMMON_GENESIS" ] ; do
  echoInfo "INFO: Waiting for genesis file and ip addresses info to be provisioned... ($(date))"
  sleep 5
done

while [ ! -f "$LIP_FILE" ] && [ ! -f "$PIP_FILE" ] ; do
  echoInfo "INFO: Waiting for Local or Public IP to be provisioned... ($(date))"
  sleep 5
done

LOCAL_IP=$(cat $LIP_FILE || echo "")
PUBLIC_IP=$(cat $PIP_FILE || echo "")
SNAP_HEIGHT=$(cat $SNAP_HEIGHT_FILE || echo "")
SNAP_NAME=$(cat $SNAP_NAME_FILE || echo "")
SNAP_FILE_OUTPUT="$COMMON_DIR/$SNAP_NAME_FILE"

echoInfo "INFO: Sucess, genesis file was found!"
echoInfo "INFO:    Local IP: $LOCAL_IP"
echoInfo "INFO:   Public IP: $PUBLIC_IP"
echoInfo "INFO: Snap Height: $SNAP_HEIGHT"
echoInfo "INFO:   Snap Name: $SNAP_NAME_FILE"

if [ ! -f "$EXECUTED_CHECK" ]; then
  rm -rfv $SEKAID_HOME
  mkdir -p $SEKAID_HOME/config/

  sekaid init --chain-id="$NETWORK_NAME" "KIRA SENTRY NODE" --home=$SEKAID_HOME

  rm -fv $SEKAID_HOME/config/node_key.json
  cp $COMMON_DIR/node_key.json $SEKAID_HOME/config/
  
  if [ -f "$SNAP_FILE_INPUT" ] ; then
    echoInfo "INFO: Snap file was found, attepting data recovery..."
    
    rm -rfv "$DATA_DIR" && mkdir -p "$DATA_DIR"
    unzip $SNAP_FILE_INPUT -d $DATA_DIR

    if [ -f "$DATA_GENESIS" ] ; then
      echoInfo "INFO: Genesis file was found within the snapshot folder, attempting recovery..."
      SHA256_DATA_GENESIS=$(sha256sum $DATA_GENESIS | awk '{ print $1 }' | xargs || echo "")
      SHA256_COMMON_GENESIS=$(sha256sum $COMMON_GENESIS | awk '{ print $1 }' | xargs || echo "")
      if [ -z "$SHA256_DATA_GENESIS" ] || [ "$SHA256_DATA_GENESIS" != "$SHA256_COMMON_GENESIS" ] ; then
          echoErr "ERROR: Expected genesis checksum of the snapshot to be '$SHA256_DATA_GENESIS' but got '$SHA256_COMMON_GENESIS'"
          exit 1
      else
          echoInfo "INFO: Genesis checksum '$SHA256_DATA_GENESIS' was verified sucessfully!"
      fi
    fi
  else
    echoInfo "INFO: Snap file is NOT present, starting new sync..."
  fi
fi


if [ "${NODE_TYPE,,}" == "sentry" ] || [ "${NODE_TYPE,,}" == "priv_sentry" ] || [ "${NODE_TYPE,,}" == "seed" ]  ; then
    if [ ! -z "$EXTERNAL_DOMAIN" ] && [ "${NODE_TYPE,,}" != "priv_sentry" ] ; then
        echoInfo "INFO: Domain name '$EXTERNAL_DOMAIN' will be used as external address advertised to other nodes"
        EXTERNAL_ADDR="$EXTERNAL_DOMAIN"
    elif [ -z "$CFG_external_address" ] ; then
        echoInfo "INFO: Scanning external address..."
        if [ "${NODE_TYPE,,}" == "priv_sentry" ] ; then
            if timeout 3 nc -z $LOCAL_IP $EXTERNAL_P2P_PORT ; then EXTERNAL_IP="$LOCAL_IP" ; else EXTERNAL_IP=0.0.0.0 ; fi
        else
            if [ ! -z "$PUBLIC_IP" ] && timeout 3 nc -z $PUBLIC_IP $EXTERNAL_P2P_PORT ; then EXTERNAL_IP="$PUBLIC_IP" ; fi
            if [ -z "$EXTERNAL_IP" ] && timeout 3 nc -z $LOCAL_IP $EXTERNAL_P2P_PORT ; then EXTERNAL_IP="$LOCAL_IP" ; fi
        fi
        
        if [ ! -z "$EXTERNAL_IP" ] && timeout 2 nc -z $EXTERNAL_IP $EXTERNAL_P2P_PORT ; then
           echoInfo "INFO: Node public address '$EXTERNAL_IP' was found"
           EXTERNAL_ADDR="$EXTERNAL_IP"
        else
            echoWarn "WARNING: Failed to discover external IP address, your node is not exposed to the public internet or its P2P port $EXTERNAL_P2P_PORT was not exposed"
        fi
    fi

    if [ ! -z "$EXTERNAL_ADDR" ] ; then
        CFG_external_address="tcp://$EXTERNAL_ADDR:$EXTERNAL_P2P_PORT"
        echo "$CFG_external_address" > "$COMMON_DIR/external_address"
        CDHelper text lineswap --insert="EXTERNAL_ADDR=\"$EXTERNAL_ADDR\"" --prefix="EXTERNAL_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
        CDHelper text lineswap --insert="CFG_external_address=\"$CFG_external_address\"" --prefix="CFG_external_address=" --path=$ETC_PROFILE --append-if-found-not=True
    elif [ -z "$CFG_external_address" ] ; then
        CFG_external_address=""
        echo "tcp://0.0.0.0:$EXTERNAL_P2P_PORT" > "$COMMON_DIR/external_address"
    fi
else
    echoInfo "INFO: Node external address will not be advertised to other nodes"
fi

rm -fv $LOCAL_GENESIS
cp -a -v -f $COMMON_GENESIS $LOCAL_GENESIS # recover genesis from common folder
$SELF_CONTAINER/configure.sh
set +e && source "/etc/profile" &>/dev/null && set -e

touch $EXECUTED_CHECK

if ($(isNaturalNumber $SNAP_HEIGHT)) && [ $SNAP_HEIGHT -gt 0 ] && [ ! -z "$SNAP_NAME_FILE" ] ; then
    echoInfo "INFO: Snapshot was requested at height $SNAP_HEIGHT, executing..."
    rm -fv $SNAP_FILE_OUTPUT
    sekaid start --home="$SEKAID_HOME" --grpc.address="$GRPC_ADDRESS" --trace --halt-height="$SNAP_HEIGHT" || echoWarn "WARNING: Snapshot done"
  
    echo "INFO: Creating backup package '$SNAP_FILE_OUTPUT' ..."
    cp -afv "$LOCAL_GENESIS" $SEKAID_HOME/data
    echo "{\"height\":$SNAP_HEIGHT}" > "$SNAP_INFO"

    # to prevent appending root path we must zip all from within the target data folder
    cd $SEKAID_HOME/data && zip -r "$SNAP_FILE_OUTPUT" . *
    [ ! -f "$SNAP_FILE_OUTPUT" ] echo "INFO: Failed to create snapshot, file $SNAP_FILE_OUTPUT was not found" && exit 1
    rm -fv $SNAP_HEIGHT_FILE
fi

echoInfo "INFO: Starting sekaid..."
sekaid start --home=$SEKAID_HOME --grpc.address="$GRPC_ADDRESS" --trace 

