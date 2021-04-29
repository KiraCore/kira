#!/bin/bash
exec 2>&1
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
set -x

echoInfo "INFO: Staring validator setup ..."

EXECUTED_CHECK="$COMMON_DIR/executed"
SNAP_DIR_INPUT="$COMMON_READ/snap"
SNAP_FILE_INPUT="$COMMON_READ/snap.zip"
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
  
    if (! $(isFileEmpty "$SNAP_FILE_INPUT")) || (! $(isDirEmpty "$SNAP_DIR_INPUT")) ; then
        echoInfo "INFO: Snap file or directory was found, attepting integrity verification and data recovery..."
        if (! $(isFileEmpty "$SNAP_FILE_INPUT")) ; then 
            cd $DATA_DIR
            jar xvf $SNAP_FILE_INPUT
            cd $SEKAID_HOME/config
        elif (! $(isDirEmpty "$SNAP_DIR_INPUT")) ; then
            cp -rfv "$SNAP_DIR_INPUT/." "$DATA_DIR"
        else
            echoErr "ERROR: Snap file or directory was not found"
            exit 1
        fi
  
        SNAP_HEIGHT=$(cat $SNAP_INFO | jsonQuickParse "height" || echo "0")
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
        jq '.app_state.customgov.network_properties.proposal_end_time = "360"' $LOCAL_GENESIS > "$LOCAL_GENESIS.tmp" && cp -afv "$LOCAL_GENESIS.tmp" "$LOCAL_GENESIS" && rm -fv "$LOCAL_GENESIS.tmp"
        jq '.app_state.customgov.network_properties.proposal_enactment_time = "300"' $LOCAL_GENESIS > "$LOCAL_GENESIS.tmp" && cp -afv "$LOCAL_GENESIS.tmp" "$LOCAL_GENESIS" && rm -fv "$LOCAL_GENESIS.tmp"
        jq '.app_state.customgov.network_properties.mischance_confidence = "25"' $LOCAL_GENESIS > "$LOCAL_GENESIS.tmp" && cp -afv "$LOCAL_GENESIS.tmp" "$LOCAL_GENESIS" && rm -fv "$LOCAL_GENESIS.tmp"
        jq '.app_state.customgov.network_properties.max_mischance = "50"' $LOCAL_GENESIS > "$LOCAL_GENESIS.tmp" && cp -afv "$LOCAL_GENESIS.tmp" "$LOCAL_GENESIS" && rm -fv "$LOCAL_GENESIS.tmp"
        # do not allow to unjail after 2 weeks of inactivity
        jq '.app_state.customgov.network_properties.jail_max_time = "1209600"' $LOCAL_GENESIS > "$LOCAL_GENESIS.tmp" && cp -afv "$LOCAL_GENESIS.tmp" "$LOCAL_GENESIS" && rm -fv "$LOCAL_GENESIS.tmp"
        jq '.app_state.customgov.network_properties.mischance_rank_decrease_amount = "1"' $LOCAL_GENESIS > "$LOCAL_GENESIS.tmp" && cp -afv "$LOCAL_GENESIS.tmp" "$LOCAL_GENESIS" && rm -fv "$LOCAL_GENESIS.tmp"
    else
        echoInfo "INFO: Network will be stared from a predefined genesis file..."
        [ ! -f "$COMMON_GENESIS" ] && echoErr "ERROR: Genesis file '$COMMON_GENESIS' was not found" && exit 1
        rm -fv $LOCAL_GENESIS
        cp -afv $COMMON_GENESIS $LOCAL_GENESIS
    fi
  
    if [ "${NEW_NETWORK,,}" == "true" ] ; then
        echoInfo "INFO: New network was created, saving genesis to local directory..."
        cp -afv $LOCAL_GENESIS $COMMON_DIR
    fi
  
    rm -fv $SIGNER_KEY $FAUCET_KEY $VALIDATOR_KEY $TEST_KEY
    touch $EXECUTED_CHECK
fi

echoInfo "INFO: Local genesis.json SHA256 checksum:"
sha256sum $LOCAL_GENESIS

echoInfo "INFO: Loading configuration..."
$SELF_CONTAINER/configure.sh

echoInfo "INFO: Starting validator..."
sekaid start --home=$SEKAID_HOME --trace  
