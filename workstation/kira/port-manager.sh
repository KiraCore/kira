#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/port-manager.sh" && rm $FILE && nano $FILE && chmod 555 $FILE
# $KIRA_MANAGER/kira/port-manager.sh --port=36657
function cleanup() {
    echoNInfo "\n\nINFO: Exiting script...\n"
    setterm -cursor on
    exit 130
}

getArgs "$1" --gargs_throw=false --gargs_verbose="true"

FIREWALL_ZONE=$(globGet INFRA_MODE)
PORT_CFG_DIR="$KIRA_CONFIGS/ports/$port"
WHITELIST="$PORT_CFG_DIR/whitelist"
BLACKLIST="$PORT_CFG_DIR/blacklist"
mkdir -p "$PORT_CFG_DIR"
touch "$WHITELIST" "$BLACKLIST"

while : ; do

    ##########################################################
    echoInfo "FORMATTING DATA FIELDS..."
    ##########################################################

    PORT_EXPOSURE=$(toLower "$(globGet "PORT_EXPOSURE_${port}")")
    [ -z "$PORT_EXPOSURE" ] && PORT_EXPOSURE="enabled"

    case "$port" in
        "$(globGet CUSTOM_INTERX_PORT)") TYPE="API" ;;
        "$(globGet CUSTOM_P2P_PORT)") TYPE="P2P" ;;
        "$(globGet CUSTOM_RPC_PORT)") TYPE="RPC" ;;
        "$(globGet CUSTOM_GRPC_PORT)") TYPE="GRPC" ;;
        "$(globGet CUSTOM_PROMETHEUS_PORT)") TYPE="HTTP" ;;
        *) echoErr "ERROR: Port $port is NOT supported!" && exit 1 ;;
    esac

    selA="a"
    selB="b"
    selC="c"
    OPTION_ENAB=" [A] Enable Port Access"
    OPTION_BLAC=" [B] Enable IP Blacklist"
    OPTION_WHIT=" [C] Enable IP Whitelist"
    OPTION_DISB=" [D] Disable Port Access"

    case "$PORT_EXPOSURE" in
        "enabled") NOTIFY_INFO="PORT IS CONFIGURED AS PUBLICLY OPEN" && \
            OPTION_A="$OPTION_DISB" && OPTION_B="$OPTION_BLAC" && OPTION_C="$OPTION_WHIT" && \
            selA="d" && selB="b" && selC="c" && \
            colNot="yel" ;;
        "whitelist") NOTIFY_INFO="PORT USES IP ADDRESS WHITELIST" \
            OPTION_A="$OPTION_ENAB" && OPTION_B="$OPTION_BLAC" && OPTION_C="$OPTION_DISB" && \
            selA="a" && selB="b" && selC="d" && \
            colNot="cya" ;;
        "blacklist") NOTIFY_INFO="PORT USES IP ADDRESS BLACKLIST" && \
            OPTION_A="$OPTION_ENAB" && OPTION_B="$OPTION_WHIT" && OPTION_C="$OPTION_DISB" && \
            selA="a" && selB="c" && selC="d" && \
            colNot="blu" ;;
        "disabled") NOTIFY_INFO="PORT ACCESS IS DISABLED" && \
            OPTION_A="$OPTION_ENAB" && OPTION_B="$OPTION_BLAC" && OPTION_C="$OPTION_WHIT" && \
            selA="a" && selB="b" && selC="c" && \
            colNot="red";;
        *) NOTIFY_INFO="" && \
            OPTION_A="" && OPTION_B="" && OPTION_C="" && \
            selA="" && selB="" && selC="" && \
            colNot="bla" ;;
    esac
    
    OPTION_A=$(strFixL "$OPTION_A" 25)
    OPTION_B=$(strFixL "$OPTION_B" 25)
    OPTION_C=$(strFixL "$OPTION_C" 26)

    selE="e"
    selF="f"
    selX="x"
    OPTION_EBLA=$(strFixL " [E] Edit IP Whitelist" 25)
    OPTION_EWHI=$(strFixL " [F] Edit IP Blacklist" 25)
    OPTION_EXIT=$(strFixL " [X] Exit" 26)

    ###############################################################

    set +x && printf "\033c" && clear
    echoC ";whi" " =============================================================================="
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "KIRA $port $TYPE PORT CONFIGURATION MANAGER $KIRA_SETUP_VER" 78)")|"
 [ ! -z "$NOTIFY_INFO" ] && \
    echoC ";whi" "|$(echoC "res;$colNot" "$(strFixC " $NOTIFY_INFO " 78 "." " ")")|"
    echoC ";whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
    echoC ";whi" "|$OPTION_A|$OPTION_B|$OPTION_C|"
    echoC ";whi" "|$OPTION_EBLA|$OPTION_EWHI|$OPTION_EXIT|"
    echoNC ";whi" " ------------------------------------------------------------------------------"
    setterm -cursor off

    timeout=300
    pressToContinue --timeout=$timeout \
     "$selA" "$selB" "$selC" "$selD" "$selE" "$selF" "$selX" && VSEL=$(toLower "$(globGet OPTION)") || VSEL=""
    setterm -cursor on
    trap cleanup SIGINT

    #############################################################

    REINITALIZE="false"
    if [ "$VSEL" == "a" ] ; then
        echoInfo "INFO: Enabling public access to the port $port..."
        globSet "PORT_EXPOSURE_${port}" "enabled"
        EINITALIZE="true"
    elif [ "$VSEL" == "b" ] ; then
        echoInfo "INFO: Enabling access blacklist to the port $port..."
        globSet "PORT_EXPOSURE_${port}" "blacklist"
        EINITALIZE="true"
    elif [ "$VSEL" == "c" ] ; then
        echoInfo "INFO: Enabling whitelist access to the port $port..."
        globSet "PORT_EXPOSURE_${port}" "whitelist"
        EINITALIZE="true"
    elif [ "$VSEL" == "d" ] ; then
        echoInfo "INFO: Disabling access to the port $port..."
        globSet "PORT_EXPOSURE_${port}" "disabled"
        EINITALIZE="true"
    else
        echoInfo "INFO: Port exposure will NOT be changed"
    fi

    if [ "$VSEL" == "e" ] || [ "$VSEL" == "f" ] ; then
        while : ; do
            [ "$VSEL" == "e" ] && FILE=$WHITELIST && TARGET="WHITELIST"
            [ "$VSEL" == "f" ] && FILE=$BLACKLIST && TARGET="BLACKLIST"
            echoInfo "INFO: Listing all ${TARGET}ED addresses..."
            i=0
            while read p; do
                [ -z "$p" ] && continue # only display non-empty lines
                i=$((i + 1))
                echoWarn "#${i} -> $p"
            done < $FILE
            echoInfo "INFO: All $i ${TARGET}ED IP addresses were displayed"
            echoNErr "Do you want to [A]dd or [R]emove $TARGET addresses or [E]xit: " && pressToContinue a r e && SELECT=$(globGet OPTION)
            [ "${SELECT,,}" == "e" ] && break
            [ "${SELECT,,}" == "a" ] && TARGET="ADDED to the $TARGET"
            [ "${SELECT,,}" == "r" ] && TARGET="REMOVED from the $TARGET"
            echoNErr "Input comma separated list of IP addesses to $TARGET: " && read IP_LIST

            i=0
            for ip in $(echo $IP_LIST | sed "s/,/ /g") ; do
                ip=$(echo "$ip" | xargs) # trim whitespace characters
                ipArr=( $(echo $ip | tr "/" "\n") )
                ip=${ipArr[0],,}
                mask=${ipArr[1],,}
                # port must be a number
                ( [[ ! $mask =~ ^[0-9]+$ ]] || (($mask < 8 || $mask > 32)) ) && mask="" 
                if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
                    ipRange="$ip" 
                    [ ! -z "$mask" ] && ipRange="$ip/$mask"
                    echoInfo "INFO: SUCCESS, '$ipRange' is a valid IP address and will be $TARGET"
                    [ "${SELECT,,}" == "a" ] && setLastLineBySubStrOrAppend "$ip" "$ipRange" $FILE
                    [ "${SELECT,,}" == "r" ] && setLastLineBySubStrOrAppend "$ip" "" $FILE
                    i=$((i + 1))
                else
                    echoInfo "INFO: FAILURE, '$ip' is NOT a valid IP address and will NOT be $TARGET"
                    continue
                fi
            done
            echoInfo "INFO: Saving unique changes to $FILE..."
            sort -u $FILE -o $FILE
            echoInfo "INFO: Total of $i IP addresses were $TARGET"
            REINITALIZE="true"
        done
    elif [ "$VSEL" == "r" ] ; then
        REINITALIZE="true"
    elif [ "$VSEL" == "x" ] ; then
        echo "INFO: Exiting port manager..."
        break
    fi
    
    if [ "$REINITALIZE" == "true" ] ; then
        echoInfo "INFO: Current '$FIREWALL_ZONE' zone rules"
        firewall-cmd --list-ports
        firewall-cmd --get-active-zones
        firewall-cmd --zone=$FIREWALL_ZONE --list-all || echoWarn "WARNING: Failed to display current firewall rules"
        echoInfo "INFO: To apply changes to above rules you will have to restart firewall"
        echoNC "bli;whi" "\nChoose to [R]estart FIREWALL or [C]ontinue: " && pressToContinue r c && SELECT="$(toLower $(globGet OPTION))"
        [ "$SELECT" == "c" ] && continue
        echoInfo "INFO: Reinitalizing firewall..."
        $KIRA_MANAGER/networking.sh
    fi

    [ ! -z $VSEL ] && echoNC "bli;whi" "\nOption ($VSEL) was executed, press any key to continue..." && pressToContinue

done
