#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

CONTAINER_NAME="frontend"
DNS1=$KIRA_FRONTEND_DNS
DNS2="${CONTAINER_NAME,,}${KIRA_SENTRY_NETWORK,,}.local"
echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NETWORK: $KIRA_FRONTEND_NETWORK"
echo "|  HOSTNAME: $DNS1"
echo "------------------------------------------------"
set -x

docker run -d \
    -p 80:$KIRA_FRONTEND_PORT \
    --hostname $DNS1 \
    --restart=always \
    --name $CONTAINER_NAME \
    --network $KIRA_FRONTEND_NETWORK \
    -e DEBUG_MODE="True" \
    frontend:latest

docker network connect $KIRA_SENTRY_NETWORK $CONTAINER_NAME

echo "INFO: Waiting for frontend to start..."
$KIRAMGR_SCRIPTS/await-frontend-init.sh || exit 1

ID=$(docker inspect --format="{{.Id}}" $CONTAINER_NAME || echo "")
IP=$(docker inspect $ID | jq -r ".[0].NetworkSettings.Networks.$KIRA_FRONTEND_NETWORK.IPAddress" | xargs || echo "")
IP2=$(docker inspect $ID| jq -r ".[0].NetworkSettings.Networks.$KIRA_SENTRY_NETWORK.IPAddress" | xargs || echo "")

if [ -z "$IP" ] || [ "${IP,,}" == "null" ] || [ -z "$IP2" ] || [ "${IP2,,}" == "null" ] ; then
    echo "ERROR: Failed to get IP address of the $CONTAINER_NAME container"
    exit 1
fi

echo "INFO: IP Address found, binding host..."
CDHelper text lineswap --insert="$IP $DNS1" --regex="$DNS1" --path=$HOSTS_PATH --prepend-if-found-not=True
CDHelper text lineswap --insert="$IP $DNS2" --regex="$DNS2" --path=$HOSTS_PATH --prepend-if-found-not=True
