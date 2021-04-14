#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/menu/chain-id-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

mkdir -p "$KIRA_CONFIGS"
TMP_GENESIS_PATH="/tmp/genesis.json"
TMP_SNAP_DIR="$KIRA_SNAP/tmp"
TMP_SNAP_PATH="$TMP_SNAP_DIR/tmp-snap.zip"

rm -fv "$TMP_GENESIS_PATH"

if [ "${INFRA_MODE,,}" == "sentry" ]; then
    SELECT="j"
else
    set +x
    SELECT="." && while ! [[ "${SELECT,,}" =~ ^(n|j)$ ]]; do echoNErr "Create [N]ew network or [J]oin existing one: " && read -d'' -s -n1 SELECT && echo ""; done
    set -x
fi

if [ "${SELECT,,}" == "n" ]; then
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
    NEW_NETWORK="true"
    TRUSTED_NODE_ADDR="0.0.0.0"
    SNAPSHOT=""
    VALIDATOR_MIN_HEIGHT="0"

    set +x
    echo "INFO: Startup configuration of the NEW network was finalized"
    echoNInfo "CONFIG:       Network name (chain-id): " && echoErr $CHAIN_ID
    echoNInfo "CONFIG:               Deployment Mode: " && echoErr $INFRA_MODE
    echoNInfo "CONFIG: Minimum expected block height: " && echoErr $VALIDATOR_MIN_HEIGHT
    echoNInfo "CONFIG:        New network deployment: " && echoErr $NEW_NETWORK
    echoNInfo "CONFIG:   KIRA Manager git repository: " && echoErr $INFRA_REPO
    echoNInfo "CONFIG:       KIRA Manager git branch: " && echoErr $INFRA_BRANCH
    echoNInfo "CONFIG:              sekai git branch: " && echoErr $SEKAI_BRANCH
    echoNInfo "CONFIG:      KIRA Frontend git branch: " && echoErr $FRONTEND_BRANCH
    echoNInfo "CONFIG:             INTERX git branch: " && echoErr $INTERX_BRANCH
    echoNInfo "CONFIG:     Default Network Interface: " && echoErr $IFACE
    
    OPTION="." && while ! [[ "${OPTION,,}" =~ ^(a|r)$ ]] ; do echoNErr "Choose to [A]pprove or [R]eject configuration: " && read -d'' -s -n1 OPTION && echo ""; done
    set -x

    if [ "${OPTION,,}" == "r" ] ; then
        echoInfo "INFO: Operation cancelled, try diffrent setup option"
        $KIRA_MANAGER/menu/chain-id-select.sh
        exit 0
    fi
elif [ "${SELECT,,}" == "j" ] ; then
    NEW_NETWORK="false"
    VALIDATOR_MIN_HEIGHT="0"
    while : ; do
        if [ ! -z "$TRUSTED_NODE_ADDR" ] && [ "$TRUSTED_NODE_ADDR" != "0.0.0.0" ] ; then 
            set +x
            echo "INFO: Previously trusted node address (default): $TRUSTED_NODE_ADDR"
            echoNErr "Input address (IP/DNS) of the public node you trust or choose [ENTER] for default: " && read v1 && v1=$(echo "$v1" | xargs)
            set -x
            [ -z "$v1" ] && v1=$TRUSTED_NODE_ADDR
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
        NODE_ID=$(echo "$STATUS" | jsonQuickParse "id" 2> /dev/null || echo -n "")

        if [ -z "$STATUS" ] || [ -z "${CHAIN_ID}" ] || [ -z "${NODE_ID}" ] || [ "${STATUS,,}" == "null" ] || [ "${CHAIN_ID,,}" == "null" ] || [ "${NODE_ID,,}" == "null" ] || [ -z "${HEIGHT##*[!0-9]*}" ] ; then
            echo "INFO: Could NOT read status, block height, chian-id or node-id"
            echoWarn "WARNING: Address '$NODE_ADDR' is not a valid, publicly exposed public node address"
            continue
        fi

        SEED_NODE_ADDR=""
        if timeout 3 nc -z $NODE_ADDR 16656 ; then
            SEED_NODE_ID=$(timeout 3 curl -f "$NODE_ADDR:$DEFAULT_INTERX_PORT/download/seed_node_id" || echo -n "")
            if $(isNodeId "$SEED_NODE_ID") ; then
                SEED_NODE_ADDR="${SEED_NODE_ID}@${NODE_ADDR}:16656"
                echoInfo "INFO: Seed node ID '$SEED_NODE_ID' was found"
            else echoWarn "WARNING: Seed node ID was NOT found" && SEED_NODE_ADDR="" ; fi
        else echoWarn "WARNING: P2P Port 16656 is not exposed by node '$NODE_ADDR'" ; fi

        SENTRY_NODE_ADDR=""
        if timeout 3 nc -z $NODE_ADDR 26656 ; then
            SENTRY_NODE_ID=$NODE_ID
            if $(isNodeId "$NODE_ID") ; then
                SENTRY_NODE_ADDR="${NODE_ID}@${NODE_ADDR}:26656"
                echoInfo "INFO: Sentry node ID '$NODE_ID' was found"
            else echoWarn "WARNING: Sentry node ID was NOT found" && SENTRY_NODE_ADDR="" ; fi
        elif [ -z "$NODE_PORT" ] ; then echoWarn "WARNING: P2P Port 26656 is not exposed by node '$NODE_ADDR'" ; fi

        PRIV_SENTRY_NODE_ADDR=""
        if timeout 3 nc -z $NODE_ADDR 36656 ; then
            PRIV_SENTRY_NODE_ID=$(timeout 3 curl -f "$NODE_ADDR:$DEFAULT_INTERX_PORT/download/priv_sentry_node_id" || echo -n "")
            if $(isNodeId "$PRIV_SENTRY_NODE_ID") ; then
                PRIV_SENTRY_NODE_ADDR="${PRIV_SENTRY_NODE_ID}@${NODE_ADDR}:36656"
                echoInfo "INFO: Private sentry node ID '$PRIV_SENTRY_NODE_ID' was found"
            else echoWarn "WARNING: Private sentry node ID was NOT found" && PRIV_SENTRY_NODE_ADDR="" ; fi
        elif [ -z "$NODE_PORT" ] ; then echoWarn "WARNING: P2P Port 36656 is not exposed by node '$NODE_ADDR'" ; fi
        
        if [ -z "${SEED_NODE_ADDR}${SENTRY_NODE_ADDR}${PRIV_SENTRY_NODE_ADDR}" ] ; then
            echoWarn "WARNING: Service located at '$NODE_ADDR' does NOT have any P2P ports exposed to your node or node id could not be retrieved, choose diffrent public or private node to connect to"
            continue
        elif (! $(isPublicIp $NODE_ADDR)) && [ -z "$PRIV_SENTRY_NODE_ADDR" ] ; then
            echoWarn "WARNINIG: Node address '$NODE_ADDR' is a local IP but private sentry port is closed or node Id could not be found, choose diffrent public or private node to connect to"
            continue
        else
            echoInfo "INFO: Success address '$NODE_ADDR' has at least one exposed node"
        fi

        echoInfo "INFO: Please wait, testing snapshot access..."
        SNAP_URL="$NODE_ADDR:$DEFAULT_INTERX_PORT/download/snapshot.zip"
        if ($(urlExists "$SNAP_URL")) ; then
            echoInfo "INFO: Snapshot was found, download will be attempted shortly"
            SNAP_AVAILABLE="true"
        else
            echoInfo "INFO: Snapshot was NOT found, download will NOT be attempted"
            SNAP_AVAILABLE="false"
        fi

        DOWNLOAD_SUCCESS="false"
        if [ "${SNAP_AVAILABLE,,}" == "true" ] ; then
            echoInfo "INFO: Please wait, downloading snapshot..."
            DOWNLOAD_SUCCESS="true"

            rm -f -v -r $TMP_SNAP_DIR
            mkdir -p "$TMP_SNAP_DIR" "$TMP_SNAP_DIR/test"
            wget "$SNAP_URL" -O $TMP_SNAP_PATH || DOWNLOAD_SUCCESS="false"

            if [ "${DOWNLOAD_SUCCESS,,}" == "false" ] ; then
                set +x
                echoWarn "WARNING: Snapshot download failed or connection with the node '$NODE_ADDR' is not stable"
                OPTION="." && while ! [[ "${OPTION,,}" =~ ^(d|c)$ ]] ; do echoNErr "Connect to [D]iffrent node or [C]ontinue without snapshot (slow sync): " && read -d'' -s -n1 OPTION && echo ""; done
                set -x
                if [ "${OPTION,,}" == "d" ] ; then
                    echoInfo "INFO: Operation cancelled after download failed, try connecting with diffrent node"
                    continue
                fi
                DOWNLOAD_SUCCESS="false"
            fi
        else
            set +x
            echoWarn "WARNING: Snapshot is NOT available, node '$NODE_ADDR' is not exposing it publicly"
            OPTION="." && while ! [[ "${OPTION,,}" =~ ^(d|c)$ ]] ; do echoNErr "Connect to [D]iffrent node or [C]ontinue without snapshot (slow sync): " && read -d'' -s -n1 OPTION && echo ""; done
            set -x
            if [ "${OPTION,,}" == "d" ] ; then
                echoInfo "INFO: Operation cancelled, try connecting with diffrent node"
                continue
            fi
            DOWNLOAD_SUCCESS="false"
        fi
         
        GENSUM="none"
        SNAPSUM="none (slow sync)"
        rm -fv $TMP_GENESIS_PATH
         
        if [ "${DOWNLOAD_SUCCESS,,}" == "true" ] ; then
            echoInfo "INFO: Snapshot archive download was sucessfull"
            UNZIP_FAILED="false"
            unzip $TMP_SNAP_PATH -d "$TMP_SNAP_DIR/test" || UNZIP_FAILED="true"
            [ "${UNZIP_FAILED,,}" == "false" ] && zip -T -v $TMP_SNAP_PATH || UNZIP_FAILED="true"

            if [ "${UNZIP_FAILED,,}" == "false" ] ; then
                DATA_GENESIS="$TMP_SNAP_DIR/test/genesis.json"
                SNAP_INFO="$TMP_SNAP_DIR/test/snapinfo.json"
                SNAP_NETWORK=$(jsonQuickParse "chain_id" $DATA_GENESIS 2> /dev/null || echo -n "")
                SNAP_HEIGHT=$(jsonQuickParse "height" $SNAP_INFO 2> /dev/null || echo -n "")
                (! $(isNaturalNumber "$SNAP_HEIGHT")) && SNAP_HEIGHT=0
    
                if [ ! -f "$DATA_GENESIS" ] || [ ! -f "$SNAP_INFO" ] || [ "$SNAP_NETWORK" != "$CHAIN_ID" ] || [ $SNAP_HEIGHT -le 0 ] || [ $SNAP_HEIGHT -gt $HEIGHT ] ; then
                    echoWarn "WARNING: Snapshot is corrupted or created by outdated node"
                    [ ! -f "$DATA_GENESIS" ] && echoErr "ERROR: Data genesis not found ($DATA_GENESIS)"
                    [ ! -f "$SNAP_INFO" ] && echoErr "ERROR: Snap info not found ($SNAP_INFO)"
                    [ "$SNAP_NETWORK" != "$CHAIN_ID" ] && echoErr "ERROR: Expected chain id '$SNAP_NETWORK' but got '$CHAIN_ID'"
                    [ $SNAP_HEIGHT -le 0 ] && echoErr "ERROR: Snap height is 0"
                    [ $SNAP_HEIGHT -gt $HEIGHT ] && echoErr "ERROR: Snap height 0 is greater then latest chain height $HEIGHT"
                    OPTION="." && while ! [[ "${OPTION,,}" =~ ^(d|c)$ ]] ; do echoNErr "Connect to [D]iffrent node or [C]ontinue without snapshot (slow sync): " && read -d'' -s -n1 OPTION && echo ""; done
                    rm -f -v -r $TMP_SNAP_DIR
                    if [ "${OPTION,,}" == "d" ] ; then
                        echoInfo "INFO: Operation cancelled, try connecting with diffrent node"
                        continue
                    fi
                    DOWNLOAD_SUCCESS="false"
                else
                    echoInfo "INFO: Success, snapshot file integrity appears to be valid"
                    cp -f -v -a $DATA_GENESIS $TMP_GENESIS_PATH
                    SNAPSUM=$(sha256sum "$TMP_SNAP_PATH" | awk '{ print $1 }' || echo -n "")
                fi
                 
                rm -f -v -r "$TMP_SNAP_DIR/test"
            else
                echo "INFO: Unzip failed, archive might be corruped"
            fi
        fi
             
        if ($(isFileEmpty "$TMP_GENESIS_PATH")) ; then
            echoWarn "INFO: Genesis file was not found, downloading..."
            rm -fv "$TMP_GENESIS_PATH" "$TMP_GENESIS_PATH.tmp"
            wget "$NODE_ADDR:$DEFAULT_RPC_PORT/genesis" -O $TMP_GENESIS_PATH || echo "WARNING: Genesis download failed"
            jq -r .result.genesis $TMP_GENESIS_PATH > "$TMP_GENESIS_PATH.tmp" || echo "WARNING: Genesis extraction from response failed"
            cp -a -f -v "$TMP_GENESIS_PATH.tmp" "$TMP_GENESIS_PATH" || echo "WARNING: Genesis copy failed"
            GENESIS_NETWORK=$(jsonQuickParse "chain_id" $TMP_GENESIS_PATH 2> /dev/null || echo -n "")
             
            if [ "$GENESIS_NETWORK" != "$CHAIN_ID" ] ; then
                rm -fv "$TMP_GENESIS_PATH" "$TMP_GENESIS_PATH.tmp"
                wget "$NODE_ADDR:$DEFAULT_INTERX_PORT/api/genesis" -O $TMP_GENESIS_PATH || echo "WARNING: Genesis download failed"
                GENESIS_NETWORK=$(jsonQuickParse "chain_id" $TMP_GENESIS_PATH 2> /dev/null || echo -n "")
            fi
             
            if [ "$GENESIS_NETWORK" != "$CHAIN_ID" ] ; then
                echoWarning "WARNING: Genesis file served by '$NODE_ADDR' is corrupted, connect to diffrent node"
                continue
            fi
             
            echoInfo "INFO: Genesis file verification suceeded"
        fi
         
        GENSUM=$(sha256sum "$TMP_GENESIS_PATH" | awk '{ print $1 }' || echo -n "")
         
        if [ "${INFRA_MODE,,}" == "validator" ] ; then
            set +x
            echoInfo "INFO: Validator mode detected, last parameter to setup..."
            echoErr "IMORTANT: To prevent validator from double signing you MUST define a minimum block height below which new blocks will NOT be produced!"
         
            while : ; do
                set +x
                echo "INFO: Default minmum block height is $HEIGHT"
                echoNErr "Input minimum block height or press [ENTER] for (default): " && read VALIDATOR_MIN_HEIGHT
                [ -z "$VALIDATOR_MIN_HEIGHT" ] && VALIDATOR_MIN_HEIGHT=$HEIGHT
                ( (! $(isNaturalNumber "$VALIDATOR_MIN_HEIGHT")) || [ $VALIDATOR_MIN_HEIGHT -lt $HEIGHT ] ) && echo "INFO: Minimum block height must be greater or equal to $HEIGHT" && continue
                set -x
                break
            done
        else
            VALIDATOR_MIN_HEIGHT=$HEIGHT
        fi

        set +x
        echo "INFO: Startup configuration was finalized"
        echoNInfo "CONFIG:       Network name (chain-id): " && echoErr $CHAIN_ID
        echoNInfo "CONFIG:               Deployment Mode: " && echoErr $INFRA_MODE
        echoNInfo "CONFIG: Minimum expected block height: " && echoErr $VALIDATOR_MIN_HEIGHT
        echoNInfo "CONFIG:         Genesis file checksum: " && echoErr $GENSUM
        echoNInfo "CONFIG:        Snapshot file checksum: " && echoErr $SNAPSUM
        echoNInfo "CONFIG:      Public Internet Exposure: " && echoErr $(isPublicIp $NODE_ADDR) 
        [ ! -z "$SEED_NODE_ADDR" ] && \
        echoNInfo "CONFIG:             Seed node address: " && echoErr $SEED_NODE_ADDR
        [ ! -z "$SENTRY_NODE_ADDR" ] && \
        echoNInfo "CONFIG:    Public Sentry node address: " && echoErr $SENTRY_NODE_ADDR
        [ ! -z "$PRIV_SENTRY_NODE_ADDR" ] && \
        echoNInfo "CONFIG:   Private Sentry node address: " && echoErr $PRIV_SENTRY_NODE_ADDR
        echoNInfo "CONFIG:        New network deployment: " && echoErr $NEW_NETWORK
        echoNInfo "CONFIG:   KIRA Manager git repository: " && echoErr $INFRA_REPO
        echoNInfo "CONFIG:       KIRA Manager git branch: " && echoErr $INFRA_BRANCH
        echoNInfo "CONFIG:              sekai git branch: " && echoErr $SEKAI_BRANCH
        echoNInfo "CONFIG:      KIRA Frontend git branch: " && echoErr $FRONTEND_BRANCH
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
if [ "${DOWNLOAD_SUCCESS,,}" == "true" ] ; then
    echo "INFO: Cloning tmp snapshot into snap directory"
    SNAP_FILENAME="${CHAIN_ID}-latest-$(date -u +%s).zip"
    SNAPSHOT="$KIRA_SNAP/$SNAP_FILENAME"
    # repair & safe copy
    rm -fv "$SNAPSHOT" && zip -FF $TMP_SNAP_PATH --out $SNAPSHOT -fz
    rm -fv $TMP_SNAP_PATH
else
    SNAPSHOT=""
fi

rm -fvr "$KIRA_SNAP/status"
rm -fv "$LOCAL_GENESIS_PATH"

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

rm -f -v -r $TMP_SNAP_DIR
NETWORK_NAME=$CHAIN_ID
CDHelper text lineswap --insert="KIRA_SNAP_PATH=\"$SNAPSHOT\"" --prefix="KIRA_SNAP_PATH=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="VALIDATOR_MIN_HEIGHT=\"$VALIDATOR_MIN_HEIGHT\"" --prefix="VALIDATOR_MIN_HEIGHT=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="NETWORK_NAME=\"$CHAIN_ID\"" --prefix="NETWORK_NAME=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="NEW_NETWORK=\"$NEW_NETWORK\"" --prefix="NEW_NETWORK=" --path=$ETC_PROFILE --append-if-found-not=True
CDHelper text lineswap --insert="TRUSTED_NODE_ADDR=\"$NODE_ADDR\"" --prefix="TRUSTED_NODE_ADDR=" --path=$ETC_PROFILE --append-if-found-not=True

rm -fv "$PUBLIC_PEERS" "$PRIVATE_PEERS" "$PUBLIC_SEEDS" "$PRIVATE_SEEDS"
touch "$PUBLIC_SEEDS" "$PRIVATE_SEEDS" "$PUBLIC_PEERS" "$PRIVATE_PEERS"

SAVED="false"
if ($(isPublicIp $NODE_ADDR)) ; then
    echoInfo "INFO: Node address '$NODE_ADDR' is a public IP address, public seeds will be added..."
    [ ! -z "$SEED_NODE_ADDR" ] && echo "$SEED_NODE_ADDR" >> $PUBLIC_SEEDS
    [ ! -z "$SENTRY_NODE_ADDR" ] && echo "$SENTRY_NODE_ADDR" >> $PUBLIC_SEEDS
    [ ! -z "$PRIV_SENTRY_NODE_ADDR" ] && echo "$PRIV_SENTRY_NODE_ADDR" >> $PUBLIC_SEEDS

    echoInfo "INFO: Downloading peers list & attempting public peers discovery..."
    TMP_PEERS="/tmp/peers.txt"
    TMP_SHUFFLED_PEERS="/tmp/peers-shuffled.txt"
    DOWNLOAD_SUCCESS="true"
    rm -fv "$TMP_PEERS" "$TMP_SHUFFLED_PEERS"
    wget "$NODE_ADDR:$DEFAULT_INTERX_PORT/download/peers.txt" -O $TMP_PEERS || DOWNLOAD_SUCCESS="false"

    if (! $(isFileEmpty "$TMP_PEERS")) && [ ${DOWNLOAD_SUCCESS,,} == "true" ]; then
        shuf $TMP_PEERS > $TMP_SHUFFLED_PEERS
        i=0
        while read peer; do
            peer=$(echo $peer | xargs || echo "")
            addrArr1=( $(echo $peer | tr "@" "\n") )
            addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
            nodeId=${addrArr1[0],,}
            ip=${addrArr2[0],,}
            port=${addrArr2[1],,}

            (! $(isPublicIp $ip)) && echoWarn "WARNING: Not a valid public ip ($ip)" && continue
            (! $(isNodeId "$nodeId")) && echoWarn "WARNING: Invalid node id '$nodeId' ($ip)" && continue 

            if grep -q "$nodeId" "$PUBLIC_SEEDS"; then
                echoWarn "WARNING: Node id '$nodeId' is already present in the seeds list ($ip)" && continue 
            fi

            if grep -q "$ip" "$PUBLIC_SEEDS"; then
                echoWarn "WARNING: Address '$ip' is already present in the seeds list" && continue 
            fi

            if ! timeout 0.1 nc -z $ip $port ; then echoWarn "WARNING: Port '$port' closed ($ip)" && continue  ; fi

            STATUS_URL="$ip:$DEFAULT_INTERX_PORT/api/status"
            STATUS=$(timeout 1 curl $STATUS_URL 2>/dev/null | jsonParse "" 2>/dev/null || echo -n "")
            if ($(isNullOrEmpty "$STATUS")) ; then echoWarn "WARNING: INTERX status not found ($ip)" && continue ; fi

            KIRA_STATUS_URL="$ip:$DEFAULT_INTERX_PORT/api/kira/status"
            KIRA_STATUS=$(timeout 1 curl $KIRA_STATUS_URL 2>/dev/null | jsonParse "" 2>/dev/null || echo -n "")
            if ($(isNullOrEmpty "$KIRA_STATUS")) ; then echoWarn "WARNING: Node status not found ($ip)" && continue  ; fi

            chain_id=$(echo "$STATUS" | jsonQuickParse "chain_id" 2> /dev/null || echo "")
            [ "$NETWORK_NAME" != "$chain_id" ] && echoWarn "WARNING: Invalid chain id '$chain_id' ($ip)" && continue 

            catching_up=$(echo "$KIRA_STATUS" | jsonQuickParse "catching_up" 2>/dev/null || echo "")
            [ "$catching_up" != "false" ] && echoWarn "WARNING: Node is still catching up '$catching_up' ($ip)" && continue 

            latest_block_height=$(echo "$KIRA_STATUS" | jsonQuickParse "latest_block_height" || echo "")
            (! $(isNaturalNumber "$latest_block_height")) && echoWarn "WARNING: Inavlid block heigh '$latest_block_height' ($ip)" && continue 
            [ $latest_block_height -lt $VALIDATOR_MIN_HEIGHT ] && echoWarn "WARNING: Block heigh '$latest_block_height' older than latest '$VALIDATOR_MIN_HEIGHT' ($ip)" && continue 

            echoInfo "INFO: Active peer found: '$peer' adding to public seeds list..."
            echo "$peer" >> $PUBLIC_SEEDS
            i=$(($i + 1))

            [ $i -ge 16 ] && echoInfo "INFO: Peers discovery limit reached..." && break
        done < $TMP_SHUFFLED_PEERS

        echoInfo "INFO: Found total of $i new peers"
    else
        echoInfo "INFO: No extra public peers were found..."
    fi
else
    echoInfo "INFO: Node address '$NODE_ADDR' is a local IP address, private peers will be added..."
    [ ! -z "$PRIV_SENTRY_NODE_ADDR" ] && echo "$PRIV_SENTRY_NODE_ADDR" >> $PRIVATE_PEERS
fi

($(isFileEmpty "$PUBLIC_SEEDS")) && ($(isFileEmpty "$PRIVATE_PEERS")) && echoErr "ERROR: No public or private seeds were found" && exit 1

echoInfo "INFO: Finished quick select!"