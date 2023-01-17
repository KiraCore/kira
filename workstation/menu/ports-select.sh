#!/usr/bin/env bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/ports-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

while : ; do
    # load latest values
    set +x
    clear

    INFRA_MODE="$(globGet INFRA_MODE)"
    SSH_PORT="$(globGet DEFAULT_SSH_PORT)"
    P2P_PORT="$(globGet CUSTOM_P2P_PORT)"
    RPC_PORT="$(globGet CUSTOM_RPC_PORT)"
    GRPC_PORT="$(globGet CUSTOM_GRPC_PORT)"
    PRTH_PORT="$(globGet CUSTOM_PROMETHEUS_PORT)"
    INEX_PORT="$(globGet CUSTOM_INTERX_PORT)"

    P2P_PORT_DEF="$(globGet "KIRA_${INFRA_MODE}_P2P_PORT")"
    RPC_PORT_DEF="$(globGet "KIRA_${INFRA_MODE}_RPC_PORT")"
    GRPC_PORT_DEF="$(globGet "KIRA_${INFRA_MODE}_GRPC_PORT")"
    PRTH_PORT_DEF="$(globGet "KIRA_${INFRA_MODE}_PROMETHEUS_PORT")"
    INEX_PORT_DEF="$(globGet "DEFAULT_INTERX_PORT")"

    DOCKER_SUBNET="$(globGet KIRA_DOCKER_SUBNET)"
    DOCKER_NETWORK="$(globGet KIRA_DOCKER_NETWORK)"
    DEFAULT_DOCKER_SUBNET="$(globGet DEFAULT_DOCKER_SUBNET)"
    DEFAULT_DOCKER_NETWORK="$(globGet DEFAULT_DOCKER_NETWORK)"

    FIREWALL_ENABLED="$(globGet FIREWALL_ENABLED)"

    echoC ";whi;" "===================================================="
    echoC ";whi;" "|$(strFixC "PORTS & LOCAL SUBNET CONFIGURATION, KM $KIRA_SETUP_VER" 50)|"
    echoC ";whi;" "|$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 50 "." "-")|"
    echoC ";whi;" "|      NAME      |      VALUE     |    DEFAULT     |"
    [ "$FIREWALL_ENABLED" == "true" ] && \
      echoC "sto;whi" "|$(echoC "res;gre" $(strFixC " FIREWALL ENABLED " 50 "." "-"))|" || \
      echoC "sto;whi" "|$(echoC "res;red" $(strFixC " FIREWALL DISABLED " 50 "." "-"))|"
    echoC ";whi;" "|  Docker Network:$(strFixC "$DOCKER_NETWORK" 16)|$(strFixC "$DEFAULT_DOCKER_NETWORK" 16)|"
    echoC ";whi;" "|   Docker Subnet:$(strFixC "$DOCKER_SUBNET" 16)|$(strFixC "$DEFAULT_DOCKER_SUBNET" 16)|"
    echoC ";whi;" "|        SSH Port:$(strFixC "$SSH_PORT" 16)|$(strFixC "$SSH_PORT" 16)|"
    echoC ";whi;" "|        P2P Port:$(strFixC "$P2P_PORT" 16)|$(strFixC "$P2P_PORT_DEF" 16)|"
    echoC ";whi;" "|        RPC Port:$(strFixC "$RPC_PORT" 16)|$(strFixC "$RPC_PORT_DEF" 16)|"
    echoC ";whi;" "|       GRPC Port:$(strFixC "$GRPC_PORT" 16)|$(strFixC "$GRPC_PORT_DEF" 16)|"
    echoC ";whi;" "|     INTERX Port:$(strFixC "$INEX_PORT" 16)|$(strFixC "$INEX_PORT_DEF" 16)|"
    echoC ";whi;" "| PROMETHEUS Port:$(strFixC "$PRTH_PORT" 16)|$(strFixC "$PRTH_PORT_DEF" 16)|"
    echoC ";whi;" "----------------------------------------------------"
    [ "$FIREWALL_ENABLED" == "true" ] && \
    echoC ";whi;" "| [F] Disable Firewall Rules Enforcing             |" || \
    echoC ";whi;" "| [F] Enable Firewall Rules Enforcing              |" 
    echoC ";whi;" "| [M] Modify individual configurations             |"
    echoC ";whi;" "| [O] Batch-offset ports from defaults (excl. SSH) |"
    echoC ";whi;" "| [X] Exit without making changes                  |"
    echoC ";whi;" "----------------------------------------------------"
    echoNErr "Input option: " && pressToContinue f m o x OPTION
    if [ "$(globGet OPTION)" == "x" ] ; then
        break
    if [ "$(globGet OPTION)" == "f" ] ; then
        [ "$FIREWALL_ENABLED" == "true" ] && globSet FIREWALL_ENABLED "false" || globSet FIREWALL_ENABLED "true"
        continue
    elif [ "$(globGet OPTION)" == "o" ] ; then
      OFFSET="." && while (! $(isNaturalNumber "$OFFSET")) || [[ $OFFSET -gt 64 ]] ; do echoNErr "Input offset value between 0 and 64: " && read OFFSET ; done
      # Do NOT offset SSH port
      SSH_PORT=$((SSH_PORT + 0))
      P2P_PORT=$((P2P_PORT_DEF + OFFSET))
      RPC_PORT=$((RPC_PORT_DEF + OFFSET))
      GRPC_PORT=$((GRPC_PORT_DEF + OFFSET))
      PRTH_PORT=$((PRTH_PORT_DEF + OFFSET))
      INEX_PORT=$((INEX_PORT_DEF + OFFSET))
      if [[ $OFFSET -gt 1 ]] ; then
        DOCKER_SUBNET="10.$((1 + OFFSET)).0.0/16"
        DOCKER_NETWORK="kiranet$((1 + OFFSET))"
      fi
    elif [ "$(globGet OPTION)" == "m" ] ; then
      # NETWORK
      echoInfo "INFO: Default Docker network name: $DEFAULT_DOCKER_NETWORK"
      NAME="." && while [[ $(strLength "$NAME") -lt 3 ]] && [ ! -z "$NAME" ]; do echoNErr "Input new name (min 3 char.) or press [ENTER] for default: " && read NAME ; done
      NAME="$(delWhitespaces $(toLower "$NAME"))"
      [ -z "$NAME" ] && NAME="$DEFAULT_DOCKER_NETWORK"
      DOCKER_NETWORK="$NAME"
      # SUBNET
      echoInfo "INFO: Default Docker subnet: $DEFAULT_DOCKER_SUBNET"
      SUBNET="." && while [[ $(strLength "$SUBNET") -lt 3 ]] && [ ! -z "$SUBNET" ]; do echoNErr "Input valid CIDR or press [ENTER] for default: " && read SUBNET ; done
      [ -z "$SUBNET" ] && SUBNET="$DEFAULT_DOCKER_SUBNET"
      DOCKER_SUBNET="$SUBNET"
      # NOTE: By adding 0 we cut the whitespaces ans ensure value is a valid
      echoInfo "INFO: Default SSH port number: $SSH_PORT"
      PORT="." && while (! $(isPort "$PORT")) && [ ! -z "$PORT" ]; do echoNErr "Input SSH port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && SSH_PORT=$((PORT + 0)) || SSH_PORT=$((SSH_PORT + 0))
      # P2P
      echoInfo "INFO: Default P2P port number: $P2P_PORT"
      PORT="." && while (! $(isPort "$PORT")) && [ ! -z "$PORT" ]; do echoNErr "Input P2P port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && P2P_PORT=$((PORT + 0)) || P2P_PORT=$((P2P_PORT + 0))
      # RPC
      echoInfo "INFO: Default RPC port number: $RPC_PORT"
      PORT="." && while (! $(isPort "$PORT")) && [ ! -z "$PORT" ]; do echoNErr "Input RPC port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && RPC_PORT=$((PORT + 0)) || RPC_PORT=$((RPC_PORT + 0))
      # GRPC
      echoInfo "INFO: Default GRPC port number: $GRPC_PORT"
      PORT="." && while (! $(isPort "$PORT")) && [ ! -z "$PORT" ]; do echoNErr "Input GRPC port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && GRPC_PORT=$((PORT + 0)) || GRPC_PORT=$((GRPC_PORT + 0))
      # PROMETHEUS
      echoInfo "INFO: Default PROMETHEUS port number: $PRTH_PORT"
      PORT="." && while (! $(isPort "$PORT")) && [ ! -z "$PORT" ]; do echoNErr "Input PROMETHEUS port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && PRTH_PORT=$((PORT + 0)) || PRTH_PORT=$((PRTH_PORT + 0))
      # INTERX
      echoInfo "INFO: Default INTERX port number: $INEX_PORT"
      PORT="." && while (! $(isPort "$PORT")) && [ ! -z "$PORT" ]; do echoNErr "Input INTERX port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && INEX_PORT=$((PORT + 0)) || INEX_PORT=$((INEX_PORT + 0))
    fi

    clear
    echoC ";whi;" "===================================================="
    echoC ";whi;" "|$(strFixC "PORTS & LOCAL SUBNET CONFIGURATION, KM $KIRA_SETUP_VER" 50)|"
    echoC ";whi;" "|$(strFixC " $(date '+%d/%m/%Y %H:%M:%S') " 50 "." "-")|"
    echoC ";whi;" "|      NAME      |   NEW VALUES   |    DEFAULT     |"
    echoC ";whi;" "|--------------------------------------------------|"
    echoC ";whi;" "|  Docker Network:$(strFixC "$DOCKER_NETWORK" 16)|$(strFixC "$DEFAULT_DOCKER_NETWORK" 16)|"
    echoC ";whi;" "|   Docker Subnet:$(strFixC "$DOCKER_SUBNET" 16)|$(strFixC "$DEFAULT_DOCKER_SUBNET" 16)|"
    echoC ";whi;" "|        SSH Port:$(strFixC "$SSH_PORT" 16)|$(strFixC "$SSH_PORT" 16)|"
    echoC ";whi;" "|        P2P Port:$(strFixC "$P2P_PORT" 16)|$(strFixC "$P2P_PORT_DEF" 16)|"
    echoC ";whi;" "|        RPC Port:$(strFixC "$RPC_PORT" 16)|$(strFixC "$RPC_PORT_DEF" 16)|"
    echoC ";whi;" "|       GRPC Port:$(strFixC "$GRPC_PORT" 16)|$(strFixC "$GRPC_PORT_DEF" 16)|"
    echoC ";whi;" "|     INTERX Port:$(strFixC "$INEX_PORT" 16)|$(strFixC "$INEX_PORT_DEF" 16)|"
    echoC ";whi;" "| PROMETHEUS Port:$(strFixC "$PRTH_PORT" 16)|$(strFixC "$PRTH_PORT_DEF" 16)|"
    echoC ";whi;" "----------------------------------------------------"
    echoC ";whi;" "| [S] Save changes                                 |"
    echoC ";whi;" "| [X] Exit without making changes                  |"
    echoC ";whi;" "----------------------------------------------------"
    echoNErr "Input option: " && pressToContinue s x OPTION

    if [ "$(globGet OPTION)" == "s" ] ; then
        globSet DEFAULT_SSH_PORT "$SSH_PORT"
        globSet CUSTOM_P2P_PORT "$P2P_PORT"
        globSet CUSTOM_RPC_PORT "$RPC_PORT"
        globSet CUSTOM_GRPC_PORT "$GRPC_PORT"
        globSet CUSTOM_PROMETHEUS_PORT "$PRTH_PORT"
        globSet CUSTOM_INTERX_PORT "$INEX_PORT"
        globSet KIRA_DOCKER_SUBNET "$DOCKER_SUBNET"
        globSet KIRA_DOCKER_NETWORK "$DOCKER_NETWORK"
    else
        break
    fi
done