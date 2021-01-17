#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

CONTAINER_NAME="frontend"
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NETWORK: $KIRA_FRONTEND_NETWORK"
echo "|  HOSTNAME: $KIRA_FRONTEND_DNS"
echo "------------------------------------------------"
set -x

docker run -d \
    -p 80:$KIRA_FRONTEND_PORT \
    --hostname $KIRA_FRONTEND_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --network $KIRA_FRONTEND_NETWORK \
    -e DEBUG_MODE="True" \
    -e NETWORK_NAME="$NETWORK_NAME" \
    $CONTAINER_NAME:latest

docker network connect $KIRA_SENTRY_NETWORK $CONTAINER_NAME

echo "INFO: Waiting for frontend to start..."
$KIRAMGR_SCRIPTS/await-frontend-init.sh || exit 1

$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_SENTRY_NETWORK"
$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_FRONTEND_NETWORK"

