#!/usr/bin/env bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/ports-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

while : ; do
    # load latest values
    IFACE="$(globGet IFACE)"
    IFACE_DEF="$(netstat -rn | grep -m 1 UG | awk '{print $8}' | xargs)"

    echoInfo "INFO: Public & Local IP discovery..."
    PUBLIC_IP=$(timeout 60 bu getPublicIp 2> /dev/null || echo "")
    LOCAL_IP=$(timeout 60 bu getLocalIp "$IFACE" 2> /dev/null || echo "0.0.0.0")
    (! $(isDnsOrIp "$PUBLIC_IP")) && PUBLIC_IP="???.???.???.???"
    (! $(isDnsOrIp "$LOCAL_IP")) && LOCAL_IP="???.???.???.???"

    INFRA_MODE="$(globGet INFRA_MODE)"
    SSH_PORT="$(globGet DEFAULT_SSH_PORT)"
    P2P_PORT="$(globGet CUSTOM_P2P_PORT)"
    RPC_PORT="$(globGet CUSTOM_RPC_PORT)"
    GRPC_PORT="$(globGet CUSTOM_GRPC_PORT)"
    PRTH_PORT="$(globGet CUSTOM_PROMETHEUS_PORT)"
    INEX_PORT="$(globGet CUSTOM_INTERX_PORT)"

    P2P_PORT_DEF="$(globGet "DEFAULT_P2P_PORT")"
    RPC_PORT_DEF="$(globGet "DEFAULT_RPC_PORT")"
    GRPC_PORT_DEF="$(globGet "DEFAULT_GRPC_PORT")"
    PRTH_PORT_DEF="$(globGet "DEFAULT_PROMETHEUS_PORT")"
    INEX_PORT_DEF="$(globGet "DEFAULT_INTERX_PORT")"

    DOCKER_SUBNET="$(globGet KIRA_DOCKER_SUBNET)"
    DOCKER_NETWORK="$(globGet KIRA_DOCKER_NETWORK)"
    DEFAULT_DOCKER_SUBNET="$(globGet DEFAULT_DOCKER_SUBNET)"
    DEFAULT_DOCKER_NETWORK="$(globGet DEFAULT_DOCKER_NETWORK)"

    PRT_SSH_PORT=$(strFixC "$SSH_PORT" 11)   &&  PRT_SSH_PORT_DEF=$(strFixC "22" 11)
    PRT_P2P_PORT=$(strFixC "$P2P_PORT" 11)   &&  PRT_P2P_PORT_DEF=$(strFixC "$P2P_PORT_DEF" 11)
    PRT_RPC_PORT=$(strFixC "$RPC_PORT" 11)   &&  PRT_RPC_PORT_DEF=$(strFixC "$RPC_PORT_DEF" 11)
    PRT_GRPC_PORT=$(strFixC "$GRPC_PORT" 12) && PRT_GRPC_PORT_DEF=$(strFixC "$GRPC_PORT_DEF" 12)
    PRT_PRTH_PORT=$(strFixC "$PRTH_PORT" 14) && PRT_PRTH_PORT_DEF=$(strFixC "$PRTH_PORT_DEF" 14)
    PRT_INEX_PORT=$(strFixC "$INEX_PORT" 14) && PRT_INEX_PORT_DEF=$(strFixC "$INEX_PORT_DEF" 14)

    set +x && printf "\033c" && clear && setterm -cursor off
    echoC ";whi" " =============================================================================="
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "PORTS MAPPING & NETWORKING CONFIGURATOR, KM $KIRA_SETUP_VER" 78)")|"
 echoC "sto;whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
    echoC ";whi" "| SSH PORT  | P2P PORT  | RPC PORT  | GRPC PORT  |  PROMETHEUS  | INTERX (API) |"
    echoC ";whi" "|$PRT_SSH_PORT|$PRT_P2P_PORT|$PRT_RPC_PORT|$PRT_GRPC_PORT|$PRT_PRTH_PORT|$PRT_INEX_PORT|"
    echoC "sto;whi" "|$(echoC "res;bla" "$(strFixC " DEFAULT PORTS " 78 "." "-")")|"
    echoC ";whi" "|$(echoC "res;bla" "$PRT_SSH_PORT_DEF|$PRT_P2P_PORT_DEF|$PRT_RPC_PORT_DEF|$PRT_GRPC_PORT_DEF|$PRT_PRTH_PORT_DEF|$PRT_INEX_PORT_DEF")|"
 echoC "sto;whi" "|$(echoC "res;bla" "--------") LOCAL IP ADDRESS $(echoC "res;bla" "---------|-----------") PUBLIC IP ADDRESS $(echoC "res;bla" "------------")|"
 echoC "sto;whi" "|$(strFixC "$LOCAL_IP" 35)$(echoC "res;bla" "|")$(strFixC "$PUBLIC_IP" 42)|"
 echoC "sto;whi" "|$(echoC "res;bla" "------------------------------------------------------------------------------")|"
    echoC "sto;whi" "|$(strFixL " Docker Network: $DOCKER_NETWORK" 35)| $(echoC "res;bla" "$(strFixL "   default - $DEFAULT_DOCKER_NETWORK" 40)") |"
    echoC "sto;whi" "|$(strFixL "  Docker Subnet: $DOCKER_SUBNET" 35)| $(echoC "res;bla" "$(strFixL "   default - $DEFAULT_DOCKER_SUBNET" 40)") |"
    echoC "sto;whi" "|$(strFixL " Net. Interface: $IFACE" 35)| $(echoC "res;bla" "$(strFixL "   default - $IFACE_DEF" 40)") |"
    echoC "sto;whi" "|$(echoC "res;bla" "------------------------------------------------------------------------------")|"
    echoC ";whi" "| $(strFixL "[I] Change network interface" 76) |"
    echoC ";whi" "| $(strFixL "[M] Modify each port mapping & subnet individually" 76) |"
    echoC ";whi" "| $(strFixL "[X] Exit _" 77 "" "_")|"
    setterm -cursor off 
    pressToContinue i m o x && KEY="$(globGet OPTION)" 
    KEY="$(toLower "$KEY")"
    setterm -cursor on
    
    clear
    [ "$KEY" != "r" ] && echoInfo "INFO: Option '$KEY' was selected, processing request..."

    if [ "$KEY" == "x" ] ; then
        break
    elif [ "$KEY" == "r" ] ; then
        continue
    elif [ "$KEY" == "i" ] ; then
        ifaces_iterate=$(ifconfig | cut -d ' ' -f1 | tr ':' '\n' | awk NF)
        ifaces=( $ifaces_iterate )

        i=-1
        for f in $ifaces_iterate ; do
            i=$((i + 1))
            if [ "$f" == "$IFACE" ] ; then
              echoC "sto;whi" " [$i] | $f $(echoC "sto;bla" "(default)")"
            else
              echoC ";whi" " [$i] | $f"
            fi
        done

        OPTION=""
        while : ; do
            echoNC ";gre" "Input interface number 0-$i or press [ENTER] for default: " && read OPTION
            [ -z "$OPTION" ] && OPTION="" && break
            ($(isNaturalNumber "$OPTION")) && [[ $OPTION -le $i ]] && [[ $OPTION -ge 0 ]] && break
        done

        ($(isNaturalNumber "$OPTION")) && IFACE="${ifaces[$OPTION]}"
    elif [ "$KEY" == "m" ] ; then
      # NETWORK
      echoC ";whi" "Default Docker network name: $DEFAULT_DOCKER_NETWORK"
      NAME="." 
      while [[ $(strLength "$NAME") -lt 3 ]] && [ ! -z "$NAME" ]; do echoNLog "Input new name (min 3 char.) or press [ENTER] for default: " && read NAME ; done
      NAME="$(delWhitespaces $(toLower "$NAME"))"
      [ -z "$NAME" ] && NAME="$DEFAULT_DOCKER_NETWORK"
      DOCKER_NETWORK="$NAME"
      # SUBNET
      echoC ";whi" "Default Docker subnet: $DEFAULT_DOCKER_SUBNET"
      SUBNET="." 
      while (! $(isCIDR "$SUBNET")) && [ ! -z "$SUBNET" ]; do echoNLog "Input valid CIDR or press [ENTER] for default: " && read SUBNET ; done
      [ -z "$SUBNET" ] && SUBNET="$DEFAULT_DOCKER_SUBNET"
      DOCKER_SUBNET="$SUBNET"
      # NOTE: By adding 0 we cut the whitespaces ans ensure value is a valid
      echoC ";whi" "Default SSH port number: $SSH_PORT"
      PORT="." && while (! $(isPort "$PORT")) && [ ! -z "$PORT" ]; do echoNLog "Input SSH port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && SSH_PORT=$((PORT + 0)) || SSH_PORT=$((SSH_PORT + 0))
      # P2P
      echoC ";whi" "Default P2P port number: $P2P_PORT"
      PORT="." && while (! $(isPort "$PORT")) && [ ! -z "$PORT" ]; do echoNLog "Input P2P port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && P2P_PORT=$((PORT + 0)) || P2P_PORT=$((P2P_PORT + 0))
      # RPC
      echoC ";whi" "Default RPC port number: $RPC_PORT"
      PORT="." && while (! $(isPort "$PORT")) && [ ! -z "$PORT" ]; do echoNLog "Input RPC port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && RPC_PORT=$((PORT + 0)) || RPC_PORT=$((RPC_PORT + 0))
      # GRPC
      echoC ";whi" "Default GRPC port number: $GRPC_PORT"
      PORT="." && while (! $(isPort "$PORT")) && [ ! -z "$PORT" ]; do echoNLog "Input GRPC port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && GRPC_PORT=$((PORT + 0)) || GRPC_PORT=$((GRPC_PORT + 0))
      # PROMETHEUS
      echoC ";whi" "Default PROMETHEUS port number: $PRTH_PORT"
      PORT="." && while (! $(isPort "$PORT")) && [ ! -z "$PORT" ]; do echoNLog "Input PROMETHEUS port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && PRTH_PORT=$((PORT + 0)) || PRTH_PORT=$((PRTH_PORT + 0))
      # INTERX
      echoC ";whi" "Default INTERX port number: $INEX_PORT"
      PORT="." && while (! $(isPort "$PORT")) && [ ! -z "$PORT" ]; do echoNLog "Input INTERX port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && INEX_PORT=$((PORT + 0)) || INEX_PORT=$((INEX_PORT + 0))
    fi

    PRT_SSH_PORT=$(strFixC "$SSH_PORT" 11)
    PRT_P2P_PORT=$(strFixC "$P2P_PORT" 11)  
    PRT_RPC_PORT=$(strFixC "$RPC_PORT" 11)  
    PRT_GRPC_PORT=$(strFixC "$GRPC_PORT" 12)
    PRT_PRTH_PORT=$(strFixC "$PRTH_PORT" 14)
    PRT_INEX_PORT=$(strFixC "$INEX_PORT" 14)

    set +x && printf "\033c" && clear && setterm -cursor off
    echoC ";whi" " =============================================================================="
 echoC "sto;whi" "|$(echoC "res;gre" "$(strFixC "PORTS MAPPING & NETWORKING CONFIGURATOR, KM $KIRA_SETUP_VER" 78)")|"
 echoC "sto;whi" "|$(echoC "res;bla" "$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 78 "." "-")")|"
    echoC ";whi" "| SSH PORT  | P2P PORT  | RPC PORT  | GRPC PORT  |  PROMETHEUS  | INTERX (API) |"
    echoC ";whi" "|$PRT_SSH_PORT|$PRT_P2P_PORT|$PRT_RPC_PORT|$PRT_GRPC_PORT|$PRT_PRTH_PORT|$PRT_INEX_PORT|"
    echoC "sto;whi" "|$(echoC "res;bla" "$(strFixC " DEFAULT PORTS " 78 "." "-")")|"
    echoC ";whi" "|$(echoC "res;bla" "$PRT_SSH_PORT_DEF|$PRT_P2P_PORT_DEF|$PRT_RPC_PORT_DEF|$PRT_GRPC_PORT_DEF|$PRT_PRTH_PORT_DEF|$PRT_INEX_PORT_DEF")|"
    echoC "sto;whi" "|$(echoC "res;bla" "------------------------------------------------------------------------------")|"
    echoC "sto;whi" "|$(strFixL " Docker Network: $DOCKER_NETWORK" 35)| $(echoC "sto;bla" "$(strFixL "   default - $DEFAULT_DOCKER_NETWORK" 40)") |"
    echoC "sto;whi" "|$(strFixL "  Docker Subnet: $DOCKER_SUBNET" 35)| $(echoC "sto;bla" "$(strFixL "   default - $DEFAULT_DOCKER_SUBNET" 40)") |"
    echoC "sto;whi" "|$(strFixL " Net. Interface: $IFACE" 35)| $(echoC "sto;bla" "$(strFixL "   default - $IFACE_DEF" 40)") |"
    echoC "sto;whi" "|$(echoC "res;bla" "------------------------------------------------------------------------------")|"
    echoC "sto;whi" "| $(echoC "res;gre" "$(strFixL "[S] Save changes" 76)") |"
    echoC ";whi" "| $(strFixL "[R] Reject changes and try again" 76) |"
    echoC ";whi" "| [X] Exit ____________________________________________________________________|"
    setterm -cursor off && pressToContinue s r x && setterm -cursor on

    if [ "$(globGet OPTION)" == "s" ] ; then
        globSet DEFAULT_SSH_PORT "$SSH_PORT"
        globSet CUSTOM_P2P_PORT "$P2P_PORT"
        globSet CUSTOM_RPC_PORT "$RPC_PORT"
        globSet CUSTOM_GRPC_PORT "$GRPC_PORT"
        globSet CUSTOM_PROMETHEUS_PORT "$PRTH_PORT"
        globSet CUSTOM_INTERX_PORT "$INEX_PORT"
        globSet KIRA_DOCKER_SUBNET "$DOCKER_SUBNET"
        globSet KIRA_DOCKER_NETWORK "$DOCKER_NETWORK"
        globSet IFACE "$IFACE"

        MTU=$(cat /sys/class/net/$(globGet IFACE)/mtu || echo "1500")
        (! $(isNaturalNumber $MTU)) && MTU=1500
        (($MTU < 100)) && MTU=900
        globSet MTU $MTU
    elif [ "$(globGet OPTION)" == "r" ] ; then
      continue
    else
        break
    fi
done