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

SENTRY_EXIST=$($KIRA_SCRIPTS/containers-exist.sh "sentry" || echo "error")
if [ "$SENTRY_EXIST" == "True" ]; then
    $KIRA_SCRIPTS/container-delete.sh "sentry"

    SENTRY_EXIST=$($KIRA_SCRIPTS/container-exists.sh "sentry" || echo "error")

    if [ "$SENTRY_EXIST" != "False" ]; then
        echo "ERROR: Failed to delete sentry container, status: ${SENTRY_EXIST}"
        exit 1
    fi
fi

KMS_EXIST=$($KIRA_SCRIPTS/containers-exist.sh "kms" || echo "error")
if [ "$KMS_EXIST" == "True" ]; then
    $KIRA_SCRIPTS/container-delete.sh "kms"

    KMS_EXIST=$($KIRA_SCRIPTS/container-exists.sh "kms" || echo "error")

    if [ "$KMS_EXIST" != "False" ]; then
        echo "ERROR: Failed to delete kms container, status: ${KMS_EXIST}"
        exit 1
    fi
fi

INTERX_EXIST=$($KIRA_SCRIPTS/containers-exist.sh "interx" || echo "error")
if [ "$INTERX_EXIST" == "True" ]; then
    $KIRA_SCRIPTS/container-delete.sh "interx"

    INTERX_EXIST=$($KIRA_SCRIPTS/container-exists.sh "interx" || echo "error")

    if [ "$INTERX_EXIST" != "False" ]; then
        echo "ERROR: Failed to delete interx container, status: ${INTERX_EXIST}"
        exit 1
    fi
fi

FRONTEND_EXIST=$($KIRA_SCRIPTS/containers-exist.sh "frontend" || echo "error")
if [ "$FRONTEND_EXIST" == "True" ]; then
    $KIRA_SCRIPTS/container-delete.sh "frontend"

    FRONTEND_EXIST=$($KIRA_SCRIPTS/container-exists.sh "frontend" || echo "error")

    if [ "$FRONTEND_EXIST" != "False" ]; then
        echo "ERROR: Failed to delete frontend container, status: ${FRONTEND_EXIST}"
        exit 1
    fi
fi

# todo: delete existing containers

source $WORKSTATION_SCRIPTS/update-base-image.sh

cd $KIRA_WORKSTATION

P2P_LOCAL_PORT="26656"
P2P_PROXY_PORT="10000"
RPC_PROXY_PORT="10001"

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Constants. The following node-ids are generated from node_key.json files. In each docker context/configs folder, you can see node_key.json file.

VALIDATOR_NODE_ID="4fdfc055acc9b2b6683794069a08bb78aa7ab9ba"
SENTRY_NODE_ID="d81a142b8d0d06f967abd407de138630d8831fff"

VALIDATOR_SEED=$(echo "${VALIDATOR_NODE_ID}@${KIRA_VALIDATOR_IP}:$P2P_LOCAL_PORT" | xargs | tr -d '\n' | tr -d '\r')
SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@${KIRA_SENTRY_IP}:$P2P_LOCAL_PORT" | xargs | tr -d '\n' | tr -d '\r')

GENESIS_SOURCE="/root/.sekaid/config/genesis.json"
GENESIS_DESTINATION="$DOCKER_COMMON/genesis.json"
rm -rfv $DOCKER_COMMON
mkdir -p $DOCKER_COMMON
rm -f $GENESIS_DESTINATION

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Generate two mnemonic keys (for signing & faucet) using hd-wallet-derive.

git clone https://github.com/dan-da/hd-wallet-derive.git
cd hd-wallet-derive
yes "yes" | composer install

SIGNER_MNEMONIC=$(./hd-wallet-derive.php --coin=DOGE --gen-key --format=jsonpretty -g | jq '.[0].mnemonic')
FAUCET_MNEMONIC=$(./hd-wallet-derive.php --coin=DOGE --gen-key --format=jsonpretty -g | jq '.[0].mnemonic')

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
CDHelper text lineswap --insert="priv_validator_laddr = \"tcp://0.0.0.0:12345\"" --prefix="priv_validator_laddr =" --path=$KIRA_DOCKER/validator/configs

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Create `kiranet` bridge network

docker network rm kiranet || echo "Failed to remove kira network"
docker network create --driver=bridge --subnet=$KIRA_VALIDATOR_SUBNET kiranet

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Create `kmsnet` bridge network

docker network rm kmsnet || echo "Failed to remove kms network"
docker network create --driver=bridge --subnet=$KIRA_KMS_SUBNET kmsnet

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Build docker images
source $WORKSTATION_SCRIPTS/update-validator-image.sh
source $WORKSTATION_SCRIPTS/update-kms-image.sh

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

# echo "INFO: Saving priv_validator_key.json file..."
# PRIV_VALIDATOR_KEY_SOURCE="/root/.sekaid/config/priv_validator_key.json"
# PRIV_VALIDATOR_KEY_DESTINATION="$DOCKER_COMMON/priv_validator_key.json"
# rm -f $PRIV_VALIDATOR_KEY_DESTINATION
# docker cp validator:$PRIV_VALIDATOR_KEY_SOURCE $PRIV_VALIDATOR_KEY_DESTINATION

CHECK_VALIDATOR_NODE_ID=$(docker exec -i "validator" sekaid tendermint show-node-id --home /root/.sekaid || echo "error")
echo "INFO: Check Validator Node id..."
echo "${VALIDATOR_NODE_ID} - ${CHECK_VALIDATOR_NODE_ID}"

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Create `sentrynet` bridge network

docker network rm sentrynet || echo "Failed to remove setnry network"
docker network create --driver=bridge --subnet=$KIRA_SENTRY_SUBNET sentrynet

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Configure config.toml file for sentry and provide genesis file.

CDHelper text lineswap --insert="pex = true" --prefix="pex =" --path=$KIRA_DOCKER/sentry/configs
CDHelper text lineswap --insert="persistent_peers = \"$VALIDATOR_SEED\"" --prefix="persistent_peers =" --path=$KIRA_DOCKER/sentry/configs
CDHelper text lineswap --insert="private_peer_ids = \"$VALIDATOR_NODE_ID\"" --prefix="private_peer_ids =" --path=$KIRA_DOCKER/sentry/configs
CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$KIRA_DOCKER/sentry/configs

cp -i $GENESIS_DESTINATION $KIRA_DOCKER/sentry/configs

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run the sentry node

echo "Kira Sentry IP: ${KIRA_SENTRY_IP}"

source $WORKSTATION_SCRIPTS/update-sentry-image.sh

docker run -d \
    --restart=always \
    --name sentry \
    --net=sentrynet \
    --ip $KIRA_SENTRY_IP \
    -e DEBUG_MODE="True" \
    sentry:latest

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * conect sentry to the kiranet

docker network connect kiranet sentry

echo "INFO: Waiting for sentry to start..."
sleep 10

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Check sentry's node id

CHECK_SENTRY_NODE_ID=$(docker exec -i "sentry" sekaid tendermint show-node-id --home /root/.sekaid || echo "error")
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

jq --arg signer "${SIGNER_MNEMONIC}" '.mnemonic = $signer' $KIRA_DOCKER/interx/configs/config.json >"tmp" && mv "tmp" $KIRA_DOCKER/interx/configs/config.json
jq --arg faucet "${FAUCET_MNEMONIC}" '.faucet.mnemonic = $faucet' $KIRA_DOCKER/interx/configs/config.json >"tmp" && mv "tmp" $KIRA_DOCKER/interx/configs/config.json

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run the interx

source $WORKSTATION_SCRIPTS/update-interx-image.sh

docker run -d \
    --restart=always \
    --name interx \
    --net=servicenet \
    --ip $KIRA_INTERX_IP \
    -e DEBUG_MODE="True" \
    --env KIRA_SENTRY_IP=$KIRA_SENTRY_IP \
    interx:latest

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * conect interx to the sentrynet

docker network connect sentrynet interx

echo "INFO: Waiting for INTERX to start..."
sleep 10

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run the frontend

source $WORKSTATION_SCRIPTS/update-frontend-image.sh

docker run -d \
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
