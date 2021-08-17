#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
exec 2>&1
set -x

KIRA_SETUP_VER=$(globGet KIRA_SETUP_VER "$GLOBAL_COMMON_RO")

echoInfo "Staring INTERX $KIRA_SETUP_VER setup..."
cd $SEKAI/INTERX

mkdir -p $GLOB_STORE_DIR

EXECUTED_CHECK="$COMMON_DIR/executed"
HALT_CHECK="${COMMON_DIR}/halt"
EXIT_CHECK="${COMMON_DIR}/exit"
CONFIG_PATH="$SEKAI/INTERX/config.json"
CACHE_DIR="$COMMON_DIR/cache"
CFG_CHECK="${COMMON_DIR}/configuring"

touch $CFG_CHECK

globSet EXTERNAL_STATUS "OFFLINE"

RESTART_COUNTER=$(globGet RESTART_COUNTER)
if ($(isNaturalNumber $RESTART_COUNTER)) ; then
    globSet RESTART_COUNTER "$(($RESTART_COUNTER+1))"
    globSet RESTART_TIME "$(date -u +%s)"
fi

while [ -f "$HALT_CHECK" ] || [ -f "$EXIT_CHECK" ]; do
    if [ -f "$EXIT_CHECK" ]; then
        echoInfo "INFO: Ensuring interxd process is killed"
        touch $HALT_CHECK
        pkill -9 interxd || echoWarn "WARNING: Failed to kill interx"
        rm -fv $EXIT_CHECK
    fi
    echoInfo "INFO: Container halted (`date`)"
    sleep 30
done

while ! ping -c1 $PING_TARGET &>/dev/null ; do
    echoInfo "INFO: Waiting for ping response form $PING_TARGET ... ($(date))"
    sleep 5
done

if [ ! -f "$EXECUTED_CHECK" ]; then
    mkdir -p $CACHE_DIR
    rm -fv $CONFIG_PATH

    CFG_grpc="dns:///$PING_TARGET:$DEFAULT_GRPC_PORT"
    CFG_rpc="http://$PING_TARGET:$DEFAULT_RPC_PORT"

    CDHelper text lineswap --insert="CFG_grpc=$CFG_grpc" --prefix="CFG_grpc=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="CFG_rpc=$CFG_rpc" --prefix="CFG_rpc=" --path=$ETC_PROFILE --append-if-found-not=True
    CDHelper text lineswap --insert="PING_TARGET=$PING_TARGET" --prefix="PING_TARGET=" --path=$ETC_PROFILE --append-if-found-not=True

    seed_node_id=$(globGet seed_node_id)
    sentry_node_id=$(globGet sentry_node_id)
    snapshot_node_id=$(globGet snapshot_node_id)
    validator_node_id=$(globGet validator_node_id)

    interxd init --cache_dir="$CACHE_DIR" --config="$CONFIG_PATH" --grpc="$CFG_grpc" --rpc="$CFG_rpc" --port="$INTERNAL_API_PORT" \
      --signing_mnemonic="$COMMON_DIR/signing.mnemonic" --faucet_mnemonic="$COMMON_DIR/faucet.mnemonic" \
      --seed_node_id="$seed_node_id" \
      --sentry_node_id="$sentry_node_id" \
      --snapshot_node_id="$snapshot_node_id" \
      --validator_node_id="$validator_node_id" \
      --faucet_time_limit=30 \
      --faucet_amounts="100000ukex,20000000test,300000000000000000samolean,1lol" \
      --faucet_minimum_amounts="1000ukex,50000test,250000000000000samolean,1lol" \
      --fee_amounts="ukex 1000ukex,test 500ukex,samolean 250ukex, lol 100ukex" \
      --version="$KIRA_SETUP_VER"

    touch $EXECUTED_CHECK
    globSet RESTART_COUNTER 0
    globSet START_TIME "$(date -u +%s)"
fi

echoInfo "INFO: Starting INTERX service..."
rm -fv $CFG_CHECK
EXIT_CODE=0 && interxd start --config="$CONFIG_PATH" || EXIT_CODE="$?"

echoErr "ERROR: INTERX failed with the exit code $EXIT_CODE"
sleep 3
exit 1

