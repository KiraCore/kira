#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 6 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 6 ) / 1024 " | bc)m"

CONTAINER_NAME="interx"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_GLOBAL_PATH="$DOCKER_COMMON/global"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"

mkdir -p $COMMON_LOGS

echo "INFO: Loading secrets..."
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
echo "$SIGNER_ADDR_MNEMONIC" > "$DOCKER_COMMON/interx/signing.mnemonic"
echo "$FAUCET_ADDR_MNEMONIC" > "$DOCKER_COMMON/interx/faucet.mnemonic"
set -e

echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NODE ID: $SENTRY_NODE_ID"
echo "|  HOSTNAME: $KIRA_INTERX_DNS"
echo "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echo "|   MAX RAM: $RAM_RESERVED"
echo "------------------------------------------------"
set -x

# cleanup
rm -f -v "$COMMON_LOGS/start.log" "$COMMON_PATH/executed" "$HALT_FILE"

if (! $($KIRA_SCRIPTS/container-healthy.sh "$CONTAINER_NAME")) ; then

    echoInfo "INFO: Wiping '$CONTAINER_NAME' resources and setting up config vars for the $DEPLOYMENT_MODE deployment mode..."
    $KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

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
    -e KIRA_SETUP_VER="$KIRA_SETUP_VER" \
    -v $COMMON_PATH:/common \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    $CONTAINER_NAME:latest
else
    echoInfo "INFO: Container $CONTAINER_NAME is healthy, restarting..."
    $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart"
fi

echo "INFO: Waiting for interx to start..."
$KIRAMGR_SCRIPTS/await-interx-init.sh || exit 1

FAUCET_ADDR=$(curl --fail 0.0.0.0:$KIRA_INTERX_PORT/api/faucet 2>/dev/null | jsonQuickParse "address" || echo -n "")

# $KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_SENTRY_NETWORK"
# $KIRAMGR_SCRIPTS/restart-networks.sh "true" "$CONTAINER_NETWORK"
# $KIRA_MANAGER/scripts/update-ifaces.sh

if [ "${INFRA_MODE,,}" == "local" ] ; then
    while : ; do
        echoInfo "INFO: Demo mode detected, attempting to transfer funds into INTERX account..."
        FAILED="false" && docker exec -i validator sekaid tx bank send validator $FAUCET_ADDR 100000000ukex --gas=1000000000 --keyring-backend=test --chain-id "$NETWORK_NAME" --home=$SEKAID_HOME --fees 100ukex --yes || FAILED="true"
        [ "${FAILED,,}" == "false" ] && echoInfo "INFO: Success, funds were sent to faucet account ($FAUCET_ADDR)" && break
        echoWarn "WARNING: Failed to transfer funds into INTERX faucet account, retry in 10 seconds"
        sleep 10
    done
else
    echoWarn "WARNING: You are running in non-DEMO mode, you will have to fuel INTERX faucet address ($FAUCET_ADDR) on your own!"
fi
