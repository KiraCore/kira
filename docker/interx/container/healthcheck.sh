#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
exec 2>&1
set -x

timerStart HEALTHCHECK

BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height" 
COMMON_CONSENSUS="$COMMON_READ/consensus"
COMMON_LATEST_BLOCK_HEIGHT="$COMMON_READ/latest_block_height"

HALT_CHECK="${COMMON_DIR}/halt"
EXIT_CHECK="${COMMON_DIR}/exit"

LIP_FILE="$COMMON_READ/local_ip"
PIP_FILE="$COMMON_READ/public_ip"

LOCAL_IP=$(tryCat $LIP_FILE)
PUBLIC_IP=$(tryCat $PIP_FILE)

set +x
echoWarn "------------------------------------------------"
echoWarn "|   STARTED: HEALTHCHECK                       |"
echoWarn "|----------------------------------------------|"
echoWarn "| PUBLIC IP: $PUBLIC_IP"
echoWarn "|  LOCAL IP: $LOCAL_IP"
echoWarn "------------------------------------------------"
set -x

if [ -f "$EXIT_CHECK" ]; then
  echo "INFO: Ensuring interxd process is killed"
  touch $HALT_CHECK
  pkill -15 interxd || echo "WARNING: Failed to kill interxd"
  rm -fv $EXIT_CHECK
fi

touch $BLOCK_HEIGHT_FILE

if [ -f "$HALT_CHECK" ]; then
    echoWarn "INFO: Contianer is halted!"
    echo "OFFLINE" > "$COMMON_DIR/external_address_status"
    sleep 1
    exit 0
fi

echoInfo "INFO: Healthcheck => START"
sleep 30 # rate limit

find "/var/log" -type f -size +1M -exec truncate --size=1M {} + || echoWarn "WARNING: Failed to truncate system logs"
find "/var/log/journal" -type f -size +256k -exec truncate --size=128k {} + || echoWarn "WARNING: Failed to truncate journal"
find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echoWarn "WARNING: Failed to truncate self logs"
find "$COMMON_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echoWarn "WARNING: Failed to truncate common logs"

VERSION_EXT=$(timeout 8 curl --fail $PUBLIC_IP:$EXTERNAL_API_PORT/api/kira/status | jsonQuickParse "interx_version" || echo -n "")
VERSION_INT=$(timeout 8 curl --fail $LOCAL_IP:$EXTERNAL_API_PORT/api/kira/status | jsonQuickParse "interx_version" || echo -n "")
VERSION_LOC=$(timeout 8 curl --fail interx.local:$INTERNAL_API_PORT/api/kira/status | jsonQuickParse "interx_version" || echo -n "")

if [ -z "$VERSION_EXT" ] ; then
    echoInfo "INFO: External interx status found"
    echo "$PUBLIC_IP:$EXTERNAL_API_PORT " > "$COMMON_DIR/external_address"
elif [ -z "$VERSION_INT" ] ; then
    echoInfo "INFO: Internal interx status found"
    echo "$LOCAL_IP:$EXTERNAL_API_PORT" > "$COMMON_DIR/external_address"
elif [ -z "$VERSION_INT" ] ;then
    echoInfo "INFO: Local interx status found"
    echo "interx.local:$INTERNAL_API_PORT" > "$COMMON_DIR/external_address"
else
    echoErr "ERROR: Unknown Status Codes: '$INDEX_STATUS_CODE_EXT' EXTERNAL, '$INDEX_STATUS_CODE_INT' INTERNAL, '$INDEX_STATUS_CODE_LOC' LOCAL"
    echo "OFFLINE" > "$COMMON_DIR/external_address_status"
    exit 1
fi


(! $(isNaturalNumber "$HEIGHT")) && HEIGHT=0
(! $(isNaturalNumber "$LATEST_BLOCK_HEIGHT")) && LATEST_BLOCK_HEIGHT=0

PREVIOUS_HEIGHT=$(cat $BLOCK_HEIGHT_FILE)
echo "$HEIGHT" >$BLOCK_HEIGHT_FILE
(! $(isNaturalNumber "$PREVIOUS_HEIGHT")) && PREVIOUS_HEIGHT=0

if [[ $PREVIOUS_HEIGHT -ge $HEIGHT ]]; then
    echoWarn "WARNING: Blocks are not beeing produced or synced"
    echoWarn "WARNING: Current height: $HEIGHT"
    echoWarn "WARNING: Previous height: $PREVIOUS_HEIGHT"
    echoWarn "WARNING: Latest height: $LATEST_BLOCK_HEIGHT"
    echoWarn "WARNING: Consensus Stopped: $CONSENSUS_STOPPED"

    if [[ $LATEST_BLOCK_HEIGHT -ge 1 ]] && [[ $LATEST_BLOCK_HEIGHT -le $HEIGHT ]] && [ "$CONSENSUS_STOPPED" == "true" ] ; then
        echoWarn "WARNINIG: Cosnensus halted, lack of block production is not result of the issue with the node"
    else
        echo "OFFLINE" > "$COMMON_DIR/external_address_status"
        exit 1
    fi
else
  echoInfo "INFO: Success, new blocks were created or synced: $HEIGHT"
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: HEALTHCHECK                        |"
echoWarn "|  ELAPSED: $(timerSpan HEALTHCHECK) seconds"
echoWarn "------------------------------------------------"
set -x
exit 0
