#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

echo "INFO: Loading secrets..."

set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh

CONTAINER_NAME="validator"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
SNAP_DESTINATION="$COMMON_PATH/snap.zip"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 4 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 4 ) / 1024 " | bc)m"

rm -rfv $COMMON_PATH
mkdir -p "$COMMON_PATH" "$DOCKER_COMMON/tmp" "$DOCKER_COMMON/sentry" "$DOCKER_COMMON/priv_sentry" "$DOCKER_COMMON/snapshoot"

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
    echo "INFO: State snapshoot '$KIRA_SNAP_PATH' was found, cloning..."
    cp -a -v -f $KIRA_SNAP_PATH $SNAP_DESTINATION
fi

echo "INFO: Setting up $CONTAINER_NAME config vars..."

SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
PRIV_SENTRY_SEED=$(echo "${PRIV_SENTRY_NODE_ID}@sentry:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

GENESIS_SOURCE="/root/.simapp/config/genesis.json"
GENESIS_DESTINATION="$DOCKER_COMMON/tmp/genesis.json"
rm -fv $GENESIS_DESTINATION "$DOCKER_COMMON/sentry/genesis.json" "$DOCKER_COMMON/priv_sentry/genesis.json" "$DOCKER_COMMON/snapshoot/genesis.json"

echo "INFO: Starting $CONTAINER_NAME node..."

docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    --hostname $KIRA_VALIDATOR_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_VALIDATOR_NETWORK \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e CFG_moniker="KIRA ${CONTAINER_NAME^^} NODE" \
    -e CFG_rpc_laddr="tcp://127.0.0.1:$DEFAULT_RPC_PORT" \
    -e CFG_private_peer_ids="$VALIDATOR_NODE_ID,$SENTRY_NODE_ID,$PRIV_SENTRY_NODE_ID,$SNAPSHOOT_NODE_ID" \
    -e CFG_persistent_peers="tcp://$SENTRY_SEED,tcp://$PRIV_SENTRY_SEED" \
    -e CFG_unconditional_peer_ids="$SENTRY_NODE_ID,$PRIV_SENTRY_NODE_ID" \
    -e CFG_max_num_outbound_peers="0" \
    -e CFG_max_num_inbound_peers="3" \
    -e CFG_addr_book_strict="false" \
    -e CFG_seed_mode="false" \
    -e CFG_pex="false" \
    -e CFG_version="v2" \
    -e NODE_TYPE=$CONTAINER_NAME \
    -v $COMMON_PATH:/common \
    kira:latest

echo "INFO: Waiting for $CONTAINER_NAME to start and import or produce genesis..."
$KIRAMGR_SCRIPTS/await-validator-init.sh "$DOCKER_COMMON" "$GENESIS_SOURCE" "$GENESIS_DESTINATION" "$VALIDATOR_NODE_ID" || exit 1

echo "INFO: Cloning genesis file..."
cp -f -a -v $GENESIS_DESTINATION "$DOCKER_COMMON/sentry/genesis.json"
cp -f -a -v $GENESIS_DESTINATION "$DOCKER_COMMON/validator/genesis.json"
cp -f -a -v $GENESIS_DESTINATION "$DOCKER_COMMON/priv_sentry/genesis.json"
cp -f -a -v $GENESIS_DESTINATION "$DOCKER_COMMON/snapshoot/genesis.json"

$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_VALIDATOR_NETWORK"
