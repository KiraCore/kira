#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/update.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# systemctl restart kiraup && journalctl -u kiraup -f --output cat
# cat $KIRA_LOGS/kiraup.log

SCRIPT_START_TIME="$(date -u +%s)"
UPDATE_DUMP="$KIRA_DUMP/kiraup"
MAX_FAILS=3

UPDATE_FAIL_COUNTER="$(globGet UPDATE_FAIL_COUNTER)"
(! $(isNaturalNumber "$UPDATE_FAIL_COUNTER")) && UPDATE_FAIL_COUNTER="0" && globSet UPDATE_FAIL_COUNTER "0"

if [[ $UPDATE_FAIL_COUNTER -ge $MAX_FAILS ]] ; then
    echoErr "ERROR: Stopping update service for error..."
    globSet UPDATE_FAIL "true"
    globSet SETUP_END_DT "$(date +'%Y-%m-%d %H:%M:%S')"
    echoErr "Press 'Q' or 'Ctrl+C' to exit then type 'kira' to enter infra manager"
    sleep 5 && systemctl stop kiraup
    exit 1
fi

set +x
echoC ";whi"  " =============================================================================="
echoC ";whi"  "|$(strFixC "STARTED KIRA UPDATE & SETUP SERVICE $KIRA_SETUP_VER" 78)|"   
echoC ";whi"  "|==============================================================================|"
echoC ";whi"  "|        BASH SOURCE: $(strFixL " ${BASH_SOURCE[0]} " 58)|"
echoC ";whi"  "|    UPDATE LOGS DIR: $(strFixL " $KIRA_LOGS/kiraup-*-$KIRA_SETUP_VER.log " 58)|"
echoC ";whi"  "|      FAILS COUNTER: $(strFixL " $UPDATE_FAIL_COUNTER/$MAX_FAILS " 58)|"
echoC ";whi"  "|  SETUP START DTATE: $(strFixL " $(globGet SETUP_START_DT) " 58)|"
echoC ";whi"  "|    SETUP END DTATE: $(strFixL " $SETUP_END_DT " 58)|"
echoC ";whi"  "|       SETUP REBOOT: $(strFixL " $(globGet SYSTEM_REBOOT) " 58)|"
echoC ";whi"  " =============================================================================="
set -x

mkdir -p $UPDATE_DUMP

if [ "$(globGet SYSTEM_REBOOT)" == "true" ] ; then
    echoInfo "INFO: Reboot is required before tools setup can continue..." && sleep 3
    echoErr "Reconnect to your machine after restart and type 'kira' in the console to continue"
    globSet SYSTEM_REBOOT "false"
    (! $(isWSL)) && reboot
    exit 0
else
    echoInfo "INFO: Tools setup reboot was already performed, setup will continue..."
    $KIRA_COMMON/docker-restart.sh
    sleep 3
fi

if [ "$(globGet "ESSENAILS_UPDATED_$KIRA_SETUP_VER")" != "true" ]; then
    echoInfo "INFO: Installing essential tools and dependecies"
    # increment fail counter in case of unexpected reboots
    globSet UPDATE_FAIL_COUNTER $(($UPDATE_FAIL_COUNTER + 1))
    globSet SYSTEM_REBOOT "true"

    echoInfo "INFO: Starting reinitalization process..."
    LOG_FILE="$KIRA_LOGS/kiraup-essentials-$KIRA_SETUP_VER.log" && globSet UPDATE_TOOLS_LOG "$LOG_FILE" 

    rm -fv $LOG_FILE && touch $LOG_FILE
    SUCCESS="true"
    $KIRA_MANAGER/setup.sh "false" 2>&1 | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "$SUCCESS" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized essentials update"
        globSet "ESSENAILS_UPDATED_$KIRA_SETUP_VER" "true"
        globSet UPDATE_FAIL_COUNTER "0"
        systemctl daemon-reload
        systemctl restart kiraup || echoErr "ERROR: Failed to restart kiraup service"
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
    SUCCESS="true" 
    $KIRA_MANAGER/cleanup.sh "true" 2>&1 | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "$SUCCESS" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized update cleanup"
        globSet "CLEANUPS_UPDATED_$KIRA_SETUP_VER" "true"
        globSet UPDATE_FAIL_COUNTER "0"
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
    if [ "$CONTAINERS_BUILD_SUCCESS" == "true" ] ; then
        echoInfo "INFO: Sucessfully finalized containers update"
        globSet "CONTAINERS_UPDATED_$KIRA_SETUP_VER" "true"
        globSet UPDATE_FAIL_COUNTER "0"
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
echoInfo "INFO: To preview logs see $KIRA_LOGS direcotry"
echoC ";whi"  "================================================================================"
echoC ";whi"  "|$(strFixC "FINISHED KIRA UPDATE SCRIPT $KIRA_SETUP_VER" 78))|"   
echoC ";whi"  "================================================================================"
echoInfo "Press 'Q' or 'Ctrl+C' to exit then type 'kira' to enter infra manager"
set -x

systemctl stop kiraup
sleep 10