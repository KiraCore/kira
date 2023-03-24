#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# $KIRA_MANAGER/kira/kira.sh --verify_setup_status=false
set +x

# Force console colour to be black and text gray
tput setab 0
tput setaf 7

echoNInfo "\n\nINFO: Launching KIRA Network Manager...\n"

if [ "${USER,,}" != "root" ]; then
    echoErr "ERROR: You have to run this application as root, try 'sudo -s' command first"
    exit 1
fi

verify_setup_status="true"
getArgs "$1" --gargs_throw=false --gargs_verbose="true"

# signal that system monitor didn't finished running yet
globSet IS_SCAN_DONE "false"

if [ "$verify_setup_status" == "true" ] ; then
    $KIRA_MANAGER/kira/kira-setup-status.sh --auto_open_km="true"
    exit 0
fi

###################################################################
set -x

cd "$(globGet KIRA_HOME)"
VALSTATUS_SCAN_PATH="$KIRA_SCAN/valstatus"
INTERX_SNAPSHOT_PATH="$INTERX_REFERENCE_DIR/snapshot.tar"

mkdir -p "$INTERX_REFERENCE_DIR"


INFRA_CONTAINERS_COUNT=$(globGet INFRA_CONTAINERS_COUNT)

INFRA_MODE=$(globGet INFRA_MODE)
CHAIN_ID=$(jsonQuickParse "chain_id" $LOCAL_GENESIS_PATH || echo "$NETWORK_NAME")
MAIN_CONTAINER="$INFRA_MODE"
MAIN_CONTAINERS=(interx $MAIN_CONTAINER)

##########################################################
# ENSURE KM CAN DISPLAY STATS
##########################################################

MONIT_SERVICE="$(systemctl is-active "kirascan" 2> /dev/null || : )"
DOCKER_SERVICE="$(systemctl is-active "docker" 2> /dev/null || : )"
if [ "$MONIT_SERVICE" != "active" ] ; then
    echoErr "ERROR: Sytem monitorig service is NOT active"
    exit 1
elif [ "$DOCKER_SERVICE" != "active" ] ; then
    echoErr "ERROR: Docker service is NOT active"
    exit 1
fi

function cleanup() {
    echoNInfo "\n\nINFO: Exiting script...\n"
    setterm -cursor on
    exit 130
}

set +x

while : ; do
    

    ##########################################################
    echoInfo "LOADING SYSTEM UTILIZATION STATISTICS..."
    ##########################################################

    CPU_UTIL="$(globGet CPU_UTIL)"      && [ -z "$CPU_UTIL" ]   && CPU_UTIL="???" && colCPU="bla" || colCPU="whi"
    RAM_UTIL="$(globGet RAM_UTIL)"      && [ -z "$RAM_UTIL" ]   && RAM_UTIL="???" && colRAM="bla" || colRAM="whi"
    DISK_UTIL="$(globGet DISK_UTIL)"    && [ -z "$DISK_UTIL" ]  && DISK_UTIL="???" && colDIS="bla" || colDIS="whi"
    NET_IN="$(globGet NET_IN)"          && [ -z "$NET_IN" ]     && NET_IN="???" && colNIN="bla" || colNIN="whi"
    NET_OUT="$(globGet NET_OUT)"        && [ -z "$NET_OUT" ]    && NET_OUT="???" && colNUT="bla" || colNUT="whi"
    NET_IFACE="$(globGet IFACE)"        && [ -z "$NET_IFACE" ]  && NET_IFACE="???" && colIFA="bla" || colIFA="whi"

    [ "$CPU_UTIL" == "100%" ] && colCPU="red"
    [ "$RAM_UTIL" == "100%" ] && colRAM="red"
    [ "$DISK_UTIL" == "100%" ] && colDIS="red"

    CPU_UTIL=$(strFixC "$CPU_UTIL" 12)
    RAM_UTIL=$(strFixC "$RAM_UTIL" 12)
    DISK_UTIL=$(strFixC "$DISK_UTIL" 12)
    NET_IN="$(prettyBytes $NET_IN)/s" && NET_IN=$(strFixC "$NET_IN" 12)
    NET_OUT="$(prettyBytes $NET_OUT)/s" && NET_OUT=$(strFixC "$NET_OUT" 12)
    NET_IFACE=$(strFixC "$NET_IFACE" 13)

    ##########################################################
    echoInfo "LOADING BLOCKCHAIN STATISTICS..."
    ##########################################################

    VAL_ACT=$(globGet VAL_ACTIVE)       && (! $(isNaturalNumber $VAL_ACT)) && VAL_ACT="???" && colACT="bla" || colACT="whi"
    VAL_TOT=$(globGet VAL_TOTAL)        && (! $(isNaturalNumber $VAL_TOT)) && VAL_TOT="???" && colTOT="bla" || colTOT="whi"
    VAL_WAI=$(globGet VAL_WAITING)      && (! $(isNaturalNumber $VAL_WAI)) && VAL_WAI="???" && colWAI="bla" || colWAI="whi"
    BLO_NUM=$(globGet LATEST_BLOCK_HEIGHT "$GLOBAL_COMMON_RO") && (! $(isNaturalNumber $BLO_NUM)) && BLO_NUM="???" && colNUM="bla" || colNUM="whi"
    BLO_TIM=$(globGet CONS_BLOCK_TIME)  && (! $(isNumber $BLO_TIM)) && BLO_TIM="???" && colTIM="bla" || colTIM="whi"
    CHA_NAM="$CHAIN_ID"                 && [ -z "$CHA_NAM" ]  && CHA_NAM="???" && colNAM="bla" || colNAM="whi"

    ($(isNumber "$BLO_TIM")) && BLO_TIM=$(echo "scale=3; ( $BLO_TIM / 1 ) " | bc) && BLO_TIM="~${BLO_TIM}s"

    ##########################################################
    echoInfo "LOADING NETWORK & SUBNET INFO..."
    ##########################################################

    PUB_IPA=$(globGet PUBLIC_IP)             && (! $(isDnsOrIp "$PUB_IPA")) && PUB_IPA="???" && colPIP="bla" || colPIP="whi"
    LOC_IPA=$(globGet LOCAL_IP)              && (! $(isDnsOrIp "$LOC_IPA")) && LOC_IPA="???" && colLIP="bla" || colLIP="whi"
    DCK_SUB="$(globGet KIRA_DOCKER_SUBNET)"  && (! $(isCIDR "$DCK_SUB"))  && DCK_SUB="???" && colDNT="bla" || colDNT="whi"
    DCK_NET="$(globGet KIRA_DOCKER_NETWORK)"

    [ "$PUB_IPA" == "0.0.0.0" ]     && PUB_IPA="???" && colPIP="bla" 
    [ "$LOC_IPA" == "0.0.0.0" ]     && LOC_IPA="???" && colLIP="bla" 
    [ "$DCK_SUB" == "0.0.0.0/0" ]   && DCK_SUB="???" && colLIP="bla" 
    
    PUB_IPA=$(strFixC "$PUB_IPA" 25)
    LOC_IPA=$(strFixC "$LOC_IPA" 25)
    DCK_SUB=$(strFixC "$DCK_SUB" 26)

    ##########################################################
    echoInfo "LOADING SNAPSHOT & GENESIS INFO..."
    ##########################################################

    KIRA_SNAP_PATH="$(globGet KIRA_SNAP_PATH)"
    SNA_PTH="$(basename -- "$KIRA_SNAP_PATH")"  && ($(isFileEmpty $SNA_PTH)) && SNA_PTH="???" && colSPH="bla" || colSPH="whi"
    SNA_SHA="$(globGet KIRA_SNAP_SHA256)"       && (! $(isSHA256 $SNA_SHA)) && SNA_SHA="???...???" && colSNS="bla" || colSNS="whi"
    GEN_SHA="$(globGet GENESIS_SHA256)"         && (! $(isSHA256 $GEN_SHA)) && GEN_SHA="???...???" && colGSH="bla" || colGSH="whi"

    (! $(isFileEmpty $SNA_PTH)) && SNA_PTH=$(basename -- "$SNA_PTH")

    SNA_PTH=$(strFixC " $SNA_PTH " 25)
    SNA_SHA=$(strFixC " $SNA_SHA " 25)
    GEN_SHA=$(strFixC " $GEN_SHA " 26)

    ##########################################################
    
    SCAN_DONE=$(globGet IS_SCAN_DONE)
    if [ "$SCAN_DONE" == "true" ]; then
        ##########################################################
        echoInfo "LOADING CONTAINERS INFO"...
        ##########################################################

        ALL_CONTAINERS_PAUSED="true"
        ALL_CONTAINERS_STOPPED="true"
        ALL_CONTAINERS_HEALTHY="true"
        ALL_CONTAINERS_RUNNING="true"

        for name in "${MAIN_CONTAINERS[@]}"; do
            GLOBAL_COMMON="$DOCKER_COMMON/${name}/kiraglob"
            CONTAINER_STATUS="unknown"
            CONTAINER_HEALTH="unknown"
            CONTAINER_SYNCING="false"
            CONTAINER_BLOCK="0"
            CONTAINER_EXISTS="$(globGet "${name}_EXISTS")"
            CONTAINER_RUNTIME="$(globGet RUNTIME_VERSION "$GLOBAL_COMMON")"
            [ -z "$CONTAINER_RUNTIME" ] && CONTAINER_RUNTIME="unknown"

            if [ "$CONTAINER_EXISTS" == "true" ] ; then
                CONTAINER_STATUS="$(globGet "${name}_STATUS")"
                CONTAINER_HEALTH="$(globGet "${name}_HEALTH")"
                CONTAINER_BLOCK="$(globGet "${name}_BLOCK")"
                CONTAINER_SYNCING="$(globGet "${name}_SYNCING")"
                [ -z "$CONTAINER_STATUS" ] && CONTAINER_SYNCING="unknown"
                [ -z "$CONTAINER_HEALTH" ] && CONTAINER_HEALTH="unknown"
                [ "$CONTAINER_SYNCING" == "true" ] && CONTAINER_SYNCING="syncing"
                (! $(isNaturalNumber $CONTAINER_SYNCING)) && CONTAINER_SYNCING="0"
            else
                CONTAINER_EXISTS="false"
            fi

            [ "${CONTAINER_STATUS,,}" != "running" ] && ALL_CONTAINERS_RUNNING="false"
            [ "${CONTAINER_STATUS,,}" != "exited" ]  && ALL_CONTAINERS_STOPPED="false"
            [ "${CONTAINER_STATUS,,}" != "paused" ]  && ALL_CONTAINERS_PAUSED="false"
            [ "${CONTAINER_HEALTH,,}" != "healthy" ] && ALL_CONTAINERS_HEALTHY="false"

            [ "$name" == "$MAIN_CONTAINER" ] && suffix="MAIN_" || suffix="$(toUpper "${name}_")"
            
            eval "${suffix}CONTAINER_STATUS"="'$CONTAINER_STATUS'"
            eval "${suffix}CONTAINER_HEALTH"="'$CONTAINER_HEALTH'"
            eval "${suffix}CONTAINER_SYNCING"="'$CONTAINER_SYNCING'"
            eval "${suffix}CONTAINER_BLOCK"="'$CONTAINER_BLOCK'"
            eval "${suffix}CONTAINER_EXISTS"="'$CONTAINER_EXISTS'"
            eval "${suffix}CONTAINER_RUNTIME"="'$CONTAINER_RUNTIME'"
        done

        ##########################################################
        echoInfo "LOADING STATUSES..."
        ##########################################################

        colNot="gre"
        NOTIFY_INFO="NO ISSUES DETECTED, ALL SYSTEMS RUNNING"

    else
        ALL_CONTAINERS_HEALTHY=""

        for name in "${MAIN_CONTAINERS[@]}"; do
            [ "$name" == "$MAIN_CONTAINER" ] && suffix="MAIN_" || suffix="$(toUpper "${name}_")"
            eval "${suffix}CONTAINER_STATUS"="'loading...'"
            eval "${suffix}CONTAINER_HEALTH"="'loading...'"
            eval "${suffix}CONTAINER_SYNCING"="'loading...'"
            eval "${suffix}CONTAINER_BLOCK"="'loading...'"
            eval "${suffix}CONTAINER_EXISTS"="'false'"
            eval "${suffix}CONTAINER_RUNTIME"="'loading...'"
        done
        VAL_ACT="loading..." && colACT="bla" 
        VAL_TOT="loading..." && colTOT="bla"
        VAL_WAI="loading..." && colWAI="bla"
        BLO_NUM="loading..." && colNUM="bla"
        BLO_TIM="loading..." && colTIM="bla"
        
        colNot="yel"
        NOTIFY_INFO="PLEASE WAIT, LOADING STATUS OF ALL SYSTEMS"
    fi

    if [ "$ALL_CONTAINERS_HEALTHY" == "false" ] ; then
        if [ "$MAIN_CONTAINER_HEALTH" != "healthy" ] ; then
            colNot="red"
            NOTIFY_INFO="ESSENTIAL CONTAINERS ARE FAILING HEALTHCHECK"
        else
            colNot="yel"
            NOTIFY_INFO="SOME CONTAINERS ARE FAILING HEALTHCHECK"
        fi
    fi

    ##########################################################
    echoInfo "LOADING SNAPSHOT INFO..."
    ##########################################################

    SNAP_EXPOSE=$(globGet SNAP_EXPOSE)
    SNAPSHOT_EXECUTE=$(globGet SNAPSHOT_EXECUTE)
    
    selB="b"
    colSnaOpt="whi"
    colSnaInf="whi"
    SNAP_OPTN="Create or Expose Snapshot"
    SNAP_INFO=""
    if [ "${SNAPSHOT_EXECUTE,,}" == "true" ] ; then
        SNAP_INFO="snapshot is scheduled or ongoing..."
        colSnaInf="yel"
        colSnaOpt="bla"
        selB="r"
    elif ($(isFileEmpty $KIRA_SNAP_PATH)) ; then
        SNAP_INFO="no snapshots were found"
    elif [ "$SNAP_EXPOSE" == "true" ] ; then
        SNAP_INFO="snapshot is exposed"
    elif [ "$SNAP_EXPOSE" != "true" ] ; then
        SNAP_INFO="snapshot is NOT exposed"
        SNAP_OPTN="Create or Hide Snapshot"
    fi

    if [ "${SNAPSHOT_EXECUTE,,}" != "true" ] && [ "$MAIN_CONTAINER_STATUS" != "running" ] ; then
        SNAP_INFO="stopped node can't be snapshot"
        colSnaInf="red"
        colSnaOpt="bla"
        selB="r"
    fi

    ##########################################################
    echoInfo "LOADING AUTOMATED UPGRADES INFO..."
    ##########################################################

    AUTO_UPGRADES=$(globGet AUTO_UPGRADES)
    colAupOpt="whi"
    colAupInf="whi"
    if [ "$AUTO_UPGRADES" == "true" ] ; then
        AUPG_OPTN="Disable Automated Upgrades"
        AUPG_INFO="enabled"
    else
        AUPG_OPTN="Enable Automated Upgrades"
        AUPG_INFO="disabled"
        colAupInf="red"
    fi

    ##########################################################
    echoInfo "LOADING NETWORKING & FIREWALL INFO..."
    ##########################################################

    PORTS_EXPOSURE=$(toLower "$(globGet PORTS_EXPOSURE)")
    colNetOpt="whi"
    colNetInf="whi"
    NETF_OPTN="Manage Networking & Firewall"
    NETF_INFO="undefined"
    
    if [ "$PORTS_EXPOSURE" == "enabled" ] ; then
        NETF_INFO="all ports open to public networks"
        colNetInf="red"
    elif [ "$PORTS_EXPOSURE" == "custom" ] ; then
        NETF_INFO="custom ports exposure"
    elif [ "$PORTS_EXPOSURE" == "disabled" ] ; then
        NETF_INFO="access to all ports is disabled"
    fi

    ##########################################################
    echoInfo "LOADING UPGRADES INFO..."
    ##########################################################

    PLAN_DONE=$(globGet PLAN_DONE)
    UPGRADE_DONE=$(globGet UPGRADE_DONE)
    PLAN_FAIL=$(globGet PLAN_FAIL)
    UPDATE_FAIL=$(globGet UPDATE_FAIL)
    LATEST_BLOCK_TIME=$(globGet LATEST_BLOCK_TIME $GLOBAL_COMMON_RO)
    UPGRADE_INSTATE=$(globGet UPGRADE_INSTATE)
    UPGRADE_TIME=$(globGet "UPGRADE_TIME")
    (! $(isNaturalNumber "$UPGRADE_TIME")) && UPGRADE_TIME=0
    (! $(isNaturalNumber "$LATEST_BLOCK_TIME")) && LATEST_BLOCK_TIME=0

    if [ "${PLAN_DONE,,}" != "true" ] || [ "${UPGRADE_DONE,,}" != "true" ] || [ "${PLAN_FAIL,,}" == "true" ] || [ "${UPDATE_FAIL,,}" == "true" ] ; then # plan in action
        UPGRADE_TIME_LEFT=$(($UPGRADE_TIME - $LATEST_BLOCK_TIME))
        UPGRADE_TYPE="HARD"
        [ "${UPGRADE_INSTATE,,}" == "true" ] && UPGRADE_TYPE="SOFT"
        TMP_UPGRADE_MSG="NEW $UPGRADE_TYPE FORK UPGRADE"
        if [ "${PLAN_FAIL,,}" == "true" ] || [ "${UPDATE_FAIL,,}" == "true" ] ; then
            colNot="red"
            NOTIFY_INFO="UPGRADE FAILED, REINSTALL NODE MANUALLY"
        elif [[ $UPGRADE_TIME_LEFT -gt 0 ]] && [[ $UPGRADE_TIME_LEFT -lt 31536000 ]] ; then
            UPGRADE_TIME_LEFT=$(prettyTimeSlim $UPGRADE_TIME_LEFT)
            NOTIFY_INFO="${TMP_UPGRADE_MSG} IN $UPGRADE_TIME_LEFT"
        else
            colNot="yel"
            NOTIFY_INFO="${TMP_UPGRADE_MSG} IS ONGOING"
        fi
    fi

    ##########################################################
    echoInfo "LOADING VALIDATOR SPECIFIC CONFIGURATION..."
    ##########################################################

    CATCHING_UP=$(globGet CATCHING_UP)
    VALSTATUS=$(jsonQuickParse "status" $VALSTATUS_SCAN_PATH 2>/dev/null || echo -n "")
    ($(isNullOrEmpty "$VALSTATUS")) && VALSTATUS=""
    colValOpt="whi"
    colValInf="whi"
    VALR_OPTN="undefined"
    VALR_INFO="undefined"
    if (! $(isNullOrWhitespaces "$VALSTATUS")) && [ "$MAIN_CONTAINER" == "validator" ] && [ "$CATCHING_UP" != "true" ] ; then
        selV="v"

        if [ "${VALSTATUS,,}" == "active" ] ; then
            VALR_OPTN="Enable Maintenance Mode"
            VALR_INFO="node is actively producing blocks"
            selV="e"
        elif [ "${VALSTATUS,,}" == "paused" ] ; then
            VALR_OPTN="Disable Maintenance Mode"
            VALR_INFO="node was gacefully paused"
            colValInf="yel"
            selV="d"
        elif [ "${VALSTATUS,,}" == "inactive" ] ; then
            VALR_OPTN="Re-Activate Halted Node"
            VALR_INFO="inactive node can't sign blcoks"
            colValOpt="gre"
            colValInf="yel"
            selV="a"
        elif [ "${VALSTATUS,,}" == "waiting" ] ; then
            VALR_OPTN="Join Validator Set"
            VALR_INFO="waiting to claim validator seat"
            selV="j"
        elif [ "${VALSTATUS,,}" == "jailed" ] ; then
            colNot="red"
            NOTIFY_INFO="VALIDATOR COMMITED DOUBLE-SIGNING FAULT"
            selV="r"
        fi
    else
        selV="r"
        colValOpt="bla"
    fi

    if [ "${SCAN_DONE,,}" == "true" ] && [ "$CATCHING_UP" == "true" ] ; then
        colNot="yel"
        NOTIFY_INFO="PLEASE WAIT, CATCHING UP WITH LATEST NETWORK STATE"
    fi

    ##########################################################
    echoInfo "FORMATTING DATA FIELDS..."
    ##########################################################

    VAL_ACT=$(strFixC "$VAL_ACT" 12)
    VAL_TOT=$(strFixC "$VAL_TOT" 12)
    VAL_WAI=$(strFixC "$VAL_WAI" 12)
    BLO_NUM=$(strFixC "$BLO_NUM" 12)
    BLO_TIM=$(strFixC "$BLO_TIM" 12)
    CHA_NAM=$(strFixC "$CHA_NAM" 13)

    MAIN_CNTN=$(strFixC "$MAIN_CONTAINER" 19)
    MAIN_STAT=$(strFixC "$MAIN_CONTAINER_STATUS" 12)
    MAIN_BLOC=$(strFixC "$MAIN_CONTAINER_BLOCK" 12)
    MAIN_HEAL=$(strFixC "$MAIN_CONTAINER_HEALTH" 12)
    MAIN_RUNT=$(strFixC "$MAIN_CONTAINER_RUNTIME" 13)

    INTX_CNTN=$(strFixC "interx" 19)
    INTX_STAT=$(strFixC "$INTERX_CONTAINER_STATUS" 12)
    INTX_BLOC=$(strFixC "$INTERX_CONTAINER_BLOCK" 12)
    INTX_HEAL=$(strFixC "$INTERX_CONTAINER_HEALTH" 12)
    INTX_RUNT=$(strFixC "$INTERX_CONTAINER_RUNTIME" 13)

    SNAP_OPTN=$(strFixC "$SNAP_OPTN" 30)
    SNAP_INFO=$(strFixC "$SNAP_INFO" 37)

    AUPG_OPTN=$(strFixC "$AUPG_OPTN" 30)
    AUPG_INFO=$(strFixC "$AUPG_INFO" 37)

    NETF_OPTN=$(strFixC "$NETF_OPTN" 30)
    NETF_INFO=$(strFixC "$NETF_INFO" 37)

    VALR_OPTN=$(strFixC "$VALR_OPTN" 30)
    VALR_INFO=$(strFixC "$VALR_INFO" 37)

    set +x && printf "\033c" && clear
    echoC ";whi" " =============================================================================="
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "KIRA $(toUpper $INFRA_MODE) NODE MANAGER $KIRA_SETUP_VER" 78)")|"
    echoC ";whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
    echoC ";whi" "|  CPU USAGE | RAM MEMORY | DISK SPACE |  UP.SPEED  |  DN.SPEED  |  INTERFACE  |"
    echoC ";whi" "|$(echoC "res;$colCPU" "$CPU_UTIL")|$(echoC "res;$colRAM" "$RAM_UTIL")|$(echoC "res;$colDIS" "$DISK_UTIL")|$(echoC "res;$colNIN" "$NET_IN")|$(echoC "res;$colNUT" "$NET_OUT")|$(echoC "res;$colIFA" "$NET_IFACE")|"
    echoC ";whi" "| VAL.ACTIVE | V.INACTIVE | V.WAITING  |   BLOCKS   | BLOCK TIME |   NETWORK   |"
    echoC ";whi" "|$(echoC "res;$colACT" "$VAL_ACT")|$(echoC "res;$colTOT" "$VAL_TOT")|$(echoC "res;$colWAI" "$VAL_WAI")|$(echoC "res;$colNUM" "$BLO_NUM")|$(echoC "res;$colTIM" "$BLO_TIM")|$(echoC "res;$colNAM" "$CHA_NAM")|"
    echoC ";whi" "|$(strFixC " PUBLIC IP " 25 "" "-")|$(strFixC " LOCAL IP " 25 "" "-")|$(strFixC " SUBNET ($DCK_NET) " 26 "" "-")|"
    echoC ";whi" "|$(echoC "res;$colPIP" "$PUB_IPA")|$(echoC "res;$colLIP" "$LOC_IPA")|$(echoC "res;$colDNT" "$DCK_SUB")|"
    echoC ";whi" "|      SNAPSHOT NAME      |    SNAPSHOT CHECKSUM    |     GENESIS CHECKSUM     |"
    echoC ";whi" "|$(echoC "res;$colSPH" "$SNA_PTH")|$(echoC "res;$colSNS" "$SNA_SHA")|$(echoC "res;$colGSH" "$GEN_SHA")|"
    echoC ";whi" "|$(echoC "res;$colNot" "$(strFixC " $NOTIFY_INFO " 78 "." "-")")|"
    echoC ";whi" "|     |  CONTAINER NAME   |   STATUS   |   BLOCKS   |   HEALTH   | APP.VERSION |"
    echoC ";whi" "| [0] |$MAIN_CNTN|$MAIN_STAT|$MAIN_BLOC|$MAIN_HEAL|$MAIN_RUNT|"
    echoC ";whi" "| [1] |$INTX_CNTN|$INTX_STAT|$INTX_BLOC|$INTX_HEAL|$INTX_RUNT|"
    #echoC ";whi" "|$(echoC "res;bla" "$(strFixC "-" 78 "." "-")")|"
    echoC ";whi" "|$(echoC "res;bla" "-----|-------- SELECT OPTION ---------:------------ CURRENT VALUE ------------")|"
    echoC ";whi" "| $(echoC "res;$colSnaOpt" "[B] | $SNAP_OPTN") : $(echoC "res;$colSnaInf" "$SNAP_INFO") |"
    echoC ";whi" "| $(echoC "res;$colAupOpt" "[U] | $AUPG_OPTN") : $(echoC "res;$colAupInf" "$AUPG_INFO") |"
    echoC ";whi" "| $(echoC "res;$colNetOpt" "[N] | $NETF_OPTN") : $(echoC "res;$colNetInf" "$NETF_INFO") |"
    [ "$selV" != "r" ] && \
    echoC ";whi" "| $(echoC "res;$colValOpt" "[$(toUpper "$selV")] | $VALR_OPTN") : $(echoC "res;$colValInf" "$VALR_INFO") |"
    echoC ";whi" "|$(echoC "res;bla" "$(strRepeat - 78)")|"
    echoC ";whi" "| [S]   Open Services & Setup Tool     |    [R]  Refresh    |     [X] Exit     |"
   echoNC ";whi" " ------------------------------------------------------------------------------"
    setterm -cursor off
    trap cleanup SIGINT

    timeout=300
    [ "$SCAN_DONE" != "true" ] && timeout=10
    pressToContinue --timeout=$timeout 0 1 "$selB" u n "$selV" s r x && VSEL=$(toLower "$(globGet OPTION)") || VSEL="r"
    setterm -cursor on
    clear

    [ "$VSEL" != "r" ] && echoInfo "INFO: Option '$VSEL' was selected, processing request..."

    PRESS_TO_CONTINUE="true"
    if [ "$VSEL" == "0" ] ; then
        PRESS_TO_CONTINUE="false"
        $KIRA_MANAGER/kira/container-manager.sh --name="$MAIN_CONTAINER" || ( echoErr "ERROR: Faile to inspect '$MAIN_CONTAINER' container" && PRESS_TO_CONTINUE="false" )
    elif [ "$VSEL" == "1" ] ; then
        PRESS_TO_CONTINUE="false"
        $KIRA_MANAGER/kira/container-manager.sh --name="interx" || ( echoErr "ERROR: Faile to inspect 'interx' container" && PRESS_TO_CONTINUE="false" )
    elif  [ "$VSEL" == "r" ] ; then
        continue
    elif  [ "$VSEL" == "s" ] ; then
        return 200
    elif  [ "$VSEL" == "x" ] ; then
        return 0
    elif  [ "$VSEL" == "b" ] ; then
        echoInfo "INFO: Staring backup configurator..."
        $KIRA_MANAGER/kira/kira-backup.sh || echoErr "ERROR: Snapshot setup failed"
        globSet IS_SCAN_DONE "false"
    elif  [ "$VSEL" == "u" ] ; then
        echoInfo "INFO: Changing auto-upgrade settings..."
        [ "${AUTO_UPGRADES,,}" != "true" ] && globSet AUTO_UPGRADES "true" || \
            globSet AUTO_UPGRADES "false"
        continue
    elif  [ "$VSEL" == "n" ] ; then
        echoInfo "INFO: Staring networking manager..."
        $KIRA_MANAGER/kira/kira-networking.sh || echoErr "ERROR: Network manager failed"
    elif  [ "$VSEL" == "$selV" ] && [ "$VSEL" != "r" ] ; then
        if [ "${VALSTATUS,,}" == "active" ] ; then
            echoInfo "INFO: Attempting to change validator status from ACTIVE to PAUSED..."
            ( docker exec -i validator /bin/bash -c ". /etc/profile && pauseValidator validator" || \
                echoErr "ERROR: Failed to confirm pause tx" ) && echoWarn "WARNINIG: Please be patient, it might take couple of minutes before your status changes in the KIRA Manager..."
            sleep 5
        elif [ "${VALSTATUS,,}" == "paused" ] ; then
            echoInfo "INFO: Attempting to change validator status from PAUSED to ACTIVE..."
            ( docker exec -i validator /bin/bash -c ". /etc/profile && unpauseValidator validator" || \
                echoErr "ERROR: Failed to confirm pause tx" ) && echoWarn "WARNINIG: Please be patient, it might take couple of minutes before your status changes in the KIRA Manager..."
            sleep 5
        elif [ "${VALSTATUS,,}" == "inactive" ] ; then
            echoInfo "INFO: Attempting to change validator status from INACTIVE to ACTIVE..."
            ( docker exec -i validator /bin/bash -c ". /etc/profile && activateValidator validator" || \
                echoErr "ERROR: Failed to confirm activate tx" ) && echoWarn "WARNINIG: Please be patient, it might take couple of minutes before your status changes in the KIRA Manager..."
            sleep 60
        elif [ "${VALSTATUS,,}" == "waiting" ] ; then
            echoInfo "INFO: Attempting to claim validator seat..."
            MONIKER=""
            while (! $(isAlphanumeric "$MONIKER")) ; do
                echoNC ";whi" "\nInput unique alphanumeric node name: " && read MONIKER
                MONIKER="$(delWhitespaces "$MONIKER")"
            done

            echoNInfo "\nINFO: Attempting to claim validator seat...\n"
            SUCCESS=false
            docker exec -i validator /bin/bash -c ". /etc/profile && claimValidatorSeat validator \"$MONIKER\"" && SUCCESS=true || \
                echoErr "ERROR: Failed to confirm claim validator tx"

            VALIDATOR_NODE_ID="$(tryGetVar VALIDATOR_NODE_ID "$MNEMONICS")"
            if [ "$SUCCESS" == "true" ] && [ ! -z "$VALIDATOR_NODE_ID" ] ; then
                echoNInfo "\nINFO: Adding validator node-id identity record...\n"
                ( docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord validator \"validator_node_id\" \"$VALIDATOR_NODE_ID\" 180" || \
                    echoErr "ERROR: Failed to confirm indentity registrar upsert tx" )
            fi
        fi

        globSet IS_SCAN_DONE "false"
    else
        echoInfo "INFO: Option '$VSEL' is NOT available at the moment."
    fi

    [ "$PRESS_TO_CONTINUE" == "true" ] && echoNC "bli;whi" "Press any key to continue..." && pressToContinue
    continue

####################################################################
#    if [ "${SCAN_DONE,,}" == "true" ]; then
#
#
#        if [ "${CATCHING_UP,,}" == "true" ]; then
#            echo -e "|\e[0m\e[33;1m     PLEASE WAIT, NODES ARE CATCHING UP        \e[33;1m|"
#        elif [[ $CONTAINERS_COUNT -lt $INFRA_CONTAINERS_COUNT ]]; then
#            echo -e "|\e[0m\e[31;1m ISSUES DETECTED, NOT ALL CONTAINERS LAUNCHED  \e[33;1m: ${CONTAINERS_COUNT}/${INFRA_CONTAINERS_COUNT}"
#        elif [ "${ALL_CONTAINERS_HEALTHY,,}" != "true" ]; then
#            echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRASTRUCTURE IS UNHEALTHY  \e[33;1m|"
#        elif [ "${SUCCESS,,}" == "true" ] && [ "${ALL_CONTAINERS_HEALTHY,,}" == "true" ]; then
#            [ -z "$VALIDATOR_ADDR" ] && echo -e "|\e[0m\e[32;1m      SUCCESS, INFRASTRUCTURE IS HEALTHY       \e[33;1m|"
#        else
#            echo -e "|\e[0m\e[31;1m    INFRASTRUCTURE IS NOT FULLY OPERATIONAL    \e[33;1m|"
#        fi
#    fi
########################################
#            echoInfo "INFO: Exposing latest snapshot '$KIRA_SNAP_PATH' via INTERX"
#            globSet SNAP_EXPOSE "true"
#            ln -fv "$KIRA_SNAP_PATH" "$INTERX_SNAPSHOT_PATH" && \
#                echoInfo "INFO: Await few minutes and your snapshot will become available via 0.0.0.0:$(globGet CUSTOM_INTERX_PORT)/download/snapshot.tar" || \
#                echoErr "ERROR: Failed to create snapshot symlink"
#        else
#            echoInfo "INFO: Ensuring exposed snapshot will be removed..."
#            globSet SNAP_EXPOSE "false"
#            rm -fv "$INTERX_SNAPSHOT_PATH" && \
#                echoInfo "INFO: Await few minutes and your snapshot will become unavailable" || \
#                echoErr "ERROR: Failed to remove snapshot symlink"
########################################

done
