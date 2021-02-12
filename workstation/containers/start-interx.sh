#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 5 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 5 ) / 1024 " | bc)m"

CONTAINER_NAME="interx"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
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
echo "|   NETWORK: $KIRA_INTERX_NETWORK"
echo "|  HOSTNAME: $KIRA_INTERX_DNS"
echo "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echo "|   MAX RAM: $RAM_RESERVED"
echo "------------------------------------------------"
set -x

# cleanup
rm -f -v "$COMMON_LOGS/start.log" "$COMMON_PATH/executed" "$HALT_FILE"

docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_INTERX_PORT:$DEFAULT_INTERX_PORT \
    --hostname $KIRA_INTERX_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_INTERX_NETWORK \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e CFG_grpc="dns:///sentry:9090" \
    -e CFG_rpc="http://sentry:26657" \
    -e CFG_port="$DEFAULT_INTERX_PORT" \
    -v $COMMON_PATH:/common \
    $CONTAINER_NAME:latest

docker network connect $KIRA_SENTRY_NETWORK $CONTAINER_NAME

echo "INFO: Waiting for interx to start..."
$KIRAMGR_SCRIPTS/await-interx-init.sh || exit 1

FAUCET_ADDR=$(docker exec -t "interx" curl 0.0.0.0:$DEFAULT_INTERX_PORT/api/faucet 2>/dev/null | jq -rc '.address' | xargs || echo "")

$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_SENTRY_NETWORK"
$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_INTERX_NETWORK"

if [ "${INFRA_MODE,,}" == "local" ] ; then
    echoInfo "INFO: Demo mode detected, demo funds will be transferred to INTERX account..."
    docker exec -i "validator" sekaid tx bank send validator $FAUCET_ADDR 200000ukex --keyring-backend=test --chain-id "$NETWORK_NAME" --home=$SEKAID_HOME --fees 2000ukex --yes
else
    echoWarn "WARNING: You are running in non-DEMO mode, you will have to fuel INTERX faucet address ($FAUCET_ADDR) on your own!"
fi

