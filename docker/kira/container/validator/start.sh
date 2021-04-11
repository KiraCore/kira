#!/bin/bash
exec 2>&1
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
set -x

echoInfo "INFO: Staring validator setup v0.0.3 ..."

EXECUTED_CHECK="$COMMON_DIR/executed"
SNAP_DIR_INPUT="$COMMON_READ/snap"
SNAP_FILE_INPUT="$COMMON_READ/snap.zip"
VALOPERS_FILE="$COMMON_READ/valopers"
DATA_DIR="$SEKAID_HOME/data"
SNAP_INFO="$DATA_DIR/snapinfo.json"
LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
DATA_GENESIS="$DATA_DIR/genesis.json"
COMMON_GENESIS="$COMMON_READ/genesis.json"

if [ ! -f "$EXECUTED_CHECK" ]; then
  rm -rf $SEKAID_HOME
  mkdir -p $SEKAID_HOME/config
  cd $SEKAID_HOME/config

  sekaid init --overwrite --chain-id="$NETWORK_NAME" "KIRA VALIDATOR NODE" --home=$SEKAID_HOME

  echoInfo "INFO: Importing key files from common storage..."
  rm -fv $SEKAID_HOME/config/node_key.json
  rm -fv $SEKAID_HOME/config/priv_validator_key.json
  cp -v $COMMON_DIR/node_key.json $SEKAID_HOME/config/
  cp -v $COMMON_DIR/priv_validator_key.json $SEKAID_HOME/config/

  if [ -f "$SNAP_FILE_INPUT" ] || [ ! -d "$SNAP_DIR_INPUT" ] ; then
    echoInfo "INFO: Snap file or directory was found, attepting integrity verification adn data recovery..."
    if [ -f "$SNAP_FILE_INPUT" ] ; then 
        zip -T -v $SNAP_FILE_INPUT
        rm -rfv "$DATA_DIR" && mkdir -p "$DATA_DIR"
        unzip $SNAP_FILE_INPUT -d $DATA_DIR
    elif [ ! -d "$SNAP_DIR_INPUT" ] ; then
        cp -rfv "$SNAP_DIR_INPUT/." "$DATA_DIR"
    else
        echoErr "ERROR: Snap file or directory was not found"
        exit 1
    fi

    SNAP_HEIGHT=$(jq -rc '.height' $SNAP_INFO || echo "0")
    echoInfo "INFO: Snap height: $SNAP_HEIGHT, minimum height: $VALIDATOR_MIN_HEIGHT"

    if [ -f "$DATA_GENESIS" ] ; then
      echoInfo "INFO: Genesis file was found within the snapshot folder, veryfying checksum..."
      SHA256_DATA_GENESIS=$(sha256sum $DATA_GENESIS | awk '{ print $1 }' | xargs || echo -n "")
      SHA256_COMMON_GENESIS=$(sha256sum $COMMON_GENESIS | awk '{ print $1 }' | xargs || echo -n "")
      if [ -z "$SHA256_DATA_GENESIS" ] || [ "$SHA256_DATA_GENESIS" != "$SHA256_COMMON_GENESIS" ] ; then
          echoErr "ERROR: Expected genesis checksum of the snapshot to be '$SHA256_DATA_GENESIS' but got '$SHA256_COMMON_GENESIS'"
          exit 1
      else
          echoInfo "INFO: Genesis checksum '$SHA256_DATA_GENESIS' was verified sucessfully!"
      fi
    fi
  else
    echoInfo "INFO: Snap file is NOT present"
  fi

  set +x
  echoInfo "INFO: Attempting accounts recovery"
  SIGNER_KEY=$COMMON_DIR/signer_addr_mnemonic.key && SIGNER_ADDR_MNEMONIC=$(cat $SIGNER_KEY)
  FAUCET_KEY=$COMMON_DIR/faucet_addr_mnemonic.key && FAUCET_ADDR_MNEMONIC=$(cat $FAUCET_KEY)
  VALIDATOR_KEY=$COMMON_DIR/validator_addr_mnemonic.key && VALIDATOR_ADDR_MNEMONIC=$(cat $VALIDATOR_KEY)
  TEST_KEY=$COMMON_DIR/test_addr_mnemonic.key && TEST_ADDR_MNEMONIC=$(cat $TEST_KEY)

  yes $SIGNER_ADDR_MNEMONIC | sekaid keys add signer --keyring-backend=test --home=$SEKAID_HOME --recover
  yes $FAUCET_ADDR_MNEMONIC | sekaid keys add faucet --keyring-backend=test --home=$SEKAID_HOME --recover
  yes $VALIDATOR_ADDR_MNEMONIC | sekaid keys add validator --keyring-backend=test --home=$SEKAID_HOME --recover
  yes $TEST_ADDR_MNEMONIC | sekaid keys add test --keyring-backend=test --home=$SEKAID_HOME --recover

  echoInfo "INFO: All accounts were recovered"
 
  sekaid keys list --keyring-backend=test --home=$SEKAID_HOME

  if [ ! -f "$COMMON_GENESIS" ] ; then
    echoInfo "INFO: Genesis file was NOT found, attempting to create new one..."
    [ "${NEW_NETWORK,,}" == "false" ] && echoErr "ERROR: Node was NOT supposed to create new network with new genesis file!" && exit 1

    set +x 
    sekaid add-genesis-account $(sekaid keys show validator -a --keyring-backend=test --home=$SEKAID_HOME) 299998800000000ukex,29999780000000000test,2000000000000000000000000000samolean,1000000lol --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show test -a --keyring-backend=test --home=$SEKAID_HOME) 100000000ukex,10000000000test --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show signer -a --keyring-backend=test --home=$SEKAID_HOME) 100000000ukex,10000000000test --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show faucet -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,200000000000test,3000000000000000000000000000samolean,1000000lol --home=$SEKAID_HOME
    sekaid gentx-claim validator --keyring-backend=test --moniker="GENESIS VALIDATOR" --home=$SEKAID_HOME
    set -x
    # default chain properties
    jq '.app_state.customgov.network_properties.proposal_end_time = "600"' $LOCAL_GENESIS > "$LOCAL_GENESIS.tmp" && cp -afv "$LOCAL_GENESIS.tmp" "$LOCAL_GENESIS" && rm -fv "$LOCAL_GENESIS.tmp"
    jq '.app_state.customgov.network_properties.proposal_enactment_time = "300"' $LOCAL_GENESIS > "$LOCAL_GENESIS.tmp" && cp -afv "$LOCAL_GENESIS.tmp" "$LOCAL_GENESIS" && rm -fv "$LOCAL_GENESIS.tmp"
  else
      echoInfo "INFO: Network will be stared from a predefined genesis file..."
      [ ! -f "$COMMON_GENESIS" ] && echoErr "ERROR: Genesis file '$COMMON_GENESIS' was not found" && exit 1
      rm -fv $LOCAL_GENESIS
      cp -a -v -f $COMMON_GENESIS $LOCAL_GENESIS
  fi

  rm -fv $SIGNER_KEY $FAUCET_KEY $VALIDATOR_KEY $TEST_KEY
  touch $EXECUTED_CHECK
fi

VALIDATOR_ADDR=$(sekaid keys show -a validator --keyring-backend=test --home=$SEKAID_HOME)
TEST_ADDR=$(sekaid keys show -a test --keyring-backend=test --home=$SEKAID_HOME)
SIGNER_ADDR=$(sekaid keys show -a signer --keyring-backend=test --home=$SEKAID_HOME)
FAUCET_ADDR=$(sekaid keys show -a faucet --keyring-backend=test --home=$SEKAID_HOME)
VALOPER_ADDR=$(sekaid val-address $VALIDATOR_ADDR)
CONSPUB_ADDR=$(sekaid tendermint show-validator)

CDHelper text lineswap --insert="TEST_ADDR=$TEST_ADDR" --prefix="TEST_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="SIGNER_ADDR=$SIGNER_ADDR" --prefix="SIGNER_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="FAUCET_ADDR=$FAUCET_ADDR" --prefix="FAUCET_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="VALIDATOR_ADDR=$VALIDATOR_ADDR" --prefix="VALIDATOR_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="VALOPER_ADDR=$VALOPER_ADDR" --prefix="VALOPER_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="CONSPUB_ADDR=$CONSPUB_ADDR" --prefix="CONSPUB_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True

echoInfo "INFO: Local genesis.json SHA256 checksum:"
sha256sum $LOCAL_GENESIS

# block time should vary from minimum of 5.1s to 100ms depending on the validator count. The more vlaidators, the shorter the block time
ACTIVE_VALIDATORS=$(jq -rc '.status.active_validators' $VALOPERS_FILE || echo "0")
(! $(isNaturalNumber "$ACTIVE_VALIDATORS")) && ACTIVE_VALIDATORS=0

if [ "${ACTIVE_VALIDATORS}" != "0" ] ; then
    TIMEOUT_COMMIT=$(echo "scale=3; ((( 5 / ( $ACTIVE_VALIDATORS + 1 ) ) * 1000 ) + 1000) " | bc)
    TIMEOUT_COMMIT=$(echo "scale=0; ( $TIMEOUT_COMMIT / 1 ) " | bc)
    (! $(isNaturalNumber "$TIMEOUT_COMMIT")) && TIMEOUT_COMMIT="5000"
    TIMEOUT_COMMIT="${TIMEOUT_COMMIT}ms"
elif [ -z "$CFG_timeout_commit" ] ; then
    TIMEOUT_COMMIT="5000ms"
else
    TIMEOUT_COMMIT=$CFG_timeout_commit
fi

if [ "$CFG_timeout_commit" != "$TIMEOUT_COMMIT" ] ; then
    echoInfo "INFO: Timeout commit will be changed to ${TIMEOUT_COMMIT}"
    CDHelper text lineswap --insert="CFG_timeout_commit=$TIMEOUT_COMMIT" --prefix="CFG_timeout_commit=" --path=$ETC_PROFILE --append-if-found-not=True
fi

$SELF_CONTAINER/configure.sh
set +e && source "/etc/profile" &>/dev/null && set -e

echoInfo "INFO: Starting validator..."
sekaid start --home=$SEKAID_HOME --trace  
