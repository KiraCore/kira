#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring validator..."
SEKAID_HOME=$HOME/.simapp

rm -rf $SEKAID_HOME

sekaid init --overwrite --chain-id=testing testing --home=$SEKAID_HOME

cd $SEKAID_HOME/config

ls

cp $COMMON_DIR/config.toml $SEKAID_HOME/config/config.toml
cp $COMMON_DIR/node_key.json $SEKAID_HOME/config/node_key.json
cp $COMMON_DIR/priv_validator_key.json $SEKAID_HOME/config/priv_validator_key.json

sekaid keys add validator --keyring-backend=test --home=$SEKAID_HOME
sekaid add-genesis-account $(sekaid keys show validator -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME

sekaid keys add test --keyring-backend=test --home=$SEKAID_HOME
sekaid add-genesis-account $(sekaid keys show test -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME

sekaid keys add frontend --keyring-backend=test --home=$SEKAID_HOME
sekaid add-genesis-account $(sekaid keys show frontend -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME

yes $SIGNER_MNEMONIC | sekaid keys add signer --keyring-backend=test --home=$SEKAID_HOME --recover
sekaid add-genesis-account $(sekaid keys show signer -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME

yes $FAUCET_MNEMONIC | sekaid keys add faucet --keyring-backend=test --home=$SEKAID_HOME --recover
sekaid add-genesis-account $(sekaid keys show faucet -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME

sekaid gentx-claim validator --keyring-backend=test --moniker="hello" --home=$SEKAID_HOME

sleep 10 && sekaid start --home=$SEKAID_HOME
