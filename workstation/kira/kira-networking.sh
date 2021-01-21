#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira-networking.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

CONTAINER_NAME=$1
WHITESPACE="                                                     "

# ports have 3 diffrent configuration states, public, disabled & custom
[ -z "$PORTS_EXPOSURE" ] && PORTS_EXPOSURE="enabled"

PORTS=( "$KIRA_FRONTEND_PORT" "$KIRA_SENTRY_GRPC_PORT" "$KIRA_INTERX_PORT" "$KIRA_SENTRY_P2P_PORT" "$KIRA_SENTRY_RPC_PORT" "$KIRA_PRIV_SENTRY_P2P_PORT" )

while : ; do
    clear
    ALLOWED_OPTIONS="x"
echo -e "\e[37;1m--------------------------------------------------"
           echo "|         KIRA NETWORKING MANAGER v0.0.1         |"
           [ "${PORTS_EXPOSURE,,}" == "enabled" ] && \
           echo -e "|\e[0m\e[33;1m   ALL PORTS ARE OPEN TO THE PUBLIC NETWORKS    \e[37;1m|"
           [ "${PORTS_EXPOSURE,,}" == "custom" ] && \
           echo -e "|\e[0m\e[32;1m      ALL PORTS USE CUSTOM CONFIGURATION        \e[37;1m|"
           [ "${PORTS_EXPOSURE,,}" == "disabled" ] && \
           echo -e "|\e[0m\e[31;1m        ACCESS TO ALL PORTS IS DISABLED         \e[37;1m|"
           echo "|--------- $(date '+%d/%m/%Y %H:%M:%S') ---------| [status]"
    i=-1
    LAST_SNAP=""
    for p in $PORTS ; do
        i=$((i + 1))
        NAME=""
        [ "$p" == "$KIRA_SENTRY_GRPC_PORT" ] && NAME="Public Sentry" && TYPE="GRPC"
        [ "$p" == "$KIRA_SENTRY_RPC_PORT" ] && NAME="Public Sentry" && TYPE="RPC"
        [ "$p" == "$KIRA_SENTRY_P2P_PORT" ] && NAME="Public Sentry" && TYPE="P2P"
        [ "$p" == "$KIRA_PRIV_SENTRY_P2P_PORT" ] && NAME="Private Sentry" && TYPE="P2P"
        [ "$p" == "$KIRA_INTERX_PORT" ] && NAME="INTERX Service" && TYPE="API"
        [ "$p" == "$KIRA_FRONTEND_PORT" ] && NAME="KIRA Frontend" && TYPE="HTTP"
        PORT_EXPOSURE="PORT_EXPOSURE_$PORT" && PORT_EXPOSURE=": ${!PORT_EXPOSURE}"
        [ -z "$PORT_EXPOSURE" ] && PORT_EXPOSURE="| enabled"
        [ "${PORTS_EXPOSURE,,}" != "custom" ] && PORT_EXPOSURE="|" # do no show port exposure if not in custom state
        P_TMP="${p}${WHITESPACE}"
        NAME_TMP="${NAME}${WHITESPACE}"
        TYPE_TMP="${TYPE}${WHITESPACE}"
        echo "| [$i] | ${TYPE_TMP:0:4} PORT ${P_TMP:0:5} - ${NAME_TMP:0:10} $PORT_EXPOSURE" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}${i}"
    done
       echo "|------------------------------------------------|"
       echo "| [S] | Edit SEED Nodes List                     |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}a"
       echo "| [P] | Edit Persistent PEERS List               |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}b"
       [ "${PORTS_EXPOSURE,,}" != "enabled" ] && \
       echo "| [E] | Force ENABLE All Ports                   |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}e"
       [ "${PORTS_EXPOSURE,,}" != "disabled" ] && \
       echo "| [D] | Force DISABLE All Ports                  |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}d"
       [ "${PORTS_EXPOSURE,,}" != "custom" ] && \
       echo "| [C] | Allow CUSTOM Configurationo of All Ports |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}c"
    echo -e "| [X] | Exit ___________________________________ |\e[0m"

    OPTION="" && read -s -n 1 -t 5 OPTION || OPTION=""
    [ -z "$OPTION" ] && continue
    [[ "${ALLOWED_OPTIONS,,}" != *"$OPTION"* ]] && continue

    if [ "${OPTION,,}" != "x" ] && [[ $OPTION != ?(-)+([0-9]) ]] ; then
        ACCEPT="" && while [ "${ACCEPT,,}" != "y" ] && [ "${ACCEPT,,}" != "n" ]; do echo -en "\e[33;1mPress [Y]es to confirm option (${OPTION^^}) or [N]o to cancel: \e[0m\c" && read -d'' -s -n1 ACCEPT && echo ""; done
        [ "${ACCEPT,,}" == "n" ] && echo -e "\nWARINIG: Operation was cancelled\n" && sleep 1 && continue
        echo ""
    fi

    i=-1
    for p in $PORTS; do
        i=$((i + 1))
        if [ "$OPTION" == "$i" ]; then
            echo "INFO: Starting port manager ($p)..."
            $KIRA_MANAGER/kira/port-manager.sh "$p"
        fi
    done
    
    if [ "${OPTION,,}" == "d" ]; then
        echo "INFO: Disabling all ports..."
        PORTS_EXPOSURE="disabled"
        CDHelper text lineswap --insert="PORTS_EXPOSURE=$PORTS_EXPOSURE" --prefix="PORTS_EXPOSURE=" --path=$ETC_PROFILE --append-if-found-not=True
    elif [ "${OPTION,,}" == "e" ]; then
        echo "INFO: Enabling all ports..."
        PORTS_EXPOSURE="enabled"
        CDHelper text lineswap --insert="PORTS_EXPOSURE=$PORTS_EXPOSURE" --prefix="PORTS_EXPOSURE=" --path=$ETC_PROFILE --append-if-found-not=True
    elif [ "${OPTION,,}" == "c" ]; then
        echo "INFO: Enabling custom ports configuration..."
        PORTS_EXPOSURE="custom"
        CDHelper text lineswap --insert="PORTS_EXPOSURE=$PORTS_EXPOSURE" --prefix="PORTS_EXPOSURE=" --path=$ETC_PROFILE --append-if-found-not=True
    elif [ "${OPTION,,}" == "x" ]; then
        echo "INFO: Stopping kira networking manager..."
        break
    fi
done

