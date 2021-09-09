#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/containers/start-snapshot.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

set -x

MAX_HEIGHT=$1
SYNC_FROM_SNAP=$2

[ -z "$MAX_HEIGHT" ] && MAX_HEIGHT=$(globGet LATEST_BLOCK) && (! $(isNaturalNumber "$MAX_HEIGHT")) && MAX_HEIGHT=0
# ensure to create parent directory for shared status info
CONTAINER_NAME="snapshot"
CONTAINER_NETWORK="$KIRA_SENTRY_NETWORK"
SNAP_STATUS="$KIRA_SNAP/status"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
COMMON_GLOB="$COMMON_PATH/kiraglob"
HALT_FILE="$COMMON_PATH/halt"
SNAP_DONE="$SNAP_STATUS/done"
SNAP_PROGRESS="$SNAP_STATUS/progress"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 5 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 5 ) / 1024 " | bc)m"

SNAP_FILENAME="${NETWORK_NAME}-$MAX_HEIGHT-$(date -u +%s).zip"
SNAP_FILE="$KIRA_SNAP/$SNAP_FILENAME"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING $CONTAINER_NAME NODE"
echoWarn "|-----------------------------------------------"
echoWarn "|    HOSTNAME: $KIRA_SNAPSHOT_DNS"
echoWarn "|     NETWORK: $CONTAINER_NETWORK"
echoWarn "| SYNC HEIGHT: $MAX_HEIGHT"
echoWarn "|  SNAP DEST.: $SNAP_FILE"
echoWarn "| SNAP SOURCE: $SYNC_FROM_SNAP"
echoWarn "|     MAX CPU: $CPU_RESERVED / $CPU_CORES"
echoWarn "|     MAX RAM: $RAM_RESERVED"
echoWarn "------------------------------------------------"
set -x

echoInfo "INFO: Wiping '$CONTAINER_NAME' resources..."
$KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

echoInfo "INFO: Ensuring base images exist..."
$KIRA_MANAGER/setup/registry.sh
$KIRAMGR_SCRIPTS/update-base-image.sh
$KIRAMGR_SCRIPTS/update-kira-image.sh

chattr -iR $COMMON_PATH || echoWarn "WARNING: Failed to remove integrity protection from $COMMON_PATH"
# globGet snapshot_health_log_old
tryCat "$COMMON_PATH/logs/health.log" | globSet "${CONTAINER_NAME}_HEALTH_LOG_OLD"
# globGet snapshot_start_log_old
tryCat "$COMMON_PATH/logs/start.log" | globSet "${CONTAINER_NAME}_START_LOG_OLD"
rm -rfv "$COMMON_PATH" "$SNAP_STATUS" "$SNAP_DONE" "$SNAP_PROGRESS"
mkdir -p "$COMMON_LOGS" "$SNAP_STATUS" "$COMMON_GLOB"

echoInfo "INFO: Loading secrets..."
set +x
set +e
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -x
set -e

echoInfo "INFO: Checking peers info..."
NODE_ID="$SNAPSHOT_NODE_ID"
EXTERNAL_P2P_PORT="$KIRA_SNAPSHOT_P2P_PORT"
cp -afv "$KIRA_SECRETS/${CONTAINER_NAME}_node_key.json" $COMMON_PATH/node_key.json

touch "$PRIVATE_PEERS" "$PRIVATE_SEEDS" "$PUBLIC_PEERS" "$PUBLIC_SEEDS"

PRIV_CONN_PRIORITY=$(globGet PRIV_CONN_PRIORITY)

if [ "${INFRA_MODE,,}" == "validator" ] || [ "${INFRA_MODE,,}" == "local" ] ; then
    CONTAINER_TARGET="validator"
    PING_TARGET="validator.local"
    NODE_ID_TARGET="$VALIDATOR_NODE_ID"
elif [ "${INFRA_MODE,,}" == "seed" ] ; then
    CONTAINER_TARGET="seed"
    PING_TARGET="seed.local"
    NODE_ID_TARGET="$SEED_NODE_ID"
elif [ "${INFRA_MODE,,}" == "sentry" ] ; then
    CONTAINER_TARGET="sentry"
    PING_TARGET="sentry.local"
    NODE_ID_TARGET="$SENTRY_NODE_ID"
else
    echoErr "ERROR: Unsupported infra mode '$INFRA_MODE', snapshoot sentry can't be launched"
fi

LISTEN_ADDR=$(timeout 3 curl --fail $PING_TARGET:$DEFAULT_RPC_PORT/status 2>/dev/null | jsonParse "result.node_info.listen_addr" 2>/dev/null || echo -n "")
LISTEN_ADDR=$(echo "$LISTEN_ADDR" | sed 's/tcp\?:\/\///')

CFG_persistent_peers=""
if [ ! -z "$LISTEN_ADDR" ] ; then
    addrArr=( $(echo $LISTEN_ADDR | tr ":" "\n") )
    LISTEN_ADDR=${addrArr[0],,}
    LISTEN_PORT=${addrArr[1],,}

    if ($(isDnsOrIp "$LISTEN_ADDR")) && ($(isPort "$LISTEN_PORT")) ; then
        CFG_persistent_peers=$(echo "${NODE_ID_TARGET}@$LISTEN_ADDR:$LISTEN_PORT" | xargs | tr -d '\n' | tr -d '\r')
    fi
fi

if [ -z "$CFG_persistent_peers" ] ; then
    echoErr "ERROR: No persistent local peers found, snapshot can NOT be created"
    exit 1
fi

SNAP_DESTINATION="$COMMON_PATH/snap.zip"
rm -rfv $SNAP_DESTINATION
if [ -f "$KIRA_SNAP_PATH" ] ; then
    echoInfo "INFO: State snapshot was found, cloning..."
    ln -fv "$KIRA_SNAP_PATH" "$SNAP_DESTINATION"
fi

globSet CFG_pex "true" $COMMON_GLOB
globSet CFG_moniker "KIRA ${CONTAINER_NAME^^} NODE" $COMMON_GLOB
# true
globSet CFG_allow_duplicate_ip "true" $COMMON_GLOB
globSet CFG_addr_book_strict "false" $COMMON_GLOB
globSet CFG_fastsync "true" $COMMON_GLOB
globSet CFG_fastsync_version "v1" $COMMON_GLOB

globSet CFG_handshake_timeout "60s" $COMMON_GLOB
globSet CFG_dial_timeout "30s" $COMMON_GLOB
globSet CFG_trust_period "87600h" $COMMON_GLOB
globSet CFG_max_txs_bytes "131072000" $COMMON_GLOB
globSet CFG_max_tx_bytes "131072" $COMMON_GLOB
globSet CFG_send_rate "65536000" $COMMON_GLOB
globSet CFG_recv_rate "65536000" $COMMON_GLOB
globSet CFG_max_packet_msg_payload_size "131072" $COMMON_GLOB
globSet CFG_cors_allowed_origins "*" $COMMON_GLOB
globSet CFG_snapshot_interval "1000" $COMMON_GLOB
globSet CFG_statesync_enable "true" $COMMON_GLOB
globSet CFG_statesync_temp_dir "/tmp" $COMMON_GLOB
globSet CFG_timeout_commit "5000ms" $COMMON_GLOB
globSet CFG_create_empty_blocks_interval "10s" $COMMON_GLOB
globSet CFG_max_num_outbound_peers "32" $COMMON_GLOB
globSet CFG_max_num_inbound_peers "128" $COMMON_GLOB
globSet CFG_prometheus "true" $COMMON_GLOB
globSet CFG_seed_mode "false" $COMMON_GLOB
globSet CFG_skip_timeout_commit "false" $COMMON_GLOB
globSet CFG_private_peer_ids "" $COMMON_GLOB
globSet CFG_unconditional_peer_ids "$SNAPSHOT_NODE_ID,$SENTRY_NODE_ID,$SEED_NODE_ID,$VALIDATOR_NODE_ID" $COMMON_GLOB
globSet CFG_persistent_peers "$CFG_persistent_peers" $COMMON_GLOB
globSet CFG_seeds "" $COMMON_GLOB

globSet CFG_grpc_laddr "tcp://0.0.0.0:$DEFAULT_GRPC_PORT" $COMMON_GLOB
globSet CFG_rpc_laddr "tcp://0.0.0.0:$DEFAULT_RPC_PORT" $COMMON_GLOB
globSet CFG_p2p_laddr "tcp://0.0.0.0:$DEFAULT_P2P_PORT" $COMMON_GLOB

globSet PRIVATE_MODE "true" $COMMON_GLOB

echoInfo "INFO: Starting '$CONTAINER_NAME' container..."
docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_SNAPSHOT_P2P_PORT:$DEFAULT_P2P_PORT \
    -p $KIRA_SNAPSHOT_RPC_PORT:$DEFAULT_RPC_PORT \
    -p $KIRA_SNAPSHOT_PROMETHEUS_PORT:$DEFAULT_PROMETHEUS_PORT \
    --hostname $KIRA_SNAPSHOT_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$CONTAINER_NETWORK \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e HALT_HEIGHT="$MAX_HEIGHT" \
    -e SNAP_FILENAME="$SNAP_FILENAME" \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e HOSTNAME="$KIRA_SNAPSHOT_DNS" \
    -e CONTAINER_NETWORK="$CONTAINER_NETWORK" \
    -e INTERNAL_P2P_PORT="$DEFAULT_P2P_PORT" \
    -e INTERNAL_RPC_PORT="$DEFAULT_RPC_PORT" \
    -e EXTERNAL_P2P_PORT="$EXTERNAL_P2P_PORT" \
    -e PING_TARGET="$PING_TARGET" \
    -e NODE_TYPE=$CONTAINER_NAME \
    -e NODE_ID="$NODE_ID" \
    -v $COMMON_PATH:/common \
    -v $KIRA_SNAP:/snap \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    kira:latest # use sentry image as base

echoInfo "INFO: Waiting for $CONTAINER_NAME node to start..."
CONTAINER_CREATED="true" && $KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$NODE_ID" || CONTAINER_CREATED="false"

if [ "${CONTAINER_CREATED,,}" != "true" ]; then
    echoErr "ERROR: Snapshot failed, '$CONTAINER_NAME' container did not start"
    $KIRA_SCRIPTS/container-pause.sh $CONTAINER_NAME || echoErr "ERROR: Failed to pause container"
else
    echoInfo "INFO: Success '$CONTAINER_NAME' container was started"
    rm -fv "$SNAP_DESTINATION"

    echoInfo "INFO: Checking genesis SHA256 hash"
    GENESIS_SHA256=$(globGet GENESIS_SHA256)
    TEST_SHA256=$(docker exec -i "$CONTAINER_NAME" /bin/bash -c ". /etc/profile;sha256 \$SEKAID_HOME/config/genesis.json" || echo -n "")
    if [ -z "$TEST_SHA256" ] || [ "$TEST_SHA256" != "$GENESIS_SHA256" ]; then
        echoErr "ERROR: Snapshot failed, expected genesis checksum to be '$GENESIS_SHA256' but got '$TEST_SHA256'"
        $KIRA_SCRIPTS/container-pause.sh $CONTAINER_NAME || echoErr "ERROR: Failed to pause container"
        exit 1
    fi

    echoInfo "INFO: Snapshot destination: $SNAP_FILE"
    echoInfo "INFO: Work in progress, await snapshot container to reach 100% sync status"
fi

systemctl restart kiraclean