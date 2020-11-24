#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring sentry..."
SEKAID_HOME=$HOME/.sekaid

rm -f /root/output.log
touch /root/output.log

sekaid init --chain-id=testing testing --home=$SEKAID_HOME
cp $SELF_CONFIGS/genesis.json $SEKAID_HOME/config/genesis.json
cp $SELF_CONFIGS/config.toml $SEKAID_HOME/config/config.toml
sekaid start --home=$SEKAID_HOME >/root/output.log
