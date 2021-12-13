#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/menu/quick-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

mkdir -p "$KIRA_CONFIGS"
TMP_GENESIS_PATH="/tmp/genesis.json"
TMP_SNAP_DIR="$KIRA_SNAP/tmp"
TMP_SNAP_PATH="$TMP_SNAP_DIR/tmp-snap.zip"
MIN_HEIGHT="0"

rm -fv "$TMP_GENESIS_PATH" "$TMP_SNAP_PATH"

if [ "${NEW_NETWORK,,}" == "true" ]; then
    rm -fv "$PUBLIC_PEERS" "$PUBLIC_SEEDS"
    REINITALIZE_NODE="flase"
    CHAIN_ID="$NETWORK_NAME"
    SEED_NODE_ADDR="" && SENTRY_NODE_ADDR=""
    GENSUM=""
    SNAPSUM=""
    DOWNLOAD_SUCCESS="false"
    TRUSTED_NODE_ADDR="0.0.0.0"
    SNAPSHOT=""

    set +x
    echo "INFO: Startup configuration of the NEW network was finalized"
    echoNInfo "CONFIG:       Network name (chain-id): " && echoErr $CHAIN_ID
    echoNInfo "CONFIG:               Deployment Mode: " && echoErr $INFRA_MODE
    echoNInfo "CONFIG: Minimum expected block height: " && echoErr $MIN_HEIGHT
    echoNInfo "CONFIG:        New network deployment: " && echoErr $NEW_NETWORK
    echoNInfo "CONFIG:   KIRA Manager git repository: " && echoErr $INFRA_REPO
    echoNInfo "CONFIG:       KIRA Manager git branch: " && echoErr $INFRA_BRANCH
    echoNInfo "CONFIG:              sekai git branch: " && echoErr $SEKAI_BRANCH
    echoNInfo "CONFIG:             INTERX git branch: " && echoErr $INTERX_BRANCH
    echoNInfo "CONFIG:     Default Network Interface: " && echoErr $IFACE
    
    OPTION="." && while ! [[ "${OPTION,,}" =~ ^(a|r)$ ]] ; do echoNErr "Choose to [A]pprove or [R]eject configuration: " && read -d'' -s -n1 OPTION && echo ""; done
    set -x

    globSet MIN_HEIGHT "$MIN_HEIGHT"
    globSet LATEST_BLOCK_HEIGHT "$MIN_HEIGHT"
    globSet LATEST_BLOCK_TIME "0"

    globSet MIN_HEIGHT "$MIN_HEIGHT" $GLOBAL_COMMON_RO
    globSet LATEST_BLOCK_HEIGHT "$MIN_HEIGHT" $GLOBAL_COMMON_RO
    globSet LATEST_BLOCK_TIME "0" $GLOBAL_COMMON_RO

    if [ "${OPTION,,}" == "r" ] ; then
        echoInfo "INFO: Operation cancelled, try diffrent setup option"
        source $KIRA_MANAGER/submenu.sh
        exit 0
    fi
elif [ "${NEW_NETWORK,,}" == "false" ] ; then
    while : ; do
        MIN_HEIGHT="0"
        if [ ! -z "$TRUSTED_NODE_ADDR" ] ; then 
            set +x
            echoInfo "INFO: Previously trusted node address (default): $TRUSTED_NODE_ADDR"
            echoInfo "INFO: To reinitalize already existing node type: 0.0.0.0"
            echoNErr "Input address (IP/DNS) of the public node you trust or choose [ENTER] for default: " && read v1 && v1=$(echo "$v1" | xargs)
            set -x
            [ -z "$v1" ] && v1=$TRUSTED_NODE_ADDR || v1=$(resolveDNS "$v1")
        else
            set +x
            echoInfo "INFO: To reinitalize already existing node type: 0.0.0.0"
            echoNErr "Input address (IP/DNS) of the public node you trust: " && read v1
            set -x
        fi

        ($(isDnsOrIp "$v1")) && NODE_ADDR="$v1" || NODE_ADDR="" 
        [ -z "$NODE_ADDR" ] && echoWarn "WARNING: Value '$v1' is not a valid DNS name or IP address, try again!" && continue
        [ "$NODE_ADDR" == "0.0.0.0" ] && REINITALIZE_NODE="true" || REINITALIZE_NODE="false"
        
        echoInfo "INFO: Please wait, testing connectivity..."
        if ! timeout 2 ping -c1 "$NODE_ADDR" &>/dev/null ; then
            echoWarn "WARNING: Address '$NODE_ADDR' could NOT be reached, check your network connection or select diffrent node" 
            continue
        else
            echoInfo "INFO: Success, node '$NODE_ADDR' is online!"
        fi

        STATUS=$(timeout 15 curl "$NODE_ADDR:$DEFAULT_INTERX_PORT/api/kira/status" 2>/dev/null | jsonParse "" 2>/dev/null || echo -n "")
        CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null|| echo -n "") && ($(isNullOrWhitespaces "$CHAIN_ID")) && STATUS=""

        ($(isNullOrWhitespaces "$STATUS")) && STATUS=$(timeout 15 curl --fail "$NODE_ADDR:$KIRA_SEED_RPC_PORT/status" 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")
        CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null|| echo -n "") && ($(isNullOrWhitespaces "$CHAIN_ID")) && STATUS=""

        ($(isNullOrWhitespaces "$STATUS")) && STATUS=$(timeout 15 curl --fail "$NODE_ADDR:$KIRA_VALIDATOR_RPC_PORT/status" 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")
        CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null|| echo -n "") && ($(isNullOrWhitespaces "$CHAIN_ID")) && STATUS=""

        ($(isNullOrWhitespaces "$STATUS")) && STATUS=$(timeout 15 curl --fail "$NODE_ADDR:$KIRA_SENTRY_RPC_PORT/status" 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")

        HEIGHT=$(echo "$STATUS" | jsonQuickParse "latest_block_height" 2> /dev/null || echo -n "")
        CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null|| echo -n "")

        if [ "${REINITALIZE_NODE,,}" == "true" ] && ( ($(isNullOrWhitespaces "$CHAIN_ID")) || (! $(isNaturalNumber "$HEIGHT")) ) ; then
            HEIGHT=$(globGet LATEST_BLOCK_HEIGHT) && (! $(isNaturalNumber "$HEIGHT")) && HEIGHT="0"
            CHAIN_ID=$NETWORK_NAME && ($(isNullOrWhitespaces "$NETWORK_NAME")) && NETWORK_NAME="unknown"
        fi

        if ($(isNullOrWhitespaces "$CHAIN_ID")) || (! $(isNaturalNumber "$HEIGHT")) ; then
            echoWarn "WARNING: Could NOT read status, block height or chian-id"
            echoErr "ERROR: Address '$NODE_ADDR' is NOT a valid, publicly exposed public node address"
            continue
        fi

        echoInfo "INFO: Please wait, testing snapshot access..."
        SNAP_URL="$NODE_ADDR:$DEFAULT_INTERX_PORT/download/snapshot.zip"
        if ($(urlExists "$SNAP_URL")) ; then
            SNAP_SIZE=$(urlContentLength "$SNAP_URL") && (! $(isNaturalNumber $SNAP_SIZE)) && SNAP_SIZE=0
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
              echoNErr "Press any key to continue..." && pressToContinue
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
                echoNErr "Connect to [D]iffrent node or [C]ontinue without snapshot (slow sync): " && pressToContinue d c && OPTION=($(globGet OPTION))
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
    
            if [ ! -f "$DATA_GENESIS" ] || [ ! -f "$SNAP_INFO" ] || [ "$SNAP_NETWORK" != "$CHAIN_ID" ] || [ $SNAP_HEIGHT -le 0 ] ; then
                set +x
                [ ! -f "$DATA_GENESIS" ] && echoErr "ERROR: Data genesis not found ($DATA_GENESIS)"
                [ ! -f "$SNAP_INFO" ] && echoErr "ERROR: Snap info not found ($SNAP_INFO)"
                [ "$SNAP_NETWORK" != "$CHAIN_ID" ] && echoErr "ERROR: Expected chain id '$SNAP_NETWORK' but got '$CHAIN_ID'" && [ "${REINITALIZE_NODE,,}" == "true" ] && CHAIN_ID="$SNAP_NETWORK" 
                [[ $SNAP_HEIGHT -le 0 ]] && echoErr "ERROR: Snap height is 0"
                [[ $SNAP_HEIGHT -gt $HEIGHT ]] && HEIGHT=$SNAP_HEIGHT
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
            while : ; do
                GENESIS_SOURCE="$NODE_ADDR:$DEFAULT_INTERX_PORT/api/genesis"
                set +x
                echoWarn "WARNING: Genesis file was NOT found!"
                echoInfo "INFO: Default genesis source file: $GENESIS_SOURCE"
                echoNErr "Input URL to external genesis file, local PATH or press [ENTER] for default: " && read g1 && g1=$(echo "$g1" | xargs)
                set -x

                (! $(isNullOrWhitespaces "$g1")) && GENESIS_SOURCE="$g1"
                rm -fv "$TMP_GENESIS_PATH" 

                if (! $(isFileEmpty "$GENESIS_SOURCE")) ; then
                    cp -afv $GENESIS_SOURCE $TMP_GENESIS_PATH || echoErr "ERROR: Genesis copy from local PATH failed"
                else
                    wget -v $GENESIS_SOURCE -O $TMP_GENESIS_PATH || echoErr "ERROR: Genesis download from external URL failed"
                fi

                GENESIS_NETWORK=$(jsonParse "chain_id" $TMP_GENESIS_PATH 2> /dev/null || echo -n "")
                GENESIS_TIME=$(date2unix $(jsonParse "genesis_time" $TMP_GENESIS_PATH 2> /dev/null || echo -n ""))
                GENESIS_HEIGHT=$(jsonParse "initial_height" $TMP_GENESIS_PATH 2> /dev/null || echo -n "")
                
                if ($(isNullOrWhitespaces "$GENESIS_NETWORK")) || (! $(isNaturalNumber "$GENESIS_TIME")) || (! $(isNaturalNumber "$GENESIS_HEIGHT")) ; then
                    echoWarn "WARNING: Genesis file served by '$NODE_ADDR' is corrupted, connect to diffrent node"
                    continue
                fi

                if [ "$GENESIS_NETWORK" != "$CHAIN_ID" ] ; then
                    set +x
                    echoNErr "Expected chain ID to be '$CHAIN_ID' but got '$GENESIS_NETWORK', do you want to [T]ry again or [C]hange chain id to '$GENESIS_NETWORK' and continue?" && pressToContinue t c && OPTION=($(globGet OPTION))
                    [ "${OPTION,,}" == "t" ] && continue
                    set -x
                    CHAIN_ID=$GENESIS_NETWORK
                fi

                [[ $HEIGHT -lt $GENESIS_HEIGHT ]] && HEIGHT=$GENESIS_HEIGHT
                echoInfo "INFO: Genesis file verification suceeded"
                break
            done
        fi
         
        echoInfo "INFO: Calculating genesis checksum..."
        GENSUM=$(sha256 "$TMP_GENESIS_PATH")

        set +x
        echoErr "IMORTANT: To prevent node from double signing and creating snapshot while syncing you MUST define a minimum block height below which new blocks will NOT be produced!"
         
        NEW_MIN_HEIGHT="0"
        while : ; do
            TMP_MIN_HEIGHT=""
            echo "INFO: Default minmum block height is $HEIGHT"
            echoNErr "Input minimum block height or press [ENTER] for (default): " && read TMP_MIN_HEIGHT && [ -z "$TMP_MIN_HEIGHT" ] && TMP_MIN_HEIGHT=$HEIGHT
            (! $(isNaturalNumber "$TMP_MIN_HEIGHT")) && TMP_MIN_HEIGHT=0
            [[ $TMP_MIN_HEIGHT -lt $HEIGHT ]] && echo "INFO: Minimum block height must be greater or equal to $HEIGHT, but was $TMP_MIN_HEIGHT" && continue
            NEW_MIN_HEIGHT="$TMP_MIN_HEIGHT" && break
        done

        ($(isNaturalNumber "$NEW_MIN_HEIGHT")) && MIN_HEIGHT=$NEW_MIN_HEIGHT

        set +x
        echo "INFO: Startup configuration was finalized"
        echoNInfo "CONFIG:       Network name (chain-id): " && echoErr $CHAIN_ID
        echoNInfo "CONFIG:               Deployment Mode: " && echoErr $INFRA_MODE
        echoNInfo "CONFIG: Minimum expected block height: " && echoErr $MIN_HEIGHT
        echoNInfo "CONFIG:         Genesis file checksum: " && echoErr $GENSUM
        echoNInfo "CONFIG:        Snapshot file checksum: " && echoErr $SNAPSUM
        echoNInfo "CONFIG:          Trusted Node Address: " && echoErr $NODE_ADDR 
        echoNInfo "CONFIG:        New network deployment: " && echoErr $NEW_NETWORK
        echoNInfo "CONFIG:   KIRA Manager git repository: " && echoErr $INFRA_REPO
        echoNInfo "CONFIG:       KIRA Manager git branch: " && echoErr $INFRA_BRANCH
        echoNInfo "CONFIG:              sekai git branch: " && echoErr $SEKAI_BRANCH
        echoNInfo "CONFIG:             INTERX git branch: " && echoErr $INTERX_BRANCH
        echoNInfo "CONFIG:     Default Network Interface: " && echoErr $IFACE
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

rm -fv $KIRA_SNAP/*.zip || echoErr "ERROR: Failed to wipe *.zip file from '$KIRA_SNAP' directory"
rm -fv $KIRA_SNAP/zi* || echoErr "ERROR: Failed to wipe zi* files from '$KIRA_SNAP' directory"

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
[ ! -z "$SNAPSHOT" ] && \
    CDHelper text lineswap --insert="KIRA_SNAP_SHA256=\"$SNAPSUM\"" --prefix="KIRA_SNAP_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True

NEW_BLOCK_TIME=$(date2unix $(jsonParse "genesis_time" $LOCAL_GENESIS_PATH 2> /dev/null || echo -n ""))

globSet MIN_HEIGHT "$MIN_HEIGHT"
globSet LATEST_BLOCK_HEIGHT "$MIN_HEIGHT"
globSet LATEST_BLOCK_TIME $NEW_BLOCK_TIME

globSet MIN_HEIGHT "$MIN_HEIGHT" $GLOBAL_COMMON_RO
globSet LATEST_BLOCK_HEIGHT "$MIN_HEIGHT" $GLOBAL_COMMON_RO
globSet LATEST_BLOCK_TIME "$NEW_BLOCK_TIME" $GLOBAL_COMMON_RO

CDHelper text lineswap --insert="NETWORK_NAME=\"$CHAIN_ID\"" --prefix="NETWORK_NAME=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="TRUSTED_NODE_ADDR=\"$NODE_ADDR\"" --prefix="TRUSTED_NODE_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="INTERX_SNAP_SHA256=\"\"" --prefix="INTERX_SNAP_SHA256=" --path=$ETC_PROFILE --append-if-found-not=True

globSet GENESIS_SHA256 "$GENSUM"

if [ "${NEW_NETWORK,,}" != "true" ] && [ "${REINITALIZE_NODE,,}" == "false" ] ; then
    rm -fv "$PUBLIC_PEERS" "$PUBLIC_SEEDS"
    touch "$PUBLIC_SEEDS" "$PUBLIC_PEERS"

    while : ; do
        set +x
        OPTION="." && while ! [[ "${OPTION,,}" =~ ^(a|m)$ ]] ; do echoNErr "Choose to [A]utomatically discover external seeds or [M]anually configure public and private connections: " && read -d'' -s -n1 OPTION && echo ""; done
        set -x

        SEED_NODE_ID=$(tmconnect id --address="$NODE_ADDR:16656" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo "")
        ($(isNodeId "$SEED_NODE_ID")) && SEED_NODE_ADDR="${SEED_NODE_ID}@${NODE_ADDR}:16656" || SEED_NODE_ADDR=""
        SENTRY_NODE_ID=$(tmconnect id --address="$NODE_ADDR:26656" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo "")
        ($(isNodeId "$SENTRY_NODE_ID")) && SENTRY_NODE_ADDR="${SENTRY_NODE_ID}@${NODE_ADDR}:26656" || SENTRY_NODE_ID=""
        VALIDATOR_NODE_ID=$(tmconnect id --address="$NODE_ADDR:36656" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo "")
        ($(isNodeId "$VALIDATOR_NODE_ID")) && VALIDATOR_NODE_ADDR="${VALIDATOR_NODE_ID}@${NODE_ADDR}:36656" || VALIDATOR_NODE_ADDR=""

        [ ! -z "$SEED_NODE_ADDR" ] && echo "$SEED_NODE_ADDR" >> $PUBLIC_SEEDS
        [ ! -z "$SENTRY_NODE_ADDR" ] && echo "$SENTRY_NODE_ADDR" >> $PUBLIC_SEEDS
        [ ! -z "$VALIDATOR_NODE_ADDR" ] && echo "$VALIDATOR_NODE_ADDR" >> $PUBLIC_SEEDS

        if [ "${OPTION,,}" == "a" ] ; then
            echoInfo "INFO: Downloading peers list & attempting public peers discovery..."
            TMP_PEERS="/tmp/peers.txt" && rm -fv "$TMP_PEERS" 
            $KIRA_MANAGER/scripts/discover-peers.sh "$NODE_ADDR" "$TMP_PEERS" false false 1024 || echoErr "ERROR: Peers discovery scan failed"
            if (! $(isFileEmpty "$TMP_PEERS")) ; then
                echoInfo "INFO: Saving extra peers..."
                cat $TMP_PEERS >> $PUBLIC_SEEDS
            else
                echoInfo "INFO: No extra public peers were found!"
                continue
            fi
        else
            $KIRA_MANAGER/menu/seeds-select.sh
        fi

        if ($(isFileEmpty "$PUBLIC_SEEDS")) && ($(isFileEmpty "$PUBLIC_PEERS")) ; then 
            echoErr "ERROR: You are attempting to join existing network but no seeds or peers were configured!"
        else
            break
        fi
    done
else
    touch "$PUBLIC_SEEDS" "$PUBLIC_PEERS"
fi

echoInfo "INFO: Finished quick select!"