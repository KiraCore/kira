#!/usr/bin/env bash
set +e && source /etc/profile &>/dev/null && set -e
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
STATE_FILE="$SEKAID_HOME/data/priv_validator_state.json"

[ -f "$COMMON_PEERS_PATH" ] && cp -afv "$COMMON_PEERS_PATH" "$LOCAL_PEERS_PATH"
[ -f "$COMMON_SEEDS_PATH" ] && cp -afv "$COMMON_SEEDS_PATH" "$LOCAL_SEEDS_PATH"

LOCAL_IP=$(globGet LOCAL_IP "$GLOBAL_COMMON_RO")
PUBLIC_IP=$(globGet PUBLIC_IP "$GLOBAL_COMMON_RO")
LATEST_BLOCK_HEIGHT=$(globGet latest_block_height $GLOBAL_COMMON_RO) 
MIN_HEIGHT=$(globGet MIN_HEIGHT $GLOBAL_COMMON_RO) 
STATE_HEIGHT=$(jsonQuickParse "height" $STATE_FILE || echo "") 
(! $(isNaturalNumber $LATEST_BLOCK_HEIGHT)) && LATEST_BLOCK_HEIGHT=0
(! $(isNaturalNumber $MIN_HEIGHT)) && MIN_HEIGHT=0
(! $(isNaturalNumber $STATE_HEIGHT)) && STATE_HEIGHT=0
[[ $MIN_HEIGHT -lt $LATEST_BLOCK_HEIGHT ]] && MIN_HEIGHT=$LATEST_BLOCK_HEIGHT
[[ $MIN_HEIGHT -lt $STATE_HEIGHT ]] && MIN_HEIGHT=$STATE_HEIGHT

cfg_p2p_max_num_outbound_peers=$(globGet cfg_p2p_max_num_outbound_peers)
cfg_p2p_unconditional_peer_ids=$(globGet cfg_p2p_unconditional_peer_ids)
cfg_p2p_persistent_peers=$(globGet cfg_p2p_persistent_peers)
cfg_p2p_seeds=$(globGet cfg_p2p_seeds)

echoInfo "INFO: Setting up node key..."
cp -afv $COMMON_DIR/node_key.json $SEKAID_HOME/config/node_key.json

[ "${NODE_TYPE,,}" == "validator" ] && \
    echoInfo "INFO: Setting up priv validator key..." && \
    cp -afv $COMMON_DIR/priv_validator_key.json $SEKAID_HOME/config/priv_validator_key.json

[ "$(globGet PRIVATE_MODE)" == "true" ] && EXTERNAL_DNS="$LOCAL_IP" || EXTERNAL_DNS="$PUBLIC_IP"

cfg_p2p_external_address="tcp://$EXTERNAL_DNS:$EXTERNAL_P2P_PORT"
globSet cfg_p2p_external_address "$cfg_p2p_external_address"
globSet EXTERNAL_ADDRESS "$cfg_p2p_external_address"
globSet EXTERNAL_DNS "$EXTERNAL_DNS"
globSet EXTERNAL_PORT "$EXTERNAL_P2P_PORT"

echoInfo "INFO:    Local Addr: $LOCAL_IP"
echoInfo "INFO:   Public Addr: $PUBLIC_IP"
echoInfo "INFO: External Addr: $EXTERNAL_ADDRESS"

echoInfo "INFO: Starting genesis configuration..."
if [[ "${NODE_TYPE,,}" =~ ^(sentry|seed)$ ]] && [ "$UPGRADE_MODE" == "none" ] ; then
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
        [ ! -z "$cfg_p2p_persistent_peers" ] && cfg_p2p_persistent_peers="${cfg_p2p_persistent_peers},"
        cfg_p2p_persistent_peers="${cfg_p2p_persistent_peers}${peer}"
    done < $LOCAL_PEERS_PATH
    set -x
else echoWarn "WARNING: List of local peers is empty ($LOCAL_PEERS_PATH)" ; fi

if [ -f "$LOCAL_SEEDS_PATH" ] ; then 
    echoInfo "INFO: List of external seeds was found, shuffling and adding to seeds config"
    shuf $LOCAL_SEEDS_PATH > "${LOCAL_SEEDS_PATH}.tmp"
    set +x
    while read seed ; do
        echoInfo "INFO: Adding extra seed '$seed' from the list"
        [ ! -z "$cfg_p2p_seeds" ] && cfg_p2p_seeds="${cfg_p2p_seeds},"
        cfg_p2p_seeds="${cfg_p2p_seeds}${seed}"
    done < "${LOCAL_SEEDS_PATH}.tmp"
    set -x
else echoWarn "WARNING: List of local peers is empty ($LOCAL_SEEDS_PATH)" ; fi

rm -fv $LOCAL_RPC_PATH
touch $LOCAL_RPC_PATH

if [ ! -z "$cfg_p2p_seeds" ] ; then
    echoInfo "INFO: Seed configuration is available, testing..."
    TMP_cfg_p2p_seeds=""
    i=0
    for seed in $(echo $cfg_p2p_seeds | sed "s/,/ /g") ; do
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
        ($(isSubStr "$TMP_cfg_p2p_seeds" "$nodeId")) && echoWarn "WARNINIG: Seed '$seed' can NOT be added, node-id already present in the config." && continue
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
        if [[ $i -ge $cfg_p2p_max_num_outbound_peers ]] ; then
            echoWarn "INFO: Outbound seeds limit (${i}/${cfg_p2p_max_num_outbound_peers}) reached"
        else
            echoInfo "INFO: Adding extra seed '$seed' to new config"
            [ ! -z "$TMP_cfg_p2p_seeds" ] && TMP_cfg_p2p_seeds="${TMP_cfg_p2p_seeds},"
            TMP_cfg_p2p_seeds="${TMP_cfg_p2p_seeds}${seed}"
        fi
        set -x
    done
    cfg_p2p_seeds=$TMP_cfg_p2p_seeds
else echoWarn "WARNING: Seeds configuration is NOT available!" ; fi

if [ ! -z "$cfg_p2p_persistent_peers" ] ; then
    echoInfo "INFO: Peers configuration is available, testing..."
    
    TMP_cfg_p2p_persistent_peers=""
    for peer in $(echo $cfg_p2p_persistent_peers | sed "s/,/ /g") ; do
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
        ($(isSubStr "$TMP_cfg_p2p_persistent_peers" "$nodeId")) && echoWarn "WARNINIG: Peer '$peer' can NOT be added, node-id already present in the peers config." && continue
        ($(isSubStr "$cfg_p2p_seeds" "$nodeId")) && echoWarn "WARNINIG: Peer '$peer' can NOT be added, node-id already present in the seeds config." && continue
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

        [ ! -z "$TMP_cfg_p2p_persistent_peers" ] && TMP_cfg_p2p_persistent_peers="${TMP_cfg_p2p_persistent_peers},"
        TMP_cfg_p2p_persistent_peers="${TMP_cfg_p2p_persistent_peers}${peer}"

        if (! $(isSubStr "$cfg_p2p_unconditional_peer_ids" "$nodeId")) ; then
            [ ! -z "$cfg_p2p_unconditional_peer_ids" ] && cfg_p2p_unconditional_peer_ids="${cfg_p2p_unconditional_peer_ids},"
            cfg_p2p_unconditional_peer_ids="${cfg_p2p_unconditional_peer_ids}${nodeId}"
        fi
        set -x
    done
    cfg_p2p_persistent_peers=$TMP_cfg_p2p_persistent_peers
else
    echoWarn "WARNING: Peers configuration is NOT available!"
fi

echoInfo "INFO: Final Peers List:"
echoInfo "$cfg_p2p_persistent_peers"
rpc_cntr=0

if (! $(isFileEmpty $LOCAL_RPC_PATH)) ; then
    echoInfo "INFO: Starting fast sync configuaration, RPC nodes detected!"
    TRUST_HASH=""
    RPC_SERVERS=""
    while read rpc ; do
        set +x
        BLOCK_INFO=$(timeout 3 curl --fail $rpc/block?height=$MIN_HEIGHT 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")
        [ -z "$BLOCK_INFO" ] && echoWarn "WARNING: Failed to fetch block info from '$rpc'" && continue
        HEIGHT=$(echo "$BLOCK_INFO" | jsonParse "block.header.height" 2>/dev/null || echo -n "") 
        (! $(isNaturalNumber $HEIGHT)) && HEIGHT=0
        [ "$HEIGHT" != "$MIN_HEIGHT" ] && echoWarn "INFO: RPC height is $HEIGHT but expected $MIN_HEIGHT" && continue
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
        cfg_statesync_trust_hash=$TRUST_HASH
        cfg_statesync_rpc_servers=$RPC_SERVERS
        cfg_statesync_trust_height="$MIN_HEIGHT"
    else
        echoWarn "WARNING: Insufficicent RPC nodes count ($rpc_cntr)"
    fi
else
    echoWarn "WARNING: Fast sync is NOT possible, RPC nodes NOT found"
fi

if ( $(isNullOrEmpty $cfg_statesync_rpc_servers) ) ; then
    echoWarn "WARNING: NO live RPC servers were found, disabling statesync"
    cfg_statesync_enable="false"
    cfg_statesync_trust_height=0
    cfg_statesync_trust_hash="\"\""
fi

mkdir -pv "$(globGet cfg_statesync_temp_dir)" || echoErr "ERROR: Failed to create statesync temp directory"

set +x
echoInfo "INFO: Final Peers List:"
echoInfo "$cfg_statesync_rpc_servers"

echoInfo "INFO: Updating CFG file..."
set -x
getTomlVarNames $CFG > /tmp/cfg_names.tmp
mapfile cfg_rows < /tmp/cfg_names.tmp
set +x
for row in "${cfg_rows[@]}"; do
    ( $(isNullOrWhitespaces $row) ) && continue
    tag=$(echo $row | cut -d' ' -f1 | tr -d '\011\012\013\014\015\040\133\135' | xargs)
    name=$(echo $row | cut -d' ' -f2 | tr -d '\011\012\013\014\015\040\133\135' | xargs)
    # value can be set from env or from globs
    val_target_1=$(echo "cfg_${tag}_${name}" | tr -d '\011\012\013\014\015\040\133\135' | xargs)
    val_target_2=$(echo "$val_target_1" | sed -r 's/[-]+/_/g' | xargs)
    val="${!val_target_2}"
    [ -z "$val" ] && val=$(globGet "$val_target_1")
    [ -z "$val" ] && val=$(globGet "$val_target_2")
    if [ ! -z "$val" ] ; then
        echoWarn "WARNING: Updating CFG value: [$tag] $name -> '$val' "
        setTomlVar "[$tag]" "$name" "$val" $CFG
    else
        echoInfo "INFO: CFG value: [$tag] $name will NOT change, glob val NOT found"
    fi
done

echoInfo "INFO: Updating APP file..."
set -x
getTomlVarNames $APP > /tmp/app_names.tmp
mapfile app_rows < /tmp/app_names.tmp
set +x
for row in "${app_rows[@]}"; do
    ( $(isNullOrWhitespaces $row) ) && continue
    tag=$(echo $row | cut -d' ' -f1 | tr -d '\011\012\013\014\015\040\133\135' | xargs)
    name=$(echo $row | cut -d' ' -f2 | tr -d '\011\012\013\014\015\040\133\135' | xargs)
    val_target_1=$(echo "app_${tag}_${name}" | tr -d '\011\012\013\014\015\040\133\135' | xargs)
    val_target_2=$(echo "$val_target_1" | sed -r 's/[-]+/_/g' | xargs)
    val="${!val_target_2}"
    [ -z "$val" ] && val=$(globGet "$val_target_1")
    [ -z "$val" ] && val=$(globGet "$val_target_2")
    if [ ! -z "$val" ] ; then
        echoWarn "WARNING: Updating APP value: [$tag] $name -> '$val' "
        setTomlVar "[$tag]" "$name" "$val" $APP
    else
        echoInfo "INFO: APP value: [$tag] $name will NOT change, glob val was NOT found"
    fi
done

set -x

if [[ $MIN_HEIGHT -gt $STATE_HEIGHT ]] ; then
    echoWarn "WARNING: Updating minimum state height, expected no less than $MIN_HEIGHT but got $STATE_HEIGHT"
    cat >$STATE_FILE <<EOL
{
  "height": "$MIN_HEIGHT",
  "round": 0,
  "step": 0
}
EOL
fi

STATE_HEIGHT=$(jsonQuickParse "height" $STATE_FILE || echo "")
echoInfo "INFO: Minimum state height is set to $STATE_HEIGHT"
echoInfo "INFO: Finished node configuration."
globSet CFG_TASK "false"
