#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring validator..."
SEKAID_HOME=$HOME/.sekaid

rm -rf $SEKAID_HOME/config

sekaid init --chain-id=testing testing --home=$SEKAID_HOME

cp $SELF_CONFIGS/config.toml $SEKAID_HOME/config/config.toml
cp $SELF_CONFIGS/node_key.json $SEKAID_HOME/config/node_key.json

cd $SEKAID_HOME/config

ls

cat config.toml

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

sekaid start --home=$SEKAID_HOME
