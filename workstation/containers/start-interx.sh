#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/containers/start-interx.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 2 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 2 ) / 1024 " | bc)m"

CONTAINER_NAME="interx"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
APP_HOME="$DOCKER_HOME/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
GLOBAL_COMMON="$COMMON_PATH/kiraglob"
KIRA_HOSTNAME="${CONTAINER_NAME}.local"
KIRA_DOCEKR_NETWORK="$(globGet KIRA_DOCEKR_NETWORK)"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING $CONTAINER_NAME NODE"
echoWarn "|-----------------------------------------------"
echoWarn "|   NODE ID: $SENTRY_NODE_ID"
echoWarn "|  HOSTNAME: $KIRA_HOSTNAME"
echoWarn "|   NETWORK: $KIRA_DOCEKR_NETWORK"
echoWarn "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echoWarn "|   MAX RAM: $RAM_RESERVED"
echoWarn "------------------------------------------------"
set -x

globSet "${CONTAINER_NAME}_STARTED" "false"

echoInfo "INFO: Updating genesis reference file..."
chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "WARNINIG: Genesis file was NOT found in the local direcotry"
chattr -i "$INTERX_REFERENCE_DIR/genesis.json" || echoWarn "WARNINIG: Genesis file was NOT found in the reference direcotry"
rm -fv "$INTERX_REFERENCE_DIR/genesis.json"
ln -fv $LOCAL_GENESIS_PATH "$INTERX_REFERENCE_DIR/genesis.json"
chattr +i "$INTERX_REFERENCE_DIR/genesis.json"
chattr +i "$LOCAL_GENESIS_PATH"

if (! $($KIRA_COMMON/container-healthy.sh "$CONTAINER_NAME")) ; then
    echoInfo "INFO: Wiping '$CONTAINER_NAME' resources and setting up config vars..."
    $KIRA_COMMON/container-delete.sh "$CONTAINER_NAME"

    chattr -iR $COMMON_PATH || echoWarn "WARNING: Failed to remove integrity protection from $COMMON_PATH"
    # globGet interx_health_log_old
    tryCat "$COMMON_PATH/logs/health.log" | globSet "${CONTAINER_NAME}_HEALTH_LOG_OLD"
    # globGet interx_start_log_old
    tryCat "$COMMON_PATH/logs/start.log" | globSet "${CONTAINER_NAME}_START_LOG_OLD"
    rm -rfv "$COMMON_PATH" "$APP_HOME"
    mkdir -p "$COMMON_LOGS" "$GLOBAL_COMMON" "$APP_HOME"

    echoInfo "INFO: Loading secrets..."
    set +x
    source $KIRAMGR_SCRIPTS/load-secrets.sh
    echo "$SIGNER_ADDR_MNEMONIC" > "$COMMON_PATH/signing.mnemonic"
    set -x

    cp -arfv "$KIRA_INFRA/kira/." "$COMMON_PATH"

    globSet "cfg_node_node_type" "$(globGet INFRA_MODE)" $GLOBAL_COMMON
    [ "$(globGet INFRA_MODE)" == "seed" ] && globSet "cfg_node_seed_node_id" "$SEED_NODE_ID" $GLOBAL_COMMON
    [ "$(globGet INFRA_MODE)" == "sentry" ] && globSet "cfg_node_sentry_node_id" "$SENTRY_NODE_ID" $GLOBAL_COMMON
    [ "$(globGet INFRA_MODE)" == "validator" ] && globSet "cfg_node_validator_node_id" "$VALIDATOR_NODE_ID" $GLOBAL_COMMON

    globSet KIRA_ADDRBOOK "" $GLOBAL_COMMON
    globSet PRIVATE_MODE "$(globGet PRIVATE_MODE)" $GLOBAL_COMMON
    globSet NEW_NETWORK "$(globGet NEW_NETWORK)" $GLOBAL_COMMON
    globSet INIT_DONE "false" $GLOBAL_COMMON

    BASE_IMAGE_SRC=$(globGet BASE_IMAGE_SRC)
    echoInfo "INFO: Starting '$CONTAINER_NAME' container from '$BASE_IMAGE_SRC'..."
docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $(globGet CUSTOM_INTERX_PORT):$(globGet DEFAULT_INTERX_PORT) \
    --hostname "$KIRA_HOSTNAME" \
    --restart=always \
    --name $CONTAINER_NAME \
    --net="$KIRA_DOCEKR_NETWORK" \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e NODE_TYPE="$CONTAINER_NAME" \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e DOCKER_NETWORK="$KIRA_DOCEKR_NETWORK" \
    -e INTERNAL_API_PORT="$(globGet DEFAULT_INTERX_PORT)" \
    -e EXTERNAL_API_PORT="$(globGet CUSTOM_INTERX_PORT)" \
    -e INFRA_MODE="$(globGet INFRA_MODE)" \
    -e PING_TARGET="$(globGet INFRA_MODE).local" \
    -e DEFAULT_GRPC_PORT="$(globGet DEFAULT_GRPC_PORT)" \
    -e DEFAULT_RPC_PORT="$(globGet DEFAULT_RPC_PORT)" \
    -v $COMMON_PATH:/common \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    -v $APP_HOME:/$INTERXD_HOME \
    $BASE_IMAGE_SRC
else
    echoInfo "INFO: Container $CONTAINER_NAME is healthy, restarting..."
    $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart" "true"
fi

echoInfo "INFO: Waiting for interx to start..."
$KIRAMGR_SCRIPTS/await-interx-init.sh

globSet "${CONTAINER_NAME}_STARTED" "true"

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: STARTING $CONTAINER_NAME NODE"
echoWarn "------------------------------------------------"
set -x