#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/containers/start-seed.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

CONTAINER_NAME="seed"
CONTAINER_NETWORK="$KIRA_SENTRY_NETWORK"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
HALT_FILE="$COMMON_PATH/halt"
EXIT_FILE="$COMMON_PATH/exit"

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
[ "${DEPLOYMENT_MODE,,}" == "minimal" ] && UTIL_DIV=2 || UTIL_DIV=6
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / $UTIL_DIV )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / $UTIL_DIV ) / 1024 " | bc)m"

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

if (! $($KIRA_SCRIPTS/container-healthy.sh "$CONTAINER_NAME")) ; then
    echoInfo "INFO: Wiping '$CONTAINER_NAME' resources..."
    $KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

    echoInfo "INFO: Ensuring base images exist..."
    $KIRA_MANAGER/setup/registry.sh
    $KIRAMGR_SCRIPTS/update-base-image.sh
    $KIRAMGR_SCRIPTS/update-kira-image.sh

    chattr -iR $COMMON_PATH || echoWarn "WARNING: Failed to remove integrity protection from $COMMON_PATH"
    # globGet seed_health_log_old
    tryCat "$COMMON_PATH/logs/health.log" | globSet "${CONTAINER_NAME}_HEALTH_LOG_OLD"
    # globGet seed_start_log_old
    tryCat "$COMMON_PATH/logs/start.log" | globSet "${CONTAINER_NAME}_START_LOG_OLD"
    rm -rfv "$COMMON_PATH"
    mkdir -p "$COMMON_LOGS"

    echo "INFO: Loading secrets..."
    set +e
    set +x
    source $KIRAMGR_SCRIPTS/load-secrets.sh
    set -x
    set -e

    echoInfo "INFO: Setting up $CONTAINER_NAME config vars..."
    cp -afv "$KIRA_SECRETS/${CONTAINER_NAME}_node_key.json" $COMMON_PATH/node_key.json

    SNAPSHOT_SEED=$(echo "${SNAPSHOT_NODE_ID}@$KIRA_SNAPSHOT_DNS:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
    SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@$KIRA_SENTRY_DNS:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
    PRIV_SENTRY_SEED=$(echo "${PRIV_SENTRY_NODE_ID}@$KIRA_PRIV_SENTRY_DNS:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

    if [ "${INFRA_MODE,,}" == "seed" ] ; then
        CFG_persistent_peers=""
        touch "$PUBLIC_PEERS" "$PUBLIC_SEEDS" "$PRIVATE_PEERS" "$PRIVATE_SEEDS"
        if (! $(isFileEmpty $PRIVATE_PEERS)) || (! $(isFileEmpty $PRIVATE_SEEDS)) ; then
            cp -afv "$PRIVATE_PEERS" "$COMMON_PATH/peers"
            cp -afv "$PRIVATE_SEEDS" "$COMMON_PATH/seeds"
        else
            cp -afv "$PUBLIC_PEERS" "$COMMON_PATH/peers"
            cp -afv "$PUBLIC_SEEDS" "$COMMON_PATH/seeds"
        fi
    else
        CFG_persistent_peers="tcp://$SENTRY_SEED,tcp://$PRIV_SENTRY_SEED"
    fi

    CFG_addr_book_strict="false"

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
    -e CFG_moniker="KIRA ${CONTAINER_NAME^^} NODE" \
    -e CFG_pex="true" \
    -e CFG_grpc_laddr="tcp://0.0.0.0:$DEFAULT_GRPC_PORT" \
    -e CFG_rpc_laddr="tcp://0.0.0.0:$DEFAULT_RPC_PORT" \
    -e CFG_p2p_laddr="tcp://0.0.0.0:$DEFAULT_P2P_PORT" \
    -e CFG_external_address="" \
    -e CFG_seeds="" \
    -e CFG_prometheus="true" \
    -e CFG_persistent_peers="$CFG_persistent_peers" \
    -e CFG_private_peer_ids="$PRIV_SENTRY_NODE_ID" \
    -e CFG_unconditional_peer_ids="$VALIDATOR_NODE_ID,$SNAPSHOT_NODE_ID,$PRIV_SENTRY_NODE_ID,$SENTRY_NODE_ID" \
    -e CFG_addr_book_strict="$CFG_addr_book_strict" \
    -e CFG_seed_mode="true" \
    -e CFG_allow_duplicate_ip="false" \
    -e CFG_max_num_outbound_peers="64" \
    -e CFG_max_num_inbound_peers="1024" \
    -e CFG_handshake_timeout="60s" \
    -e CFG_dial_timeout="30s" \
    -e CFG_trust_period="87600h" \
    -e CFG_max_txs_bytes="131072000" \
    -e CFG_max_tx_bytes="131072" \
    -e CFG_send_rate="65536000" \
    -e CFG_recv_rate="65536000" \
    -e CFG_max_packet_msg_payload_size="131072" \
    -e MIN_HEIGHT="$(globGet MIN_HEIGHT)" \
    -e NODE_TYPE=$CONTAINER_NAME \
    -e NODE_ID="$SEED_NODE_ID" \
    -e EXTERNAL_P2P_PORT="$KIRA_SEED_P2P_PORT" \
    -e INTERNAL_P2P_PORT="$DEFAULT_P2P_PORT" \
    -e INTERNAL_RPC_PORT="$DEFAULT_RPC_PORT" \
    -e EXTERNAL_SYNC="$EXTERNAL_SYNC" \
    -e NEW_NETWORK="$NEW_NETWORK" \
    -e KIRA_SETUP_VER="$KIRA_SETUP_VER" \
    -e DEPLOYMENT_MODE="$DEPLOYMENT_MODE" \
    -e INFRA_MODE="$INFRA_MODE" \
    --env-file "$KIRA_MANAGER/containers/sekaid.env" \
    -v $COMMON_PATH:/common \
    -v $KIRA_SNAP:/snap \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    kira:latest
else
    echoInfo "INFO: Container $CONTAINER_NAME is healthy, restarting..."
    $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart"
fi

echoInfo "INFO: Waiting for $CONTAINER_NAME to start..."
$KIRAMGR_SCRIPTS/await-seed-init.sh "$CONTAINER_NAME" "$SEED_NODE_ID" || exit 1

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