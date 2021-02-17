#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
exec 2>&1
set -x

echo "INFO: Staring sentry setup v0.0.4"

EXECUTED_CHECK="$COMMON_DIR/executed"
SNAP_FILE="$COMMON_DIR/snap.zip"
DATA_DIR="$SEKAID_HOME/data"
LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
COMMON_GENESIS="$COMMON_DIR/genesis.json"

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

while [ ! -f "$SNAP_FILE" ] && [ ! -f "$COMMON_GENESIS" ]; do
  echo "INFO: Waiting for genesis file to be provisioned... ($(date))"
  sleep 5
done

echo "INFO: Sucess, genesis file was found!"

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
      rm -fv $COMMON_GENESIS
      cp -v -a $DATA_GENESIS $COMMON_GENESIS # move snapshot genesis into common folder
    fi

    rm -fv "$SNAP_FILE"
  else
    echo "INFO: Snap file is NOT present, starting new sync..."
  fi
fi

rm -fv $LOCAL_GENESIS
cp -a -v -f $COMMON_GENESIS $LOCAL_GENESIS # recover genesis from common folder
$SELF_CONTAINER/configure.sh
set +e && source "/etc/profile" &>/dev/null && set -e

touch $EXECUTED_CHECK
sekaid start --home=$SEKAID_HOME --grpc.address="$GRPC_ADDRESS" --trace
