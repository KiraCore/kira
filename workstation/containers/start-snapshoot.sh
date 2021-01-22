#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/containers/start-snapshoot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

set -x

MAX_HEIGHT=$1
SYNC_FROM_SNAP=$2

[ -z "$MAX_HEIGHT" ] && MAX_HEIGHT="0"
# ensure to create parent directory for shared status info
CONTAINER_NAME="snapshoot"
SNAP_STATUS="$KIRA_SNAP/status"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
GENESIS_SOURCE="/root/.simapp/config/genesis.json"
SNAP_DESTINATION="$COMMON_PATH/snap.zip"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 4 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 4 ) / 1024 " | bc)m"

rm -fvr "$SNAP_STATUS"
mkdir -p "$SNAP_STATUS" "$COMMON_PATH"

SENTRY_STATUS=$(docker exec -i "sentry" sekaid status 2> /dev/null | jq -r '.' 2> /dev/null || echo "")
SENTRY_CATCHING_UP=$(echo $SENTRY_STATUS | jq -r '.sync_info.catching_up' 2> /dev/null || echo "") && [ -z "$SENTRY_CATCHING_UP" ] && SENTRY_CATCHING_UP="true"
SENTRY_NETWORK=$(echo $SENTRY_STATUS | jq -r '.node_info.network' 2> /dev/null || echo "")

if [ "${SENTRY_CATCHING_UP,,}" != "false" ] || [ -z "$SENTRY_NETWORK" ] ; then
    echo "INFO: Failed to snapshoot state, public sentry is still catching up..."
    exit 1
fi

if [ $MAX_HEIGHT -le 0 ] ; then
    SENTRY_BLOCK=$(echo $SENTRY_STATUS | jq -r '.sync_info.latest_block_height' 2> /dev/null || echo "") && [ -z "$SENTRY_BLOCK" ] && SENTRY_BLOCK="0"
    MAX_HEIGHT=$SENTRY_BLOCK
fi

SNAP_FILENAME="${SENTRY_NETWORK}-$MAX_HEIGHT-$(date -u +%s).zip"
SNAP_FILE="$KIRA_SNAP/$SNAP_FILENAME"

set +x
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|     NETWORK: $KIRA_SENTRY_NETWORK"
echo "|    HOSTNAME: $KIRA_SNAPSHOOT_DNS"
echo "| SYNC HEIGHT: $MAX_HEIGHT" 
echo "|   SNAP FILE: $SNAP_FILE"
echo "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echo "|   MAX RAM: $RAM_RESERVED"
echo "------------------------------------------------"

echo "INFO: Loading secrets..."
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -x
set -e

cp -f -a -v $KIRA_SECRETS/snapshoot_node_key.json $COMMON_PATH/node_key.json

rm -fv $SNAP_DESTINATION
if [ -f "$SYNC_FROM_SNAP" ] ; then
    echo "INFO: State snapshoot was found, cloning..."
    cp -a -v -f $SYNC_FROM_SNAP $SNAP_DESTINATION
fi

echo "INFO: Cleaning up snapshoot container..."
$KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

echo "INFO: Setting up $CONTAINER_NAME config vars..." # * Config ~/configs/config.toml
SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

echo "INFO: Copy genesis file from sentry into snapshoot container common direcotry..."
docker cp -a sentry:$GENESIS_SOURCE $COMMON_PATH

echo "INFO: Starting $CONTAINER_NAME node..."

docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    --hostname $KIRA_SNAPSHOOT_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_SENTRY_NETWORK \
    -e HALT_HEIGHT="$MAX_HEIGHT" \
    -e SNAP_FILENAME="$SNAP_FILENAME" \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e CFG_moniker="KIRA ${CONTAINER_NAME^^} NODE" \
    -e CFG_seed="$SENTRY_SEED" \
    -e CFG_rpc_laddr="tcp://0.0.0.0:$DEFAULT_RPC_PORT" \
    -e CFG_persistent_peers="tcp://$SENTRY_SEED" \
    -e CFG_private_peer_ids="$VALIDATOR_NODE_ID,$SNAPSHOOT_NODE_ID,$SENTRY_NODE_ID,$PRIV_SENTRY_NODE_ID" \
    -e CFG_unconditional_peer_ids="$SENTRY_NODE_ID" \
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
CONTAINER_CREATED="true" && $KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$SNAPSHOOT_NODE_ID" || CONTAINER_CREATED="false"

set +x
if [ "${CONTAINER_CREATED,,}" != "true" ] ; then
    echo "INFO: Snapshoot failed, '$CONTAINER_NAME' container did not start"
else
    echo "INFO: Success '$CONTAINER_NAME' container was started" && echo ""
    echo -en "\e[31;1mINFO: Snapshoot destination: $SNAP_FILE\e[0m"  && echo ""
    echo "INFO: Work in progress, await snapshoot container to reach 100% sync status"
fi
set -x