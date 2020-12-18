#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring sentry..."
SEKAID_HOME=$HOME/.simapp
rm -rf $SEKAID_HOME

sekaid init --chain-id=testing testing --home=$SEKAID_HOME
cp $COMMON_DIR/genesis.json $SEKAID_HOME/config/genesis.json
cp $COMMON_DIR/sentry_node_key.json $SEKAID_HOME/config/node_key.json
cp $SELF_CONFIGS/config.toml $SEKAID_HOME/config/config.toml

sekaid start --home=$SEKAID_HOME --rpc.laddr="tcp://0.0.0.0:26657"
