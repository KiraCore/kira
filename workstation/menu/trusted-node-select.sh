#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/trusted-node-select.sh" && rm -f $FILE && touch $FILE && nano $FILE && chmod 555 $FILE
show_log="false"
getArgs "$1" --gargs_throw=false --gargs_verbose=true
[ "$show_log" == "true" ] && ( set +x && set -x ) || ( set -x && set +x && clear )

DEFAULT_INTERX_PORT="$(globGet DEFAULT_INTERX_PORT)"
CUSTOM_INTERX_PORT="$(globGet CUSTOM_INTERX_PORT)"
CUSTOM_RPC_PORT="$(globGet CUSTOM_RPC_PORT)"
DEFAULT_RPC_PORT="$(globGet DEFAULT_RPC_PORT)"
KIRA_SEED_RPC_PORT="$(globGet KIRA_SEED_RPC_PORT)"
KIRA_VALIDATOR_RPC_PORT="$(globGet KIRA_VALIDATOR_RPC_PORT)"
KIRA_SENTRY_RPC_PORT="$(globGet KIRA_SENTRY_RPC_PORT)"

TRUSTED_NODE_ADDR="$(globGet TRUSTED_NODE_ADDR)"
TRUSTED_NODE_INTERX_PORT="$(globGet TRUSTED_NODE_INTERX_PORT)"
TRUSTED_NODE_RPC_PORT="$(globGet TRUSTED_NODE_RPC_PORT)"

SNAPSHOT_FILE=$(globGet SNAPSHOT_FILE)
SNAPSHOT_FILE_HASH=$(globGet SNAPSHOT_FILE_HASH)
SNAPSHOT_GENESIS_HASH=$(globGet SNAPSHOT_GENESIS_HASH)
SNAPSHOT_CHAIN_ID=$(globGet SNAPSHOT_CHAIN_ID)
SNAPSHOT_HEIGHT=$(globGet SNAPSHOT_HEIGHT)

KIRA_SNAP_PATH="$(globGet KIRA_SNAP_PATH)"

while : ; do
    while : ; do
      if ($(isDnsOrIp "$TRUSTED_NODE_ADDR")) ; then
          NODE_ADDR="$TRUSTED_NODE_ADDR"
          ($(isPort "$TRUSTED_NODE_INTERX_PORT")) && NODE_ADDR="${NODE_ADDR}:${TRUSTED_NODE_INTERX_PORT}" || \
           ( ($(isPort "$TRUSTED_NODE_RPC_PORT")) && NODE_ADDR="${NODE_ADDR}:${TRUSTED_NODE_RPC_PORT}" )
          echoInfo "INFO: Previously trusted node address (default): $NODE_ADDR"
          echoInfo "INFO: To reinitalize already existing node type: 0.0.0.0"
          echoNErr "Input address of the node you trust or choose [ENTER] for default: " && read v1 && v1=$(echo "$v1" | xargs)
          [ -z "$v1" ] && v1=$NODE_ADDR
      else
          echoInfo "INFO: To reinitalize already existing node type: 0.0.0.0"
          echoNErr "Input address of the node you trust: " && read v1 && v1=$(echo "$v1" | xargs)
      fi

      v2=$(strSplitTakeN : 1 "$v1")
      v1=$(strSplitTakeN : 0 "$v1")
      v1=$(resolveDNS "$v1")
    
      ($(isDnsOrIp "$v1")) && NODE_ADDR="$v1" || NODE_ADDR="" 
      [ -z "$NODE_ADDR" ] && echoWarn "WARNING: Value '$v1' is not a valid DNS name or IP address, try again!" && continue

      ($(isPort "$v2")) && NODE_ADDR_PORT="$v2" || NODE_ADDR_PORT="";

      echoInfo "INFO: Please wait, testing connectivity..."
      if ! timeout 2 ping -c1 "$NODE_ADDR" &>/dev/null ; then
          echoWarn "WARNING: Address '$NODE_ADDR' could NOT be reached, check your network connection or select diffrent node" 
          continue
      else
          echoInfo "INFO: Success, node '$NODE_ADDR' is online!"
      fi

      TRUSTED_NODE_INTERX_PORT=""
      TRUSTED_NODE_RPC_PORT=""
      STATUS=""
      CHAIN_ID=""

        echoInfo "INFO: Trusted node INTERX port discovery..."
        # search interx ports
        INTERX_PORTS=($NODE_ADDR_PORT $DEFAULT_INTERX_PORT $CUSTOM_INTERX_PORT)
        for port in "${INTERX_PORTS[@]}" ; do
            echoInfo "INFO: Testing interx port '$port' for status..."
            STATUS=$(timeout 15 curl "$NODE_ADDR:$port/api/kira/status" 2>/dev/null | jsonParse "" 2>/dev/null || echo -n "")
            CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null || echo -n "")
            ($(isNullOrWhitespaces "$CHAIN_ID")) && STATUS=""
            if [ ! -z "$STATUS" ] ; then
                echoInfo "INFO: INTERX port $port found!"
                TRUSTED_NODE_INTERX_PORT="$port" 
                break
            fi
        done

        echoInfo "INFO: Trusted node RPC port discovery..."
        # search rpc ports
        RPC_PORTS=($CUSTOM_RPC_PORT $DEFAULT_RPC_PORT $KIRA_SEED_RPC_PORT $KIRA_SENTRY_RPC_PORT $KIRA_VALIDATOR_RPC_PORT)
        [ -z "$STATUS" ] && RPC_PORTS+=($NODE_ADDR_PORT)
        for port in "${RPC_PORTS[@]}" ; do
            echoInfo "INFO: Testing rpc port '$port' for status..."
            TMP_STATUS=$(timeout 15 curl --fail "$NODE_ADDR:$port/status" 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")
            TMP_CHAIN_ID=$(echo "$TMP_STATUS" | jsonQuickParse "network" 2>/dev/null || echo -n "")
            ($(isNullOrWhitespaces "$TMP_CHAIN_ID")) && TMP_STATUS=""
            if [ ! -z "$TMP_STATUS" ] ; then
                echoInfo "INFO: RPC port $port found!"
                TRUSTED_NODE_RPC_PORT="$port" 
                break
            fi
        done

      HEIGHT=$(echo "$STATUS" | jsonQuickParse "latest_block_height" 2> /dev/null || echo -n "")
      CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null || echo -n "")

      if [ "$REINITALIZE_NODE" == "true" ] && ( ($(isNullOrWhitespaces "$CHAIN_ID")) || (! $(isNaturalNumber "$HEIGHT")) ) ; then
          HEIGHT=$(globGet LATEST_BLOCK_HEIGHT "$GLOBAL_COMMON_RO") 
          CHAIN_ID=$NETWORK_NAME 
          ($(isNullOrWhitespaces "$NETWORK_NAME")) && NETWORK_NAME="unknown"
          (! $(isNaturalNumber "$HEIGHT")) && HEIGHT="0"
      fi

      if ($(isNullOrWhitespaces "$CHAIN_ID")) || (! $(isNaturalNumber "$HEIGHT")) ; then
          echoWarn "WARNING: Could NOT read status, block height or chian-id"
          echoErr "ERROR: Address '$NODE_ADDR' is NOT a valid, publicly exposed public RPC or INTERX node address"
          continue
      fi

      globSet "TRUSTED_NODE_ID" ""
      globSet "TRUSTED_NODE_P2P_PORT" ""
      globSet "TRUSTED_NODE_GENESIS_HASH" ""
      globSet "TRUSTED_NODE_ADDR" "$NODE_ADDR"
      globSet "TRUSTED_NODE_RPC_PORT" "$TRUSTED_NODE_RPC_PORT"
      globSet "TRUSTED_NODE_INTERX_PORT" "$TRUSTED_NODE_INTERX_PORT"
      globSet "TRUSTED_NODE_STATUS" "$STATUS"
      globSet "TRUSTED_NODE_CHAIN_ID" "$CHAIN_ID"
      globSet "TRUSTED_NODE_HEIGHT" "$HEIGHT"
    
      break
    done

    TRUSTED_NODE_ADDR="$(globGet TRUSTED_NODE_ADDR)"
    TRUSTED_NODE_INTERX_PORT="$(globGet TRUSTED_NODE_INTERX_PORT)"
    TRUSTED_NODE_RPC_PORT="$(globGet TRUSTED_NODE_RPC_PORT)" 
    [ -z "$TRUSTED_NODE_RPC_PORT" ] && TRUSTED_NODE_RPC_PORT=0

    CUSTOM_P2P_PORT="$(globGet CUSTOM_P2P_PORT)"
    DEFAULT_P2P_PORT="$(globGet DEFAULT_P2P_PORT)"
    KIRA_SEED_P2P_PORT="$(globGet KIRA_SEED_P2P_PORT)"
    KIRA_VALIDATOR_P2P_PORT="$(globGet KIRA_VALIDATOR_P2P_PORT)"
    KIRA_SENTRY_P2P_PORT="$(globGet KIRA_SENTRY_P2P_PORT)"

    P2P_PORTS=($CUSTOM_P2P_PORT $DEFAULT_P2P_PORT $KIRA_SEED_P2P_PORT $KIRA_VALIDATOR_P2P_PORT $KIRA_SENTRY_P2P_PORT $((TRUSTED_NODE_RPC_PORT - 1)) $((TRUSTED_NODE_RPC_PORT + 1)))

    # P2P port can be discovered from the node status message
    if (! $(isPort "$TRUSTED_NODE_P2P_PORT")) ; then
        LISTEN_ADDR=$(echo "$STATUS" | jsonParse "node_info.listen_addr" 2>/dev/null || echo -n "")
        LISTEN_PORT=$(strSplitTakeN : 2 "$LISTEN_ADDR")
        if ($(isPort "$LISTEN_PORT")) ; then
            echoInfo "INFO: Listen port found: $LISTEN_ADDR:$LISTEN_PORT"
            P2P_PORTS+=($((LISTEN_PORT - 1)) $LISTEN_PORT $((LISTEN_PORT + 1)))
        fi
    fi

    echoInfo "INFO: Trusted node P2P port discovery..."

    for port in "${P2P_PORTS[@]}" ; do
        echoInfo "INFO: Testing port '$port' for p2p access..."
        TRUSTED_NODE_ID=$(tmconnect id --address="$TRUSTED_NODE_ADDR:$port" --node_key="$KIRA_SECRETS/test_node_key.json" --timeout=3 || echo "")
        if ($(isNodeId "$TRUSTED_NODE_ID")) ; then
            echoInfo "INFO: Testing p2p port '$port' for status..."
            globSet TRUSTED_NODE_ID "$TRUSTED_NODE_ID"
            globSet TRUSTED_NODE_P2P_PORT "$port"
        fi
    done

    if (! $(isPort "$TRUSTED_NODE_RPC_PORT")) ; then
        for port in "${P2P_PORTS[@]}" ; do
            echoInfo "INFO: Testing port '$port' for rpc status..."
            TMP_STATUS=$(timeout 15 curl --fail "$NODE_ADDR:$port/status" 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")
            TMP_CHAIN_ID=$(echo "$TMP_STATUS" | jsonQuickParse "network" 2>/dev/null || echo -n "")
            ($(isNullOrWhitespaces "$TMP_CHAIN_ID")) && TMP_STATUS=""
            if [ ! -z "$TMP_STATUS" ] ; then
                echoInfo "INFO: RPC port $port found!"
                TRUSTED_NODE_RPC_PORT="$port"
                globSet TRUSTED_NODE_RPC_PORT "$port"
                break
            fi
        done
    fi

    echoInfo "INFO: Genesis file search..."

    GENESIS_FILE="$(globFile TRUSTED_NODE_GENESIS_FILE)"
    ($(isPort "$TRUSTED_NODE_INTERX_PORT")) && \
        GENSUM=$(timeout 120 curl $TRUSTED_NODE_ADDR:$TRUSTED_NODE_INTERX_PORT/api/gensum 2>/dev/null | jsonParse "checksum" | sed 's/^0x//' 2>/dev/null || echo -n "") || \
        GENSUM=""

    echoInfo "INFO: Please wait, calculating old genesis file checksum..."
    GENSUM_OLD=$(sha256 "$GENESIS_FILE")

    if [ "$GENSUM_OLD" != "$GENSUM" ] || (! $(isSHA256 $GENSUM)) ; then
        echoInfo "INFO: Genesis file was NOT downloaded yet or does not match interx gensum"
        GENSUM=""
        rm -fv  $GENESIS_FILE && touch $GENESIS_FILE

        if ($(isPort "$TRUSTED_NODE_RPC_PORT")) ; then
            GENCHUNK_DIR="/tmp/genchunks"
            GENTEMP64=$GENCHUNK_DIR/temp64.txt
            rm -rfv $GENCHUNK_DIR 
            mkdir -p $GENCHUNK_DIR

            CHUNK_ID=0
            totalChunks=1
            while : ; do
                [[ $CHUNK_ID -ge $totalChunks ]] && break
                rm -rfv $GENTEMP64 && touch $GENTEMP64
                CHUNK="$GENCHUNK_DIR/chunk_${CHUNK_ID}.json"
                wget "$TRUSTED_NODE_ADDR:$TRUSTED_NODE_RPC_PORT/genesis_chunked?chunk=$CHUNK_ID" -O $CHUNK || echo "" > $CHUNK
                totalChunks=$(jsonQuickParse "total" $CHUNK || echo "")
                (! $(isNaturalNumber "$totalChunks")) && totalChunks=0
                jsonParse "result.data" "$CHUNK" "$GENTEMP64" || echo "" > $GENTEMP64
                sed -i "s/[\"\']//g" $GENTEMP64 || echo "" > $GENTEMP64

                if (! $(isFilleEmpty $GENTEMP64)) ; then 
                    base64 -d $GENTEMP64 >> $GENESIS_FILE || ( rm -fv $GENESIS_FILE && totalChunks=-1 )
                else
                    echoEWarn "WARNINIG: Failed to porcess genesis chunk $CHUNK_ID"
                    totalChunks=-1
                fi
                CHUNK_ID=$((CHUNK_ID + 1))
            done

            echoInfo "INFO: Please wait, attempting to minimize & sort genesis json..."
            jsonParse "" "$GENESIS_FILE" "$GENESIS_FILE" --indent=false --sort_keys=true || rm -fv $GENESIS_FILE

            if (! $(isFilleEmpty $GENESIS_FILE)) ; then 
                echoInfo "INFO: Please wait, calculating new checksum..."
                GENSUM=$(sha256 "$GENESIS_FILE")
            else
                echoWarn "WARNING: Genesis checksum fetch from RPC failed"
                GENSUM=""
            fi
        fi

        if ($(isPort "$TRUSTED_NODE_INTERX_PORT")) && (! $(isSHA256 $GENSUM)) ; then
            echoInfo "INFO: Attempting to download genesis from interx..."
            GENSUM=$(timeout 120 curl $TRUSTED_NODE_ADDR:$TRUSTED_NODE_INTERX_PORT/api/gensum 2>/dev/null | jsonParse "checksum" | sed 's/^0x//' 2>/dev/null || echo -n "")
            ($(isSHA256 $GENSUM)) && safeWget "$GENESIS_FILE" $TRUSTED_NODE_ADDR:$TRUSTED_NODE_INTERX_PORT/api/genesis $GENSUM || globDel TRUSTED_NODE_GENESIS_FILE

            echoInfo "INFO: Please wait, attempting to minimize & sort genesis json..."
            jsonParse "" "$GENESIS_FILE" "$GENESIS_FILE" --indent=false --sort_keys=true || globDel TRUSTED_NODE_GENESIS_FILE
            echoInfo "INFO: Please wait, calculating new checksum..."
            GENSUM=$(sha256 $GENESIS_FILE)
        fi
    else
        echoInfo "INFO: Genesis file already exists and matches interx gensum"
    fi

    if ($(isSHA256 $GENSUM)) && (! $(isFileEmpty $GENESIS_FILE)) ; then
        globSet "TRUSTED_NODE_GENESIS_HASH" "$GENSUM"
    fi

    echoInfo "INFO: Snapshot discovery..."
    SNAP_URL="$TRUSTED_NODE_ADDR:$TRUSTED_NODE_INTERX_PORT/download/snapshot.tar"

    if ($(urlExists "$SNAP_URL")) ; then
        echoInfo "INFO: Snapshoot found!"
        SNAP_SIZE=$(urlContentLength "$SNAP_URL") 
        (! $(isNaturalNumber $SNAP_SIZE)) && SNAP_SIZE=0 
        globSet TRUSTED_NODE_SNAP_URL "$SNAP_URL"
        globSet TRUSTED_NODE_SNAP_SIZE "$SNAP_SIZE"
    else
        globSet TRUSTED_NODE_SNAP_URL ""
        globSet TRUSTED_NODE_SNAP_SIZE ""
    fi
    break
done

TRUSTED_NODE_CHAIN_ID="$(globGet TRUSTED_NODE_CHAIN_ID)"
SNAPSHOT_CHAIN_ID="$(globGet SNAPSHOT_CHAIN_ID)"

echoInfo "INFO: Local snapshots lookup..."
SNAPSHOTS=`ls $KIRA_SNAP/${TRUSTED_NODE_CHAIN_ID}-*-*.tar` || SNAPSHOTS=""
SNAPSHOTS_COUNT=${#SNAPSHOTS[@]}
SNAP_LATEST_PATH="$KIRA_SNAP_PATH"

if [ ! -z "$SNAPSHOTS" ] && [[ $SNAPSHOTS_COUNT -gt 0 ]] && [[ "$SNAPSHOT_CHAIN_ID" != "$TRUSTED_NODE_CHAIN_ID" ]] ; then
    DEFAULT_SNAP="${SNAPSHOTS[-1]}"
    (! $(isNullOrWhitespaces "$DEFAULT_SNAP")) && $KIRA_MANAGER/menu/snap-select.sh --snap-file="$DEFAULT_SNAP"
fi

echoC ";gre" "Trusted node discovery results:"
echoC ";whi" "TRUSTED_NODE_GENESIS_HASH: $(globGet TRUSTED_NODE_GENESIS_HASH)"
echoC ";whi" "TRUSTED_NODE_GENESIS_FILE: $(globFile TRUSTED_NODE_GENESIS_FILE)"
echoC ";whi" "        TRUSTED_NODE_ADDR: $(globGet TRUSTED_NODE_ADDR)"
echoC ";whi" "          TRUSTED_NODE_ID: $(globGet TRUSTED_NODE_ID)"
echoC ";whi" "    TRUSTED_NODE_P2P_PORT: $(globGet TRUSTED_NODE_P2P_PORT)"
echoC ";whi" "    TRUSTED_NODE_RPC_PORT: $(globGet TRUSTED_NODE_RPC_PORT)"
echoC ";whi" " TRUSTED_NODE_INTERX_PORT: $(globGet TRUSTED_NODE_INTERX_PORT)"
echoC ";whi" "    TRUSTED_NODE_CHAIN_ID: $(globGet TRUSTED_NODE_CHAIN_ID)"
echoC ";whi" "      TRUSTED_NODE_HEIGHT: $(globGet TRUSTED_NODE_HEIGHT)"
echoC ";whi" "    TRUSTED_NODE_SNAP_URL: $(globGet TRUSTED_NODE_SNAP_URL)"
echoC ";whi" "   TRUSTED_NODE_SNAP_SIZE: $(globGet TRUSTED_NODE_SNAP_SIZE)"

