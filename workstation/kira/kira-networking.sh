#!/usr/bin/env bash
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/kira/kira-networking.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

# ports have 3 diffrent configuration states, public, disabled & custom
FIREWALL_ZONE=$(globGet INFRA_MODE)
PORT_CFG_DIR="$KIRA_CONFIGS/ports/$PORT"
mkdir -p "$PORT_CFG_DIR"
touch "$PUBLIC_PEERS" "$PUBLIC_SEEDS"

while : ; do
    PORTS_EXPOSURE=$(globGet PORTS_EXPOSURE)

    ##########################################################
    echoInfo "FORMATTING DATA FIELDS..."
    ##########################################################

    selS="s"
    selP="p"
    selF="f"
    colS="whi"
    colP="whi"
    colF="whi"
    OPTION_SEEDS=$(strFixL " [S] Edit Seed Nodes" 25)
    OPTION_PEERS=$(strFixL " [P] Edit Peer Nodes" 25)
    OPTION_FIREW=$(strFixL " [F] Reload Firewall" 26)

    selN="n"
    selW="w"
    selX="x"
    colN="whi"
    colW="whi"
    colX="whi"
    OPTION_NETWO=$(strFixL " [N] Reload Networking" 25)
    OPTION_WINDO=$(strFixL " [W] Refresh Window" 25)
     OPTION_EXIT=$(strFixL " [X] Exit" 26)

    selE="e"
    selC="c"
    selD="d"
    colE="whi"
    colC="whi"
    colD="whi"
    OPTION_ALLP=$(strFixL " [E] Expose All Ports" 25)
    OPTION_CUST=$(strFixL " [C] Custom Ports Expose" 25)
    OPTION_DISP=$(strFixL " [D] Disable All Ports" 26)

    case "$PORTS_EXPOSURE" in
        "enabled") NOTIFY_INFO="ALL PORTS ARE OPEN TO THE PUBLIC NETWORKS" && \
            selE="" && colE="bla" && colNot="yel" ;;
        "custom") NOTIFY_INFO="ALL PORTS USE CUSTOM CONFIGURATION" && \
            selC="" && colC="bla" && colNot="gre" ;;
        "disabled") NOTIFY_INFO="ACCESS TO ALL PORTS IS DISABLED" && \
            selD="" && colD="bla" && colNot="red" ;;
        *) NOTIFY_INFO="" && colNot="" ;;
        esac
    
    ####################################################################################

    set +x && printf "\033c" && clear
    echoC ";whi" " =============================================================================="
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "KIRA NETWORKING MANAGER $KIRA_SETUP_VER" 78)")|"
 [ ! -z "$NOTIFY_INFO" ] && \
    echoC ";whi" "|$(echoC "res;$colNot" "$(strFixC " $NOTIFY_INFO " 78 "." " ")")|"
    echoC ";whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
    echoC ";whi" "|     |    TYPE    |    PORT    |  EXPOSURE  |           DESCRIPTION           |"

    sel0=""
    sel1=""
    sel2=""
    sel3=""
    sel4=""
    sel5=""
    sel6=""
    sel7=""
    sel8=""
    sel9=""

    i=-1
    LAST_SNAP=""
    PORTS_CNT=0
    PORTS="$(globGet EXPOSED_PORTS)"
    PORTS=($PORTS) || PORTS=""
    for p in "${PORTS[@]}" ; do

        case "$p" in
            "$(globGet CUSTOM_INTERX_PORT)") DESC="INTERX Service" && TYPE="API" ;;
            "$(globGet CUSTOM_P2P_PORT)") DESC="Gossip Protocol" && TYPE="P2P" ;;
            "$(globGet CUSTOM_RPC_PORT)") DESC="REST Service" && TYPE="RPC" ;;
            "$(globGet CUSTOM_PROMETHEUS_PORT)") DESC="Prometheus Monitoring" && TYPE="HTTP" ;;
            *) DESC="" && TYPE="" ;;
        esac

        PORTS_CNT=$((PORTS_CNT + 1))
        i=$((i + 1))
        [ -z "$DESC" ] && continue

        EXPO=$(globGet "PORT_EXPOSURE_${p}")
        [ -z "$EXPO" ] && EXPO="enabled"


        case "$PORTS_EXPOSURE" in
        "enabled") colExp="gre" && EXPO="enabled" ;;
        "custom")
                case "$EXPO" in
                    "enabled") colExp="gre" ;;
                    "disabled") colExp="red" ;;
                    "blacklist") colExp="blu" ;;
                    "whitelist") colExp="cya" ;;
                    *) colExp="bla" ;;
                esac
        ;;
        "disabled") colExp="red" && EXPO="disabled" ;;
        *) NOTIFY_INFO="" && colNot="" ;;
        esac
        
        INDX=$(strFixC "[$i]" 5)
        TYPE=$(strFixC "$TYPE" 12)
        PORT=$(strFixC "$p" 12)
        EXPO=$(strFixC "$EXPO" 12)
        DESC=$(strFixC "$DESC" 33)

        selOpt="sel${i}"
        eval ${selOpt}="$i"

        echoC ";whi" "|$INDX|$TYPE|$PORT|$(echoC "res;$colExp" "$EXPO")|$DESC|"
    done

    echoC ";whi" "|$(echoC "res;bla" "$(strFixC "-" 78 "." "-")")|"
    echoC ";whi" "|$(echoC "res;$colE" "$OPTION_ALLP")|$(echoC "res;$colC" "$OPTION_CUST")|$(echoC "res;$colD" "$OPTION_DISP")|"
    echoC ";whi" "|$(echoC "res;$colS" "$OPTION_SEEDS")|$(echoC "res;$colP" "$OPTION_PEERS")|$(echoC "res;$colF" "$OPTION_FIREW")|"
    echoC ";whi" "|$(echoC "res;$colN" "$OPTION_NETWO")|$(echoC "res;$colW" "$OPTION_WINDO")|$(echoC "res;$colX" "$OPTION_EXIT")|"
    echoNC ";whi" " ------------------------------------------------------------------------------"

    pressToContinue --timeout=300 --cursor=false \
     "$sel0" "$sel1" "$sel2" "$sel3" "$sel4" "$sel5" "$sel6" "$sel7" "$sel8" "$sel9" \
     "$selS" "$selP" "$selF" "$selN" "$selW" "$selX" "$selE" "$selC" "$selD" && VSEL=$(toLower "$(globGet OPTION)") || VSEL="w"

    i=-1
    for p in "${PORTS[@]}" ; do
        i=$((i + 1))
        if [ "$VSEL" == "$i" ]; then
            echoInfo "INFO: Starting port manager ($p)..."
            $KIRA_MANAGER/kira/port-manager.sh --port=$p
            VSEL=""
        fi
    done

    if [ "$VSEL" == "d" ]; then
        echoInfo "INFO: Disabling all ports..."
        globSet PORTS_EXPOSURE "disabled"
    elif [ "$VSEL" == "e" ]; then
        echoInfo "INFO: Enabling all ports..."
        globSet PORTS_EXPOSURE "enabled"
    elif [ "$VSEL" == "c" ]; then
        echoInfo "INFO: Enabling custom ports configuration..."
        globSet PORTS_EXPOSURE "custom"
    elif [ "$VSEL" == "s" ] || [ "${VSEL}" == "p" ] ; then
        [ "$VSEL" == "s" ] && TYPE="seeds" && TARGET="Seed Nodes"
        [ "$VSEL" == "p" ] && TYPE="peers" && TARGET="Persistent Peers"

        [ "$VSEL" == "s" ] && FILE=$PUBLIC_SEEDS
        [ "$VSEL" == "p" ] && FILE=$PUBLIC_PEERS
        EXPOSURE="public"

        echoInfo "INFO: Starting $TYPE editor..."
        $KIRA_MANAGER/kira/seeds-edit.sh --destination="$FILE" --target="$EXPOSURE $TARGET"

        CONTAINER="$(globGet INFRA_MODE)"
        COMMON_PATH="$DOCKER_COMMON/$CONTAINER" && mkdir -p "$COMMON_PATH"
        echoInfo "INFO: Copying $TYPE configuration to the $CONTAINER container common directory..."
        cp -afv "$FILE" "$COMMON_PATH/$TYPE"

        echoInfo "INFO: To apply changes you MUST restart your $EXPOSURE facing $CONTAINER container"
        echoNC "bli;whi" "\nChoose to [R]estart $CONTAINER container or [C]ontinue: " && pressToContinue r c && SELECT="$(globGet OPTION)"
        [ "$SELECT" == "c" ] && continue

        echoInfo "INFO: Re-starting $CONTAINER container..."
        $KIRA_MANAGER/kira/container-pkill.sh --name="$CONTAINER" --await="true" --task="restart"
    elif [ "$VSEL" == "f" ]; then
        echoInfo "INFO: Reinitalizing firewall..."
        $KIRA_MANAGER/networking.sh
    elif [ "$VSEL" == "r" ]; then
        echoInfo "INFO: Restarting network interfaces..."
        $KIRA_MANAGER/launch/update-ifaces.sh
    elif [ "$VSEL" == "w" ]; then
        VSEL=""
    elif [ "$VSEL" == "x" ]; then
        echoInfo "INFO: Stopping kira networking manager..."
        break
    fi

    if [ "$VSEL" == "e" ] || [ "$VSEL" == "c" ] || [ "$VSEL" == "d" ] ; then
        echoInfo "INFO: Current '$FIREWALL_ZONE' zone rules"
        firewall-cmd --list-ports
        firewall-cmd --get-active-zones
        firewall-cmd --zone=$FIREWALL_ZONE --list-all || echo "INFO: Failed to display current firewall rules"
        echoInfo "INFO: To apply changes to above rules you will have to restart firewall"
        echoNC "bli;whi" "\nChoose to [R]estart FIREWALL or [C]ontinue: " && pressToContinue r c && SELECT="$(globGet OPTION)"
        [ "$SELECT" == "c" ] && continue
        echoInfo "INFO: Reinitalizing firewall..."
        $KIRA_MANAGER/networking.sh
    fi

    [ ! -z $VSEL ] && echoNC "bli;whi" "\nOption ($VSEL) was executed, press any key to continue..." && pressToContinue
done

