#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/containers/start-interx.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 2 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 2 ) / 1024 " | bc)m"

CONTAINER_NAME="interx"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
COMMON_GLOB="$COMMON_PATH/kiraglob"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING $CONTAINER_NAME NODE"
echoWarn "|-----------------------------------------------"
echoWarn "|   NODE ID: $SENTRY_NODE_ID"
echoWarn "|  HOSTNAME: $KIRA_INTERX_DNS"
echoWarn "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echoWarn "|   MAX RAM: $RAM_RESERVED"
echoWarn "------------------------------------------------"
set -x

globSet "${CONTAINER_NAME}_STARTED" "false"

if (! $($KIRA_SCRIPTS/container-healthy.sh "$CONTAINER_NAME")) ; then
    echoInfo "INFO: Wiping '$CONTAINER_NAME' resources and setting up config vars..."
    $KIRA_SCRIPTS/container-delete.sh "$CONTAINER_NAME"

    chattr -iR $COMMON_PATH || echoWarn "WARNING: Failed to remove integrity protection from $COMMON_PATH"
    # globGet interx_health_log_old
    tryCat "$COMMON_PATH/logs/health.log" | globSet "${CONTAINER_NAME}_HEALTH_LOG_OLD"
    # globGet interx_start_log_old
    tryCat "$COMMON_PATH/logs/start.log" | globSet "${CONTAINER_NAME}_START_LOG_OLD"
    rm -rfv "$COMMON_PATH"
    mkdir -p "$COMMON_LOGS" "$COMMON_GLOB"

    echoInfo "INFO: Loading secrets..."
    set +x
    set +e
    source $KIRAMGR_SCRIPTS/load-secrets.sh
    echo "$SIGNER_ADDR_MNEMONIC" > "$COMMON_PATH/signing.mnemonic"
    set -e
    set -x

    cp -arfv "$KIRA_INFRA/kira/." "$COMMON_PATH"

    CONTAINER_NETWORK="$KIRA_INTERX_NETWORK"
    globSet seed_node_id "$SEED_NODE_ID" $COMMON_GLOB
    globSet sentry_node_id "$SENTRY_NODE_ID" $COMMON_GLOB
    globSet validator_node_id "$VALIDATOR_NODE_ID" $COMMON_GLOB
    globSet KIRA_ADDRBOOK "" $COMMON_GLOB

    echoInfo "INFO: Starting '$CONTAINER_NAME' container..."
docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_INTERX_PORT:$DEFAULT_INTERX_PORT \
    --hostname $KIRA_INTERX_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$CONTAINER_NETWORK \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e INTERNAL_API_PORT="$DEFAULT_INTERX_PORT" \
    -e EXTERNAL_API_PORT="$KIRA_INTERX_PORT" \
    -e PING_TARGET="${INFRA_MODE,,}.local" \
    -e DEFAULT_GRPC_PORT="$DEFAULT_GRPC_PORT" \
    -e DEFAULT_RPC_PORT="$DEFAULT_RPC_PORT" \
    -v $COMMON_PATH:/common \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    ghcr.io/kiracore/docker/kira-base:$KIRA_BASE_VERSION
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