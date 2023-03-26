#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/seeds-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

mkdir -p "$KIRA_CONFIGS"
TMP_GENESIS_PATH="/tmp/genesis.json"
NEW_NETWORK=$(globGet NEW_NETWORK)

if [ "$(globGet NEW_NETWORK)" == "true" ] ; then
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
    echoNErr "Attemp Public Seeds [A]uto-discovery, edit list of [S]eed/[P]eer Nodes, [W]ipe all or [E]xit: " && pressToContinue a s p w e && SELECT="$(toLower "$(globGet OPTION)")"
    set -x
    if [ "$SELECT" == "p" ] ; then
        $KIRA_MANAGER/kira/seeds-edit.sh --destination="$PUBLIC_PEERS" --target="Peer Nodes"
    elif [ "$SELECT" == "s" ] ; then
        $KIRA_MANAGER/kira/seeds-edit.sh --destination="$PUBLIC_SEEDS" --target="Seed Nodes"
    elif [ "$SELECT" == "w" ] ; then
        echoInfo "INFO: Wiping all seed & peer node lists"
        rm -f -v "$PUBLIC_SEEDS" "$PUBLIC_PEERS"
        touch "$PUBLIC_SEEDS" "$PUBLIC_PEERS"
    elif [ "$SELECT" == "a" ] ; then
        NODE_ADDR=""
        set +x
        echo "INFO: Previously trusted node address (default): $(globGet TRUSTED_NODE_ADDR)"
        echoNErr "Input address (IP/DNS) of the public node you trust or choose [ENTER] for default: " && read NODE_ADDR && NODE_ADDR=$(echo "$NODE_ADDR" | xargs)
        set -x

        [ -z "$NODE_ADDR" ] && NODE_ADDR=$(globGet TRUSTED_NODE_ADDR)
        (! $(isDnsOrIp "$NODE_ADDR")) && echoErr "ERROR: Invalid IPv4 address or DNS name" && continue
        globSet TRUSTED_NODE_ADDR "$NODE_ADDR"

        echoInfo "INFO: Downloading seeds list..."
        TMP_PEERS="/tmp/peers.txt" && rm -fv "$TMP_PEERS" 
        wget $NODE_ADDR:11000/api/pub_p2p_list?peers_only=true -O $TMP_PEERS || echoErr "ERROR: Active seeds discovery scan failed"
        if (! $(isFileEmpty "$TMP_PEERS")) ; then
            echoInfo "INFO: List of active public seeds was found, saving changes to $PUBLIC_SEEDS"
            cat $TMP_PEERS >> $PUBLIC_SEEDS
            sort -u $PUBLIC_SEEDS -o $PUBLIC_SEEDS
        else
            echoWarn "INFO: List of active public seeds was NOT found"
        fi
    elif [ "$SELECT" == "e" ] ; then
        if ( ($(isFileEmpty $PUBLIC_SEEDS )) && ($(isFileEmpty $PUBLIC_PEERS )) ) ; then
            set +x
            echoNErr "No public seed or peer nodes were specified, are you sure you want to launch network locally? (y/n): " && pressToContinue y n && SELECT="$(toLower "$(globGet OPTION)")"
            [ "$SELECT" != "y" ] && echoInfo "INFO: Action was cancelled by the user" && continue
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

