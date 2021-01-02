#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

echo "INFO: Loading secrets..."
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
rm -f "./config.tmp"
jq --arg signer "${SIGNER_MNEMONIC}" '.mnemonic = $signer' $DOCKER_COMMON/interx/config.json >"./config.tmp" && mv "./config.tmp" $DOCKER_COMMON/interx/config.json
jq --arg faucet "${FAUCET_MNEMONIC}" '.faucet.mnemonic = $faucet' $DOCKER_COMMON/interx/config.json >"./config.tmp" && mv "./config.tmp" $DOCKER_COMMON/interx/config.json
rm -f "./config.tmp"
set -e

CONTAINER_NAME="interx"
DNS1=$KIRA_INTERX_DNS
DNS2="${CONTAINER_NAME,,}${KIRA_SENTRY_NETWORK,,}.local"
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NODE ID: $SENTRY_NODE_ID"
echo "|   NETWORK: $KIRA_INTERX_NETWORK"
echo "|  HOSTNAME: $DNS1"
echo "------------------------------------------------"
set -x

docker run -d \
    -p $DEFAULT_INTERX_PORT:$KIRA_INTERX_PORT \
    --hostname $DNS1 \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_INTERX_NETWORK \
    -e DEBUG_MODE="True" \
    -v $DOCKER_COMMON/interx:/common \
    interx:latest

docker network connect $KIRA_SENTRY_NETWORK $CONTAINER_NAME

echo "INFO: Waiting for interx to start..."
$KIRAMGR_SCRIPTS/await-interx-init.sh || exit 1

ID=$(docker inspect --format="{{.Id}}" $CONTAINER_NAME || echo "")
IP=$(docker inspect $ID | jq -r ".[0].NetworkSettings.Networks.$KIRA_INTERX_NETWORK.IPAddress" | xargs || echo "")
IP2=$(docker inspect $ID| jq -r ".[0].NetworkSettings.Networks.$KIRA_SENTRY_NETWORK.IPAddress" | xargs || echo "")

if [ -z "$IP" ] || [ "${IP,,}" == "null" ] || [ -z "$IP2" ] || [ "${IP2,,}" == "null" ] ; then
    echo "ERROR: Failed to get IP address of the $CONTAINER_NAME container"
    exit 1
fi

echo "INFO: IP Address found, binding host..."
CDHelper text lineswap --insert="$IP $DNS1" --regex="$DNS1" --path=$HOSTS_PATH --prepend-if-found-not=True
CDHelper text lineswap --insert="$IP $DNS2" --regex="$DNS2" --path=$HOSTS_PATH --prepend-if-found-not=True


#FAUCET_ADDR=$(curl http://interx.servicenet.local:11000/api/faucet | jq -r '.address')
#yes "y" | docker exec -i "validator" sekaid tx bank send validator $FAUCET_ADDR 200000ukex --keyring-backend=test --chain-id testing --home=/root/.simapp --fees 2000ukex
