#!/usr/bin/env bash
set +e && source /etc/profile &>/dev/null && set -e
exec 2>&1
set -x

KIRA_SETUP_VER=$(globGet KIRA_SETUP_VER "$GLOBAL_COMMON_RO")

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: KIRA ${NODE_TYPE^^} START SCRIPT $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "| INTERX VERSION: $(interxd version)"
echoWarn "|    BASH SOURCE: ${BASH_SOURCE[0]}"
echoWarn "|    INTERX HOME: $INTERXD_HOME"
echoWarn "------------------------------------------------"
set -x

globSet EXTERNAL_STATUS "offline"

PING_ADDR=$(globGet "$PING_TARGET" $GLOBAL_COMMON_RO)
PING_ADDR_RES=$(resolveDNS "$PING_TARGET")

if [ -z "$PING_ADDR_RES" ] ; then
    echoWarn "WARNING: Could NOT resolve '$PING_TARGET', the DNS will be replaced with address '$PING_ADDR'."
    PING_TARGET=$PING_ADDR
fi

while ! ping -c1 $PING_TARGET &>/dev/null ; do    
    echoInfo "INFO: Waiting for ping response form $PING_TARGET ($PING_ADDR) ... ($(date))"
    sleep 5
done

if [ "$(globGet INIT_DONE)" != "true" ]; then
    CACHE_DIR="$COMMON_DIR/cache"

    rm -rfv $INTERXD_HOME/*
    mkdir -p "$CACHE_DIR" "$INTERXD_HOME"
    grpc="dns:///$PING_TARGET:$DEFAULT_GRPC_PORT"
    rpc="http://$PING_TARGET:$DEFAULT_RPC_PORT"

    interxd init --cache_dir="$CACHE_DIR" --home="$INTERXD_HOME" --grpc="$grpc" --rpc="$rpc" --port="$INTERNAL_API_PORT" \
      --signing_mnemonic="$COMMON_DIR/signing.mnemonic" \
      --node_type="$(globGet INFRA_MODE)" \
      --addrbook="$(globFile KIRA_ADDRBOOK)" \
      --faucet_time_limit=30 \
      --faucet_amounts="100000ukex,20000000test,300000000000000000samolean,1lol" \
      --faucet_minimum_amounts="1000ukex,50000test,250000000000000samolean,1lol" \
      --fee_amounts="ukex 1000ukex,test 500ukex,samolean 250ukex,lol 100ukex"

    globSet INIT_DONE "true" 
    globSet RESTART_COUNTER 0
    globSet START_TIME "$(date -u +%s)"
fi

echoInfo "INFO: Loading configuration..."
$COMMON_DIR/interx/configure.sh

globSet CFG_TASK "false"
globSet RUNTIME_VERSION "$(interxd version)"

echoInfo "INFO: Starting INTERX service..."
kill -9 $(lsof -t -i:11000) || echoWarn "WARNING: Nothing running on port 11000, or failed to kill processes"
EXIT_CODE=0 && interxd start --home="$INTERXD_HOME" || EXIT_CODE="$?"
set +x
echoErr "ERROR: INTERX failed with the exit code $EXIT_CODE"
sleep 3
exit 1