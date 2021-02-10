#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

echo "INFO: Loading secrets..."

set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh

CONTAINER_NAME="validator"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"
SNAP_DESTINATION="$COMMON_PATH/snap.zip"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 5 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 5 ) / 1024 " | bc)m"

rm -rfv $COMMON_PATH
mkdir -p "$COMMON_LOGS" "$DOCKER_COMMON/tmp" "$DOCKER_COMMON/sentry" "$DOCKER_COMMON/priv_sentry" "$DOCKER_COMMON/snapshot"

echo "$SIGNER_ADDR_MNEMONIC" > $COMMON_PATH/signer_addr_mnemonic.key
echo "$FAUCET_ADDR_MNEMONIC" > $COMMON_PATH/faucet_addr_mnemonic.key
echo "$VALIDATOR_ADDR_MNEMONIC" > $COMMON_PATH/validator_addr_mnemonic.key
echo "$FRONTEND_ADDR_MNEMONIC" > $COMMON_PATH/frontend_addr_mnemonic.key
echo "$TEST_ADDR_MNEMONIC" > $COMMON_PATH/test_addr_mnemonic.key
cp -a $KIRA_SECRETS/priv_validator_key.json $COMMON_PATH/priv_validator_key.json
cp -a $KIRA_SECRETS/validator_node_key.json $COMMON_PATH/node_key.json
set -e

echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NETWORK: $KIRA_VALIDATOR_NETWORK"
echo "|   NODE ID: $VALIDATOR_NODE_ID"
echo "|  HOSTNAME: $KIRA_VALIDATOR_DNS"
echo "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echo "|   MAX RAM: $RAM_RESERVED"
echo "------------------------------------------------"
set -x

rm -fv $SNAP_DESTINATION
if [ -f "$KIRA_SNAP_PATH" ] ; then
    echoInfo "INFO: State snapshot '$KIRA_SNAP_PATH' was found, cloning..."
    cp -a -v -f $KIRA_SNAP_PATH $SNAP_DESTINATION
fi

echoInfo "INFO: Setting up $CONTAINER_NAME config vars..."

SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$KIRA_SENTRY_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
PRIV_SENTRY_SEED=$(echo "${PRIV_SENTRY_NODE_ID}@priv_sentry:$KIRA_PRIV_SENTRY_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

GENESIS_SOURCE="$SEKAID_HOME/config/genesis.json"
GENESIS_DESTINATION="$DOCKER_COMMON/tmp/genesis.json"

rm -f -v "$COMMON_LOGS/start.log" "$COMMON_PATH/executed"

if [ "${EXTERNAL_SYNC,,}" == "true" ] ; then 
    echoInfo "INFO: Synchronisation using external genesis file ($LOCAL_GENESIS_PATH) will be performed"
    rm -fv "$COMMON_PATH/genesis.json"
    cp -f -a -v "$KIRA_CONFIGS/genesis.json" "$COMMON_PATH/genesis.json"
    CFG_persistent_peers="tcp://$SENTRY_SEED,tcp://$PRIV_SENTRY_SEED"
else
    echoInfo "INFO: Synchronisation using internal genesis file ($GENESIS_DESTINATION) will be performed"
    rm -fv $GENESIS_DESTINATION "$COMMON_PATH/genesis.json" "$DOCKER_COMMON/sentry/genesis.json" "$DOCKER_COMMON/priv_sentry/genesis.json" "$DOCKER_COMMON/snapshot/genesis.json"
    CFG_persistent_peers=""
fi

echoInfo "INFO: Starting $CONTAINER_NAME node..."

docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    --hostname "$KIRA_VALIDATOR_DNS" \
    --restart=always \
    --name "$CONTAINER_NAME" \
    --net="$KIRA_VALIDATOR_NETWORK" \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e CFG_moniker="KIRA ${CONTAINER_NAME^^} NODE" \
    -e CFG_grpc_laddr="tcp://127.0.0.1:$DEFAULT_GRPC_PORT" \
    -e CFG_rpc_laddr="tcp://127.0.0.1:$DEFAULT_RPC_PORT" \
    -e CFG_p2p_laddr="tcp://0.0.0.0:$DEFAULT_P2P_PORT" \
    -e CFG_private_peer_ids="$SENTRY_NODE_ID,$PRIV_SENTRY_NODE_ID,$SNAPSHOT_NODE_ID" \
    -e CFG_persistent_peers="$CFG_persistent_peers" \
    -e CFG_unconditional_peer_ids="$SENTRY_NODE_ID,$PRIV_SENTRY_NODE_ID,$SNAPSHOT_NODE_ID" \
    -e CFG_max_num_outbound_peers="0" \
    -e CFG_max_num_inbound_peers="3" \
    -e CFG_addr_book_strict="false" \
    -e CFG_seed_mode="false" \
    -e CFG_pex="false" \
    -e CFG_version="v2" \
    -e EXTERNAL_SYNC="$EXTERNAL_SYNC" \
    -e NODE_TYPE="$CONTAINER_NAME" \
    -e VALIDATOR_MIN_HEIGHT="$VALIDATOR_MIN_HEIGHT" \
    -v $COMMON_PATH:/common \
    kira:latest

echoInfo "INFO: Waiting for $CONTAINER_NAME to start and import or produce genesis..."
$KIRAMGR_SCRIPTS/await-validator-init.sh "$DOCKER_COMMON" "$GENESIS_SOURCE" "$GENESIS_DESTINATION" "$VALIDATOR_NODE_ID" || exit 1

if [ "${EXTERNAL_SYNC,,}" != "true" ] ; then 
    echoInfo "INFO: Cloning internal genesis file..."
    cp -f -a -v $GENESIS_DESTINATION "$DOCKER_COMMON/validator/genesis.json"
    cp -f -a -v $GENESIS_DESTINATION "$DOCKER_COMMON/sentry/genesis.json"
    cp -f -a -v $GENESIS_DESTINATION "$DOCKER_COMMON/priv_sentry/genesis.json"
    cp -f -a -v $GENESIS_DESTINATION "$DOCKER_COMMON/snapshot/genesis.json"
    cp -f -a -v $GENESIS_DESTINATION "$KIRA_CONFIGS/genesis.json"

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

$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_VALIDATOR_NETWORK"
