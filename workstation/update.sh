#!/usr/bin/env bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/update.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kiraup && journalctl -u kiraup -f --output cat

SCRIPT_START_TIME="$(date -u +%s)"
UPDATE_DONE="true"
UPDATE_DUMP="$KIRA_DUMP/kiraup"
MAX_FAILS=3

UPDATE_FAILS=$(globGet UPDATE_FAIL_COUNTER)

if (! $(isNaturalNumber $UPDATE_FAILS)) ; then
    UPDATE_FAILS=0
    globSet UPDATE_FAIL_COUNTER $UPDATE_FAILS
fi 

SETUP_START_DT=$(globGet SETUP_START_DT)
# marks if system was rebooted before tools setup started (this is required in case of docker deamon malfunction)
SETUP_REBOOT=$(globGet SETUP_REBOOT)
# do not reboot if KM is run in WSL mode
IS_WSL=$(isSubStr "$(uname -a)" "microsoft-standard-WSL")
[ "${IS_WSL,,}" == "true" ] && SETUP_REBOOT="true"

if [[ $UPDATE_FAILS -ge $MAX_FAILS ]] ; then
    echoErr "ERROR: Stopping update service for error..."
    globSet UPDATE_FAIL "true"
    globSet SETUP_END_DT "$(date +'%Y-%m-%d %H:%M:%S')"
    echoInfo "INFO: Dumping service logs..."
    if ($(isFileEmpty "$KIRA_DUMP/kiraup-done.log.txt")) ; then
        cat $KIRA_LOGS/kiraup.log > "$KIRA_DUMP/kiraup-done.log.txt" || echoErr "ERROR: Failed to dump kira update service log"
        cat $KIRA_LOGS/kirascan.log > "$KIRA_DUMP/kirascan-done.log.txt" || echoErr "ERROR: Failed to dump kira scan service log"
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
echoWarn "|   UPDATE LOGS DIR: $KIRA_LOGS/kiraup-*-$KIRA_SETUP_VER.log"
echoWarn "|     FAILS COUNTER: $UPDATE_FAILS"
echoWarn "|         MAX FAILS: $MAX_FAILS"
echoWarn "| SETUP START DTATE: $SETUP_START_DT"
echoWarn "|   SETUP END DTATE: $SETUP_END_DT"
echoWarn "|      SETUP REBOOT: $SETUP_REBOOT"
echoWarn "------------------------------------------------"

mkdir -p $UPDATE_DUMP

[ "${NEW_NETWORK,,}" == "false" ] && [ ! -f "$LOCAL_GENESIS_PATH" ] && echoErr "ERROR: Genesis file was not found! ($LOCAL_GENESIS_PATH)" && sleep 60 && exit 1

if [ "$(globGet "ESSENAILS_UPDATED_$KIRA_SETUP_VER")" != "true" ]; then
    echoInfo "INFO: Installing essential tools and dependecies"

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

    echoInfo "INFO: Starting reinitalization process..."
    LOG_FILE="$KIRA_LOGS/kiraup-essentials-$KIRA_SETUP_VER.log" && globSet UPDATE_TOOLS_LOG "$LOG_FILE" 

    rm -fv $LOG_FILE && touch $LOG_FILE
    SUCCESS="true" && $KIRA_MANAGER/setup.sh "false" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${SUCCESS,,}" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized essentials update"
        globSet "ESSENAILS_UPDATED_$KIRA_SETUP_VER" "true"
        systemctl daemon-reload
        systemctl enable kiraup
        systemctl restart kiraup || echoErr "ERROR: Failed to restart kiraup service"
        globSet SETUP_REBOOT ""
        exit 0
    else
        echoErr "ERROR: Failed installing essential tools and dependecies"
        globSet UPDATE_FAIL_COUNTER $(($UPDATE_FAILS + 1))
        sleep 5 && exit 1
    fi
else
    echoInfo "INFO: Essential tools and dependecies were already installed"
fi

if [ "$(globGet "CLEANUPS_UPDATED_$KIRA_SETUP_VER")" != "true" ]; then
    echoInfo "INFO: Cleaning up environment & containers"
    set -x
    UPDATE_DONE="false"

    echoInfo "INFO: Starting cleanup process..."
    LOG_FILE="$KIRA_LOGS/kiraup-cleanup-$KIRA_SETUP_VER.log" && globSet UPDATE_CLEANUP_LOG "$LOG_FILE" 

    rm -fv $LOG_FILE && touch $LOG_FILE
    SUCCESS="true" && $KIRA_MANAGER/cleanup.sh "true" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${SUCCESS,,}" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized update cleanup"
        globSet "CLEANUPS_UPDATED_$KIRA_SETUP_VER" "true"
    else
        echoErr "ERROR: Failed cleaning up environment"
        globSet UPDATE_FAIL_COUNTER $(($UPDATE_FAILS + 1))
        sleep 5 && exit 1
    fi
else
    echoInfo "INFO: Environment cleanup was already executed"
fi

if [ -z "$SETUP_REBOOT" ] && [ "${IS_WSL,,}" != "true" ] ; then
    echoInfo "INFO: Reboot is required before setup can continue..." && sleep 3
    echoErr "Reconnect to your machine after restart and type 'kira' in the console to continue"
    globSet SETUP_REBOOT "done"
    reboot
    exit 0
else
    echoInfo "INFO: Reboot was already performed, setup will continue..."
fi

if [ "$(globGet "CONTAINERS_UPDATED_$KIRA_SETUP_VER")" != "true" ]; then
    echoInfo "INFO: Building docker containers"
    set -x
    UPDATE_DONE="false"
    echoInfo "INFO: Starting build process..."
    LOG_FILE="$KIRA_LOGS/kiraup-containers-$KIRA_SETUP_VER.log" && globSet UPDATE_CONTAINERS_LOG "$LOG_FILE"

    rm -fv $LOG_FILE && touch $LOG_FILE
    globSet CONTAINERS_BUILD_SUCCESS "false"
    $KIRA_MANAGER/containers.sh "true" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || echoErr "ERROR: Containers build logs pipe failed!"
    CONTAINERS_BUILD_SUCCESS=$(globGet CONTAINERS_BUILD_SUCCESS)
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${CONTAINERS_BUILD_SUCCESS,,}" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized containers update"
        globSet "CONTAINERS_UPDATED_$KIRA_SETUP_VER" "true"
    else
        echoErr "ERROR: Failed docker containers build"
        globSet "CLEANUPS_UPDATED_$KIRA_SETUP_VER" "false"
        globSet "ESSENAILS_UPDATED_$KIRA_SETUP_VER" "false"
        globSet UPDATE_FAIL_COUNTER $(($UPDATE_FAILS + 1))
        sleep 5
        reboot
    fi
else
    echoInfo "INFO: Docker containers were already updated"
    systemctl start docker || echoWarn "WARNINIG: Failed to start docker"
    sleep 3
fi

set -x

if [ "${UPDATE_DONE,,}" == "true" ] ; then
    echoInfo "INFO: Update & Setup was sucessfully finalized"
    if ($(isFileEmpty "$KIRA_DUMP/kiraup-done.log.txt")) ; then
        cat $KIRA_LOGS/kiraup.log > "$KIRA_DUMP/kiraup-done.log.txt" || echoErr "ERROR: Failed to dump kira update service log"
        cat $KIRA_LOGS/kirascan.log > "$KIRA_DUMP/kirascan-done.log.txt" || echoErr "ERROR: Failed to dump kira scan service log"
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

echoInfo "INFO: To preview logs see $KIRA_LOGS direcotry"
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: UPDATE SCRIPT $KIRA_SETUP_VER"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"

sleep 10