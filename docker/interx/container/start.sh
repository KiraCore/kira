#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
exec 2>&1
set -x

echoInfo "Staring INTERX..."
cd $SEKAI/INTERX

EXECUTED_CHECK="$COMMON_DIR/executed"
HALT_CHECK="${COMMON_DIR}/halt"
CONFIG_PATH="$SEKAI/INTERX/config.json"
CACHE_DIR="$COMMON_DIR/cache"

while [ -f "$HALT_CHECK" ]; do
    sleep 30
done

while ! ping -c1 sentry &>/dev/null; do
    echoInfo "INFO: Waiting for ping response form sentry node... ($(date))"
    sleep 5
done

if [ ! -f "$EXECUTED_CHECK" ]; then
    mkdir -p $CACHE_DIR

    rm -f $CONFIG_PATH
    interxd init --cache_dir="$CACHE_DIR" --config="$CONFIG_PATH" --grpc="$CFG_grpc" --rpc="$CFG_rpc" --port="$CFG_port" \
      --signing_mnemonic="$COMMON_DIR/signing.mnemonic" --faucet_mnemonic="$COMMON_DIR/faucet.mnemonic" \
      --faucet_time_limit=30 \
      --faucet_amounts="100000ukex,20000000test,300000000000000000samolean,1lol" \
      --faucet_minimum_amounts="1000ukex,50000test,250000000000000samolean,1lol" \
      --fee_amounts="ukex 1000ukex,test 500ukex,samolean 250ukex, lol 100ukex"

  touch $EXECUTED_CHECK
fi

interxd start --config="$CONFIG_PATH"
