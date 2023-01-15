#!/usr/bin/env bash
set +x
set +e && source "/etc/profile" &>/dev/null && set -e
# quick edit: FILE="$KIRA_MANAGER/menu/ports-select.sh" && rm $FILE && nano $FILE && chmod 555 $FILE

while : ; do
    # load latest values
    set +x
    clear
    SSH_PORT="$(globGet DEFAULT_SSH_PORT)"
    P2P_PORT="$(globGet CUSTOM_P2P_PORT)"
    RPC_PORT="$(globGet CUSTOM_RPC_PORT)"
    GRPC_PORT="$(globGet CUSTOM_GRPC_PORT)"
    PRTH_PORT="$(globGet CUSTOM_PROMETHEUS_PORT)"
    INEX_PORT="$(globGet CUSTOM_INTERX_PORT)"

    echoWarn "Please review youur current ports configuration"
    echoInfo "         SSH: $SSH_PORT"
    echoInfo "         P2P: $P2P_PORT"
    echoInfo "         RPC: $RPC_PORT"
    echoInfo "        GRPC: $GRPC_PORT"
    echoInfo "      INTERX: $INEX_PORT"
    echoInfo "  PROMETHEUS: $PRTH_PORT"
    echoNErr "Choose to modify each [I]ndividual port, [O]ffset all except SSH by fixed number or e[X]it: " && pressToContinue i o x OPTION
    if [ "$(globGet OPTION)" == "x" ] ; then
        break
    elif [ "$(globGet OPTION)" == "o" ] ; then
      OFFSET="." && while (! $(isNaturalNumber "$OFFSET")) || [[ $OFFSET -gt 1000 ]] ; do echoNErr "Input offset value between 0 and 1000: " && read OFFSET ; done
      # Do NOT offset SSH port
      SSH_PORT=$((SSH_PORT + 0))
      P2P_PORT=$((P2P_PORT + OFFSET))
      RPC_PORT=$((RPC_PORT + OFFSET))
      GRPC_PORT=$((GRPC_PORT + OFFSET))
      PRTH_PORT=$((PRTH_PORT + OFFSET))
      INEX_PORT=$((INEX_PORT + OFFSET))
    elif [ "$(globGet OPTION)" == "i" ] ; then 
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
    echoWarn "Please review port configuration changes"
    echoInfo "         SSH: $SSH_PORT"
    echoInfo "         P2P: $P2P_PORT"
    echoInfo "         RPC: $RPC_PORT"
    echoInfo "        GRPC: $GRPC_PORT"
    echoInfo "      INTERX: $INEX_PORT"
    echoInfo "  PROMETHEUS: $PRTH_PORT"
    echoNErr "Press [Y]es to approve changes or [N]o to cancel: " && pressToContinue y n OPTION
    if [ "$(globGet OPTION)" == "y" ] ; then
        globSet DEFAULT_SSH_PORT "$SSH_PORT"
        globSet CUSTOM_P2P_PORT "$P2P_PORT"
        globSet CUSTOM_RPC_PORT "$RPC_PORT"
        globSet CUSTOM_GRPC_PORT "$GRPC_PORT"
        globSet CUSTOM_PROMETHEUS_PORT "$PRTH_PORT"
        globSet CUSTOM_INTERX_PORT "$INEX_PORT"
        break
    fi
done