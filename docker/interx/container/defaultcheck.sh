#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
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
    sleep 5
    exit 0
fi

echoInfo "INFO: Healthcheck => START"
sleep 15 # rate limit

find "$SELF_LOGS" -type f -size +16M -exec truncate --size=8M {} + || echoWarn "WARNING: Failed to truncate self logs"
find "$COMMON_LOGS" -type f -size +16M -exec truncate --size=8M {} + || echoWarn "WARNING: Failed to truncate common logs"
journalctl --vacuum-time=3d --vacuum-size=32M || echoWarn "WARNING: journalctl vacuum failed"
find "/var/log" -type f -size +64M -exec truncate --size=8M {} + || echoWarn "WARNING: Failed to truncate system logs"

VERSION_EXT=$(timeout 8 curl --fail $PUBLIC_IP:$EXTERNAL_API_PORT/api/kira/status | jsonQuickParse "interx_version" || echo -n "")
VERSION_INT=$(timeout 8 curl --fail $LOCAL_IP:$EXTERNAL_API_PORT/api/kira/status | jsonQuickParse "interx_version" || echo -n "")
VERSION_LOC=$(timeout 8 curl --fail interx.local:$INTERNAL_API_PORT/api/kira/status | jsonQuickParse "interx_version" || echo -n "")

if [ -z "$VERSION_EXT" ] ; then
    echoInfo "INFO: External interx status found"
    echo "$PUBLIC_IP:$EXTERNAL_API_PORT " > "$COMMON_DIR/external_address"
    echo "ONLINE" > "$COMMON_DIR/external_address_status"
elif [ -z "$VERSION_INT" ] ; then
    echoInfo "INFO: Internal interx status found"
    echo "$LOCAL_IP:$EXTERNAL_API_PORT" > "$COMMON_DIR/external_address"
    echo "ONLINE" > "$COMMON_DIR/external_address_status"
elif [ -z "$VERSION_INT" ] ;then
    echoInfo "INFO: Local interx status found"
    echo "interx.local:$INTERNAL_API_PORT" > "$COMMON_DIR/external_address"
    echo "ONLINE" > "$COMMON_DIR/external_address_status"
else
    echoErr "ERROR: Unknown Status Codes: '$INDEX_STATUS_CODE_EXT' EXTERNAL, '$INDEX_STATUS_CODE_INT' INTERNAL, '$INDEX_STATUS_CODE_LOC' LOCAL"
    echo "OFFLINE" > "$COMMON_DIR/external_address_status"
    sleep 5
    exit 1
fi

if ! ping -c1 $PING_TARGET &>/dev/null ; do
    echoErr "ERROR: Ping target $PING_TARGET is unavilable ($(date))"
    sleep 5
    exit 1
done

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: HEALTHCHECK                        |"
echoWarn "|  ELAPSED: $(timerSpan HEALTHCHECK) seconds"
echoWarn "------------------------------------------------"
set -x
