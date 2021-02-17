#!/bin/bash
exec 2>&1
set +e && source "/etc/profile" &>/dev/null && set -e
set -x

echo "INFO: Staring validator setup v0.0.3 ..."

EXECUTED_CHECK="$COMMON_DIR/executed"
SNAP_FILE="$COMMON_DIR/snap.zip"
DATA_DIR="$SEKAID_HOME/data"
LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
DATA_GENESIS="$DATA_DIR/genesis.json"
COMMON_GENESIS="$COMMON_DIR/genesis.json"

if [ ! -f "$EXECUTED_CHECK" ]; then
  rm -rf $SEKAID_HOME
  mkdir -p $SEKAID_HOME/config
  cd $SEKAID_HOME/config

  sekaid init --overwrite --chain-id="$NETWORK_NAME" "KIRA VALIDATOR NODE" --home=$SEKAID_HOME

  $SELF_CONTAINER/configure.sh
  set +e && source "/etc/profile" &>/dev/null && set -e

  echo "INFO: Importing key files from common storage..."
  rm -fv $SEKAID_HOME/config/node_key.json
  rm -fv $SEKAID_HOME/config/priv_validator_key.json
  cp -v $COMMON_DIR/node_key.json $SEKAID_HOME/config/
  cp -v $COMMON_DIR/priv_validator_key.json $SEKAID_HOME/config/

  if [ -f "$SNAP_FILE" ] ; then
    echo "INFO: Snap file was found, attepting data recovery..."
    
    rm -rfv "$DATA_DIR" && mkdir -p "$DATA_DIR"
    unzip $SNAP_FILE -d "$DATA_DIR"

    if [ -f "$DATA_GENESIS" ] ; then
      echo "INFO: Genesis file was found within the snapshot folder, attempting recovery..."
      rm -fv $COMMON_GENESIS
      cp -v -a $DATA_GENESIS $COMMON_GENESIS
      cp -v -a $DATA_GENESIS $LOCAL_GENESIS
    fi

    rm -fv "$SNAP_FILE"
  else
    echo "INFO: Snap file is NOT present"
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

  if [ "${EXTERNAL_SYNC,,}" == "false" ] ; then
    echo "INFO: Genesis file was NOT found, attempting to create new one"
    sekaid add-genesis-account $(sekaid keys show validator -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show test -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show frontend -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show signer -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show faucet -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,1000000000validatortoken,1000000000stake --home=$SEKAID_HOME
    sekaid gentx-claim validator --keyring-backend=test --moniker="GENESIS VALIDATOR" --home=$SEKAID_HOME

    # default chain properties
    jq '.app_state.customgov.network_properties.proposal_end_time = "600"' $LOCAL_GENESIS > "$LOCAL_GENESIS.tmp" && cp -afv "$LOCAL_GENESIS.tmp" "$LOCAL_GENESIS" && rm -fv "$LOCAL_GENESIS.tmp"
    jq '.app_state.customgov.network_properties.proposal_enactment_time = "300"' $LOCAL_GENESIS > "$LOCAL_GENESIS.tmp" && cp -afv "$LOCAL_GENESIS.tmp" "$LOCAL_GENESIS" && rm -fv "$LOCAL_GENESIS.tmp"
  else
      echo "INFO: Network will be stared from a predefined genesis file..."
      [ ! -f "$COMMON_GENESIS" ] && echo "ERROR: Genesis file '$COMMON_GENESIS' was not found" && exit 1
      rm -fv $LOCAL_GENESIS
      cp -a -v -f $COMMON_GENESIS $LOCAL_GENESIS
  fi

  rm -fv $COMMON_GENESIS
  cp -a -v -f $LOCAL_GENESIS $COMMON_GENESIS

  echo "INFO: genesis.json SHA256 checksum:"
  sha256sum $COMMON_GENESIS

  rm -fv $SIGNER_KEY $FAUCET_KEY $VALIDATOR_KEY $FRONTEND_KEY $TEST_KEY
fi

VALIDATOR_ADDR=$(sekaid keys show -a validator --keyring-backend=test --home=$SEKAID_HOME)
TEST_ADDR=$(sekaid keys show -a test --keyring-backend=test --home=$SEKAID_HOME)
FRONTEND_ADDR=$(sekaid keys show -a frontend --keyring-backend=test --home=$SEKAID_HOME)
SIGNER_ADDR=$(sekaid keys show -a signer --keyring-backend=test --home=$SEKAID_HOME)
FAUCET_ADDR=$(sekaid keys show -a faucet --keyring-backend=test --home=$SEKAID_HOME)
VALOPER_ADDR=$(sekaid val-address $VALIDATOR_ADDR)
CONSPUB_ADDR=$(sekaid tendermint show-validator)

CDHelper text lineswap --insert="TEST_ADDR=$TEST_ADDR" --prefix="TEST_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="SIGNER_ADDR=$SIGNER_ADDR" --prefix="SIGNER_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="FAUCET_ADDR=$FAUCET_ADDR" --prefix="FAUCET_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="FRONTEND_ADDR=$FRONTEND_ADDR" --prefix="FRONTEND_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="VALIDATOR_ADDR=$VALIDATOR_ADDR" --prefix="VALIDATOR_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="VALOPER_ADDR=$VALOPER_ADDR" --prefix="VALOPER_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="CONSPUB_ADDR=$CONSPUB_ADDR" --prefix="CONSPUB_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True

touch $EXECUTED_CHECK
sekaid start --home=$SEKAID_HOME --trace
