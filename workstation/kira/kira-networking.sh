#!/bin/bash
set +e && source "/etc/profile" &>/dev/null && set -e
source $KIRA_MANAGER/utils.sh
# quick edit: FILE="$KIRA_MANAGER/kira/kira-networking.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

# ports have 3 diffrent configuration states, public, disabled & custom
WHITESPACE="                                                     "
PORTS=($KIRA_FRONTEND_PORT $KIRA_SENTRY_GRPC_PORT $KIRA_SENTRY_P2P_PORT $KIRA_SENTRY_RPC_PORT $KIRA_PRIV_SENTRY_P2P_PORT $KIRA_INTERX_PORT)

PORT_CFG_DIR="$KIRA_CONFIGS/ports/$PORT"
mkdir -p "$PORT_CFG_DIR"
touch "$PUBLIC_PEERS" "$PRIVATE_PEERS" "$PUBLIC_SEEDS" "$PRIVATE_SEEDS"

while : ; do
    set +e && source "/etc/profile" &>/dev/null && set -e
    printf "\033c"
    ALLOWED_OPTIONS="x"
echo -e "\e[37;1m--------------------------------------------------"
           echo "|         KIRA NETWORKING MANAGER v0.0.5         |"
           [ "${PORTS_EXPOSURE,,}" == "enabled" ] && \
           echo -e "|\e[0m\e[33;1m   ALL PORTS ARE OPEN TO THE PUBLIC NETWORKS    \e[37;1m|"
           [ "${PORTS_EXPOSURE,,}" == "custom" ] && \
           echo -e "|\e[0m\e[32;1m      ALL PORTS USE CUSTOM CONFIGURATION        \e[37;1m|"
           [ "${PORTS_EXPOSURE,,}" == "disabled" ] && \
           echo -e "|\e[0m\e[31;1m        ACCESS TO ALL PORTS IS DISABLED         \e[37;1m|"
           echo "|-------------- $(date '+%d/%m/%Y %H:%M:%S') -------------| [config]"
    i=-1
    LAST_SNAP=""
    for p in "${PORTS[@]}" ; do
        i=$((i + 1))
        NAME=""
        [ "$p" == "$KIRA_SENTRY_GRPC_PORT" ] && NAME="Public Sentry" && TYPE="GRPC"
        [ "$p" == "$KIRA_SENTRY_RPC_PORT" ] && NAME="Public Sentry" && TYPE="RPC"
        [ "$p" == "$KIRA_SENTRY_P2P_PORT" ] && NAME="Public Sentry" && TYPE="P2P"
        [ "$p" == "$KIRA_PRIV_SENTRY_P2P_PORT" ] && NAME="Private Sentry" && TYPE="P2P"
        [ "$p" == "$KIRA_INTERX_PORT" ] && NAME="INTERX Service" && TYPE="API"
        [ "$p" == "$KIRA_FRONTEND_PORT" ] && NAME="KIRA Frontend" && TYPE="HTTP"
        PORT_EXPOSURE="PORT_EXPOSURE_${p}" && PORT_EXPOSURE="${!PORT_EXPOSURE}"
        [ -z "$PORT_EXPOSURE" ] && PORT_EXPOSURE="enabled"
        P_TMP="${p}${WHITESPACE}"
        NAME_TMP="${NAME}${WHITESPACE}"
        TYPE_TMP="${TYPE}${WHITESPACE}"
        echo "| [$i] | ${TYPE_TMP:0:4} PORT ${P_TMP:0:5} - ${NAME_TMP:0:22} : $PORT_EXPOSURE" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}${i}"
    done
       echo "|------------------------------------------------|"
       [ "${PORTS_EXPOSURE,,}" != "enabled" ] && \
       echo "| [E] | Force ENABLE All Ports                   |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}e"
       [ "${PORTS_EXPOSURE,,}" != "custom" ] && \
       echo "| [C] | Force CUSTOM Ports Configuration         |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}c"
       [ "${PORTS_EXPOSURE,,}" != "disabled" ] && \
       echo "| [D] | Force DISABLE All Ports                  |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}d"
       IFACE_TMP="(${IFACE})${WHITESPACE:0:10}|"
       echo "| [I] | Change Network INTERFACE $IFACE_TMP"        && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}i"
       echo "|------------------------------------------------|"
       echo "| [S] | Edit/Show SEED Nodes List                |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}s"
       echo "| [P] | Edit/Show Persistent PEERS List          |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}p"
       echo "| [F] | Reload FIREWALL Settings                 |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}f"
       echo "| [R] | RELOAD Networking                        |" && ALLOWED_OPTIONS="${ALLOWED_OPTIONS}r"
    echo -e "| [X] | Exit ___________________________________ |\e[0m"
    OPTION="" && read -s -n 1 -t 10 OPTION || OPTION=""
    [ -z "$OPTION" ] && continue
    [[ "${ALLOWED_OPTIONS,,}" != *"$OPTION"* ]] && continue

    if [ "${OPTION,,}" != "x" ] && [ "${OPTION,,}" != "p" ] && [ "${OPTION,,}" != "s" ] && [[ $OPTION != ?(-)+([0-9]) ]] ; then
        ACCEPT="." && while ! [[ "${ACCEPT,,}" =~ ^(y|n)$ ]] ; do echoNErr "Press [Y]es to confirm option (${OPTION^^}) or [N]o to cancel: " && read -d'' -s -n1 ACCEPT && echo ""; done
        [ "${ACCEPT,,}" == "n" ] && echo -e "\nWARINIG: Operation was cancelled\n" && sleep 1 && continue
        echo ""
    fi

    i=-1
    for p in "${PORTS[@]}" ; do
        i=$((i + 1))
        if [ "$OPTION" == "$i" ]; then
            echoInfo "INFO: Starting port manager ($p)..."
            $KIRA_MANAGER/kira/port-manager.sh "$p"
            OPTION=""
        fi
    done
    
    if [ "${OPTION,,}" == "d" ]; then
        echoInfo "INFO: Disabling all ports..."
        PORTS_EXPOSURE="disabled"
        CDHelper text lineswap --insert="PORTS_EXPOSURE=$PORTS_EXPOSURE" --prefix="PORTS_EXPOSURE=" --path=$ETC_PROFILE --append-if-found-not=True
    elif [ "${OPTION,,}" == "e" ]; then
        echoInfo "INFO: Enabling all ports..."
        PORTS_EXPOSURE="enabled"
        CDHelper text lineswap --insert="PORTS_EXPOSURE=$PORTS_EXPOSURE" --prefix="PORTS_EXPOSURE=" --path=$ETC_PROFILE --append-if-found-not=True
    elif [ "${OPTION,,}" == "c" ]; then
        echoInfo "INFO: Enabling custom ports configuration..."
        PORTS_EXPOSURE="custom"
        CDHelper text lineswap --insert="PORTS_EXPOSURE=$PORTS_EXPOSURE" --prefix="PORTS_EXPOSURE=" --path=$ETC_PROFILE --append-if-found-not=True
    elif [ "${OPTION,,}" == "i" ]; then
        echoInfo "INFO: Starting network interface selection menu..."
        IFACE_OLD="$IFACE"
        $KIRA_MANAGER/menu/interface-select.sh
        set +e && source "/etc/profile" &>/dev/null && set -e
        if [ "$IFACE_OLD" != "$IFACE" ] ; then
            echoInfo "INFO: Reinitalizing firewall..."
            $KIRA_MANAGER/networking.sh
        else
            echoInfo "INFO: Network interface was not changed"
        fi
    elif [ "${OPTION,,}" == "s" ] || [ "${OPTION,,}" == "p" ] ; then
        [ "${OPTION,,}" == "s" ] && TYPE="seeds" && TARGET="Seed Nodes"
        [ "${OPTION,,}" == "p" ] && TYPE="peers" && TARGET="Persistent Peers"
        SELECT="." && while ! [[ "${SELECT,,}" =~ ^(p|v)$ ]] ; do echoNErr "Choose to list [P]ublic or Pri[V]ate $TARGET: " && read -d'' -s -n1 SELECT && echo ""; done
        [ "${SELECT,,}" == "p" ] && [ "${OPTION,,}" == "s" ] && FILE=$PUBLIC_SEEDS && EXPOSURE="public" && CONTAINER="sentry"
        [ "${SELECT,,}" == "v" ] && [ "${OPTION,,}" == "s" ] && FILE=$PRIVATE_SEEDS && EXPOSURE="private" && CONTAINER="priv_sentry"
        [ "${SELECT,,}" == "p" ] && [ "${OPTION,,}" == "p" ] && FILE=$PUBLIC_PEERS && EXPOSURE="public" && CONTAINER="sentry"
        [ "${SELECT,,}" == "v" ] && [ "${OPTION,,}" == "p" ] && FILE=$PRIVATE_PEERS && EXPOSURE="private" && CONTAINER="priv_sentry"

        echoInfo "INFO: Starting $TYPE editor..."
        $KIRA_MANAGER/kira/seeds-edit.sh "$FILE" "$TARGET"

        echoInfo "INFO: Copying $TYPE configuration to the $CONTAINER container common directory..."
        cp -a -v -f "$FILE" "$DOCKER_COMMON/$CONTAINER/$TYPE"

        echoInfo "INFO: To apply changes you will have to restart your $EXPOSURE facing $CONTAINER container"
        SELECT="." && while ! [[ "${SELECT,,}" =~ ^(r|c)$ ]]  ; do echoNErr "Choose to [R]estart $CONTAINER container or [C]ontinue: " && read -d'' -s -n1 SELECT && echo ""; done
        [ "${SELECT,,}" == "c" ] && continue
        
        echoInfo "INFO: Re-starting $CONTAINER container..."
        $KIRA_SCRIPTS/container-restart.sh $CONTAINER
    elif [ "${OPTION,,}" == "f" ]; then
        echoInfo "INFO: Reinitalizing firewall..."
        $KIRA_MANAGER/networking.sh
    elif [ "${OPTION,,}" == "r" ]; then
        echoInfo "INFO: Restarting networks..."
        $KIRA_MANAGER/scripts/restart-networks.sh
    elif [ "${OPTION,,}" == "x" ]; then
        echoInfo "INFO: Stopping kira networking manager..."
        break
    fi

    if [ "${OPTION,,}" == "e" ] || [ "${OPTION,,}" == "c" ] || [ "${OPTION,,}" == "d" ] ; then
        echoInfo "INFO: Current '$FIREWALL_ZONE' zone rules"
        firewall-cmd --list-ports
        firewall-cmd --get-active-zones
        firewall-cmd --zone=$FIREWALL_ZONE --list-all || echo "INFO: Failed to display current firewall rules"
        echoInfo "INFO: To apply changes to above rules you will have to restart firewall"
        SELECT="." && while ! [[ "${SELECT,,}" =~ ^(r|c)$ ]] ; do echoNErr "Choose to [R]estart FIREWALL container or [C]ontinue: " && read -d'' -s -n1 SELECT && echo ""; done
        [ "${SELECT,,}" == "c" ] && continue
        echoInfo "INFO: Reinitalizing firewall..."
        $KIRA_MANAGER/networking.sh
    fi

    [ ! -z $OPTION ] && echoNErr "INFO: Option ($OPTION) was executed, press any key to continue..." && read -n 1 -s && echo ""
done

