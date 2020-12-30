#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

echo "INFO: Loading secrets..."
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
echo "$SIGNER_MNEMONIC" >>$DOCKER_COMMON/validator/signer_mnemonic.key
echo "$FAUCET_MNEMONIC" >>$DOCKER_COMMON/validator/faucet_mnemonic.key
cp -a $PRIV_VAL_KEY_PATH $DOCKER_COMMON/validator/priv_validator_key.json
cp -a $VAL_NODE_KEY_PATH $DOCKER_COMMON/validator/node_key.json
set -e

NETWORK="kiranet"
echo "------------------------------------------------"
echo "| STARTING VALIDATOR NODE"
echo "|-----------------------------------------------"
echo "|        IP: $KIRA_VALIDATOR_IP"
echo "|   NETWORK: $NETWORK"
echo "|   NODE ID: $VALIDATOR_NODE_ID"
echo "|  HOSTNAME: $KIRA_VALIDATOR_DNS"
echo "------------------------------------------------"
set -x

SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

echo "INFO: Setting up validator config files..."
# * Config validator/configs/config.toml

CDHelper text lineswap --insert="pex = false" --prefix="pex =" --path=$DOCKER_COMMON/validator
CDHelper text lineswap --insert="persistent_peers = \"$SENTRY_SEED\"" --prefix="persistent_peers =" --path=$DOCKER_COMMON/validator
CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$DOCKER_COMMON/validator

GENESIS_SOURCE="/root/.simapp/config/genesis.json"
GENESIS_DESTINATION="$DOCKER_COMMON/sentry/genesis.json"
rm -f $GENESIS_DESTINATION

echo "INFO: Starting validator node..."

docker run -d \
    --hostname $KIRA_VALIDATOR_DNS \
    --restart=always \
    --name validator \
    --net=$NETWORK \
    --ip $KIRA_VALIDATOR_IP \
    -e DEBUG_MODE="True" \
    -v $DOCKER_COMMON/validator:/common \
    validator:latest

echo "INFO: Waiting for validator to start and import or produce genesis..."
$KIRAMGR_SCRIPTS/await-validator-init.sh "$DOCKER_COMMON" "$GENESIS_SOURCE" "$GENESIS_DESTINATION" "$VALIDATOR_NODE_ID" || exit 1