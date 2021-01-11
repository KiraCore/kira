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

while [ ! -f "$COMMON_DIR/genesis.json" ]; do
  echo "INFO: Waiting for genesis file to be provisioned... ($(date))"
  sleep 5
done

echo "INFO: Sucess, genesis file was found!"

if [ ! -f "$EXECUTED_CHECK" ]; then
  rm -rfv $SEKAID_HOME
  mkdir -p $SEKAID_HOME/config/

  sekaid init --chain-id=testing testing --home=$SEKAID_HOME

  rm -fv $SEKAID_HOME/config/genesis.json
  rm -fv $SEKAID_HOME/config/config.toml

  cp $COMMON_DIR/genesis.json $SEKAID_HOME/config/
  cp $COMMON_DIR/config.toml $SEKAID_HOME/config/

  touch $EXECUTED_CHECK
fi

HEIGHT=$(sekaid status 2>/dev/null | jq -r '.sync_info.latest_block_height' 2>/dev/null | xargs || echo "")

if [ -z "$HEIGHT" ] || [ -z "${HEIGHT##*[!0-9]*}" ]; then # not a number
  HEIGHT=0
fi

if [ "$HALT_HEIGHT" != "$HEIGHT" ] ; then
    echo "INFO: Target height was not reached yet $HEIGHT / $HALT_HEIGHT"
    sekaid start --home=$SEKAID_HOME --rpc.laddr="tcp://0.0.0.0:26657" --grpc.address="0.0.0.0:9090" --halt-height="$HALT_HEIGHT" --trace
fi

HEIGHT=$(sekaid status 2>/dev/null | jq -r '.sync_info.latest_block_height' 2>/dev/null | xargs || echo "")

if [ -z "$HEIGHT" ] || [ -z "${HEIGHT##*[!0-9]*}" ]; then # not a number
  HEIGHT=0
fi

if [ "$HALT_HEIGHT" != "$HEIGHT" ] ; then
    echo "ERROR: Target height $HALT_HEIGHT was not reached ($HEIGHT) but node stopped"
    exit 1
fi

while ; ; do
  echo "INFO: Node was stopped gracefully and is ready for the snapshoot... ($(date))"
  sleep 60
done