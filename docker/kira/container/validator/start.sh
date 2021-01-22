#!/bin/bash

exec 2>&1
set -e
set -x

echo "INFO: Staring validator setup v0.0.3 ..."

EXECUTED_CHECK="$COMMON_DIR/executed"

if [ ! -f "$EXECUTED_CHECK" ]; then
  rm -rf $SEKAID_HOME
  mkdir -p $SEKAID_HOME/config
  cd $SEKAID_HOME/config

  sekaid init --overwrite --chain-id="$NETWORK_NAME" "KIRA VALIDATOR NODE" --home=$SEKAID_HOME

  $SELF_CONTAINER/configure.sh

  echo "INFO: Importing key files from common storage..."
  rm -fv $SEKAID_HOME/config/node_key.json
  rm -fv $SEKAID_HOME/config/priv_validator_key.json
  cp -v $COMMON_DIR/node_key.json $SEKAID_HOME/config/
  cp -v $COMMON_DIR/priv_validator_key.json $SEKAID_HOME/config/

  SNAP_FILE="$COMMON_DIR/snap.zip"
  DATA_DIR="$SEKAID_HOME/data"
  LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
  DATA_GENESIS="$DATA_DIR/genesis.json"
  COMMON_GENESIS="$COMMON_DIR/genesis.json"

  if [ -f "$SNAP_FILE" ] ; then
    echo "INFO: Snap file was found, attepting data recovery..."
    
    rm -rfv "$DATA_DIR" && mkdir -p "$DATA_DIR"
    unzip $SNAP_FILE -d "$DATA_DIR"

    if [ -f "$DATA_GENESIS" ] ; then
      echo "INFO: Genesis file was found within the snapshoot folder, attempting recovery..."
      rm -fv $COMMON_GENESIS
      cp -v -a $DATA_GENESIS $COMMON_GENESIS
      cp -v -a $DATA_GENESIS $LOCAL_GENESIS
    fi

    rm -fv "$SNAP_FILE"
  else
    echo "INFO: Snap file is NOT present, starting new sync..."
  fi

  set +x
  echo "INFO: Attempting accounts recovery"
  SIGNER_KEY=$COMMON_DIR/signer_addr_mnemonic.key && SIGNER_ADDR_MNEMONIC=$(cat $SIGNER_KEY)
  FAUCET_KEY=$COMMON_DIR/faucet_addr_mnemonic.key && FAUCET_ADDR_MNEMONIC=$(cat $FAUCET_KEY)
  VALIDATOR_KEY=$COMMON_DIR/validator_addr_mnemonic.key && VALIDATOR_ADDR_MNEMONIC=$(cat $VALIDATOR_KEY)
  FRONTEND_KEY=$COMMON_DIR/frontend_addr_mnemonic.key && FRONTEND_ADDR_MNEMONIC=$(cat $FRONTEND_KEY)
  TEST_KEY=$COMMON_DIR/test_addr_mnemonic.key && TEST_ADDR_MNEMONIC=$(cat $TEST_KEY)

  yes $SIGNER_ADDR_MNEMONIC | sekaid keys add signer --keyring-backend=test --home=$SEKAID_HOME --recover
  yes $FAUCET_ADDR_MNEMONIC | sekaid keys add faucet --keyring-backend=test --home=$SEKAID_HOME --recover
  yes $VALIDATOR_ADDR_MNEMONIC | sekaid keys add validator --keyring-backend=test --home=$SEKAID_HOME --recover
  yes $TEST_ADDR_MNEMONIC | sekaid keys add test --keyring-backend=test --home=$SEKAID_HOME --recover
  yes $FRONTEND_ADDR_MNEMONIC | sekaid keys add frontend --keyring-backend=test --home=$SEKAID_HOME --recover

  echo "INFO: All accounts were recovered"
  set +x

  sekaid keys list --keyring-backend=test --home=$SEKAID_HOME

  if [ ! -f "$COMMON_GENESIS" ] ; then
    echo "INFO: Genesis file was NOT found, attempting to create new one"
    sekaid add-genesis-account $(sekaid keys show validator -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show test -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show frontend -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show signer -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show faucet -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid gentx-claim validator --keyring-backend=test --moniker="Hello World" --home=$SEKAID_HOME
  else
      echo "INFO: Common genesis file was found, attempting recovery..."
      cp -v -a $COMMON_GENESIS $LOCAL_GENESIS
  fi

  cp -v -a $LOCAL_GENESIS $COMMON_GENESIS

  rm -fv $SIGNER_KEY $FAUCET_KEY $VALIDATOR_KEY $FRONTEND_KEY $TEST_KEY
  touch $EXECUTED_CHECK
fi

sekaid start --home=$SEKAID_HOME --trace
