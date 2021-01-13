#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e

echo "INFO: Loading secrets..."
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh

CONTAINER_NAME="validator"
COMMON_PATH="$DOCKER_COMMON/$CONTAINER_NAME"
SNAP_DESTINATION="$COMMON_PATH/snap.zip"

echo "$SIGNER_MNEMONIC" > $COMMON_PATH/signer_mnemonic.key
echo "$FAUCET_MNEMONIC" > $COMMON_PATH/faucet_mnemonic.key
echo "$VALIDATOR_MNEMONIC" > $COMMON_PATH/validator_mnemonic.key
echo "$FRONTEND_MNEMONIC" > $COMMON_PATH/frontend_mnemonic.key
echo "$TEST_MNEMONIC" > $COMMON_PATH/test_mnemonic.key
cp -a $PRIV_VAL_KEY_PATH $COMMON_PATH/priv_validator_key.json
cp -a $VAL_NODE_KEY_PATH $COMMON_PATH/node_key.json
set -e

echo "------------------------------------------------"
echo "| STARTING $CONTAINER_NAME NODE"
echo "|-----------------------------------------------"
echo "|   NETWORK: $KIRA_VALIDATOR_NETWORK"
echo "|   NODE ID: $VALIDATOR_NODE_ID"
echo "|  HOSTNAME: $KIRA_VALIDATOR_DNS"
echo "------------------------------------------------"
set -x

rm -fv $SNAP_DESTINATION
if [ -f "$KIRA_SNAP_PATH" ] ; then
    echo "INFO: State snapshoot was found, cloning..."
    cp -a -v $KIRA_SNAP_PATH $SNAP_DESTINATION
fi

SENTRY_SEED=$(echo "${SENTRY_NODE_ID}@sentry:$DEFAULT_P2P_PORT" | xargs | tr -d '\n' | tr -d '\r')

echo "INFO: Setting up validator config files..."
# * Config validator/configs/config.toml

CDHelper text lineswap --insert="pex = false" --prefix="pex =" --path=$COMMON_PATH
CDHelper text lineswap --insert="persistent_peers = \"tcp://$SENTRY_SEED\"" --prefix="persistent_peers =" --path=$COMMON_PATH
CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$COMMON_PATH
CDHelper text lineswap --insert="version = \"v2\"" --prefix="version =" --path=$COMMON_PATH # fastsync

GENESIS_SOURCE="/root/.simapp/config/genesis.json"
GENESIS_DESTINATION="$DOCKER_COMMON/sentry/genesis.json"
rm -f $GENESIS_DESTINATION

echo "INFO: Starting validator node..."

docker run -d \
    --hostname $KIRA_VALIDATOR_DNS \
    --restart=always \
    --name $CONTAINER_NAME \
    --net=$KIRA_VALIDATOR_NETWORK \
    -e DEBUG_MODE="True" \
    -v $COMMON_PATH:/common \
    $CONTAINER_NAME:latest

echo "INFO: Waiting for validator to start and import or produce genesis..."
$KIRAMGR_SCRIPTS/await-validator-init.sh "$DOCKER_COMMON" "$GENESIS_SOURCE" "$GENESIS_DESTINATION" "$VALIDATOR_NODE_ID" || exit 1

$KIRAMGR_SCRIPTS/restart-networks.sh "true" "$KIRA_VALIDATOR_NETWORK"
