#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/containers/start-sentry.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

CONTAINER_NAME="sentry"
CONTAINER_NETWORK="$KIRA_SENTRY_NETWORK"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
GLOBAL_COMMON="$COMMON_PATH/kiraglob"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 2 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 2 ) / 1024 " | bc)m"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING $CONTAINER_NAME NODE"
echoWarn "|-----------------------------------------------"
echoWarn "|   NODE ID: $SENTRY_NODE_ID"
echoWarn "|   NETWORK: $CONTAINER_NETWORK"
echoWarn "|  HOSTNAME: $KIRA_SENTRY_DNS"
echoWarn "|  SNAPSHOT: $KIRA_SNAP_PATH"
echoWarn "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echoWarn "|   MAX RAM: $RAM_RESERVED"
echoWarn "------------------------------------------------"
set -x

globSet "${CONTAINER_NAME}_STARTED" "false"

if (! $($KIRA_COMMON/container-healthy.sh "$CONTAINER_NAME")) ; then
    
    echoInfo "INFO: Wiping '$CONTAINER_NAME' resources..."
    $KIRA_COMMON/container-delete.sh "$CONTAINER_NAME"

    chattr -iR $COMMON_PATH || echoWarn "WARNING: Failed to remove integrity protection from $COMMON_PATH"
    # globGet sentry_health_log_old
    tryCat "$COMMON_PATH/logs/health.log" | globSet "${CONTAINER_NAME}_HEALTH_LOG_OLD"
    # globGet sentry_start_log_old
    tryCat "$COMMON_PATH/logs/start.log" | globSet "${CONTAINER_NAME}_START_LOG_OLD"
    rm -rfv "$COMMON_PATH"
    mkdir -p "$COMMON_LOGS" "$GLOBAL_COMMON"

    echoInfo "INFO: Loading secrets..."
    set +x
    set +e
    source $KIRAMGR_SCRIPTS/load-secrets.sh
    set -x
    set -e

    echoInfo "INFO: Setting up $CONTAINER_NAME config vars..."
    touch "$PUBLIC_PEERS" "$PUBLIC_SEEDS"
    cp -afv "$PUBLIC_PEERS" "$COMMON_PATH/peers"
    cp -afv "$PUBLIC_SEEDS" "$COMMON_PATH/seeds"
    cp -arfv "$KIRA_INFRA/kira/." "$COMMON_PATH"
    cp -afv "$KIRA_SECRETS/${CONTAINER_NAME}_node_key.json" $COMMON_PATH/node_key.json

    EXTERNAL_P2P_PORT="$KIRA_SENTRY_P2P_PORT"
    NODE_ID="$SENTRY_NODE_ID"

    globSet cfg_p2p_pex "true" $GLOBAL_COMMON
    globSet cfg_base_moniker "KIRA ${CONTAINER_NAME^^} NODE" $GLOBAL_COMMON
    #true
    globSet cfg_p2p_allow_duplicate_ip "true" $GLOBAL_COMMON
    globSet cfg_p2p_addr_book_strict "false" $GLOBAL_COMMON
    globSet cfg_fast_sync "true" $GLOBAL_COMMON
    globSet cfg_fastsync_version "v1" $GLOBAL_COMMON

    globSet cfg_p2p_handshake_timeout "60s" $GLOBAL_COMMON
    globSet cfg_p2p_dial_timeout "30s" $GLOBAL_COMMON
    globSet CFG_trust_period "87600h" $GLOBAL_COMMON
    globSet cfg_mempool_max_txs_bytes "131072000" $GLOBAL_COMMON
    globSet cfg_mempool_max_tx_bytes "131072" $GLOBAL_COMMON
    globSet cfg_p2p_send_rate "65536000" $GLOBAL_COMMON
    globSet cfg_p2p_recv_rate "65536000" $GLOBAL_COMMON
    globSet cfg_p2p_max_packet_msg_payload_size "131072" $GLOBAL_COMMON
    globSet cfg_rpc_cors_allowed_origins "[ \"*\" ]" $GLOBAL_COMMON
    globSet app_state_sync_snapshot_interval "1000" $GLOBAL_COMMON
    globSet cfg_statesync_enable "true" $GLOBAL_COMMON
    globSet cfg_statesync_temp_dir "/tmp" $GLOBAL_COMMON
    globSet cfg_consensus_timeout_commit "7500ms" $GLOBAL_COMMON
    globSet cfg_consensus_create_empty_blocks_interval "10s" $GLOBAL_COMMON
    globSet cfg_p2p_max_num_outbound_peers "32" $GLOBAL_COMMON
    globSet cfg_p2p_max_num_inbound_peers "128" $GLOBAL_COMMON
    globSet cfg_instrumentation_prometheus "true" $GLOBAL_COMMON
    globSet cfg_p2p_seed_mode "false" $GLOBAL_COMMON
    globSet cfg_consensus_skip_timeout_commit "false" $GLOBAL_COMMON
    globSet cfg_p2p_private_peer_ids "" $GLOBAL_COMMON
    globSet cfg_p2p_unconditional_peer_ids "$SENTRY_NODE_ID,$SEED_NODE_ID,$VALIDATOR_NODE_ID" $GLOBAL_COMMON
    globSet cfg_p2p_persistent_peers "" $GLOBAL_COMMON
    globSet cfg_p2p_seeds "" $GLOBAL_COMMON
    globSet cfg_rpc_laddr "tcp://0.0.0.0:$DEFAULT_RPC_PORT" $GLOBAL_COMMON
    globSet cfg_p2p_laddr "tcp://0.0.0.0:$DEFAULT_P2P_PORT" $GLOBAL_COMMON

    globSet PRIVATE_MODE "$(globGet PRIVATE_MODE)" $GLOBAL_COMMON

    echoInfo "INFO: Starting '$CONTAINER_NAME' container..."
docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_SENTRY_P2P_PORT:$DEFAULT_P2P_PORT \
    -p $KIRA_SENTRY_RPC_PORT:$DEFAULT_RPC_PORT \
    -p $KIRA_SENTRY_PROMETHEUS_PORT:$DEFAULT_PROMETHEUS_PORT \
    --hostname $KIRA_SENTRY_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$CONTAINER_NETWORK \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e HOSTNAME="$KIRA_SENTRY_DNS" \
    -e CONTAINER_NETWORK="$CONTAINER_NETWORK" \
    -e NODE_TYPE=$CONTAINER_NAME \
    -e NODE_ID="$NODE_ID" \
    -e EXTERNAL_P2P_PORT="$EXTERNAL_P2P_PORT" \
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

echo "INFO: Waiting for $CONTAINER_NAME to start..."
$KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$NODE_ID" "true"

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