#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

CONTAINER_NAME="priv-sentry"
SNAP_DESTINATION="$DOCKER_COMMON/$CONTAINER_NAME/snap.zip"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"

set +x
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NODE ID: $SENTRY_NODE_ID"
echo "|   NETWORK: $KIRA_SENTRY_NETWORK"
echo "|  HOSTNAME: $KIRA_PRIV_SENTRY_DNS"
echo "| SNAPSHOOT: $KIRA_SNAP_PATH"
echo "------------------------------------------------"

echo "INFO: Loading secrets..."
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -x
set -e

cp -a -v $KIRA_SECRETS/priv_sentry_node_key.json $COMMON_PATH/node_key.json

rm -fv $SNAP_DESTINATION
if [ -f "$KIRA_SNAP_PATH" ] ; then
    echo "INFO: State snapshoot was found, cloning..."
    cp -a -v $KIRA_SNAP_PATH $SNAP_DESTINATION
fi

VALIDATOR_SEED=$(echo "${VALIDATOR_NODE_ID}@validator:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

echo "INFO: Setting up validator config files..."
# * Config sentry/configs/config.toml

CDHelper text lineswap --insert="moniker = \"KIRA ${CONTAINER_NAME} NODE\"" --prefix="moniker =" --path=$COMMON_PATH
CDHelper text lineswap --insert="pex = false" --prefix="pex =" --path=$COMMON_PATH
CDHelper text lineswap --insert="persistent_peers = \"tcp://$VALIDATOR_SEED\"" --prefix="persistent_peers =" --path=$COMMON_PATH
CDHelper text lineswap --insert="private_peer_ids = \"$VALIDATOR_NODE_ID,$SNAPSHOOT_NODE_ID,$SENTRYT_NODE_ID,$PRIV_SENTRYT_NODE_ID\"" --prefix="private_peer_ids =" --path=$COMMON_PATH
CDHelper text lineswap --insert="unconditional_peer_ids = \"$VALIDATOR_NODE_ID\"" --prefix="unconditional_peer_ids =" --path=$COMMON_PATH
# Set true for strict address routability rules & Set false for private or local networks
CDHelper text lineswap --insert="addr_book_strict = true" --prefix="addr_book_strict =" --path=$COMMON_PATH
CDHelper text lineswap --insert="version = \"v2\"" --prefix="version =" --path=$COMMON_PATH # fastsync
CDHelper text lineswap --insert="seed_mode = \"false\"" --prefix="seed_mode =" --path=$COMMON_PATH # pex must be true

echo "INFO: Starting sentry node..."

docker run -d \
    -p $DEFAULT_P2P_PORT:$KIRA_PRIV_SENTRY_P2P_PORT \
    --hostname $KIRA_PRIV_SENTRY_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_SENTRY_NETWORK \
    -e DEBUG_MODE="True" \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -v $COMMON_PATH:/common \
    $CONTAINER_NAME:latest

docker network connect $KIRA_VALIDATOR_NETWORK $CONTAINER_NAME

echo "INFO: Waiting for sentry to start..."
$KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$SENTRY_NODE_ID" || exit 1

$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_SENTRY_NETWORK"
$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_VALIDATOR_NETWORK"
