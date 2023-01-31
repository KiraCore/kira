#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira-setup-status.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# $KIRA_MANAGER/kira/kira-setup-status.sh --auto_open_km=false
set -x

auto_open_km="true"
getArgs "$1" --gargs_throw=false --gargs_verbose="true"

echoInfo "INFO: Checking KIRA Setup Status..."
timerStart SETUP_STATUS_CHECK
KIRASCAN_LOG="$KIRA_LOGS/kirascan.log"
DOCKER_LOG="$KIRA_LOGS/docker.log"
CLEANUP_LOG="$KIRA_LOGS/kiraclean.log"
KIRAUP_LOG="$KIRA_LOGS/kiraup.log"
KIRAPLAN_LOG="$KIRA_LOGS/kiraplan.log"

while : ; do
    SETUP_END_DT=$(globGet SETUP_END_DT)
    SETUP_START_DT=$(globGet SETUP_START_DT)

    CONTAINERS=$(globGet CONTAINERS)
    CONTAINERS_COUNT=$(globGet CONTAINERS_COUNT)
    INFRA_CONTAINERS_COUNT=$(globGet INFRA_CONTAINERS_COUNT)
    (! $(isNaturalNumber "$CONTAINERS_COUNT")) && CONTAINERS_COUNT=0
    (! $(isNaturalNumber "$INFRA_CONTAINERS_COUNT")) && INFRA_CONTAINERS_COUNT=2

    UPDATE_DONE="$(globGet UPDATE_DONE)"
    UPDATE_FAIL="$(globGet UPDATE_FAIL)"
    UPGRADE_DONE=$(globGet UPGRADE_DONE)
    PLAN_DONE="$(globGet PLAN_DONE)"
    PLAN_FAIL="$(globGet PLAN_FAIL)"

    UPDATE_SERVICE="$(systemctl is-active "kiraup" 2> /dev/null || : )"
    UPGRADE_SERVICE="$(systemctl is-active "kiraplan" 2> /dev/null || : )"
    CLEANUP_SERVICE="$(systemctl is-active "kiraclean" 2> /dev/null || : )"
    MONIT_SERVICE="$(systemctl is-active "kirascan" 2> /dev/null || : )"
    DOCKER_SERVICE="$(systemctl is-active "docker" 2> /dev/null || : )"

    [ -z "$UPDATE_SERVICE" ] && UPDATE_SERVICE="inactive" 
    [ -z "$UPGRADE_SERVICE" ] && UPGRADE_SERVICE="inactive" 
    [ -z "$MONIT_SERVICE" ] && MONIT_SERVICE="inactive" 
    [ -z "$CLEANUP_SERVICE" ] && CLEANUP_SERVICE="inactive" 
    [ -z "$DOCKER_SERVICE" ] && DOCKER_SERVICE="inactive" 
    
    INACTIVE_SERVICES=""
    [ "$UPDATE_SERVICE" != "active" ] && INACTIVE_SERVICES="  kiraup" && colUpd="bla" || colUpd="whi"
    [ "$UPGRADE_SERVICE" != "active" ] && INACTIVE_SERVICES="$INACTIVE_SERVICES, kiraplan" && colUpg="bla" || colUpg="whi"
    [ "$MONIT_SERVICE" != "active" ] && INACTIVE_SERVICES="$INACTIVE_SERVICES, kirascan" && colMon="bla" || colMon="whi"
    [ "$CLEANUP_SERVICE" != "active" ] && INACTIVE_SERVICES="$INACTIVE_SERVICES, kiraclean" && colCle="bla" || colCle="whi"
    [ "$DOCKER_SERVICE" != "active" ] && INACTIVE_SERVICES="$INACTIVE_SERVICES, docker" && colDoc="bla" || colDoc="whi"
    [[ $(strLength "$INACTIVE_SERVICES") -le 2 ]] && INACTIVE_SERVICES=""
    INACTIVE_SERVICES="$(strLastN "$INACTIVE_SERVICES" "$(($(strLength "$INACTIVE_SERVICES") - 2))")"
    INACTIVE_SERVICES=$(echo $INACTIVE_SERVICES | sed 's/^[ \t]*//')
    [ ! -z "$INACTIVE_SERVICES" ] && selS="s" || selS="r"

    NOTIFY_INFO="" 
    colNot="yel"
    colPrg="gre"
    colKM="whi"
    selV="v"
    if [ "${UPDATE_FAIL,,}" == "true" ] ; then
        colNot="red"
        colPrg="red"
        colUpd="red"
        UPDATE_SERVICE="failed"
        NOTIFY_INFO="NODE SETUP FAILED, PLEASE [D]UMP LOGGS AND TRY SETUP AGAIN"
    elif  [ "${PLAN_FAIL,,}" == "true" ] ; then
        colNot="red"
        colPrg="red"
        colUpg="red"
        UPGRADE_SERVICE="failed"
        NOTIFY_INFO="NETWORK UPGRADE FAILED, PLEASE [D]UMP LOGGS AND REINSTALL NODE"
    elif  [ "${MONIT_SERVICE,,}" != "active" ] ; then
        colNot="red"
        colMon="red"
        NOTIFY_INFO="KIRA MONITORING SERVICE IS INACTIVE, PLEASE [R]ESTART SERVICES"
    elif [ "${DOCKER_SERVICE,,}" != "active" ] ; then
        colNot="red"
        CONTAINERS=""
        CONTAINERS_COUNT="0"
        NOTIFY_INFO="DOCKER SERVICE IS NOT ACTIVE, PLEASE [R]ESTART SERVICES"
    else
        if [ "${UPDATE_DONE,,}" != "true" ] ; then
            colPrg="yel"
            NOTIFY_INFO="NODE SETUP IS ONGOING"
        elif [ "${UPGRADE_DONE,,}" != "true" ] ; then
            colPrg="yel"
            NOTIFY_INFO="NETWORK UPGRADE IS ONGOING"
        elif [ "${PLAN_DONE,,}" != "true" ] ; then
            colPrg="yel"
            NOTIFY_INFO="PLANNED UPGRADE IS ONGOING OR AWAITING SCHEDULED BLOCK TIME"
        elif [ "${CLEANUP_SERVICE,,}" != "active" ] ; then
            NOTIFY_INFO="CLEANING SERVICE IS NOT ACTIVE, YOU MIGHT RUN OUT OF DISK SPACE"
        else
            colNot="gre"
            colPrg="bla"
            colKM="gre"
            selV="r"
            NOTIFY_INFO="ALL SYSTEMS READY TO LAUNCH [K]IRA MANAGER"
            if [ "$auto_open_km" == "true" ] ; then
                $KIRA_MANAGER/kira/kira.sh --verify_setup_status="false"
                exit 0
            fi
        fi
    fi

    SETUP_SRV=$(strFixC "$UPDATE_SERVICE" 14)
    UPGRADE_SRV=$(strFixC "$UPGRADE_SERVICE" 15)
    SCAN_SRV=$(strFixC "$MONIT_SERVICE" 15)
    CLEAN_SRV=$(strFixC "$CLEANUP_SERVICE" 15)
    DOCKR_SRV=$(strFixC "$DOCKER_SERVICE" 15)

    DUMP_FILE="$KIRA_DUMP/kira.zip"
    ($(isFileEmpty "$DUMP_FILE")) && DUMP_INFO="dump file is NOT saved" || DUMP_INFO="last saved $(date -r $DUMP_FILE)"
    if [ ! -z "$SETUP_END_DT" ] ; then 
        SETUP_END_INFO="$SETUP_END_DT"
        UNIX_START=$(date2unix $SETUP_START_DT)
        UNIX_END=$(date2unix $SETUP_END_DT)
        SETUP_SPAN=$((UNIX_END - UNIX_START))
    else
        UNIX_NOW="$(date -u +%s)"
        UNIX_START=$(date2unix $SETUP_START_DT)
        SETUP_SPAN=$((UNIX_NOW - UNIX_START))
        SETUP_SPAN=$((UNIX_NOW - UNIX_START))
        SETUP_END_INFO="pending"
    fi
    

    cSubCnt=51
    set +x && printf "\033c" && clear
    echoC ";whi" " =============================================================================="
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "SETUP PROGRESS CHECK TOOL, KM $KIRA_SETUP_VER" 78)")|"
    echoC ";whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
    echoC ";whi" "|  SETUP SERV. | UPGRADE SERV. | MONITOR SERV. | CLEANUP SERV. | DOCKER SERV.  |"
 echoC "sto;whi" "|$(echoC "res;$colUpd" "$SETUP_SRV")|$(echoC "res;$colUpg" "$UPGRADE_SRV")|$(echoC "res;$colMon" "$SCAN_SRV")|$(echoC "res;$colCle" "$CLEAN_SRV")|$(echoC "res;$colDoc" "$DOCKR_SRV")|"
 echoC "sto;whi" "|$(echoC "res;$colNot" "$(strFixC " $NOTIFY_INFO " 78 "." "-")")|"
    echoC ";whi" "|   Node Setup Start Time: $(strFixL "$SETUP_START_DT" $cSubCnt) |"
    echoC ";whi" "|     Node Setup End Time: $(strFixL "$SETUP_END_INFO, elapsed $(prettyTimeSlim $SETUP_SPAN)" $cSubCnt) |"
    echoC ";whi" "|       Active Containers: $(strFixL "$CONTAINERS ($CONTAINERS_COUNT/$INFRA_CONTAINERS_COUNT)" $cSubCnt) |"
    echoC ";whi" "|  Service Logs Directory: $(strFixL "$KIRA_LOGS" $cSubCnt) |"
    ($(isFileEmpty "$DUMP_FILE")) && \
    echoC ";whi" "|     Logs Dump Directory: $(strFixL "$KIRA_DUMP" $cSubCnt) |" || \
    echoC ";whi" "|          Logs Dump File: $(strFixL "$DUMP_FILE ~ $(prettyBytes $(fileSize $DUMP_FILE))" $cSubCnt) |"
 echoC "sto;whi" "|$(echoC "res;bla" "$(strRepeat - 78)")|"
    echoC ";whi" "| [D] |     Dump All Logs: $(strFixL "$DUMP_INFO" $cSubCnt) |"
    [ ! -z "$INACTIVE_SERVICES" ] && \
    echoC ";whi" "| [S] |  Restart Services: $(strFixL "$INACTIVE_SERVICES" $cSubCnt) |"
    echoC ";whi" "| [I] |   Re-Install Node: $(strFixL "$(globGet INFRA_SRC)" $cSubCnt) |"
    echoC "sto;whi" "|$(echoC "res;bla" "$(strRepeat - 78)")|"
 echoC "sto;whi" "| $(echoC "res;$colPrg" "$(strFixL "[V] | View Progress" 23)")|     [R] Refresh     |$(echoC "res;$colKM" "  [K] Open KM  ")|   [X] Exit    |"
    echoNC ";whi" " ------------------------------------------------------------------------------"

    setterm -cursor off 
    pressToContinue --timeout=60 d s k "$selV" r x && VSEL=$(globGet OPTION) || VSEL="r"
    setterm -cursor on
    VSEL="$(toLower "$VSEL")"

    PRESS_TO_CONTINUE="true"
    if [ "$VSEL" == "r" ] ; then
        continue
    elif [ "$VSEL" == "x" ] ; then
        break
    elif [ "$VSEL" == "k" ] ; then
        $KIRA_MANAGER/kira/kira.sh --verify_setup_status="false"
        break
    elif [ "$VSEL" == "d" ] ; then
        $KIRA_MANAGER/kira/kira-dump.sh || ( echoErr "ERROR: Failed logs dump" && echoNC ";gre" "Press any key to continue:" && pressToContinue )
    elif [ "$VSEL" == "i" ] ; then
        $KIRA_MANAGER/kira/kira-reinitalize.sh || ( echoErr "ERROR: Re-installation failed or was cancelled" && sleep 3 )
    elif [ "$VSEL" == "s" ] ; then
        timeout 30 systemctl daemon-reload || echoWarn "WARNING: Failed to reload deamon"
        [ "$UPDATE_SERVICE" != "active" ] && ( systemctl restart kiraup || echoWarn "WARNING: Service 'kiraup' failed to be restarted" )
        [ "$UPGRADE_SERVICE" != "active" ] && ( systemctl restart kiraplan || echoWarn "WARNING: Service 'kiraplan' failed to be restarted" )
        [ "$MONIT_SERVICE" != "active" ] && ( systemctl restart kirascan || echoWarn "WARNING: Service 'kirascan' failed to be restarted" )
        [ "$CLEANUP_SERVICE" != "active" ] && ( systemctl restart kiraclean || echoWarn "WARNING: Service 'kiraclean' failed to be restarted" )
        [ "$DOCKER_SERVICE" != "active" ] && ( systemctl restart docker || echoWarn "WARNING: Service 'docker' failed to be restarted" )
        echoInfo "INFO: Please wait, services are restarting..."
        sleep 10
    elif [ "$VSEL" == "v" ] ; then
        if [ "${UPDATE_DONE,,}" != "true" ] || [ "${UPDATE_FAIL,,}" != "false" ] || ($(isNullOrWhitespaces "$CONTAINERS")) ; then
            if ($(isNullOrWhitespaces "$SETUP_END_DT")) ; then
                clear && echoInfo "INFO: Starting setup logs preview..."
                fileFollow $KIRAUP_LOG
                PRESS_TO_CONTINUE="false"
            else
                clear && echoInfo "INFO: Printing update tools logs:" && sleep 2
                cat $(globGet UPDATE_TOOLS_LOG) || echoErr "ERROR: Tools Update Log was NOT found!"
                echoInfo "INFO: Finished update tools logs." && echoInfo "INFO: Printing update cleanup logs:"
                cat $(globGet UPDATE_CLEANUP_LOG) || echoErr "ERROR: Cleanup Update Log was NOT found!"
                echoInfo "INFO: Finished Printing update cleanup logs." && echoInfo "INFO: Printing update containers logs:"
                cat $(globGet UPDATE_CONTAINERS_LOG) || echoErr "ERROR: Containers Update Log was NOT found!"
                echoInfo "INFO: Finished Printing update containers logs." && echoInfo "INFO: Printing update service logs:"
                cat $KIRAUP_LOG || echoErr "ERROR: Update Log was NOT found! Please run 'journalctl -u kiraup -f --output cat' to see service issues"
                echoInfo "INFO: Finished printing update service logs."
            fi
        elif [ "${PLAN_DONE,,}" != "true" ] || [ "${PLAN_FAIL,,}" != "false" ] || [ "${UPGRADE_DONE,,}" != "true" ] ; then
            if ($(isNullOrWhitespaces "$PLAN_END_DT")) && [ "${PLAN_FAIL,,}" == "false" ] ; then
                clear && echoInfo "INFO: Starting plan logs preview..."
                fileFollow $KIRAPLAN_LOG
                PRESS_TO_CONTINUE="false"
            else
                clear && echoInfo "INFO: Printing plan logs:" && sleep 2
                cat $KIRAPLAN_LOG || echoErr "ERROR: Plan Log was NOT found! Please run 'journalctl -u kiraplan -f --output cat' to see service issues"
            fi
        elif [ "$MONIT_SERVICE" != "active" ] && [ -f "$KIRASCAN_LOG" ] ; then 
            clear && echoInfo "INFO: Printing 'kirascan' service logs:" && sleep 2
            echoInfo "INFO: Printing hosts log"
            cat $(globFile HOSTS_SCAN_LOG) || echoWarn "WARNING: Failed to print hosts scan log"
            echoInfo "INFO: Printing valinfo log"
            cat $(globFile VALINFO_SCAN_LOG) || echoWarn "WARNING: Failed to print valinfo scan log"
            echoInfo "INFO: Printing hardware log"
            cat $(globFile HARDWARE_SCAN_LOG) || echoWarn "WARNING: Failed to print hardware scan log"
            echoInfo "INFO: Printing snaps log"
            cat $(globFile SNAPSHOT_SCAN_LOG) || echoWarn "WARNING: Failed to print snaps scan log"
            echoInfo "INFO: Printing peers log"
            cat $(globFile PEERS_SCAN_LOG) || echoWarn "WARNING: Failed to print peers scan log"
            echoInfo "INFO: Printing containers log"
            cat $(globFile CONTAINERS_SCAN_LOG) || echoWarn "WARNING: Failed to print containers scan log"
            echoInfo "INFO: Printing full kirascan log"
            cat $KIRASCAN_LOG
        elif [ "$DOCKER_SERVICE" != "active" ] && [ -f "$DOCKER_LOG" ] ; then 
            clear && echoInfo "INFO: Printing 'docker' service logs:" && sleep 2
            cat $DOCKER_LOG
        elif [ "${CLEANUP_SERVICE,,}" != "active" ] && [ -f "$CLEANUP_LOG" ] ; then 
            clear && echoInfo "INFO: Printing 'kiraclean' service logs:" && sleep 2
            cat $CLEANUP_LOG
        else
            echoInfo "INFO: No logs to display..."
        fi
        [ "$PRESS_TO_CONTINUE" == "true" ] && echoNC ";gre" "Press any key to continue:" && pressToContinue
    fi
done
