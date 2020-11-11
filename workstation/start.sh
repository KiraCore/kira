#!/bin/bash

exec 2>&1
set -e
set -x

echo $SEKAI_BRANCH
source "/etc/profile" &>/dev/null

SKIP_UPDATE=$1
[ -z "$SKIP_UPDATE" ] && SKIP_UPDATE="False"

echo "INFO: Updating kira repository and fetching changes..."
if [ "$SKIP_UPDATE" == "False" ]; then
    $KIRA_MANAGER/setup.sh "$SKIP_UPDATE"
    source $KIRA_WORKSTATION/start.sh "True"
    exit 0
fi

source $ETC_PROFILE &>/dev/null

if [ "$KIRA_STOP" == "True" ]; then
    echo "INFO: Stopping kira..."
    source $KIRA_MANAGER/stop.sh
    exit 0
fi

$KIRA_SCRIPTS/container-restart.sh "registry"

VALIDATORS_EXIST=$($KIRA_SCRIPTS/containers-exist.sh "validator" || echo "error")
if [ "$VALIDATORS_EXIST" == "True" ]; then
    $KIRA_SCRIPTS/container-delete.sh "validator"

    VALIDATOR_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "validator" || echo "error")

    if [ "$VALIDATOR_EXISTS" != "False" ]; then
        echo "ERROR: Failed to delete validator container, status: ${VALIDATOR_EXISTS}"
        exit 1
    fi
fi

# todo: delete existing containers

source $WORKSTATION_SCRIPTS/update-base-image.sh
source $WORKSTATION_SCRIPTS/update-validator-image.sh
# source $WORKSTATION_SCRIPTS/update-sentry-image.sh
# source $WORKSTATION_SCRIPTS/update-frontend-image.sh
# source $WORKSTATION_SCRIPTS/update-kms-image.sh

cd $KIRA_WORKSTATION

docker network rm kiranet || echo "Failed to remove kira network"
docker network create --subnet=$KIRA_VALIDATOR_SUBNET kiranet

GENESIS_SOURCE="/root/.sekaid/config/genesis.json"
GENESIS_DESTINATION="$DOCKER_COMMON/genesis.json"
rm -rfv $DOCKER_COMMON
mkdir -p $DOCKER_COMMON
rm -f $GENESIS_DESTINATION

SEEDS=""
PEERS=""

echo "Kira Validator IP: ${KIRA_VALIDATOR_IP} Registry IP: ${KIRA_REGISTRY_IP}"

docker run -d \
    --restart=always \
    --name validator \
    --network kiranet \
    --ip $KIRA_VALIDATOR_IP \
    -e DEBUG_MODE="True" \
    validator:latest

echo "INFO: Waiting for validator to start..."
sleep 10
source $WORKSTATION_SCRIPTS/await-container-init.sh "validator" "300" "10"

echo "INFO: Inspecting if validator is running..."
SEKAID_VERSION=$(docker exec -i "validator" sekaid version || echo "error")
if [ "$SEKAID_VERSION" == "error" ]; then
    echo "ERROR: sekaid was NOT found"
    exit 1
else
    echo "SUCCESS: sekaid $SEKAID_VERSION was found"
fi

echo "INFO: Saving genesis file..."
docker cp validator:$GENESIS_SOURCE $GENESIS_DESTINATION

if [ ! -f "$GENESIS_DESTINATION" ]; then
    echo "ERROR: Failed to copy genesis file from validator"
    exit 1
fi

NODE_ID=$(docker exec -i "validator" sekaid tendermint show-node-id || echo "error")
# NOTE: New lines have to be removed
SEEDS=$(echo "${NODE_ID}@$KIRA_VALIDATOR_IP:$P2P_LOCAL_PORT" | xargs | tr -d '\n' | tr -d '\r')
PEERS=$SEEDS
echo "SUCCESS: validator is up and running, seed: $SEEDS"
