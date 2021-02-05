#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

CONTAINER_NAME="sentry"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"
SNAP_DESTINATION="$COMMON_PATH/snap.zip"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 5 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 5 ) / 1024 " | bc)m"

set +x
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NODE ID: $SENTRY_NODE_ID"
echo "|   NETWORK: $KIRA_SENTRY_NETWORK"
echo "|  HOSTNAME: $KIRA_SENTRY_DNS"
echo "| SNAPSHOOT: $KIRA_SNAP_PATH"
echo "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echo "|   MAX RAM: $RAM_RESERVED"
echo "------------------------------------------------"

echo "INFO: Loading secrets..."
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -x
set -e

echo "INFO: Setting up $CONTAINER_NAME config vars..."
# * Config sentry/configs/config.toml

VALIDATOR_SEED=$(echo "${VALIDATOR_NODE_ID}@validator:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
PRIV_SENTRY_SEED=$(echo "${PRIV_SENTRY_NODE_ID}@priv_sentry:$KIRA_PRIV_SENTRY_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
CFG_seeds="tcp://$PRIV_SENTRY_SEED,tcp://$VALIDATOR_SEED"
CFG_persistent_peers=""

mkdir -p "$COMMON_LOGS"
cp -a -v -f $KIRA_SECRETS/sentry_node_key.json $COMMON_PATH/node_key.json

rm -fv $SNAP_DESTINATION
if [ -f "$KIRA_SNAP_PATH" ] ; then
    echo "INFO: State snapshoot was found, cloning..."
    cp -a -v -f $KIRA_SNAP_PATH $SNAP_DESTINATION
fi

COMMON_PEERS_PATH="$COMMON_PATH/peers"
COMMON_SEEDS_PATH="$COMMON_PATH/seeds"
PEERS_PATH="$KIRA_CONFIGS/public_peers"
SEEDS_PATH="$KIRA_CONFIGS/public_seeds"
touch "$PEERS_PATH" "$SEEDS_PATH"

cp -a -v -f "$PEERS_PATH" "$COMMON_PEERS_PATH"
cp -a -v -f "$SEEDS_PATH" "$COMMON_SEEDS_PATH"

# cleanup
rm -f -v "$COMMON_LOGS/start.log" "$COMMON_PATH/executed" "$HALT_FILE"

if [ "${EXTERNAL_SYNC,,}" == "true" ] ; then 
    echoInfo "INFO: Synchronisation using external genesis file ($LOCAL_GENESIS_PATH) will be performed"
    cp -f -a -v "$KIRA_CONFIGS/genesis.json" "$COMMON_PATH/genesis.json"
fi

echo "INFO: Starting sentry node..."

docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_SENTRY_P2P_PORT:$DEFAULT_P2P_PORT \
    -p $KIRA_SENTRY_RPC_PORT:$DEFAULT_RPC_PORT \
    -p $KIRA_SENTRY_GRPC_PORT:$DEFAULT_GRPC_PORT \
    --hostname $KIRA_SENTRY_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_SENTRY_NETWORK \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e CFG_moniker="KIRA ${CONTAINER_NAME^^} NODE" \
    -e CFG_pex="true" \
    -e CFG_grpc_laddr="tcp://0.0.0.0:$DEFAULT_GRPC_PORT" \
    -e CFG_rpc_laddr="tcp://0.0.0.0:$DEFAULT_RPC_PORT" \
    -e CFG_p2p_laddr="tcp://0.0.0.0:$DEFAULT_P2P_PORT" \
    -e CFG_seeds="$CFG_seeds" \
    -e CFG_persistent_peers="$CFG_persistent_peers" \
    -e CFG_private_peer_ids="$VALIDATOR_NODE_ID,$SNAPSHOOT_NODE_ID,$SENTRY_NODE_ID,$PRIV_SENTRY_NODE_ID" \
    -e CFG_unconditional_peer_ids="$VALIDATOR_NODE_ID,$SNAPSHOOT_NODE_ID,$PRIV_SENTRY_NODE_ID" \
    -e CFG_addr_book_strict="false" \
    -e CFG_seed_mode="false" \
    -e CFG_version="v2" \
    -e CFG_cors_allowed_origins="*" \
    -e CFG_max_num_outbound_peers="100" \
    -e CFG_max_num_inbound_peers="10" \
    -e NODE_TYPE=$CONTAINER_NAME \
    -e EXTERNAL_SYNC="$EXTERNAL_SYNC" \
    -e VALIDATOR_MIN_HEIGHT="$VALIDATOR_MIN_HEIGHT" \
    -v $COMMON_PATH:/common \
    -v $KIRA_SNAP:/snap \
    kira:latest

docker network connect $KIRA_VALIDATOR_NETWORK $CONTAINER_NAME

echo "INFO: Waiting for $CONTAINER_NAME to start..."
$KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$SENTRY_NODE_ID" || exit 1

if [ -z "$GENESIS_SHA256" ] ; then
    GENESIS_SHA256=$(docker exec -i "$CONTAINER_NAME" sha256sum $SEKAID_HOME/config/genesis.json | awk '{ print $1 }' | xargs || echo "")
    CDHelper text lineswap --insert="GENESIS_SHA256=\"$GENESIS_SHA256\"" --prefix="GENESIS_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
fi

echoInfo "INFO: Checking genesis SHA256 hash"
TEST_SHA256=$(docker exec -i "$CONTAINER_NAME" sha256sum $SEKAID_HOME/config/genesis.json | awk '{ print $1 }' | xargs || echo "")
if [ ! -z "$TEST_SHA256" ] && [ "$TEST_SHA256" != "$GENESIS_SHA256" ] ; then
    echoErr "ERROR: Expected genesis checksum to be '$GENESIS_SHA256' but got '$TEST_SHA256'"
    exit 1
else
    echoInfo "INFO: Genesis checksum '$TEST_SHA256' was verified sucessfully!"
fi

$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_SENTRY_NETWORK"
$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_VALIDATOR_NETWORK"
