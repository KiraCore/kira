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

while ! ping -c1 validator &>/dev/null ; do
    echo "INFO: Waiting for ping response form validator node... (`date`)"
    sleep 5
done
echo "INFO: Validator IP Found: $(getent hosts validator | awk '{ print $1 }')"

while [ ! -f "$COMMON_DIR/genesis.json" ] ; do
  echo "INFO: Waiting for genesis file to be provisioned... (`date`)"
  sleep 5
done

echo "INFO: Sucess, genesis file was found!"

if [ ! -f "$EXECUTED_CHECK" ]; then
  rm -rfv $SEKAID_HOME
  mkdir -p $SEKAID_HOME/config/

  cp $COMMON_DIR/genesis.json $SEKAID_HOME/config/
  cp $COMMON_DIR/node_key.json $SEKAID_HOME/config/
  cp $COMMON_DIR/config.toml $SEKAID_HOME/config/

  # sekaid init --chain-id=testing testing --home=$SEKAID_HOME

  touch $EXECUTED_CHECK
fi

sekaid start --home=$SEKAID_HOME --rpc.laddr="tcp://0.0.0.0:26657" --trace
