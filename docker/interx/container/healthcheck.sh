#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
exec 2>&1
set -x

HALT_CHECK="${COMMON_DIR}/halt"
BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height" 
COMMON_CONSENSUS="$COMMON_READ/consensus"
COMMON_LATEST_BLOCK_HEIGHT="$COMMON_READ/latest_block_height"

touch $BLOCK_HEIGHT_FILE

if [ -f "$HALT_CHECK" ]; then
  exit 0
fi

echoinfo "INFO: Healthcheck => START"
sleep 30 # rate limit

find "/var/log/journal" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate journal"
find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate self logs"
find "$COMMON_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echo "INFO: Failed to truncate common logs"

LATEST_BLOCK_HEIGHT=$(cat $COMMON_LATEST_BLOCK_HEIGHT || echo "")
CONSENSUS=$(cat $COMMON_CONSENSUS | jq -rc || echo "")
CONSENSUS_STOPPED=$(echo "$CONSENSUS" | jq -rc '.consensus_stopped' || echo "")
HEIGHT=$(curl 127.0.0.1:11000/api/kira/status 2>/dev/null | jq -rc '.SyncInfo.latest_block_height' 2>/dev/null || echo "")

(! $(isNaturalNumber "$HEIGHT")) && HEIGHT=$(curl 127.0.0.1:11000/api/kira/status 2>/dev/null | jq -rc '.sync_info.latest_block_height' 2>/dev/null || echo "")
(! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0
(! $(isNaturalNumber "$LATEST_BLOCK_HEIGHT")) && LATEST_BLOCK_HEIGHT=0

PREVIOUS_HEIGHT=$(cat $BLOCK_HEIGHT_FILE)
echo "$HEIGHT" >$BLOCK_HEIGHT_FILE
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
        exit 1
    fi
else
  echoInfo "INFO: Success, new blocks were created or synced: $HEIGHT"
fi

echoinfo "INFO: Latest Block Height: $HEIGHT"
exit 0