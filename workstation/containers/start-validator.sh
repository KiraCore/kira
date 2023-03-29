#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/containers/start-validator.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

CONTAINER_NAME="validator"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
APP_HOME="$DOCKER_HOME/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
GLOBAL_COMMON="$COMMON_PATH/kiraglob"
KIRA_HOSTNAME="${CONTAINER_NAME}.local"
KIRA_DOCKER_NETWORK="$(globGet KIRA_DOCKER_NETWORK)"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 2 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 2 ) / 1024 " | bc)m"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING $CONTAINER_NAME NODE"
echoWarn "|-----------------------------------------------"
echoWarn "|   NETWORK: $KIRA_DOCKER_NETWORK"
echoWarn "|   NODE ID: $VALIDATOR_NODE_ID"
echoWarn "|  HOSTNAME: $KIRA_HOSTNAME"
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
    mkdir -p "$COMMON_LOGS" "$GLOBAL_COMMON" "$APP_HOME"

    echoInfo "INFO: Loading secrets..."
    set +x
    source $KIRAMGR_SCRIPTS/load-secrets.sh
    echo "$SIGNER_ADDR_MNEMONIC" > $COMMON_PATH/signer_addr_mnemonic.key
    echo "$VALIDATOR_ADDR_MNEMONIC" > $COMMON_PATH/validator_addr_mnemonic.key
    echo "$TEST_ADDR_MNEMONIC" > $COMMON_PATH/test_addr_mnemonic.key
    cp -afv $KIRA_SECRETS/priv_validator_key.json $COMMON_PATH/priv_validator_key.json
    cp -afv "$KIRA_SECRETS/${CONTAINER_NAME}_node_key.json" $COMMON_PATH/node_key.json
    set -x

    # ensure all data is cleaned up before container is launched
    if [ "$(globGet NEW_NETWORK)" == "true" ] ; then
        rm -fv "$COMMON_PATH/genesis.json"
        globDel "sentry_SEKAID_STATUS" "validator_SEKAID_STATUS" "seed_SEKAID_STATUS" "interx_SEKAID_STATUS"
        rm -fv "$(globFile validator_SEKAID_STATUS)" "$(globFile sentry_SEKAID_STATUS)" "$(globFile seed_SEKAID_STATUS)" "$(globFile interx_SEKAID_STATUS)"
        globSet MIN_HEIGHT "0" $GLOBAL_COMMON_RO
        globSet LATEST_BLOCK_TIME "" $GLOBAL_COMMON_RO
        globSet LATEST_BLOCK_HEIGHT "0" $GLOBAL_COMMON_RO
    fi

    touch "$PUBLIC_PEERS" "$PUBLIC_SEEDS"
    cp -arfv "$KIRA_INFRA/kira/." "$COMMON_PATH"

    if [ "$(globGet INIT_MODE)" == "upgrade" ] ; then
        UPGRADE_INSTATE=$(globGet UPGRADE_INSTATE)
        if [ "$UPGRADE_INSTATE" == "true" ] ; then
            UPGRADE_MODE="soft"
        else
            UPGRADE_MODE="hard"
        fi
    else
        UPGRADE_MODE="none"
        rm -rfv "$APP_HOME" "$GLOBAL_COMMON"
        mkdir -p "$APP_HOME" "$GLOBAL_COMMON"

        cp -afv "$PUBLIC_PEERS" "$COMMON_PATH/peers"
        cp -afv "$PUBLIC_SEEDS" "$COMMON_PATH/seeds"

        ####################################################################################
        # ref.: https://www.notion.so/kira-network/app-toml-68c3c5c890904752a78c63a8b63aaf4a
        # APP [state_sync]
        globSet app_state_sync_snapshot_interval "0" $GLOBAL_COMMON
        globSet app_base_pruning "custom" $GLOBAL_COMMON
        globSet app_base_pruning_keep_recent "100" $GLOBAL_COMMON
        globSet app_base_pruning_keep_every "0" $GLOBAL_COMMON
        globSet app_base_pruning_interval "10" $GLOBAL_COMMON
        ####################################################################################
        # ref.: https://www.notion.so/kira-network/config-toml-4dc4c7ace16c4316bfc06dad6e2d15c2
        # CFG [base]
        globSet cfg_base_moniker "$(toUpper "KIRA $CONTAINER_NAME NODE")" $GLOBAL_COMMON
        globSet cfg_base_fast_sync "true" $GLOBAL_COMMON
        # CFG [FASTSYNC]
        globSet cfg_fastsync_version "v1" $GLOBAL_COMMON
        # CFG [TRUST]
        globSet cfg_trust_period "87600h" $GLOBAL_COMMON
        # CFG [MEMPOOL]
        globSet cfg_mempool_max_txs_bytes "131072000" $GLOBAL_COMMON
        globSet cfg_mempool_max_tx_bytes "131072" $GLOBAL_COMMON
        # CFG [STATESYNC]
        globSet cfg_statesync_enable "true" $GLOBAL_COMMON
        globSet cfg_statesync_temp_dir "/tmp" $GLOBAL_COMMON
        # CFG [CONSENSUS]
        globSet cfg_consensus_timeout_commit "7500ms" $GLOBAL_COMMON
        globSet cfg_consensus_create_empty_blocks_interval "10s" $GLOBAL_COMMON
        globSet cfg_consensus_skip_timeout_commit "false" $GLOBAL_COMMON
        # CFG [INSTRUMENTATION]
        globSet cfg_instrumentation_prometheus "true" $GLOBAL_COMMON
        # CFG [P2P]
        globSet cfg_p2p_pex "true" $GLOBAL_COMMON
        globSet cfg_p2p_private_peer_ids "" $GLOBAL_COMMON
        globSet cfg_p2p_unconditional_peer_ids "$SENTRY_NODE_ID,$SEED_NODE_ID,$VALIDATOR_NODE_ID" $GLOBAL_COMMON
        globSet cfg_p2p_persistent_peers "" $GLOBAL_COMMON
        globSet cfg_p2p_seeds "" $GLOBAL_COMMON
        globSet cfg_p2p_laddr "tcp://0.0.0.0:$(globGet DEFAULT_P2P_PORT)" $GLOBAL_COMMON
        globSet cfg_p2p_seed_mode "false" $GLOBAL_COMMON
        globSet cfg_p2p_max_num_outbound_peers "32" $GLOBAL_COMMON
        globSet cfg_p2p_max_num_inbound_peers "128" $GLOBAL_COMMON
        globSet cfg_p2p_send_rate "65536000" $GLOBAL_COMMON
        globSet cfg_p2p_recv_rate "65536000" $GLOBAL_COMMON
        globSet cfg_p2p_max_packet_msg_payload_size "131072" $GLOBAL_COMMON
        globSet cfg_p2p_handshake_timeout "60s" $GLOBAL_COMMON
        globSet cfg_p2p_dial_timeout "30s" $GLOBAL_COMMON
        globSet cfg_p2p_allow_duplicate_ip "true" $GLOBAL_COMMON
        globSet cfg_p2p_addr_book_strict "false" $GLOBAL_COMMON
        # CFG [RPC]
        globSet cfg_rpc_laddr "tcp://0.0.0.0:$(globGet DEFAULT_RPC_PORT)" $GLOBAL_COMMON
        globSet cfg_rpc_cors_allowed_origins "[ \"*\" ]" $GLOBAL_COMMON
        ####################################################################################
    fi

    globSet PRIVATE_MODE "$(globGet PRIVATE_MODE)" $GLOBAL_COMMON
    globSet NEW_NETWORK "$(globGet NEW_NETWORK)" $GLOBAL_COMMON
    globSet INIT_DONE "false" $GLOBAL_COMMON

    BASE_IMAGE_SRC=$(globGet BASE_IMAGE_SRC)
    echoInfo "INFO: Starting '$CONTAINER_NAME' container from '$BASE_IMAGE_SRC'..."
docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p "$(globGet CUSTOM_P2P_PORT):$(globGet DEFAULT_P2P_PORT)" \
    -p "$(globGet CUSTOM_RPC_PORT):$(globGet DEFAULT_RPC_PORT)" \
    -p "$(globGet CUSTOM_PROMETHEUS_PORT):$(globGet DEFAULT_PROMETHEUS_PORT)" \
    --hostname "$KIRA_HOSTNAME" \
    --restart=always \
    --name "$CONTAINER_NAME" \
    --net="$KIRA_DOCKER_NETWORK" \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e UPGRADE_MODE="$UPGRADE_MODE" \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e HOSTNAME="$KIRA_HOSTNAME" \
    -e EXTERNAL_P2P_PORT="$(globGet CUSTOM_P2P_PORT)" \
    -e INTERNAL_P2P_PORT="$(globGet DEFAULT_P2P_PORT)" \
    -e INTERNAL_RPC_PORT="$(globGet DEFAULT_RPC_PORT)" \
    -e NODE_TYPE="$CONTAINER_NAME" \
    -e NODE_ID="$VALIDATOR_NODE_ID" \
    -v $COMMON_PATH:/common \
    -v $KIRA_SNAP:/snap \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    -v $APP_HOME:/$SEKAID_HOME \
    $BASE_IMAGE_SRC
else
    echoInfo "INFO: Container $CONTAINER_NAME is healthy, restarting..."
    $KIRA_MANAGER/kira/container-pkill.sh --name="$CONTAINER_NAME" --await="true" --task="restart" --unhalt="true"
fi

echoInfo "INFO: Waiting for $CONTAINER_NAME to start and import or produce genesis..."
$KIRAMGR_SCRIPTS/await-validator-init.sh "$VALIDATOR_NODE_ID"

[ ! -f "$LOCAL_GENESIS_PATH" ] && echoErr "ERROR: Genesis file was NOT created" && exit 1

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