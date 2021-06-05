#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

CONTAINER_NAME="validator"
CONTAINER_NETWORK="$KIRA_VALIDATOR_NETWORK"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
[ "${DEPLOYMENT_MODE,,}" == "minimal" ] && UTIL_DIV=2 || UTIL_DIV=6
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / $UTIL_DIV )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / $UTIL_DIV ) / 1024 " | bc)m"

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

if (! $($KIRA_SCRIPTS/container-healthy.sh "$CONTAINER_NAME")) ; then
    echoInfo "INFO: Wiping '$CONTAINER_NAME' resources and setting up config vars for the $DEPLOYMENT_MODE deployment mode..."
    $KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

    chattr -iR $COMMON_PATH || echoWarn "WARNING: Failed to remove integrity protection from $COMMON_PATH"
    # globGet validator_health_log_old
    tryCat "$COMMON_PATH/logs/health.log" | globSet "${CONTAINER_NAME}_HEALTH_LOG_OLD"
    # globGet validator_start_log_old
    tryCat "$COMMON_PATH/logs/start.log" | globSet "${CONTAINER_NAME}_START_LOG_OLD"
    rm -rfv "$COMMON_PATH"
    mkdir -p "$COMMON_LOGS"

    echoInfo "INFO: Ensuring base images exist..."
    $KIRA_MANAGER/setup/registry.sh
    $KIRAMGR_SCRIPTS/update-base-image.sh
    $KIRAMGR_SCRIPTS/update-kira-image.sh

    echoInfo "INFO: Loading secrets..."
    set +e
    set +x
    source $KIRAMGR_SCRIPTS/load-secrets.sh
    echo "$SIGNER_ADDR_MNEMONIC" > $COMMON_PATH/signer_addr_mnemonic.key
    echo "$FAUCET_ADDR_MNEMONIC" > $COMMON_PATH/faucet_addr_mnemonic.key
    echo "$VALIDATOR_ADDR_MNEMONIC" > $COMMON_PATH/validator_addr_mnemonic.key
    echo "$TEST_ADDR_MNEMONIC" > $COMMON_PATH/test_addr_mnemonic.key
    cp -afv $KIRA_SECRETS/priv_validator_key.json $COMMON_PATH/priv_validator_key.json
    cp -afv "$KIRA_SECRETS/${CONTAINER_NAME}_node_key.json" $COMMON_PATH/node_key.json
    set -x
    set -e

    SNAPSHOT_SEED=$(echo "${SNAPSHOT_NODE_ID}@$KIRA_SNAPSHOT_DNS:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
    SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@$KIRA_SENTRY_DNS:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
    PRIV_SENTRY_SEED=$(echo "${PRIV_SENTRY_NODE_ID}@$KIRA_PRIV_SENTRY_DNS:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
    CFG_seeds=""

    if [ "${DEPLOYMENT_MODE,,}" == "full" ] ; then    
        [ "${NEW_NETWORK,,}" == true ] && rm -fv "$COMMON_PATH/genesis.json"
        CFG_persistent_peers="tcp://$SENTRY_SEED,tcp://$PRIV_SENTRY_SEED"
        CFG_private_peer_ids="$SENTRY_NODE_ID,$PRIV_SENTRY_NODE_ID"
        CFG_unconditional_peer_ids="$SNAPSHOT_NODE_ID,$PRIV_SENTRY_NODE_ID,$SEED_NODE_ID,$SENTRY_NODE_ID"
        CFG_max_num_outbound_peers="2"
        CFG_max_num_inbound_peers="4"
        CFG_pex="false"
        CFG_allow_duplicate_ip="true"
        EXTERNAL_P2P_PORT=""
    else
        touch "$PUBLIC_PEERS" "$PUBLIC_SEEDS" "$PRIVATE_PEERS" "$PRIVATE_SEEDS"
        cat $PRIVATE_SEEDS >> $PUBLIC_SEEDS
        cat $PRIVATE_PEERS >> $PUBLIC_PEERS

        cp -afv "$PUBLIC_PEERS" "$COMMON_PATH/peers"
        cp -afv "$PUBLIC_SEEDS" "$COMMON_PATH/seeds"
        cp -afv "$DOCKER_COMMON_RO/addrbook.json" "$COMMON_PATH/addrbook.json"

        CFG_private_peer_ids=""
        CFG_unconditional_peer_ids="$SNAPSHOT_NODE_ID"
        CFG_max_num_outbound_peers="64"
        CFG_max_num_inbound_peers="256"
        CFG_persistent_peers=""
        CFG_pex="true"
        CFG_allow_duplicate_ip="true"
        EXTERNAL_P2P_PORT="$KIRA_VALIDATOR_P2P_PORT"
    fi

    echoInfo "INFO: Starting '$CONTAINER_NAME' container..."
docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_VALIDATOR_P2P_PORT:$DEFAULT_P2P_PORT \
    -p $KIRA_VALIDATOR_RPC_PORT:$DEFAULT_RPC_PORT \
    -p $KIRA_VALIDATOR_GRPC_PORT:$DEFAULT_GRPC_PORT \
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
    -e CFG_moniker="KIRA ${CONTAINER_NAME^^} NODE" \
    -e CFG_grpc_laddr="tcp://0.0.0.0:$DEFAULT_GRPC_PORT" \
    -e CFG_rpc_laddr="tcp://0.0.0.0:$DEFAULT_RPC_PORT" \
    -e CFG_p2p_laddr="tcp://0.0.0.0:$DEFAULT_P2P_PORT" \
    -e CFG_private_peer_ids="$CFG_private_peer_ids" \
    -e CFG_seeds="$CFG_seeds" \
    -e CFG_persistent_peers="$CFG_persistent_peers" \
    -e CFG_unconditional_peer_ids="$CFG_unconditional_peer_ids" \
    -e CFG_max_num_outbound_peers="$CFG_max_num_outbound_peers" \
    -e CFG_max_num_inbound_peers="$CFG_max_num_inbound_peers" \
    -e CFG_timeout_commit="5s" \
    -e CFG_create_empty_blocks_interval="10s" \
    -e CFG_addr_book_strict="false" \
    -e CFG_seed_mode="false" \
    -e CFG_skip_timeout_commit="false" \
    -e CFG_allow_duplicate_ip="$CFG_allow_duplicate_ip" \
    -e CFG_handshake_timeout="60s" \
    -e CFG_dial_timeout="30s" \
    -e CFG_max_txs_bytes="131072000" \
    -e CFG_send_rate="65536000" \
    -e CFG_recv_rate="65536000" \
    -e CFG_max_tx_bytes="131072" \
    -e CFG_max_packet_msg_payload_size="131072" \
    -e SETUP_VER="$KIRA_SETUP_VER" \
    -e CFG_pex="$CFG_pex" \
    -e CFG_prometheus="true" \
    -e EXTERNAL_P2P_PORT="$EXTERNAL_P2P_PORT" \
    -e INTERNAL_P2P_PORT="$DEFAULT_P2P_PORT" \
    -e INTERNAL_RPC_PORT="$DEFAULT_RPC_PORT" \
    -e CFG_trust_period="87600h" \
    -e NEW_NETWORK="$NEW_NETWORK" \
    -e EXTERNAL_SYNC="$EXTERNAL_SYNC" \
    -e NODE_TYPE="$CONTAINER_NAME" \
    -e NODE_ID="$VALIDATOR_NODE_ID" \
    -e MIN_HEIGHT="$(globGet MIN_HEIGHT)" \
    -e DEPLOYMENT_MODE="$DEPLOYMENT_MODE" \
    -e INFRA_MODE="$INFRA_MODE" \
    --env-file "$KIRA_MANAGER/containers/sekaid.env" \
    -v $COMMON_PATH:/common \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    kira:latest
else
    echoInfo "INFO: Container $CONTAINER_NAME is healthy, restarting..."
    $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart"
fi

mkdir -p $INTERX_REFERENCE_DIR
if [ "${NEW_NETWORK,,}" == true ] ; then
    chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "WARNINIG: Genesis file was NOT found in the local direcotry"
    chattr -i "$INTERX_REFERENCE_DIR/genesis.json" || echoWarn "WARNINIG: Genesis file was NOT found in the reference direcotry"
    rm -fv $LOCAL_GENESIS_PATH "$INTERX_REFERENCE_DIR/genesis.json"
fi
echoInfo "INFO: Waiting for $CONTAINER_NAME to start and import or produce genesis..."
$KIRAMGR_SCRIPTS/await-validator-init.sh "$VALIDATOR_NODE_ID" || exit 1

[ ! -f "$LOCAL_GENESIS_PATH" ] && echoErr "ERROR: Genesis file was NOT created" && exit 1

if [ "${NEW_NETWORK,,}" == true ] ; then
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
TEST_SHA256=$(docker exec -i "$CONTAINER_NAME" /bin/bash -c ". /etc/profile;sha256 \$SEKAID_HOME/config/genesis.json" || echo -n "")
if [ -z "$TEST_SHA256" ] || [ "$TEST_SHA256" != "$(globGet GENESIS_SHA256)" ] ; then
    echoErr "ERROR: Expected genesis checksum to be '$GENESIS_SHA256' but got '$TEST_SHA256'"
    exit 1
else
    echoInfo "INFO: Genesis checksum '$TEST_SHA256' was verified sucessfully!"
fi

systemctl restart kiraclean
