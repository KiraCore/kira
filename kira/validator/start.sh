#!/usr/bin/env bash
exec 2>&1
set +e && source /etc/profile &>/dev/null && set -e
# quick edit: FILE="${COMMON_DIR}/validator/start.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: KIRA $NODE_TYPE START SCRIPT $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "| SEKAI VERSION: $(sekaid version)"
echoWarn "|   BASH SOURCE: ${BASH_SOURCE[0]}"
echoWarn "|   SEKAID HOME: $SEKAID_HOME"
echoWarn "|   NEW NETWORK: $(globGet NEW_NETWORK)"
echoWarn "|  PRIVATE MODE: $(globGet PRIVATE_MODE)"
echoWarn "------------------------------------------------"
set -x

globSet EXTERNAL_STATUS "offline"

if [ "$(globGet INIT_DONE)" != "true" ]; then
    if [ "$UPGRADE_MODE" == "soft" ] || [ "$UPGRADE_MODE" == "hard" ] ; then
        $COMMON_DIR/sekai-upgrade.sh
    elif [ "$UPGRADE_MODE" == "none" ] ; then
        $COMMON_DIR/validator/init.sh
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
globSet CFG_TASK "false"
globSet RUNTIME_VERSION "$(sekaid version)"

echoInfo "INFO: Starting validator..."
kill -9 $(lsof -t -i:9090) || echoWarn "WARNING: Nothing running on port 9090, or failed to kill processes"
kill -9 $(lsof -t -i:6060) || echoWarn "WARNING: Nothing running on port 6060, or failed to kill processes"
kill -9 $(lsof -t -i:26656) || echoWarn "WARNING: Nothing running on port 26656, or failed to kill processes"
kill -9 $(lsof -t -i:26657) || echoWarn "WARNING: Nothing running on port 26657, or failed to kill processes"
kill -9 $(lsof -t -i:26658) || echoWarn "WARNING: Nothing running on port 26658, or failed to kill processes"
EXIT_CODE=0
sekaid start --home=$SEKAID_HOME --trace || EXIT_CODE="$?"
set +x
echoErr "ERROR: SEKAID process failed with the exit code $EXIT_CODE"
sleep 3
exit 1
