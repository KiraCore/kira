#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
set +X

# Force console colour to be black
tput setab 0
echoInfo "INFO: Launching KIRA Network Manager..."

if [ "${USER,,}" != "root" ]; then
    echoErr "ERROR: You have to run this application as root, try 'sudo -s' command first"
    exit 1
fi

verify_setup_status="true"
getArgs "$1" --gargs_throw=false --gargs_verbose="true"

# signal that system monitor didn't finished running yet
globSet IS_SCAN_DONE "false"

[ "$verify_setup_status" == "true" ] && $KIRA_MANAGER/kira/kira-setup-status.sh --auto_open_km="true"
set -x

cd "$(globGet KIRA_HOME)"
VALSTATUS_SCAN_PATH="$KIRA_SCAN/valstatus"
WHITESPACE="                                                          "
CONTAINERS=""
INTERX_SNAPSHOT_PATH="$INTERX_REFERENCE_DIR/snapshot.tar"

mkdir -p "$INTERX_REFERENCE_DIR"


INFRA_CONTAINERS_COUNT=$(globGet INFRA_CONTAINERS_COUNT)

INFRA_MODE=$(globGet INFRA_MODE)
CHAIN_ID=$(jsonQuickParse "chain_id" $LOCAL_GENESIS_PATH || echo "$NETWORK_NAME")

# $LOCAL_GENESIS_PATH
# )

set +x

while : ; do
    set +e && source "/etc/profile" &>/dev/null && set -e
    PORTS_EXPOSURE=$(globGet PORTS_EXPOSURE)
    SCAN_DONE=$(globGet IS_SCAN_DONE)
    SNAP_EXPOSE=$(globGet SNAP_EXPOSE)
    VALIDATOR_ADDR=$(globGet VALIDATOR_ADDR)
    GENESIS_SHA256=$(globGet GENESIS_SHA256)
    UPGRADE_TIME=$(globGet "UPGRADE_TIME")
    PLAN_DONE=$(globGet PLAN_DONE)
    UPGRADE_DONE=$(globGet UPGRADE_DONE)
    PLAN_FAIL=$(globGet PLAN_FAIL)
    UPDATE_FAIL=$(globGet UPDATE_FAIL)
    SNAPSHOT_TARGET=$(globGet SNAPSHOT_TARGET)
    SNAPSHOT_EXECUTE=$(globGet SNAPSHOT_EXECUTE)
    CONTAINERS_COUNT=$(globGet CONTAINERS_COUNT)
    (! $(isNaturalNumber "$UPGRADE_TIME")) && UPGRADE_TIME=0
    
    VALSTATUS=$(jsonQuickParse "status" $VALSTATUS_SCAN_PATH 2>/dev/null || echo -n "")
    ($(isNullOrEmpty "$VALSTATUS")) && VALSTATUS=""

    START_TIME="$(date -u +%s)"
    
    CONS_STOPPED=$(globGet CONS_STOPPED)
    CONS_BLOCK_TIME=$(globGet CONS_BLOCK_TIME)
    AUTO_UPGRADES=$(globGet AUTO_UPGRADES)
    CONTAINERS=$(globGet CONTAINERS)
    CATCHING_UP=$(globGet CATCHING_UP)

    if [ "${SCAN_DONE,,}" == "true" ]; then
        SUCCESS="true"
        ALL_CONTAINERS_PAUSED="true"
        ALL_CONTAINERS_STOPPED="true"
        ALL_CONTAINERS_HEALTHY="true"
        VALIDATOR_RUNNING="false"

        for name in $CONTAINERS; do
            EXISTS_TMP=$(globGet "${name}_EXISTS")
            [ "${EXISTS_TMP,,}" != "true" ] && continue

            STATUS_TMP=$(globGet "${name}_STATUS")
            HEALTH_TMP=$(globGet "${name}_HEALTH")
            [ "${STATUS_TMP,,}" != "running" ] && SUCCESS="false"
            [ "${STATUS_TMP,,}" != "exited" ] && ALL_CONTAINERS_STOPPED="false"
            [ "${STATUS_TMP,,}" != "paused" ] && ALL_CONTAINERS_PAUSED="false"
            [ "${HEALTH_TMP,,}" != "healthy" ] && ALL_CONTAINERS_HEALTHY="false"
            [ "${name,,}" == "validator" ] && [ "${STATUS_TMP,,}" == "running" ] && VALIDATOR_RUNNING="true"
            [ "${name,,}" == "validator" ] && [ "${STATUS_TMP,,}" != "running" ] && VALIDATOR_RUNNING="false"
        done
    fi

    ##########################################################
    # SYSTEM UTILIZATION STATYSTICS
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
    # BLOCKCHAIN STATYSTICS
    ##########################################################

    VAL_ACT=$(globGet VAL_ACTIVE)       && (! $(isNaturalNumber $VAL_ACT)) && VAL_ACT="???" && colACT="bla" || colACT="whi"
    VAL_TOT=$(globGet VAL_TOTAL)        && (! $(isNaturalNumber $VAL_TOT)) && VAL_TOT="???" && colVTO="bla" || colVTO="whi"
    VAL_WAI=$(globGet VAL_WAITING)      && (! $(isNaturalNumber $VAL_WAI)) && VAL_WAI="???" && colVWI="bla" || colVWI="whi"
    BLO_NUM=$(globGet LATEST_BLOCK_HEIGHT "$GLOBAL_COMMON_RO") && (! $(isNaturalNumber $BLO_NUM)) && BLO_NUM="???" && colBNR="bla" || colBNR="whi"
    BLO_TIM=$(globGet CONS_BLOCK_TIME)  && (! $(isNumber $BLO_TIM)) && BLO_TIM="???" && colBTM="bla" || colBTM="whi"
    CHA_NAM="$CHAIN_ID"                 && [ -z "$CHA_NAM" ]  && CHA_NAM="???" && colCNA="bla" || colCNA="whi"

    ($(isNumber "$BLO_TIM")) && BLO_TIM=$(echo "scale=3; ( $BLO_TIM / 1 ) " | bc) && BLO_TIM="~${BLO_TIM}s"

    VAL_ACT=$(strFixC "$VAL_ACT" 12)
    VAL_TOT=$(strFixC "$VAL_TOT" 12)
    VAL_WAI=$(strFixC "$VAL_WAI" 12)
    BLO_NUM=$(strFixC "$BLO_NUM" 12)
    BLO_TIM=$(strFixC "$BLO_TIM" 12)
    CHA_NAM=$(strFixC "$CHA_NAM" 13)

    ##########################################################
    # NETWORK & SUBNET INFO
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
    # SNAPSHOT & GENESIS INFO
    ##########################################################

    KIRA_SNAP_PATH="$(globGet KIRA_SNAP_PATH)"
    SNA_PTH="$KIRA_SNAP_PATH"             && ($(isFileEmpty $SNA_PTH)) && SNA_PTH="???" && colSPH="bla" || colSPH="whi"
    SNA_SHA="$(globGet KIRA_SNAP_SHA256)" && (! $(isSHA256 $SNA_SHA)) && SNA_SHA="???...???" && colSNS="bla" || colSNS="whi"
    GEN_SHA="$(globGet GENESIS_SHA256)"   && (! $(isSHA256 $GEN_SHA)) && GEN_SHA="???...???" && colGSH="bla" || colGSH="whi"

    (! $(isFileEmpty $SNA_PTH)) && SNA_PTH=$(basename -- "$SNA_PTH")

    SNA_PTH=$(strFixC " $SNA_PTH " 25)
    SNA_SHA=$(strFixC " $SNA_SHA " 25)
    GEN_SHA=$(strFixC " $GEN_SHA " 26)


    set +x && printf "\033c" && clear
    echoC ";whi" " =============================================================================="
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "KIRA $(toUpper $INFRA_MODE) NODE MANAGER $KIRA_SETUP_VER" 78)")|"
    echoC ";whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
    echoC ";whi" "|  CPU USAGE | RAM MEMORY | DISK SPACE |  UP.SPEED  |  DN.SPEED  |  INTERFACE  |"
    echoC ";whi" "|$(echoC "res;$colCPU" "$CPU_UTIL")|$(echoC "res;$colRAM" "$RAM_UTIL")|$(echoC "res;$colDIS" "$DISK_UTIL")|$(echoC "res;$colNIN" "$NET_IN")|$(echoC "res;$colNUT" "$NET_OUT")|$(echoC "res;$colIFA" "$NET_IFACE")|"
    echoC ";whi" "| VAL.ACTIVE | V.INACTIVE | V.WAITING  |   BLOCKS   | BLOCK TIME |   NETWORK   |"
    echoC ";whi" "|$(echoC "res;$colACT" "$VAL_ACT")|$(echoC "res;$colVTO" "$VAL_TOT")|$(echoC "res;$colVWI" "$VAL_WAI")|$(echoC "res;$colBNR" "$BLO_NUM")|$(echoC "res;$colBTM" "$BLO_TIM")|$(echoC "res;$colCNA" "$CHA_NAM")|"
    echoC ";whi" "|$(strFixC " PUBLIC IP " 25 "" "-")|$(strFixC " LOCAL IP " 25 "" "-")|$(strFixC " SUBNET ($DCK_NET) " 26 "" "-")|"
    echoC ";whi" "|$(echoC "res;$colPIP" "$PUB_IPA")|$(echoC "res;$colLIP" "$LOC_IPA")|$(echoC "res;$colDNT" "$DCK_SUB")|"
    echoC ";whi" "|      SNAPSHOT NAME      |    SNAPSHOT CHECKSUM    |     GENESIS CHECKSUM     |"
    echoC ";whi" "|$(echoC "res;$colSPH" "$SNA_PTH")|$(echoC "res;$colSNS" "$SNA_SHA")|$(echoC "res;$colGSH" "$GEN_SHA")|"
    sleep 30
    continue

    printf "\033c"

    ALLOWED_OPTIONS="x"
    echo -e "\e[33;1m-------------------------------------------------"
    BANER="         KIRA NETWORK MANAGER ${KIRA_SETUP_VER}${WHITESPACE}"
    echo "|${BANER:0:47}: $(globGet INFRA_MODE) mode"
    echo "|------------ $(date '+%d/%m/%Y %H:%M:%S') --------------|"

    if [ "${PLAN_DONE,,}" != "true" ] || [ "${UPGRADE_DONE,,}" != "true" ] || [ "${PLAN_FAIL,,}" == "true" ] || [ "${UPDATE_FAIL,,}" == "true" ] ; then # plan in action
        LATEST_BLOCK_TIME=$(globGet LATEST_BLOCK_TIME $GLOBAL_COMMON_RO) 
        (! $(isNaturalNumber "$LATEST_BLOCK_TIME")) && LATEST_BLOCK_TIME=0
        UPGRADE_TIME_LEFT=$(($UPGRADE_TIME - $LATEST_BLOCK_TIME))
        UPGRADE_INSTATE=$(globGet UPGRADE_INSTATE)
        [ "${UPGRADE_INSTATE,,}" == "true" ] && UPGRADE_INSTATE="SOFT" || UPGRADE_INSTATE="HARD"
        TMP_UPGRADE_MSG="NEW $UPGRADE_INSTATE FORK UPGRADE"
        if [ "${PLAN_FAIL,,}" == "true" ] || [ "${UPDATE_FAIL,,}" == "true" ] ; then
            TMP_UPGRADE_MSG="  WARNING!!! UPGRADE FAILED, RUN MANUAL SETUP ${WHITESPACE}"
        elif [[ $UPGRADE_TIME_LEFT -gt 0 ]] ; then
            UPGRADE_TIME_LEFT=$(prettyTimeSlim $UPGRADE_TIME_LEFT)
            TMP_UPGRADE_MSG="    ${TMP_UPGRADE_MSG} IN $UPGRADE_TIME_LEFT ${WHITESPACE}"
        else
            TMP_UPGRADE_MSG="      ${TMP_UPGRADE_MSG} IS ONGOING ${WHITESPACE}"
        fi
        echo -e "|\e[31;1m ${TMP_UPGRADE_MSG:0:45} \e[33;1m|"
    fi

    if [ "${SCAN_DONE,,}" == "true" ]; then
        RAM_UTIL=$(globGet RAM_UTIL) && [ -z "$RAM_UTIL" ] && RAM_UTIL="???" ; RAM_TMP="RAM: ${RAM_UTIL}${WHITESPACE}"
        CPU_UTIL=$(globGet CPU_UTIL) && [ -z "$CPU_UTIL" ] && CPU_UTIL="???" ; CPU_TMP="CPU: ${CPU_UTIL}${WHITESPACE}"
        DISK_UTIL=$(globGet DISK_UTIL) && [ -z "$DISK_UTIL" ] && DISK_UTIL="???" ; DISK_TMP="DISK: ${DISK_UTIL}${WHITESPACE}"
        echo -e "|\e[35;1m ${CPU_TMP:0:16}${RAM_TMP:0:16}${DISK_TMP:0:13} \e[33;1m: $(globGet DISK_CONS)"

        KIRA_NETWORK=$(jsonQuickParse "network" $(globFile LATEST_STATUS) 2>/dev/null || echo -n "")
        ($(isNullOrEmpty "$KIRA_NETWORK")) && KIRA_NETWORK="???"
        if (! $(isNaturalNumber "$LATEST_BLOCK_HEIGHT")) || [ "$LATEST_BLOCK_HEIGHT" == "0" ]; then
            LATEST_BLOCK_HEIGHT="???"
        else
            ($(isNumber "$CONS_BLOCK_TIME")) && CONS_BLOCK_TIME=$(echo "scale=1; ( $CONS_BLOCK_TIME / 1 ) " | bc) && LATEST_BLOCK_HEIGHT="$LATEST_BLOCK_HEIGHT ~${CONS_BLOCK_TIME}s"
        fi

        KIRA_NETWORK_TMP="NETWORK: ${KIRA_NETWORK}${WHITESPACE}"
        KIRA_BLOCK_TMP="BLOCKS: ${LATEST_BLOCK_HEIGHT}${WHITESPACE}"
        [ -z "$GENESIS_SHA256" ] && GENESIS_SHA256="????????????"
        echo -e "|\e[35;1m ${KIRA_NETWORK_TMP:0:24}${KIRA_BLOCK_TMP:0:21} \e[33;1m: $(echo "$GENESIS_SHA256" | head -c 4)...$(echo "$GENESIS_SHA256" | tail -c 5)"

        VAL_ACTIVE=$(globGet VAL_ACTIVE) && VALACTIVE="V.ACTIVE: ${VAL_ACTIVE}${WHITESPACE}"
        VAL_TOTAL=$(globGet VAL_TOTAL) && VALTOTAL="V.TOTAL: ${VAL_TOTAL}${WHITESPACE}"
        VAL_WAITING=$(globGet VAL_WAITING) && VALWAITING="WAITING: ${VAL_WAITING}${WHITESPACE}"
        
        [ "${CATCHING_UP,,}" != "true" ] && [ "${CONS_STOPPED,,}" == "true" ] && echo -e "|\e[35;1m ${VALACTIVE:0:16}${VALTOTAL:0:16}${VALWAITING:0:13} \e[33;1m:\e[31;1m CONSENSUS HALTED\e[33;1m"
        [ "${CONS_STOPPED,,}" == "false" ] && echo -e "|\e[35;1m ${VALACTIVE:0:16}${VALTOTAL:0:16}${VALWAITING:0:13} \e[33;1m|"
    else
        LATEST_BLOCK_HEIGHT="???"
    fi

#    LOCAL_IP=$(globGet "LOCAL_IP") && PUBLIC_IP=$(globGet "PUBLIC_IP")
#    LOCAL_IP="L.IP: $LOCAL_IP                                               "
#    if [ "$PUBLIC_IP" == "0.0.0.0" ] || ( ! $(isDnsOrIp "$PUBLIC_IP")) ; then
#        echo -e "|\e[35;1m ${LOCAL_IP:0:24}P.IP: \e[31;1mdisconnected\e[33;1m    : $(globGet IFACE) $(globGet NET_PRIOR)"
#    else
#        PUBLIC_IP="$PUBLIC_IP                          "
#        echo -e "|\e[35;1m ${LOCAL_IP:0:24}P.IP: ${PUBLIC_IP:0:15}\e[33;1m : $(globGet IFACE) $(globGet NET_PRIOR)"
#    fi

    if [ -f "$KIRA_SNAP_PATH" ]; then # snapshot is present
        SNAP_FILENAME="SNAPSHOT: $(basename -- "$KIRA_SNAP_PATH")${WHITESPACE}"
        [ -z "$KIRA_SNAP_SHA256" ] && KIRA_SNAP_SHA256="????????????"
        [ "${SNAP_EXPOSE,,}" == "true" ] &&
            echo -e "|\e[32;1m ${SNAP_FILENAME:0:45} \e[33;1m: $(echo $KIRA_SNAP_SHA256 | head -c 4)...$(echo $KIRA_SNAP_SHA256 | tail -c 5)" ||
            echo -e "|\e[31;1m ${SNAP_FILENAME:0:45} \e[33;1m: $(echo $KIRA_SNAP_SHA256 | head -c 4)...$(echo $KIRA_SNAP_SHA256 | tail -c 5)"
    fi

    if [ "${SCAN_DONE,,}" == "true" ]; then
        if [ ! -z "$VALIDATOR_ADDR" ] && [ "${CATCHING_UP,,}" != "true" ] ; then
            if [ "${VALSTATUS,,}" == "active" ] ; then
                echo -e "|\e[0m\e[32;1m    SUCCESS, VALIDATOR AND INFRA IS HEALTHY    \e[33;1m: $VALSTATUS"
            elif [ "${VALSTATUS,,}" == "inactive" ] ; then
                echo -e "|\e[0m\e[31;1m   VALIDATOR WAS STOPPED, ACTIVATE YOUR NODE   \e[33;1m: $VALSTATUS"
            elif [ "${VALSTATUS,,}" == "jailed" ] ; then
                echo -e "|\e[0m\e[31;1m    VALIDATOR COMMITED DOUBLE-SIGNING FAULT    \e[33;1m: $VALSTATUS"
            elif [ "${VALSTATUS,,}" == "paused" ] ; then
                echo -e "|\e[0m\e[36;1m      VALIDATOR ENTERED MAINTENANCE MODE       \e[33;1m: $VALSTATUS"
            elif [ "${VALSTATUS,,}" == "waiting" ] ; then
                echo -e "|\e[0m\e[33;1m  WHITELISTED, READY TO CLAIM VALIDATOR SEAT   \e[33;1m: $VALSTATUS"
            else
                echo -e "|\e[0m\e[31;1m    VALIDATOR NODE IS NOT PRODUCING BLOCKS     \e[33;1m: $VALSTATUS"
            fi
        fi

        if [ "${CATCHING_UP,,}" == "true" ]; then
            echo -e "|\e[0m\e[33;1m     PLEASE WAIT, NODES ARE CATCHING UP        \e[33;1m|"
        elif [[ $CONTAINERS_COUNT -lt $INFRA_CONTAINERS_COUNT ]]; then
            echo -e "|\e[0m\e[31;1m ISSUES DETECTED, NOT ALL CONTAINERS LAUNCHED  \e[33;1m: ${CONTAINERS_COUNT}/${INFRA_CONTAINERS_COUNT}"
        elif [ "${ALL_CONTAINERS_HEALTHY,,}" != "true" ]; then
            echo -e "|\e[0m\e[31;1m ISSUES DETECTED, INFRASTRUCTURE IS UNHEALTHY  \e[33;1m|"
        elif [ "${SUCCESS,,}" == "true" ] && [ "${ALL_CONTAINERS_HEALTHY,,}" == "true" ]; then
            [ -z "$VALIDATOR_ADDR" ] && echo -e "|\e[0m\e[32;1m      SUCCESS, INFRASTRUCTURE IS HEALTHY       \e[33;1m|"
        else
            echo -e "|\e[0m\e[31;1m    INFRASTRUCTURE IS NOT FULLY OPERATIONAL    \e[33;1m|"
        fi
    fi

    [ "${PORTS_EXPOSURE,,}" == "enabled" ] && \
        echo -e "|\e[0m\e[31;1m   ALL PORTS ARE OPEN TO THE PUBLIC NETWORKS   \e[33;1m|"
    [ "${PORTS_EXPOSURE,,}" == "custom" ] && \
        echo -e "|\e[0m\e[32;1m      ALL PORTS USE CUSTOM CONFIGURATION       \e[33;1m|"
    [ "${PORTS_EXPOSURE,,}" == "disabled" ] && \
        echo -e "|\e[0m\e[31;1m        ACCESS TO ALL PORTS IS DISABLED        \e[33;1m|"

    if [ "${SCAN_DONE,,}" == "true" ]; then
        echo "|-----------------------------------------------| [health]"
        i=-1
        for name in $CONTAINERS; do
            i=$((i + 1))

            STATUS_TMP=$(globGet "${name}_STATUS")
            HEALTH_TMP=$(globGet "${name}_HEALTH")

            if [[ "${name,,}" =~ ^(validator|sentry|seed|interx)$ ]] && [[ "${STATUS_TMP,,}" =~ ^(running|starting)$ ]]; then
                LATEST_BLOCK=$(globGet "${name}_BLOCK") 
                TMP_CATCHING_UP=$(globGet "${name}_SYNCING")
                (! $(isNaturalNumber "$LATEST_BLOCK")) && LATEST_BLOCK=0
                [ "${TMP_CATCHING_UP,,}" == "true" ] && STATUS_TMP="syncing : $LATEST_BLOCK" || STATUS_TMP="$STATUS_TMP : $LATEST_BLOCK"
            fi

            NAME_TMP="${name}${WHITESPACE}"
            STATUS_TMP="${STATUS_TMP}${WHITESPACE}"
            LABEL="| [$i] | Manage ${NAME_TMP:0:11} : ${STATUS_TMP:0:21}"
            echo "${LABEL:0:47} : $HEALTH_TMP" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}${i}"
        done
    else
        echo -e "|\e[0m\e[31;1m PLEASE WAIT, LOADING INFRASTRUCTURE STATUS... \e[33;1m|"
    fi

    echo "|-----------------------------------------------|"
    if [[ $CONTAINERS_COUNT -gt 0 ]] && [ "${SCAN_DONE,,}" == "true" ]; then
        [ "${ALL_CONTAINERS_PAUSED,,}" == "false" ] &&
            echo "| [P] | PAUSE All Containers                    |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p" ||
            echo "| [P] | Un-PAUSE All Containers                 |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p"
        [ "${ALL_CONTAINERS_STOPPED,,}" == "false" ] &&
            echo "| [R] | RESTART All Containers                  |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}r"
        [ "${ALL_CONTAINERS_STOPPED,,}" == "false" ] &&
            echo "| [S] | STOP All Containers                     |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s" ||
            echo "| [S] | START All Containers                    |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s"
        echo "|-----------------------------------------------|"
    fi

    [ "${SNAPSHOT_EXECUTE,,}" == "false" ] && echo "| [B] | BACKUP Chain State                      |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}b"

    if [ ! -z "$KIRA_SNAP_PATH" ] && [ -f "$KIRA_SNAP_PATH" ]; then
        [ "${SNAP_EXPOSE,,}" == "false" ] &&
            echo "| [E] | EXPOSE Snapshot                         |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}e" ||
            echo "| [E] | Hide EXPOSED Snapshot                   |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}e"
    fi

    [ "${AUTO_UPGRADES,,}" != "true" ] &&
            echo "| [U] | Enable Automated UPGRADES               |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}u" ||
            echo "| [U] | Disable Automated UPGRADES              |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}u"

    if [ "${VALIDATOR_RUNNING,,}" == "true" ] && [ "${CATCHING_UP,,}" != "true" ] ; then
        [ "${VALSTATUS,,}" == "active" ]   && echo "| [M] | Enable MAINTENANCE Mode                 |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}m"
        [ "${VALSTATUS,,}" == "paused" ]   && echo "| [M] | Disable MAINTENANCE Mode                |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}m"
        [ "${VALSTATUS,,}" == "inactive" ] && echo "| [A] | Re-ACTIVATE Inactive Validator          |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}a"
    fi

    [ "${VALSTATUS,,}" == "waiting" ] && [ "${CATCHING_UP,,}" != "true" ] && \
    echo "| [J] | JOIN Validator Set                      |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}j"
    echo "| [D] | DUMP All Loggs                          |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}d"
    echo "| [N] | Manage NETWORKING & Firewall            |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}n"
    echo "| [I] | Re-INITALIZE Infrastructure             |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}i"
    echo -e "| [X] | Exit __________________________________ |\e[0m"

    OPTION="" && read -s -n 1 -t 20 OPTION || OPTION=""
    [ -z "$OPTION" ] && continue
    [[ "${ALLOWED_OPTIONS,,}" != *"$OPTION"* ]] && continue

    if ! [[ "${OPTION,,}" =~ ^(x|n)$ ]] && [[ $OPTION != ?(-)+([0-9]) ]]; then
        ACCEPT="" && while ! [[ "${ACCEPT,,}" =~ ^(y|n)$ ]]; do echoNErr "Press [Y]es to confirm option (${OPTION^^}) or [N]o to cancel: " && read -d'' -s -n1 ACCEPT && echo ""; done
        [ "${ACCEPT,,}" == "n" ] && echo -e "\nWARINIG: Operation was cancelled\n" && sleep 1 && continue
        echo -n ""
    fi

    if [ "${OPTION,,}" == "r" ]; then
        echoInfo "INFO: Restarting docker..."
        $KIRA_COMMON/docker-restart.sh
    fi

    FORCE_SCAN="false"
    EXECUTED="false"
    i=-1
    for name in $CONTAINERS; do
        i=$((i + 1))
        if [ "$OPTION" == "$i" ]; then
            source $KIRA_MANAGER/kira/container-manager.sh $name
            OPTION="" && EXECUTED="true" && break
        elif [ "${OPTION,,}" == "r" ]; then
            echoInfo "INFO: Re-starting $name container..."
            $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "restart"
            EXECUTED="true" && FORCE_SCAN="true"
        elif [ "${OPTION,,}" == "s" ]; then
            if [ "${ALL_CONTAINERS_STOPPED,,}" == "false" ]; then
                echoInfo "INFO: Stopping $name container..."
                $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "stop"
            else
                echoInfo "INFO: Staring $name container..."
                $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "start"
            fi
            FORCE_SCAN="true" && EXECUTED="true"
        elif [ "${OPTION,,}" == "p" ]; then
            if [ "${ALL_CONTAINERS_PAUSED,,}" == "false" ]; then
                echoInfo "INFO: Pausing $name container..."
                $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "pause"
            else
                echoInfo "INFO: UnPausing $name container..."
                $KIRA_MANAGER/kira/container-pkill.sh "$name" "true" "unpause"
            fi
            FORCE_SCAN="true" && EXECUTED="true"
        fi
    done

    if [ "${OPTION,,}" == "d" ]; then
        $KIRA_MANAGER/kira/kira-dump.sh || echoErr "ERROR: Failed logs dump"
        EXECUTED="true"
    elif [ "${OPTION,,}" == "s" ] && [ "${ALL_CONTAINERS_STOPPED,,}" != "false" ]; then
        echoInfo "INFO: Reinitalizing firewall..."
        $KIRA_MANAGER/networking.sh
    elif [ "${OPTION,,}" == "u" ] ; then
        if [ "${AUTO_UPGRADES,,}" != "true" ] ; then
            globSet AUTO_UPGRADES "true"
            echoInfo "INFO: Enabled automated upgrades"
        else
            globSet AUTO_UPGRADES "false"
            echoInfo "INFO: Disabled automated upgrades"
        fi
    elif [ "${OPTION,,}" == "b" ]; then
        echoInfo "INFO: Backing up blockchain state..."
        $KIRA_MANAGER/kira/kira-backup.sh || echoErr "ERROR: Snapshot failed"
        FORCE_SCAN="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "n" ]; then
        echoInfo "INFO: Staring networking manager..."
        $KIRA_MANAGER/kira/kira-networking.sh || echoErr "ERROR: Network manager failed"
        EXECUTED="true" && OPTION=""
    elif [ "${OPTION,,}" == "e" ]; then
        if [ "${SNAP_EXPOSE,,}" == "false" ]; then
            echoInfo "INFO: Exposing latest snapshot '$KIRA_SNAP_PATH' via INTERX"
            globSet SNAP_EXPOSE "true"
            ln -fv "$KIRA_SNAP_PATH" "$INTERX_SNAPSHOT_PATH" && \
                echoInfo "INFO: Await few minutes and your snapshot will become available via 0.0.0.0:$(globGet CUSTOM_INTERX_PORT)/download/snapshot.tar" || \
                echoErr "ERROR: Failed to create snapshot symlink"
        else
            echoInfo "INFO: Ensuring exposed snapshot will be removed..."
            globSet SNAP_EXPOSE "false"
            rm -fv "$INTERX_SNAPSHOT_PATH" && \
                echoInfo "INFO: Await few minutes and your snapshot will become unavailable" || \
                echoErr "ERROR: Failed to remove snapshot symlink"
        fi
        FORCE_SCAN="false" && EXECUTED="true"
    elif [ "${OPTION,,}" == "m" ]; then
        if [ "${VALSTATUS,,}" == "active" ]; then
            echoInfo "INFO: Attempting to change validator status from ACTIVE to PAUSED..."
            ( docker exec -i validator /bin/bash -c ". /etc/profile && pauseValidator validator" || \
            echoErr "ERROR: Failed to confirm pause tx" ) && echoWarn "WARNINIG: Please be patient, it might take couple of minutes before your status changes in the KIRA Manager..."
            sleep 5
        elif [ "${VALSTATUS,,}" == "paused" ] ; then
            echoInfo "INFO: Attempting to change validator status from PAUSED to ACTIVE..."
            ( docker exec -i validator /bin/bash -c ". /etc/profile && unpauseValidator validator" || \
            echoErr "ERROR: Failed to confirm pause tx" ) && echoWarn "WARNINIG: Please be patient, it might take couple of minutes before your status changes in the KIRA Manager..."
            sleep 5
        else
            echoWarn "WARNINIG: Unknown validator status '$VALSTATUS'"
        fi
        FORCE_SCAN="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "j" ]; then
        echoInfo "INFO: Attempting to claim validator seat..."
        read -p "INPUT UNIQUE MONIKER (your node new nickname): " MONIKER
        SUCCESS=false 
        docker exec -i validator /bin/bash -c ". /etc/profile && claimValidatorSeat validator \"$MONIKER\"" && SUCCESS=true || \
            echoErr "ERROR: Failed to confirm claim validator tx"

        if [ "${SUCCESS,,}" == "true" ] ; then
            echoInfo "INFO: Loading secrets..."
            set +e
            set +x
            source $KIRAMGR_SCRIPTS/load-secrets.sh
            set -e

            ( docker exec -i validator bash -c "source /etc/profile && upsertIdentityRecord validator \"validator_node_id\" \"$VALIDATOR_NODE_ID\" 180" || \
            echoErr "ERROR: Failed to confirm indentity registrar upsert tx" )

            echoWarn "WARNINIG: Please be patient, it might take couple of minutes before your status changes in the KIRA Manager..."
        else
            echoErr "ERROR: Failed to join validator set, see error message!"
        fi
        sleep 5
        FORCE_SCAN="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "a" ]; then
        if [ "${VALSTATUS,,}" == "inactive" ] ; then
            echoInfo "INFO: Attempting to change validator status from INACTIVE to ACTIVE..."
            ( docker exec -i validator /bin/bash -c ". /etc/profile && activateValidator validator" || \
            echoErr "ERROR: Failed to confirm activate tx" ) && echoWarn "WARNINIG: Please be patient, it might take couple of minutes before your status changes in the KIRA Manager..."
            sleep 60
        else
            echoWarn "WARNINIG: Unknown validator status '$VALSTATUS'"
        fi
        FORCE_SCAN="true" && EXECUTED="true"
    elif [ "${OPTION,,}" == "x" ]; then
        printf "\033c"
        echoInfo "INFO: Stopping kira network scanner..."
        rm -fv /dev/null && mknod -m 666 /dev/null c 1 3 || :
        exit 0
    fi

    # trigger re-scan if requested
    [ "${FORCE_SCAN,,}" == "true" ] && globSet IS_SCAN_DONE "false"
    [ "${EXECUTED,,}" == "true" ] && [ ! -z $OPTION ] && echoNErr "INFO: Option ($OPTION) was executed, press any key to continue..." && pressToContinue

    if [ "${OPTION,,}" == "i" ]; then
        cd "$(globGet KIRA_HOME)"
        systemctl stop kirascan || echoErr "ERROR: Failed to stop kirascan service"
        source $KIRA_MANAGER/kira/kira-reinitalize.sh
        source $KIRA_MANAGER/kira/kira.sh
        exit 0
    fi
done
