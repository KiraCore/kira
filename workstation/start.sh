#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

SKIP_UPDATE=$1
START_TIME_LAUNCH="$(date -u +%s)"
# START_LOG="$KIRA_DUMP/start.log"

# exec >> $START_LOG 2>&1 && tail $START_LOG

echo "------------------------------------------------"
echo "| STARTED: LAUNCH SCRIPT                       |"
echo "|-----------------------------------------------"
echo "|  SKIP UPDATE: $SKIP_UPDATE"
echo "| SEKAI BRANCH: $SEKAI_BRANCH"
# echo "|    START LOG: $START_LOG"
echo "------------------------------------------------"

[ -z "$SKIP_UPDATE" ] && SKIP_UPDATE="False"

echo "INFO: Updating kira repository and fetching changes..."
if [ "$SKIP_UPDATE" == "False" ]; then
    $KIRA_MANAGER/setup.sh "$SKIP_UPDATE"
    source $KIRA_WORKSTATION/start.sh "True"
    exit 0
fi

set +e && source "/etc/profile" &>/dev/null && set -e
set -x

if [ "$KIRA_STOP" == "True" ]; then
    echo "INFO: Stopping kira..."
    source $KIRA_MANAGER/stop.sh
    exit 0
fi

echo "INFO: Prunning unused cache..."
docker builder prune -a -f || echo "WARNING: Cache prune failed"
echo "INFO: Prunning unused images..."
docker image prune -a -f || echo "WARNING: Image prune failed"

echo "INFO: Restarting registry..."
$KIRA_SCRIPTS/container-restart.sh "registry"

CONTAINERS=$(docker ps -a | awk '{if(NR>1) print $NF}' | tac)

i=-1
for name in $CONTAINERS; do
    i=$((i + 1)) # dele all containers except registry
    [ "${name,,}" == "registry" ] && continue
    CONTAINER_EXISTS=$($KIRA_SCRIPTS/containers-exist.sh "$name" || echo "error")
    if [ "${CONTAINER_EXISTS,,}" == "true" ]; then
        $KIRA_SCRIPTS/container-delete.sh "$name"

        CONTAINER_EXISTS=$($KIRA_SCRIPTS/container-exists.sh "$name" || echo "error")

        if [ "${CONTAINER_EXISTS,,}" != "false" ]; then
            echo "ERROR: Failed to delete $name container, status: ${VALIDATOR_EXISTS}"
            exit 1
        fi
    fi
done

# todo: delete existing containers

source $WORKSTATION_SCRIPTS/update-base-image.sh

cd $KIRA_WORKSTATION
# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Generate node_key.json for validator & sentry.

rm -rfv $DOCKER_COMMON
mkdir -p $DOCKER_COMMON

VALIDATOR_NODE_ID_MNEMONIC=$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic')
SENTRY_NODE_ID_MNEMONIC=$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic')
tmkms-key-import "${VALIDATOR_NODE_ID_MNEMONIC}" ./validator_node_key.json ./signing.key
tmkms-key-import "${SENTRY_NODE_ID_MNEMONIC}" ./sentry_node_key.json ./signing.key
VALIDATOR_NODE_ID=$(cat ./validator_node_key.json | jq '.address' --raw-output)
SENTRY_NODE_ID=$(cat ./sentry_node_key.json | jq '.address' --raw-output)

echo "Validator Node ID: ${VALIDATOR_NODE_ID}"
echo "Sentry Node ID: ${SENTRY_NODE_ID}"

jq 'del(.address, .pub_key)' ./validator_node_key.json >"tmp" && mv "tmp" $DOCKER_COMMON/validator_node_key.json
jq 'del(.address, .pub_key)' ./sentry_node_key.json >"tmp" && mv "tmp" $DOCKER_COMMON/sentry_node_key.json

rm ./validator_node_key.json
rm ./sentry_node_key.json

PRIVATE_KEY_MNEMONIC=$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic')
tmkms-key-import "${PRIVATE_KEY_MNEMONIC}" $DOCKER_COMMON/priv_validator_key.json $DOCKER_COMMON/signing.key

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Seeds

VALIDATOR_SEED=$(echo "${VALIDATOR_NODE_ID}@validator:$VALIDATOR_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$VALIDATOR_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

GENESIS_SOURCE="/root/.simapp/config/genesis.json"
GENESIS_DESTINATION="$DOCKER_COMMON/genesis.json"
rm -f $GENESIS_DESTINATION

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Generate two mnemonic keys (for signing & faucet) using hd-wallet-derive.

SIGNER_MNEMONIC=$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic')
FAUCET_MNEMONIC=$(hd-wallet-derive --gen-words=24 --gen-key --format=jsonpretty -g | jq '.[0].mnemonic')

# * Cut the first and the last quotes("")
SIGNER_MNEMONIC_LEN=$(expr ${#SIGNER_MNEMONIC} - 2)
SIGNER_MNEMONIC=$(echo $SIGNER_MNEMONIC | tail -c +2 | head -c $SIGNER_MNEMONIC_LEN)

FAUCET_MNEMONIC_LEN=$(expr ${#FAUCET_MNEMONIC} - 2)
FAUCET_MNEMONIC=$(echo $FAUCET_MNEMONIC | tail -c +2 | head -c $FAUCET_MNEMONIC_LEN)

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Config validator/configs/config.toml

CDHelper text lineswap --insert="pex = false" --prefix="pex =" --path=$KIRA_DOCKER/validator/configs
CDHelper text lineswap --insert="persistent_peers = \"$SENTRY_SEED\"" --prefix="persistent_peers =" --path=$KIRA_DOCKER/validator/configs
CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$KIRA_DOCKER/validator/configs
# CDHelper text lineswap --insert="priv_validator_laddr = \"tcp://0.0.0.0:12345\"" --prefix="priv_validator_laddr =" --path=$KIRA_DOCKER/validator/configs

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Config sentry/configs/config.toml

CDHelper text lineswap --insert="pex = true" --prefix="pex =" --path=$KIRA_DOCKER/sentry/configs
CDHelper text lineswap --insert="persistent_peers = \"$VALIDATOR_SEED\"" --prefix="persistent_peers =" --path=$KIRA_DOCKER/sentry/configs
CDHelper text lineswap --insert="private_peer_ids = \"$VALIDATOR_NODE_ID\"" --prefix="private_peer_ids =" --path=$KIRA_DOCKER/sentry/configs
CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$KIRA_DOCKER/sentry/configs

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Build docker images
$WORKSTATION_SCRIPTS/update-validator-image.sh &
$WORKSTATION_SCRIPTS/update-kms-image.sh &
$WORKSTATION_SCRIPTS/update-sentry-image.sh &
$WORKSTATION_SCRIPTS/update-interx-image.sh &
wait

$WORKSTATION_SCRIPTS/update-frontend-image.sh

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Create `kiranet` bridge network

docker network rm kiranet || echo "Failed to remove kira network"
docker network create --driver=bridge --subnet=$KIRA_VALIDATOR_SUBNET kiranet

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Create `kmsnet` bridge network

docker network rm kmsnet || echo "Failed to remove kms network"
docker network create --driver=bridge --subnet=$KIRA_KMS_SUBNET kmsnet

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run the validator

echo "Kira Validator IP: ${KIRA_VALIDATOR_IP}"

docker run -d \
    --restart=always \
    --name validator \
    --net=kiranet \
    --ip $KIRA_VALIDATOR_IP \
    -e DEBUG_MODE="True" \
    --env SIGNER_MNEMONIC="$SIGNER_MNEMONIC" \
    --env FAUCET_MNEMONIC="$FAUCET_MNEMONIC" \
    -v $DOCKER_COMMON:/common \
    validator:latest

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run the KMS node

# cp $PRIV_VALIDATOR_KEY_DESTINATION $KIRA_DOCKER/kms/configs

echo "Kira KMS IP: ${KIRA_KMS_IP}"

docker run -d \
    \
    --name kms \
    --net=kmsnet \
    --ip $KIRA_KMS_IP \
    -e DEBUG_MODE="True" \
    -v $DOCKER_COMMON:/common \
    kms:latest # --restart=always \

docker network connect kiranet kms
docker network connect kmsnet validator

sleep 10

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Check if validator is running
echo "INFO: Inspecting if validator is running..."
SEKAID_VERSION=$(docker exec -i "validator" sekaid version || echo "error")
if [ "$SEKAID_VERSION" == "error" ]; then
    echo "ERROR: sekaid was NOT found"
    exit 1
else
    echo "SUCCESS: sekaid $SEKAID_VERSION was found"
fi

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Get the genesis file from the validator.
echo "INFO: Saving genesis file..."
docker cp validator:$GENESIS_SOURCE $GENESIS_DESTINATION

if [ ! -f "$GENESIS_DESTINATION" ]; then
    echo "ERROR: Failed to copy genesis file from validator"
    exit 1
fi

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Get the genesis file from the validator.

CHECK_VALIDATOR_NODE_ID=$(docker exec -i "validator" sekaid tendermint show-node-id --home /root/.simapp || echo "error")
echo "INFO: Check Validator Node id..."
echo "${VALIDATOR_NODE_ID} - ${CHECK_VALIDATOR_NODE_ID}"

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Create `sentrynet` bridge network

docker network rm sentrynet || echo "Failed to remove setnry network"
docker network create --driver=bridge --subnet=$KIRA_SENTRY_SUBNET sentrynet

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run the sentry node

echo "Kira Sentry IP: ${KIRA_SENTRY_IP}"

docker run -d \
    --restart=always \
    --name sentry \
    --net=sentrynet \
    --ip $KIRA_SENTRY_IP \
    -e DEBUG_MODE="True" \
    -v $DOCKER_COMMON:/common \
    sentry:latest

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * conect sentry to the kiranet

docker network connect kiranet sentry

echo "INFO: Waiting for sentry to start..."
sleep 10

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Check sentry's node id

CHECK_SENTRY_NODE_ID=$(docker exec -i "sentry" sekaid tendermint show-node-id --home /root/.simapp || echo "error")
echo $CHECK_SENTRY_NODE_ID
if [ "$CHECK_SENTRY_NODE_ID" == "error" ]; then
    echo "ERROR: sentry node error"
    exit 1
fi

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Create `servicenet` bridge network

docker network rm servicenet || echo "Failed to remove service network"
docker network create --driver=bridge --subnet=$KIRA_SERVICE_SUBNET servicenet

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Update interx's config for signer and fuacet mnemonic keys

DOCKER_COMMON_INTERX="$DOCKER_COMMON/interx"
rm -rfv $DOCKER_COMMON_INTERX
mkdir -p $DOCKER_COMMON_INTERX

DOCKER_COMMON_INTERX_CONFIG="$DOCKER_COMMON_INTERX/config.json"
rm -f $DOCKER_COMMON_INTERX_CONFIG

jq --arg signer "${SIGNER_MNEMONIC}" '.mnemonic = $signer' $KIRA_DOCKER/interx/configs/config.json >"tmp" && mv "tmp" $DOCKER_COMMON_INTERX_CONFIG
jq --arg faucet "${FAUCET_MNEMONIC}" '.faucet.mnemonic = $faucet' $KIRA_DOCKER/interx/configs/config.json >"tmp" && mv "tmp" $DOCKER_COMMON_INTERX_CONFIG

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run the interx

docker run -d \
    -p 11000:11000 \
    --restart=always \
    --name interx \
    --net=servicenet \
    --ip $KIRA_INTERX_IP \
    -e DEBUG_MODE="True" \
    -v $DOCKER_COMMON:/common \
    --env KIRA_SENTRY_IP=$KIRA_SENTRY_IP \
    interx:latest

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * conect interx to the sentrynet

docker network connect sentrynet interx

echo "INFO: Waiting for INTERX to start..."
sleep 10

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run the frontend

docker run -d \
    -p 80:80 \
    --restart=always \
    --name frontend \
    --network servicenet \
    --ip $KIRA_FRONTEND_IP \
    -e DEBUG_MODE="True" \
    frontend:latest

docker network connect sentrynet frontend

echo "INFO: Waiting for frontend to start..."
sleep 10
# ---------- FRONTEND END ----------

echo "------------------------------------------------"
echo "| FINISHED: LAUNCH SCRIPT                      |"
echo "|  ELAPSED: $(($(date -u +%s) - $START_TIME_LAUNCH)) seconds"
echo "------------------------------------------------"
