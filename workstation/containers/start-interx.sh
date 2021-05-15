#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
[ "${DEPLOYMENT_MODE,,}" == "minimal" ] && UTIL_DIV=4 || UTIL_DIV=6
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / $UTIL_DIV )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / $UTIL_DIV ) / 1024 " | bc)m"

CONTAINER_NAME="interx"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_GLOBAL_PATH="$DOCKER_COMMON/global"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING $CONTAINER_NAME NODE"
echoWarn "|-----------------------------------------------"
echoWarn "|   NODE ID: $SENTRY_NODE_ID"
echoWarn "|  HOSTNAME: $KIRA_INTERX_DNS"
echoWarn "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echoWarn "|   MAX RAM: $RAM_RESERVED"
echoWarn "------------------------------------------------"
set -x

if (! $($KIRA_SCRIPTS/container-healthy.sh "$CONTAINER_NAME")) ; then
    echoInfo "INFO: Wiping '$CONTAINER_NAME' resources and setting up config vars for the $DEPLOYMENT_MODE deployment mode..."
    $KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

    chattr -iR $COMMON_PATH || echoWarn "WARNING: Failed to remove integrity protection from $COMMON_PATH"
    rm -rfv "$COMMON_PATH"
    mkdir -p "$COMMON_LOGS"

    echoInfo "INFO: Loading secrets..."
    set +x
    set +e
    source $KIRAMGR_SCRIPTS/load-secrets.sh
    echo "$SIGNER_ADDR_MNEMONIC" > "$COMMON_PATH/signing.mnemonic"
    echo "$FAUCET_ADDR_MNEMONIC" > "$COMMON_PATH/faucet.mnemonic"
    set -e
    set -x

    if [ "${DEPLOYMENT_MODE,,}" == "full" ] ; then    
        CFG_grpc="dns:///sentry:$DEFAULT_GRPC_PORT"
        CFG_rpc="http://sentry:$DEFAULT_RPC_PORT"
        CONTAINER_NETWORK="$KIRA_INTERX_NETWORK"
    else
        if [ "${INFRA_MODE,,}" == "validator" ] ; then
            CFG_grpc="dns:///validator:$DEFAULT_GRPC_PORT"
            CFG_rpc="http://validator:$DEFAULT_RPC_PORT"
            CONTAINER_NETWORK="$KIRA_VALIDATOR_NETWORK"
        fi
    fi

    echoInfo "INFO: Starting '$CONTAINER_NAME' container..."
docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_INTERX_PORT:$DEFAULT_INTERX_PORT \
    --hostname $KIRA_INTERX_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$CONTAINER_NETWORK \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e CFG_grpc="$CFG_grpc" \
    -e CFG_rpc="$CFG_rpc" \
    -e CFG_port="$DEFAULT_INTERX_PORT" \
    -e INFRA_MODE="$INFRA_MODE" \
    -e DEPLOYMENT_MODE="$DEPLOYMENT_MODE" \
    -e KIRA_SETUP_VER="$KIRA_SETUP_VER" \
    -v $COMMON_PATH:/common \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    $CONTAINER_NAME:latest
else
    echoInfo "INFO: Container $CONTAINER_NAME is healthy, restarting..."
    $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart"
fi

echoInfo "INFO: Waiting for interx to start..."
$KIRAMGR_SCRIPTS/await-interx-init.sh || exit 1

if [ "${INFRA_MODE,,}" == "local" ] ; then
    while : ; do
        FAUCET_ADDR=$(curl --fail 0.0.0.0:$KIRA_INTERX_PORT/api/faucet 2>/dev/null | jsonQuickParse "address" || echo -n "")
        echoInfo "INFO: Demo mode detected, attempting to transfer funds into INTERX account..."
        FAILED="false" && docker exec -i validator sekaid tx bank send validator $FAUCET_ADDR 100000000ukex --gas=1000000000 --keyring-backend=test --chain-id "$NETWORK_NAME" --home=$SEKAID_HOME --fees 100ukex --yes || FAILED="true"
        [ "${FAILED,,}" == "false" ] && echoInfo "INFO: Success, funds were sent to faucet account ($FAUCET_ADDR)" && break
        echoWarn "WARNING: Failed to transfer funds into INTERX faucet account, retry in 10 seconds"
        sleep 10
    done
else
    echoWarn "WARNING: You are running in non-DEMO mode, you will have to fuel INTERX faucet address ($FAUCET_ADDR) on your own!"
fi

systemctl restart kiraclean
