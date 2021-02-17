#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
exec 2>&1
set -x

echo "Staring INTERX..."
cd $SEKAI/INTERX

EXECUTED_CHECK="$COMMON_DIR/executed"
HALT_CHECK="${COMMON_DIR}/halt"
CONFIG_PATH="$SEKAI/INTERX/config.json"
CACHE_DIR="$COMMON_DIR/cache"

while [ -f "$HALT_CHECK" ]; do
  sleep 30
done

while ! ping -c1 sentry &>/dev/null; do
  echo "INFO: Waiting for ping response form sentry node... ($(date))"
  sleep 5
done

if [ ! -f "$EXECUTED_CHECK" ]; then
  mkdir -p $CACHE_DIR

  rm -f $CONFIG_PATH
  interxd init --cache_dir="$CACHE_DIR" --config="$CONFIG_PATH" --grpc="$CFG_grpc" --rpc="$CFG_rpc" --port="$CFG_port" --signing_mnemonic="$COMMON_DIR/signing.mnemonic" --faucet_mnemonic="$COMMON_DIR/faucet.mnemonic"

  touch $EXECUTED_CHECK
fi

interxd start --config="$CONFIG_PATH"
