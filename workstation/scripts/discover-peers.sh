#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/scripts/discover-peers.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

# e.g. $KIRA_MANAGER/scripts/discover-peers.sh 18.168.78.192 /tmp/pdump true false 16

ADDR=$1
OUTPUT=$2
SNAPS_ONLY=$3
PEERS_ONLY=$4
LIMIT=$5
[ -z "$SNAPS_ONLY" ] && SNAPS_ONLY="false"
[ -z "$PEERS_ONLY" ] && PEERS_ONLY="false"
(! $(isNaturalNumber "$LIMIT")) && LIMIT="0"

SCRIPT_START_TIME="$(date -u +%s)"

TMP_OUTPUT="${OUTPUT}.tmp" 
TMP_PEERS="/tmp/$ADDR.peers"
TMP_PEERS_SHUFF="/tmp/$ADDR.peers.shuff"
URL_PEERS="$ADDR:$DEFAULT_INTERX_PORT/download/peers.txt"
URL_SNAPS="$ADDR:$DEFAULT_INTERX_PORT/download/snaps.txt"

LATEST_BLOCK_SCAN_PATH="$KIRA_SCAN/latest_block"

set +x
echoWarn "------------------------------------------------"
echoWarn "|   STARTING KIRA PUBLIC PEERS SCAN v0.2.2.3   |"
echoWarn "|-----------------------------------------------"
echoWarn "|       SEED ADDRESS: $ADDR"
echoWarn "|        OUTPUT PATH: $OUTPUT"
echoWarn "|  EXPOSED SNAP ONLY: $SNAPS_ONLY"
echoWarn "| EXPOSED PEERS ONLY: $PEERS_ONLY"
echoWarn "|       OUTPUT LIMIT: $LIMIT"
echoWarn "|          PEERS URL: $URL_PEERS"
echoWarn "|          SNAPS URL: $URL_SNAPS"
echoWarn "------------------------------------------------"
set -x

echoInfo "INFO: Fetching peers file..."
rm -fv $TMP_PEERS
DOWNLOAD_SUCCESS="true" && wget $URL_PEERS -O $TMP_PEERS || DOWNLOAD_SUCCESS="false"

if ($(isFileEmpty $TMP_PEERS)) || [ "${DOWNLOAD_SUCCESS,,}" == "false" ] ; then
    echoErr "ERROR: Discovery address '$ADDR' is not exposing public peers list"
    rm -fv $TMP_PEERS
    exit 1
fi

BASE_STATUS=$(timeout 10 curl $ADDR:$DEFAULT_INTERX_PORT/api/status 2>/dev/null || echo -n "")
if ($(isNullOrEmpty "$BASE_STATUS")) ; then echoWarn "WARNING: INTERX status not found ($ADDR)" && exit 1 ; fi

BASE_KIRA_STATUS=$(timeout 10 curl "$ADDR:$DEFAULT_INTERX_PORT/api/kira/status" 2>/dev/null || echo -n "")
if ($(isNullOrEmpty "$BASE_KIRA_STATUS")) ; then echoWarn "WARNING: Node status not found ($ADDR)" && exit 1 ; fi

NETWORK_NAME=$(echo "$BASE_STATUS" | jsonQuickParse "chain_id" || echo "")
if ($(isNullOrEmpty "$BASE_KIRA_STATUS")) ; then echoWarn "WARNING: Network name not found ($ADDR)" && exit 1 ; fi

CHECKSUM=$(echo "$BASE_STATUS" | jsonQuickParse "genesis_checksum" || echo "")
if ($(isNullOrEmpty "$CHECKSUM")) ; then echoWarn "WARNING: Genesis checksum not found ($ADDR)" && exit 1 ; fi

MIN_HEIGHT=$(echo "$BASE_KIRA_STATUS"  | jsonQuickParse "latest_block_height" || echo "")
if (! $(isNaturalNumber "$MIN_HEIGHT")) ; then echoWarn "WARNING: Latest block height not found ($ADDR)" && exit 1 ; fi

echoInfo "INFO: Processing peers list..."
rm -fv "$TMP_PEERS_SHUFF" "$OUTPUT" "$TMP_OUTPUT"
shuf $TMP_PEERS > $TMP_PEERS_SHUFF && rm -fv $TMP_PEERS
touch $OUTPUT $TMP_OUTPUT

i=0
total=0
HEIGHT=0

# max_txs_bytes == MAX_BLOCK_SIZE
MAX_BLOCK_SIZE="131072000"
MIN_SNAP_SIZE="524288"

while : ; do
    total=$(($total + 1))
    peer=$(sed "${total}q;d" $TMP_PEERS_SHUFF | xargs || echo "")
    [ -z "$peer" ] && echoWarn "WARNING: Peers list ended" && break
    set +x
    addrArr1=( $(echo $peer | tr "@" "\n") )
    addrArr2=( $(echo ${addrArr1[1]} | tr ":" "\n") )
    nodeId=${addrArr1[0],,}
    ip=${addrArr2[0],,}
    port=${addrArr2[1],,}

    (! $(isPublicIp $ip)) && echoWarn "WARNING: Not a valid public ip ($ip)" && continue
    (! $(isNodeId "$nodeId")) && echoWarn "WARNING: Invalid node id '$nodeId' ($ip)" && continue 

    if grep -q "$nodeId" "$OUTPUT"; then
        echoWarn "WARNING: Node id '$nodeId' is already present in the seeds list ($ip)" && continue 
    fi

    if grep -q "$ip" "$OUTPUT"; then
        echoWarn "WARNING: Address '$ip' is already present in the seeds list" && continue 
    fi

    TMP_HEIGHT=$(cat $LATEST_BLOCK_SCAN_PATH || echo "")
    if ($(isNaturalNumber "$TMP_HEIGHT")) && [[ $TMP_HEIGHT -gt $HEIGHT ]] ; then
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
    if ($(isNullOrEmpty "$KIRA_STATUS")) ; then echoWarn "WARNING: Node status not found ($ip)" && continue ; fi
    
    chain_id=$(echo "$STATUS" | jsonQuickParse "chain_id" || echo "")
    [ "$NETWORK_NAME" != "$chain_id" ] && echoWarn "WARNING: Invalid chain id '$chain_id' ($ip)" && continue 

    genesis_checksum=$(echo "$STATUS" | jsonQuickParse "genesis_checksum" || echo "")
    [ "$CHECKSUM" != "$genesis_checksum" ] && echoWarn "WARNING: Invalid genesis checksum, expected '', but got '$genesis_checksum' ($ip)" && continue 
    
    node_id=$(echo "$KIRA_STATUS" | jsonQuickParse "id" || echo "")
    (! $(isNodeId "$node_id")) && echoWarn "WARNING: Invalid node id '$node_id' ($ip)" && continue
    [ "$node_id" != "$nodeId" ] && echoWarn "WARNING: Diffrent node id was advertised, got '$node_id' but expected '$nodeId' ($ip)" && continue

    catching_up=$(echo "$KIRA_STATUS" | jsonQuickParse "catching_up" || echo "")
    [ "$catching_up" != "false" ] && echoWarn "WARNING: Node is still catching up '$catching_up' ($ip)" && continue 

    latest_block_height=$(echo "$KIRA_STATUS"  | jsonQuickParse "latest_block_height" || echo "")
    (! $(isNaturalNumber "$latest_block_height")) && echoWarn "WARNING: Inavlid block heigh '$latest_block_height' ($ip)" && continue 
    [[ $(($latest_block_height + 1)) -lt $MIN_HEIGHT ]] && echoWarn "WARNING: Expected minimum block height to be $MIN_HEIGHT but got $latest_block_height ($ip)" && continue

    if [ "${PEERS_ONLY,,}" == "true" ] && (! $(urlExists "$ip:$DEFAULT_INTERX_PORT/download/peers.txt")); then
        echoWarn "WARNING: Peer is not exposing peers list ($ip)"
        continue 
    fi

    if [ "${SNAPS_ONLY,,}" == "true" ] && (! $(urlExists "$ip:$DEFAULT_INTERX_PORT/download/snaps.txt")); then
        echoWarn "WARNING: Peer is not exposing snaps list ($ip)"
        continue 
    fi

    SNAP_URL="$ip:$DEFAULT_INTERX_PORT/download/snapshot.zip"
    if [ "${SNAPS_ONLY,,}" == "true" ] ; then
        if (! $(urlExists "$SNAP_URL")) ; then
            echoWarn "WARNING: Peer is not exposing snapshots ($ip)"
            continue 
        else
            SIZE=$(urlContentLength "$SNAP_URL")
            MAX_SNAP_SIZE=$((($latest_block_height * $MAX_BLOCK_SIZE) + 524288))
            if [[ $SIZE -gt $MAX_SNAP_SIZE ]] ; then
                echoWarn "WARNING: Snap size $SIZE is out of upper safe download range $MAX_SNAP_SIZE ($ip)"
                continue
            elif [[ $SIZE -lt $MIN_SNAP_SIZE ]] ; then
                echoWarn "WARNING: Snap size $SIZE is out of lower safe download range $MIN_SNAP_SIZE ($ip)"
                continue
            fi

            # if large snapshot was already found do not record smaller ones
            MIN_SNAP_SIZE=$SIZE
            peer="${peer} $SIZE"
        fi
    fi

    i=$(($i + 1))
    echo "$peer" >> $OUTPUT
    echoInfo "INFO: Active peer found: $peer"

    if [[ $LIMIT -gt 0 ]] && [[ $i -ge $LIMIT ]] ; then
        echoInfo "INFO: Peer discovery limit ($LIMIT) reached."
        break
    fi
done 

if ($(isFileEmpty $OUTPUT)) || [[ $i -le 0 ]] ; then
    echoInfo "INFO: No public peers were discovered"
    exit 0
fi

if [ "${SNAPS_ONLY,,}" == "true" ] && [[ $i -gt 1 ]] ; then
    echoInfo "INFO: Sorting peers by snapshot size"
    sort -nrk2 -n $OUTPUT > $TMP_OUTPUT
    cat $TMP_OUTPUT | cut -d ' ' -f1 > $OUTPUT
fi

echoInfo "INFO: Printing results:"
cat $OUTPUT
echoInfo "INFO: Sucessfully discovered $i public peers out of total $total from the list, results are saved to '$OUTPUT'"
rm -fv $TMP_PEERS_SHUFF $TMP_OUTPUT

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: PEERS DISCOVERY & VERIFICATION     |"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
set -x
