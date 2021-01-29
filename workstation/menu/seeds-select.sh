#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/menu/seeds-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

mkdir -p "$KIRA_CONFIGS"
TMP_GENESIS_PATH="/tmp/genesis.json"
LOCAL_GENESIS_PATH="$KIRA_CONFIGS/genesis.json"
PUBLIC_SEEDS="$KIRA_CONFIGS/public_seeds"
PRIVATE_SEEDS="$KIRA_CONFIGS/private_seeds"
PUBLIC_PEERS="$KIRA_CONFIGS/public_peers"
PRIVATE_PEERS="$KIRA_CONFIGS/private_peers"

if [ "${NEW_NETWORK,,}" == "true" ] ; then
    echoWarn "WARNING: User chose to create new network, existing list of seeds & peers will be remove"
    rm -f -v "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS" "$PUBLIC_SEEDS"
    touch "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS" "$PUBLIC_SEEDS"
    exit 0
fi

while : ; do
    set +x
    echoInfo "INFO: If you want to connect to external networks you have to specify at least one public seed node"
    echoInfo "INFO: If you are launching a new network you will have to wipe the contents of the seed list"

    $KIRA_MANAGER/kira/seeds-edit.sh "$PUBLIC_SEEDS" "Seed Nodes"
    # TODO: Implement Backup & Recovery of network settings

    echoInfo "INFO: Testing seeds..."

    set -x

    if [[ -z $(grep '[^[:space:]]' $PUBLIC_SEEDS) ]] ; then
        set +x
        echoInfo "INFO: No public seeds were specified"
        echoErr "Press any key to continue or Ctrl+C to abort..." && read -n 1 -s && echo ""
        SVAL="." && while [ "${SVAL,,}" != "y" ] && [ "${SVAL,,}" != "n" ] ; do echo -en "\e[31;1mDo you want to launch a local network? (y/n): \e[0m\c" && read -d'' -s -n1 SVAL && echo ""; done
        set -x
        [ "${SVAL,,}" != "y" ] && echo "INFO: Action was cancelled by the user" && continue
        rm -f -v "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS"
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

        nodeId="" && [[ "$p1" =~ ^[a-f0-9]{40}$ ]] && nodeId="$p1"
        dns="" && [[ "$(echo $p2 | grep -P '(?=^.{4,253}$)(^(?:[a-zA-Z](?:(?:[a-zA-Z0-9\-]){0,61}[a-zA-Z])?\.)+[a-zA-Z]{2,}$)')" == "$p2" ]] && dns="$p2" # DNS regex
        [ -z "$dns" ] && [[ $p2 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && dns="$p2" # IP is fine too

        if ! timeout 1 ping -c1 $dns &>/dev/null ; then 
            echoWarn "WARNING: Seed '$addr' is not reachable"
        else
            set +x && echo "SUCCESS: Seed '$addr' is ONLINE!" && set -
            rm -f -v "$PRIVATE_SEEDS" "$PRIVATE_PEERS" "$PUBLIC_PEERS"
            exit 0
        fi
    done < $PUBLIC_SEEDS
    
    set +x
    echoWarn "WARNING: Not a single seed node defined in the configuration is reachable, you will not be able to launch your node!"
    SVAL="." && while [ "${SVAL,,}" != "t" ] && [ "${SVAL,,}" != "x" ] ; do echo -en "\e[31;1mDo you want to [T]ry again or [E]xit? (y/n): \e[0m\c" && read -d'' -s -n1 SVAL && echo ""; done
    [ "${SVAL,,}" == "x" ] && echo "INFO: Action was cancelled by the user" && exit 1
done
