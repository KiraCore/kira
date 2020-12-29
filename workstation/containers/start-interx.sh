#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

echo "INFO: Loading secrets..."
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
rm -f "./config.tmp"
jq --arg signer "${SIGNER_MNEMONIC}" '.mnemonic = $signer' $DOCKER_COMMON/interx/config.json >"./config.tmp" && mv "./config.tmp" $DOCKER_COMMON/interx/config.json
jq --arg faucet "${FAUCET_MNEMONIC}" '.faucet.mnemonic = $faucet' $DOCKER_COMMON/interx/config.json >"./config.tmp" && mv "./config.tmp" $DOCKER_COMMON/interx/config.json
rm -f "./config.tmp"
set -e

NETWORK="servicenet"
echo "------------------------------------------------"
echo "| STARTING INTERX NODE"
echo "|-----------------------------------------------"
echo "|        IP: $KIRA_SENTRY_IP"
echo "|   NODE ID: $SENTRY_NODE_ID"
echo "|   NETWORK: $NETWORK"
echo "|  HOSTNAME: $KIRA_SENTRY_DNS"
echo "------------------------------------------------"
set -x

docker run -d \
    -p $DEFAULT_INTERX_PORT:$KIRA_INTERX_PORT \
    --hostname $KIRA_INTERX_DNS \
    --restart=always \
    --name interx \
    --net=$NETWORK \
    --ip $KIRA_INTERX_IP \
    -e DEBUG_MODE="True" \
    -v $DOCKER_COMMON/interx:/common \
    --env KIRA_SENTRY_IP=$KIRA_SENTRY_IP \
    interx:latest

docker network connect sentrynet interx

echo "INFO: Waiting for interx to start..."
$KIRAMGR_SCRIPTS/await-interx-init.sh || exit 1
