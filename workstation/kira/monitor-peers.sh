#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/monitor-peers.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kirascan && journalctl -u kirascan -f --output cat
set -x

SCRIPT_START_TIME="$(date -u +%s)"
SCAN_DIR="$KIRA_HOME/kirascan"
LATEST_BLOCK_SCAN_PATH="$SCAN_DIR/latest_block"
PEERS_SCAN_PATH="$SCAN_DIR/peers"
INTERX_REFERENCE_DIR="$DOCKER_COMMON/interx/cache/reference"
INTERX_PEERS_PATH="$INTERX_REFERENCE_DIR/peers.txt"

set +x
echoWarn "------------------------------------------------"
echoWarn "|     STARTING KIRA PEERS SCAN v0.2.2.3        |"
echoWarn "|-----------------------------------------------"
echoWarn "| LATEST_BLOCK_SCAN_PATH: $LATEST_BLOCK_SCAN_PATH"
echoWarn "|        PEERS_SCAN_PATH: $PEERS_SCAN_PATH"
echoWarn "|   INTERX_REFERENCE_DIR: $INTERX_REFERENCE_DIR"
echoWarn "|      INTERX_PEERS_PATH: $INTERX_PEERS_PATH"
echoWarn "------------------------------------------------"
set -x

if [ "${INFRA_MODE,,}" != "sentry" ] ; then
    echoInfo "INFO: Infra must be deployed in the sentry mode, aborting"
    exit 0
fi

echoInfo "INFO: Fetching address book file..."
TMP_BOOK="/tmp/addrbook.txt"
TMP_BOOK_SHUFF="/tmp/addrbook-shuff.txt"
((docker exec -i seed cat "$SEKAID_HOME/config/addrbook.json") | grep -Eo '"ip"[^,]*' | grep -Eo '[^:]*$' || echo "") > $TMP_BOOK
sort -u $TMP_BOOK -o $TMP_BOOK
shuf $TMP_BOOK > $TMP_BOOK_SHUFF

if ($(isFileEmpty $TMP_BOOK)) ; then
    echoInfo "INFO: No unique addresses were found in the '$TMP_BOOK'"
    exit 0
fi

CHECKSUM=$(timeout 30 curl 0.0.0.0:$KIRA_INTERX_PORT/api/status | grep -Eo '"genesis_checksum"[^,]*' | grep -Eo '[^:]*$' | xargs || echo -n "")
if ($(isNullOrEmpty "$CHECKSUM")) ; then
    echoWarn "WARNING: Invalid local genesis checksum '$CHECKSUM'"
    exit 0 
fi

echoInfo "INFO: Processing address book entries..."
TMP_BOOK_PUBLIC="/tmp/addrbook.public.txt"
rm -fv "$TMP_BOOK_PUBLIC" && touch $TMP_BOOK_PUBLIC
i=0
total=0
HEIGHT=0
while read ip; do
    sleep 2
    total=$(($total + 1))
    ip=$(echo $ip | xargs || "")
    (! $(isPublicIp $ip)) && continue

    if grep -q "$ip" "$TMP_BOOK_PUBLIC"; then
        echoWarn "WARNING: Address '$ip' is already present in the address book" && continue 
    fi

    TMP_HEIGHT=$(cat $LATEST_BLOCK_SCAN_PATH || echo "")
    if ($(isNaturalNumber "$TMP_HEIGHT")) && [ $TMP_HEIGHT -gt $HEIGHT ] ; then
        echoInfo "INFO: Block height was updated form $HEIGHT to $TMP_HEIGHT"
        HEIGHT=$TMP_HEIGHT
    fi

    if ! timeout 0.1 nc -z $ip $DEFAULT_INTERX_PORT ; then echoWarn "WARNING: Port '$DEFAULT_INTERX_PORT' closed ($ip)" && continue ; fi
    if ! timeout 0.1 nc -z $ip $KIRA_SENTRY_P2P_PORT ; then echoWarn "WARNING: Port '$KIRA_SENTRY_P2P_PORT' closed ($ip)" && continue ; fi

    STATUS_URL="$ip:$DEFAULT_INTERX_PORT/api/status"
    STATUS=$(timeout 1 curl $STATUS_URL 2>/dev/null || echo -n "")
    if ($(isNullOrEmpty "$STATUS")) ; then echoWarn "WARNING: INTERX status not found ($ip)" && continue ; fi

    KIRA_STATUS_URL="$ip:$DEFAULT_INTERX_PORT/api/kira/status"
    KIRA_STATUS=$(timeout 1 curl $KIRA_STATUS_URL 2>/dev/null || echo -n "")
    if ($(isNullOrEmpty "$KIRA_STATUS")) ; then echoWarn "WARNING: Node status not found ($ip)" && continue  ; fi

    chain_id=$(echo "$STATUS" | grep -Eo '"chain_id"[^,]*' | grep -Eo '[^:]*$' | xargs || echo "")
    [ "$NETWORK_NAME" != "$chain_id" ] && echoWarn "WARNING: Invalid chain id '$chain_id' ($ip)" && continue 

    genesis_checksum=$(echo "$STATUS" | grep -Eo '"genesis_checksum"[^,]*' | grep -Eo '[^:]*$' | xargs || echo "")
    [ "$CHECKSUM" != "$genesis_checksum" ] && echoWarn "WARNING: Invalid genesis checksum '$genesis_checksum' ($ip)" && continue 
    
    node_id=$(echo "$KIRA_STATUS" | grep -Eo '"id"[^,]*' | grep -Eo '[^:]*$' | xargs || echo "")
    (! $(isNodeId "$node_id")) && echoWarn "WARNING: Invalid node id '$node_id' ($ip)" && continue

    if grep -q "$node_id" "$TMP_BOOK_PUBLIC"; then
        echoWarn "WARNING: Node id '$node_id' is already present in the address book ($ip)" && continue 
    fi

    catching_up=$(echo "$KIRA_STATUS" | grep -Eo '"catching_up"[^,]*' | grep -Eo '[^:]*$' | xargs || echo "")
    [ "$catching_up" != "false" ] && echoWarn "WARNING: Node is still catching up '$catching_up' ($ip)" && continue 

    latest_block_height=$(echo "$KIRA_STATUS" | grep -Eo '"latest_block_height"[^,]*' | grep -Eo '[^:]*$' | xargs || echo "")
    (! $(isNaturalNumber "$latest_block_height")) && echoWarn "WARNING: Inavlid block heigh '$latest_block_height' ($ip)" && continue 
    [ $latest_block_height -lt $HEIGHT ] && echoWarn "WARNING: Block heigh '$latest_block_height' older than latest '$HEIGHT' ($ip)" && continue 

    peer="$node_id@$ip:$KIRA_SENTRY_P2P_PORT"
    echoInfo "INFO: Active peer found: '$peer'"
    echo "$peer" >> $TMP_BOOK_PUBLIC
    i=$(($i + 1))
    if [ $i -ge 128 ] ; then
        echoWarn "WARNING: Peer limit (128) reached"
        break
    fi
done < $TMP_BOOK_SHUFF 

if ($(isFileEmpty $TMP_BOOK_PUBLIC)) || [ $i -le 0 ] ; then
    echoInfo "INFO: No public addresses were found in the '$TMP_BOOK_PUBLIC'"
    exit 0
fi

echoInfo "INFO: Sucessfully discovered '$i' public peers out of total '$total' in the address book, saving results to '$PEERS_SCAN_PATH' and '$INTERX_PEERS_PATH'"
cp -afv $TMP_BOOK_PUBLIC $PEERS_SCAN_PATH
cp -afv $TMP_BOOK_PUBLIC $INTERX_PEERS_PATH

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: PEERS MONITOR                      |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x

sleep 60