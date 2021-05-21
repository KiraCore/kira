#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/menu/quick-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

mkdir -p "$KIRA_CONFIGS"
TMP_GENESIS_PATH="/tmp/genesis.json"
TMP_SNAP_DIR="$KIRA_SNAP/tmp"
TMP_SNAP_PATH="$TMP_SNAP_DIR/tmp-snap.zip"

rm -fv "$TMP_GENESIS_PATH" "$TMP_SNAP_PATH"

if [ "${NEW_NETWORK,,}" == "true" ]; then
    $KIRA_MANAGER/menu/chain-id-select.sh
    set +x
    set +e && source "/etc/profile" &>/dev/null && set -e
    set -x
    rm -fv "$PUBLIC_PEERS" "$PRIVATE_PEERS" "$PUBLIC_SEEDS" "$PRIVATE_SEEDS"
    CHAIN_ID="$NETWORK_NAME"
    SEED_NODE_ADDR="" && SENTRY_NODE_ADDR="" && PRIV_SENTRY_NODE_ADDR=""
    GENSUM=""
    SNAPSUM=""
    DOWNLOAD_SUCCESS="false"
    TRUSTED_NODE_ADDR="0.0.0.0"
    SNAPSHOT=""
    MIN_HEIGHT="0"

    set +x
    echo "INFO: Startup configuration of the NEW network was finalized"
    echoNInfo "CONFIG:       Network name (chain-id): " && echoErr $CHAIN_ID
    echoNInfo "CONFIG:               Deployment Mode: " && echoErr $INFRA_MODE
    echoNInfo "CONFIG: Minimum expected block height: " && echoErr $MIN_HEIGHT
    echoNInfo "CONFIG:        New network deployment: " && echoErr $NEW_NETWORK
    echoNInfo "CONFIG:   KIRA Manager git repository: " && echoErr $INFRA_REPO
    echoNInfo "CONFIG:       KIRA Manager git branch: " && echoErr $INFRA_BRANCH
    echoNInfo "CONFIG:              sekai git branch: " && echoErr $SEKAI_BRANCH
    echoNInfo "CONFIG:      KIRA Frontend git branch: " && echoErr $FRONTEND_BRANCH
    echoNInfo "CONFIG:             INTERX git branch: " && echoErr $INTERX_BRANCH
    echoNInfo "CONFIG:     Default Network Interface: " && echoErr $IFACE
    echoNInfo "CONFIG:               Deployment Mode: " && echoErr $DEPLOYMENT_MODE
    
    OPTION="." && while ! [[ "${OPTION,,}" =~ ^(a|r)$ ]] ; do echoNErr "Choose to [A]pprove or [R]eject configuration: " && read -d'' -s -n1 OPTION && echo ""; done
    set -x

    if [ "${OPTION,,}" == "r" ] ; then
        echoInfo "INFO: Operation cancelled, try diffrent setup option"
        $KIRA_MANAGER/menu/chain-id-select.sh
        exit 0
    fi
elif [ "${NEW_NETWORK,,}" == "false" ] ; then
    MIN_HEIGHT="0"
    while : ; do
        if [ ! -z "$TRUSTED_NODE_ADDR" ] && [ "$TRUSTED_NODE_ADDR" != "0.0.0.0" ] ; then 
            set +x
            echo "INFO: Previously trusted node address (default): $TRUSTED_NODE_ADDR"
            echoNErr "Input address (IP/DNS) of the public node you trust or choose [ENTER] for default: " && read v1 && v1=$(echo "$v1" | xargs)
            set -x
            [ -z "$v1" ] && v1=$TRUSTED_NODE_ADDR || v1=$(resolveDNS "$v1")
        else
            set +x
            echoNErr "Input address (IP/DNS) of the public node you trust: " && read v1
            set -x
        fi

        ($(isDnsOrIp "$v1")) && NODE_ADDR="$v1" || NODE_ADDR="" 
        [ -z "$NODE_ADDR" ] && echoWarn "WARNING: Value '$v1' is not a valid DNS name or IP address, try again!" && continue
         
        echoInfo "INFO: Please wait, testing connectivity..."
        if ! timeout 2 ping -c1 "$NODE_ADDR" &>/dev/null ; then 
            echoWarn "WARNING: Address '$NODE_ADDR' could NOT be reached, check your network connection or select diffrent node" && continue
        else
            echoInfo "INFO: Success, node '$NODE_ADDR' is online!"
        fi

        STATUS_URL="$NODE_ADDR:$DEFAULT_INTERX_PORT/api/kira/status"
        STATUS=$(timeout 3 curl $STATUS_URL 2>/dev/null | jsonParse "" 2>/dev/null || echo -n "")

        if [ -z "$STATUS" ] || [ "${STATUS,,}" == "null" ] ; then
            STATUS_URL="$NODE_ADDR:$DEFAULT_RPC_PORT/status"
            STATUS=$(timeout 3 curl --fail $STATUS_URL 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")
        fi
        
        HEIGHT=$(echo "$STATUS" | jsonQuickParse "latest_block_height" 2> /dev/null || echo -n "")
        CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null|| echo -n "")

        if [ -z "$STATUS" ] || [ -z "${CHAIN_ID}" ] || [ "${STATUS,,}" == "null" ] || [ "${CHAIN_ID,,}" == "null" ] || [ "${NODE_ID,,}" == "null" ] || [ -z "${HEIGHT##*[!0-9]*}" ] ; then
            echoWarn "WARNING: Could NOT read status, block height or chian-id"
            echoErr "ERROR: Address '$NODE_ADDR' is NOT a valid, publicly exposed public node address"
            continue
        fi

        SEED_NODE_ADDR=""
        if timeout 3 nc -z $NODE_ADDR 16656 ; then
            SEED_NODE_ID=$(tmconnect id --address="$NODE_ADDR:16656" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo "")
            if $(isNodeId "$SEED_NODE_ID") ; then
                SEED_NODE_ADDR="${SEED_NODE_ID}@${NODE_ADDR}:16656"
                echoInfo "INFO: Seed node ID '$SEED_NODE_ID' was found"
            else echoWarn "WARNING: Seed node ID was NOT found" && SEED_NODE_ADDR="" ; fi
        else echoWarn "WARNING: P2P Port 16656 is not exposed by node '$NODE_ADDR'" ; fi

        SENTRY_NODE_ADDR=""
        if timeout 3 nc -z $NODE_ADDR 26656 ; then
            SENTRY_NODE_ID=$(tmconnect id --address="$NODE_ADDR:26656" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo "")
            if $(isNodeId "$SENTRY_NODE_ID") ; then
                SENTRY_NODE_ADDR="${SENTRY_NODE_ID}@${NODE_ADDR}:26656"
                echoInfo "INFO: Sentry node ID '$SENTRY_NODE_ID' was found"
            else echoWarn "WARNING: Sentry node ID was NOT found" && SENTRY_NODE_ADDR="" ; fi
        elif [ -z "$NODE_PORT" ] ; then echoWarn "WARNING: P2P Port 26656 is not exposed by node '$NODE_ADDR'" ; fi

        PRIV_SENTRY_NODE_ADDR=""
        if timeout 3 nc -z $NODE_ADDR 36656 ; then
            PRIV_SENTRY_NODE_ID=$(tmconnect id --address="$NODE_ADDR:36656" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo "")
            if $(isNodeId "$PRIV_SENTRY_NODE_ID") ; then
                PRIV_SENTRY_NODE_ADDR="${PRIV_SENTRY_NODE_ID}@${NODE_ADDR}:36656"
                echoInfo "INFO: Private sentry node ID '$PRIV_SENTRY_NODE_ID' was found"
            else echoWarn "WARNING: Private sentry node ID was NOT found" && PRIV_SENTRY_NODE_ADDR="" ; fi
        elif [ -z "$NODE_PORT" ] ; then echoWarn "WARNING: P2P Port 36656 is not exposed by node '$NODE_ADDR'" ; fi

        VALIDATOR_NODE_ADDR=""
        if timeout 3 nc -z $NODE_ADDR 56656 ; then
            VALIDATOR_NODE_ADDR=$(tmconnect id --address="$NODE_ADDR:56656" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo "")
            if $(isNodeId "$VALIDATOR_NODE_ADDR") ; then
                VALIDATOR_NODE_ADDR="${VALIDATOR_NODE_ADDR}@${NODE_ADDR}:56656"
                echoInfo "INFO: Validator node ID '$VALIDATOR_NODE_ADDR' was found"
            else echoWarn "WARNING: Validator node ID was NOT found" && VALIDATOR_NODE_ADDR="" ; fi
        elif [ -z "$NODE_PORT" ] ; then echoWarn "WARNING: P2P Port 56656 is not exposed by node '$NODE_ADDR'" ; fi

        if [ -z "${SEED_NODE_ADDR}${SENTRY_NODE_ADDR}${PRIV_SENTRY_NODE_ADDR}${VALIDATOR_NODE_ADDR}" ] ; then
            echoWarn "WARNING: Service located at '$NODE_ADDR' does NOT have any P2P ports exposed to your node or node id could not be retrieved, choose diffrent public or private node to connect with"
            
            continue
        elif (! $(isPublicIp $NODE_ADDR)) && [ -z "$PRIV_SENTRY_NODE_ADDR" ] ; then
            echoWarn "WARNINIG: Node address '$NODE_ADDR' is a local IP but private sentry port is closed or node Id could not be found, choose diffrent public or private node to connect to"
            continue
        else
            echoInfo "INFO: Success address '$NODE_ADDR' has at least one exposed node"
        fi

        echoInfo "INFO: Please wait, testing snapshot access..."
        SNAP_URL="$NODE_ADDR:$DEFAULT_INTERX_PORT/download/snapshot.zip"
        SNAP_SIZE=$(urlContentLength "$SNAP_URL")
        if ($(urlExists "$SNAP_URL")) && [[ $SNAP_SIZE -gt 0 ]]; then
            set +x
            echoInfo "INFO: Node '$NODE_ADDR' is exposing $SNAP_SIZE Bytes snapshot"
            VSEL="." && while ! [[ "${VSEL,,}" =~ ^(e|l|a|d|c)$ ]]; do echoNErr "Sync from snap [E]xposed by trusted node, [L]ocal direcotry, [A]uto-discover new snap, select [D]iffrent node or [C]ontinue with slow sync: " && read -d'' -s -n1 VSEL && echo ""; done
            set -x
        else
            set +x
            echoWarn "WARNINIG: Node '$NODE_ADDR' is NOT exposing snapshot files! It might take you a VERY long time to sync your node!"
            VSEL="." && while ! [[ "${VSEL,,}" =~ ^(a|l|d|c)$ ]]; do echoNErr "Select snap from [L]ocal direcotry, try snap [A]uto-discovery, choose [D]iffrent node or [C]ontinue with slow sync: " && read -d'' -s -n1 VSEL && echo ""; done
            set -x
        fi

        SNAP_AVAILABLE="false"
        DOWNLOAD_SUCCESS="false"
        rm -fv $TMP_SNAP_PATH
        if [ "${VSEL,,}" == "e" ] ; then
            echoInfo "INFO: Snapshot exposed by $NODE_ADDR peer will be used to bootstrap blockchain state"
            SNAP_AVAILABLE="true"
        elif [ "${VSEL,,}" == "l" ] ; then
            # get all zip files in the snap directory
            SNAPSHOTS=`ls $KIRA_SNAP/*.zip` || SNAPSHOTS=""
            SNAPSHOTS_COUNT=${#SNAPSHOTS[@]}
            SNAP_LATEST_PATH="$KIRA_SNAP_PATH"

            if [[ $SNAPSHOTS_COUNT -le 0 ]] || [ -z "$SNAPSHOTS" ] ; then
              set +x
              echoWarn "WARNING: No snapshots were found in the '$KIRA_SNAP' direcory, state recovery will be aborted"
              echoNErr "Press any key to continue..." && read -n 1 -s && echo ""
              set -x
              continue
            fi
            set +x
            echoErr "Select snapshot to recover from:"

            i=-1
            LAST_SNAP=""
            for s in $SNAPSHOTS ; do
                i=$((i + 1))
                echo "[$i] $s"
                LAST_SNAP=$s
            done

            [ ! -f "$SNAP_LATEST_PATH" ] && SNAP_LATEST_PATH=$LAST_SNAP
            echoInfo "INFO: Latest snapshot: '$SNAP_LATEST_PATH'"

            OPTION=""
            while : ; do
                read -p "Input snapshot number 0-$i (Default: latest): " OPTION
                [ -z "$OPTION" ] && break
                [ "${OPTION,,}" == "latest" ] && break
                ($(isNaturalNumber "$OPTION")) && [[ $OPTION -le $i ]] && break
            done
            set -x

            if [ ! -z "$OPTION" ] && [ "${OPTION,,}" != "latest" ] ; then
                SNAPSHOTS=( $SNAPSHOTS )
                SELECTED_SNAPSHOT=${SNAPSHOTS[$OPTION]}
            else
                OPTION="latest"
                SELECTED_SNAPSHOT=$SNAP_LATEST_PATH
            fi

            mkdir -p "$TMP_SNAP_DIR"
            cp -afv $SELECTED_SNAPSHOT $TMP_SNAP_PATH || echoErr "ERROR: Failed to create snapshot symlink"
            DOWNLOAD_SUCCESS="true"
        elif [ "${VSEL,,}" == "a" ] ; then
            echoInfo "INFO: Downloading peers list & attempting public peers discovery..."
            TMP_PEERS="/tmp/peers.txt" && rm -fv "$TMP_PEERS" 
            $KIRA_MANAGER/scripts/discover-peers.sh "$NODE_ADDR" "$TMP_PEERS" true false 0 || echoErr "ERROR: Peers discovery scan failed"
            SNAP_PEER=$(sed "1q;d" $TMP_PEERS | xargs || echo "")
            if [ ! -z "$SNAP_PEER" ]; then
                echoInfo "INFO: Snapshot peer was found"
                addrArr1=( $(echo $SNAP_PEER | tr "@" "\n") )
                addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
                SNAP_URL="${addrArr2[0],,}:$DEFAULT_INTERX_PORT/download/snapshot.zip"
                SNAP_AVAILABLE="true"
            else
                echoWarn "INFO: No snapshot peers were found"
            fi
        elif [ "${VSEL,,}" == "d" ] ; then
            echoInfo "INFO: Auto-discovery was cancelled, try connecting with diffrent node"
            continue
        else
            echoInfo "INFO: Snapshot was NOT found, download will NOT be attempted"
        fi

        if [ "${SNAP_AVAILABLE,,}" == "true" ] ; then
            echoInfo "INFO: Please wait, downloading snapshot..."
            rm -rfv $TMP_SNAP_DIR
            mkdir -p "$TMP_SNAP_DIR/test"
            DOWNLOAD_SUCCESS="true" && wget "$SNAP_URL" -O $TMP_SNAP_PATH || DOWNLOAD_SUCCESS="false"

            if [ "${DOWNLOAD_SUCCESS,,}" == "false" ] ; then
                set +x
                echoWarn "WARNING: Snapshot download failed or connection with the node is not stable ($SNAP_URL)"
                OPTION="." && while ! [[ "${OPTION,,}" =~ ^(d|c)$ ]] ; do echoNErr "Connect to [D]iffrent node or [C]ontinue without snapshot (slow sync): " && read -d'' -s -n1 OPTION && echo ""; done
                set -x
                if [ "${OPTION,,}" == "d" ] ; then
                    echoInfo "INFO: Operation cancelled after download failed, try connecting with diffrent node"
                    continue
                fi
            fi
        fi
         
        GENSUM="none"
        SNAPSUM="none (slow sync)"
        
        rm -fv $TMP_GENESIS_PATH
         
        if [ "${DOWNLOAD_SUCCESS,,}" == "true" ] ; then
            echoInfo "INFO: Snapshot archive was found, testing integrity..."
            mkdir -p "$TMP_SNAP_DIR/test"
            DATA_GENESIS="$TMP_SNAP_DIR/test/genesis.json"
            SNAP_INFO="$TMP_SNAP_DIR/test/snapinfo.json"
            unzip -p $TMP_SNAP_PATH genesis.json > "$DATA_GENESIS" || echo -n "" > "$DATA_GENESIS"
            unzip -p $TMP_SNAP_PATH snapinfo.json > "$SNAP_INFO" || echo -n "" > "$SNAP_INFO"
                
            SNAP_NETWORK=$(jsonQuickParse "chain_id" $DATA_GENESIS 2> /dev/null || echo -n "")
            SNAP_HEIGHT=$(jsonQuickParse "height" $SNAP_INFO 2> /dev/null || echo -n "")
            (! $(isNaturalNumber "$SNAP_HEIGHT")) && SNAP_HEIGHT=0
    
            if [ ! -f "$DATA_GENESIS" ] || [ ! -f "$SNAP_INFO" ] || [ "$SNAP_NETWORK" != "$CHAIN_ID" ] || [ $SNAP_HEIGHT -le 0 ] || [ $SNAP_HEIGHT -gt $HEIGHT ] ; then
                set +x
                [ ! -f "$DATA_GENESIS" ] && echoErr "ERROR: Data genesis not found ($DATA_GENESIS)"
                [ ! -f "$SNAP_INFO" ] && echoErr "ERROR: Snap info not found ($SNAP_INFO)"
                [ "$SNAP_NETWORK" != "$CHAIN_ID" ] && echoErr "ERROR: Expected chain id '$SNAP_NETWORK' but got '$CHAIN_ID'"
                [[ $SNAP_HEIGHT -le 0 ]] && echoErr "ERROR: Snap height is 0"
                [[ $SNAP_HEIGHT -gt $HEIGHT ]] && echoErr "ERROR: Snap height 0 is greater then latest chain height $HEIGHT"
                set -x
                DOWNLOAD_SUCCESS="false"
            else
                echoInfo "INFO: Success, snapshot file integrity appears to be valid, saving genesis and calculating checksum..."
                cp -afv $DATA_GENESIS $TMP_GENESIS_PATH
                SNAPSUM=$(sha256 "$TMP_SNAP_PATH")
                DOWNLOAD_SUCCESS="true"
            fi
             
            rm -rfv "$TMP_SNAP_DIR/test"
        fi

        if [ "${DOWNLOAD_SUCCESS,,}" == "false" ] ; then
            set +x
            echoErr "ERROR: Snapshot could not be found, file was corrupted or created by outdated node"
            OPTION="." && while ! [[ "${OPTION,,}" =~ ^(d|c)$ ]] ; do echoNErr "Connect to [D]iffrent node, select diffrent file or [C]ontinue without snapshot (slow sync): " && read -d'' -s -n1 OPTION && echo ""; done
            set -x
            rm -rfv $TMP_SNAP_DIR
            if [ "${OPTION,,}" == "d" ] ; then
                echoInfo "INFO: Operation cancelled, try connecting with diffrent node"
                continue
            fi
        fi
             
        if ($(isFileEmpty "$TMP_GENESIS_PATH")) ; then
            echoWarn "INFO: Genesis file was not found, downloading..."
            rm -fv "$TMP_GENESIS_PATH" 
            wget $NODE_ADDR:$DEFAULT_INTERX_PORT/download/genesis.json -O $TMP_GENESIS_PATH || echoWarn "WARNING: Genesis download failed"
            GENESIS_NETWORK=$(jsonQuickParse "chain_id" $TMP_GENESIS_PATH 2> /dev/null || echo -n "")
             
            if [ "$GENESIS_NETWORK" != "$CHAIN_ID" ] ; then
                echoWarn "WARNING: Genesis file served by '$NODE_ADDR' is corrupted, connect to diffrent node"
                continue
            fi
             
            echoInfo "INFO: Genesis file verification suceeded"
        fi
         
        echoInfo "INFO: Calculating genesis checksum..."
        GENSUM=$(sha256 "$TMP_GENESIS_PATH")
         
        if [ "${INFRA_MODE,,}" == "validator" ] ; then
            set +x
            echoInfo "INFO: Validator mode detected, last parameter to setup..."
            echoErr "IMORTANT: To prevent validator from double signing you MUST define a minimum block height below which new blocks will NOT be produced!"
         
            while : ; do
                set +x
                echo "INFO: Default minmum block height is $HEIGHT"
                echoNErr "Input minimum block height or press [ENTER] for (default): " && read MIN_HEIGHT
                [ -z "$MIN_HEIGHT" ] && MIN_HEIGHT=$HEIGHT
                ( (! $(isNaturalNumber "$MIN_HEIGHT")) || [[ $MIN_HEIGHT -lt $HEIGHT ]] ) && echo "INFO: Minimum block height must be greater or equal to $HEIGHT" && continue
                set -x
                break
            done
        else
            MIN_HEIGHT=$HEIGHT
        fi

        set +x
        echo "INFO: Startup configuration was finalized"
        echoNInfo "CONFIG:       Network name (chain-id): " && echoErr $CHAIN_ID
        echoNInfo "CONFIG:               Deployment Mode: " && echoErr $INFRA_MODE
        echoNInfo "CONFIG: Minimum expected block height: " && echoErr $MIN_HEIGHT
        echoNInfo "CONFIG:         Genesis file checksum: " && echoErr $GENSUM
        echoNInfo "CONFIG:        Snapshot file checksum: " && echoErr $SNAPSUM
        echoNInfo "CONFIG:      Public Internet Exposure: " && echoErr $(isPublicIp $NODE_ADDR) 
        [ ! -z "$SEED_NODE_ADDR" ] && \
        echoNInfo "CONFIG:             Seed node address: " && echoErr $SEED_NODE_ADDR
        [ ! -z "$SENTRY_NODE_ADDR" ] && \
        echoNInfo "CONFIG:    Public Sentry node address: " && echoErr $SENTRY_NODE_ADDR
        [ ! -z "$PRIV_SENTRY_NODE_ADDR" ] && \
        echoNInfo "CONFIG:   Private Sentry node address: " && echoErr $PRIV_SENTRY_NODE_ADDR
        [ ! -z "$VALIDATOR_NODE_ADDR" ] && \
        echoNInfo "CONFIG:        Validator node address: " && echoErr $PRIV_SENTRY_NODE_ADDR
        echoNInfo "CONFIG:        New network deployment: " && echoErr $NEW_NETWORK
        echoNInfo "CONFIG:   KIRA Manager git repository: " && echoErr $INFRA_REPO
        echoNInfo "CONFIG:       KIRA Manager git branch: " && echoErr $INFRA_BRANCH
        echoNInfo "CONFIG:              sekai git branch: " && echoErr $SEKAI_BRANCH
        echoNInfo "CONFIG:      KIRA Frontend git branch: " && echoErr $FRONTEND_BRANCH
        echoNInfo "CONFIG:             INTERX git branch: " && echoErr $INTERX_BRANCH
        echoNInfo "CONFIG:     Default Network Interface: " && echoErr $IFACE
        echoNInfo "CONFIG:               Deployment Mode: " && echoErr $DEPLOYMENT_MODE
        OPTION="." && while ! [[ "${OPTION,,}" =~ ^(a|r)$ ]] ; do echoNErr "Choose to [A]pprove or [R]eject configuration: " && read -d'' -s -n1 OPTION && echo ""; done
        set -x

        if [ "${OPTION,,}" == "r" ] ; then
            echoInfo "INFO: Operation cancelled, try connecting with diffrent node"
            continue
        fi

        TRUSTED_NODE_ADDR=$NODE_ADDR
        break
    done
else
    echoErr "ERROR: Unexpected option '$SELECT'"
    exit 1
fi

set -x

if [ "${DOWNLOAD_SUCCESS,,}" == "true" ] ; then
    echo "INFO: Cloning tmp snapshot into snap directory"
    SNAP_FILENAME="${CHAIN_ID}-latest-$(date -u +%s).zip"
    SNAPSHOT="$KIRA_SNAP/$SNAP_FILENAME"
    mv -fv $TMP_SNAP_PATH $SNAPSHOT

    ($(isFileEmpty $SNAPSHOT)) && echoErr "ERROR: Failed to copy snapshot file from temp directory '$TMP_SNAP_PATH' to destination '$SNAPSHOT'"
else
    SNAPSHOT=""
fi

rm -fvr "$KIRA_SNAP/status"
chattr -i "$LOCAL_GENESIS_PATH" || echoWarn "Genesis file was NOT found in the local direcotry"
rm -fv "$LOCAL_GENESIS_PATH" "$TMP_SNAP_PATH"

if [ -f "$TMP_GENESIS_PATH" ] ; then
    echoInfo "INFO: New genesis found, replacing"
    cp -vaf "$TMP_GENESIS_PATH" "$LOCAL_GENESIS_PATH"
    rm -fv "$TMP_GENESIS_PATH"
fi

# Make sure genesis already exists if joining exisitng network was initiated
if [ "${NEW_NETWORK,,}" == "false" ] && [ ! -f "$LOCAL_GENESIS_PATH" ] ; then
    echoErr "ERROR: Genesis file is missing despite attempt to join existing network"
    exit 1
fi

rm -rfv $TMP_SNAP_DIR
NETWORK_NAME=$CHAIN_ID
CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$SNAPSHOT\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
globSet MIN_HEIGHT $MIN_HEIGHT
CDHelper text lineswap --insert="NETWORK_NAME=\"$CHAIN_ID\"" --prefix="NETWORK_NAME=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="TRUSTED_NODE_ADDR=\"$NODE_ADDR\"" --prefix="TRUSTED_NODE_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True

rm -fv "$PUBLIC_PEERS" "$PRIVATE_PEERS" "$PUBLIC_SEEDS" "$PRIVATE_SEEDS"
touch "$PUBLIC_SEEDS" "$PRIVATE_SEEDS" "$PUBLIC_PEERS" "$PRIVATE_PEERS"

set +x
OPTION="." && while ! [[ "${OPTION,,}" =~ ^(a|m)$ ]] ; do echoNErr "Choose to [A]utomatically discover external seeds or [M]anually configure public and private connections: " && read -d'' -s -n1 OPTION && echo ""; done
set -x

if ($(isPublicIp $NODE_ADDR)) ; then
    ( $(isNaturalNumber $(tmconnect handshake --address="$SEED_NODE_ADDR" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo ""))) && \
        echo "$SEED_NODE_ADDR" >> $PUBLIC_SEEDS
    ( $(isNaturalNumber $(tmconnect handshake --address="$SENTRY_NODE_ADDR" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo ""))) && \
        echo "$SENTRY_NODE_ADDR" >> $PUBLIC_SEEDS
    ( $(isNaturalNumber $(tmconnect handshake --address="$PRIV_SENTRY_NODE_ADDR" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo ""))) && \
        echo "$PRIV_SENTRY_NODE_ADDR" >> $PUBLIC_SEEDS
    ( $(isNaturalNumber $(tmconnect handshake --address="$VALIDATOR_NODE_ADDR" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo ""))) && \
        echo "$VALIDATOR_NODE_ADDR" >> $PUBLIC_SEEDS
else
    echoInfo "INFO: Node address '$NODE_ADDR' is a local IP address, private peers will be added..."
    ( $(isNaturalNumber $(tmconnect handshake --address="$PRIV_SENTRY_NODE_ADDR" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo ""))) && \
        echo "$PRIV_SENTRY_NODE_ADDR" >> $PRIVATE_SEEDS
fi

if [ "${OPTION,,}" == "a" ] ; then
    echoInfo "INFO: Downloading peers list & attempting public peers discovery..."
    TMP_PEERS="/tmp/peers.txt" && rm -fv "$TMP_PEERS" 
    $KIRA_MANAGER/scripts/discover-peers.sh "$NODE_ADDR" "$TMP_PEERS" false false 1024 || echoErr "ERROR: Peers discovery scan failed"
    if (! $(isFileEmpty "$TMP_PEERS")) ; then
        echoInfo "INFO: Saving extra peers..."
        cat $TMP_PEERS >> $PUBLIC_SEEDS
    else
        echoInfo "INFO: No extra public peers were found!"
    fi
else
    $KIRA_MANAGER/menu/seeds-select.sh
fi

if [ "${NEW_NETWORK,,}" != "true" ] && ($(isFileEmpty "$PUBLIC_SEEDS")) && ($(isFileEmpty "$PRIVATE_SEEDS")) && ($(isFileEmpty "$PUBLIC_PEERS")) && ($(isFileEmpty "$PRIVATE_PEERS")) ; then 
    echoErr "ERROR: No public or private seeds were found"
    exit 1
fi

echoInfo "INFO: Finished quick select!"