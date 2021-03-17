#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/menu/seeds-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

mkdir -p "$KIRA_CONFIGS"
TMP_GENESIS_PATH="/tmp/genesis.json"

if [ "${NEW_NETWORK,,}" == "true" ] ; then
    echoWarn "WARNING: User chose to create new network, existing list of seeds & peers will be remove"
    rm -f -v "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS" "$PUBLIC_SEEDS"
    touch "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS" "$PUBLIC_SEEDS"
    exit 0
fi

while : ; do
    set +x
    echoInfo "INFO: If you want to connect to external networks you have to specify at least one public or private seed node"
    echoInfo "INFO: If you are launching a new network you should wipe entire content of the seed list"

    if [ "${INFRA_MODE,,}" == "validator" ] ; then
        SEEDS_EDIT="$PRIVATE_SEEDS"
        SEEDS_WIPE="$PUBLIC_SEEDS"
        TARGET_EDIT="Private Nodes"
    else
        SEEDS_EDIT="$PUBLIC_SEEDS"
        SEEDS_WIPE="$PRIVATE_SEEDS"
        TARGET_EDIT="Seed Nodes"
    fi
    $KIRA_MANAGER/kira/seeds-edit.sh "$SEEDS_EDIT" "$TARGET_EDIT"
    # TODO: Implement Backup & Recovery of network settings

    echoInfo "INFO: Testing seeds..."
    set -x

    if [[ -z $(grep '[^[:space:]]' $SEEDS_EDIT) ]] ; then
        set +x
        SVAL="." && while ! [[ "${SVAL,,}" =~ ^(y|n)$ ]] ; do echoNErr "No public or private seed nodes were specified, do you want to launch a network locally? (y/n): " && read -d'' -s -n1 SVAL && echo ""; done
        set -x
        [ "${SVAL,,}" != "y" ] && echo "INFO: Action was cancelled by the user" && continue
        rm -f -v "$PUBLIC_SEEDS" "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS"
        exit 0
    fi

    while read addr ; do
        [ -z "$addr" ] && continue # only display non-empty lines
        i=$((i + 1))

        addr=$(echo "$addr" | xargs) # trim whitespace characters
        addrArr1=( $(echo $addr | tr "@" "\n") )
        addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )

        p1=${addrArr1[0],,}
        p2=${addrArr2[0],,}
        p3=${addrArr2[1],,}

        ($(isNodeId "$p1")) && nodeId="$p1" || nodeId=""
        ($(isDnsOrIp "$p2")) && dns="$p2" || dns=""
        if timeout 2 nc -z $p2 $p3 ; then
            set +x && echo "SUCCESS: Seed '$addr' is ONLINE!" && set -x
            rm -f -v "$SEEDS_WIPE" "$PRIVATE_PEERS" "$PUBLIC_PEERS"
            exit 0
        else
            echoWarn "WARNING: Seed '$addr' is not reachable"
        fi
    done < $SEEDS_EDIT
    
    set +x
    echoWarn "WARNING: Not a single seed node defined in the configuration list is reachable, you will not be able to launch your node!"
    SVAL="." && while [ "${SVAL,,}" != "t" ] && [ "${SVAL,,}" != "x" ] ; do echo -en "\e[31;1mDo you want to [T]ry again or [E]xit? (y/n): \e[0m\c" && read -d'' -s -n1 SVAL && echo ""; done
    [ "${SVAL,,}" == "x" ] && echo "INFO: Action was cancelled by the user" && exit 1
done
