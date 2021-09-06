#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/containers/start-sentry.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

SAVE_SNAPSHOT=$1
[ -z "$SAVE_SNAPSHOT" ] && SAVE_SNAPSHOT="false"

CONTAINER_NAME="sentry"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
COMMON_GLOB="$COMMON_PATH/kiraglob"
HALT_FILE="$COMMON_PATH/halt"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 5 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 5 ) / 1024 " | bc)m"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING $CONTAINER_NAME NODE"
echoWarn "|-----------------------------------------------"
echoWarn "|   NODE ID: $SENTRY_NODE_ID"
echoWarn "|  HOSTNAME: $KIRA_SENTRY_DNS"
echoWarn "|  SNAPSHOT: $KIRA_SNAP_PATH"
echoWarn "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echoWarn "|   MAX RAM: $RAM_RESERVED"
echoWarn "------------------------------------------------"
set -x

if (! $($KIRA_SCRIPTS/container-healthy.sh "$CONTAINER_NAME")) ; then
    
    echoInfo "INFO: Wiping '$CONTAINER_NAME' resources..."
    $KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

    echoInfo "INFO: Ensuring base images exist..."
    $KIRA_MANAGER/setup/registry.sh
    $KIRAMGR_SCRIPTS/update-base-image.sh
    $KIRAMGR_SCRIPTS/update-kira-image.sh

    chattr -iR $COMMON_PATH || echoWarn "WARNING: Failed to remove integrity protection from $COMMON_PATH"
    # globGet sentry_health_log_old
    tryCat "$COMMON_PATH/logs/health.log" | globSet "${CONTAINER_NAME}_HEALTH_LOG_OLD"
    # globGet sentry_start_log_old
    tryCat "$COMMON_PATH/logs/start.log" | globSet "${CONTAINER_NAME}_START_LOG_OLD"
    rm -rfv "$COMMON_PATH"
    mkdir -p "$COMMON_LOGS" "$COMMON_GLOB"

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

    if [ "${INFRA_MODE,,}" == "validator" ] ; then
        CONTAINER_NETWORK="$KIRA_VALIDATOR_NETWORK"
        EXTERNAL_P2P_PORT="$KIRA_VALIDATOR_P2P_PORT"

        # fake that sentry node is a validator to ensure that previously accepted connections remain valid
        cp -afv $KIRA_SECRETS/validator_node_key.json $COMMON_PATH/node_key.json
        NODE_ID="$VALIDATOR_NODE_ID"
    else
        CONTAINER_NETWORK="$KIRA_SENTRY_NETWORK"
        EXTERNAL_P2P_PORT="$KIRA_SENTRY_P2P_PORT"
        
        cp -afv "$KIRA_SECRETS/${CONTAINER_NAME}_node_key.json" $COMMON_PATH/node_key.json
        NODE_ID="$SENTRY_NODE_ID"
    fi

    globSet CFG_pex "true" $COMMON_GLOB
    globSet CFG_moniker "KIRA ${CONTAINER_NAME^^} NODE" $COMMON_GLOB
    #true
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
    globSet CFG_persistent_peers "" $COMMON_GLOB
    globSet CFG_seeds "" $COMMON_GLOB
    globSet CFG_grpc_laddr "tcp://0.0.0.0:$DEFAULT_GRPC_PORT" $COMMON_GLOB
    globSet CFG_rpc_laddr "tcp://0.0.0.0:$DEFAULT_RPC_PORT" $COMMON_GLOB
    globSet CFG_p2p_laddr "tcp://0.0.0.0:$DEFAULT_P2P_PORT" $COMMON_GLOB

    globSet PRIVATE_MODE "false" $COMMON_GLOB

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
    $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart"
fi

echo "INFO: Waiting for $CONTAINER_NAME to start..."
$KIRAMGR_SCRIPTS/await-sentry-init.sh "$CONTAINER_NAME" "$NODE_ID" "$SAVE_SNAPSHOT" "true" || exit 1

echoInfo "INFO: Checking genesis SHA256 hash"
GENESIS_SHA256=$(globGet GENESIS_SHA256)
TEST_SHA256=$(docker exec -i "$CONTAINER_NAME" /bin/bash -c ". /etc/profile;sha256 \$SEKAID_HOME/config/genesis.json" || echo -n "")
if [ -z "$TEST_SHA256" ] || [ "$TEST_SHA256" != "$GENESIS_SHA256" ] ; then
    echoErr "ERROR: Expected genesis checksum to be '$GENESIS_SHA256' but got '$TEST_SHA256'"
    exit 1
else
    echoInfo "INFO: Genesis checksum '$TEST_SHA256' was verified sucessfully!"
fi

systemctl restart kiraclean