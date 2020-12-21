#!/bin/bash

exec 2>&1
set -e
set -x

echo "Staring validator..."

EXECUTED_CHECK="/root/executed"
HALT_CHECK="${COMMON_DIR}/halt"

while [ -f "$HALT_CHECK" ]; do
  echo "INFO: Container is prevented from further, executing start script, halt file is present..."
  sleep 30
done

if [ ! -f "$EXECUTED_CHECK" ]; then
  rm -rf $SEKAID_HOME
  
  sekaid init --overwrite --chain-id=testing testing --home=$SEKAID_HOME

  cd $SEKAID_HOME/config

  rm -f $SEKAID_HOME/config/config.toml
  rm -f $SEKAID_HOME/config/node_key.json
  cp $COMMON_DIR/config.toml $SEKAID_HOME/config/
  cp $COMMON_DIR/node_key.json $SEKAID_HOME/config/
  # cp $COMMON_DIR/priv_validator_key.json $SEKAID_HOME/config/

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

  touch $EXECUTED_CHECK
fi

sekaid start --home=$SEKAID_HOME --trace
