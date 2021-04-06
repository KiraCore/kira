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
SCAN_DIR="$KIRA_HOME/kirascan"
LATEST_BLOCK_SCAN_PATH="$SCAN_DIR/latest_block"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"
SNAP_DESTINATION="$COMMON_PATH/snap.zip"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 7 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 7 ) / 1024 " | bc)m"
LATETS_BLOCK=$(cat $LATEST_BLOCK_SCAN_PATH || echo "0") && (! $(isNaturalNumber "$LATETS_BLOCK")) && LATETS_BLOCK=0

rm -fvr "$SNAP_STATUS"
mkdir -p "$SNAP_STATUS" "$COMMON_LOGS"

echo "INFO: Setting up $CONTAINER_NAME config vars..." # * Config ~/configs/config.toml

SENTRY_STATUS=$(timeout 3 curl 0.0.0.0:$KIRA_SENTRY_RPC_PORT/status 2>/dev/null | jq -rc '.result' 2>/dev/null || echo "")
PRIV_SENTRY_STATUS=$(timeout 3 curl 0.0.0.0:$KIRA_PRIV_SENTRY_RPC_PORT/status 2>/dev/null | jq -rc '.result' 2>/dev/null || echo "")

SENTRY_CATCHING_UP=$(echo $SENTRY_STATUS | jq -r '.sync_info.catching_up' 2>/dev/null || echo "") && ($(isNullOrEmpty "$SENTRY_CATCHING_UP")) && SENTRY_CATCHING_UP="true"
PRIV_SENTRY_CATCHING_UP=$(echo $PRIV_SENTRY_STATUS | jq -r '.sync_info.catching_up' 2>/dev/null || echo "") && ($(isNullOrEmpty "$PRIV_SENTRY_CATCHING_UP")) && PRIV_SENTRY_CATCHING_UP="true"

SENTRY_NETWORK=$(echo $SENTRY_STATUS | jq -r '.node_info.network' 2>/dev/null || echo "")
PRIV_SENTRY_NETWORK=$(echo $PRIV_SENTRY_STATUS | jq -r '.node_info.network' 2>/dev/null || echo "")

SENTRY_BLOCK=$(echo $SENTRY_STATUS | jq -r '.sync_info.latest_block_height' 2>/dev/null || echo "") && (! $(isNaturalNumber "$SENTRY_BLOCK")) && SENTRY_BLOCK=0
PRIV_SENTRY_BLOCK=$(echo $PRIV_SENTRY_STATUS | jq -r '.sync_info.latest_block_height' 2>/dev/null || echo "") && (! $(isNaturalNumber "$PRIV_SENTRY_BLOCK")) && PRIV_SENTRY_BLOCK=0

[ $MAX_HEIGHT -le 0 ] && MAX_HEIGHT=$LATETS_BLOCK
SNAP_FILENAME="${NETWORK_NAME}-$MAX_HEIGHT-$(date -u +%s).zip"
SNAP_FILE="$KIRA_SNAP/$SNAP_FILENAME"

set +x
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|     NETWORK: $KIRA_SENTRY_NETWORK"
echo "|    HOSTNAME: $KIRA_SNAPSHOT_DNS"
echo "| SYNC HEIGHT: $MAX_HEIGHT"
echo "|  SNAP DEST.: $SNAP_FILE"
echo "| SNAP SOURCE: $SYNC_FROM_SNAP"
echo "|     MAX CPU: $CPU_RESERVED / $CPU_CORES"
echo "|     MAX RAM: $RAM_RESERVED"
echo "------------------------------------------------"

echo "INFO: Loading secrets..."
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -x
set -e

echo "INFO: Checking peers info..."
SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$KIRA_SENTRY_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
PRIV_SENTRY_SEED=$(echo "${PRIV_SENTRY_NODE_ID}@priv_sentry:$KIRA_PRIV_SENTRY_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

CFG_persistent_peers=""

if [ "${SENTRY_CATCHING_UP,,}" == "false" ] && [ "$SENTRY_NETWORK" == "$NETWORK_NAME" ] && [ $LATETS_BLOCK -le $SENTRY_BLOCK ] ; then
    echo "INFO: Public sentry is healthy and will be added to the persistent peers list..."
    CFG_persistent_peers="tcp://$SENTRY_SEED"
fi

if [ "${PRIV_SENTRY_CATCHING_UP,,}" == "false" ] && [ "$PRIV_SENTRY_NETWORK" == "$NETWORK_NAME" ] && [ $LATETS_BLOCK -le $PRIV_SENTRY_BLOCK ] ; then
    echo "INFO: Private sentry is healthy and will be added to the persistent peers list..."
    [ ! -z "$CFG_persistent_peers" ] && CFG_persistent_peers="${CFG_persistent_peers},"
    CFG_persistent_peers="${CFG_persistent_peers}tcp://$PRIV_SENTRY_SEED"
fi

if [ -z "$CFG_persistent_peers" ] ; then
    echo "INFO: Failed to snapshot state, not a single healthy persistent peer was found..."
    exit 1
fi

cp -f -a -v $KIRA_SECRETS/snapshot_node_key.json $COMMON_PATH/node_key.json

rm -fv $SNAP_DESTINATION
if [ -f "$SYNC_FROM_SNAP" ]; then
    echo "INFO: State snapshot was found, cloning..."
    cp -a -v -f $SYNC_FROM_SNAP $SNAP_DESTINATION
fi

echo "INFO: Cleaning up snapshot container..."
$KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

# cleanup
rm -f -v "$COMMON_LOGS/start.log" "$COMMON_PATH/executed" "$HALT_FILE"

echo "INFO: Starting $CONTAINER_NAME node..."

docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_SNAPSHOT_RPC_PORT:$DEFAULT_RPC_PORT \
    --hostname $KIRA_SNAPSHOT_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_SENTRY_NETWORK \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e HALT_HEIGHT="$MAX_HEIGHT" \
    -e SNAP_FILENAME="$SNAP_FILENAME" \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e CFG_moniker="KIRA ${CONTAINER_NAME^^} NODE" \
    -e CFG_persistent_peers="$CFG_persistent_peers" \
    -e CFG_grpc_laddr="tcp://0.0.0.0:$DEFAULT_GRPC_PORT" \
    -e CFG_rpc_laddr="tcp://0.0.0.0:$DEFAULT_RPC_PORT" \
    -e CFG_p2p_laddr="tcp://0.0.0.0:$DEFAULT_P2P_PORT" \
    -e CFG_private_peer_ids="$SENTRY_NODE_ID,$PRIV_SENTRY_NODE_ID" \
    -e CFG_unconditional_peer_ids="$VALIDATOR_NODE_ID,$PRIV_SENTRY_NODE_ID" \
    -e CFG_pex="false" \
    -e CFG_addr_book_strict="false" \
    -e CFG_seed_mode="false" \
    -e CFG_max_num_outbound_peers="2" \
    -e CFG_max_num_inbound_peers="2" \
    -e NODE_TYPE=$CONTAINER_NAME \
    -v $COMMON_PATH:/common \
    -v $KIRA_SNAP:/snap \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    kira:latest # use sentry image as base

echo "INFO: Waiting for $CONTAINER_NAME node to start..."
CONTAINER_CREATED="true" && $KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$SNAPSHOT_NODE_ID" || CONTAINER_CREATED="false"

set +x
if [ "${CONTAINER_CREATED,,}" != "true" ]; then
    echo "INFO: Snapshot failed, '$CONTAINER_NAME' container did not start"
    $KIRA_SCRIPTS/container-pause.sh $CONTAINER_NAME || echoErr "ERROR: Failed to pause container"
else
    echo "INFO: Success '$CONTAINER_NAME' container was started"
    rm -fv "$SNAP_DESTINATION"

    echoInfo "INFO: Checking genesis SHA256 hash"
    TEST_SHA256=$(docker exec -i "$CONTAINER_NAME" sha256sum $SEKAID_HOME/config/genesis.json | awk '{ print $1 }' | xargs || echo "")
    if [ -z "$TEST_SHA256" ] || [ "$TEST_SHA256" != "$GENESIS_SHA256" ]; then
        echoErr "ERROR: Snapshot failed, expected genesis checksum to be '$GENESIS_SHA256' but got '$TEST_SHA256'"
        $KIRA_SCRIPTS/container-pause.sh $CONTAINER_NAME || echoErr "ERROR: Failed to pause container"
        exit 1
    fi

    echo -en "\e[31;1mINFO: Snapshot destination: $SNAP_FILE\e[0m" && echo ""
    echo "INFO: Work in progress, await snapshot container to reach 100% sync status"
fi
set -x
