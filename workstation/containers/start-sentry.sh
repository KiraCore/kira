#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

CONTAINER_NAME="sentry"
SNAP_DESTINATION="$DOCKER_COMMON/$CONTAINER_NAME/snap.zip"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"

set +x
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NODE ID: $SENTRY_NODE_ID"
echo "|   NETWORK: $KIRA_SENTRY_NETWORK"
echo "|  HOSTNAME: $KIRA_SENTRY_DNS"
echo "| SNAPSHOOT: $KIRA_SNAP_PATH"
echo "------------------------------------------------"

echo "INFO: Loading secrets..."
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -x
set -e

cp -a -v $SENT_NODE_KEY_PATH $COMMON_PATH/node_key.json

rm -fv $SNAP_DESTINATION
if [ -f "$KIRA_SNAP_PATH" ] ; then
    echo "INFO: State snapshoot was found, cloning..."
    cp -a -v $KIRA_SNAP_PATH $SNAP_DESTINATION
fi

VALIDATOR_SEED=$(echo "${VALIDATOR_NODE_ID}@validator:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
SNAPSHOOT_SEED=$(echo "${SNAPSHOOT_NODE_ID}@snapshoot:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

echo "INFO: Setting up validator config files..."
# * Config sentry/configs/config.toml

CDHelper text lineswap --insert="pex = true" --prefix="pex =" --path=$COMMON_PATH
CDHelper text lineswap --insert="persistent_peers = \"tcp://$VALIDATOR_SEED,tcp://$SNAPSHOOT_SEED\"" --prefix="persistent_peers =" --path=$COMMON_PATH
CDHelper text lineswap --insert="private_peer_ids = \"$VALIDATOR_NODE_ID,$SNAPSHOOT_NODE_ID\"" --prefix="private_peer_ids =" --path=$COMMON_PATH
CDHelper text lineswap --insert="unconditional_peer_ids = \"$VALIDATOR_NODE_ID,$SNAPSHOOT_NODE_ID\"" --prefix="unconditional_peer_ids =" --path=$COMMON_PATH
# Set true for strict address routability rules & Set false for private or local networks
CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$COMMON_PATH
CDHelper text lineswap --insert="version = \"v2\"" --prefix="version =" --path=$COMMON_PATH # fastsync
CDHelper text lineswap --insert="seed_mode = \"true\"" --prefix="seed_mode =" --path=$COMMON_PATH # pex must be true
CDHelper text lineswap --insert="cors_allowed_origins = [ \"*\" ]" --prefix="cors_allowed_origins =" --path=$COMMON_PATH

echo "INFO: Starting sentry node..."

docker run -d \
    -p $DEFAULT_P2P_PORT:$KIRA_SENTRY_P2P_PORT \
    -p $DEFAULT_RPC_PORT:$KIRA_SENTRY_RPC_PORT \
    -p $DEFAULT_GRPC_PORT:$KIRA_SENTRY_GRPC_PORT \
    --hostname $KIRA_SENTRY_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_SENTRY_NETWORK \
    -e DEBUG_MODE="True" \
    -v $COMMON_PATH:/common \
    $CONTAINER_NAME:latest

docker network connect $KIRA_VALIDATOR_NETWORK $CONTAINER_NAME

echo "INFO: Waiting for sentry to start..."
$KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$SENTRY_NODE_ID" || exit 1

$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_SENTRY_NETWORK"
$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_VALIDATOR_NETWORK"
