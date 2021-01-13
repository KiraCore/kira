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
  mkdir -p $SEKAID_HOME/config
  cd $SEKAID_HOME/config

  sekaid init --overwrite --chain-id=testing testing --home=$SEKAID_HOME

  rm -fv $SEKAID_HOME/config/config.toml
  rm -fv $SEKAID_HOME/config/node_key.json
  rm -fv $SEKAID_HOME/config/priv_validator_key.json

  cp -v $COMMON_DIR/config.toml $SEKAID_HOME/config/
  cp -v $COMMON_DIR/node_key.json $SEKAID_HOME/config/
  cp -v $COMMON_DIR/priv_validator_key.json $SEKAID_HOME/config/

  SNAP_FILE="$COMMON_DIR/snap.zip"
  DATA_DIR="$SEKAID_HOME/data"
  GENESIS_FILE="$SEKAID_HOME/config/genesis.json"

  if [ -f "$SNAP_FILE" ] ; then
    echo "INFO: Snap file was found, attepting data recovery..."
    
    unzip ./$SNAP_FILE -d $DATA_DIR
    DATA_GENESIS="$DATA_DIR/genesis.json"

    if [ -f "$DATA_GENESIS" ] ; then
      echo "INFO: Genesis file was found within the snapshoot folder, attempting recovery..."
      rm -fv $COMMON_DIR/genesis.json
      cp -v -a $DATA_DIR/genesis.json $GENESIS_FILE
    fi

    rm -fv "$SNAP_FILE"
  fi

  set +x
  echo "INFO: Attempting accounts recovery"
  SIGNER_KEY=$COMMON_DIR/signer_mnemonic.key && SIGNER_MNEMONIC=$(cat $SIGNER_KEY)
  FAUCET_KEY=$COMMON_DIR/faucet_mnemonic.key && FAUCET_MNEMONIC=$(cat $FAUCET_KEY)
  VALIDATOR_KEY=$COMMON_DIR/validator_mnemonic.key && VALIDATOR_MNEMONIC=$(cat $VALIDATOR_KEY)
  FRONTEND_KEY=$COMMON_DIR/frontend_mnemonic.key && FRONTEND_MNEMONIC=$(cat $FRONTEND_KEY)
  TEST_KEY=$COMMON_DIR/test_mnemonic.key && TEST_MNEMONIC=$(cat $TEST_KEY)

  yes $SIGNER_MNEMONIC | sekaid keys add signer --keyring-backend=test --home=$SEKAID_HOME --recover
  yes $FAUCET_MNEMONIC | sekaid keys add faucet --keyring-backend=test --home=$SEKAID_HOME --recover
  yes $VALIDATOR_MNEMONIC | sekaid keys add validator --keyring-backend=test --home=$SEKAID_HOME --recover
  yes $TEST_MNEMONIC | sekaid keys add test --keyring-backend=test --home=$SEKAID_HOME --recover
  yes $FRONTEND_MNEMONIC | sekaid keys add frontend --keyring-backend=test --home=$SEKAID_HOME --recover

  echo "INFO: All accounts were recovered"
  set +x

  if [ ! -f "$GENESIS_FILE" ] ; then
    echo "INFO: Genesis file was NOT found, attempting to create new one"
    sekaid add-genesis-account $(sekaid keys show validator -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show test -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show frontend -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show signer -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show faucet -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid gentx-claim validator --keyring-backend=test --moniker="Hello World" --home=$SEKAID_HOME
  fi

  rm -fv $SIGNER_KEY $FAUCET_KEY $VALIDATOR_KEY $FRONTEND_KEY $TEST_KEY
  touch $EXECUTED_CHECK
fi

sekaid start --home=$SEKAID_HOME --trace
