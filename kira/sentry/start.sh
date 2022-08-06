#!/usr/bin/env bash
set +e && source $ETC_PROFILE &>/dev/null && set -e
exec 2>&1
set -x

KIRA_SETUP_VER=$(globGet KIRA_SETUP_VER "$GLOBAL_COMMON_RO")
PRIVATE_MODE=$(globGet PRIVATE_MODE)

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: KIRA ${NODE_TYPE^^} START SCRIPT $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "| SEKAI VERSION: $(sekaid version)"
echoWarn "|   BASH SOURCE: ${BASH_SOURCE[0]}"
echoWarn "|   SEKAID HOME: $SEKAID_HOME"
echoWarn "|  PRIVATE MODE: $PRIVATE_MODE"
echoWarn "------------------------------------------------"
set -x

SNAP_FILE_INPUT="$COMMON_READ/snap.tar"
COMMON_GENESIS="$COMMON_READ/genesis.json"

globSet EXTERNAL_STATUS "OFFLINE"

while [ "$(globGet INIT_DONE)" != "true" ] && ($(isFileEmpty "$SNAP_FILE_INPUT")) && ($(isFileEmpty "$COMMON_GENESIS")) ; do
    echoInfo "INFO: Waiting for genesis file to be provisioned... ($(date))"
    sleep 5
done

LOCAL_IP=$(globGet LOCAL_IP "$GLOBAL_COMMON_RO")
PUBLIC_IP=$(globGet PUBLIC_IP "$GLOBAL_COMMON_RO")
EXTERNAL_SYNC=$(globGet EXTERNAL_SYNC "$GLOBAL_COMMON_RO")
INFRA_MODE=$(globGet INFRA_MODE "$GLOBAL_COMMON_RO")

while [ -z "$LOCAL_IP" ] && [ "${PRIVATE_MODE,,}" == "true" ] ; do
   echoInfo "INFO: Waiting for Local IP to be provisioned... ($(date))"
   LOCAL_IP=$(globGet LOCAL_IP "$GLOBAL_COMMON_RO")
   PRIVATE_MODE=$(globGet PRIVATE_MODE)
   sleep 5
done

while [ -z "$PUBLIC_IP" ] && [ "${PRIVATE_MODE,,}" != "true" ] ; do
    echoInfo "INFO: Waiting for Public IP to be provisioned... ($(date))"
    PUBLIC_IP=$(globGet PUBLIC_IP "$GLOBAL_COMMON_RO")
    PRIVATE_MODE=$(globGet PRIVATE_MODE)
    sleep 5
done

echoInfo "INFO: Sucess, genesis file was found!"

if [ "$(globGet INIT_DONE)" != "true" ]; then
    if [ "$UPGRADE_MODE" == "soft" ] || [ "$UPGRADE_MODE" == "hard" ] ; then
        $COMMON_DIR/sekai-upgrade.sh
    elif [ "$UPGRADE_MODE" == "none" ] ; then
        $COMMON_DIR/sentry/init.sh
    else    
        echoErr "ERROR: Unknown upgrade mode '$UPGRADE_MODE'"
        sleep 10 && exit 1
    fi

    globSet INIT_DONE "true" 
    globSet RESTART_COUNTER 0
    globSet START_TIME "$(date -u +%s)"
fi

echoInfo "INFO: Loading configuration..."
$COMMON_DIR/configure.sh
set +e && source "$ETC_PROFILE" &>/dev/null && set -e
globSet CFG_TASK "false"
globSet RUNTIME_VERSION "sekaid $(sekaid version)"

echoInfo "INFO: Starting sekaid..."
kill -9 $(sudo lsof -t -i:9090) || echoWarn "WARNING: Nothing running on port 9090, or failed to kill processes"
kill -9 $(sudo lsof -t -i:6060) || echoWarn "WARNING: Nothing running on port 6060, or failed to kill processes"
kill -9 $(sudo lsof -t -i:26656) || echoWarn "WARNING: Nothing running on port 26656, or failed to kill processes"
kill -9 $(sudo lsof -t -i:26657) || echoWarn "WARNING: Nothing running on port 26657, or failed to kill processes"
kill -9 $(sudo lsof -t -i:26658) || echoWarn "WARNING: Nothing running on port 26658, or failed to kill processes"
EXIT_CODE=0
sekaid start --home=$SEKAID_HOME --trace || EXIT_CODE="$?"
set +x
echoErr "ERROR: SEKAID process failed with the exit code $EXIT_CODE"
sleep 3
exit 1
