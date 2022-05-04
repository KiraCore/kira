#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/seeds-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

mkdir -p "$KIRA_CONFIGS"
TMP_GENESIS_PATH="/tmp/genesis.json"

if [ "${NEW_NETWORK,,}" == "true" ] ; then
    echoWarn "WARNING: User chose to create new network, existing list of seeds & peers will be removed"
    rm -f -v "$PUBLIC_PEERS" "$PUBLIC_SEEDS"
    touch "$PUBLIC_PEERS" "$PUBLIC_SEEDS"
    exit 0
fi

while : ; do
    set +x
    loadGlobEnvs
    echoInfo "INFO: Current list of peers:"
    (! $(isFileEmpty $PUBLIC_PEERS )) && cat $PUBLIC_PEERS || echo "none"
    echoInfo "INFO: Current list of seeds:"
    (! $(isFileEmpty $PUBLIC_SEEDS )) && cat $PUBLIC_SEEDS || echo "none"
    echoWarn "WARNING: If you want to connect to external networks you have to specify at least one seed or peer node"
    echoInfo "INFO: If you are launching a new network you should wipe entire content of the seed & peer nodes list"
    echoNErr "Attemp Public Seeds [A]uto-discovery, edit list of [S]eed/[P]eer  Nodes, [W]ipe all or [E]xit: " && pressToContinue a s p w e && SELECT=($(globGet OPTION))
    set -x
    if [ "${SELECT,,}" == "p" ] ; then
        $KIRA_MANAGER/kira/seeds-edit.sh "$PUBLIC_PEERS" "Peer Nodes"
    elif [ "${SELECT,,}" == "s" ] ; then
        $KIRA_MANAGER/kira/seeds-edit.sh "$PUBLIC_SEEDS" "Seed Nodes"
    elif [ "${SELECT,,}" == "w" ] ; then
        echoInfo "INFO: Wiping all seed & peer node lists"
        rm -f -v "$PUBLIC_SEEDS" "$PUBLIC_PEERS"
        touch "$PUBLIC_SEEDS" "$PUBLIC_PEERS"
    elif [ "${SELECT,,}" == "a" ] ; then
        NODE_ADDR=""
        set +x
        echo "INFO: Previously trusted node address (default): $TRUSTED_NODE_ADDR"
        echoNErr "Input address (IP/DNS) of the public node you trust or choose [ENTER] for default: " && read NODE_ADDR && NODE_ADDR=$(echo "$NODE_ADDR" | xargs)
        set -x

        [ -z "$NODE_ADDR" ] && NODE_ADDR=$TRUSTED_NODE_ADDR
        (! $(isDnsOrIp "$NODE_ADDR")) && echoErr "ERROR: Invalid IPv4 address or DNS name" && continue
        TRUSTED_NODE_ADDR="$NODE_ADDR" && setGlobEnv TRUSTED_NODE_ADDR "$TRUSTED_NODE_ADDR"

        echoInfo "INFO: Downloading seeds list & attempting discovery of active nodes..."
        TMP_PEERS="/tmp/peers.txt" && rm -fv "$TMP_PEERS" 
        $KIRA_MANAGER/scripts/discover-peers.sh "$NODE_ADDR" "$TMP_PEERS" false false 1024 || echoErr "ERROR: Active seeds discovery scan failed"
        SNAP_PEER=$(sed "1q;d" $TMP_PEERS | xargs || echo "")
        if [ ! -z "$SNAP_PEER" ]; then
            echoInfo "INFO: List of active public seeds was found, saving changes to $PUBLIC_SEEDS"
            cat $TMP_PEERS > $PUBLIC_SEEDS
        else
            echoWarn "INFO: List of active public seeds was NOT found"
        fi
    elif [ "${SELECT,,}" == "e" ] ; then
        if ( ($(isFileEmpty $PUBLIC_SEEDS )) && ($(isFileEmpty $PUBLIC_PEERS )) ) ; then
            set +x
            echoNErr "No public seed or peer nodes were specified, are you sure you want to launch network locally? (y/n): " && pressToContinue y n && SELECT=($(globGet OPTION))
            [ "${SELECT,,}" != "y" ] && echoInfo "INFO: Action was cancelled by the user" && continue
            set -x
            rm -f -v "$PUBLIC_SEEDS" "$PUBLIC_PEERS"
            touch "$PUBLIC_SEEDS" "$PUBLIC_PEERS"
        fi
        echoInfo "INFO: Exiting seeds select"
        exit 0
    else
        continue
    fi
done

