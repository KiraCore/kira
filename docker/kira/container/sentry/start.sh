#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
exec 2>&1
set -x

echo "INFO: Staring sentry setup v0.0.4"

EXECUTED_CHECK="$COMMON_DIR/executed"

[ "${NODE_TYPE,,}" == "snapshot" ] && \
SNAP_FILE="$COMMON_DIR/snap.zip" || \
SNAP_FILE="$COMMON_READ/snap.zip"

LIP_FILE="$COMMON_READ/local_ip"
PIP_FILE="$COMMON_READ/public_ip"
DATA_DIR="$SEKAID_HOME/data"
LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
COMMON_GENESIS="$COMMON_READ/genesis.json"

echo "OFFLINE" > "$COMMON_DIR/external_address_status"

if [ "${EXTERNAL_SYNC,,}" != "true" ] ; then
    echo "INFO: Checking if sentry can be synchronized from the validator node..."
    while ! ping -c1 validator &>/dev/null ; do
      echo "INFO: Waiting for ping response form validator node... ($(date))"
      sleep 5
    done
    echo "INFO: Validator IP Found: $(getent hosts validator | awk '{ print $1 }')"
else
    echo "INFO: Node will be synchronised from external networks"
fi

while [ ! -f "$SNAP_FILE" ] && [ ! -f "$COMMON_GENESIS" ] && [ ! -f "$LIP_FILE" ] && [ ! -f "$PIP_FILE" ] ; do
  echo "INFO: Waiting for genesis file and ip addresses info to be provisioned... ($(date))"
  sleep 5
done
LOCAL_IP=$(cat $LIP_FILE || echo "")
PUBLIC_IP=$(cat $PIP_FILE || echo "")

echo "INFO: Sucess, genesis file was found!"
echo "INFO: Local IP: $LOCAL_IP"
echo "INFO: Public IP: $PUBLIC_IP"

if [ ! -f "$EXECUTED_CHECK" ]; then
  rm -rfv $SEKAID_HOME
  mkdir -p $SEKAID_HOME/config/

  sekaid init --chain-id="$NETWORK_NAME" "KIRA SENTRY NODE" --home=$SEKAID_HOME

  rm -fv $SEKAID_HOME/config/node_key.json
  cp $COMMON_DIR/node_key.json $SEKAID_HOME/config/
  
  if [ -f "$SNAP_FILE" ] ; then
    echo "INFO: Snap file was found, attepting data recovery..."
    
    rm -rfv "$DATA_DIR" && mkdir -p "$DATA_DIR"
    unzip $SNAP_FILE -d $DATA_DIR
    DATA_GENESIS="$DATA_DIR/genesis.json"

    if [ -f "$DATA_GENESIS" ] ; then
      echo "INFO: Genesis file was found within the snapshot folder, attempting recovery..."
      SHA256_DATA_GENESIS=$(sha256sum $DATA_GENESIS | awk '{ print $1 }' | xargs || echo "")
      SHA256_COMMON_GENESIS=$(sha256sum $COMMON_GENESIS | awk '{ print $1 }' | xargs || echo "")
      if [ "$SHA256_DATA_GENESIS" != "$SHA256_COMMON_GENESIS" ] ; then
          echoErr "ERROR: Expected genesis checksum of the snapshot to be '$SHA256_DATA_GENESIS' but got '$SHA256_COMMON_GENESIS'"
          exit 1
      else
          echoInfo "INFO: Genesis checksum '$SHA256_DATA_GENESIS' was verified sucessfully!"
      fi
    fi

    # snap file should only be removed if sentry is a snapshot container otherwise it is supplied from read only volume and can't be modify by a container
    [ "${NODE_TYPE,,}" == "snapshot" ] && rm -fv "$SNAP_FILE"
  else
    echo "INFO: Snap file is NOT present, starting new sync..."
  fi
fi


if [ "${NODE_TYPE,,}" == "sentry" ] || [ "${NODE_TYPE,,}" == "seed" ]  ; then
    if [ ! -z "$EXTERNAL_DOMAIN" ] ; then
        echo "INFO: Domain name '$EXTERNAL_DOMAIN' will be used as external address advertised to other nodes"
        EXTERNAL_ADDR="$EXTERNAL_DOMAIN"
    elif [ -z "$CFG_external_address" ] ; then
        echo "INFO: Scanning external address..."
        if [ ! -z "$PUBLIC_IP" ] && timeout 3 nc -z $PUBLIC_IP $EXTERNAL_P2P_PORT ; then EXTERNAL_IP="$PUBLIC_IP" ; fi
        if [ -z "$EXTERNAL_IP" ] && timeout 3 nc -z $LOCAL_IP $EXTERNAL_P2P_PORT ; then EXTERNAL_IP="$LOCAL_IP" ; fi

        if [ ! -z "$EXTERNAL_IP" ] && timeout 2 nc -z $EXTERNAL_IP $EXTERNAL_P2P_PORT ; then
           echo "INFO: Node public address '$EXTERNAL_IP' was found"
           EXTERNAL_ADDR="$EXTERNAL_IP"
        else
            echo "WARNING: Failed to discover external IP address, your node is not exposed to the public internet or its P2P port $EXTERNAL_P2P_PORT was not exposed"
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
    echo "INFO: Node external address will not be advertised to other nodes"
fi

rm -fv $LOCAL_GENESIS
cp -a -v -f $COMMON_GENESIS $LOCAL_GENESIS # recover genesis from common folder
$SELF_CONTAINER/configure.sh
set +e && source "/etc/profile" &>/dev/null && set -e

touch $EXECUTED_CHECK
sekaid start --home=$SEKAID_HOME --grpc.address="$GRPC_ADDRESS" --trace
