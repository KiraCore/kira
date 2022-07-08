#!/usr/bin/env bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
# quick edit: FILE="${COMMON_DIR}/configure.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
exec 2>&1
set -x

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

LATEST_BLOCK_HEIGHT=$(globGet latest_block_height "$GLOBAL_COMMON_RO") && (! $(isNaturalNumber $LATEST_BLOCK_HEIGHT)) && LATEST_BLOCK_HEIGHT=0
MIN_HEIGHT=$(globGet MIN_HEIGHT "$GLOBAL_COMMON_RO") && (! $(isNaturalNumber $MIN_HEIGHT)) && MIN_HEIGHT=0
STATE_HEIGHT=$(jsonQuickParse "height" $LOCAL_STATE || echo "") && (! $(isNaturalNumber $STATE_HEIGHT)) && STATE_HEIGHT=0

[[ $MIN_HEIGHT -lt $LATEST_BLOCK_HEIGHT ]] && MIN_HEIGHT=$LATEST_BLOCK_HEIGHT

CFG_timeout_commit=$(globGet CFG_timeout_commit)
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
FORCE_EXTERNAL_DNS=$(globGet FORCE_EXTERNAL_DNS)

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

echoInfo "INFO: Starting genesis configuration..."
if [[ "${NODE_TYPE,,}" =~ ^(sentry|seed)$ ]] ; then
    rm -fv $LOCAL_GENESIS
    cp -afv $COMMON_GENESIS $LOCAL_GENESIS # recover genesis from common folder
elif [ "${NODE_TYPE,,}" == "validator" ] ; then
    validatorAddr=$(showAddress validator)                      && setGlobEnv VALIDATOR_ADDR "$validatorAddr"
    testAddr=$(showAddress test)                                && setGlobEnv TEST_ADDR "$testAddr"
    signerAddr=$(showAddress signer)                            && setGlobEnv SIGNER_ADDR "$signerAddr"
    valoperAddr=$(sekaid val-address $validatorAddr || echo "") && setGlobEnv VALOPER_ADDR "$valoperAddr"
    consPubAddr=$(sekaid tendermint show-validator || echo "")  && setGlobEnv CONSPUB_ADDR "$consPubAddr"   
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

set +x
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
set -x

#######################################################################
###                   Main Base Config Options                      ###
#######################################################################

# A custom human readable name for this node
[ ! -z "$CFG_moniker" ]     && setTomlVar "" moniker "$CFG_moniker" $CFG
# If this node is many blocks behind the tip of the chain, FastSync
# allows them to catchup quickly by downloading blocks in parallel
# and verifying their commits. Default (true)
[ ! -z "$CFG_fastsync" ]    && setTomlVar "" fast_sync "$CFG_fastsync" $CFG


#######################################################
###           P2P Configuration Options             ###
#######################################################
# [p2p]

# Address to listen for incoming connections
[ ! -z "$CFG_p2p_laddr" ]                   && setTomlVar "[p2p]" laddr "$CFG_p2p_laddr" $CFG
# Address to advertise to peers for them to dial
# If empty, will use the same port as the laddr,
# and will introspect on the listener or use UPnP
# to figure out the address. ip and port are required
# example: 159.89.10.97:26656
[ ! -z "$EXTERNAL_ADDRESS" ]                && setTomlVar "[p2p]" external_address "$EXTERNAL_ADDRESS" $CFG
# Comma separated list of seed nodes to connect to
[ ! -z "$CFG_seeds" ]                       && setTomlVar "[p2p]" seeds "$CFG_seeds" $CFG
# Comma separated list of nodes to keep persistent connections to
[ ! -z "$CFG_persistent_peers" ]            && setTomlVar "[p2p]" persistent_peers "$CFG_persistent_peers" $CFG

# Set true for strict address routability rules
# Set false for private or local networks
[ ! -z "$CFG_addr_book_strict" ]            && setTomlVar "[p2p]" addr_book_strict "$CFG_addr_book_strict" $CFG
# Maximum number of inbound P2P peers that can dial your node and connect to it, default (40)
[ ! -z "$CFG_max_num_inbound_peers" ]       && setTomlVar "[p2p]" max_num_inbound_peers "$CFG_max_num_inbound_peers" $CFG
# Maximum number of outbound P2P peers to connect to, excluding persistent peers, default (10)
[ ! -z "$CFG_max_num_outbound_peers" ]      && setTomlVar "[p2p]" max_num_outbound_peers "$CFG_max_num_outbound_peers" $CFG

# Maximum size of a message packet payload, in bytes, default 1024, kira def. 131072
[ ! -z "$CFG_max_packet_msg_payload_size" ] && setTomlVar "[p2p]" max_packet_msg_payload_size "$CFG_max_packet_msg_payload_size" $CFG
# Rate at which packets can be sent, in bytes/second, default 5120000, kira def. 65536000
[ ! -z "$CFG_send_rate" ]                   && setTomlVar "[p2p]" send_rate "$CFG_send_rate" $CFG
# Rate at which packets can be received, in bytes/second, default 5120000, kira def. 65536000
[ ! -z "$CFG_recv_rate" ]                   && setTomlVar "[p2p]" recv_rate "$CFG_recv_rate" $CFG
# Set true to enable the peer-exchange reactor
[ ! -z "$CFG_pex" ]                         && setTomlVar "[p2p]" pex "$CFG_pex" $CFG
# Seed mode, in which node constantly crawls the network and looks for
# peers. If another node asks it for addresses, it responds and disconnects.
# Does not work if the peer-exchange reactor is disabled. Default (false)
[ ! -z "$CFG_seed_mode" ]                   && setTomlVar "[p2p]" seed_mode "$CFG_seed_mode" $CFG
# List of node IDs, to which a connection will be (re)established ignoring any existing limits
[ ! -z "$CFG_unconditional_peer_ids" ]      && setTomlVar "[p2p]" unconditional_peer_ids "$CFG_unconditional_peer_ids" $CFG
# Comma separated list of peer IDs to keep private (will not be gossiped to other peers)
[ ! -z "$CFG_private_peer_ids" ]            && setTomlVar "[p2p]" private_peer_ids "$CFG_private_peer_ids" $CFG
# Toggle to disable guard against peers connecting from the same ip, default (false)
[ ! -z "$CFG_allow_duplicate_ip" ]          && setTomlVar "[p2p]" allow_duplicate_ip "$CFG_allow_duplicate_ip" $CFG
# Peer connection configuration.
[ ! -z "$CFG_handshake_timeout" ]           && setTomlVar "[p2p]" handshake_timeout "$CFG_handshake_timeout" $CFG
[ ! -z "$CFG_dial_timeout" ]                && setTomlVar "[p2p]" dial_timeout "$CFG_dial_timeout" $CFG

#######################################################
###       RPC Server Configuration Options          ###
#######################################################
# [rpc]

# TCP or UNIX socket address for the RPC server to listen on, default ("tcp://127.0.0.1:26657")
[ ! -z "$CFG_rpc_laddr" ]               && setTomlVar "[rpc]" laddr "$CFG_rpc_laddr" $CFG
# A list of origins a cross-domain request can be executed from
# Default value '[]' disables cors support
# Use '["*"]' to allow any origin. Default ([])
[ ! -z "$CFG_cors_allowed_origins" ]    && setTomlVar "[rpc]" laddr "$CFG_cors_allowed_origins" $CFG

# TCP or UNIX socket address for the gRPC server to listen on
# NOTE: This server only supports /broadcast_tx_commit, default ("")
[ ! -z "$CFG_grpc_laddr" ]              && setTomlVar "[rpc]" grpc_laddr "$CFG_grpc_laddr" $CFG

#######################################################
###         Consensus Configuration Options         ###
#######################################################
# [consensus]

# How long we wait after committing a block, before starting on the new
# height (this gives us a chance to receive some more precommits, even
# though we already have +2/3).
[ ! -z "$CFG_timeout_commit" ]                  && setTomlVar "[consensus]" timeout_commit "$CFG_timeout_commit" $CFG

# How many blocks to look back to check existence of the node's consensus votes before joining consensus
# When non-zero, the node will panic upon restart
# if the same consensus key was used to sign {double_sign_check_height} last blocks.
# So, validators should stop the state machine, wait for some blocks, and then restart the state machine to avoid panic. Default (0)
[ ! -z "$CFG_double_sign_check_height" ]        && setTomlVar "[consensus]" grpc_laddr "$CFG_double_sign_check_height" $CFG
# Make progress as soon as we have all the precommits (as if TimeoutCommit = 0), default (false)
[ ! -z "$CFG_skip_timeout_commit" ]             && setTomlVar "[consensus]" skip_timeout_commit "$CFG_skip_timeout_commit" $CFG
# EmptyBlocks mode and possible interval between empty blocks
[ ! -z "$CFG_create_empty_blocks_interval" ]    && setTomlVar "[consensus]" create_empty_blocks_interval "$CFG_create_empty_blocks_interval" $CFG

#######################################################
###          Mempool Configuration Option          ###
#######################################################
# [mempool]

# Limit the total size of all txs in the mempool.
# This only accounts for raw transactions (e.g. given 1MB transactions and
# max_txs_bytes=5MB, mempool will only accept 5 transactions). Default (1073741824)
[ ! -z "$CFG_max_txs_bytes" ]        && setTomlVar "[mempool]" max_txs_bytes "$CFG_max_txs_bytes" $CFG

# Maximum size of a single transaction.
# NOTE: the max size of a tx transmitted over the network is {max_tx_bytes}. Default (1048576)
[ ! -z "$CFG_max_tx_bytes" ]        && setTomlVar "[mempool]" max_tx_bytes "$CFG_max_tx_bytes" $CFG

#######################################################
###       Instrumentation Configuration Options     ###
#######################################################
# [instrumentation]

# When true, Prometheus metrics are served under /metrics on
# PrometheusListenAddr.
# Check out the documentation for the list of available metrics. Default (false)
[ ! -z "$CFG_prometheus" ]              && setTomlVar "[instrumentation]" prometheus "$CFG_prometheus" $CFG
# Address to listen for Prometheus collector(s) connections. Default (":26660")
[ ! -z "$CFG_prometheus_listen_addr" ]  && setTomlVar "[instrumentation]" prometheus_listen_addr "$CFG_prometheus_listen_addr" $CFG

#######################################################
###         State Sync Configuration Options        ###
#######################################################
# [statesync]

if ( $(isNullOrEmpty $CFG_rpc_servers) ) ; then
    echoWarn "WARNING: NO live RPC servers were found, disabling statesync"
    CFG_statesync_enable="false"
    CFG_trust_height=0
    CFG_trust_hash="\"\""
fi

mkdir -pv $CFG_statesync_temp_dir || echoErr "ERROR: Failed to create statesync temp directory"

# State sync rapidly bootstraps a new node by discovering, fetching, and restoring a state machine
# snapshot from peers instead of fetching and replaying historical blocks. Requires some peers in
# the network to take and serve state machine snapshots. State sync is not attempted if the node
# has any local state (LastBlockHeight > 0). The node will have a truncated block history,
# starting from the height of the snapshot. Default (false)
[ ! -z "$CFG_statesync_enable" ]    && setTomlVar "[statesync]" enable "$CFG_statesync_enable" $CFG

# Temporary directory for state sync snapshot chunks, defaults to the OS tempdir (typically /tmp).
# Will create a new, randomly named directory within, and remove it when done. Default ("")
[ ! -z "$CFG_statesync_temp_dir" ]  && setTomlVar "[statesync]" temp_dir "$CFG_statesync_temp_dir" $CFG

# RPC servers (comma-separated) for light client verification of the synced state machine and
# retrieval of state data for node bootstrapping. Also needs a trusted height and corresponding
# header hash obtained from a trusted source, and a period during which validators can be trusted.
#
# For Cosmos SDK-based chains, trust_period should usually be about 2/3 of the unbonding time (~2
# weeks) during which they can be financially punished (slashed) for misbehavior. Default ("")
[ ! -z "$CFG_rpc_servers" ]         && setTomlVar "[statesync]" rpc_servers "$CFG_rpc_servers" $CFG
# Default (0)
[ ! -z "$CFG_trust_height" ]        && setTomlVar "[statesync]" trust_height "$CFG_trust_height" $CFG
# Default ("")
[ ! -z "$CFG_trust_hash" ]          && setTomlVar "[statesync]" trust_hash "$CFG_trust_hash" $CFG


#######################################################
###       Fast Sync Configuration Connections       ###
#######################################################
# [fastsync]

# Fast Sync version to use:
#   1) "v0" (default) - the legacy fast sync implementation
#   2) "v1" - refactor of v0 version for better testability
#   2) "v2" - complete redesign of v0, optimized for testability & readability. Default (0)
[ ! -z "$CFG_fastsync_version" ]    && setTomlVar "[fastsync]" version "$CFG_fastsync_version" $CFG


###############################################################################
###                app.toml - Base Configuration                            ###
###############################################################################


###############################################################################
###                        State Sync Configuration                         ###
###############################################################################
# State sync snapshots allow other nodes to rapidly join the network without replaying historical
# blocks, instead downloading and applying a snapshot of the application state at a given height.
# [state-sync]

# snapshot-interval specifies the block interval at which local state sync snapshots are
# taken (0 to disable). Must be a multiple of pruning-keep-every. Default (0)
[ ! -z "$CFG_snapshot_interval" ]    && setTomlVar "[state-sync]" "snapshot-interval" "$CFG_snapshot_interval" $APP

##########################

GRPC_ADDRESS=$(echo "$CFG_grpc_laddr" | sed 's/tcp\?:\/\///')
setGlobEnv GRPC_ADDRESS "$GRPC_ADDRESS"

if [[ $MIN_HEIGHT -gt $STATE_HEIGHT ]] ; then
    echoWarn "WARNING: Updating minimum state height, expected no less than $MIN_HEIGHT but got $STATE_HEIGHT"
    cat >$LOCAL_STATE <<EOL
{
  "height": "$MIN_HEIGHT",
  "round": 0,
  "step": 0
}
EOL
fi

STATE_HEIGHT=$(jsonQuickParse "height" $LOCAL_STATE || echo "")
echoInfo "INFO: Minimum state height is set to $STATE_HEIGHT"
echoInfo "INFO: Latest known height is set to $LATEST_BLOCK_HEIGHT"

echoInfo "INFO: Finished node configuration."
globSet CFG_TASK "false"
