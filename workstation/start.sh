#!/bin/bash

exec 2>&1
set -e
set -x

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

# todo: delete existing containers

source $WORKSTATION_SCRIPTS/update-base-image.sh
source $WORKSTATION_SCRIPTS/update-tools-image.sh
source $WORKSTATION_SCRIPTS/update-validator-image.sh

cd $KIRA_WORKSTATION

docker network rm kiranet || echo "Failed to remove kira network"
docker network create --subnet=$KIRA_VALIDATOR_SUBNET kiranet

GENESIS_SOUCE="/root/.sekaid/config/genesis.json"
GENESIS_DESTINATION="$DOCKER_COMMON/genesis.json"
rm -rfv $DOCKER_COMMON
mkdir -p $DOCKER_COMMON
rm -f $GENESIS_DESTINATION

SEEDS=""
PEERS=""

docker run -d \
    --restart=always \
    --name "validator" \
    --network kiranet \
    --ip "10.2.0.1" \
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
docker cp $NAME:$GENESIS_SOUCE $GENESIS_DESTINATION

if [ ! -f "$GENESIS_DESTINATION" ]; then
    echo "ERROR: Failed to copy genesis file from validator-$VALIDATOR_INDEX"
    exit 1
fi

NODE_ID=$(docker exec -i "validator" sekaid tendermint show-node-id || echo "error")
# NOTE: New lines have to be removed
SEEDS=$(echo "${NODE_ID}@10.2.0.1:$P2P_LOCAL_PORT" | xargs | tr -d '\n' | tr -d '\r')
PEERS=$SEEDS
echo "SUCCESS: validator is up and running, seed: $SEEDS"
