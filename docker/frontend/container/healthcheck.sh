#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $SELF_SCRIPTS/utils.sh
exec 2>&1
set -x

START_TIME="$(date -u +%s)"
echoInfo "INFO: Starting healthcheck $START_TIME"

BLOCK_HEIGHT_FILE="$SELF_LOGS/latest_block_height"
COMMON_CONSENSUS="$COMMON_READ/consensus"
COMMON_LATEST_BLOCK_HEIGHT="$COMMON_READ/latest_block_height"
touch $BLOCK_HEIGHT_FILE

HALT_CHECK="${COMMON_DIR}/halt"
EXIT_CHECK="${COMMON_DIR}/exit"

if [ -f "$EXIT_CHECK" ]; then
    echoInfo "INFO: Ensuring nginx process is killed"
    touch $HALT_CHECK
    pkill -15 nginx || echoWarn "WARNING: Failed to kill nginx"
    rm -fv $EXIT_CHECK
fi

if [ -f "$HALT_CHECK" ]; then
    exit 0
fi

echoInfo "INFO: Healthcheck => START"
sleep 30 # rate limit

find "$SELF_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echoWarn "WARNING: Failed to truncate self logs"
find "$COMMON_LOGS" -type f -size +256k -exec truncate --size=128k {} + || echoWarn "WARNING: Failed to truncate common logs"
find "/var/log" -type f -size +1M -exec truncate --size=1M {} + || echoWarn "WARNING: Failed to truncate system logs"
find "/var/log/journal" -type f -size +256k -exec truncate --size=128k {} + || echoWarn "WARNING: Failed to truncate journal"

if (! $(isServiceActive "nginx")) ; then
  echoErr "ERROR: NGINX service is NOT active"
  nginx -t
  service nginx restart
  exit 1
fi

INDEX_HTML="$(curl --fail http://127.0.0.1:80 || echo -n '')"

EX_CHAR="!"
SUB_STR="<${EX_CHAR}DOCTYPE html>"
if [[ "$INDEX_HTML" != *"$SUB_STR"* ]]; then
  echoInfo "INFO: HTML page is not rendering."
  exit 1
fi

INDEX_STATUS_CODE="$(curl -s -o /dev/null -I -w '%{http_code}' 127.0.0.1:80)"

if [ "$INDEX_STATUS_CODE" -ne "200" ]; then
  echoInfo "INFO: Index page returns ${INDEX_STATUS_CODE}"
  exit 1
fi

echo "------------------------------------------------"
echo "| FINISHED: HEALTHCHECK                        |"
echo "|  ELAPSED: $(($(date -u +%s)-$START_TIME)) seconds"
echo "------------------------------------------------"
exit 0
