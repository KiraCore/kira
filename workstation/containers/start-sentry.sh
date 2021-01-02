#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

echo "INFO: Loading secrets..."
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
cp -a $SENT_NODE_KEY_PATH $DOCKER_COMMON/sentry/node_key.json
set -e


CONTAINER_NAME="sentry"
DNS1=$KIRA_SENTRY_DNS
DNS2="${CONTAINER_NAME,,}${KIRA_VALIDATOR_NETWORK,,}.local"
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NODE ID: $SENTRY_NODE_ID"
echo "|   NETWORK: $KIRA_SENTRY_NETWORK"
echo "|  HOSTNAME: $DNS1"
echo "------------------------------------------------"
set -x

VALIDATOR_SEED=$(echo "${VALIDATOR_NODE_ID}@validator:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

echo "INFO: Setting up validator config files..."
# * Config sentry/configs/config.toml

CDHelper text lineswap --insert="pex = true" --prefix="pex =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="persistent_peers = \"tcp://$VALIDATOR_SEED\"" --prefix="persistent_peers =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="private_peer_ids = \"$VALIDATOR_NODE_ID\"" --prefix="private_peer_ids =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="unconditional_peer_ids = \"$VALIDATOR_NODE_ID\"" --prefix="unconditional_peer_ids =" --path=$DOCKER_COMMON/validator
CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="version = \"v2\"" --prefix="version =" --path=$DOCKER_COMMON/validator # fastsync
CDHelper text lineswap --insert="seed_mode = \"true\"" --prefix="seed_mode =" --path=$DOCKER_COMMON/validator # pex must be true
CDHelper text lineswap --insert="cors_allowed_origins = [ \"*\" ]" --prefix="cors_allowed_origins =" --path=$DOCKER_COMMON/validator 

echo "INFO: Starting sentry node..."

docker run -d \
    -p $DEFAULT_P2P_PORT:$KIRA_SENTRY_P2P_PORT \
    -p $DEFAULT_RPC_PORT:$KIRA_SENTRY_RPC_PORT \
    -p $DEFAULT_GRPC_PORT:$KIRA_SENTRY_GRPC_PORT \
    --hostname $DNS1 \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_SENTRY_NETWORK \
    -e DEBUG_MODE="True" \
    -v $DOCKER_COMMON/sentry:/common \
    sentry:latest

docker network connect $KIRA_VALIDATOR_NETWORK $CONTAINER_NAME

echo "INFO: Waiting for sentry to start..."
$KIRAMGR_SCRIPTS/await-sentry-init.sh "$SENTRY_NODE_ID" || exit 1

ID=$(docker inspect --format="{{.Id}}" $CONTAINER_NAME || echo "")
IP=$(docker inspect $ID | jq -r ".[0].NetworkSettings.Networks.$KIRA_SENTRY_NETWORK.IPAddress" | xargs || echo "")
IP2=$(docker inspect $ID| jq -r ".[0].NetworkSettings.Networks.$KIRA_VALIDATOR_NETWORK.IPAddress" | xargs || echo "")

if [ -z "$IP" ] || [ "${IP,,}" == "null" ] || [ -z "$IP2" ] || [ "${IP2,,}" == "null" ] ; then
    echo "ERROR: Failed to get IP address of the $CONTAINER_NAME container"
    exit 1
fi

echo "INFO: IP Address found, binding host..."
CDHelper text lineswap --insert="$IP $DNS1" --regex="$DNS1" --path=$HOSTS_PATH --prepend-if-found-not=True
CDHelper text lineswap --insert="$IP $DNS2" --regex="$DNS2" --path=$HOSTS_PATH --prepend-if-found-not=True
