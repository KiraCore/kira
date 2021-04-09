#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
exec 2>&1
set -x

echoInfo "INFO: Starting node configuration..."

CFG="$SEKAID_HOME/config/config.toml"
COMMON_PEERS_PATH="$COMMON_DIR/peers"
COMMON_SEEDS_PATH="$COMMON_DIR/seeds"
LOCAL_PEERS_PATH="$SEKAID_HOME/config/peers"
LOCAL_SEEDS_PATH="$SEKAID_HOME/config/seeds"

LOCAL_GENESIS="$SEKAID_HOME/config/genesis.json"
LOCAL_STATE="$SEKAID_HOME/data/priv_validator_state.json"

[ -f "$COMMON_PEERS_PATH" ] && cp -a -v -f "$COMMON_PEERS_PATH" "$LOCAL_PEERS_PATH"
[ -f "$COMMON_SEEDS_PATH" ] && cp -a -v -f "$COMMON_SEEDS_PATH" "$LOCAL_SEEDS_PATH"

if [ -f "$LOCAL_PEERS_PATH" ] ; then 
    echoInfo "INFO: List of external peers was found"
    while read peer ; do
        peer=$(echo "$peer" | sed 's/tcp\?:\/\///')
        [ -z "$peer" ] && echo "WARNING: peer not found" && continue
        addrArr1=( $(echo $peer | tr "@" "\n") )
        addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
        nodeId=${addrArr1[0],,}
        addr=${addrArr2[0],,}
        port=${addrArr2[1],,}

        (! $(isNodeId "$nodeId")) && "WARNINIG: Peer '$peer' can NOT be added, invalid node-id!" && continue

        peer="tcp://$peer"
        echoInfo "INFO: Adding extra peer '$peer'"

        #[ ! -z "$CFG_private_peer_ids" ] && CFG_private_peer_ids="${CFG_private_peer_ids},"
        [ ! -z "$CFG_persistent_peers" ] && CFG_persistent_peers="${CFG_persistent_peers},"
        [ ! -z "$CFG_unconditional_peer_ids" ] && CFG_unconditional_peer_ids="${CFG_unconditional_peer_ids},"
        
        #CFG_private_peer_ids="${CFG_private_peer_ids}${nodeId}"
        CFG_persistent_peers="${CFG_persistent_peers}${peer}"
        CFG_unconditional_peer_ids="${CFG_unconditional_peer_ids}${nodeId}"
    done < $LOCAL_PEERS_PATH
fi

if [ -f "$LOCAL_SEEDS_PATH" ] ; then 
    echoInfo "INFO: List of external seeds was found"
    while read seed ; do
        seed=$(echo "$seed" | sed 's/tcp\?:\/\///')
        [ -z "$seed" ] && echo "WARNING: seed not found" && continue
        addrArr1=( $(echo $seed | tr "@" "\n") )
        addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
        nodeId=${addrArr1[0],,}
        addr=${addrArr2[0],,}
        port=${addrArr2[1],,}

        (! $(isNodeId "$nodeId")) && "WARNINIG: Seed '$seed' can NOT be added, invalid node-id!" && continue

        seed="tcp://$seed"
        echoInfo "INFO: Adding extra seed '$seed'"
        [ ! -z "$CFG_seeds" ] && CFG_seeds="${CFG_seeds},"
        CFG_seeds="${CFG_seeds}${seed}"
    done < $LOCAL_SEEDS_PATH
fi

[ ! -z "$CFG_moniker" ] && CDHelper text lineswap --insert="moniker = \"$CFG_moniker\"" --prefix="moniker =" --path=$CFG
[ ! -z "$CFG_pex" ] && CDHelper text lineswap --insert="pex = \"$CFG_pex\"" --prefix="pex =" --path=$CFG
[ ! -z "$CFG_persistent_peers" ] && CDHelper text lineswap --insert="persistent_peers = \"$CFG_persistent_peers\"" --prefix="persistent_peers =" --path=$CFG
[ ! -z "$CFG_private_peer_ids" ] && CDHelper text lineswap --insert="private_peer_ids = \"$CFG_private_peer_ids\"" --prefix="private_peer_ids =" --path=$CFG
[ ! -z "$CFG_seeds" ] && CDHelper text lineswap --insert="seeds = \"$CFG_seeds\"" --prefix="seeds =" --path=$CFG
[ ! -z "$CFG_unconditional_peer_ids" ] && CDHelper text lineswap --insert="unconditional_peer_ids = \"$CFG_unconditional_peer_ids\"" --prefix="unconditional_peer_ids =" --path=$CFG
# addr_book_strict -> set true for strict address routability rules ; set false for private or local networks
[ ! -z "$CFG_addr_book_strict" ] && CDHelper text lineswap --insert="addr_book_strict = \"$CFG_addr_book_strict\"" --prefix="addr_book_strict =" --path=$CFG
# P2P Address to advertise to peers for them to dial, If empty, will use the same port as the laddr, and will introspect on the listener or use UPnP to figure out the address.
[ ! -z "$CFG_external_address" ] && CDHelper text lineswap --insert="external_address = \"$CFG_external_address\"" --prefix="external_address =" --path=$CFG
[ ! -z "$CFG_rpc_laddr" ] && CDHelper text lineswap --insert="laddr = \"$CFG_rpc_laddr\"" --prefix="laddr = \"tcp://127.0.0.1:26657\"" --path=$CFG
[ ! -z "$CFG_p2p_laddr" ] && CDHelper text lineswap --insert="laddr = \"$CFG_p2p_laddr\"" --prefix="laddr = \"tcp://0.0.0.0:26656\"" --path=$CFG
#[ ! -z "$CFG_grpc_laddr" ] && CDHelper text lineswap --insert="grpc_laddr = \"$CFG_grpc_laddr\"" --prefix="grpc_laddr =" --path=$CFG
[ ! -z "$CFG_version" ] && CDHelper text lineswap --insert="version = \"$CFG_version\"" --prefix="version =" --path=$CFG
[ ! -z "$CFG_double_sign_check_height" ] && CDHelper text lineswap --insert="double_sign_check_height = \"$CFG_double_sign_check_height\"" --prefix="double_sign_check_height =" --path=$CFG
[ ! -z "$CFG_seed_mode" ] && CDHelper text lineswap --insert="seed_mode = \"$CFG_seed_mode\"" --prefix="seed_mode =" --path=$CFG
[ ! -z "$CFG_skip_timeout_commit" ] && CDHelper text lineswap --insert="skip_timeout_commit = \"$CFG_skip_timeout_commit\"" --prefix="skip_timeout_commit =" --path=$CFG
[ ! -z "$CFG_cors_allowed_origins" ] && CDHelper text lineswap --insert="cors_allowed_origins = [ \"$CFG_cors_allowed_origins\" ]" --prefix="cors_allowed_origins =" --path=$CFG

# Maximum number of inbound P2P peers that can dial your node and connect to it
[ ! -z "$CFG_max_num_inbound_peers" ] && CDHelper text lineswap --insert="max_num_inbound_peers = \"$CFG_max_num_inbound_peers\"" --prefix="max_num_inbound_peers =" --path=$CFG
# Maximum number of outbound P2P peers to connect to, excluding persistent peers
[ ! -z "$CFG_max_num_outbound_peers " ] && CDHelper text lineswap --insert="max_num_outbound_peers = \"$CFG_max_num_outbound_peers\"" --prefix="max_num_outbound_peers =" --path=$CFG
# Toggle to disable guard against peers connecting from the same ip
[ ! -z "$CFG_allow_duplicate_ip" ] && CDHelper text lineswap --insert="allow_duplicate_ip = \"$CFG_allow_duplicate_ip\"" --prefix="allow_duplicate_ip =" --path=$CFG
# How long we wait after commiting a block before starting on the new height
[ ! -z "$CFG_timeout_commit" ] && CDHelper text lineswap --insert="timeout_commit = \"$CFG_timeout_commit\"" --prefix="timeout_commit =" --path=$CFG

[ ! -z "$CFG_create_empty_blocks_interval" ] && CDHelper text lineswap --insert="create_empty_blocks_interval = \"$CFG_create_empty_blocks_interval\"" --prefix="create_empty_blocks_interval =" --path=$CFG

GRPC_ADDRESS=$(echo "$CFG_grpc_laddr" | sed 's/tcp\?:\/\///')
CDHelper text lineswap --insert="GRPC_ADDRESS=\"$GRPC_ADDRESS\"" --prefix="GRPC_ADDRESS=" --path=$ETC_PROFILE --append-if-found-not=True

echoInfo "INFO: Starting state file configuration..."
STATE_HEIGHT=$(cat $LOCAL_STATE | jq -rc '.height' || echo "0")

if [ "${NODE_TYPE,,}" == "validator" ] && [ ! -z "$VALIDATOR_MIN_HEIGHT" ] && [ $VALIDATOR_MIN_HEIGHT -gt $STATE_HEIGHT ] ; then
    echoWarn "WARNING: Updating minimum state height, expected no less than $VALIDATOR_MIN_HEIGHT but got $STATE_HEIGHT"
    cat $LOCAL_STATE | jq ".height = \"$VALIDATOR_MIN_HEIGHT\"" > "$LOCAL_STATE.tmp"
    cp -f -v -a "$LOCAL_STATE.tmp" $LOCAL_STATE
    rm -fv "$LOCAL_STATE.tmp"
fi

STATE_HEIGHT=$(cat $LOCAL_STATE | jq -rc '.height' || echo "0")
echoInfo "INFO: Minimum state height is set to $STATE_HEIGHT"

echoInfo "INFO: Finished node configuration."
