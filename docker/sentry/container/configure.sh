#!/bin/bash

exec 2>&1
set -e
set -x

echo "INFO: Starting node configuration..."

CFG="$SEKAID_HOME/config/config.toml"
[ ! -z "$CFG_moniker" ] && CDHelper text lineswap --insert="moniker = \"$CFG_moniker\"" --prefix="moniker =" --path=$CFG
[ ! -z "$CFG_pex" ] && CDHelper text lineswap --insert="pex = \"$CFG_pex\"" --prefix="pex =" --path=$CFG
[ ! -z "$CFG_persistent_peers" ] && CDHelper text lineswap --insert="persistent_peers = \"$CFG_persistent_peers\"" --prefix="persistent_peers =" --path=$CFG
[ ! -z "$CFG_private_peer_ids" ] && CDHelper text lineswap --insert="private_peer_ids = \"$CFG_private_peer_ids\"" --prefix="private_peer_ids =" --path=$CFG
[ ! -z "$CFG_private_peer_ids" ] && CDHelper text lineswap --insert="private_peer_ids = \"$CFG_private_peer_ids\"" --prefix="private_peer_ids =" --path=$CFG
[ ! -z "$CFG_unconditional_peer_ids" ] && CDHelper text lineswap --insert="unconditional_peer_ids = \"$CFG_unconditional_peer_ids\"" --prefix="unconditional_peer_ids =" --path=$CFG
# addr_book_strict -> set true for strict address routability rules ; set false for private or local networks
[ ! -z "$CFG_addr_book_strict" ] && CDHelper text lineswap --insert="addr_book_strict = \"$CFG_addr_book_strict\"" --prefix="addr_book_strict =" --path=$CFG

[ ! -z "$CFG_version" ] && CDHelper text lineswap --insert="version = \"$CFG_version\"" --prefix="version =" --path=$CFG
[ ! -z "$CFG_seed_mode" ] && CDHelper text lineswap --insert="seed_mode = \"$CFG_seed_mode\"" --prefix="seed_mode =" --path=$CFG
[ ! -z "$CFG_cors_allowed_origins" ] && CDHelper text lineswap --insert="cors_allowed_origins = [ $CFG_cors_allowed_origins ]" --prefix="cors_allowed_origins =" --path=$CFG



