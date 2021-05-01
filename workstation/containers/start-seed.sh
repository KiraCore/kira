#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/containers/start-seed.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

CONTAINER_NAME="seed"
CONTAINER_NETWORK="$KIRA_SENTRY_NETWORK"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"
EXIT_FILE="$COMMON_PATH/exit"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 6 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 6 ) / 1024 " | bc)m"

set +x
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NODE ID: $SEED_NODE_ID"
echo "|   NETWORK: $CONTAINER_NETWORK"
echo "|  HOSTNAME: $KIRA_SEED_DNS"
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

mkdir -p "$COMMON_LOGS"
cp -a -v -f $KIRA_SECRETS/seed_node_key.json $COMMON_PATH/node_key.json

# cleanup
rm -f -v "$COMMON_LOGS/start.log" "$COMMON_PATH/executed" "$HALT_FILE" "$EXIT_FILE"

if (! $($KIRA_SCRIPTS/container-healthy.sh "$CONTAINER_NAME")) ; then
    SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
    PRIV_SENTRY_SEED=$(echo "${PRIV_SENTRY_NODE_ID}@priv_sentry:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
    SNAPSHOT_SEED=$(echo "${SNAPSHOT_NODE_ID}@seed:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

    CFG_persistent_peers="tcp://$SENTRY_SEED,tcp://$PRIV_SENTRY_SEED,tcp://$SNAPSHOT_SEED"

    echoInfo "INFO: Wiping '$CONTAINER_NAME' resources..."
    $KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

    echoInfo "INFO: Starting '$CONTAINER_NAME' container..."
docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_SEED_P2P_PORT:$DEFAULT_P2P_PORT \
    -p $KIRA_SEED_RPC_PORT:$DEFAULT_RPC_PORT \
    --hostname $KIRA_SEED_DNS \
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
    -e CFG_external_address="" \
    -e CFG_seeds="" \
    -e CFG_persistent_peers="$CFG_persistent_peers" \
    -e CFG_private_peer_ids="" \
    -e CFG_unconditional_peer_ids="$VALIDATOR_NODE_ID,$SNAPSHOT_NODE_ID,$PRIV_SENTRY_NODE_ID,$SENTRY_NODE_ID" \
    -e CFG_addr_book_strict="true" \
    -e CFG_seed_mode="true" \
    -e CFG_allow_duplicate_ip="false" \
    -e CFG_max_num_outbound_peers="128" \
    -e CFG_max_num_inbound_peers="128" \
    -e CFG_handshake_timeout="30s" \
    -e CFG_dial_timeout="15s" \
    -e CFG_max_txs_bytes="131072000" \
    -e CFG_max_tx_bytes="131072" \
    -e CFG_send_rate="65536000" \
    -e CFG_recv_rate="65536000" \
    -e CFG_max_packet_msg_payload_size="131072" \
    -e NODE_TYPE=$CONTAINER_NAME \
    -e NODE_ID="$SEED_NODE_ID" \
    -e EXTERNAL_P2P_PORT="$KIRA_SEED_P2P_PORT" \
    -e INTERNAL_P2P_PORT="$DEFAULT_P2P_PORT" \
    -e INTERNAL_RPC_PORT="$DEFAULT_RPC_PORT" \
    -e EXTERNAL_SYNC="$EXTERNAL_SYNC" \
    -e KIRA_SETUP_VER="$KIRA_SETUP_VER" \
    --env-file "$KIRA_MANAGER/containers/sekaid.env" \
    -v $COMMON_PATH:/common \
    -v $KIRA_SNAP:/snap \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    kira:latest
else
    echoInfo "INFO: Container $CONTAINER_NAME is healthy, restarting..."
    $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart"
fi

echo "INFO: Waiting for $CONTAINER_NAME to start..."
$KIRAMGR_SCRIPTS/await-seed-init.sh "$CONTAINER_NAME" "$SEED_NODE_ID" || exit 1

echoInfo "INFO: Checking genesis SHA256 hash"
GENESIS_SHA256=$(sha256sum "$LOCAL_GENESIS_PATH" | awk '{ print $1 }' | xargs || echo -n "")
TEST_SHA256=$(docker exec -i "$CONTAINER_NAME" sha256sum $SEKAID_HOME/config/genesis.json | awk '{ print $1 }' | xargs || echo -n "")
if [ -z "$TEST_SHA256" ] || [ "$TEST_SHA256" != "$GENESIS_SHA256" ] ; then
    echoErr "ERROR: Expected genesis checksum to be '$GENESIS_SHA256' but got '$TEST_SHA256'"
    exit 1
else
    echoInfo "INFO: Genesis checksum '$TEST_SHA256' was verified sucessfully!"
fi

# $KIRAMGR_SCRIPTS/restart-networks.sh "true" "$CONTAINER_NETWORK"

# $KIRA_MANAGER/scripts/update-ifaces.sh