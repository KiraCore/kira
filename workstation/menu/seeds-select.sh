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
    echoWarn "WARNING: If you want to connect to external networks you have to specify at least one public seed or a private peer node"
    echoInfo "INFO: If you are launching a new network you should wipe entire content of the public and private seed & peer nodes list"
    TVAL="." && while ! [[ "${TVAL,,}" =~ ^(p|v|e|w)$ ]] ; do echoNErr "Edit list of [P]ublic Seed Nodes, Pri[V]ate Peer Nodes, [W]ipe all or [E]xit: " && read -d'' -s -n1 TVAL && echo -n ""; done
    [ "${TVAL,,}" == "e" ] && echoInfo "INFO: Seed editor was aborted by the user" && break
    if [ "${TVAL,,}" == "v" ] ; then
        $KIRA_MANAGER/kira/seeds-edit.sh "$PRIVATE_PEERS" "Private Peer Nodes"
    elif [ "${TVAL,,}" == "p" ] ; then
        $KIRA_MANAGER/kira/seeds-edit.sh "$PUBLIC_SEEDS" "Public Seed Nodes"
    elif [ "${TVAL,,}" == "w" ] ; then
        echoInfo "INFO: Wiping all public and private seed & peer node lists"
        rm -f -v "$PUBLIC_SEEDS" "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS"
        touch "$PUBLIC_SEEDS" "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS"
    elif [ "${TVAL,,}" == "e" ] ; then
        if ( ($(isFileEmpty $PUBLIC_SEEDS )) && ($(isFileEmpty $PRIVATE_PEERS )) ) ; then
            SVAL="." && while ! [[ "${SVAL,,}" =~ ^(y|n)$ ]] ; do echoNErr "No public or private seed nodes were specified, are you sure you want to launch network locally? (y/n): " && read -d'' -s -n1 SVAL && echo -n ""; done
            [ "${SVAL,,}" != "y" ] && echo "INFO: Action was cancelled by the user" && continue
            rm -f -v "$PUBLIC_SEEDS" "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS"
        fi
        echoInfo "INFO: Exiting seeds select"
        exit 0
    else
        continue
    fi
done
