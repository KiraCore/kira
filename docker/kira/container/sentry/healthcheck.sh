#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
set -x

LIP_FILE="$COMMON_READ/local_ip"
PIP_FILE="$COMMON_READ/public_ip"
EXCEPTION_COUNTER_FILE="$COMMON_DIR/exception_counter"
COMMON_CONSENSUS="$COMMON_READ/consensus"
COMMON_LATEST_BLOCK_HEIGHT="$COMMON_READ/latest_block_height"
BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height"
EXECUTED_CHECK="$COMMON_DIR/executed"

touch "$BLOCK_HEIGHT_FILE" "$EXCEPTION_COUNTER_FILE"

EXCEPTION_COUNTER=$(cat $EXCEPTION_COUNTER_FILE || echo "")
LATEST_BLOCK_HEIGHT=$(cat $COMMON_LATEST_BLOCK_HEIGHT || echo "")
CONSENSUS=$(cat $COMMON_CONSENSUS | jq -rc || echo "")
CONSENSUS_STOPPED=$(echo "$CONSENSUS" | jq -rc '.consensus_stopped' || echo "")
HEIGHT=$(sekaid status 2>&1 | jq -rc '.SyncInfo.latest_block_height' || echo "")

(! $(isNaturalNumber "$EXCEPTION_COUNTER")) && EXCEPTION_COUNTER=0
(! $(isNaturalNumber "$HEIGHT")) && HEIGHT=$(sekaid status 2>&1 | jq -rc '.sync_info.latest_block_height' || echo "")
(! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0
(! $(isNaturalNumber "$LATEST_BLOCK_HEIGHT")) && LATEST_BLOCK_HEIGHT=0

PREVIOUS_HEIGHT=$(cat $BLOCK_HEIGHT_FILE)
echo "$HEIGHT" > $BLOCK_HEIGHT_FILE
(! $(isNaturalNumber "$PREVIOUS_HEIGHT")) && PREVIOUS_HEIGHT=0

if [ $PREVIOUS_HEIGHT -ge $HEIGHT ]; then
  echoWarn "WARNING: Blocks are not beeing produced or synced"
  echoWarn "WARNING: Current height: $HEIGHT"
  echoWarn "WARNING: Previous height: $PREVIOUS_HEIGHT"
  echoWarn "WARNING: Latest height: $LATEST_BLOCK_HEIGHT"
  echoWarn "WARNING: Consensus Stopped: $CONSENSUS_STOPPED"

  if [ $LATEST_BLOCK_HEIGHT -ge 1 ] && [ $LATEST_BLOCK_HEIGHT -le $HEIGHT ] && [ "$CONSENSUS_STOPPED" == "true" ] ; then
      echoWarn "WARNINIG: Cosnensus halted, lack of block production is not result of the issue with the node"
  else
      EXCEPTION_COUNTER=$(($i + 1))
      if [ $EXCEPTION_COUNTER -ge 4 ] ; then
          echoWarn "WARNINIG: Node will be setup from scratch during future restart"
          echo "0" > $EXCEPTION_COUNTER_FILE
          rm -fv $EXECUTED_CHECK
      else
          echo "$EXCEPTION_COUNTER" > $EXCEPTION_COUNTER_FILE
      fi
      exit 1
  fi
else
  echoInfo "INFO, Success, new blocks were created or synced: $HEIGHT"
fi

echoInfo "INFO: Latest Block Height: $HEIGHT"

if [ ! -z "$EXTERNAL_ADDR" ] && [ "$EXTERNAL_ADDR" != "0.0.0.0" ] ; then
    echoInfo "INFO: Checking availability of the external address '$EXTERNAL_ADDR'"
    LOCAL_IP=$(cat $LIP_FILE || echo "")
    PUBLIC_IP=$(cat $PIP_FILE || echo "")
    echoInfo "INFO: Local IP: $LOCAL_IP"
    echoInfo "INFO: Public IP: $PUBLIC_IP"

    if timeout 2 nc -z $PUBLIC_IP $EXTERNAL_P2P_PORT ; then 
        echoInfo "INFO: Success, your node external address '$EXTERNAL_ADDR' is exposed to the internet"
        echo "ONLINE" > "$COMMON_DIR/external_address_status"
    elif timeout 2 nc -z $LOCAL_IP $EXTERNAL_P2P_PORT ; then 
        echoWarn "WARNINIG: Your node external address is only exposed to the local networks!"
        echo "LOCAL" > "$COMMON_DIR/external_address_status"
    else
        echoErr "ERROR: Your node external address is not visible to other nodes, failed to diall '$EXTERNAL_ADDR:$EXTERNAL_P2P_PORT'"
        echo "OFFLINE" > "$COMMON_DIR/external_address_status"
        exit 1
    fi
else
    echoWarn "WARNING: This node is NOT advertising its it's public or local external address to other nodes in the network!"
    echo "OFFLINE" > "$COMMON_DIR/external_address_status"
fi

echo "0" > $EXCEPTION_COUNTER_FILE
exit 0