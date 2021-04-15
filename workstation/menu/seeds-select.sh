#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/menu/seeds-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

mkdir -p "$KIRA_CONFIGS"
TMP_GENESIS_PATH="/tmp/genesis.json"

if [ "${NEW_NETWORK,,}" == "true" ] ; then
    echoWarn "WARNING: User chose to create new network, existing list of seeds & peers will be removed"
    rm -f -v "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS" "$PUBLIC_SEEDS"
    touch "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS" "$PUBLIC_SEEDS"
    exit 0
fi

while : ; do
    set +x
    echoWarn "WARNING: If you want to connect to external networks you have to specify at least one public seed or a private peer node"
    echoInfo "INFO: If you are launching a new network you should wipe entire content of the public and private seed & peer nodes list"
    TVAL="." && while ! [[ "${TVAL,,}" =~ ^(a|p|v|e|w)$ ]] ; do echoNErr "Attemp Public Seeds [A]uto-discovery, edit list of [P]ublic/Pri[V]ate Seed Nodes, [W]ipe all or [E]xit: " && read -d'' -s -n1 TVAL && echo ""; done
    [ "${TVAL,,}" == "e" ] && echoInfo "INFO: Seed editor was aborted by the user" && break
    set -x
    if [ "${TVAL,,}" == "v" ] ; then
        $KIRA_MANAGER/kira/seeds-edit.sh "$PRIVATE_SEEDS" "Private Peer Nodes"
    elif [ "${TVAL,,}" == "p" ] ; then
        $KIRA_MANAGER/kira/seeds-edit.sh "$PUBLIC_SEEDS" "Public Seed Nodes"
    elif [ "${TVAL,,}" == "w" ] ; then
        echoInfo "INFO: Wiping all public and private seed & peer node lists"
        rm -f -v "$PUBLIC_SEEDS" "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS"
        touch "$PUBLIC_SEEDS" "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS"
    elif [ "${TVAL,,}" == "a" ] ; then
        NODE_ADDR=""
        set +x
        echo "INFO: Previously trusted node address (default): $TRUSTED_NODE_ADDR"
        echoNErr "Input address (IP/DNS) of the public node you trust or choose [ENTER] for default: " && read NODE_ADDR && NODE_ADDR=$(echo "$NODE_ADDR" | xargs)
        set -x
        [ -z "$NODE_ADDR" ] && NODE_ADDR=$TRUSTED_NODE_ADDR

        if (! $(isDnsOrIp "$NODE_ADDR")) ; then
            echoErr "ERROR: Invalid IPv4 address or DNS name"
            continue
        fi

        echoInfo "INFO: Downloading seeds list & attempting discovery of active nodes..."
        TMP_PEERS="/tmp/peers.txt" && rm -fv "$TMP_PEERS" 
        $KIRA_MANAGER/scripts/discover-peers.sh "$NODE_ADDR" "$TMP_PEERS" false false 16 || echoErr "ERROR: Active seeds discovery scan failed"
        SNAP_PEER=$(sed "1q;d" $TMP_PEERS | xargs || echo "")
        if [ ! -z "$SNAP_PEER" ]; then
            [ ! -z $NODE_ADDR ] && CDHelper text lineswap --insert="TRUSTED_NODE_ADDR=\"$NODE_ADDR\"" --prefix="TRUSTED_NODE_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
            echoInfo "INFO: List of active public seeds was found, saving changes to $PUBLIC_SEEDS"
            cat $TMP_PEERS > $PUBLIC_SEEDS
        else
            echoWarn "INFO: List of active public seeds was NOT found"
        fi
    elif [ "${TVAL,,}" == "e" ] ; then
        if ( ($(isFileEmpty $PUBLIC_SEEDS )) && ($(isFileEmpty $PRIVATE_PEERS )) ) ; then
            set +x
            SVAL="." && while ! [[ "${SVAL,,}" =~ ^(y|n)$ ]] ; do echoNErr "No public or private seed nodes were specified, are you sure you want to launch network locally? (y/n): " && read -d'' -s -n1 SVAL && echo ""; done
            [ "${SVAL,,}" != "y" ] && echoInfo "INFO: Action was cancelled by the user" && continue
            set -x
            rm -f -v "$PUBLIC_SEEDS" "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS"
        fi
        echoInfo "INFO: Exiting seeds select"
        exit 0
    else
        continue
    fi
done

