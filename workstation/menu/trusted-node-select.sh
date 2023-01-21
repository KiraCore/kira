#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/trusted-node-select.sh" && rm -f $FILE && touch $FILE && nano $FILE && chmod 555 $FILE
set +x

DEFAULT_INTERX_PORT="$(globGet DEFAULT_INTERX_PORT)"
CUSTOM_INTERX_PORT="$(globGet CUSTOM_INTERX_PORT)"
CUSTOM_RPC_PORT="$(globGet CUSTOM_RPC_PORT)"
DEFAULT_RPC_PORT="$(globGet DEFAULT_RPC_PORT)"
KIRA_SEED_RPC_PORT="$(globGet KIRA_SEED_RPC_PORT)"
KIRA_VALIDATOR_RPC_PORT="$(globGet KIRA_VALIDATOR_RPC_PORT)"
KIRA_SENTRY_RPC_PORT="$(globGet KIRA_SENTRY_RPC_PORT)"
TRUSTED_NODE_ADDR="$(globGet TRUSTED_NODE_ADDR)"

while : ; do
  if ($(isDnsOrIp "$TRUSTED_NODE_ADDR")) ; then 
      echoInfo "INFO: Previously trusted node address (default): $TRUSTED_NODE_ADDR"
      echoInfo "INFO: To reinitalize already existing node type: 0.0.0.0"
      echoNErr "Input address of the node you trust or choose [ENTER] for default: " && read v1 && v1=$(echo "$v1" | xargs)
      [ -z "$v1" ] && v1=$TRUSTED_NODE_ADDR
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
        [ ! -z "$STATUS" ] && TRUSTED_NODE_INTERX_PORT="$port" && break
    done

    echoInfo "INFO: Trusted node RPC port discovery..."

    # search rpc ports
    if [ -z "$STATUS" ] ; then
        RPC_PORTS=($NODE_ADDR_PORT $CUSTOM_RPC_PORT $DEFAULT_RPC_PORT $KIRA_SEED_RPC_PORT $KIRA_SENTRY_RPC_PORT $KIRA_VALIDATOR_RPC_PORT)
        for port in "${INTERX_PORTS[@]}" ; do
            echoInfo "INFO: Testing rpc port '$port' for status..."
            ($(isNullOrWhitespaces "$STATUS")) && STATUS=$(timeout 15 curl --fail "$NODE_ADDR:$port/status" 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")
            CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null || echo -n "")
            ($(isNullOrWhitespaces "$CHAIN_ID")) && STATUS=""
            [ ! -z "$STATUS" ] && TRUSTED_NODE_RPC_PORT="$port" && break
        done
    fi

  HEIGHT=$(echo "$STATUS" | jsonQuickParse "latest_block_height" 2> /dev/null || echo -n "")
  CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null || echo -n "")

  if [ "${REINITALIZE_NODE,,}" == "true" ] && ( ($(isNullOrWhitespaces "$CHAIN_ID")) || (! $(isNaturalNumber "$HEIGHT")) ) ; then
      HEIGHT=$(globGet LATEST_BLOCK_HEIGHT "$GLOBAL_COMMON_RO") && (! $(isNaturalNumber "$HEIGHT")) && HEIGHT="0"
      CHAIN_ID=$NETWORK_NAME && ($(isNullOrWhitespaces "$NETWORK_NAME")) && NETWORK_NAME="unknown"
  fi

  if ($(isNullOrWhitespaces "$CHAIN_ID")) || (! $(isNaturalNumber "$HEIGHT")) ; then
      echoWarn "WARNING: Could NOT read status, block height or chian-id"
      echoErr "ERROR: Address '$NODE_ADDR' is NOT a valid, publicly exposed public node address"
      continue
  fi

  globSet "TRUSTED_NODE_GENESIS" ""
  globSet "TRUSTED_NODE_GENESIS_HASH" ""
  globSet "TRUSTED_NODE_ADDR" "$NODE_ADDR"
  globSet "TRUSTED_NODE_ID" ""
  globSet "TRUSTED_NODE_P2P_PORT" ""
  globSet "TRUSTED_NODE_RPC_PORT" "$TRUSTED_NODE_RPC_PORT"
  globSet "TRUSTED_NODE_INTERX_PORT" "$TRUSTED_NODE_INTERX_PORT"
  
  break
done

TRUSTED_NODE_ADDR="$(globGet TRUSTED_NODE_ADDR)"
TRUSTED_NODE_INTERX_PORT="$(globGet TRUSTED_NODE_INTERX_PORT)"
TRUSTED_NODE_RPC_PORT="$(globGet TRUSTED_NODE_RPC_PORT)" && [ -z "$TRUSTED_NODE_RPC_PORT" ] && TRUSTED_NODE_RPC_PORT=0

CUSTOM_P2P_PORT="$(globGet CUSTOM_P2P_PORT)"
DEFAULT_P2P_PORT="$(globGet DEFAULT_P2P_PORT)"
KIRA_SEED_P2P_PORT="$(globGet KIRA_SEED_P2P_PORT)"
KIRA_VALIDATOR_P2P_PORT="$(globGet KIRA_VALIDATOR_P2P_PORT)"
KIRA_SENTRY_P2P_PORT="$(globGet KIRA_SENTRY_P2P_PORT)"

P2P_PORTS=($CUSTOM_P2P_PORT $DEFAULT_P2P_PORT $KIRA_SEED_P2P_PORT $KIRA_VALIDATOR_P2P_PORT $KIRA_SENTRY_P2P_PORT $((TRUSTED_NODE_RPC_PORT - 1)))

# RPC port can be discovered from the node status message
if (! $(isPort "$TRUSTED_NODE_RPC_PORT")) ; then
    LISTEN_ADDR=$(echo "$STATUS" | jsonParse "node_info.listen_addr" 2>/dev/null || echo -n "")
    LISTEN_PORT=$(strSplitTakeN : 1 "$LISTEN_ADDR")
    if ($(isPort "$LISTEN_PORT")) ; then
        TRUSTED_NODE_RPC_PORT="$LISTEN_PORT"
        globSet "TRUSTED_NODE_RPC_PORT" "$LISTEN_PORT"
        P2P_PORTS+=($((LISTEN_PORT - 1)))
    fi
fi

echoInfo "INFO: Trusted node P2P port discovery..."

for port in "${P2P_PORTS[@]}" ; do
    echoInfo "INFO: Testing p2p port '$port' for access..."
    TRUSTED_NODE_ID=$(tmconnect id --address="$TRUSTED_NODE_ADDR:$port" --node_key="$KIRA_SECRETS/test_node_key.json" --timeout=3 || echo "")
    if ($(isNodeId "$TRUSTED_NODE_ID")) ; then
        globSet TRUSTED_NODE_ID "$TRUSTED_NODE_ID"
        globSet "TRUSTED_NODE_P2P_PORT" "$port"
        break
    fi
done

echoInfo "INFO: Genesis file search..."

GENSUM=""
GENESIS_FILE="$(globFile TRUSTED_NODE_GENESIS)"
if ($(isPort "$TRUSTED_NODE_INTERX_PORT")) ; then
    GENSUM=$(timeout 120 curl $TRUSTED_NODE_ADDR:$TRUSTED_NODE_INTERX_PORT/api/gensum 2>/dev/null | jsonParse "checksum" | sed 's/^0x//' 2>/dev/null || echo -n "")
    ($(isSHA256 $GENSUM)) && safeWget "$GENESIS_FILE" $TRUSTED_NODE_ADDR:$TRUSTED_NODE_INTERX_PORT/api/genesis $GENSUM || globDel TRUSTED_NODE_GENESIS
fi

if ($(isSHA256 $GENSUM)) && (! $(isFileEmpty $GENESIS_FILE)) ; then
    globSet "TRUSTED_NODE_GENESIS_HASH" "$GENSUM"
fi

