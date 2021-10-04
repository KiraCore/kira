#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-peers.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat
# cat $KIRA_SCAN/peers.logs
set -x

timerStart
PEERS_SCAN_PATH="$KIRA_SCAN/peers"
SNAPS_SCAN_PATH="$KIRA_SCAN/snaps"
INTERX_PEERS_PATH="$INTERX_REFERENCE_DIR/peers.txt"
INTERX_SNAPS_PATH="$INTERX_REFERENCE_DIR/snaps.txt"
MIN_SNAP_SIZE="524288"


while [ "$(globGet IS_SCAN_DONE)" != "true" ] ; do
    echo "INFO: Waiting for monitor scan to finalize run..."
    sleep 10
done

CONTAINERS=$(globGet CONTAINERS)

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTING KIRA PEERS SCAN $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "|      PEERS_SCAN_PATH: $PEERS_SCAN_PATH"
echoWarn "|      SNAPS_SCAN_PATH: $SNAPS_SCAN_PATH"
echoWarn "| INTERX_REFERENCE_DIR: $INTERX_REFERENCE_DIR"
echoWarn "|    INTERX_PEERS_PATH: $INTERX_PEERS_PATH"
echoWarn "|    INTERX_SNAPS_PATH: $INTERX_SNAPS_PATH"
echoWarn "|           CONTAINERS: $CONTAINERS"
echoWarn "------------------------------------------------"
set -x

echoInfo "INFO: Fetching address book file..."
TMP_BOOK="/tmp/addrbook.txt"
TMP_BOOK_DUMP="/tmp/addrbook-dump.json"
TMP_BOOK_SHUFF="/tmp/addrbook-shuff.txt"

touch $TMP_BOOK

echoInfo "INFO: Substituting address book..."
rm -fv $TMP_BOOK_DUMP
CONTAINERS=$(globGet CONTAINERS)
for name in $CONTAINERS; do
    if [[ "${name,,}" =~ ^(validator|sentry|seed)$ ]] ; then
        echoInfo "INFO: Fetching address book..."
        TMP_BOOK_DUMP=$(globFile TMP_BOOK_DUMP)
        timeout 60 docker cp "$name:$SEKAID_HOME/config/addrbook.json" $TMP_BOOK_DUMP || echo "" > $TMP_BOOK_DUMP

        if (! $(isFileEmpty $TMP_BOOK_DUMP)) ; then
            COMMON_PATH="$DOCKER_COMMON/interx"
            COMMON_GLOB="$COMMON_PATH/kiraglob"
            TMP_BOOK_DUMP_GLOB=$(globFile KIRA_ADDRBOOK $COMMON_GLOB)
            echoInfo "INFO: Address book was found in the $name container, exporting file from tmp directory to '$TMP_BOOK_DUMP_GLOB'"
            cat $TMP_BOOK_DUMP > $TMP_BOOK_DUMP_GLOB
        else
            echoWarn "WARNING: Address book was empty, can't subsitute for the interx..."
        fi
    fi
done

echoInfo "INFO: Starting address discovery..."
rm -fv $TMP_BOOK_DUMP
timeout 60 docker cp "seed:$SEKAID_HOME/config/addrbook.json" $TMP_BOOK_DUMP || echo "" > $TMP_BOOK_DUMP
echo $(cat "$TMP_BOOK_DUMP" | grep -Eo '"ip"[^,]*' | grep -Eo '[^:]*$' || echo "") >> $TMP_BOOK && rm -fv $TMP_BOOK_DUMP
timeout 60 docker cp "sentry:$SEKAID_HOME/config/addrbook.json" $TMP_BOOK_DUMP || echo "" > $TMP_BOOK_DUMP
echo $(cat "$TMP_BOOK_DUMP" | grep -Eo '"ip"[^,]*' | grep -Eo '[^:]*$' || echo "") >> $TMP_BOOK && rm -fv $TMP_BOOK_DUMP
timeout 60 docker cp "validator:$SEKAID_HOME/config/addrbook.json" $TMP_BOOK_DUMP || echo "" > $TMP_BOOK_DUMP
echo $(cat "$TMP_BOOK_DUMP" | grep -Eo '"ip"[^,]*' | grep -Eo '[^:]*$' || echo "") >> $TMP_BOOK && rm -fv $TMP_BOOK_DUMP

PUBLIC_IP=$(globGet "PUBLIC_IP")
(! $(isNullOrEmpty $PUBLIC_IP)) && echo "\"$PUBLIC_IP\"" >> $TMP_BOOK

sed -i '/^$/d' $TMP_BOOK
sort -u $TMP_BOOK -o $TMP_BOOK
shuf $TMP_BOOK > $TMP_BOOK_SHUFF

if ($(isFileEmpty $TMP_BOOK)) ; then
    echoInfo "INFO: No unique addresses were found in the '$TMP_BOOK'"
    exit 0
fi

CHECKSUM=$(timeout 30 curl --fail 0.0.0.0:$KIRA_INTERX_PORT/api/status | jsonQuickParse "genesis_checksum" || echo -n "")
if ($(isNullOrEmpty "$CHECKSUM")) ; then
    echoWarn "WARNING: Invalid local genesis checksum '$CHECKSUM'"
    exit 0 
fi

# if public peers list is empty then quickly return list, otherwise scan all
($(isFileEmpty $INTERX_PEERS_PATH)) && PEERS_LIMIT=64 || PEERS_LIMIT=0

echoInfo "INFO: Processing address book entries..."
TMP_BOOK_PUBLIC="/tmp/addrbook.public.txt"
TMP_BOOK_PUBLIC_SNAPS="/tmp/addrbook.public-snaps.txt"
rm -fv "$TMP_BOOK_PUBLIC" "$TMP_BOOK_PUBLIC_SNAPS"
touch "$TMP_BOOK_PUBLIC" "$TMP_BOOK_PUBLIC_SNAPS"
P2P_PORTS=(16656 26656 36656)

i=0
i_snaps=0
total=0
HEIGHT=0
while read ip; do
    total=$(($total + 1))
    ip=$(delWhitespaces $ip | tr -d '"' || "")
    ($(isNullOrEmpty "$ip")) && continue
    set +x
    (! $(isPublicIp $ip)) && echoWarn "WARNING: Not a valid public IPv4 ($ip)" && continue

    if grep -q "$ip" "$TMP_BOOK_PUBLIC"; then
        echoWarn "WARNING: Address '$ip' is already present in the address book" && continue 
    fi

    TMP_HEIGHT=$(globGet LATEST_BLOCK_HEIGHT)
    if ($(isNaturalNumber "$TMP_HEIGHT")) && [[ $TMP_HEIGHT -gt $HEIGHT ]] ; then
        echoInfo "INFO: Block height was updated form $HEIGHT to $TMP_HEIGHT"
        HEIGHT=$TMP_HEIGHT
    fi

    if ! timeout 1 nc -z $ip $DEFAULT_INTERX_PORT ; then echoWarn "WARNING: Port '$DEFAULT_INTERX_PORT' closed ($ip)" && continue ; fi

    sleep 1
    set -x
    STATUS=$(timeout 3 curl "$ip:$DEFAULT_INTERX_PORT/api/status" 2>/dev/null || echo -n "")
    if ($(isNullOrEmpty "$STATUS")) ; then echoWarn "WARNING: INTERX status not found ($ip)" && continue ; fi

    KIRA_STATUS=$(timeout 3 curl "$ip:$DEFAULT_INTERX_PORT/api/kira/status" 2>/dev/null || echo -n "")
    if ($(isNullOrEmpty "$KIRA_STATUS")) ; then echoWarn "WARNING: Node status not found ($ip)" && continue ; fi

    latest_block_height=$(echo "$KIRA_STATUS"  | jsonQuickParse "latest_block_height" || echo "")
    (! $(isNaturalNumber "$latest_block_height")) && echoWarn "WARNING: Inavlid block heigh '$latest_block_height' ($ip)" && continue 
    [[ $((latest_block_height + 100)) -lt $HEIGHT ]] && echoWarn "WARNING: Block heigh '$latest_block_height' older than latest '$HEIGHT' ($ip)" && continue 
    set +x

    # do not reject self otherwise nothing can be exposed in the peers list
    [ "$PUBLIC_IP" != "$ip" ] && \
        (! $(urlExists "$ip:$DEFAULT_INTERX_PORT/download/peers.txt")) && echoWarn "WARNING: Peer is NOT exposing peers list ($ip)" && continue

    chain_id=$(echo "$STATUS" | jsonQuickParse "chain_id" || echo "")
    [ "$NETWORK_NAME" != "$chain_id" ] && echoWarn "WARNING: Invalid chain id '$chain_id' ($ip)" && continue

    genesis_checksum=$(echo "$STATUS" | jsonQuickParse "genesis_checksum" || echo "")
    [ "$CHECKSUM" != "$genesis_checksum" ] && echoWarn "WARNING: Invalid genesis checksum '$genesis_checksum' ($ip)" && continue 

    peer=""
    for port in "${P2P_PORTS[@]}" ; do
        if ! timeout 1 nc -z $ip $port ; then
            echoWarn "WARNING: Port $port is closed ($ip)"
            continue
        fi

        node_id=$(tmconnect id --address="$ip:$port" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo "")
        if (! $(isNodeId "$node_id")) ; then
            echoWarn "WARNING: Handshake fialure, Node Id was NOT found ($ip)"
            TARGET=""
            [[ $port == 16656 ]] && TARGET="seed_node_id"
            [[ $port == 26656 ]] && TARGET="sentry_node_id"
            [[ $port == 36656 ]] && TARGET="validator_node_id"
            node_id=$(timeout 1 curl "$ip:$DEFAULT_INTERX_PORT/download/$TARGET" 2>/dev/null || echo -n "")
            ($(isNodeId "$node_id")) && peer="$node_id@$ip:$port"
            continue
        else
            peer="$node_id@$ip:$port"
        fi

        if grep -q "$node_id" "$TMP_BOOK_PUBLIC"; then
            echoWarn "WARNING: Node Id '$node_id' is already present in the address book ($ip)" && continue 
        fi

        chain_id=$(tmconnect network --address="$ip:$port" --node_key="$KIRA_SECRETS/seed_node_key.json" --timeout=3 || echo "")
        [ "$NETWORK_NAME" != "$chain_id" ] && echoWarn "WARNING: Invalid chain id '$chain_id' ($ip)" && continue

        rpc_port=$((port + 1))
        if (! $(isPortOpen "$ip" "$rpc_port" "0.25")) ; then
            echoWarn "WARNING: RPC Port '$rpc_port' is closed ($ip)" && continue
        fi

        echoInfo "INFO: Active peer found: '$peer'"
        echo "$peer" >> $TMP_BOOK_PUBLIC
        i=$(($i + 1))
        [[ $PEERS_LIMIT -gt 0 ]] && [[ $i -ge $PEERS_LIMIT ]] && break
    done

    [ -z "$peer" ] && echoWarn "WARNING: No P2P peers were found ($ip)" && continue

    if [[ $PEERS_LIMIT -gt 0 ]] && [[ $i -ge $PEERS_LIMIT ]] ; then
        echoWarn "WARNING: Peer limit ($PEERS_LIMIT) reached"
        break
    fi
    
    SNAP_URL="$ip:$DEFAULT_INTERX_PORT/download/snapshot.zip"
    if (! $(urlExists "$SNAP_URL")) ; then
        echoWarn "WARNING: Peer is not exposing snapshots ($ip)"
        continue 
    else
        if grep -q "$peer" "$TMP_BOOK_PUBLIC_SNAPS"; then
            echoWarn "WARNING: Peer '$peer' is already present in the snap book" && continue 
        fi

        SIZE=$(urlContentLength "$SNAP_URL")
        if [[ $SIZE -gt $MIN_SNAP_SIZE ]] ; then
            i_snaps=$(($i_snaps + 1))
            echoInfo "INFO: Peer $peer is exposing $SIZE Bytes snpashot"
            echo "${peer} $SIZE" >> $TMP_BOOK_PUBLIC_SNAPS
        fi
    fi
done < $TMP_BOOK_SHUFF 

if ($(isFileEmpty $TMP_BOOK_PUBLIC)) || [[ $i -le 0 ]] ; then
    echoInfo "INFO: No public addresses were found in the '$TMP_BOOK_PUBLIC'"
    sleep 60
else
    echoInfo "INFO: Sucessfully discovered '$i' public peers out of total '$total' in the address book, saving results to '$PEERS_SCAN_PATH' and '$INTERX_PEERS_PATH'"
    cp -afv $TMP_BOOK_PUBLIC $PEERS_SCAN_PATH
    cp -afv $TMP_BOOK_PUBLIC $INTERX_PEERS_PATH
fi

if (! $(isFileEmpty $TMP_BOOK_PUBLIC_SNAPS)) ; then
    echoInfo "INFO: Sorting peers by snapshot size"
    sort -nrk2 -n $TMP_BOOK_PUBLIC_SNAPS > "${TMP_BOOK_PUBLIC_SNAPS}.tmp"
    cat "${TMP_BOOK_PUBLIC_SNAPS}.tmp" | cut -d ' ' -f1 > $TMP_BOOK_PUBLIC_SNAPS
    
    echoInfo "INFO: Sucessfully discovered '$i_snaps' public peers exposing snaps out of total '$total' in the address book, saving results to '$SNAPS_SCAN_PATH' and '$INTERX_SNAPS_PATH'"
    cp -afv $TMP_BOOK_PUBLIC_SNAPS $SNAPS_SCAN_PATH
    cp -afv $TMP_BOOK_PUBLIC_SNAPS $INTERX_SNAPS_PATH
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: PEERS MONITOR                      |"
echoWarn "|  ELAPSED: $(timerSpan) seconds"
echoWarn "------------------------------------------------"
set -x

sleep 60