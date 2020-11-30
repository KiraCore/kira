#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring sentry..."
SEKAID_HOME=$HOME/.sekaid

sekaid init --chain-id=testing testing --home=$SEKAID_HOME
# cp root/config.toml $SEKAID_HOME/config/config.toml

sekaid keys add validator --keyring-backend=test --home=$SEKAID_HOME
sekaid add-genesis-account $(sekaid keys show validator -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME

sekaid gentx-claim validator --keyring-backend=test --moniker="hello" --home=$SEKAID_HOME

sekaid start --home=$SEKAID_HOME --abci=grpc --rpc.laddr="tcp://0.0.0.0:26657"
