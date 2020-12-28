#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

SKIP_UPDATE=$1
START_TIME_LAUNCH="$(date -u +%s)"

cd $HOME

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
    $KIRA_MANAGER/networking.sh
    source $KIRA_MANAGER/start.sh "True"
    exit 0
fi

set +e && source "/etc/profile" &>/dev/null && set -e
set -x

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
source $KIRAMGR_SCRIPTS/update-base-image.sh
set -e

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Build other docker images in parallel
$KIRAMGR_SCRIPTS/update-validator-image.sh &
$KIRAMGR_SCRIPTS/update-sentry-image.sh &
$KIRAMGR_SCRIPTS/update-interx-image.sh &
wait

$KIRAMGR_SCRIPTS/update-frontend-image.sh || exit 1

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Generate node_key.json for validator & sentry.

rm -rfv $DOCKER_COMMON
mkdir -p $DOCKER_COMMON
cp -r $KIRA_DOCKER/configs/. $DOCKER_COMMON

# Load or generate secret mnemonics
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -e
set -x

# copy secrets and rename
cp -a $PRIV_VAL_KEY_PATH $DOCKER_COMMON/validator/priv_validator_key.json
cp -a $VAL_NODE_KEY_PATH $DOCKER_COMMON/validator/node_key.json
cp -a $SENT_NODE_KEY_PATH $DOCKER_COMMON/sentry/node_key.json

echo "INFO: Validator Node ID: ${VALIDATOR_NODE_ID}"
echo "INFO: Sentry Node ID: ${SENTRY_NODE_ID}"

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Seeds

VALIDATOR_SEED=$(echo "${VALIDATOR_NODE_ID}@validator:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')
SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

GENESIS_SOURCE="/root/.simapp/config/genesis.json"
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
# * Create all networks

$KIRAMGR_SCRIPTS/restart-networks.sh "false" # restarts all network without re-connecting containers 

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run the validator

echo "Kira Validator IP: ${KIRA_VALIDATOR_IP}"

docker run -d \
    --hostname $KIRA_VALIDATOR_DNS \
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
$KIRAMGR_SCRIPTS/await-validator-init.sh "$DOCKER_COMMON" "$GENESIS_SOURCE" "$GENESIS_DESTINATION" "$VALIDATOR_NODE_ID" || exit 1

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run the sentry node

echo "Kira Sentry IP: ${KIRA_SENTRY_IP}"

docker run -d \
    -p $DEFAULT_P2P_PORT:$KIRA_SENTRY_P2P_PORT \
    -p $DEFAULT_RPC_PORT:$KIRA_SENTRY_RPC_PORT \
    -p $DEFAULT_GRPC_PORT:$KIRA_SENTRY_GRPC_PORT \
    --hostname $KIRA_SENTRY_DNS \
    --restart=always \
    --name sentry \
    --net=sentrynet \
    --ip $KIRA_SENTRY_IP \
    -e DEBUG_MODE="True" \
    -v $DOCKER_COMMON/sentry:/common \
    sentry:latest

docker network connect kiranet sentry

echo "INFO: Waiting for sentry to start..."
$KIRAMGR_SCRIPTS/await-sentry-init.sh "$SENTRY_NODE_ID" || exit 1

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run INTERX & update config for signer and fuacet mnemonic keys

set +x
jq --arg signer "${SIGNER_MNEMONIC}" '.mnemonic = $signer' $DOCKER_COMMON/interx/config.json >"./config.tmp" && mv "./config.tmp" $DOCKER_COMMON/interx/config.json
jq --arg faucet "${FAUCET_MNEMONIC}" '.faucet.mnemonic = $faucet' $DOCKER_COMMON/interx/config.json >"./config.tmp" && mv "./config.tmp" $DOCKER_COMMON/interx/config.json
set -x

rm -f "./config.tmp"

docker run -d \
    -p $DEFAULT_INTERX_PORT:$KIRA_INTERX_PORT \
    --hostname $KIRA_INTERX_DNS \
    --restart=always \
    --name interx \
    --net=servicenet \
    --ip $KIRA_INTERX_IP \
    -e DEBUG_MODE="True" \
    -v $DOCKER_COMMON/interx:/common \
    --env KIRA_SENTRY_IP=$KIRA_SENTRY_IP \
    interx:latest

docker network connect sentrynet interx

$KIRAMGR_SCRIPTS/await-interx-init.sh || exit 1

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run the frontend

docker run -d \
    -p 80:$KIRA_FRONTEND_PORT \
    --hostname $KIRA_FRONTEND_DNS \
    --restart=always \
    --name frontend \
    --network servicenet \
    --ip $KIRA_FRONTEND_IP \
    -e DEBUG_MODE="True" \
    frontend:latest

docker network connect sentrynet frontend

$KIRAMGR_SCRIPTS/await-frontend-init.sh || exit 1

# ------------------------------------------------------------------------------------------------------------------------------------------------
# * Run the cleanup

echo "INFO: Prunning unused images..."
docker rmi $(docker images --filter "dangling=true" -q --no-trunc) || echo "WARNING: Failed to prune dangling image"

echo "------------------------------------------------"
echo "| FINISHED: LAUNCH SCRIPT                      |"
echo "|  ELAPSED: $(($(date -u +%s) - $START_TIME_LAUNCH)) seconds"
echo "------------------------------------------------"
