#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
# quick edit: FILE="${SELF_CONTAINER}/configure.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
exec 2>&1
set -x

CFG_CHECK="${COMMON_DIR}/configuring"
touch $CFG_CHECK

echoInfo "INFO: Starting $NODE_TYPE node configuration..."

CFG="$SEKAID_HOME/config/config.toml"
APP="$SEKAID_HOME/config/app.toml"
COMMON_PEERS_PATH="$COMMON_DIR/peers"
COMMON_SEEDS_PATH="$COMMON_DIR/seeds"
LOCAL_PEERS_PATH="$SEKAID_HOME/config/peers"
LOCAL_SEEDS_PATH="$SEKAID_HOME/config/seeds"
LOCAL_RPC_PATH="$SEKAID_HOME/config/rpc"

VALOPERS_FILE="$COMMON_READ/valopers"
COMMON_GENESIS="$COMMON_READ/genesis.json"

DATA_DIR="$SEKAID_HOME/data"
DATA_GENESIS="$DATA_DIR/genesis.json"
LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
LOCAL_STATE="$SEKAID_HOME/data/priv_validator_state.json"

[ -f "$COMMON_PEERS_PATH" ] && cp -afv "$COMMON_PEERS_PATH" "$LOCAL_PEERS_PATH"
[ -f "$COMMON_SEEDS_PATH" ] && cp -afv "$COMMON_SEEDS_PATH" "$LOCAL_SEEDS_PATH"

LOCAL_IP=$(globGet LOCAL_IP "$GLOBAL_COMMON_RO")
PUBLIC_IP=$(globGet PUBLIC_IP "$GLOBAL_COMMON_RO")
LATEST_BLOCK_HEIGHT=$(globGet latest_block_height "$GLOBAL_COMMON_RO")
NEW_NETWORK=$(globGet NEW_NETWORK "$GLOBAL_COMMON_RO")
MIN_HEIGHT=$(globGet MIN_HEIGHT "$GLOBAL_COMMON_RO")

CFG_pex=$(globGet CFG_pex)
CFG_moniker=$(globGet CFG_moniker)
CFG_allow_duplicate_ip=$(globGet CFG_allow_duplicate_ip)
CFG_addr_book_strict=$(globGet CFG_addr_book_strict)
CFG_fastsync=$(globGet CFG_fastsync)
CFG_fastsync_version=$(globGet CFG_fastsync_version)
CFG_handshake_timeout=$(globGet CFG_handshake_timeout)
CFG_dial_timeout=$(globGet CFG_dial_timeout)
CFG_trust_period=$(globGet CFG_trust_period)
CFG_max_txs_bytes=$(globGet CFG_max_txs_bytes)
CFG_max_tx_bytes=$(globGet CFG_max_tx_bytes)
CFG_send_rate=$(globGet CFG_send_rate)
CFG_recv_rate=$(globGet CFG_recv_rate)
CFG_max_packet_msg_payload_size=$(globGet CFG_max_packet_msg_payload_size)
CFG_cors_allowed_origins=$(globGet CFG_cors_allowed_origins)
CFG_snapshot_interval=$(globGet CFG_snapshot_interval)
CFG_statesync_enable=$(globGet CFG_statesync_enable)
CFG_statesync_temp_dir=$(globGet CFG_statesync_temp_dir)
CFG_create_empty_blocks_interval=$(globGet CFG_create_empty_blocks_interval)
CFG_timeout_commit=$(globGet CFG_timeout_commit)
CFG_max_num_outbound_peers=$(globGet CFG_max_num_outbound_peers)
CFG_max_num_inbound_peers=$(globGet CFG_max_num_inbound_peers)
CFG_prometheus=$(globGet CFG_prometheus)
CFG_seed_mode=$(globGet CFG_seed_mode)
CFG_skip_timeout_commit=$(globGet CFG_skip_timeout_commit)
CFG_unconditional_peer_ids=$(globGet CFG_unconditional_peer_ids)
CFG_persistent_peers=$(globGet CFG_persistent_peers)
CFG_seeds=$(globGet CFG_seeds)
CFG_grpc_laddr=$(globGet CFG_grpc_laddr)
CFG_rpc_laddr=$(globGet CFG_rpc_laddr)
CFG_p2p_laddr=$(globGet CFG_p2p_laddr)

PRIVATE_MODE=$(globGet PRIVATE_MODE)

echoInfo "INFO: Setting up node key..."
cp -afv $COMMON_DIR/node_key.json $SEKAID_HOME/config/node_key.json

[ "${NODE_TYPE,,}" == "validator" ] && \
    echoInfo "INFO: Setting up priv validator key..." && \
    cp -afv $COMMON_DIR/priv_validator_key.json $SEKAID_HOME/config/priv_validator_key.json

[ "${PRIVATE_MODE,,}" == "true" ] && EXTERNAL_DNS="$LOCAL_IP" || EXTERNAL_DNS="$PUBLIC_IP"

EXTERNAL_ADDRESS="tcp://$EXTERNAL_DNS:$EXTERNAL_P2P_PORT"
globSet EXTERNAL_ADDRESS "$EXTERNAL_ADDRESS"
globSet EXTERNAL_DNS "$EXTERNAL_DNS"
globSet EXTERNAL_PORT "$EXTERNAL_P2P_PORT"

echoInfo "INFO:    Local Addr: $LOCAL_IP"
echoInfo "INFO:   Public Addr: $PUBLIC_IP"
echoInfo "INFO: External Addr: $EXTERNAL_ADDRESS"

echoInfo "INFO: Starting state file configuration..."
STATE_HEIGHT=$(jsonQuickParse "height" $LOCAL_STATE || echo "")
(! $(isNaturalNumber $STATE_HEIGHT)) && STATE_HEIGHT=0
(! $(isNaturalNumber $MIN_HEIGHT)) && MIN_HEIGHT=0
(! $(isNaturalNumber $LATEST_BLOCK_HEIGHT)) && LATEST_BLOCK_HEIGHT=0
[[ $MIN_HEIGHT -gt $LATEST_BLOCK_HEIGHT ]] && LATEST_BLOCK_HEIGHT=$MIN_HEIGHT
[[ $STATE_HEIGHT -gt $LATEST_BLOCK_HEIGHT ]] && LATEST_BLOCK_HEIGHT=$STATE_HEIGHT

echoInfo "INFO: Starting genesis configuration..."
if [[ "${NODE_TYPE,,}" =~ ^(sentry|seed|snapshot)$ ]] ; then
    rm -fv $LOCAL_GENESIS
    cp -afv $COMMON_GENESIS $LOCAL_GENESIS # recover genesis from common folder
elif [ "${NODE_TYPE,,}" == "validator" ] ; then

    validatorAddr=$(sekaid keys show -a validator --keyring-backend=test --home=$SEKAID_HOME || echo "")
    testAddr=$(sekaid keys show -a test --keyring-backend=test --home=$SEKAID_HOME || echo "")
    signerAddr=$(sekaid keys show -a signer --keyring-backend=test --home=$SEKAID_HOME || echo "")
    faucetAddr=$(sekaid keys show -a faucet --keyring-backend=test --home=$SEKAID_HOME || echo "")
    valoperAddr=$(sekaid val-address $validatorAddr || echo "")
    consPubAddr=$(sekaid tendermint show-validator || echo "")
    
    [ "$VALIDATOR_ADDR" != "$validatorAddr" ] && CDHelper text lineswap --insert="VALIDATOR_ADDR=$validatorAddr" --prefix="VALIDATOR_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
    [ "$TEST_ADDR" != "$testAddr" ]           && CDHelper text lineswap --insert="TEST_ADDR=$testAddr" --prefix="TEST_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
    [ "$SIGNER_ADDR" != "$signerAddr" ]       && CDHelper text lineswap --insert="SIGNER_ADDR=$signerAddr" --prefix="SIGNER_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
    [ "$FAUCET_ADDR" != "$faucetAddr" ]       && CDHelper text lineswap --insert="FAUCET_ADDR=$faucetAddr" --prefix="FAUCET_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
    [ "$VALOPER_ADDR" != "$valoperAddr" ]     && CDHelper text lineswap --insert="VALOPER_ADDR=$valoperAddr" --prefix="VALOPER_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
    [ "$CONSPUB_ADDR" != "$consPubAddr" ]     && CDHelper text lineswap --insert="CONSPUB_ADDR=$consPubAddr" --prefix="CONSPUB_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True    
fi

# block time should vary from minimum of 5.1s to 100ms depending on the validator count. The more validators, the shorter the block time
ACTIVE_VALIDATORS=$(jsonParse "status.active_validators" $VALOPERS_FILE || echo "0")
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
    CFG_timeout_commit=$TIMEOUT_COMMIT
    globSet CFG_timeout_commit "$CFG_timeout_commit"
fi

if [ ! -s "$LOCAL_PEERS_PATH" ] ; then 
    echoInfo "INFO: List of external peers was found, adding to peers config"
    set +x
    while read peer ; do
        echoInfo "INFO: Adding extra peer '$peer' from the list"
        [ ! -z "$CFG_persistent_peers" ] && CFG_persistent_peers="${CFG_persistent_peers},"
        CFG_persistent_peers="${CFG_persistent_peers}${peer}"
    done < $LOCAL_PEERS_PATH
    set -x
else echoWarn "WARNING: List of local peers is empty ($LOCAL_PEERS_PATH)" ; fi

if [ -f "$LOCAL_SEEDS_PATH" ] ; then 
    echoInfo "INFO: List of external seeds was found, shuffling and adding to seeds config"
    shuf $LOCAL_SEEDS_PATH > "${LOCAL_SEEDS_PATH}.tmp"
    set +x
    while read seed ; do
        echoInfo "INFO: Adding extra seed '$seed' from the list"
        [ ! -z "$CFG_seeds" ] && CFG_seeds="${CFG_seeds},"
        CFG_seeds="${CFG_seeds}${seed}"
    done < "${LOCAL_SEEDS_PATH}.tmp"
    set -x
else echoWarn "WARNING: List of local peers is empty ($LOCAL_SEEDS_PATH)" ; fi

rm -fv $LOCAL_RPC_PATH
touch $LOCAL_RPC_PATH

if [ ! -z "$CFG_seeds" ] ; then
    echoInfo "INFO: Seed configuration is available, testing..."
    TMP_CFG_seeds=""
    i=0
    for seed in $(echo $CFG_seeds | sed "s/,/ /g") ; do
        seed=$(echo "$seed" | sed 's/tcp\?:\/\///')
        set +x
        [ -z "$seed" ] && echoWarn "WARNING: seed not found" && continue
        addrArr1=( $(echo $seed | tr "@" "\n") )
        addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
        nodeId=${addrArr1[0],,}
        addr=${addrArr2[0],,}
        port=${addrArr2[1],,}
        ip=$(resolveDNS $addr)

        (! $(isDnsOrIp "$addr")) && echoWarn "WARNINIG: Seed '$seed' DNS could NOT be resolved!" && continue
        (! $(isNodeId "$nodeId")) && echoWarn "WARNINIG: Seed '$seed' can NOT be added, invalid node-id!" && continue
        (! $(isPort "$port")) && echoWarn "WARNINIG: Seed '$seed' PORT is invalid!" && continue
        ($(isSubStr "$TMP_CFG_seeds" "$nodeId")) && echoWarn "WARNINIG: Seed '$seed' can NOT be added, node-id already present in the config." && continue
        (! $(isIp "$ip")) && echoWarn "WARNINIG: Seed '$seed' IP could NOT be resolved" && continue
        (! $(isPortOpen "$addr" "$port" "0.25")) && echoWarn "WARNINIG: Seed '$seed' is NOT reachable!" && continue

        currentNodeId=$(tmconnect id --address="$addr:$port" --node_key="$SEKAID_HOME/config/node_key.json" --timeout=3 || echo "")
        [ "$currentNodeId" != "$nodeId" ] && echoWarn "WARNINIG: Handshake fialure, expected node id to be '$isNodeId' but got '$currentNodeId'" && continue

        rpc_port=$((port + 1))
        rpc="${addr}:${rpc_port}"
        if ($(isPublicIp "$addr")) && ($(isPortOpen "$addr" "$rpc_port" "0.25")) ; then
            echoInfo "INFO: Detected open RPC port ($rpc)"
            
            if grep -q "$rpc" "$LOCAL_RPC_PATH"; then
                echoWarn "WARNING: Address is already present in the RPC list ($rpc)"
            else
                echoInfo "INFO: Adding address to the RPC list ($rpc)"
                echo "$rpc" >> $LOCAL_RPC_PATH
            fi
        else
            echoInfo "INFP: RPC address in NOT exposed ($rpc)"
        fi

        seed="tcp://${nodeId}@${ip}:${port}"

        i=$(($i + 1))
        if [[ $i -ge $CFG_max_num_outbound_peers ]] ; then
            echoWarn "INFO: Outbound seeds limit (${i}/${CFG_max_num_outbound_peers}) reached"
        else
            echoInfo "INFO: Adding extra seed '$seed' to new config"
            [ ! -z "$TMP_CFG_seeds" ] && TMP_CFG_seeds="${TMP_CFG_seeds},"
            TMP_CFG_seeds="${TMP_CFG_seeds}${seed}"
        fi
        set -x
    done
    CFG_seeds=$TMP_CFG_seeds
else echoWarn "WARNING: Seeds configuration is NOT available!" ; fi

if [ ! -z "$CFG_persistent_peers" ] ; then
    echoInfo "INFO: Peers configuration is available, testing..."
    
    TMP_CFG_persistent_peers=""
    for peer in $(echo $CFG_persistent_peers | sed "s/,/ /g") ; do
        peer=$(echo "$peer" | sed 's/tcp\?:\/\///')
        set +x
        [ -z "$peer" ] && echoWarn "WARNING: peer not found" && continue
        addrArr1=( $(echo $peer | tr "@" "\n") )
        addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
        nodeId=${addrArr1[0],,}
        addr=${addrArr2[0],,}
        port=${addrArr2[1],,}
        ip=$(resolveDNS $addr)
        
        (! $(isDnsOrIp "$addr")) && echoWarn "WARNINIG: Peer '$peer' DNS could NOT be resolved!" && continue
        (! $(isNodeId "$nodeId")) && echoWarn "WARNINIG: Peer '$peer' can NOT be added, invalid node-id!" && continue
        (! $(isPort "$port")) && echoWarn "WARNINIG: Peer '$peer' PORT is invalid!" && continue
        ($(isSubStr "$TMP_CFG_persistent_peers" "$nodeId")) && echoWarn "WARNINIG: Peer '$peer' can NOT be added, node-id already present in the peers config." && continue
        ($(isSubStr "$CFG_seeds" "$nodeId")) && echoWarn "WARNINIG: Peer '$peer' can NOT be added, node-id already present in the seeds config." && continue
        (! $(isIp "$ip")) && echoWarn "WARNINIG: Peer '$peer' IP could NOT be resolved" && continue

        rpc_port=$((port + 1))
        rpc="${addr}:${rpc_port}"
        if ($(isPublicIp "$addr")) && ($(isPortOpen "$addr" "$rpc_port" "0.25")) ; then
            echoInfo "INFO: Detected open RPC port ($rpc)"
            
            if grep -q "$rpc" "$LOCAL_RPC_PATH"; then
                echoWarn "WARNING: Address is already present in the RPC list ($rpc)"
            else
                echoInfo "INFO: Adding address to the RPC list ($rpc)"
                echo "$rpc" >> $LOCAL_RPC_PATH
            fi
        else
            echoInfo "INFP: RPC address in NOT exposed ($rpc)"
        fi

        peer="tcp://${nodeId}@${addr}:${port}"
        echoInfo "INFO: Adding extra peer '$peer' to new config"

        [ ! -z "$TMP_CFG_persistent_peers" ] && TMP_CFG_persistent_peers="${TMP_CFG_persistent_peers},"
        TMP_CFG_persistent_peers="${TMP_CFG_persistent_peers}${peer}"

        if (! $(isSubStr "$CFG_unconditional_peer_ids" "$nodeId")) ; then
            [ ! -z "$CFG_unconditional_peer_ids" ] && CFG_unconditional_peer_ids="${CFG_unconditional_peer_ids},"
            CFG_unconditional_peer_ids="${CFG_unconditional_peer_ids}${nodeId}"
        fi
        set -x
    done
    CFG_persistent_peers=$TMP_CFG_persistent_peers
else
    echoWarn "WARNING: Peers configuration is NOT available!"
fi

echoInfo "INFO: Final Peers List:"
echoInfo "$CFG_persistent_peers"
rpc_cntr=0

if (! $(isFileEmpty $LOCAL_RPC_PATH)) ; then
    echoInfo "INFO: Starting fast sync configuaration, RPC nodes detected!"
    TRUST_HASH=""
    RPC_SERVERS=""
    while read rpc ; do
        set +x
        BLOCK_INFO=$(timeout 3 curl --fail $rpc/block?height=$LATEST_BLOCK_HEIGHT 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")
        [ -z "$BLOCK_INFO" ] && echoWarn "WARNING: Failed to fetch block info from '$rpc'" && continue
        HEIGHT=$(echo "$BLOCK_INFO" | jsonParse "block.header.height" 2>/dev/null || echo -n "") && (! $(isNaturalNumber $HEIGHT)) && HEIGHT=0
        [ "$HEIGHT" != "$LATEST_BLOCK_HEIGHT" ] && echoWarn "INFO: RPC height is $HEIGHT but expected $LATEST_BLOCK_HEIGHT" && continue
        NEW_TRUST_HASH=$(echo "$BLOCK_INFO" | jsonParse "block_id.hash" 2>/dev/null || echo -n "")
        [ -z "$TRUST_HASH" ] && TRUST_HASH=$NEW_TRUST_HASH
        [ "$NEW_TRUST_HASH" != "$TRUST_HASH" ] && echoWarn "WARNING: Got block hash '$NEW_TRUST_HASH' but expected '$TRUST_HASH'" && continue
        echoInfo "INFO: Adding RPC '$rpc' to the fast sync list"
        [ -z "$RPC_SERVERS" ] && \
            RPC_SERVERS=$rpc || \
            RPC_SERVERS="${RPC_SERVERS},$rpc"
        
        rpc_cntr=$((rpc_cntr + 1))
        set -x
    done < "$LOCAL_RPC_PATH"

    if [[ $rpc_cntr -ge 2 ]] ; then
        CFG_trust_hash=$TRUST_HASH
        CFG_rpc_servers=$RPC_SERVERS
        CFG_trust_height="$LATEST_BLOCK_HEIGHT"
    else
        echoWarn "WARNING: Insufficicent RPC nodes count ($rpc_cntr)"
    fi
else
    echoWarn "WARNING: Fast sync is NOT possible, RPC nodes NOT found"
fi

echoInfo "INFO: Final Peers List:"
echoInfo "$CFG_rpc_servers"

echoInfo "INFO: Ensuring, that following config vars are set via global parameters:"
echoInfo "----------------------------------"
echoInfo "|                      CFG_moniker: $CFG_moniker"
echoInfo "|                          CFG_pex: $CFG_pex"
echoInfo "|           CFG_allow_duplicate_ip: $CFG_allow_duplicate_ip"
echoInfo "|             CFG_addr_book_strict: $CFG_addr_book_strict"
echoInfo "|                     CFG_fastsync: $CFG_fastsync"
echoInfo "|             CFG_fastsync_version: $CFG_fastsync_version"
echoInfo "|            CFG_handshake_timeout: $CFG_handshake_timeout"
echoInfo "|                 CFG_dial_timeout: $CFG_dial_timeout"
echoInfo "|                 CFG_trust_period: $CFG_trust_period"
echoInfo "|                CFG_max_txs_bytes: $CFG_max_txs_bytes"
echoInfo "|                 CFG_max_tx_bytes: $CFG_max_tx_bytes"
echoInfo "|                    CFG_send_rate: $CFG_send_rate"
echoInfo "|                    CFG_recv_rate: $CFG_recv_rate"
echoInfo "|  CFG_max_packet_msg_payload_size: $CFG_max_packet_msg_payload_size"
echoInfo "|         CFG_cors_allowed_origins: $CFG_cors_allowed_origins"
echoInfo "|            CFG_snapshot_interval: $CFG_snapshot_interval"
echoInfo "|             CFG_statesync_enable: $CFG_statesync_enable"
echoInfo "|           CFG_statesync_temp_dir: $CFG_statesync_temp_dir"
echoInfo "| CFG_create_empty_blocks_interval: $CFG_create_empty_blocks_interval"
echoInfo "|               CFG_timeout_commit: $CFG_timeout_commit"
echoInfo "|       CFG_max_num_outbound_peers: $CFG_max_num_outbound_peers"
echoInfo "|        CFG_max_num_inbound_peers: $CFG_max_num_inbound_peers"
echoInfo "|                   CFG_prometheus: $CFG_prometheus"
echoInfo "|                    CFG_seed_mode: $CFG_seed_mode"
echoInfo "|          CFG_skip_timeout_commit: $CFG_skip_timeout_commit"
echoInfo "|             CFG_private_peer_ids: $CFG_private_peer_ids"
echoInfo "|       CFG_unconditional_peer_ids: $CFG_unconditional_peer_ids"
echoInfo "|             CFG_persistent_peers: $CFG_persistent_peers"
echoInfo "|                        CFG_seeds: $CFG_seeds"
echoInfo "|                   CFG_grpc_laddr: $CFG_grpc_laddr"
echoInfo "|                    CFG_rpc_laddr: $CFG_rpc_laddr"
echoInfo "|                    CFG_p2p_laddr: $CFG_p2p_laddr"
echoInfo "----------------------------------"
echoInfo "|                       MIN_HEIGHT: $MIN_HEIGHT"
echoInfo "|                 EXTERNAL_ADDRESS: $EXTERNAL_ADDRESS"
echoInfo "----------------------------------"

echoInfo "INFO: Starting sekai & tendermint configs setup..."
[ ! -z "$CFG_moniker" ] && CDHelper text lineswap --insert="moniker = \"$CFG_moniker\"" --prefix="moniker =" --path=$CFG
[ ! -z "$CFG_pex" ] && CDHelper text lineswap --insert="pex = $CFG_pex" --prefix="pex =" --path=$CFG
[ ! -z "$CFG_persistent_peers" ] && CDHelper text lineswap --insert="persistent_peers = \"$CFG_persistent_peers\"" --prefix="persistent_peers =" --path=$CFG
[ ! -z "$CFG_private_peer_ids" ] && CDHelper text lineswap --insert="private_peer_ids = \"$CFG_private_peer_ids\"" --prefix="private_peer_ids =" --path=$CFG
[ ! -z "$CFG_seeds" ] && CDHelper text lineswap --insert="seeds = \"$CFG_seeds\"" --prefix="seeds =" --path=$CFG
[ ! -z "$CFG_unconditional_peer_ids" ] && CDHelper text lineswap --insert="unconditional_peer_ids = \"$CFG_unconditional_peer_ids\"" --prefix="unconditional_peer_ids =" --path=$CFG
# addr_book_strict -> set true for strict address routability rules ; set false for private or local networks
[ ! -z "$CFG_addr_book_strict" ] && CDHelper text lineswap --insert="addr_book_strict = $CFG_addr_book_strict" --prefix="addr_book_strict =" --path=$CFG
# P2P Address to advertise to peers for them to dial, If empty, will use the same port as the laddr, and will introspect on the listener or use UPnP to figure out the address.
[ ! -z "$EXTERNAL_ADDRESS" ] && CDHelper text lineswap --insert="external_address = \"$EXTERNAL_ADDRESS\"" --prefix="external_address =" --path=$CFG
[ ! -z "$CFG_rpc_laddr" ] && CDHelper text lineswap --insert="laddr = \"$CFG_rpc_laddr\"" --prefix="laddr = \"tcp://127.0.0.1:26657\"" --path=$CFG
[ ! -z "$CFG_p2p_laddr" ] && CDHelper text lineswap --insert="laddr = \"$CFG_p2p_laddr\"" --prefix="laddr = \"tcp://0.0.0.0:26656\"" --path=$CFG
#[ ! -z "$CFG_grpc_laddr" ] && CDHelper text lineswap --insert="grpc_laddr = \"$CFG_grpc_laddr\"" --prefix="grpc_laddr =" --path=$CFG
[ ! -z "$CFG_double_sign_check_height" ] && CDHelper text lineswap --insert="double_sign_check_height = $CFG_double_sign_check_height" --prefix="double_sign_check_height =" --path=$CFG
[ ! -z "$CFG_seed_mode" ] && CDHelper text lineswap --insert="seed_mode = $CFG_seed_mode" --prefix="seed_mode =" --path=$CFG
[ ! -z "$CFG_skip_timeout_commit" ] && CDHelper text lineswap --insert="skip_timeout_commit = $CFG_skip_timeout_commit" --prefix="skip_timeout_commit =" --path=$CFG
[ ! -z "$CFG_cors_allowed_origins" ] && CDHelper text lineswap --insert="cors_allowed_origins = [ \"$CFG_cors_allowed_origins\" ]" --prefix="cors_allowed_origins =" --path=$CFG

# Maximum number of inbound P2P peers that can dial your node and connect to it
[ ! -z "$CFG_max_num_inbound_peers" ] && CDHelper text lineswap --insert="max_num_inbound_peers = $CFG_max_num_inbound_peers" --prefix="max_num_inbound_peers =" --path=$CFG
# Maximum number of outbound P2P peers to connect to, excluding persistent peers
[ ! -z "$CFG_max_num_outbound_peers " ] && CDHelper text lineswap --insert="max_num_outbound_peers = $CFG_max_num_outbound_peers" --prefix="max_num_outbound_peers =" --path=$CFG
# Toggle to disable guard against peers connecting from the same ip
[ ! -z "$CFG_allow_duplicate_ip" ] && CDHelper text lineswap --insert="allow_duplicate_ip = $CFG_allow_duplicate_ip" --prefix="allow_duplicate_ip =" --path=$CFG
# How long we wait after commiting a block before starting on the new height
[ ! -z "$CFG_timeout_commit" ] && CDHelper text lineswap --insert="timeout_commit = \"$CFG_timeout_commit\"" --prefix="timeout_commit =" --path=$CFG
# Peer connection configuration.
[ ! -z "$CFG_handshake_timeout" ] && CDHelper text lineswap --insert="handshake_timeout = \"$CFG_handshake_timeout\"" --prefix="handshake_timeout =" --path=$CFG
[ ! -z "$CFG_dial_timeout" ] && CDHelper text lineswap --insert="dial_timeout = \"$CFG_dial_timeout\"" --prefix="dial_timeout =" --path=$CFG
[ ! -z "$CFG_create_empty_blocks_interval" ] && CDHelper text lineswap --insert="create_empty_blocks_interval = \"$CFG_create_empty_blocks_interval\"" --prefix="create_empty_blocks_interval =" --path=$CFG

# Limit the total size of all txs in the mempool.
# This only accounts for raw transactions (e.g. given 1MB transactions and
# max_txs_bytes=5MB, mempool will only accept 5 transactions).
# default: 1073741824, kira deg. 131072000 (1000 tx)
[ ! -z "$CFG_max_txs_bytes" ] && CDHelper text lineswap --insert="max_txs_bytes = $CFG_max_txs_bytes" --prefix="max_txs_bytes =" --path=$CFG
# Maximum size of a single transaction.
# NOTE: the max size of a tx transmitted over the network is {max_tx_bytes}.
# default: 1048576 (1MB), kira def. 131072 (128KB)
[ ! -z "$CFG_max_tx_bytes" ] && CDHelper text lineswap --insert="max_tx_bytes = $CFG_max_tx_bytes" --prefix="max_tx_bytes =" --path=$CFG

# Rate at which packets can be sent, in bytes/second
# default 5120000, kira def. 65536000
[ ! -z "$CFG_send_rate" ] && CDHelper text lineswap --insert="send_rate = $CFG_send_rate" --prefix="send_rate =" --path=$CFG
# Rate at which packets can be received, in bytes/second
# default 5120000, kira def. 65536000
[ ! -z "$CFG_recv_rate" ] && CDHelper text lineswap --insert="recv_rate = $CFG_recv_rate" --prefix="recv_rate =" --path=$CFG
# Maximum size of a message packet payload, in bytes
# default 1024, kira def. 131072
[ ! -z "$CFG_max_packet_msg_payload_size" ] && CDHelper text lineswap --insert="max_packet_msg_payload_size = $CFG_max_packet_msg_payload_size" --prefix="max_packet_msg_payload_size =" --path=$CFG

# When true, Prometheus metrics are served under /metrics on
# PrometheusListenAddr.
# Check out the documentation for the list of available metrics.
[ ! -z "$CFG_prometheus" ] && CDHelper text lineswap --insert="prometheus = $CFG_prometheus" --prefix="prometheus =" --path=$CFG
# Address to listen for Prometheus collector(s) connections
[ ! -z "$CFG_prometheus_listen_addr" ] && CDHelper text lineswap --insert="prometheus_listen_addr = \"$CFG_prometheus_listen_addr\"" --prefix="prometheus_listen_addr =" --path=$CFG

#######################################################
###         State Sync Configuration Options        ###
#######################################################
# [statesync]

if ( $(isNullOrEmpty $CFG_rpc_servers) ) ; then
    echoWarn "WARNING: NO live RPC servers were found, disabling statesync"
    CFG_statesync_enable="false"
    CFG_trust_height=0
    CFG_trust_hash=""
fi

mkdir -pv $CFG_statesync_temp_dir || echoErr "ERROR: Failed to create statesync temp directory"

# State sync rapidly bootstraps a new node by discovering, fetching, and restoring a state machine
# snapshot from peers instead of fetching and replaying historical blocks. Requires some peers in
# the network to take and serve state machine snapshots. State sync is not attempted if the node
# has any local state (LastBlockHeight > 0). The node will have a truncated block history,
# starting from the height of the snapshot.
[ ! -z "$CFG_statesync_enable" ] && CDHelper text lineswap --insert="enable = $CFG_statesync_enable" --prefix="enable =" --after-regex="^\[statesync\]" --before-regex="^\[fastsync\]" --path=$CFG
# Temporary directory for state sync snapshot chunks, defaults to the OS tempdir (typically /tmp).
# Will create a new, randomly named directory within, and remove it when done.
[ ! -z "$CFG_statesync_temp_dir" ] && CDHelper text lineswap --insert="temp_dir = \"$CFG_statesync_temp_dir\"" --prefix="temp_dir =" --after-regex="^\[statesync\]" --before-regex="^\[fastsync\]" --path=$CFG

[ ! -z "$CFG_rpc_servers" ] && CDHelper text lineswap --insert="rpc_servers = \"$CFG_rpc_servers\"" --prefix="rpc_servers =" --path=$CFG
[ ! -z "$CFG_trust_height" ] && CDHelper text lineswap --insert="trust_height = $CFG_trust_height" --prefix="trust_height =" --path=$CFG
[ ! -z "$CFG_trust_hash" ] && CDHelper text lineswap --insert="trust_hash = \"$CFG_trust_hash\"" --prefix="trust_hash =" --path=$CFG

#######################################################
###       Fast Sync Configuration Connections       ###
#######################################################
# [fastsync]

[ ! -z "$CFG_fastsync" ] && CDHelper text lineswap --insert="fast_sync = $CFG_fastsync" --prefix="fast_sync =" --path=$CFG

# Fast Sync version to use:
#   1) "v0" (default) - the legacy fast sync implementation
#   2) "v1" - refactor of v0 version for better testability
#   2) "v2" - complete redesign of v0, optimized for testability & readability
[ ! -z "$CFG_fastsync_version" ] && CDHelper text lineswap --insert="version = \"$CFG_fastsync_version\"" --prefix="version =" --after-regex="^\[fastsync\]" --before-regex="^\[consensus\]" --path=$CFG

##########################
# app.toml configuration
##########################

# snapshot-interval specifies the block interval at which local state sync snapshots are
# taken (0 to disable). Must be a multiple of pruning-keep-every.
[ ! -z "$CFG_snapshot_interval" ] && CDHelper text lineswap --insert="snapshot-interval = $CFG_snapshot_interval" --prefix="snapshot-interval =" --after-regex="^\[state\-sync\]" --path=$APP

GRPC_ADDRESS=$(echo "$CFG_grpc_laddr" | sed 's/tcp\?:\/\///')
CDHelper text lineswap --insert="GRPC_ADDRESS=\"$GRPC_ADDRESS\"" --prefix="GRPC_ADDRESS=" --path=$ETC_PROFILE --append-if-found-not=True

if [ "${NODE_TYPE,,}" == "validator" ] && [[ $LATEST_BLOCK_HEIGHT -gt $STATE_HEIGHT ]] && [ "$NEW_NETWORK" != "true" ] ; then
    echoWarn "WARNING: Updating minimum state height, expected no less than $LATEST_BLOCK_HEIGHT but got $STATE_HEIGHT"
    cat >$LOCAL_STATE <<EOL
{
  "height": "$LATEST_BLOCK_HEIGHT",
  "round": 0,
  "step": 0
}
EOL
fi

STATE_HEIGHT=$(jsonQuickParse "height" $LOCAL_STATE || echo "")
echoInfo "INFO: Minimum state height is set to $STATE_HEIGHT"
echoInfo "INFO: Latest known height is set to $LATEST_BLOCK_HEIGHT"

echoInfo "INFO: Finished node configuration."
rm -fv $CFG_CHECK


