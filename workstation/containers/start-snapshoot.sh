#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/containers/start-snapshot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

set -x

MAX_HEIGHT=$1
SYNC_FROM_SNAP=$2

[ -z "$MAX_HEIGHT" ] && MAX_HEIGHT="0"
# ensure to create parent directory for shared status info
CONTAINER_NAME="snapshot"
SNAP_STATUS="$KIRA_SNAP/status"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"
GENESIS_SOURCE="$SEKAID_HOME/config/genesis.json"
SNAP_DESTINATION="$COMMON_PATH/snap.zip"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 5 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 5 ) / 1024 " | bc)m"

rm -fvr "$SNAP_STATUS"
mkdir -p "$SNAP_STATUS" "$COMMON_LOGS"

SENTRY_STATUS=$(curl 127.0.0.1:$KIRA_SENTRY_RPC_PORT/status 2> /dev/null | jq -rc '.result' 2> /dev/null || echo "")
SENTRY_CATCHING_UP=$(echo $SENTRY_STATUS | jq -r '.sync_info.catching_up' 2> /dev/null || echo "") && [ -z "$SENTRY_CATCHING_UP" ] && SENTRY_CATCHING_UP="true"
SENTRY_NETWORK=$(echo $SENTRY_STATUS | jq -r '.node_info.network' 2> /dev/null || echo "")

if [ "${SENTRY_CATCHING_UP,,}" != "false" ] || [ -z "$SENTRY_NETWORK" ] || [ "${SENTRY_NETWORK,,}" == "null" ] ; then
    echo "INFO: Failed to snapshot state, public sentry is still catching up or network was not found..."
    exit 1
fi

if [ $MAX_HEIGHT -le 0 ] ; then
    SENTRY_BLOCK=$(echo $SENTRY_STATUS | jq -r '.sync_info.latest_block_height' 2> /dev/null || echo "")
    ( [ -z "$SENTRY_BLOCK" ] || [ "${SENTRY_BLOCK,,}" == "null" ] ) && SENTRY_BLOCK=$(echo $SENTRY_STATUS | jq -r '.SyncInfo.latest_block_height' 2> /dev/null || echo "")
    ( [ -z "$SENTRY_BLOCK" ] || [ "${SENTRY_BLOCK,,}" == "null" ] ) && SENTRY_BLOCK="0"
    MAX_HEIGHT=$SENTRY_BLOCK
fi

SNAP_FILENAME="${SENTRY_NETWORK}-$MAX_HEIGHT-$(date -u +%s).zip"
SNAP_FILE="$KIRA_SNAP/$SNAP_FILENAME"

set +x
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|     NETWORK: $KIRA_SENTRY_NETWORK"
echo "|    HOSTNAME: $KIRA_SNAPSHOT_DNS"
echo "| SYNC HEIGHT: $MAX_HEIGHT" 
echo "|   SNAP FILE: $SNAP_FILE"
echo "|     MAX CPU: $CPU_RESERVED / $CPU_CORES"
echo "|     MAX RAM: $RAM_RESERVED"
echo "------------------------------------------------"

echo "INFO: Loading secrets..."
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -x
set -e

cp -f -a -v $KIRA_SECRETS/snapshot_node_key.json $COMMON_PATH/node_key.json

rm -fv $SNAP_DESTINATION
if [ -f "$SYNC_FROM_SNAP" ] ; then
    echo "INFO: State snapshot was found, cloning..."
    cp -a -v -f $SYNC_FROM_SNAP $SNAP_DESTINATION
fi

echo "INFO: Cleaning up snapshot container..."
$KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

echo "INFO: Setting up $CONTAINER_NAME config vars..." # * Config ~/configs/config.toml

SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
PRIV_SENTRY_SEED=$(echo "${PRIV_SENTRY_NODE_ID}@priv_sentry:$KIRA_PRIV_SENTRY_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
CFG_persistent_peers="tcp://$SENTRY_SEED,tcp://$PRIV_SENTRY_SEED"

echo "INFO: Copy genesis file from sentry into snapshot container common direcotry..."
docker cp -a sentry:$GENESIS_SOURCE $COMMON_PATH

# cleanup
rm -f -v "$COMMON_LOGS/start.log" "$COMMON_PATH/executed" "$HALT_FILE"

echo "INFO: Starting $CONTAINER_NAME node..."

docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    --hostname $KIRA_SNAPSHOT_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_SENTRY_NETWORK \
    -e HALT_HEIGHT="$MAX_HEIGHT" \
    -e SNAP_FILENAME="$SNAP_FILENAME" \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e CFG_moniker="KIRA ${CONTAINER_NAME^^} NODE" \
    -e CFG_persistent_peers="$CFG_persistent_peers" \
    -e CFG_grpc_laddr="tcp://127.0.0.1:$DEFAULT_GRPC_PORT" \
    -e CFG_rpc_laddr="tcp://127.0.0.1:$DEFAULT_RPC_PORT" \
    -e CFG_p2p_laddr="tcp://0.0.0.0:$DEFAULT_P2P_PORT" \
    -e CFG_private_peer_ids="$SENTRY_NODE_ID,$PRIV_SENTRY_NODE_ID" \
    -e CFG_unconditional_peer_ids="$VALIDATOR_NODE_ID,$PRIV_SENTRY_NODE_ID" \
    -e CFG_pex="false" \
    -e CFG_addr_book_strict="false" \
    -e CFG_version="v2" \
    -e CFG_seed_mode="false" \
    -e CFG_cors_allowed_origins="*" \
    -e CFG_max_num_outbound_peers="0" \
    -e CFG_max_num_inbound_peers="1" \
    -e NODE_TYPE=$CONTAINER_NAME \
    -v $COMMON_PATH:/common \
    -v $KIRA_SNAP:/snap \
    kira:latest # use sentry image as base

echo "INFO: Waiting for $CONTAINER_NAME node to start..."
CONTAINER_CREATED="true" && $KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$SNAPSHOT_NODE_ID" || CONTAINER_CREATED="false"

echoInfo "INFO: Checking genesis SHA256 hash"
TEST_SHA256=$(docker exec -i "$CONTAINER_NAME" sha256sum $SEKAID_HOME/config/genesis.json | awk '{ print $1 }' | xargs || echo "")
if [ ! -z "$TEST_SHA256" ] && [ "$TEST_SHA256" != "$GENESIS_SHA256" ] ; then
    echoErr "ERROR: Expected genesis checksum to be '$GENESIS_SHA256' but got '$TEST_SHA256'"
    exit 1
else
    echoInfo "INFO: Genesis checksum '$TEST_SHA256' was verified sucessfully!"
fi

set +x
if [ "${CONTAINER_CREATED,,}" != "true" ] ; then
    echo "INFO: Snapshot failed, '$CONTAINER_NAME' container did not start"
else
    echo "INFO: Success '$CONTAINER_NAME' container was started" && echo ""
    echo -en "\e[31;1mINFO: Snapshot destination: $SNAP_FILE\e[0m"  && echo ""
    echo "INFO: Work in progress, await snapshot container to reach 100% sync status"
fi
set -x