#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

CPU_CORES=$(cat /proc/cpuinfo | grep processor | wc -l || echo "0")
RAM_MEMORY=$(grep MemTotal /proc/meminfo | awk '{print $2}' || echo "0")
CPU_RESERVED=$(echo "scale=2; ( $CPU_CORES / 4 )" | bc)
RAM_RESERVED="$(echo "scale=0; ( $RAM_MEMORY / 4 ) / 1024 " | bc)m"

CONTAINER_NAME="frontend"
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NETWORK: $KIRA_FRONTEND_NETWORK"
echo "|  HOSTNAME: $KIRA_FRONTEND_DNS"
echo "|   MAX CPU: $CPU_RESERVED / $CPU_CORES"
echo "|   MAX RAM: $RAM_RESERVED"
echo "------------------------------------------------"
set -x

docker run -d \
    --cpus="$CPU_RESERVED" \
    --memory="$RAM_RESERVED" \
    --oom-kill-disable \
    -p $KIRA_FRONTEND_PORT:80 \
    --hostname $KIRA_FRONTEND_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --network $KIRA_FRONTEND_NETWORK \
    -e NETWORK_NAME="$NETWORK_NAME" \
    $CONTAINER_NAME:latest

docker network connect $KIRA_SENTRY_NETWORK $CONTAINER_NAME

echo "INFO: Waiting for frontend to start..."
$KIRAMGR_SCRIPTS/await-frontend-init.sh || exit 1

$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_SENTRY_NETWORK"
$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_FRONTEND_NETWORK"

