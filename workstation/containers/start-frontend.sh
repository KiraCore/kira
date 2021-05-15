#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 6 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 6 ) / 1024 " | bc)m"

CONTAINER_NAME="frontend"
CONTAINER_NETWORK="$KIRA_FRONTEND_NETWORK"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
COMMON_LOGS="$COMMON_PATH/logs"
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

    chattr -iR $COMMON_PATH || echoWarn "WARNING: Failed to remove integrity protection from $COMMON_PATH"
    rm -rfv "$COMMON_PATH"
    mkdir -p "$COMMON_LOGS"

    echoInfo "INFO: Starting '$CONTAINER_NAME' container..."
docker run -d \
    --cpus="$CPU_RESERVED" \
    --cap-add=SYS_PTRACE \
    --security-opt=apparmor:unconfined \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_FRONTEND_PORT:80 \
    --hostname $KIRA_FRONTEND_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --network $CONTAINER_NETWORK \
    --log-opt max-size=5m \
    --log-opt max-file=5 \
    -e NETWORK_NAME="$NETWORK_NAME" \
    -e KIRA_SETUP_VER="$KIRA_SETUP_VER" \
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
