#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira-setup-status.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set -x

echoInfo "INFO: Checking KIRA Setup Status..."
timerStart SETUP_STATUS_CHECK

SETUP_END_DT=$(globGet SETUP_END_DT)
SETUP_START_DT=$(globGet SETUP_START_DT)
UPDATE_DONE=$(globGet UPDATE_DONE)
UPDATE_FAIL=$(globGet UPDATE_FAIL)
PLAN_DONE=$(globGet PLAN_DONE)
PLAN_FAIL=$(globGet PLAN_FAIL)
UPGRADE_DONE=$(globGet UPGRADE_DONE)
CONTAINERS=$(globGet CONTAINERS)

timeout 30 systemctl daemon-reload || echoErr "ERROR: Failed to reload deamon"
# systemctl restart kiraup || echoErr "ERROR: Failed to restart kiraup service"
# systemctl restart kiraplan || echoErr "ERROR: Failed to restart kiraplan service"
# systemctl restart kirascan || echoErr "ERROR: Failed to restart kirascan service"
# systemctl restart kiraclean || echoErr "ERROR: Failed to restart kiraclean service"
# sleep 3

while [ "${PLAN_DONE,,}" != "true" ] || [ "${UPGRADE_DONE,,}" != "true" ] || [ "${PLAN_FAIL,,}" != "false" ] || [ "${UPDATE_FAIL,,}" != "false" ] || [ "${UPDATE_DONE,,}" != "true" ]; do
    
    SETUP_END_DT=$(globGet SETUP_END_DT)
    SETUP_START_DT=$(globGet SETUP_START_DT)
    UPDATE_DONE=$(globGet UPDATE_DONE)
    UPDATE_FAIL=$(globGet UPDATE_FAIL)
    PLAN_DONE=$(globGet PLAN_DONE)
    PLAN_FAIL=$(globGet PLAN_FAIL)
    UPGRADE_DONE=$(globGet UPGRADE_DONE)
    CONTAINERS=$(globGet CONTAINERS)

    set +x
    clear
    cSubCnt=57
    echoC ";whi" " =============================================================================="
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "SETUP PROGRESS CHECK TOOL, KM $KIRA_SETUP_VER" 78)")|"
    echoC ";whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
    echoC ";whi" "|  SETUP START DATE: $(strFixL "$SETUP_START_DT" $cSubCnt) |"
    echoC ";whi" "|    SETUP END DATE: $(strFixL "$SETUP_END_DT" $cSubCnt) |"
    echoC ";whi" "|       UPDATE DONE: $(strFixL "$UPDATE_DONE" $cSubCnt) |"
    echoC ";whi" "|      UPGRADE DONE: $(strFixL "$UPGRADE_DONE" $cSubCnt) |"
    echoC ";whi" "|     UPDATE FAILED: $(strFixL "$UPDATE_FAIL" $cSubCnt) |"
    echoC ";whi" "|         PLAN DONE: $(strFixL "$PLAN_DONE" $cSubCnt) |"
    echoC ";whi" "|       PLAN FAILED: $(strFixL "$PLAN_FAIL" $cSubCnt) |"
    echoC "sto;whi" "|$(echoC "res;bla" "------------------------------------------------------------------------------")|"
    echoC ";whi" "|    KIRAUP SERVICE: $(strFixL "$(systemctl is-active "kiraup" 2> /dev/null || echo "inactive")" $cSubCnt) |"
    echoC ";whi" "|  KIRAPLAN SERVICE: $(strFixL "$(systemctl is-active "kiraplan" 2> /dev/null || echo "inactive")" $cSubCnt) |"
    echoC ";whi" "|  KIRASCAN SERVICE: $(strFixL "$(systemctl is-active "kirascan" 2> /dev/null || echo "inactive")" $cSubCnt) |"
    echoC ";whi" "| KIRACLEAN SERVICE: $(strFixL "$(systemctl is-active "kirascan" 2> /dev/null || echo "inactive")" $cSubCnt) |"
    echoC ";whi" " ------------------------------------------------------------------------------"

    while [ "${UPDATE_DONE,,}" != "true" ] || [ "${UPDATE_FAIL,,}" != "false" ] || ($(isNullOrWhitespaces "$CONTAINERS")) ; do
        set +x
        set +e && source "/etc/profile" &>/dev/null && set -e
        SETUP_END_DT=$(globGet SETUP_END_DT)
        SETUP_START_DT=$(globGet SETUP_START_DT)
        UPDATE_DONE=$(globGet UPDATE_DONE)
        UPDATE_FAIL=$(globGet UPDATE_FAIL)
        CONTAINERS=$(globGet CONTAINERS)
    
        if [ "${UPDATE_FAIL,,}" == "true" ] ; then
            echoWarn "WARNING: Your node setup FAILED, its reccomended that you [D]ump all logs"
            echoWarn "WARNING: Make sure to investigate issues before reporting them to relevant gitub repository"
            echoNLog "Choose to [V]iew setup logs, [R]initalize new node, [D]ump logs or force open [K]IRA Manager: " && pressToContinue v r d k
        else
            echoWarn "WARNING: Your node initial setup is NOT compleated yet"
            echoNLog "Choose to [V]iew setup progress, [R]initalize new node, [D]ump logs or force open [K]IRA Manager: " && pressToContinue v r d k
        fi
        VSEL=$(globGet OPTION)
        set -x
        
        if [ "${VSEL,,}" == "r" ] ; then
            set +x
            source $KIRA_MANAGER/kira/kira-reinitalize.sh
        elif [ "${VSEL,,}" == "v" ] ; then
            if ($(isNullOrWhitespaces "$SETUP_END_DT")) ; then
                clear && echoInfo "INFO: Starting setup logs preview, to exit type Ctrl+c" && sleep 2
                tail -f $KIRA_LOGS/kiraup.log
            else
                clear && echoInfo "INFO: Printing update tools logs:" && sleep 2
                cat $(globGet UPDATE_TOOLS_LOG) || echoErr "ERROR: Tools Update Log was NOT found!"
                echoInfo "INFO: Finished update tools logs." && echoInfo "INFO: Printing update cleanup logs:"
                cat $(globGet UPDATE_CLEANUP_LOG) || echoErr "ERROR: Cleanup Update Log was NOT found!"
                echoInfo "INFO: Finished Printing update cleanup logs." && echoInfo "INFO: Printing update containers logs:"
                cat $(globGet UPDATE_CONTAINERS_LOG) || echoErr "ERROR: Containers Update Log was NOT found!"
                echoInfo "INFO: Finished Printing update containers logs." && echoInfo "INFO: Printing update service logs:"
                cat $KIRA_LOGS/kiraup.log || echoErr "ERROR: Update Log was NOT found! Please run 'journalctl -u kiraup -f --output cat' to see service issues"
                echoInfo "INFO: Finished printing update service logs."
            fi
        elif [ "${VSEL,,}" == "d" ] ; then
            $KIRA_MANAGER/kira/kira-dump.sh || echoErr "ERROR: Failed logs dump"
        else
            exit 0
        fi
    done
    
    while [ "${PLAN_DONE,,}" != "true" ] || [ "${PLAN_FAIL,,}" != "false" ] || [ "${UPGRADE_DONE,,}" != "true" ] ; do
        set +x
        set +e && source "/etc/profile" &>/dev/null && set -e
        PLAN_END_DT=$(globGet PLAN_END_DT)
        PLAN_START_DT=$(globGet PLAN_START_DT)
        PLAN_DONE=$(globGet PLAN_DONE)
        PLAN_FAIL=$(globGet PLAN_FAIL)
        UPGRADE_DONE=$(globGet UPGRADE_DONE)
    
        if [ "${PLAN_FAIL,,}" == "true" ] ; then
            echoWarn "WARNING: Your node upgrade FAILED, its reccomended that you [D]ump all logs"
            echoWarn "WARNING: Make sure to investigate issues before reporting them to relevant gitub repository"
            echoNLog "Choose to [V]iew setup logs, [R]initalize new node, [D]ump logs or force open [K]IRA Manager: " && pressToContinue v r d k
        else
            echoWarn "WARNING: Your node upgrade setup is NOT compleated yet"
            echoNLog "Choose to [V]iew setup progress, [R]initalize new node, [D]ump logs or force open [K]IRA Manager: "  && pressToContinue v r d k
        fi
        VSEL=$(globGet OPTION)
        set -x

        if [ "${VSEL,,}" == "r" ] ; then
            set +x
            source $KIRA_MANAGER/kira/kira-reinitalize.sh
        elif [ "${VSEL,,}" == "v" ] ; then
            if ($(isNullOrWhitespaces "$PLAN_END_DT")) && [ "${PLAN_FAIL,,}" == "false" ] ; then
                clear && echoInfo "INFO: Starting plan logs preview, to exit type Ctrl+c"
                sleep 2 && tail -f $KIRA_LOGS/kiraplan.log
            else
                clear && echoInfo "INFO: Printing plan logs:" && sleep 2
                cat $KIRA_LOGS/kiraplan.log || echoErr "ERROR: Plan Log was NOT found! Please run 'journalctl -u kiraplan -f --output cat' to see service issues"
            fi
        elif [ "${VSEL,,}" == "d" ] ; then
            $KIRA_MANAGER/kira/kira-dump.sh || echoErr "ERROR: Failed logs dump"
        else
            exit 0
        fi
    done
done

set +x
echoWarn "------------------------------------------------"
echoWarn "| FINISHED: KIRA SETUP STATUS CHECK            |"
echoWarn "|  ELAPSED: $(timerSpan SETUP_STATUS_CHECK) seconds"
echoWarn "------------------------------------------------"
set -x