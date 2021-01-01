#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

echo "INFO: Loading secrets..."
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
cp -a $SENT_NODE_KEY_PATH $DOCKER_COMMON/sentry/node_key.json
set -e

NETWORK="sentrynet"
echo "------------------------------------------------"
echo "| STARTING SENTRY NODE"
echo "|-----------------------------------------------"
echo "|        IP: $KIRA_SENTRY_IP"
echo "|   NODE ID: $SENTRY_NODE_ID"
echo "|   NETWORK: $NETWORK"
echo "|  HOSTNAME: $KIRA_SENTRY_DNS"
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
    --hostname $KIRA_SENTRY_DNS \
    --restart=always \
    --name sentry \
    --net=$NETWORK \
    --ip $KIRA_SENTRY_IP \
    -e DEBUG_MODE="True" \
    -v $DOCKER_COMMON/sentry:/common \
    sentry:latest

docker network connect kiranet sentry

echo "INFO: Waiting for sentry to start..."
$KIRAMGR_SCRIPTS/await-sentry-init.sh "$SENTRY_NODE_ID" || exit 1