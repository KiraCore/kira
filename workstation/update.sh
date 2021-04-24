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
UPDATE_DUMP="$KIRA_DUMP/kiraup"
UPDATE_FAIL_COUNTER="$KIRA_DUMP/fail_counter"
MAX_FAILS=2

UPDATE_CHECK_TOOLS="tools-setup-1-$KIRA_SETUP_VER"
UPDATE_CHECK_CLEANUP="system-cleanup-1-$KIRA_SETUP_VER"
UPDATE_CHECK_IMAGES="images-build-1-$KIRA_SETUP_VER"
UPDATE_CHECK_CONTAINERS="containers-build-1-$KIRA_SETUP_VER"

touch $UPDATE_FAIL_COUNTER
UPDATE_FAILS=$(tryCat $UPDATE_FAIL_COUNTER "0") && (! $(isNaturalNumber $UPDATE_FAILS)) && UPDATE_FAILS=0

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
    if [ ! -f "${UPDATE_CHECK}-skip" ]; then
        echoInfo "INFO: Starting reinitalization process..."
        UPDATE_CHECK_TOOLS="$UPDATE_CHECK_TOOLS-skip"
        UPDATE_CHECK="$KIRA_UPDATE/$UPDATE_CHECK_TOOLS"
        LOG_FILE="$UPDATE_LOGS_DIR/${UPDATE_CHECK_TOOLS}.log"
        if [[ $UPDATE_FAILS -gt $MAX_FAILS ]] $ ; then
            echoErr "ERROR: Setup aborted, max nr. of re-tries reached, to see details type 'cat $LOG_FILE'"
            sleep 120 && systemctl stop kiraup && exit 1
        fi
        rm -fv $LOG_FILE && touch $LOG_FILE
        SUCCESS="true" && $KIRA_MANAGER/setup.sh "false" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
        echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
        if [ "${SUCCESS,,}" == "true" ] ; then
            touch $UPDATE_CHECK
            UPDATE_FAILS=0 && echo "$UPDATE_FAILS" > $UPDATE_FAIL_COUNTER
        else
            echoErr "ERROR: Failed installing essential tools and dependecies ($UPDATE_CHECK_TOOLS)"
            UPDATE_FAILS=$(($UPDATE_FAILS + 1)) && echo "$UPDATE_FAILS" > $UPDATE_FAIL_COUNTER
            sleep 120 
            exit 1
        fi
        
        cat > /etc/systemd/system/kiraup.service << EOL
[Unit]
Description=KIRA Update And Setup Service
After=network.target
[Service]
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=99
Type=simple
User=root
WorkingDirectory=$KIRA_HOME
ExecStart=/bin/bash $KIRA_MANAGER/update.sh
Restart=always
RestartSec=5
LimitNOFILE=4096
[Install]
WantedBy=default.target
EOL
        systemctl daemon-reload
        systemctl restart kiraup || echoErr "ERROR: Failed to reinit "
    else
        echoInfo "INFO: Starting setup process..."
        LOG_FILE="$UPDATE_LOGS_DIR/${UPDATE_CHECK_TOOLS}.log"
        if [[ $UPDATE_FAILS -gt $MAX_FAILS ]] $ ; then
            echoErr "ERROR: Setup aborted, max nr. of re-tries reached, to see details type 'cat $LOG_FILE'"
            sleep 120 && systemctl stop kiraup && exit 1
        fi
        rm -fv $LOG_FILE && touch $LOG_FILE
        SUCCESS="true" && $KIRA_MANAGER/setup.sh "false" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
        set +x
        echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
        if [ "${SUCCESS,,}" == "true" ] ; then
            touch $UPDATE_CHECK
            UPDATE_FAILS=0 && echo "$UPDATE_FAILS" > $UPDATE_FAIL_COUNTER
        else
            echoErr "ERROR: Failed installing essential tools and dependecies ($UPDATE_CHECK_TOOLS)"
            UPDATE_FAILS=$(($UPDATE_FAILS + 1)) && echo "$UPDATE_FAILS" > $UPDATE_FAIL_COUNTER
            sleep 120 
            exit 1
        fi
    fi
    exit 0
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
    if [[ $UPDATE_FAILS -gt $MAX_FAILS ]] $ ; then
        echoErr "ERROR: Setup aborted, max nr. of re-tries reached, to see details type 'cat $LOG_FILE'"
        sleep 120 && systemctl stop kiraup && exit 1
    fi
    rm -fv $LOG_FILE && touch $LOG_FILE
    SUCCESS="true" && $KIRA_MANAGER/cleanup.sh "true" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    set +x
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${SUCCESS,,}" == "true" ] ; then
        touch $UPDATE_CHECK
        UPDATE_FAILS=0 && echo "$UPDATE_FAILS" > $UPDATE_FAIL_COUNTER
    else
        echoErr "ERROR: Failed cleaning up environment ($UPDATE_CHECK_CLEANUP)"
        UPDATE_FAILS=$(($UPDATE_FAILS + 1)) && echo "$UPDATE_FAILS" > $UPDATE_FAIL_COUNTER
        sleep 120 
        exit 1
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
    if [[ $UPDATE_FAILS -gt $MAX_FAILS ]] $ ; then
        echoErr "ERROR: Setup aborted, max nr. of re-tries reached, to see details type 'cat $LOG_FILE'"
        sleep 120 && systemctl stop kiraup && exit 1
    fi
    rm -fv $LOG_FILE && touch $LOG_FILE
    SUCCESS="true" && $KIRA_MANAGER/images.sh "true" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    set +x
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${SUCCESS,,}" == "true" ] ; then
        touch $UPDATE_CHECK
        UPDATE_FAILS=0 && echo "$UPDATE_FAILS" > $UPDATE_FAIL_COUNTER
    else
        rm -fv "$KIRA_UPDATE/$UPDATE_CHECK_CLEANUP"
        echoErr "ERROR: Failed docker images build ($UPDATE_CHECK_IMAGES)"
        UPDATE_FAILS=$(($UPDATE_FAILS + 1)) && echo "$UPDATE_FAILS" > $UPDATE_FAIL_COUNTER
        sleep 120 
        exit 1
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
    if [[ $UPDATE_FAILS -gt $MAX_FAILS ]] $ ; then
        echoErr "ERROR: Setup aborted, max nr. of re-tries reached, to see details type 'cat $LOG_FILE'"
        sleep 120 && systemctl stop kiraup && exit 1
    fi
    rm -fv $LOG_FILE && touch $LOG_FILE
    SUCCESS="true" && $KIRA_MANAGER/containers.sh "true" | tee $LOG_FILE ; test ${PIPESTATUS[0]} = 0 || SUCCESS="false"
    set +x
    echoInfo "INFO: Logs were saved to $LOG_FILE" && cp -afv $LOG_FILE $UPDATE_DUMP || echoErr "ERROR: Failed to save log file in the dump directory"
    if [ "${SUCCESS,,}" == "true" ] ; then
        touch $UPDATE_CHECK
        UPDATE_FAILS=0 && echo "$UPDATE_FAILS" > $UPDATE_FAIL_COUNTER
    else
        rm -fv "$KIRA_UPDATE/$UPDATE_CHECK_CLEANUP"
        echoErr "ERROR: Failed docker containers build ($UPDATE_CHECK_CONTAINERS)"
        UPDATE_FAILS=$(($UPDATE_FAILS + 1)) && echo "$UPDATE_FAILS" > $UPDATE_FAIL_COUNTER
        sleep 120 
        exit 1
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

echoInfo "INFO: To preview logs type 'cd $UPDATE_LOGS_DIR'"

echoWarn "------------------------------------------------"
echoWarn "| FINISHED: LAUNCH SCRIPT $KIRA_SETUP_VER"
echoWarn "|  ELAPSED: $(($(date -u +%s) - $SCRIPT_START_TIME)) seconds"
echoWarn "------------------------------------------------"

[ "${UPDATE_DONE,,}" == "true" ] && echoErr "Press 'Ctrl+c' to exit then type 'kira' to enter infra manager" && sleep 180 && systemctl stop kiraup && exit 0