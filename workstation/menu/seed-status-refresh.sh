#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/seed-status-refresh.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set +x

NODE_ADDR=$(globGet TRUSTED_NODE_ADDR)
[ -z "$NODE_ADDR" ] && NODE_ADDR="0.0.0.0"

echoInfo "INFO: Please wait, testing connectivity..."
if ! timeout 2 ping -c1 "$NODE_ADDR" &>/dev/null ; then
    echoWarn "WARNING: Address '$NODE_ADDR' could NOT be reached, check your network connection or select diffrent node" 
    STATUS=""
    CHAIN_ID="???"
    HEIGHT="0"
else
    echoInfo "INFO: Success, node '$NODE_ADDR' is online!"
    STATUS=$(timeout 15 curl "$NODE_ADDR:$(globGet DEFAULT_INTERX_PORT)/api/kira/status" 2>/dev/null | jsonParse "" 2>/dev/null || echo -n "")
    CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null|| echo -n "") && ($(isNullOrWhitespaces "$CHAIN_ID")) && STATUS=""

    STATUS=$(timeout 15 curl "$NODE_ADDR:$(globGet CUSTOM_INTERX_PORT)/api/kira/status" 2>/dev/null | jsonParse "" 2>/dev/null || echo -n "")
    CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null|| echo -n "") && ($(isNullOrWhitespaces "$CHAIN_ID")) && STATUS=""

    ($(isNullOrWhitespaces "$STATUS")) && STATUS=$(timeout 15 curl --fail "$NODE_ADDR:$(globGet CUSTOM_RPC_PORT)/status" 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")
    CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null|| echo -n "") && ($(isNullOrWhitespaces "$CHAIN_ID")) && STATUS=""

    ($(isNullOrWhitespaces "$STATUS")) && STATUS=$(timeout 15 curl --fail "$NODE_ADDR:$(globGet KIRA_SEED_RPC_PORT)/status" 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")
    CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null|| echo -n "") && ($(isNullOrWhitespaces "$CHAIN_ID")) && STATUS=""

    ($(isNullOrWhitespaces "$STATUS")) && STATUS=$(timeout 15 curl --fail "$NODE_ADDR:$(globGet KIRA_VALIDATOR_RPC_PORT)/status" 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")
    CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null|| echo -n "") && ($(isNullOrWhitespaces "$CHAIN_ID")) && STATUS=""

    ($(isNullOrWhitespaces "$STATUS")) && STATUS=$(timeout 15 curl --fail "$NODE_ADDR:$(globGet KIRA_SENTRY_RPC_PORT)/status" 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")

    HEIGHT=$(echo "$STATUS" | jsonQuickParse "latest_block_height" 2> /dev/null || echo -n "")
    CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null|| echo -n "")

    if [ "$NODE_ADDR" == "0.0.0.0" ] && ( ($(isNullOrWhitespaces "$CHAIN_ID")) || (! $(isNaturalNumber "$HEIGHT")) ) ; then
        HEIGHT=$(globGet LATEST_BLOCK_HEIGHT "$GLOBAL_COMMON_RO") && (! $(isNaturalNumber "$HEIGHT")) && HEIGHT="0"
        CHAIN_ID=$NETWORK_NAME && ($(isNullOrWhitespaces "$NETWORK_NAME")) && NETWORK_NAME="???"
    fi

    if ($(isNullOrWhitespaces "$CHAIN_ID")) || (! $(isNaturalNumber "$HEIGHT")) ; then
        echoWarn "WARNING: Could NOT read status, block height or chian-id"
        echoErr "ERROR: Address '$NODE_ADDR' is NOT a valid, publicly exposed public node address"
        STATUS=""
        ($(isNullOrWhitespaces "$NETWORK_NAME")) && CHAIN_ID="???"
        HEIGHT="0"
    fi
fi

globSet "TRUSTED_NODE_STATUS" "$STATUS"
globSet "TRUSTED_NODE_CHAIN_ID" "$CHAIN_ID"
globSet "TRUSTED_NODE_HEIGHT" "$HEIGHT"

echoInfo "INFO: Please wait, testing snapshot access..."
SNAP_SIZE="0"
SNAP_URL="$NODE_ADDR:$(globGet DEFAULT_INTERX_PORT)/download/snapshot.tar"
if ($(urlExists "$SNAP_URL")) ; then
    SNAP_SIZE=$(urlContentLength "$SNAP_URL") && (! $(isNaturalNumber $SNAP_SIZE)) && SNAP_SIZE=0
    echoInfo "INFO: Node '$NODE_ADDR' is exposing $SNAP_SIZE Bytes snapshot"
fi

if [[ $SNAP_SIZE -le 0 ]] ; then
    SNAP_URL=""
    SNAP_SIZE="0"
fi

globSet "TRUSTED_SNAP_URL" "$SNAP_URL"
globSet "TRUSTED_SNAP_SIZE" "$SNAP_SIZE"