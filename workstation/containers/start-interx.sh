#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 4 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 4 ) / 1024 " | bc)m"

echo "INFO: Loading secrets..."
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
rm -f "./config.tmp"
jq --arg signer "${SIGNER_ADDR_MNEMONIC}" '.mnemonic = $signer' $DOCKER_COMMON/interx/config.json >"./config.tmp" && mv "./config.tmp" $DOCKER_COMMON/interx/config.json
jq --arg faucet "${FAUCET_ADDR_MNEMONIC}" '.faucet.mnemonic = $faucet' $DOCKER_COMMON/interx/config.json >"./config.tmp" && mv "./config.tmp" $DOCKER_COMMON/interx/config.json
rm -f "./config.tmp"
set -e

CONTAINER_NAME="interx"
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

COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"

docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_INTERX_PORT:$DEFAULT_INTERX_PORT \
    --hostname $KIRA_INTERX_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_INTERX_NETWORK \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -v $COMMON_PATH:/common \
    $CONTAINER_NAME:latest

docker network connect $KIRA_SENTRY_NETWORK $CONTAINER_NAME

echo "INFO: Waiting for interx to start..."
$KIRAMGR_SCRIPTS/await-interx-init.sh || exit 1

FAUCET_ADDR=$(docker exec -i "interx" curl 0.0.0.0:$DEFAULT_INTERX_PORT/api/faucet 2>/dev/null | jq -r '.address' || echo "")

$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_SENTRY_NETWORK"
$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_INTERX_NETWORK"

docker exec -i "validator" sekaid tx bank send validator $FAUCET_ADDR 200000ukex --keyring-backend=test --chain-id "$NETWORK_NAME" --home=/root/.simapp --fees 2000ukex --yes


