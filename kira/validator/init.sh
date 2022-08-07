#!/usr/bin/env bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
# quick edit: FILE="${SELF_CONTAINER}/sekai-init.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

echoInfo "INFO: Started SEKAI init..."

NEW_NETWORK=$(globGet NEW_NETWORK)
PRIVATE_MODE=$(globGet PRIVATE_MODE)

SNAP_FILE_INPUT="$COMMON_READ/snap.tar"
SNAP_INFO="$SEKAID_HOME/data/snapinfo.json"

DATA_DIR="$SEKAID_HOME/data"
LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
DATA_GENESIS="$DATA_DIR/genesis.json"
COMMON_GENESIS="$COMMON_READ/genesis.json"

rm -rf $SEKAID_HOME/*
mkdir -p $SEKAID_HOME/config
cd $SEKAID_HOME/config
  
sekaid init --overwrite --chain-id="$NETWORK_NAME" "KIRA VALIDATOR NODE" --home=$SEKAID_HOME
  
echoInfo "INFO: Importing priv key from common storage..."
cp -afv $COMMON_DIR/priv_validator_key.json $SEKAID_HOME/config/priv_validator_key.json
  
if (! $(isFileEmpty "$SNAP_FILE_INPUT")) ; then
    echoInfo "INFO: Snap file or directory was found, attepting integrity verification and data recovery..."
    cd $DATA_DIR && timerStart SNAP_EXTRACT
    tar -xvf $SNAP_FILE_INPUT -C ./ || ( echoErr "ERROR: Failed extracting '$SNAP_FILE_INPUT'" && sleep 10 && exit 1 )
    echoInfo "INFO: Success, snapshot ($SNAP_FILE_INPUT) was extracted into data directory ($DATA_DIR), elapsed $(timerSpan SNAP_EXTRACT) seconds"
    cd $SEKAID_HOME/config
  
    SNAP_HEIGHT=$(cat $SNAP_INFO | jsonQuickParse "height" || echo "0")
    echoInfo "INFO: Snap height: $SNAP_HEIGHT, minimum height: $MIN_HEIGHT"
  
    if [ -f "$DATA_GENESIS" ] ; then
        echoInfo "INFO: Genesis file was found within the snapshot folder, veryfying checksum..."
        SHA256_DATA_GENESIS=$(sha256 $DATA_GENESIS)
        SHA256_COMMON_GENESIS=$(sha256 $COMMON_GENESIS)
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
VALIDATOR_KEY=$COMMON_DIR/validator_addr_mnemonic.key && VALIDATOR_ADDR_MNEMONIC=$(cat $VALIDATOR_KEY)
TEST_KEY=$COMMON_DIR/test_addr_mnemonic.key && TEST_ADDR_MNEMONIC=$(cat $TEST_KEY)
  
yes $SIGNER_ADDR_MNEMONIC | sekaid keys add signer --keyring-backend=test --home=$SEKAID_HOME --recover
yes $VALIDATOR_ADDR_MNEMONIC | sekaid keys add validator --keyring-backend=test --home=$SEKAID_HOME --recover
yes $TEST_ADDR_MNEMONIC | sekaid keys add test --keyring-backend=test --home=$SEKAID_HOME --recover
set -x

echoInfo "INFO: All accounts were recovered"
sekaid keys list --keyring-backend=test --home=$SEKAID_HOME
  
if [ "${NEW_NETWORK,,}" == "true" ]; then
    echoInfo "INFO: Generating new genesis file..."
    set +x 
    sekaid add-genesis-account $(sekaid keys show validator -a --keyring-backend=test --home=$SEKAID_HOME) 299998800000000ukex,29999780000000000test,2000000000000000000000000000samolean,1000000lol --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show test -a --keyring-backend=test --home=$SEKAID_HOME) 100000000ukex,10000000000test --home=$SEKAID_HOME
    sekaid add-genesis-account $(sekaid keys show signer -a --keyring-backend=test --home=$SEKAID_HOME) 1000000000ukex,200000000000test,3000000000000000000000000000samolean,1000000lol --home=$SEKAID_HOME
    sekaid gentx-claim validator --keyring-backend=test --moniker="GENESIS VALIDATOR" --home=$SEKAID_HOME
    set -x
    # default chain properties
    jsonEdit "app_state.customgov.network_properties.proposal_enactment_time" "\"300\"" $LOCAL_GENESIS $LOCAL_GENESIS
    jsonEdit "app_state.customgov.network_properties.minimum_proposal_end_time" "\"360\"" $LOCAL_GENESIS $LOCAL_GENESIS
    jsonEdit "app_state.customgov.network_properties.mischance_confidence" "\"25\"" $LOCAL_GENESIS $LOCAL_GENESIS
    jsonEdit "app_state.customgov.network_properties.max_mischance" "\"50\"" $LOCAL_GENESIS $LOCAL_GENESIS
    # do not allow to unjail after 2 weeks of inactivity
    jsonEdit "app_state.customgov.network_properties.unjail_max_time" "\"1209600\"" $LOCAL_GENESIS $LOCAL_GENESIS
    jsonEdit "app_state.customgov.network_properties.mischance_rank_decrease_amount" "\"1\"" $LOCAL_GENESIS $LOCAL_GENESIS

    echoInfo "INFO: New network was created, saving genesis to local directory..."
    cp -afv $LOCAL_GENESIS $COMMON_DIR/genesis.json
else
    echoInfo "INFO: Network will be stared from a predefined genesis file..."
    [ ! -f "$COMMON_GENESIS" ] && echoErr "ERROR: Genesis file '$COMMON_GENESIS' was NOT found" && exit 1
    rm -rfv $LOCAL_GENESIS
    ln -sfv $COMMON_GENESIS $LOCAL_GENESIS
fi
  
rm -fv $SIGNER_KEY $VALIDATOR_KEY $TEST_KEY

echoInfo "INFO: Finished SEKAI init"