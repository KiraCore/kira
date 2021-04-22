#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

echo "INFO: Loading secrets..."

set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh

CONTAINER_NAME="validator"
CONTAINER_NETWORK="$KIRA_VALIDATOR_NETWORK"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 6 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 6 ) / 1024 " | bc)m"

rm -rfv $COMMON_PATH
mkdir -p "$COMMON_LOGS" "$DOCKER_COMMON/tmp" "$DOCKER_COMMON/sentry" "$DOCKER_COMMON/priv_sentry" "$DOCKER_COMMON/snapshot"

echo "$SIGNER_ADDR_MNEMONIC" > $COMMON_PATH/signer_addr_mnemonic.key
echo "$FAUCET_ADDR_MNEMONIC" > $COMMON_PATH/faucet_addr_mnemonic.key
echo "$VALIDATOR_ADDR_MNEMONIC" > $COMMON_PATH/validator_addr_mnemonic.key
echo "$TEST_ADDR_MNEMONIC" > $COMMON_PATH/test_addr_mnemonic.key
cp -a $KIRA_SECRETS/priv_validator_key.json $COMMON_PATH/priv_validator_key.json
cp -a $KIRA_SECRETS/validator_node_key.json $COMMON_PATH/node_key.json
set -e

echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NETWORK: $CONTAINER_NETWORK"
echo "|   NODE ID: $VALIDATOR_NODE_ID"
echo "|  HOSTNAME: $KIRA_VALIDATOR_DNS"
echo "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echo "|   MAX RAM: $RAM_RESERVED"
echo "------------------------------------------------"
set -x

echoInfo "INFO: Setting up $CONTAINER_NAME config vars..."

GENESIS_SOURCE="$SEKAID_HOME/config/genesis.json"
rm -f -v "$COMMON_LOGS/start.log" "$COMMON_PATH/executed"

if (! $($KIRA_SCRIPTS/container-healthy.sh "$CONTAINER_NAME")) ; then
    SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
    PRIV_SENTRY_SEED=$(echo "${PRIV_SENTRY_NODE_ID}@priv_sentry:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

    if [ "${EXTERNAL_SYNC,,}" == "true" ] ; then 
        CFG_persistent_peers="tcp://$PRIV_SENTRY_SEED,tcp://$SENTRY_SEED"
    else
        CFG_seeds=""
        CFG_persistent_peers=""
    fi

    echoInfo "INFO: Wiping '$CONTAINER_NAME' resources..."
    $KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

    echoInfo "INFO: Starting '$CONTAINER_NAME' container..."
docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_VALIDATOR_RPC_PORT:$DEFAULT_RPC_PORT \
    --hostname "$KIRA_VALIDATOR_DNS" \
    --restart=always \
    --name "$CONTAINER_NAME" \
    --net="$CONTAINER_NETWORK" \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e CFG_moniker="KIRA ${CONTAINER_NAME^^} NODE" \
    -e CFG_grpc_laddr="tcp://0.0.0.0:$DEFAULT_GRPC_PORT" \
    -e CFG_rpc_laddr="tcp://0.0.0.0:$DEFAULT_RPC_PORT" \
    -e CFG_p2p_laddr="tcp://0.0.0.0:$DEFAULT_P2P_PORT" \
    -e CFG_private_peer_ids="$SENTRY_NODE_ID,$PRIV_SENTRY_NODE_ID,$SNAPSHOT_NODE_ID,$SEED_NODE_ID" \
    -e CFG_seeds="$CFG_seeds" \
    -e CFG_persistent_peers="$CFG_persistent_peers" \
    -e CFG_unconditional_peer_ids="$SENTRY_NODE_ID,$PRIV_SENTRY_NODE_ID,$SNAPSHOT_NODE_ID" \
    -e CFG_max_num_outbound_peers="0" \
    -e CFG_max_num_inbound_peers="0" \
    -e CFG_timeout_commit="5s" \
    -e CFG_create_empty_blocks_interval="10s" \
    -e CFG_addr_book_strict="false" \
    -e CFG_seed_mode="false" \
    -e CFG_skip_timeout_commit="false" \
    -e CFG_allow_duplicate_ip="true" \
    -e CFG_handshake_timeout="30s" \
    -e CFG_dial_timeout="15s" \
    -e CFG_send_rate="65536000" \
    -e CFG_recv_rate="65536000" \
    -e CFG_max_packet_msg_payload_size="131072" \
    -e SETUP_VER="$KIRA_SETUP_VER" \
    -e CFG_pex="false" \
    -e NEW_NETWORK="$NEW_NETWORK" \
    -e NODE_TYPE="$CONTAINER_NAME" \
    -e VALIDATOR_MIN_HEIGHT="$VALIDATOR_MIN_HEIGHT" \
    --env-file "$KIRA_MANAGER/containers/sekaid.env" \
    -v $COMMON_PATH:/common \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    kira:latest
else
    echoInfo "INFO: Container $CONTAINER_NAME is healthy, restarting..."
    $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart"
fi

echoInfo "INFO: Waiting for $CONTAINER_NAME to start and import or produce genesis..."
$KIRAMGR_SCRIPTS/await-validator-init.sh "$GENESIS_SOURCE" "$VALIDATOR_NODE_ID" || exit 1

echoInfo "INFO: Checking genesis SHA256 hash"
TEST_SHA256=$(docker exec -i "$CONTAINER_NAME" sha256sum $SEKAID_HOME/config/genesis.json | awk '{ print $1 }' | xargs || echo -n "")
GENESIS_SHA256=$(sha256sum $LOCAL_GENESIS_PATH | awk '{ print $1 }' | xargs || echo -n "")
if [ -z "$TEST_SHA256" ] || [ "$TEST_SHA256" != "$GENESIS_SHA256" ] ; then
    echoErr "ERROR: Expected genesis checksum to be '$GENESIS_SHA256' but got '$TEST_SHA256'"
    exit 1
else
    echoInfo "INFO: Genesis checksum '$TEST_SHA256' was verified sucessfully!"
fi

CDHelper text lineswap --insert="GENESIS_SHA256=\"$GENESIS_SHA256\"" --prefix="GENESIS_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True
$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$CONTAINER_NETWORK"
