#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
START_TIME="$(date -u +%s)"

echo "INFO: Loading secrets..."
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
cp -a $SENT_NODE_KEY_PATH $DOCKER_COMMON/sentry/node_key.json
set -e

CONTAINER_NAME="snapshoot"
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NETWORK: $KIRA_SENTRY_NETWORK"
echo "|  HOSTNAME: $KIRA_SNAPSHOOT_DNS"
echo "------------------------------------------------"
set -x

SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

echo "INFO: Setting up validator config files..."
# * Config sentry/configs/config.toml

CDHelper text lineswap --insert="pex = false" --prefix="pex =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="seed = \"$SENTRY_SEED\"" --prefix="seed =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="persistent_peers = \"tcp://$SENTRY_SEED\"" --prefix="persistent_peers =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="unconditional_peer_ids = \"$SENTRY_NODE_ID\"" --prefix="unconditional_peer_ids =" --path=$DOCKER_COMMON/sentry
# Set true for strict address routability rules & Set false for private or local networks
CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="version = \"v2\"" --prefix="version =" --path=$DOCKER_COMMON/sentry # fastsync
CDHelper text lineswap --insert="seed_mode = \"false\"" --prefix="seed_mode =" --path=$DOCKER_COMMON/sentry # pex must be true
CDHelper text lineswap --insert="cors_allowed_origins = [ \"*\" ]" --prefix="cors_allowed_origins =" --path=$DOCKER_COMMON/sentry 

echo "INFO: Starting sentry node..."

docker run -d \
    -p $DEFAULT_P2P_PORT:$KIRA_SENTRY_P2P_PORT \
    -p $DEFAULT_RPC_PORT:$KIRA_SENTRY_RPC_PORT \
    -p $DEFAULT_GRPC_PORT:$KIRA_SENTRY_GRPC_PORT \
    --hostname $KIRA_SNAPSHOOT_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_SENTRY_NETWORK \
    -e DEBUG_MODE="True" \
    -v $DOCKER_COMMON/sentry:/common \
    sentry:latest

docker network connect $KIRA_VALIDATOR_NETWORK $CONTAINER_NAME

echo "INFO: Waiting for $CONTAINER_NAME node to start..."

CONTAINER_CREATED="true" && $KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$SENTRY_NODE_ID" || CONTAINER_CREATED="false"

# TODO: remove conatainer if creation failed

$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_SENTRY_NETWORK"
$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_VALIDATOR_NETWORK"

echo "INFO: Success, snapshoot was created, elapsed $(($(date -u +%s) - $START_TIME_LAUNCH)) seconds"



