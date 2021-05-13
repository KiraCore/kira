#!/bin/bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/update.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kiraup && journalctl -u kiraup -f --output cat

SCRIPT_START_TIME="$(date -u +%s)"
UPDATE_LOGS_DIR="$KIRA_UPDATE/logs"
mkdir -p $UPDATE_LOGS_DIR
UPDATE_DONE="true"
UPDATE_DONE_FILE="$KIRA_UPDATE/done"
UPDATE_FAIL_FILE="$KIRA_UPDATE/fail"
UPDATE_FAIL_COUNTER="$KIRA_UPDATE/fail_counter"
UPDATE_DUMP="$KIRA_DUMP/kiraup"
MAX_FAILS=3

UPDATE_CHECK_TOOLS="tools-setup-1-$KIRA_SETUP_VER"
UPDATE_CHECK_CLEANUP="system-cleanup-1-$KIRA_SETUP_VER"
UPDATE_CHECK_IMAGES="images-build-1-$KIRA_SETUP_VER"
UPDATE_CHECK_CONTAINERS="containers-build-1-$KIRA_SETUP_VER"

touch $UPDATE_FAIL_COUNTER
UPDATE_FAILS=$(tryCat $UPDATE_FAIL_COUNTER "0") && (! $(isNaturalNumber $UPDATE_FAILS)) && UPDATE_FAILS=0

if [[ $UPDATE_FAILS -ge $MAX_FAILS ]] ; then
    echoErr "ERROR: Stopping update service for error..."
    touch $UPDATE_FAIL_FILE
    CDHelper text lineswap --insert="SETUP_END_DT=\"$(date +'%Y-%m-%d %H:%M:%S')\"" --prefix="SETUP_END_DT=" --path=$ETC_PROFILE --append-if-found-not=True
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
echoWarn "|     BASH SOURCE: ${BASH_SOURCE[0]}"
echoWarn "| UPDATE LOGS DIR: $UPDATE_LOGS_DIR"
echoWarn "|   FAILS COUNTER: $UPDATE_FAILS"
echoWarn "|       MAX FAILS: $MAX_FAILS"
echoWarn "------------------------------------------------"

mkdir -p $UPDATE_DUMP

[ ! -f "$UPDATE_CHECK" ] && rm -fv $UPDATE_DONE_FILE
[ "${NEW_NETWORK,,}" == "false" ] && [ ! -f "$LOCAL_GENESIS_PATH" ] && echoErr "ERROR: Genesis file was not found! ($LOCAL_GENESIS_PATH)" && sleep 60 && exit 1

UPDATE_CHECK="$KIRA_UPDATE/$UPDATE_CHECK_TOOLS"
if [ ! -f "$UPDATE_CHECK" ]; then
    echoInfo "INFO: Installing essential tools and dependecies ($UPDATE_CHECK_TOOLS)"
    set -x
    UPDATE_DONE="false" && rm -fv $UPDATE_DONE_FILE
    rm -rfv $UPDATE_LOGS_DIR 
    mkdir -p $UPDATE_LOGS_DIR

    echoInfo "INFO: Starting reinitalization process..."
    UPDATE_CHECK="$KIRA_UPDATE/$UPDATE_CHECK_TOOLS"
    LOG_FILE="$UPDATE_LOGS_DIR/${UPDATE_CHECK_TOOLS}.log"

    rm -fv $LOG_FILE && touch $LOG_FILE
    SUCCESS="true" && $KIRA_MANAGER/setup.sh "false" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${SUCCESS,,}" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized $UPDATE_CHECK_TOOLS"
        touch $UPDATE_CHECK
        systemctl daemon-reload
        systemctl restart kiraup || echoErr "ERROR: Failed to restart kiraup service"
        exit 0
    else
        echoErr "ERROR: Failed installing essential tools and dependecies ($UPDATE_CHECK_TOOLS)"
        UPDATE_FAILS=$(($UPDATE_FAILS + 1)) && echo "$UPDATE_FAILS" > $UPDATE_FAIL_COUNTER
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
    UPDATE_DONE="false" && rm -fv $UPDATE_DONE_FILE

    echoInfo "INFO: Starting cleanup process..."
    LOG_FILE="$UPDATE_LOGS_DIR/${UPDATE_CHECK_CLEANUP}.log"

    rm -fv $LOG_FILE && touch $LOG_FILE
    SUCCESS="true" && $KIRA_MANAGER/cleanup.sh "true" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${SUCCESS,,}" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized $UPDATE_CHECK_CLEANUP"
        touch $UPDATE_CHECK
    else
        echoErr "ERROR: Failed cleaning up environment ($UPDATE_CHECK_CLEANUP)"
        UPDATE_FAILS=$(($UPDATE_FAILS + 1)) && echo "$UPDATE_FAILS" > $UPDATE_FAIL_COUNTER
        sleep 5 && exit 1
    fi
else
    echoInfo "INFO: Environment cleanup was already executed ($UPDATE_CHECK_CLEANUP)"
fi

if [ ! -f "$KIRA_SETUP/reboot" ] ; then
    rm -fv "$KIRA_SETUP/rebooted"
    echoWarn "WARNING: To apply all changes your machine must be rebooted!"
    echoWarn "WARNING: After restart is compleated type 'kira' in your console terminal to continue"
    echoInfo "INFO: Rebooting will occur in 3 seconds and you will be logged out of your machine"
    echoErr "Log back in and type 'kira' in terminal then select [V]iew progress option to continue..."
    sleep 3
    set -x
    touch "$KIRA_SETUP/reboot"
    reboot
else
    echoInfo "INFO: Reboot was already performed, setup will continue..."
    touch "$KIRA_SETUP/rebooted"
fi

UPDATE_CHECK="$KIRA_UPDATE/$UPDATE_CHECK_IMAGES"
LOG_FILE="$UPDATE_LOGS_DIR/${UPDATE_CHECK_IMAGES}.log"
if [ ! -f "$UPDATE_CHECK" ]; then
    echoInfo "INFO: Building docker images ($UPDATE_CHECK_IMAGES)"
    set -x
    UPDATE_DONE="false" && rm -fv $UPDATE_DONE_FILE
    echoInfo "INFO: Starting build process..."
    LOG_FILE="$UPDATE_LOGS_DIR/${UPDATE_CHECK_IMAGES}.log"

    rm -fv $LOG_FILE && touch $LOG_FILE
    SUCCESS="true" && $KIRA_MANAGER/images.sh "true" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${SUCCESS,,}" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized $UPDATE_CHECK_IMAGES"
        rm -fv "$KIRA_UPDATE/$UPDATE_CHECK_CONTAINERS"
        touch $UPDATE_CHECK
    else
        echoErr "ERROR: Failed docker images build ($UPDATE_CHECK_IMAGES)"
        rm -fv "$KIRA_UPDATE/$UPDATE_CHECK_CLEANUP" "$KIRA_UPDATE/$UPDATE_CHECK_TOOLS"
        UPDATE_FAILS=$(($UPDATE_FAILS + 1)) && echo "$UPDATE_FAILS" > $UPDATE_FAIL_COUNTER
        sleep 5 && exit 1
    fi
else
    echoInfo "INFO: Docker images were already updated ($UPDATE_CHECK_IMAGES)"
fi

UPDATE_CHECK="$KIRA_UPDATE/$UPDATE_CHECK_CONTAINERS"
LOG_FILE="$UPDATE_LOGS_DIR/${UPDATE_CHECK_CONTAINERS}.log"
if [ ! -f "$UPDATE_CHECK" ]; then
    echoInfo "INFO: Building docker containers ($UPDATE_CHECK_CONTAINERS)"
    set -x
    UPDATE_DONE="false" && rm -fv $UPDATE_DONE_FILE
    echoInfo "INFO: Starting build process..."
    LOG_FILE="$UPDATE_LOGS_DIR/${UPDATE_CHECK_CONTAINERS}.log"

    rm -fv $LOG_FILE && touch $LOG_FILE
    SUCCESS="true" && $KIRA_MANAGER/containers.sh "true" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${SUCCESS,,}" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized $UPDATE_CHECK_CONTAINERS"
        touch $UPDATE_CHECK
    else
        echoErr "ERROR: Failed docker containers build ($UPDATE_CHECK_CONTAINERS)"
        rm -fv "$KIRA_UPDATE/$UPDATE_CHECK_CLEANUP" "$KIRA_UPDATE/$UPDATE_CHECK_TOOLS"
        UPDATE_FAILS=$(($UPDATE_FAILS + 1)) && echo "$UPDATE_FAILS" > $UPDATE_FAIL_COUNTER
        sleep 5 && exit 1
    fi
else
    echoInfo "INFO: Docker containers were already updated ($UPDATE_CHECK_CONTAINERS)"
fi

if [ "${UPDATE_DONE,,}" == "true" ] ; then
    echoInfo "INFO: Update & Setup was sucessfully finalized"
    if [ ! -f $UPDATE_DONE_FILE ] ; then
        set -x
        touch $UPDATE_DONE_FILE
        CDHelper text lineswap --insert="SETUP_END_DT=\"$(date +'%Y-%m-%d %H:%M:%S')\"" --prefix="SETUP_END_DT=" --path=$ETC_PROFILE --append-if-found-not=True
        set +x
    fi
else
    echoWarn "WARNING: Update & Setup is NOT finalized yet"
fi

[ "${UPDATE_DONE,,}" == "false" ] && sleep 10

set +x
echoInfo "INFO: To preview logs type 'cd $UPDATE_LOGS_DIR'"
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: LAUNCH SCRIPT $KIRA_SETUP_VER"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"

if [ "${UPDATE_DONE,,}" == "true" ] ; then
    timerStart AUTO_BACKUP
    if ($(isFileEmpty "$KIRA_DUMP/kiraup-done.log.txt")) ; then
        journalctl --since "$SETUP_START_DT" -u kiraup -b --no-pager --output cat > "$KIRA_DUMP/kiraup-done.log.txt" || echoErr "ERROR: Failed to dump kira update service log"
        journalctl --since "$SETUP_START_DT" -u kirascan -b --no-pager --output cat > "$KIRA_DUMP/kirascan-done.log.txt" || echoErr "ERROR: Failed to dump kira scan service log"
    fi
    echoInfo "Press 'Ctrl+c' to exit then type 'kira' to enter infra manager"
    sleep 5
    set -x
    systemctl stop kiraup 
    exit 0
fi
