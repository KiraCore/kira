#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/containers/start-frontend.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 6 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 6 ) / 1024 " | bc)m"

CONTAINER_NAME="frontend"
CONTAINER_NETWORK="$KIRA_FRONTEND_NETWORK"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
COMMON_GLOB="$COMMON_PATH/kiraglob"
HALT_FILE="$COMMON_PATH/halt"

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING $CONTAINER_NAME NODE"
echoWarn "|-----------------------------------------------"
echoWarn "|   NETWORK: $KIRA_FRONTEND_NETWORK"
echoWarn "|  HOSTNAME: $KIRA_FRONTEND_DNS"
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
    $KIRAMGR_SCRIPTS/update-frontend-image.sh

    chattr -iR $COMMON_PATH || echoWarn "WARNING: Failed to remove integrity protection from $COMMON_PATH"
    # globGet frontend_health_log_old
    tryCat "$COMMON_PATH/logs/health.log" | globSet "${CONTAINER_NAME}_HEALTH_LOG_OLD"
    # globGet frontend_start_log_old
    tryCat "$COMMON_PATH/logs/start.log" | globSet "${CONTAINER_NAME}_START_LOG_OLD"
    rm -rfv "$COMMON_PATH"
    mkdir -p "$COMMON_LOGS" "$COMMON_GLOB"

    INTERNAL_HTTP_PORT="80"

    echoInfo "INFO: Starting '$CONTAINER_NAME' container..."
docker run -d \
    --cpus="$CPU_RESERVED" \
    --cap-add=SYS_PTRACE \
    --security-opt=apparmor:unconfined \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_FRONTEND_PORT:$INTERNAL_HTTP_PORT \
    --hostname $KIRA_FRONTEND_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --network $CONTAINER_NETWORK \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e EXTERNAL_HTTP_PORT="$KIRA_FRONTEND_PORT" \
    -e INTERNAL_HTTP_PORT="$INTERNAL_HTTP_PORT" \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e DEFAULT_INTERX_PORT="$DEFAULT_INTERX_PORT" \
    -e KIRA_INTERX_PORT="$KIRA_INTERX_PORT" \
    -v $COMMON_PATH:/common \
    -v $DOCKER_COMMON_RO:/common_ro:ro \
    $CONTAINER_NAME:latest

    docker network connect $KIRA_SENTRY_NETWORK $CONTAINER_NAME
else
    echoInfo "INFO: Container $CONTAINER_NAME is healthy, restarting..."
    $KIRA_MANAGER/kira/container-pkill.sh "$CONTAINER_NAME" "true" "restart"
fi

echoInfo "INFO: Waiting for frontend to start..."
$KIRAMGR_SCRIPTS/await-frontend-init.sh || exit 1

systemctl restart kiraclean
