#!/bin/bash

exec 2>&1
set -e

if [ "$DEBUG_MODE" == "True" ] ; then set -x ; else set +x ; fi

# (rm -fv $KIRA_INFRA/docker/validator/container/on_init.sh) && nano $KIRA_INFRA/docker/validator/container/on_init.sh

echo "Staring on-init script..."
SEKAID_HOME=$HOME/.sekaid
SEKAID_CONFIG=$SEKAID_HOME/config
NODE_KEY_PATH=$SEKAID_CONFIG/node_key.json
APP_TOML_PATH=$SEKAID_CONFIG/app.toml
GENESIS_JSON_PATH=$SEKAID_CONFIG/genesis.json
CONFIG_TOML_PATH=$SEKAID_CONFIG/config.toml
INIT_START_FILE=$HOME/init_started
INIT_END_FILE=$HOME/init_ended
SIGNING_KEY_PATH="$SEKAID_CONFIG/priv_validator_key.json"

[ -z "$VALIDATOR_INDEX" ] && VALIDATOR_INDEX=1

[ ! -f "$NODE_KEY" ] && NODE_KEY="$SELF_CONFIGS/node-keys/node-key-${VALIDATOR_INDEX}.json"
[ ! -f "$NODE_KEY" ] && NODE_KEY="$COMMON_DIR/node-keys/node-key-${VALIDATOR_INDEX}.json"
[ ! -f "$NODE_KEY" ] && echo "ERROR: Node key was not found" && exit 1

[ ! -f "$SIGNING_KEY" ] && SIGNING_KEY="$SELF_CONFIGS/signing-keys/signing-${VALIDATOR_INDEX}.json"
[ ! -f "$SIGNING_KEY" ] && SIGNING_KEY="$COMMON_DIR/signing-keys/signing-${VALIDATOR_INDEX}.json"
[ ! -f "$SIGNING_KEY" ] && echo "ERROR: Signing key was not found" && exit 1

P2P_LOCAL_PORT=26656
RPC_LOCAL_PORT=26657
GRPC_LOCAL_PORT=9090
RLY_LOCAL_PORT=8000

[ -z "$P2P_PROXY_PORT" ] && P2P_PROXY_PORT="10000"
[ -z "$RPC_PROXY_PORT" ] && RPC_PROXY_PORT="10001"
[ -z "$LCD_PROXY_PORT" ] && LCD_PROXY_PORT="10002"
[ -z "$RLY_PROXY_PORT" ] && RLY_PROXY_PORT="10003"
[ -z "$GRPC_PROXY_PORT" ] && GRPC_PROXY_PORT="10004"

HOST_IP=$(hostname -i)

[ -z "$NODE_ADDESS" ] && NODE_ADDESS="tcp://localhost:$RPC_LOCAL_PORT"
[ -z "$CHAIN_JSON_FULL_PATH" ] && CHAIN_JSON_FULL_PATH="$SELF_CONFIGS/$CHAIN_ID.json"
[ -z "$PASSPHRASE" ] && PASSPHRASE="1234567890"
[ -z "$KEYRINGPASS" ] && KEYRINGPASS="1234567890"
[ -z "$MONIKER" ] && MONIKER="Test Chain Moniker"

if [ -f "$CHAIN_JSON_FULL_PATH" ] ; then
    echo "Chain configuration file was defined, loading JSON"
    CHAIN_ID="$(cat $CHAIN_JSON_FULL_PATH | jq -r '.["chain-id"]')"
    DENOM="$(cat $CHAIN_JSON_FULL_PATH | jq -r '.["default-denom"]')"
    RLYKEY=$(cat $CHAIN_JSON_FULL_PATH | jq -r '.key')
    cat $CHAIN_JSON_FULL_PATH > $CHAIN_ID.json 
else
    echo "Chain configuration file was NOT defined, loading ENV's"
    [ -z "$DENOM" ] && DENOM="ukex"
    [ -z "$CHAIN_ID" ] && CHAIN_ID="kira-1"
    [ -z "$RPC_ADDR" ] && RPC_ADDR="http://${ROUTE53_RECORD_NAME}.kiraex.com:${RPC_PROXY_PORT}"
    [ -z "$RLYKEY" ] && RLYKEY="faucet"
    [ -z "$ACCOUNT_PREFIX" ] && ACCOUNT_PREFIX="kira"
    [ -z "$GAS" ] && GAS="200000"
    [ -z "$GAS_PRICES" ] && GAS_PRICES="0.0025$DENOM"
    [ -z "$RLYTRUSTING" ] && RLYTRUSTING="21d"
    echo "{\"key\":\"$RLYKEY\",\"chain-id\":\"$CHAIN_ID\",\"rpc-addr\":\"$RPC_ADDR\",\"account-prefix\":\"$ACCOUNT_PREFIX\",\"gas\":$GAS,\"gas-prices\":\"$GAS_PRICES\",\"default-denom\":\"$DENOM\",\"trusting-period\":\"$RLYTRUSTING\"}" > $CHAIN_ID.json
fi

mkdir -p "$COMMON_DIR/node-keys"
mkdir -p "$COMMON_DIR/signing-keys"
mkdir -p "$COMMON_DIR/test-keys"
mkdir -p "$COMMON_DIR/validator-keys"

sekaid init --chain-id="$CHAIN_ID" "$MONIKER"

# NOTE: can be supplied from parameter, in such case following instruction can be used: sed -i 's/\\\"/\"/g' $PATH_TO_FILE
# NOTE: to VALIDATOR_KEY new key delete $SIGNING_KEY_PATH and run sekaid start 
# NOTE: to create new key delete $NODE_KEY_PATH and run sekaid start
cat $NODE_KEY > $NODE_KEY_PATH
echo "INFO: Node ID: $(sekaid tendermint show-node-id)"
cat $SIGNING_KEY > $SIGNING_KEY_PATH
echo "INFO: Signing key: $(sekaid tendermint show-validator)"

# NOTE: ensure that the sekai rpc is open to all connections
# CDHelper text replace --old="tcp://127.0.0.1:26657" --new="tcp://0.0.0.0:$RPC_LOCAL_PORT" --input=$CONFIG_TOML_PATH
CDHelper text replace --old="stake" --new="$DENOM" --input=$GENESIS_JSON_PATH

CDHelper text lineswap --insert="addr_book_strict = false" --prefix="addr_book_strict =" --path=$CONFIG_TOML_PATH
CDHelper text lineswap --insert="external_address = \"tcp://$HOST_IP:$P2P_LOCAL_PORT\"" --prefix="external_address =" --path=$CONFIG_TOML_PATH
CDHelper text lineswap --insert="cors_allowed_origins = [\"*\"]" --prefix="cors_allowed_origins =" --path=$CONFIG_TOML_PATH
CDHelper text lineswap --insert="unsafe = true" --prefix="unsafe =" --path=$CONFIG_TOML_PATH
CDHelper text lineswap --insert="pruning = \"nothing\"" --prefix="pruning =" --path=$APP_TOML_PATH

if [ ! -z "$SEEDS" ] ; then # NOTE: In some cases '@' characters cause line splits
    SEEDS=$(echo $SEEDS | xargs)
     
    SEEDS=$(echo "seeds = \"$SEEDS\"" | tr -d '\n' | tr -d '\r')
    CDHelper text lineswap --insert="$SEEDS" --prefix="seeds =" --path=$CONFIG_TOML_PATH
fi
if [ ! -z "$PEERS" ] ; then # NOTE: In some cases '@' characters cause line splits
    PEERS=$(echo $PEERS | xargs)
    PEERS=$(echo "persistent_peers = \"$PEERS\"" | tr -d '\n' | tr -d '\r')
    CDHelper text lineswap --insert="$PEERS" --prefix="persistent_peers =" --path=$CONFIG_TOML_PATH
fi

if [ $VALIDATOR_INDEX -eq 1 ] ; then # first validator always creates a genesis tx
    echo "INFO: Creating genesis file..."
    for ((i=1;i<=$VALIDATORS_COUNT;i++)); do
        TEST_ACC_NAME="test-$i"
        VALIDATOR_ACC_NAME="validator-$i"
        TMP_NODE_KEY="$SELF_CONFIGS/node-keys/node-key-$i.json"
        COM_NODE_KEY="$COMMON_DIR/node-keys/node-key-$i.json"
        TMP_SIGNING_KEY="$SELF_CONFIGS/signing-keys/signing-$i.json"
        COM_SIGNING_KEY="$COMMON_DIR/signing-keys/signing-$i.json"
        COM_TEST_KEY="$COMMON_DIR/test-keys/$TEST_ACC_NAME.key"
        COM_VALIDATOR_KEY="$COMMON_DIR/validator-keys/$VALIDATOR_ACC_NAME.key"

        echo "INFO: Adding $TEST_ACC_NAME account..."
        echo "INFO: Adding $VALIDATOR_ACC_NAME account..."
        $SELF_SCRIPTS/add-account.sh $TEST_ACC_NAME "test-keys/$TEST_ACC_NAME" $KEYRINGPASS $PASSPHRASE
        $SELF_SCRIPTS/add-account.sh $VALIDATOR_ACC_NAME "validator-keys/$VALIDATOR_ACC_NAME" $KEYRINGPASS $PASSPHRASE
        $SELF_SCRIPTS/export-account.sh $TEST_ACC_NAME $COM_TEST_KEY $KEYRINGPASS $PASSPHRASE
        $SELF_SCRIPTS/export-account.sh $VALIDATOR_ACC_NAME $COM_VALIDATOR_KEY $KEYRINGPASS $PASSPHRASE
        echo ${KEYRINGPASS} | sekaid keys list
        TEST_ACC_ADDR=$(echo ${KEYRINGPASS} | sekaid keys show "$TEST_ACC_NAME" -a)
        VALIDATOR_ACC_ADDR=$(echo ${KEYRINGPASS} | sekaid keys show "$VALIDATOR_ACC_NAME" -a)
        echo "SUCCESS: Accounts $TEST_ACC_ADDR and $VALIDATOR_ACC_ADDR were created"

        echo "INFO: Adding genesis accounts..."
        sekaid add-genesis-account $TEST_ACC_ADDR 100000000000000$DENOM,10000000samoleans,100000000uatom,1000000usent,100000000ubtc
        sekaid add-genesis-account $VALIDATOR_ACC_ADDR 200000000000000$DENOM,1000000000stake,1000000000validatortoken

        echo "INFO: Creating $VALIDATOR_ACC_NAME genesis tx..."
        if [ ! -f "$TMP_NODE_KEY" ] || [ ! -f "$TMP_SIGNING_KEY" ] ; then
            echo "INFO: Generating new node & signing keys..."
            rm -f $NODE_KEY_PATH
            rm -f $SIGNING_KEY_PATH
            timeout 2 sekaid start || echo "INFO: Forced timeout"
            cat $NODE_KEY_PATH > $TMP_NODE_KEY
            cat $SIGNING_KEY_PATH > $TMP_SIGNING_KEY
        fi

        #signing key has to be rotated as it is used by default by the gentx
        cat $TMP_NODE_KEY > $NODE_KEY_PATH
        cat $TMP_NODE_KEY > $COM_NODE_KEY
        cat $TMP_SIGNING_KEY > $SIGNING_KEY_PATH
        cat $TMP_SIGNING_KEY > $COM_SIGNING_KEY
        TMP_NODE_ID=$(sekaid tendermint show-node-id)
        TMP_CONSPUB=$(sekaid tendermint show-validator)
        TMP_ADDRESS=$(sekaid tendermint show-address)
        echo "INFO: Node Id: $TMP_NODE_ID"
        echo "INFO: Cons Pub: $TMP_CONSPUB"
        echo "INFO: Address: $TMP_ADDRESS"
        #--node-id "$TMP_NODE_ID" --details "Kira Hub Validator $i"
        sekaid gentx-claim $VALIDATOR_ACC_NAME << EOF
$KEYRINGPASS
$KEYRINGPASS
$KEYRINGPASS
EOF
    done
    
    # original signing key and node-id has to be recovered
    echo "INFO: Key recovery and chain hard reset"
    cat $NODE_KEY > $NODE_KEY_PATH
    cat $SIGNING_KEY > $SIGNING_KEY_PATH

elif [ -f "$COMMON_DIR/genesis.json" ] ; then # import genesis if shared file already exists
    echo "INFO: Adding test-$VALIDATOR_INDEX account..."
    $SELF_SCRIPTS/add-account.sh "test-$VALIDATOR_INDEX" "test-keys/test-$VALIDATOR_INDEX" $KEYRINGPASS $PASSPHRASE
    echo "INFO: Adding validator-$VALIDATOR_INDEX account..."
    $SELF_SCRIPTS/add-account.sh "validator-$VALIDATOR_INDEX" "validator-keys/validator-$VALIDATOR_INDEX" $KEYRINGPASS $PASSPHRASE
    echo "INFO: Loading existing genesis file..."
    cat "$COMMON_DIR/genesis.json" > $GENESIS_JSON_PATH
else
    echo "ERROR: Failed to find existing genesis file"
    exit 1
fi

echo "INFO: Chain restart..."
sekaid unsafe-reset-all

echo "INFO: Setting up services..."
cat > /etc/systemd/system/sekaid.service << EOL
[Unit]
Description=sekaid
After=network.target
[Service]
Type=simple
User=root
WorkingDirectory=/usr/local
ExecStart=$SEKAID_BIN start --pruning=nothing --home=$SEKAID_HOME --grpc.address=127.0.0.1:$GRPC_LOCAL_PORT --grpc.enable=true
Restart=always
RestartSec=5
LimitNOFILE=4096
[Install]
WantedBy=multi-user.target
EOL

#cat > /etc/systemd/system/lcd.service << EOL
#[Unit]
#Description=Light Client Daemon Service
#After=network.target
#[Service]
#Type=simple
#EnvironmentFile=/etc/environment
#ExecStart=$SEKAID_BIN rest-server --chain-id=$CHAIN_ID --home=$SEKAID_HOME --node=$NODE_ADDESS 
#Restart=always
#RestartSec=5
#LimitNOFILE=4096
#[Install]
#WantedBy=default.target
#EOL

#cat > /etc/systemd/system/faucet.service << EOL
#[Unit]
#Description=faucet
#After=network.target
#[Service]
#Type=simple
#User=root
#WorkingDirectory=/usr/local
#ExecStart=$RLY_BIN testnets faucet $CHAIN_ID $RLYKEY 200000000$DENOM
#Restart=always
#RestartSec=5
#LimitNOFILE=4096
#[Install]
#WantedBy=multi-user.target
#EOL

#systemctl2 enable faucet.service
systemctl2 enable sekaid.service
#systemctl2 enable lcd.service
systemctl2 enable nginx.service

#systemctl2 status faucet.service || true
systemctl2 status sekaid.service || true
#systemctl2 status lcd.service || true
systemctl2 status nginx.service || true

${SELF_SCRIPTS}/local-cors-proxy.sh $RPC_PROXY_PORT http://127.0.0.1:$RPC_LOCAL_PORT; wait
${SELF_SCRIPTS}/local-cors-proxy.sh $P2P_PROXY_PORT http://127.0.0.1:$P2P_LOCAL_PORT; wait
${SELF_SCRIPTS}/local-cors-proxy-grpc.sh $GRPC_PROXY_PORT grpc://127.0.0.1:$GRPC_LOCAL_PORT; wait
#${SELF_SCRIPTS}/local-cors-proxy-v0.0.1.sh $RLY_PROXY_PORT http://127.0.0.1:$RLY_LOCAL_PORT; wait

#echo "AWS Account Setup..."
#
#aws configure set output $AWS_OUTPUT
#aws configure set region $AWS_REGION
#aws configure set aws_access_key_id "$AWS_ACCESS_KEY_ID"
#aws configure set aws_secret_access_key "$AWS_SECRET_ACCESS_KEY"
#
#aws configure list

echo "INFO: Starting services..."
systemctl2 restart nginx || systemctl2 status nginx.service || echo "Failed to re-start nginx service"
systemctl2 restart sekaid || systemctl2 status sekaid.service || echo "Failed to re-start sekaid service" && echo "$(cat /etc/systemd/system/sekaid.service)" || true
#systemctl2 restart lcd || systemctl2 status lcd.service || echo "Failed to re-start lcd service" && echo "$(cat /etc/systemd/system/lcd.service)" || true
#systemctl2 restart faucet || echo "Failed to re-start faucet service" && echo "$(cat /etc/systemd/system/faucet.service)" || true


echo "INFO: Setting up CLI..."
# sekaid config trust-node true
# sekaid config chain-id $(cat $GENESIS_JSON_PATH | jq -r '.chain_id')
# sekaid config node tcp://localhost:$RPC_LOCAL_PORT


if [ "$NOTIFICATIONS" == "True" ] ; then
CDHelper email send \
 --to="$EMAIL_NOTIFY" \
 --subject="[$MONIKER] Was Initalized Sucessfully" \
 --body="[$(date)] Attached $(find $SELF_LOGS -type f | wc -l) Log Files" \
 --html="false" \
 --recursive="true" \
 --attachments="$SELF_LOGS,$JOURNAL_LOGS"
fi
