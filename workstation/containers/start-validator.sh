#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/containers/start-validator.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

CONTAINER_NAME="validator"
CONTAINER_NETWORK="$KIRA_SENTRY_NETWORK"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
GLOBAL_COMMON="$COMMON_PATH/kiraglob"

NEW_NETWORK=$(globGet NEW_NETWORK)
CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 2 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 2 ) / 1024 " | bc)m"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING $CONTAINER_NAME NODE"
echoWarn "|-----------------------------------------------"
echoWarn "|   NETWORK: $CONTAINER_NETWORK"
echoWarn "|   NODE ID: $VALIDATOR_NODE_ID"
echoWarn "|  HOSTNAME: $KIRA_VALIDATOR_DNS"
echoWarn "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echoWarn "|   MAX RAM: $RAM_RESERVED"
echoWarn "------------------------------------------------"
set -x

globSet "${CONTAINER_NAME}_STARTED" "false"

if (! $($KIRA_COMMON/container-healthy.sh "$CONTAINER_NAME")) ; then
    echoInfo "INFO: Wiping '$CONTAINER_NAME' resources and setting up config vars..."
    $KIRA_COMMON/container-delete.sh "$CONTAINER_NAME"

    chattr -iR $COMMON_PATH || echoWarn "WARNING: Failed to remove integrity protection from $COMMON_PATH"
    # globGet validator_health_log_old
    tryCat "$COMMON_PATH/logs/health.log" | globSet "${CONTAINER_NAME}_HEALTH_LOG_OLD"
    # globGet validator_start_log_old
    tryCat "$COMMON_PATH/logs/start.log" | globSet "${CONTAINER_NAME}_START_LOG_OLD"
    rm -rfv "$COMMON_PATH"
    mkdir -p "$COMMON_LOGS" "$GLOBAL_COMMON"

    echoInfo "INFO: Loading secrets..."
    set +e
    set +x
    source $KIRAMGR_SCRIPTS/load-secrets.sh
    echo "$SIGNER_ADDR_MNEMONIC" > $COMMON_PATH/signer_addr_mnemonic.key
    echo "$VALIDATOR_ADDR_MNEMONIC" > $COMMON_PATH/validator_addr_mnemonic.key
    echo "$TEST_ADDR_MNEMONIC" > $COMMON_PATH/test_addr_mnemonic.key
    cp -afv $KIRA_SECRETS/priv_validator_key.json $COMMON_PATH/priv_validator_key.json
    cp -afv "$KIRA_SECRETS/${CONTAINER_NAME}_node_key.json" $COMMON_PATH/node_key.json
    set -x
    set -e

    SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@$KIRA_SENTRY_DNS:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

    [ "${NEW_NETWORK,,}" == "true" ] && rm -fv "$COMMON_PATH/genesis.json"

    touch "$PUBLIC_PEERS" "$PUBLIC_SEEDS"

    cp -afv "$PUBLIC_PEERS" "$COMMON_PATH/peers"
    cp -afv "$PUBLIC_SEEDS" "$COMMON_PATH/seeds"
    cp -arfv "$KIRA_INFRA/kira/." "$COMMON_PATH"

    EXTERNAL_P2P_PORT="$KIRA_VALIDATOR_P2P_PORT"

    globSet CFG_moniker "KIRA ${CONTAINER_NAME^^} NODE" $GLOBAL_COMMON
    globSet CFG_pex "true" $GLOBAL_COMMON
    # true
    globSet CFG_allow_duplicate_ip "true" $GLOBAL_COMMON
    globSet CFG_addr_book_strict "false" $GLOBAL_COMMON
    globSet CFG_fastsync "true" $GLOBAL_COMMON
    globSet CFG_fastsync_version "v1" $GLOBAL_COMMON

    globSet CFG_handshake_timeout "60s" $GLOBAL_COMMON
    globSet CFG_dial_timeout "30s" $GLOBAL_COMMON
    globSet CFG_trust_period "87600h" $GLOBAL_COMMON
    globSet CFG_max_txs_bytes "131072000" $GLOBAL_COMMON
    globSet CFG_max_tx_bytes "131072" $GLOBAL_COMMON
    globSet CFG_send_rate "65536000" $GLOBAL_COMMON
    globSet CFG_recv_rate "65536000" $GLOBAL_COMMON
    globSet CFG_max_packet_msg_payload_size "131072" $GLOBAL_COMMON
    globSet CFG_cors_allowed_origins "*" $GLOBAL_COMMON
    globSet CFG_snapshot_interval "1000" $GLOBAL_COMMON
    globSet CFG_statesync_enable "true" $GLOBAL_COMMON
    globSet CFG_statesync_temp_dir "/tmp" $GLOBAL_COMMON
    globSet CFG_timeout_commit "7500ms" $GLOBAL_COMMON
    globSet CFG_create_empty_blocks_interval "10s" $GLOBAL_COMMON
    globSet CFG_max_num_outbound_peers "32" $GLOBAL_COMMON
    globSet CFG_max_num_inbound_peers "128" $GLOBAL_COMMON
    globSet CFG_prometheus "true" $GLOBAL_COMMON
    globSet CFG_seed_mode "false" $GLOBAL_COMMON
    globSet CFG_skip_timeout_commit "false" $GLOBAL_COMMON

    globSet CFG_private_peer_ids "" $GLOBAL_COMMON
    globSet CFG_unconditional_peer_ids "$SENTRY_NODE_ID,$SEED_NODE_ID,$VALIDATOR_NODE_ID" $GLOBAL_COMMON
    globSet CFG_persistent_peers "" $GLOBAL_COMMON
    globSet CFG_seeds "" $GLOBAL_COMMON
    globSet CFG_grpc_laddr "tcp://0.0.0.0:$DEFAULT_GRPC_PORT" $GLOBAL_COMMON
    globSet CFG_rpc_laddr "tcp://0.0.0.0:$DEFAULT_RPC_PORT" $GLOBAL_COMMON
    globSet CFG_p2p_laddr "tcp://0.0.0.0:$DEFAULT_P2P_PORT" $GLOBAL_COMMON

    globSet PRIVATE_MODE "$(globGet PRIVATE_MODE)" $GLOBAL_COMMON
    globSet NEW_NETWORK "$NEW_NETWORK" $GLOBAL_COMMON

    echoInfo "INFO: Starting '$CONTAINER_NAME' container..."
docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_VALIDATOR_P2P_PORT:$DEFAULT_P2P_PORT \
    -p $KIRA_VALIDATOR_RPC_PORT:$DEFAULT_RPC_PORT \
    -p $KIRA_VALIDATOR_PROMETHEUS_PORT:$DEFAULT_PROMETHEUS_PORT \
    --hostname "$KIRA_VALIDATOR_DNS" \
    --restart=always \
    --name "$CONTAINER_NAME" \
    --net="$CONTAINER_NETWORK" \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e HOSTNAME="$KIRA_VALIDATOR_DNS" \
    -e CONTAINER_NETWORK="$CONTAINER_NETWORK" \
    -e EXTERNAL_P2P_PORT="$EXTERNAL_P2P_PORT" \
    -e INTERNAL_P2P_PORT="$DEFAULT_P2P_PORT" \
    -e INTERNAL_RPC_PORT="$DEFAULT_RPC_PORT" \
    -e NODE_TYPE="$CONTAINER_NAME" \
    -e NODE_ID="$VALIDATOR_NODE_ID" \
    -v $COMMON_PATH:/common \
    -v $KIRA_SNAP:/snap \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    ghcr.io/kiracore/docker/kira-base:$KIRA_BASE_VERSION
else
    echoInfo "INFO: Container $CONTAINER_NAME is healthy, restarting..."
    $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart" "true"
fi

mkdir -p $INTERX_REFERENCE_DIR
if [ "${NEW_NETWORK,,}" == "true" ] ; then
    chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "WARNINIG: Genesis file was NOT found in the local direcotry"
    chattr -i "$INTERX_REFERENCE_DIR/genesis.json" || echoWarn "WARNINIG: Genesis file was NOT found in the reference direcotry"
    rm -fv $LOCAL_GENESIS_PATH "$INTERX_REFERENCE_DIR/genesis.json"
fi
echoInfo "INFO: Waiting for $CONTAINER_NAME to start and import or produce genesis..."
$KIRAMGR_SCRIPTS/await-validator-init.sh "$VALIDATOR_NODE_ID"

[ ! -f "$LOCAL_GENESIS_PATH" ] && echoErr "ERROR: Genesis file was NOT created" && exit 1

if [ "${NEW_NETWORK,,}" == "true" ] ; then
    echoInfo "INFO: New network was created, saving genesis to common read only directory..."
    chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "WARNINIG: Genesis file was NOT found in the local direcotry"
    chattr -i "$INTERX_REFERENCE_DIR/genesis.json" || echoWarn "WARNINIG: Genesis file was NOT found in the reference direcotry"
    rm -fv "$INTERX_REFERENCE_DIR/genesis.json"
    ln -fv $LOCAL_GENESIS_PATH "$INTERX_REFERENCE_DIR/genesis.json"
    chattr +i "$INTERX_REFERENCE_DIR/genesis.json"
    GENESIS_SHA256=$(sha256 $LOCAL_GENESIS_PATH)
    globSet GENESIS_SHA256 "$GENESIS_SHA256"
fi

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