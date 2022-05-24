#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/containers/start-seed.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

CONTAINER_NAME="seed"
CONTAINER_NETWORK="$KIRA_SENTRY_NETWORK"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
COMMON_GLOB="$COMMON_PATH/kiraglob"
HALT_FILE="$COMMON_PATH/halt"
EXIT_FILE="$COMMON_PATH/exit"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 2 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 2 ) / 1024 " | bc)m"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING $CONTAINER_NAME NODE"
echoWarn "|-----------------------------------------------"
echoWarn "|   NODE ID: $SEED_NODE_ID"
echoWarn "|   NETWORK: $CONTAINER_NETWORK"
echoWarn "|  HOSTNAME: $KIRA_SEED_DNS"
echoWarn "|  SNAPSHOT: $KIRA_SNAP_PATH"
echoWarn "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echoWarn "|   MAX RAM: $RAM_RESERVED"
echoWarn "------------------------------------------------"
set -x

globSet "${CONTAINER_NAME}_STARTED" "false"

if (! $($KIRA_SCRIPTS/container-healthy.sh "$CONTAINER_NAME")) ; then
    echoInfo "INFO: Wiping '$CONTAINER_NAME' resources..."
    $KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

    chattr -iR $COMMON_PATH || echoWarn "WARNING: Failed to remove integrity protection from $COMMON_PATH"
    # globGet seed_health_log_old
    tryCat "$COMMON_PATH/logs/health.log" | globSet "${CONTAINER_NAME}_HEALTH_LOG_OLD"
    # globGet seed_start_log_old
    tryCat "$COMMON_PATH/logs/start.log" | globSet "${CONTAINER_NAME}_START_LOG_OLD"
    rm -rfv "$COMMON_PATH"
    mkdir -p "$COMMON_LOGS" "$COMMON_GLOB"

    echo "INFO: Loading secrets..."
    set +e
    set +x
    source $KIRAMGR_SCRIPTS/load-secrets.sh
    set -x
    set -e

    echoInfo "INFO: Setting up $CONTAINER_NAME config vars..."
    cp -afv "$KIRA_SECRETS/${CONTAINER_NAME}_node_key.json" $COMMON_PATH/node_key.json

    SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@$KIRA_SENTRY_DNS:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

    touch "$PUBLIC_PEERS" "$PUBLIC_SEEDS"
    cp -afv "$PUBLIC_PEERS" "$COMMON_PATH/peers"
    cp -afv "$PUBLIC_SEEDS" "$COMMON_PATH/seeds"

    globSet CFG_pex "true" $COMMON_GLOB
    globSet CFG_moniker "KIRA ${CONTAINER_NAME^^} NODE" $COMMON_GLOB
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
    globSet CFG_timeout_commit "7500ms" $COMMON_GLOB
    globSet CFG_create_empty_blocks_interval "10s" $COMMON_GLOB
    globSet CFG_max_num_outbound_peers "32" $COMMON_GLOB
    globSet CFG_max_num_inbound_peers "512" $COMMON_GLOB
    globSet CFG_prometheus "true" $COMMON_GLOB
    globSet CFG_seed_mode "true" $COMMON_GLOB
    globSet CFG_skip_timeout_commit "false" $COMMON_GLOB
    globSet CFG_private_peer_ids "" $COMMON_GLOB
    globSet CFG_unconditional_peer_ids "$SENTRY_NODE_ID,$SEED_NODE_ID,$VALIDATOR_NODE_ID" $COMMON_GLOB
    globSet CFG_persistent_peers "" $COMMON_GLOB
    globSet CFG_seeds "" $COMMON_GLOB
    globSet CFG_grpc_laddr "tcp://0.0.0.0:$DEFAULT_GRPC_PORT" $COMMON_GLOB
    globSet CFG_rpc_laddr "tcp://0.0.0.0:$DEFAULT_RPC_PORT" $COMMON_GLOB
    globSet CFG_p2p_laddr "tcp://0.0.0.0:$DEFAULT_P2P_PORT" $COMMON_GLOB

    globSet PRIVATE_MODE "$(globGet PRIVATE_MODE)" $COMMON_GLOB

    echoInfo "INFO: Starting '$CONTAINER_NAME' container..."
docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_SEED_P2P_PORT:$DEFAULT_P2P_PORT \
    -p $KIRA_SEED_RPC_PORT:$DEFAULT_RPC_PORT \
    -p $KIRA_SEED_PROMETHEUS_PORT:$DEFAULT_PROMETHEUS_PORT \
    --hostname $KIRA_SEED_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$CONTAINER_NETWORK \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e HOSTNAME="$KIRA_SEED_DNS" \
    -e CONTAINER_NETWORK="$CONTAINER_NETWORK" \
    -e NODE_TYPE=$CONTAINER_NAME \
    -e NODE_ID="$SEED_NODE_ID" \
    -e EXTERNAL_P2P_PORT="$KIRA_SEED_P2P_PORT" \
    -e INTERNAL_P2P_PORT="$DEFAULT_P2P_PORT" \
    -e INTERNAL_RPC_PORT="$DEFAULT_RPC_PORT" \
    -v $COMMON_PATH:/common \
    -v $KIRA_SNAP:/snap \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    kira:latest
else
    echoInfo "INFO: Container $CONTAINER_NAME is healthy, restarting..."
    $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart" "true"
fi

echoInfo "INFO: Waiting for $CONTAINER_NAME to start..."
$KIRAMGR_SCRIPTS/await-seed-init.sh "$CONTAINER_NAME" "$SEED_NODE_ID"

echoInfo "INFO: Checking genesis SHA256 hash"
GENESIS_SHA256=$(globGet GENESIS_SHA256)
TEST_SHA256=$(docker exec -i "$CONTAINER_NAME" /bin/bash -c ". /etc/profile;sha256 \$SEKAID_HOME/config/genesis.json" || echo -n "")
if [ -z "$TEST_SHA256" ] || [ "$TEST_SHA256" != "$GENESIS_SHA256" ] ; then
    echoErr "ERROR: Expected genesis checksum to be '$GENESIS_SHA256' but got '$TEST_SHA256'"
    exit 1
else
    echoInfo "INFO: Genesis checksum '$TEST_SHA256' was verified sucessfully!"
fi

globSet "${CONTAINER_NAME}_STARTED" "true"

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: STARTING $CONTAINER_NAME NODE"
echoWarn "------------------------------------------------"
set -x