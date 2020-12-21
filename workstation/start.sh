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

echo "INFO: Restarting registry..."
$KIRA_SCRIPTS/container-restart.sh "registry" &

CONTAINERS=$(docker ps -a | awk '{if(NR>1) print $NF}' | tac)

i=-1
for name in $CONTAINERS; do
    i=$((i + 1)) # dele all containers except registry
    [ "${name,,}" == "registry" ] && continue
    $KIRA_SCRIPTS/container-delete.sh "$name"
done

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Build base image
source $WORKSTATION_SCRIPTS/update-base-image.sh
set -e

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Build other docker images in parallel
$WORKSTATION_SCRIPTS/update-validator-image.sh &
$WORKSTATION_SCRIPTS/update-sentry-image.sh &
$WORKSTATION_SCRIPTS/update-interx-image.sh &
wait

$WORKSTATION_SCRIPTS/update-frontend-image.sh || exit 1

cd $KIRA_WORKSTATION
# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Generate node_key.json for validator & sentry.

rm -rfv $DOCKER_COMMON
mkdir -p $DOCKER_COMMON
cp -r $KIRA_DOCKER/configs/. $DOCKER_COMMON

# Load or generate secret mnemonics
set +x
source $WORKSTATION_SCRIPTS/load-secrets.sh
set -e
set -x

# copy secrets and rename
# cp -a $PRIV_VAL_KEY_PATH $DOCKER_COMMON/validator/

cp -a $VAL_NODE_KEY_PATH $DOCKER_COMMON/validator/node_key.json
cp -a $SENT_NODE_KEY_PATH $DOCKER_COMMON/sentry/node_key.json

# cp -a ./tmp/validator_node_key.json $DOCKER_COMMON/validator/node_key.json
# cp -a ./tmp/sentry_node_key.json $DOCKER_COMMON/sentry/node_key.json

# VALIDATOR_NODE_ID="cf74dc682e07590962dce40db7404b07faa88afc"
# SENTRY_NODE_ID="0af3fe063192904ee30e6c76490e8310e709bd6e"

echo "INFO: Validator Node ID: ${VALIDATOR_NODE_ID}"
echo "INFO: Sentry Node ID: ${SENTRY_NODE_ID}"

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Seeds

VALIDATOR_SEED=$(echo "${VALIDATOR_NODE_ID}@validator:$VALIDATOR_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$VALIDATOR_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

GENESIS_SOURCE="/common/.sekai/config/genesis.json"
GENESIS_DESTINATION="$DOCKER_COMMON/sentry/genesis.json"
rm -f $GENESIS_DESTINATION

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Config validator/configs/config.toml

CDHelper text lineswap --insert="pex = false" --prefix="pex =" --path=$DOCKER_COMMON/validator
CDHelper text lineswap --insert="persistent_peers = \"$SENTRY_SEED\"" --prefix="persistent_peers =" --path=$DOCKER_COMMON/validator
CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$DOCKER_COMMON/validator
# CDHelper text lineswap --insert="priv_validator_laddr = \"tcp://0.0.0.0:12345\"" --prefix="priv_validator_laddr =" --path=$DOCKER_COMMON/validator

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Config sentry/configs/config.toml

CDHelper text lineswap --insert="pex = true" --prefix="pex =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="persistent_peers = \"$VALIDATOR_SEED\"" --prefix="persistent_peers =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="private_peer_ids = \"$VALIDATOR_NODE_ID\"" --prefix="private_peer_ids =" --path=$DOCKER_COMMON/sentry
CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$DOCKER_COMMON/sentry

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Create `kiranet` bridge network

docker network rm kiranet || echo "Failed to remove kira network"
docker network create --driver=bridge --subnet=$KIRA_VALIDATOR_SUBNET kiranet

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Create `sentrynet` bridge network

docker network rm sentrynet || echo "Failed to remove setnry network"
docker network create --driver=bridge --subnet=$KIRA_SENTRY_SUBNET sentrynet

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
    -v $DOCKER_COMMON/validator:/common \
    validator:latest

echo "INFO: Waiting for validator to start and import or produce genesis..."
$WORKSTATION_SCRIPTS/await-validator-init.sh "$DOCKER_COMMON" "$GENESIS_SOURCE" "$GENESIS_DESTINATION" "$VALIDATOR_NODE_ID" || exit 1

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run the sentry node

echo "Kira Sentry IP: ${KIRA_SENTRY_IP}"

docker run -d \
    --restart=always \
    --name sentry \
    --net=sentrynet \
    --ip $KIRA_SENTRY_IP \
    -e DEBUG_MODE="True" \
    -v $DOCKER_COMMON/sentry:/common \
    sentry:latest

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * conect sentry to the kiranet

docker network connect kiranet sentry

# echo "INFO: Waiting for sentry to start..."
# sleep 10
echo "INFO: Waiting for sentry to start..."
$WORKSTATION_SCRIPTS/await-sentry-init.sh "$SENTRY_NODE_ID" || exit 1

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Create `servicenet` bridge network

docker network rm servicenet || echo "Failed to remove service network"
docker network create --driver=bridge --subnet=$KIRA_SERVICE_SUBNET servicenet

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Update interx's config for signer and fuacet mnemonic keys

set +x
jq --arg signer "${SIGNER_MNEMONIC}" '.mnemonic = $signer' $DOCKER_COMMON/interx/config.json >"./config.tmp" && mv "./config.tmp" $DOCKER_COMMON/interx/config.json
jq --arg faucet "${FAUCET_MNEMONIC}" '.faucet.mnemonic = $faucet' $DOCKER_COMMON/interx/config.json >"./config.tmp" && mv "./config.tmp" $DOCKER_COMMON/interx/config.json
set -x

rm -f "./config.tmp"

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run the interx

docker run -d \
    -p 11000:11000 \
    --restart=always \
    --name interx \
    --net=servicenet \
    --ip $KIRA_INTERX_IP \
    -e DEBUG_MODE="True" \
    -v $DOCKER_COMMON/interx:/common \
    --env KIRA_SENTRY_IP=$KIRA_SENTRY_IP \
    interx:latest

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * conect interx to the sentrynet

docker network connect sentrynet interx

$WORKSTATION_SCRIPTS/await-interx-init.sh || exit 1

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

echo "INFO: Prunning unused images..."
docker rmi $(docker images --filter "dangling=true" -q --no-trunc) || echo "WARNING: Failed to prune dangling image"

# ---------- FRONTEND END ----------

echo "------------------------------------------------"
echo "| FINISHED: LAUNCH SCRIPT                      |"
echo "|  ELAPSED: $(($(date -u +%s) - $START_TIME_LAUNCH)) seconds"
echo "------------------------------------------------"
