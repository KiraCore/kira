#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring sentry..."

EXECUTED_CHECK="/root/executed"
HALT_CHECK="${COMMON_DIR}/halt"

while [ -f "$HALT_CHECK" ]; do
  sleep 30
done

while ! ping -c1 validator &>/dev/null; do
  echo "INFO: Waiting for ping response form validator node... ($(date))"
  sleep 5
done
echo "INFO: Validator IP Found: $(getent hosts validator | awk '{ print $1 }')"

while [ -f "$SNAP_FILE" ] || [ ! -f "$COMMON_DIR/genesis.json" ]; do
  echo "INFO: Waiting for genesis file to be provisioned... ($(date))"
  sleep 5
done

echo "INFO: Sucess, genesis file was found!"

if [ ! -f "$EXECUTED_CHECK" ]; then
  SNAP_FILE="$COMMON_DIR/snap.zip"
  DATA_DIR="$SEKAID_HOME/data"
  LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
  COMMON_GENESIS="$COMMON_DIR/genesis.json"

  rm -rfv $SEKAID_HOME
  mkdir -p $SEKAID_HOME/config/

  sekaid init --chain-id=testing testing --home=$SEKAID_HOME

  rm -fv $SEKAID_HOME/config/node_key.json
  rm -fv $SEKAID_HOME/config/config.toml

  cp $COMMON_DIR/node_key.json $SEKAID_HOME/config/
  cp $COMMON_DIR/config.toml $SEKAID_HOME/config/
  
  if [ -f "$SNAP_FILE" ] ; then
    echo "INFO: Snap file was found, attepting data recovery..."
    
    unzip $SNAP_FILE -d $DATA_DIR
    DATA_GENESIS="$DATA_DIR/genesis.json"

    if [ -f "$DATA_GENESIS" ] ; then
      echo "INFO: Genesis file was found within the snapshoot folder, attempting recovery..."
      rm -fv $COMMON_GENESIS
      cp -v -a $DATA_GENESIS $COMMON_GENESIS # move snapshoot genesis into common folder
    fi

    rm -fv "$SNAP_FILE"
  fi

  rm -fv $LOCAL_GENESIS
  cp -a -v $COMMON_GENESIS $LOCAL_GENESIS # recover genesis from common folder

  touch $EXECUTED_CHECK
fi

sekaid start --home=$SEKAID_HOME --rpc.laddr="tcp://0.0.0.0:26657" --grpc.address="0.0.0.0:9090" --trace
