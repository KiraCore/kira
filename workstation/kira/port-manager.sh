#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/port-manager.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

PORT=$1
WHITESPACE="                                        "
PORT_CFG_DIR="$KIRA_CONFIGS/ports/$PORT"
WHITELIST="$PORT_CFG_DIR/whitelist"
BLACKLIST="$PORT_CFG_DIR/blacklist"
mkdir -p "$PORT_CFG_DIR"
touch "$WHITELIST" "$BLACKLIST"

while : ; do
    clear
    set +e && source "/etc/profile" &>/dev/null && set -e
    PORT_EXPOSURE="PORT_EXPOSURE_$PORT" && PORT_EXPOSURE="${!PORT_EXPOSURE}"
    [ -z "$PORT_EXPOSURE" ] && PORT_EXPOSURE="enabled"
    [ "$PORT" == "$KIRA_SENTRY_GRPC_PORT" ] && TYPE="GRPC"
    [ "$PORT" == "$KIRA_SENTRY_RPC_PORT" ] && TYPE="RPC"
    [ "$PORT" == "$KIRA_SENTRY_P2P_PORT" ] && TYPE="P2P"
    [ "$PORT" == "$KIRA_PRIV_SENTRY_P2P_PORT" ] && TYPE="P2P"
    [ "$PORT" == "$KIRA_INTERX_PORT" ] && TYPE="API"
    [ "$PORT" == "$KIRA_FRONTEND_PORT" ] && TYPE="HTTP"
    PORT_TMP="${PORT}${WHITESPACE}"
    TYPE_TMP="${TYPE}${WHITESPACE}"
  
    ALLOWED_OPTIONS="x"
        echo -e "\e[37;1m--------------------------------------------------"
        echo "|         ${TYPE_TMP} PORT ${PORT_TMP:0:5} CONFIGURATION          |"
        echo "|--------- $(date '+%d/%m/%Y %H:%M:%S') ---------|"

        [ "${PORT_EXPOSURE,,}" == "enabled" ] && \
        echo -e "|\e[0m\e[33;1m    PORT IS PUBLICLY OPEN TO THE INTERNET    \e[37;1m|"
        [ "${PORT_EXPOSURE,,}" == "whitelist" ] && \
        echo -e "|\e[0m\e[32;1m        PORT USES IP ADDRESS WHITELIST       \e[37;1m|"
        [ "${PORT_EXPOSURE,,}" == "blacklist" ] && \
        echo -e "|\e[0m\e[32;1m        PORT USES IP ADDRESS BLACKLIST       \e[37;1m|"
        [ "${PORT_EXPOSURE,,}" == "disabled" ] && \
        echo -e "|\e[0m\e[31;1m           PORT ACCESS IS DISABLED           \e[37;1m|"

        echo "|------------------------------------------------|"
        [ "${PORT_EXPOSURE,,}" != "enabled" ] && \
        echo "| [A] | Enable Port ACCESS     ${WHITESPACE:0:18}|" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}a"
        [ "${PORT_EXPOSURE,,}" != "whitelist" ] && \
        echo "| [B] | Enable IP WHITELIST    ${WHITESPACE:0:18}|" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}b"
        [ "${PORT_EXPOSURE,,}" != "blacklist" ] && \
        echo "| [C] | Enable IP BLACKLIST    ${WHITESPACE:0:18}|" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}c"
        [ "${PORT_EXPOSURE,,}" != "enabled" ] && \
        echo "| [D] | Disable Port ACCESS    ${WHITESPACE:0:18}|" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}d"
        echo "|--------------------------------------------------|"
        echo "| [E] | Edit/Show WHITELIST         ${WHITESPACE:0:18}|" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}e"
        echo "| [F] | Edit/Show BLACKLIST         ${WHITESPACE:0:18}|" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}f"
        echo "| [R] | RELOAD Network Settings${WHITESPACE:0:18}|" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}r"
     echo -e "| [X] | Exit _____________________________________ |\e[0m"
    
    [ -z "$OPTION" ] && continue
    [[ "${ALLOWED_OPTIONS,,}" != *"$OPTION"* ]] && continue

    if [ "${OPTION,,}" != "x" ] && [[ $OPTION != ?(-)+([0-9]) ]] ; then
        ACCEPT="" && while [ "${ACCEPT,,}" != "y" ] && [ "${ACCEPT,,}" != "n" ]; do echo -en "\e[33;1mPress [Y]es to confirm option (${OPTION^^}) or [N]o to cancel: \e[0m\c" && read -d'' -s -n1 ACCEPT && echo ""; done
        [ "${ACCEPT,,}" == "n" ] && echo -e "\nWARINIG: Operation was cancelled\n" && sleep 1 && continue
        echo ""
    fi
    
    REINITALIZE="false"
    if [ "${OPTION,,}" == "a" ] ; then
        echo "INFO: Enabling public access to the port $PORT..."
        PORT_EXPOSURE="enabled"
        CDHelper text lineswap --insert="PORT_EXPOSURE_$PORT=$PORT_EXPOSURE" --prefix="PORT_EXPOSURE_$PORT=" --path=$ETC_PROFILE --append-if-found-not=True
        REINITALIZE="true"
    elif [ "${OPTION,,}" == "b" ] ; then
        echo "INFO: Enabling whitelist access to the port $PORT..."
        PORT_EXPOSURE="whitelist"
        CDHelper text lineswap --insert="PORT_EXPOSURE_$PORT=$PORT_EXPOSURE" --prefix="PORT_EXPOSURE_$PORT=" --path=$ETC_PROFILE --append-if-found-not=True
        REINITALIZE="true"
    elif [ "${OPTION,,}" == "c" ] ; then
        echo "INFO: Enaling access blacklist to the port $PORT..."
        PORT_EXPOSURE="blacklist"
        CDHelper text lineswap --insert="PORT_EXPOSURE_$PORT=$PORT_EXPOSURE" --prefix="PORT_EXPOSURE_$PORT=" --path=$ETC_PROFILE --append-if-found-not=True
        REINITALIZE="true"
    elif [ "${OPTION,,}" == "d" ] ; then
        echo "INFO: Disabling access to the port $PORT..."
        PORT_EXPOSURE="disabled"
        CDHelper text lineswap --insert="PORT_EXPOSURE_$PORT=$PORT_EXPOSURE" --prefix="PORT_EXPOSURE_$PORT=" --path=$ETC_PROFILE --append-if-found-not=True
        REINITALIZE="true"
    elif [ "${OPTION,,}" == "e" ] || [ "${OPTION,,}" == "f" ] ; then
        [ "${OPTION,,}" == "e" ] && FILE=$WHITELIST && TARGET="WHITELIST"
        [ "${OPTION,,}" == "f" ] && FILE=$BLACKLIST && TARGET="BLACKLIST"
        echo "INFO: Listing all ${TARGET}ED addresses..."
        i=0
        while read p; do
            [ -z "$p" ] && continue # only display non-empty lines
            i=$((i + 1))
            echo "${1}. $p"
        done < $FILE
        echo "INFO: All $i ${TARGET}ED IP addresses were displayed"
        SELECT="." && while [ "${SELECT,,}" != "a" ] && [ "${SELECT,,}" != "r" ] && [ "${SELECT,,}" != "s" ] ; do echo -en "\e[31;1mDo you want to [A]dd or [R]emove $TARGET addresses or [S]kip action: \e[0m\c" && read -d'' -s -n1 SELECT && echo ""; done
        echo -en "\e[31;1mInput comma separated list of IP addesses to $TARGET: \e[0m" && read IP_LIST
        [ "${SELECT,,}" == "s" ] && continue
        [ "${SELECT,,}" == "a" ] && TARGET="ADDED to the $TARGET"
        [ "${SELECT,,}" == "r" ] && TARGET="REMOVED from the $TARGET"
        i=0
        for ip in $(echo $IP_LIST | sed "s/,/ /g") ; do
            ip=$(echo "$ip" | xargs) # trim whitespace characters
            ipArr=( $(echo $ip | tr "/" "\n") )
            ip=${ipArr[0],,}
            mask_tmp=${ipArr[1],,}
            mask="" && [[ $mask_tmp =~ ^[0-9]+$ ]] && mask="$mask_tmp" # port must be a number
            [ ! -z "$mask" ] && (($mask < 8 || $mask > 32)) && mask=""
            if [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] ; then
                ipRange="$ip" && [ ! -z "$mask" ] && ipRange="$ip/$mask"
                echo "INFO: SUCCESS, '$ipRange' is a valid IP address and will be $TARGET"
                [ "${SELECT,,}" == "a" ] && CDHelper text lineswap --insert="$ipRange" --regex="$ip" --path=$FILE --append-if-found-not=True --silent=True
                [ "${SELECT,,}" == "r" ] && CDHelper text lineswap --insert="" --regex="$ip" --path=$FILE --append-if-found-not=True --silent=True
                i=$((i + 1))
            else
                echo "INFO: FAILURE, '$ip' is NOT a valid IP address and will NOT be $TARGET"
                continue
            fi
        done
        echo "INFO: Saving unique changes to $FILE..."
        grep "\S" $FILE
        sort -u $FILE | tee $FILE
        echo "INFO: Total of $i IP addresses were $TARGET"
        REINITALIZE="true"
    elif [ "${OPTION,,}" == "x" ] ; then
        echo "INFO: Exiting port manager..."
        break
    fi

    [ "${OPTION,,}" != "r" ] && [ ! -z $OPTION ] && echo -en "\e[31;1mINFO: Option ($OPTION) was executed, press any key to continue...\e[0m" && read -n 1 -s && echo ""
     
    if [ "${REINITALIZE,,}" == "true" ] ; then
        echo "INFO: Reinitalizing firewall..."
        $KIRA_MANAGER/networking.sh
        echo -en "\e[31;1mINFO:Network was reinitalized, press any key to continue...\e[0m" && read -n 1 -s && echo ""
    fi
done
