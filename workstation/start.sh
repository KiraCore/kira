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

docker network rm sentrynet || echo "Failed to remove setnry network"
docker network create --subnet=103.0.0.0/8 sentrynet

echo "Kira Sentry IP: ${KIRA_SENTRY_IP}"

source $WORKSTATION_SCRIPTS/update-sentry-image.sh

docker run -d \
    --restart=always \
    --name sentry \
    --network host \
    -p 103.0.1.1:26657:26657 \
    -p 103.0.1.1:9090:9090 \
    -e DEBUG_MODE="True" \
    sentry:latest # --ip 103.0.1.1 \

echo "INFO: Waiting for sentry to start..."
sleep 10

SENTRY_ID=$(docker exec -i "sentry" sekaid tendermint show-node-id || echo "error")
echo $SENTRY_ID
if [ "$SENTRY_ID" == "error" ]; then
    echo "ERROR: sentry node error"
    exit 1
fi

P2P_LOCAL_PORT="26656"
P2P_PROXY_PORT="10000"
RPC_PROXY_PORT="10001"

SENTRY_SEED=$(echo "${SENTRY_ID}@103.0.1.1:$P2P_LOCAL_PORT" | xargs | tr -d '\n' | tr -d '\r')
SENTRY_PEER=$SENTRY_SEED
echo "SUCCESS: sentry is up and running, seed: $SENTRY_SEED"

CDHelper text lineswap --insert="pex = false" --prefix="pex =" --path=$KIRA_DOCKER/validator/configs
CDHelper text lineswap --insert="persistent_peers = \"$SENTRY_SEED\"" --prefix="persistent_peers =" --path=$KIRA_DOCKER/validator/configs
CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$KIRA_DOCKER/validator/configs
# CDHelper text lineswap --insert="priv_validator_laddr = \"tcp://101.0.1.1:26658\"" --prefix="priv_validator_laddr =" --path=$KIRA_DOCKER/validator/configs

docker network rm kiranet || echo "Failed to remove kira network"
docker network create --subnet=$KIRA_VALIDATOR_SUBNET kiranet

GENESIS_SOURCE="/root/.sekaid/config/genesis.json"
GENESIS_DESTINATION="$DOCKER_COMMON/genesis.json"
rm -rfv $DOCKER_COMMON
mkdir -p $DOCKER_COMMON
rm -f $GENESIS_DESTINATION

SEEDS=""
PEERS=""

git clone https://github.com/dan-da/hd-wallet-derive.git
cd hd-wallet-derive
yes "yes" | composer install

SIGNER_MNEMONIC=$(./hd-wallet-derive.php --coin=DOGE --gen-key --format=jsonpretty -g | jq '.[0].mnemonic')
FAUCET_MNEMONIC=$(./hd-wallet-derive.php --coin=DOGE --gen-key --format=jsonpretty -g | jq '.[0].mnemonic')

SIGNER_MNEMONIC_LEN=$(expr ${#SIGNER_MNEMONIC} - 2)
SIGNER_MNEMONIC=$(echo $SIGNER_MNEMONIC | tail -c +2 | head -c $SIGNER_MNEMONIC_LEN)

FAUCET_MNEMONIC_LEN=$(expr ${#FAUCET_MNEMONIC} - 2)
FAUCET_MNEMONIC=$(echo $FAUCET_MNEMONIC | tail -c +2 | head -c $FAUCET_MNEMONIC_LEN)

echo "********************************************"
echo $SIGNER_MNEMONIC
echo $FAUCET_MNEMONIC

echo "Kira Validator IP: ${KIRA_VALIDATOR_IP} Registry IP: ${KIRA_REGISTRY_IP} Sentry IP: ${KIRA_SENTRY_IP}"

source $WORKSTATION_SCRIPTS/update-validator-image.sh

docker run -d \
    --restart=always \
    --name validator \
    --network kiranet \
    --ip $KIRA_VALIDATOR_IP \
    -e DEBUG_MODE="True" \
    --env SIGNER_MNEMONIC="$SIGNER_MNEMONIC" \
    --env FAUCET_MNEMONIC="$FAUCET_MNEMONIC" \
    validator:latest

echo "INFO: Waiting for validator to start..."
sleep 10
# source $WORKSTATION_SCRIPTS/await-container-init.sh "validator" "300" "10"

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

echo "INFO: Saving priv_validator_key.json file..."
PRIV_VALIDATOR_KEY_SOURCE="/root/.sekaid/config/priv_validator_key.json"
PRIV_VALIDATOR_KEY_DESTINATION="$DOCKER_COMMON/priv_validator_key.json"
rm -f $PRIV_VALIDATOR_KEY_DESTINATION
docker cp validator:$PRIV_VALIDATOR_KEY_SOURCE $PRIV_VALIDATOR_KEY_DESTINATION

NODE_ID=$(docker exec -i "validator" sekaid tendermint show-node-id || echo "error")
# NOTE: New lines have to be removed
SEEDS=$(echo "${NODE_ID}@$KIRA_VALIDATOR_IP:$P2P_LOCAL_PORT" | xargs | tr -d '\n' | tr -d '\r')
PEERS=$SEEDS
echo "SUCCESS: validator is up and running, seed: $SEEDS"

CDHelper text lineswap --insert="pex = true" --prefix="pex =" --path=$KIRA_DOCKER/sentry/configs
CDHelper text lineswap --insert="persistent_peers = \"$PEERS\"" --prefix="persistent_peers =" --path=$KIRA_DOCKER/sentry/configs
CDHelper text lineswap --insert="private_peer_ids = \"$NODE_ID\"" --prefix="private_peer_ids =" --path=$KIRA_DOCKER/sentry/configs
CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$KIRA_DOCKER/sentry/configs

docker cp $GENESIS_DESTINATION sentry:/root/.sekaid/config
docker cp $KIRA_DOCKER/sentry/configs/config.toml sentry:/root/.sekaid/config/

# ---------- INTERX BEGIN ----------
docker network rm servicenet || echo "Failed to remove service network"
docker network create --subnet=104.0.0.0/8 servicenet

jq --arg signer "${SIGNER_MNEMONIC}" '.mnemonic = $signer' $KIRA_DOCKER/interx/configs/config.json >"tmp" && mv "tmp" $KIRA_DOCKER/interx/configs/config.json
jq --arg faucet "${FAUCET_MNEMONIC}" '.faucet.mnemonic = $faucet' $KIRA_DOCKER/interx/configs/config.json >"tmp" && mv "tmp" $KIRA_DOCKER/interx/configs/config.json

source $WORKSTATION_SCRIPTS/update-interx-image.sh

docker run -d \
    --restart=always \
    --name interx \
    --network servicenet \
    --ip 104.0.1.1 \
    -p 11000:11000/tcp \
    -e DEBUG_MODE="True" \
    interx:latest

echo "INFO: Waiting for INTERX to start..."
sleep 10
# ---------- INTERX END ----------

# ---------- FRONTEND BEGIN ----------
# source $WORKSTATION_SCRIPTS/update-frontend-image.sh

# docker run -d \
#     --restart=always \
#     --name frontend \
#     --network servicenet \
#     --ip 104.0.1.2 \
#     -p 80:80/tcp \
#     -e DEBUG_MODE="True" \
#     frontend:latest

# echo "INFO: Waiting for frontend to start..."
# sleep 10
# ---------- FRONTEND END ----------

# ---------- KMS BEGIN ----------

# cp $PRIV_VALIDATOR_KEY_DESTINATION $KIRA_DOCKER/kms/config

# docker network rm kmsnet || echo "Failed to remove kms network"
# docker network create --subnet=101.0.0.0/8 kmsnet

# source $WORKSTATION_SCRIPTS/update-kms-image.sh

# KMS_NODE_ID=$(docker run -d --restart=always --name kms --network kmsnet --ip 101.0.1.1 -e DEBUG_MODE="True" kms:latest)
# echo KMS_NODE_ID

# echo "INFO: Waiting for kms to start..."
# sleep 10

# ---------- KMS END ----------
