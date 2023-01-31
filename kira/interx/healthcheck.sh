#!/usr/bin/env bash
set +e && source /etc/profile &>/dev/null && set -e
set -x

timerStart HEALTHCHECK

LOCAL_IP=$(globGet LOCAL_IP "$GLOBAL_COMMON_RO")
PUBLIC_IP=$(globGet PUBLIC_IP "$GLOBAL_COMMON_RO")
PRIVATE_MODE=$(globGet PRIVATE_MODE)

set +x
echoWarn "------------------------------------------------"
echoWarn "|   STARTED: ${NODE_TYPE^^} INTERX HEALTHCHECK"
echoWarn "|----------------------------------------------|"
echoWarn "|    PUBLIC IP: $PUBLIC_IP"
echoWarn "|     LOCAL IP: $LOCAL_IP"
echoWarn "| PRIVATE MODE: $PRIVATE_MODE"
echoWarn "------------------------------------------------"
set -x

echoInfo "INFO: Healthcheck => START"
sleep 15 # rate limit

VERSION_EXT=$(timeout 8 curl --fail $PUBLIC_IP:$EXTERNAL_API_PORT/api/kira/status | jsonQuickParse "interx_version" || echo -n "")
VERSION_INT=$(timeout 8 curl --fail $LOCAL_IP:$EXTERNAL_API_PORT/api/kira/status | jsonQuickParse "interx_version" || echo -n "")
VERSION_LOC=$(timeout 8 curl --fail interx.local:$INTERNAL_API_PORT/api/kira/status | jsonQuickParse "interx_version" || echo -n "")

if [ -z "$VERSION_EXT" ] && [ "$PRIVATE_MODE" != "true" ] ; then
    echoInfo "INFO: External interx status found"
    globSet EXTERNAL_ADDRESS "$PUBLIC_IP:$EXTERNAL_API_PORT"
    globSet EXTERNAL_STATUS "ONLINE"
elif [ -z "$VERSION_INT" ] && [ "$PRIVATE_MODE" == "true" ] ; then
    echoInfo "INFO: Internal interx status found"
    globSet EXTERNAL_ADDRESS "$LOCAL_IP:$EXTERNAL_API_PORT"
    globSet EXTERNAL_STATUS "ONLINE"
elif [ -z "$VERSION_INT" ] ;then
    echoInfo "INFO: Local interx status found"
    # globSet EXTERNAL_ADDRESS "interx.local:$EXTERNAL_API_PORT"
    globSet EXTERNAL_ADDRESS "$LOCAL_IP:$EXTERNAL_API_PORT"
    globSet EXTERNAL_STATUS "OFFLINE"
else
    echoErr "ERROR: Unknown Status Codes: '$INDEX_STATUS_CODE_EXT' EXTERNAL, '$INDEX_STATUS_CODE_INT' INTERNAL, '$INDEX_STATUS_CODE_LOC' LOCAL"
    globSet EXTERNAL_STATUS "OFFLINE"
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
