#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

NETWORK="servicenet"
echo "------------------------------------------------"
echo "| STARTING FRONTEND NODE"
echo "|-----------------------------------------------"
echo "|        IP: $KIRA_FRONTEND_IP"
echo "|   NETWORK: $NETWORK"
echo "|  HOSTNAME: $KIRA_FRONTEND_DNS"
echo "------------------------------------------------"
set -x

docker run -d \
    -p 80:$KIRA_FRONTEND_PORT \
    --hostname $KIRA_FRONTEND_DNS \
    --restart=always \
    --name frontend \
    --network $NETWORK \
    --ip $KIRA_FRONTEND_IP \
    -e DEBUG_MODE="True" \
    frontend:latest

docker network connect sentrynet frontend

echo "INFO: Waiting for frontend to start..."
$KIRAMGR_SCRIPTS/await-frontend-init.sh || exit 1
