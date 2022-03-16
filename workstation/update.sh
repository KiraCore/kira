#!/usr/bin/env bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/update.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kiraup && journalctl -u kiraup -f --output cat

SCRIPT_START_TIME="$(date -u +%s)"
UPDATE_LOGS_DIR="$KIRA_UPDATE/logs"
mkdir -p $UPDATE_LOGS_DIR
UPDATE_DONE="true"
UPDATE_DUMP="$KIRA_DUMP/kiraup"
MAX_FAILS=3

UPDATE_CHECK_TOOLS="tools-setup-1-$KIRA_SETUP_VER"
UPDATE_CHECK_CLEANUP="system-cleanup-1-$KIRA_SETUP_VER"
UPDATE_CHECK_CONTAINERS="containers-build-1-$KIRA_SETUP_VER"

UPDATE_FAILS=$(globGet UPDATE_FAIL_COUNTER)

if (! $(isNaturalNumber $UPDATE_FAILS)) ; then
    UPDATE_FAILS=0
    globSet UPDATE_FAIL_COUNTER $UPDATE_FAILS
fi 

SETUP_START_DT=$(globGet SETUP_START_DT)
# marks if system was rebooted before tools setup started (this is required in case of docker deamon malfunction)
SETUP_REBOOT=$(globGet SETUP_REBOOT)

if [[ $UPDATE_FAILS -ge $MAX_FAILS ]] ; then
    echoErr "ERROR: Stopping update service for error..."
    globSet UPDATE_FAIL "true"
    globSet SETUP_END_DT "$(date +'%Y-%m-%d %H:%M:%S')"
    echoInfo "INFO: Dumping service logs..."
    if ($(isFileEmpty "$KIRA_DUMP/kiraup-done.log.txt")) ; then
        journalctl --since "$SETUP_START_DT" -u kiraup -b --no-pager --output cat > "$KIRA_DUMP/kiraup-done.log.txt" || echoErr "ERROR: Failed to dump kira update service log"
        journalctl --since "$SETUP_START_DT" -u kirascan -b --no-pager --output cat > "$KIRA_DUMP/kirascan-done.log.txt" || echoErr "ERROR: Failed to dump kira scan service log"
    fi
    echoErr "Press 'Ctrl+c' to exit then type 'kira' to enter infra manager"
    sleep 5
    systemctl stop kiraup
    exit 1
fi

echoWarn "------------------------------------------------"
echoWarn "| STARTED: KIRA UPDATE & SETUP SERVICE $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "|       BASH SOURCE: ${BASH_SOURCE[0]}"
echoWarn "|   UPDATE LOGS DIR: $UPDATE_LOGS_DIR"
echoWarn "|     FAILS COUNTER: $UPDATE_FAILS"
echoWarn "|         MAX FAILS: $MAX_FAILS"
echoWarn "| SETUP START DTATE: $SETUP_START_DT"
echoWarn "|   SETUP END DTATE: $SETUP_END_DT"
echoWarn "|      SETUP REBOOT: $SETUP_REBOOT"
echoWarn "------------------------------------------------"

mkdir -p $UPDATE_DUMP

[ "${NEW_NETWORK,,}" == "false" ] && [ ! -f "$LOCAL_GENESIS_PATH" ] && echoErr "ERROR: Genesis file was not found! ($LOCAL_GENESIS_PATH)" && sleep 60 && exit 1

UPDATE_CHECK="$KIRA_UPDATE/$UPDATE_CHECK_TOOLS"
if [ ! -f "$UPDATE_CHECK" ]; then
    echoInfo "INFO: Installing essential tools and dependecies ($UPDATE_CHECK_TOOLS)"

    if [ -z "$SETUP_REBOOT" ] ; then
        echoInfo "INFO: Reboot is required before tools setup can continue..." && sleep 3
        echoErr "Reconnect to your machine after restart and type 'kira' in the console to continue"
        globSet SETUP_REBOOT "done"
        reboot
        exit 0
    else
        echoInfo "INFO: Tools setup reboot was already performed, setup will continue..."
        systemctl start docker || echoWarn "WARNINIG: Failed to start docker"
        sleep 3
    fi

    set -x
    UPDATE_DONE="false"
    rm -rfv $UPDATE_LOGS_DIR 
    mkdir -p $UPDATE_LOGS_DIR

    echoInfo "INFO: Starting reinitalization process..."
    UPDATE_CHECK="$KIRA_UPDATE/$UPDATE_CHECK_TOOLS"
    LOG_FILE="$UPDATE_LOGS_DIR/${UPDATE_CHECK_TOOLS}.log" && globSet UPDATE_TOOLS_LOG "$LOG_FILE" 

    rm -fv $LOG_FILE && touch $LOG_FILE
    SUCCESS="true" && $KIRA_MANAGER/setup.sh "false" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${SUCCESS,,}" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized $UPDATE_CHECK_TOOLS"
        touch $UPDATE_CHECK
        systemctl daemon-reload
        systemctl restart kiraup || echoErr "ERROR: Failed to restart kiraup service"
        globSet SETUP_REBOOT ""
        exit 0
    else
        echoErr "ERROR: Failed installing essential tools and dependecies ($UPDATE_CHECK_TOOLS)"
        globSet UPDATE_FAIL_COUNTER $(($UPDATE_FAILS + 1))
        sleep 5 && exit 1
    fi
else
    echoInfo "INFO: Essential tools and dependecies were already installed ($UPDATE_CHECK_TOOLS)"
fi

UPDATE_CHECK="$KIRA_UPDATE/$UPDATE_CHECK_CLEANUP"
LOG_FILE="$UPDATE_LOGS_DIR/${UPDATE_CHECK_CLEANUP}.log"
if [ ! -f "$UPDATE_CHECK" ]; then
    echoInfo "INFO: Cleaning up environment & containers ($UPDATE_CHECK_CLEANUP)"
    set -x
    UPDATE_DONE="false"

    echoInfo "INFO: Starting cleanup process..."
    LOG_FILE="$UPDATE_LOGS_DIR/${UPDATE_CHECK_CLEANUP}.log" && globSet UPDATE_CLEANUP_LOG "$LOG_FILE" 

    rm -fv $LOG_FILE && touch $LOG_FILE
    SUCCESS="true" && $KIRA_MANAGER/cleanup.sh "true" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${SUCCESS,,}" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized $UPDATE_CHECK_CLEANUP"
        touch $UPDATE_CHECK
    else
        echoErr "ERROR: Failed cleaning up environment ($UPDATE_CHECK_CLEANUP)"
        globSet UPDATE_FAIL_COUNTER $(($UPDATE_FAILS + 1))
        sleep 5 && exit 1
    fi
else
    echoInfo "INFO: Environment cleanup was already executed ($UPDATE_CHECK_CLEANUP)"
fi

if [ -z "$SETUP_REBOOT" ] ; then
    echoInfo "INFO: Reboot is required before setup can continue..." && sleep 3
    echoErr "Reconnect to your machine after restart and type 'kira' in the console to continue"
    globSet SETUP_REBOOT "done"
    reboot
    exit 0
else
    echoInfo "INFO: Reboot was already performed, setup will continue..."
fi

UPDATE_CHECK="$KIRA_UPDATE/$UPDATE_CHECK_CONTAINERS"
LOG_FILE="$UPDATE_LOGS_DIR/${UPDATE_CHECK_CONTAINERS}.log"
if [ ! -f "$UPDATE_CHECK" ]; then
    echoInfo "INFO: Building docker containers ($UPDATE_CHECK_CONTAINERS)"
    set -x
    UPDATE_DONE="false"
    echoInfo "INFO: Starting build process..."
    LOG_FILE="$UPDATE_LOGS_DIR/${UPDATE_CHECK_CONTAINERS}.log" && globSet UPDATE_CONTAINERS_LOG "$LOG_FILE"

    rm -fv $LOG_FILE && touch $LOG_FILE
    globSet CONTAINERS_BUILD_SUCCESS "false"
    $KIRA_MANAGER/containers.sh "true" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || echoErr "ERROR: Containers build logs pipe failed!"
    CONTAINERS_BUILD_SUCCESS=$(globGet CONTAINERS_BUILD_SUCCESS)
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${CONTAINERS_BUILD_SUCCESS,,}" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized $UPDATE_CHECK_CONTAINERS"
        touch $UPDATE_CHECK
    else
        echoErr "ERROR: Failed docker containers build ($UPDATE_CHECK_CONTAINERS)"
        rm -fv "$KIRA_UPDATE/$UPDATE_CHECK_CLEANUP" "$KIRA_UPDATE/$UPDATE_CHECK_TOOLS"
        globSet UPDATE_FAIL_COUNTER $(($UPDATE_FAILS + 1))
        sleep 5
        reboot
    fi
else
    echoInfo "INFO: Docker containers were already updated ($UPDATE_CHECK_CONTAINERS)"
    systemctl start docker || echoWarn "WARNINIG: Failed to start docker"
    sleep 3
fi

set -x

if [ "${UPDATE_DONE,,}" == "true" ] ; then
    echoInfo "INFO: Update & Setup was sucessfully finalized"
    if ($(isFileEmpty "$KIRA_DUMP/kiraup-done.log.txt")) ; then
        journalctl --since "$SETUP_START_DT" -u kiraup -b --no-pager --output cat > "$KIRA_DUMP/kiraup-done.log.txt" || echoErr "ERROR: Failed to dump kira update service log"
        journalctl --since "$SETUP_START_DT" -u kirascan -b --no-pager --output cat > "$KIRA_DUMP/kirascan-done.log.txt" || echoErr "ERROR: Failed to dump kira scan service log"
    fi
    set +x
    globSet SETUP_END_DT "$(date +'%Y-%m-%d %H:%M:%S')"
    globSet UPDATE_DONE "true"
    echoInfo "Press 'Ctrl+c' to exit then type 'kira' to enter infra manager"
    sleep 5
    systemctl stop kiraup 
else
    set +x
    echoWarn "WARNING: Update & Setup is NOT finalized yet"
fi

echoInfo "INFO: To preview logs type 'cd $UPDATE_LOGS_DIR'"
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: UPDATE SCRIPT $KIRA_SETUP_VER"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"

sleep 10