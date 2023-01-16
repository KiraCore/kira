#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/trusted-node-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set +x

while : ; do
  if [ ! -z "$(globGet TRUSTED_NODE_ADDR)" ] ; then 
      echoInfo "INFO: Previously trusted node address (default): $(globGet TRUSTED_NODE_ADDR)"
      echoInfo "INFO: To reinitalize already existing node type: 0.0.0.0"
      echoNErr "Input address (IP/DNS) of the public node you trust or choose [ENTER] for default: " && read v1 && v1=$(echo "$v1" | xargs)
      [ -z "$v1" ] && v1=$(globGet TRUSTED_NODE_ADDR) || v1=$(resolveDNS "$v1")
  else
      echoInfo "INFO: To reinitalize already existing node type: 0.0.0.0"
      echoNErr "Input address (IP/DNS) of the public node you trust: " && read v1
  fi

  ($(isDnsOrIp "$v1")) && NODE_ADDR="$v1" || NODE_ADDR="" 
  [ -z "$NODE_ADDR" ] && echoWarn "WARNING: Value '$v1' is not a valid DNS name or IP address, try again!" && continue

  echoInfo "INFO: Please wait, testing connectivity..."
  if ! timeout 2 ping -c1 "$NODE_ADDR" &>/dev/null ; then
      echoWarn "WARNING: Address '$NODE_ADDR' could NOT be reached, check your network connection or select diffrent node" 
      continue
  else
      echoInfo "INFO: Success, node '$NODE_ADDR' is online!"
  fi

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

  ($(isNullOrWhitespaces "$STATUS")) && STATUS=$(timeout 15 curl --fail "$NODE_ADDR:$(globGetKIRA_SENTRY_RPC_PORT)/status" 2>/dev/null | jsonParse "result" 2>/dev/null || echo -n "")

  HEIGHT=$(echo "$STATUS" | jsonQuickParse "latest_block_height" 2> /dev/null || echo -n "")
  CHAIN_ID=$(echo "$STATUS" | jsonQuickParse "network" 2>/dev/null|| echo -n "")

  if [ "${REINITALIZE_NODE,,}" == "true" ] && ( ($(isNullOrWhitespaces "$CHAIN_ID")) || (! $(isNaturalNumber "$HEIGHT")) ) ; then
      HEIGHT=$(globGet LATEST_BLOCK_HEIGHT "$GLOBAL_COMMON_RO") && (! $(isNaturalNumber "$HEIGHT")) && HEIGHT="0"
      CHAIN_ID=$NETWORK_NAME && ($(isNullOrWhitespaces "$NETWORK_NAME")) && NETWORK_NAME="unknown"
  fi

  if ($(isNullOrWhitespaces "$CHAIN_ID")) || (! $(isNaturalNumber "$HEIGHT")) ; then
      echoWarn "WARNING: Could NOT read status, block height or chian-id"
      echoErr "ERROR: Address '$NODE_ADDR' is NOT a valid, publicly exposed public node address"
      continue
  fi

  globSet "TRUSTED_NODE_ADDR" "$NODE_ADDR"
  break
done