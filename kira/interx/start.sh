#!/usr/bin/env bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
exec 2>&1
set -x

KIRA_SETUP_VER=$(globGet KIRA_SETUP_VER "$GLOBAL_COMMON_RO")

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: KIRA ${NODE_TYPE^^} START SCRIPT $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "| SEKAI VERSION: $(interx version)"
echoWarn "|   BASH SOURCE: ${BASH_SOURCE[0]}"
echoWarn "|   INTERX HOME: $INTERXD_HOME"
echoWarn "------------------------------------------------"
set -x

KIRA_ADDRBOOK_FILE=$(globFile KIRA_ADDRBOOK)
CACHE_DIR="$COMMON_DIR/cache"

globSet EXTERNAL_STATUS "OFFLINE"

RESTART_COUNTER=$(globGet RESTART_COUNTER)
if ($(isNaturalNumber $RESTART_COUNTER)) ; then
    globSet RESTART_COUNTER "$(($RESTART_COUNTER+1))"
    globSet RESTART_TIME "$(date -u +%s)"
fi

while ! ping -c1 $PING_TARGET &>/dev/null ; do
    echoInfo "INFO: Waiting for ping response form $PING_TARGET ... ($(date))"
    sleep 5
done

if [ "$(globGet INIT_DONE)" != "true" ]; then
    mkdir -p "$CACHE_DIR" "$INTERXD_HOME"

    CFG_grpc="dns:///$PING_TARGET:$DEFAULT_GRPC_PORT"
    CFG_rpc="http://$PING_TARGET:$DEFAULT_RPC_PORT"

    setGlobEnv CFG_grpc "$CFG_grpc"
    setGlobEnv CFG_rpc "$CFG_rpc"
    setGlobEnv PING_TARGET "$PING_TARGET"

    interxd init --cache_dir="$CACHE_DIR" --home="$INTERXD_HOME" --grpc="$CFG_grpc" --rpc="$CFG_rpc" --port="$INTERNAL_API_PORT" \
      --signing_mnemonic="$COMMON_DIR/signing.mnemonic" \
      --node_type="$INFRA_MODE" \
      --seed_node_id="$(globGet seed_node_id)" \
      --sentry_node_id="$(globGet sentry_node_id)" \
      --validator_node_id="$(globGet validator_node_id)" \
      --addrbook="$(globFile KIRA_ADDRBOOK)" \
      --faucet_time_limit=30 \
      --faucet_amounts="100000ukex,20000000test,300000000000000000samolean,1lol" \
      --faucet_minimum_amounts="1000ukex,50000test,250000000000000samolean,1lol" \
      --fee_amounts="ukex 1000ukex,test 500ukex,samolean 250ukex,lol 100ukex"

    globSet INIT_DONE "true" 
    globSet RESTART_COUNTER 0
    globSet START_TIME "$(date -u +%s)"
fi

globSet CFG_TASK "false"
globSet RUNTIME_VERSION "interxd $(interxd version)"

echoInfo "INFO: Starting INTERX service..."
EXIT_CODE=0 && interxd start --home="$INTERXD_HOME" || EXIT_CODE="$?"
set +x
echoErr "ERROR: INTERX failed with the exit code $EXIT_CODE"
sleep 3
exit 1