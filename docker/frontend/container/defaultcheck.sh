#!/bin/bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
set -x
# quick edit: FILE="${SELF_CONTAINER}/defaultcheck.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

timerStart HEALTHCHECK

COMMON_CONSENSUS="$COMMON_READ/consensus"
HALT_CHECK="${COMMON_DIR}/halt"
EXIT_CHECK="${COMMON_DIR}/exit"

LOCAL_IP=$(globGet LOCAL_IP "$GLOBAL_COMMON_RO")
PUBLIC_IP=$(globGet PUBLIC_IP "$GLOBAL_COMMON_RO")

set +x
echoWarn "------------------------------------------------"
echoWarn "|   STARTED: HEALTHCHECK                       |"
echoWarn "|----------------------------------------------|"
echoWarn "| PUBLIC IP: $PUBLIC_IP"
echoWarn "|  LOCAL IP: $LOCAL_IP"
echoWarn "------------------------------------------------"
set -x

if [ -f "$EXIT_CHECK" ]; then
    echoInfo "INFO: Ensuring nginx process is killed"
    touch $HALT_CHECK
    pkill -15 nginx || echoWarn "WARNING: Failed to kill nginx"
    rm -fv $EXIT_CHECK
fi

if [ -f "$HALT_CHECK" ]; then
    echoWarn "INFO: Contianer is halted!"
    globSet EXTERNAL_STATUS "OFFLINE"
    sleep 1
    exit 0
fi

echoInfo "INFO: Healthcheck rate limiting..."
sleep 15 # rate limit

find "$SELF_LOGS" -type f -size +16M -exec truncate --size=8M {} + || echoWarn "WARNING: Failed to truncate self logs"
find "$COMMON_LOGS" -type f -size +16M -exec truncate --size=8M {} + || echoWarn "WARNING: Failed to truncate common logs"
journalctl --vacuum-time=3d --vacuum-size=32M || echoWarn "WARNING: journalctl vacuum failed"
find "/var/log" -type f -size +64M -exec truncate --size=8M {} + || echoWarn "WARNING: Failed to truncate system logs"

if ($(isServiceActive "nginx")) ; then
  echoErr "ERROR: NGINX service SHOULD NOT be active"
  globSet EXTERNAL_STATUS "OFFLINE"
  nginx -t
  service nginx stop || echoErr "ERROR: Failed to stop nginx"
  pkill -15 nginx || echoWarn "WARNING: Failed to kill nginx"
  exit 1
fi

INDEX_HTML="$(timeout 8 curl --fail http://127.0.0.1:80 || echo -n '')"

EX_CHAR="!"
SUB_STR="<${EX_CHAR}DOCTYPE html>"
if [[ "$INDEX_HTML" != *"$SUB_STR"* ]]; then
  echoInfo "INFO: HTML page is not rendering."
  globSet EXTERNAL_STATUS "OFFLINE"
  exit 1
fi

INDEX_STATUS_CODE_EXT=$(timeout 8 curl -s -o /dev/null -I -w '%{http_code}' $PUBLIC_IP:$EXTERNAL_HTTP_PORT || echo "")
INDEX_STATUS_CODE_INT=$(timeout 8 curl -s -o /dev/null -I -w '%{http_code}' $LOCAL_IP:$EXTERNAL_HTTP_PORT || echo "")
INDEX_STATUS_CODE_LOC=$(timeout 8 curl -s -o /dev/null -I -w '%{http_code}' frontend.local:$INTERNAL_HTTP_PORT || echo "")

if [ "$INDEX_STATUS_CODE_EXT" == "200" ]; then
    echoInfo "INFO: External Index page retured status code ${INDEX_STATUS_CODE_EXT}"
    globSet EXTERNAL_ADDRESS "$PUBLIC_IP:$INTERNAL_HTTP_PORT"
elif [ "$INDEX_STATUS_CODE_INT" == "200" ]; then
    echoInfo "INFO: Internal Index page retured status code ${INDEX_STATUS_CODE_INT}"
    globSet EXTERNAL_ADDRESS "$LOCAL_IP:$INTERNAL_HTTP_PORT"
elif [ "$INDEX_STATUS_CODE_LOC" == "200" ]; then
    echoInfo "INFO: Local Index page retured status code ${INDEX_STATUS_CODE_LOC}"
    globSet EXTERNAL_ADDRESS "frontend.local:$INTERNAL_HTTP_PORT"
else
    echoErr "ERROR: Unknown Status Codes: '$INDEX_STATUS_CODE_EXT' EXTERNAL, '$INDEX_STATUS_CODE_INT' INTERNAL, '$INDEX_STATUS_CODE_LOC' LOCAL"
    globSet EXTERNAL_STATUS "OFFLINE"
    sleep 3
    exit 1
fi

globSet EXTERNAL_STATUS "ONLINE"

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: HEALTHCHECK                        |"
echoWarn "|  ELAPSED: $(timerSpan HEALTHCHECK) seconds"
echoWarn "------------------------------------------------"
set -x
