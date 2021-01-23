#!/bin/bash

exec 2>&1
set -e
set -x

echo "INFO: Starting node configuration..."

CFG="$SEKAID_HOME/config/config.toml"
COMMON_PEERS_PATH="$COMMON_DIR/peers"
COMMON_SEEDS_PATH="$COMMON_DIR/seeds"
LOCAL_PEERS_PATH="$SEKAID_HOME/config/peers"
LOCAL_SEEDS_PATH="$SEKAID_HOME/config/seeds"

[ -f "$COMMON_PEERS_PATH" ] && cp -a -v -f "$COMMON_PEERS_PATH" "$LOCAL_PEERS_PATH"
[ -f "$COMMON_SEEDS_PATH" ] && cp -a -v -f "$COMMON_SEEDS_PATH" "$LOCAL_SEEDS_PATH"

if [ -f "$LOCAL_PEERS_PATH" ] ; then 
    echo "INFO: List of external peers was found"
    while read peer ; do
        peer=$(echo "$peer" | sed 's/tcp\?:\/\///')
        [ -z "$peer" ] && continue # peer not found
        addrArr1=( $(echo $peer | tr "@" "\n") )
        nodeId=${addrArr1[0],,}
        peer="tcp://$peer"
        echo "INFO: Adding extra peer '$peer'"

        [ ! -z "$CFG_private_peer_ids" ] && CFG_private_peer_ids="${CFG_private_peer_ids},"
        [ ! -z "$CFG_persistent_peers" ] && CFG_persistent_peers="${CFG_persistent_peers},"
        [ ! -z "$CFG_unconditional_peer_ids" ] && CFG_unconditional_peer_ids="${CFG_unconditional_peer_ids},"
        
        CFG_private_peer_ids="${CFG_private_peer_ids}${nodeId}"
        CFG_persistent_peers="${CFG_persistent_peers}${peer}"
        CFG_unconditional_peer_ids="${CFG_unconditional_peer_ids}${nodeId}"
    done < $LOCAL_PEERS_PATH
fi

if [ -f "$LOCAL_SEEDS_PATH" ] ; then 
    echo "INFO: List of external seeds was found"
    while read seed ; do
        peer=$(echo "$seed" | sed 's/tcp\?:\/\///')
        [ -z "$seed" ] && continue # seed not found
        seed="tcp://$seed"
        echo "INFO: Adding extra seed '$seed'"
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
[ ! -z "$CFG_rpc_laddr" ] && CDHelper text lineswap --insert="laddr = \"$CFG_rpc_laddr\"" --prefix="laddr = \"tcp://127.0.0.1:26657\"" --path=$CFG
[ ! -z "$CFG_p2p_laddr" ] && CDHelper text lineswap --insert="laddr = \"$CFG_p2p_laddr\"" --prefix="laddr = \"tcp://0.0.0.0:26656\"" --path=$CFG
#[ ! -z "$CFG_grpc_laddr" ] && CDHelper text lineswap --insert="grpc_laddr = \"$CFG_grpc_laddr\"" --prefix="grpc_laddr =" --path=$CFG
[ ! -z "$CFG_version" ] && CDHelper text lineswap --insert="version = \"$CFG_version\"" --prefix="version =" --path=$CFG
[ ! -z "$CFG_seed_mode" ] && CDHelper text lineswap --insert="seed_mode = \"$CFG_seed_mode\"" --prefix="seed_mode =" --path=$CFG
[ ! -z "$CFG_cors_allowed_origins" ] && CDHelper text lineswap --insert="cors_allowed_origins = [ \"$CFG_cors_allowed_origins\" ]" --prefix="cors_allowed_origins =" --path=$CFG

# Maximum number of inbound P2P peers that can dial your node and connect to it
[ ! -z "$CFG_max_num_inbound_peers" ] && CDHelper text lineswap --insert="max_num_inbound_peers = \"$CFG_max_num_inbound_peers\"" --prefix="max_num_inbound_peers =" --path=$CFG
# Maximum number of outbound P2P peers to connect to, excluding persistent peers
[ ! -z "$CFG_max_num_outbound_peers " ] && CDHelper text lineswap --insert="max_num_outbound_peers = \"$CFG_max_num_outbound_peers\"" --prefix="max_num_outbound_peers =" --path=$CFG

echo "INFO: Finished node configuration."
