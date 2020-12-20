#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring sentry..."
SEKAID_HOME=$HOME/.simapp

EXECUTED_CHECK="/root/executed"

if [ -f "$EXECUTED_CHECK" ]; then
  sekaid start --home=$SEKAID_HOME --rpc.laddr="tcp://0.0.0.0:26657"
else
  rm -rf $SEKAID_HOME

  sekaid init --chain-id=testing testing --home=$SEKAID_HOME
  cp $COMMON_DIR/genesis.json $SEKAID_HOME/config/genesis.json
  cp $COMMON_DIR/node_key.json $SEKAID_HOME/config/node_key.json
  cp $COMMON_DIR/config.toml $SEKAID_HOME/config/config.toml

  touch $EXECUTED_CHECK
  sekaid start --home=$SEKAID_HOME --rpc.laddr="tcp://0.0.0.0:26657"
fi
