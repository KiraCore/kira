#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/kira-setup-status.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
 
set +x
echoInfo "INFO: Checking KIRA Setup Status..."
UPDATE_DONE_FILE="$KIRA_UPDATE/done"
UPDATE_FAIL_FILE="$KIRA_UPDATE/fail"

while [ ! -f "$UPDATE_DONE_FILE" ] || [ -f $UPDATE_FAIL_FILE ] ; do
    set +e && source "/etc/profile" &>/dev/null && set -e

    if [ -f $UPDATE_FAIL_FILE ] ; then
        echoWarn "WARNING: Your node setup FAILED, its reccomended that you [D]ump all logs"
        echoWarn "WARNING: Make sure to investigate issues before reporting them to relevant gitub repository"
        VSEL="." && while ! [[ "${VSEL,,}" =~ ^(v|r|k|d)$ ]]; do echoNErr "Choose to [V]iew setup logs, [R]initalize new node, [D]ump logs or force open [K]IRA Manager: " && read -d'' -s -n1 VSEL && echo ""; done
    else
        echoWarn "WARNING: Your node setup is NOT compleated yet"
        VSEL="." && while ! [[ "${VSEL,,}" =~ ^(v|r|k|d)$ ]]; do echoNErr "Choose to [V]iew setup progress, [R]initalize new node, [D]ump logs or force open [K]IRA Manager: " && read -d'' -s -n1 VSEL && echo ""; done
    fi

    if [ "${VSEL,,}" == "r" ] ; then
        source $KIRA_MANAGER/kira/kira-reinitalize.sh
    elif [ "${VSEL,,}" == "v" ] ; then
        if [ -z "$SETUP_END_DT" ] ; then
            echoInfo "INFO: Starting setup logs preview, to exit type Ctrl+c"
            sleep 2 && journalctl --since "$SETUP_START_DT" -u kiraup -f --output cat
        else
            echoInfo "INFO: Printing setup logs:"
            sleep 2
            if ($(isFileEmpty "$KIRA_DUMP/kiraup-done.log.txt")) ; then
                journalctl --since "$SETUP_START_DT" --until "$SETUP_END_DT" -u kiraup -b --no-pager --output cat
            else
                tryCat "$KIRA_DUMP/kiraup-done.log.txt"
            fi
        fi
    elif [ "${VSEL,,}" == "d" ] ; then
        $KIRA_MANAGER/kira/kira-dump.sh || echoErr "ERROR: Failed logs dump"
    else
        break
    fi
done