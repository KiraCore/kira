#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/update.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kiraup && journalctl -u kiraup -f --output cat
# cat $KIRA_LOGS/kiraup.log

SCRIPT_START_TIME="$(date -u +%s)"
UPDATE_DUMP="$KIRA_DUMP/kiraup"
MAX_FAILS=3

UPDATE_FAIL_COUNTER=$(globGet UPDATE_FAIL_COUNTER)
IS_WSL=$(isSubStr "$(uname -a)" "microsoft-standard-WSL")

if (! $(isNaturalNumber "$(globGet UPDATE_FAIL_COUNTER)")) ; then
    UPDATE_FAIL_COUNTER=0
    globSet UPDATE_FAIL_COUNTER "0"
fi 

if [[ $UPDATE_FAIL_COUNTER -ge $MAX_FAILS ]] ; then
    echoErr "ERROR: Stopping update service for error..."
    globSet UPDATE_FAIL "true"
    globSet SETUP_END_DT "$(date +'%Y-%m-%d %H:%M:%S')"
    echoErr "Press 'Ctrl+c' to exit then type 'kira' to open infrastructure manager"
    sleep 5 && systemctl stop kiraup
    exit 1
fi

set +x
echoWarn "------------------------------------------------"
echoWarn "| STARTED: KIRA UPDATE & SETUP SERVICE $KIRA_SETUP_VER"
echoWarn "|-----------------------------------------------"
echoWarn "|       BASH SOURCE: ${BASH_SOURCE[0]}"
echoWarn "|   UPDATE LOGS DIR: $KIRA_LOGS/kiraup-*-$KIRA_SETUP_VER.log"
echoWarn "|     FAILS COUNTER: $UPDATE_FAIL_COUNTER/$MAX_FAILS"
echoWarn "| SETUP START DTATE: $(globGet SETUP_START_DT)"
echoWarn "|   SETUP END DTATE: $SETUP_END_DT"
echoWarn "|      SETUP REBOOT: $(globGet SYSTEM_REBOOT)"
echoWarn "------------------------------------------------"
set -x

mkdir -p $UPDATE_DUMP

if [ "$(globGet SYSTEM_REBOOT)" == "true" ] ; then
    echoInfo "INFO: Reboot is required before tools setup can continue..." && sleep 3
    echoErr "Reconnect to your machine after restart and type 'kira' in the console to continue"
    globSet SYSTEM_REBOOT "false"
    [ "${IS_WSL,,}" != "true" ] && reboot
    exit 0
else
    echoInfo "INFO: Tools setup reboot was already performed, setup will continue..."
    systemctl restart docker || echoWarn "WARNINIG: Failed to start docker"
    sleep 3
fi

if [ "$(globGet "ESSENAILS_UPDATED_$KIRA_SETUP_VER")" != "true" ]; then
    echoInfo "INFO: Installing essential tools and dependecies"
    # increment fail counter in case of unexpected reboots
    globSet UPDATE_FAIL_COUNTER $(($UPDATE_FAIL_COUNTER + 1))

    echoInfo "INFO: Starting reinitalization process..."
    LOG_FILE="$KIRA_LOGS/kiraup-essentials-$KIRA_SETUP_VER.log" && globSet UPDATE_TOOLS_LOG "$LOG_FILE" 

    rm -fv $LOG_FILE && touch $LOG_FILE
    SUCCESS="true" && $KIRA_MANAGER/setup.sh "false" 2>&1 | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${SUCCESS,,}" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized essentials update"
        globSet "ESSENAILS_UPDATED_$KIRA_SETUP_VER" "true"
        globSet UPDATE_FAIL_COUNTER $(($UPDATE_FAIL_COUNTER - 1))
        systemctl daemon-reload
        systemctl restart kiraup || echoErr "ERROR: Failed to restart kiraup service"
        globSet SYSTEM_REBOOT "true"
        exit 0
    else
        set +x
        echoErr "--- ERROR LOG STAR '$LOG_FILE' ---"
        cat $LOG_FILE || echoErr "ERROR: Faile to print error log file"
        echoErr "--- ERROR LOG END '$LOG_FILE' ---"
        echoErr "ERROR: Failed installing essential tools and dependecies"
        set -x
        exit 1
    fi
else
    echoInfo "INFO: Essential tools and dependecies were already installed"
fi

if [ "$(globGet "CLEANUPS_UPDATED_$KIRA_SETUP_VER")" != "true" ] ; then
    echoInfo "INFO: Cleaning up environment & containers"
    # increment fail counter in case of unexpected reboots
    globSet UPDATE_FAIL_COUNTER $(($UPDATE_FAIL_COUNTER + 1))

    echoInfo "INFO: Starting cleanup process..."
    LOG_FILE="$KIRA_LOGS/kiraup-cleanup-$KIRA_SETUP_VER.log" && globSet UPDATE_CLEANUP_LOG "$LOG_FILE" 
    rm -fv $LOG_FILE && touch $LOG_FILE
    SUCCESS="true" && $KIRA_MANAGER/cleanup.sh "true" 2>&1 | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${SUCCESS,,}" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized update cleanup"
        globSet "CLEANUPS_UPDATED_$KIRA_SETUP_VER" "true"
        globSet UPDATE_FAIL_COUNTER $(($UPDATE_FAIL_COUNTER - 1))
        exit 0
    else
        set +x
        echoErr "--- ERROR LOG STAR '$LOG_FILE' ---"
        cat $LOG_FILE || echoErr "ERROR: Faile to print error log file"
        echoErr "--- ERROR LOG END '$LOG_FILE' ---"
        echoErr "ERROR: Failed cleaning up environment"
        set -x
        exit 1
    fi
else
    echoInfo "INFO: Environment cleanup was already executed"
fi

if [ "$(globGet "CONTAINERS_UPDATED_$KIRA_SETUP_VER")" != "true" ] ; then
    echoInfo "INFO: Building docker containers"
    # increment fail counter in case of unexpected reboots
    globSet UPDATE_FAIL_COUNTER $(($UPDATE_FAIL_COUNTER + 1))

    echoInfo "INFO: Starting build process..."
    LOG_FILE="$KIRA_LOGS/kiraup-containers-$KIRA_SETUP_VER.log" && globSet UPDATE_CONTAINERS_LOG "$LOG_FILE"
    rm -fv $LOG_FILE && touch $LOG_FILE
    globSet CONTAINERS_BUILD_SUCCESS "false"
    $KIRA_MANAGER/containers.sh "true" 2>&1 | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || echoErr "ERROR: Containers build logs pipe failed!"
    CONTAINERS_BUILD_SUCCESS=$(globGet CONTAINERS_BUILD_SUCCESS)
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${CONTAINERS_BUILD_SUCCESS,,}" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized containers update"
        globSet "CONTAINERS_UPDATED_$KIRA_SETUP_VER" "true"
        globSet UPDATE_FAIL_COUNTER $(($UPDATE_FAIL_COUNTER - 1))
        exit 0
    else
        set +x
        echoErr "--- ERROR LOG STAR '$LOG_FILE' ---"
        cat $LOG_FILE || echoErr "ERROR: Faile to print error log file"
        echoErr "--- ERROR LOG END '$LOG_FILE' ---"
        echoErr "ERROR: Failed docker containers build"
        globSet "CLEANUPS_UPDATED_$KIRA_SETUP_VER" "false"
        globSet "ESSENAILS_UPDATED_$KIRA_SETUP_VER" "false"
        globSet SYSTEM_REBOOT "true"
        set -x
        exit 1
    fi
else
    echoInfo "INFO: Docker containers were already updated"
fi

set -x

globSet SETUP_END_DT "$(date +'%Y-%m-%d %H:%M:%S')"
globSet UPDATE_DONE "true"

set +x
echoInfo "INFO: Update & Setup was sucessfully finalized"
echoInfo "INFO: To preview logs see $KIRA_LOGS direcotry"
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: UPDATE SCRIPT $KIRA_SETUP_VER"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"
echoInfo "Press 'Ctrl+c' to exit then type 'kira' to enter infra manager"
set -x

systemctl stop kiraup
sleep 10