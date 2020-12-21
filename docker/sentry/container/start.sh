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

if [ -f "$EXECUTED_CHECK" ]; then
  sekaid start --home=$SEKAID_HOME --rpc.laddr="tcp://0.0.0.0:26657"
else

  i=0
  while [ ! -f "$COMMON_DIR/genesis.json" ] && [[ ("$i" < 6) ]]; do
    sleep 10
    i=$((i + 1))
  done

  rm -rf $SEKAID_HOME

  sekaid init --chain-id=testing testing --home=$SEKAID_HOME
  rm -f $SEKAID_HOME/config/genesis.json
  rm -f $SEKAID_HOME/config/node_key.json
  rm -f $SEKAID_HOME/config/config.toml
  cp $COMMON_DIR/genesis.json $SEKAID_HOME/config/
  cp $COMMON_DIR/node_key.json $SEKAID_HOME/config/
  cp $COMMON_DIR/config.toml $SEKAID_HOME/config/

  touch $EXECUTED_CHECK
  touch $COMMON_DIR/started
  sekaid start --home=$SEKAID_HOME --rpc.laddr="tcp://0.0.0.0:26657" --trace
fi
