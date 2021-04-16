#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/containers/start-sentry.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

SAVE_SNAPSHOT=$1
[ -z "$SAVE_SNAPSHOT" ] && SAVE_SNAPSHOT="false"

CONTAINER_NAME="sentry"
CONTAINER_NETWORK="$KIRA_SENTRY_NETWORK"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 6 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 6 ) / 1024 " | bc)m"

set +x
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NODE ID: $SENTRY_NODE_ID"
echo "|   NETWORK: $CONTAINER_NETWORK"
echo "|  HOSTNAME: $KIRA_SENTRY_DNS"
echo "|  SNAPSHOT: $KIRA_SNAP_PATH"
echo "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echo "|   MAX RAM: $RAM_RESERVED"
echo "------------------------------------------------"

echo "INFO: Loading secrets..."
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -x
set -e

echo "INFO: Setting up $CONTAINER_NAME config vars..."
# * Config sentry/configs/config.toml

SEED_SEED=$(echo "${SEED_NODE_ID}@seed:$KIRA_SEED_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
VALIDATOR_SEED=$(echo "${VALIDATOR_NODE_ID}@validator:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
PRIV_SENTRY_SEED=$(echo "${PRIV_SENTRY_NODE_ID}@priv_sentry:$KIRA_PRIV_SENTRY_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

mkdir -p "$COMMON_LOGS"
touch "$PUBLIC_PEERS" "$PUBLIC_SEEDS"
cp -a -v -f $KIRA_SECRETS/sentry_node_key.json $COMMON_PATH/node_key.json
cp -a -v -f "$PUBLIC_PEERS" "$COMMON_PATH/peers"
cp -a -v -f "$PUBLIC_SEEDS" "$COMMON_PATH/seeds"

# cleanup
rm -f -v "$COMMON_LOGS/start.log" "$COMMON_PATH/executed" "$HALT_FILE"

if [ "${EXTERNAL_SYNC,,}" == "true" ] ; then 
    if (! $(isFileEmpty $PRIVATE_SEEDS )) || (! $(isFileEmpty $PRIVATE_PEERS )) ; then
        echo "INFO: Node will sync from the private sentry..."
        CFG_persistent_peers="tcp://$PRIV_SENTRY_SEED"
    else
        echo "INFO: Node will sync blocks from its own seed list..."
        CFG_persistent_peers=""
    fi
else
    CFG_persistent_peers="tcp://$VALIDATOR_SEED"
fi

echoInfo "INFO: Wiping '$CONTAINER_NAME' resources..."
$KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

echoInfo "INFO: Starting '$CONTAINER_NAME' container..."
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
    --net=$CONTAINER_NETWORK \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e CFG_moniker="KIRA ${CONTAINER_NAME^^} NODE" \
    -e CFG_pex="true" \
    -e CFG_grpc_laddr="tcp://0.0.0.0:$DEFAULT_GRPC_PORT" \
    -e CFG_rpc_laddr="tcp://0.0.0.0:$DEFAULT_RPC_PORT" \
    -e CFG_p2p_laddr="tcp://0.0.0.0:$DEFAULT_P2P_PORT" \
    -e CFG_seeds="" \
    -e CFG_persistent_peers="$CFG_persistent_peers" \
    -e CFG_private_peer_ids="$VALIDATOR_NODE_ID,$SNAPSHOT_NODE_ID,$PRIV_SENTRY_NODE_ID" \
    -e CFG_unconditional_peer_ids="$VALIDATOR_NODE_ID,$SNAPSHOT_NODE_ID,$PRIV_SENTRY_NODE_ID,$SEED_NODE_ID" \
    -e CFG_addr_book_strict="false" \
    -e CFG_seed_mode="false" \
    -e CFG_allow_duplicate_ip="true" \
    -e CFG_max_num_outbound_peers="64" \
    -e CFG_max_num_inbound_peers="512" \
    -e NODE_TYPE=$CONTAINER_NAME \
    -e EXTERNAL_SYNC="$EXTERNAL_SYNC" \
    -e EXTERNAL_P2P_PORT="$KIRA_SENTRY_P2P_PORT" \
    -e INTERNAL_P2P_PORT="$DEFAULT_P2P_PORT" \
    --env-file "$KIRA_MANAGER/containers/sekaid.env" \
    -v $COMMON_PATH:/common \
    -v $KIRA_SNAP:/snap \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    kira:latest

docker network connect $KIRA_VALIDATOR_NETWORK $CONTAINER_NAME

echo "INFO: Waiting for $CONTAINER_NAME to start..."
$KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$SENTRY_NODE_ID" "$SAVE_SNAPSHOT" || exit 1

echoInfo "INFO: Checking genesis SHA256 hash"
GENESIS_SHA256=$(sha256sum "$LOCAL_GENESIS_PATH" | awk '{ print $1 }' | xargs || echo -n "")
TEST_SHA256=$(docker exec -i "$CONTAINER_NAME" sha256sum $SEKAID_HOME/config/genesis.json | awk '{ print $1 }' | xargs || echo -n "")
if [ -z "$TEST_SHA256" ] || [ "$TEST_SHA256" != "$GENESIS_SHA256" ] ; then
    echoErr "ERROR: Expected genesis checksum to be '$GENESIS_SHA256' but got '$TEST_SHA256'"
    exit 1
else
    echoInfo "INFO: Genesis checksum '$TEST_SHA256' was verified sucessfully!"
    CDHelper text lineswap --insert="GENESIS_SHA256=\"$GENESIS_SHA256\"" --prefix="GENESIS_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
fi

$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$CONTAINER_NETWORK"
$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_VALIDATOR_NETWORK"
