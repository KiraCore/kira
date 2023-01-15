#!/usr/bin/env bash
ETC_PROFILE="/etc/profile" && set +e && source $ETC_PROFILE &>/dev/null && set -e

if [ "$(globGet INFRA_MODE)" == "seed" ]; then
  title="Seed Mode"
elif [ "$(globGet INFRA_MODE)" == "sentry" ]; then
  title="Sentry Mode"
elif [ "$(globGet INFRA_MODE)" == "validator" ]; then
  title="Validator Mode"
else
  echoErr "ERROR: Unknown operation mode"
  exit 1
fi

systemctl stop kirascan || echoWarn "WARNING: KIRA scan service could NOT be stopped"
systemctl stop kiraup || echoWarn "WARNING: KIRA update service could NOT be stopped"
systemctl stop kiraplan || echoWarn "WARNING: KIRA upgrade service could NOT be stopped"
systemctl stop kiraclean || echoWarn "WARNING: KIRA cleanup service could NOT be stopped"
sleep 1

timedatectl set-timezone "Etc/UTC" || ( echoErr "ERROR: Failed to set time zone to UTC, ensure to do that manually after setup is finalized!" && sleep 10 )

[ -z "$(globGet IFACE)" ] && globSet IFACE "$(netstat -rn | grep -m 1 UG | awk '{print $8}' | xargs)"
[ -z "$(globGet PORTS_EXPOSURE)" ] && globSet PORTS_EXPOSURE "enabled"


MNEMONICS="$KIRA_SECRETS/mnemonics.env" && touch $MNEMONICS
set +x
source $MNEMONICS

while (! $(isMnemonic "$MASTER_MNEMONIC")) ; do
    echoInfo "INFO: Private key store location: '$MNEMONICS'"
    echoWarn "WARNING: Master mnemonic is invalid or was NOT found within the key store"
    echoNErr "Input minimum of 24 whitespace-separated bip39 seed words or press [ENTER] to autogenerate: " && read MASTER_MNEMONIC
    MASTER_MNEMONIC=$(echo "$MASTER_MNEMONIC" | xargs 2> /dev/null || echo -n "")
    MASTER_MNEMONIC=$(echo ${MASTER_MNEMONIC//,/ })

    if [ -z "$MASTER_MNEMONIC" ] ; then
      echoInfo "INFO: Master mnemonic will be auto-generated during setup"
      MASTER_MNEMONIC="autogen"
    elif ($(isMnemonic "$MASTER_MNEMONIC")) ; then
      echoInfo "INFO: Master mnemonic is valid and will be saved to keystore"
    else
      echoErr "ERROR: Invalid Bip39 seed words sequence"
      continue
    fi

    setVar MASTER_MNEMONIC "$MASTER_MNEMONIC" "$MNEMONICS" 1> /dev/null
    break
done

echo "INFO: Loading secrets..."
set +e
set +x
source $KIRAMGR_SCRIPTS/load-secrets.sh
set -x
set -e

NEW_NETWORK="false"
if [ "$(globGet INFRA_MODE)" == "validator" ]; then
    set +x
    echoNErr "Create [N]ew network or [J]oin existing one: " && pressToContinue n j
    set -x
    [ "$(globGet OPTION)" == "n" ] && NEW_NETWORK="true" || NEW_NETWORK="false"
fi

globSet NEW_BASE_IMAGE_SRC "$(globGet BASE_IMAGE_SRC)"
globSet NEW_NETWORK "$NEW_NETWORK"
[ "$(globGet NEW_NETWORK)" == "true" ] && $KIRA_MANAGER/menu/chain-id-select.sh
[ -z "$(globGet SNAPSHOT_EXECUTE)" ] && globSet SNAPSHOT_EXECUTE "true"

PRIVATE_MODE=$(globGet PRIVATE_MODE) && (! $(isBoolean "$PRIVATE_MODE")) && PRIVATE_MODE="false" && globSet PRIVATE_MODE "$PRIVATE_MODE"

while :; do
    loadGlobEnvs
    set +x
    printf "\033c"

    SSH_PORT=$(strFixC "$(globGet DEFAULT_SSH_PORT)" 7)
    P2P_PORT=$(strFixC "$(globGet CUSTOM_P2P_PORT)" 7)
    RPC_PORT=$(strFixC "$(globGet CUSTOM_RPC_PORT)" 7)
    GRPC_PORT=$(strFixC "$(globGet CUSTOM_GRPC_PORT)" 7)
    PRTH_PORT=$(strFixC "$(globGet CUSTOM_PROMETHEUS_PORT)" 7)
    INEX_PORT=$(strFixC "$(globGet CUSTOM_INTERX_PORT)" 7)

    printWidth=47
    echo -e "\e[31;1m-------------------------------------------------"
    displayAlign center $printWidth "$title $KIRA_SETUP_VER"
    displayAlign center $printWidth "$(date '+%d/%m/%Y %H:%M:%S')"
    echo -e "|-----------------------------------------------|"
    echo -e "|  SSH  |  P2P  |  RPC  | GRPC  | PROM. | INT.X |"
    echo -e "|$SSH_PORT|$P2P_PORT|$RPC_PORT|$GRPC_PORT|$PRTH_PORT|$INEX_PORT|"
    echo -e "|-----------------------------------------------|"
    echo -e "|       Network Interface: $(globGet IFACE) (default)"
    echo -e "|            Privacy Mode: ${PRIVATE_MODE^^}"
    echo -e "|  NEW Network Deployment: $(globGet NEW_NETWORK)"
    [ "$(globGet NEW_NETWORK)" == "true" ] && \
    echo -e "|        NEW Network Name: $(globGet NEW_NETWORK_NAME)"
    echo -e "|       Secrets Direcotry: $KIRA_SECRETS"
    echo -e "|     Snapshots Direcotry: $KIRA_SNAP"
    echo -e "|       Snapshots Enabled: $(globGet SNAPSHOT_EXECUTE)"
    [ "$(globGet NEW_NETWORK)" != "true" ] && [ -f "$KIRA_SNAP_PATH" ] && \
    echo -e "| Latest (local) Snapshot: $KIRA_SNAP_PATH"
    echo -e "|       Base Image Source: $(strFixL "$(globGet NEW_BASE_IMAGE_SRC)" 21)"
    echo -e "|-----------------------------------------------|"
    displayAlign left $printWidth " [1] | Change Default Network Interface"
    displayAlign left $printWidth " [2] | Change Default Port Configuration"
    displayAlign left $printWidth " [3] | Change Base Image URL"
    displayAlign left $printWidth " [4] | Change Node Type (sentry/seed/validator)"
    displayAlign left $printWidth " [5] | Change Network Exposure (local/public)"
    displayAlign left $printWidth " [6] | Change Snapshots Configuration"
    echo "|-----------------------------------------------|"
    displayAlign left $printWidth " [S] | Start Node Setup"
    displayAlign left $printWidth " [X] | Exit"
    echo -e "-------------------------------------------------\e[0m\c\n"
    echo ""
    FAILED="false"
  
    echoErr "Input option: " && pressToContinue 1 2 3 4 5 6 s x && KEY=$(globGet OPTION) && echo ""

  case ${KEY,,} in
  s*)
    echo "INFO: Starting Quick Setup..."
    echo "NETWORK interface: $(globGet IFACE)"
    setGlobEnv KIRA_SNAP_PATH ""
    globSet BASE_IMAGE_SRC "$(globGet NEW_BASE_IMAGE_SRC)"

    if [ "$(globGet INFRA_MODE)" == "validator" ] || [ "$(globGet INFRA_MODE)" == "sentry" ] || [ "$(globGet INFRA_MODE)" == "seed" ] ; then
        $KIRA_MANAGER/menu/quick-select.sh
    else
        echoErr "ERROR: Unknown infra mode '$(globGet INFRA_MODE)'"
        sleep 10
        continue
    fi
    break
    ;;
  1*)
    $KIRA_MANAGER/menu/interface-select.sh
    continue
    ;;
  2*)
    clear
    echoErr "Choose to modify each [I]ndividual port, [O]ffset all except SSH by fixed number or e[X]it." && pressToContinue e i x OPTION
    [ "$(globGet OPTION)" == "x" ] && continue
    if [ "$(globGet OPTION)" == "o" ] ; then
      OFFSET="." && while (! $(isNaturalNumber "$OFFSET")) || [[ $OFFSET -gt 1000 ]] ; do echoNErr "Input offset value between 0 and 1000: " && read OFFSET ; done
      SSH_PORT=$(strFixC "$(globGet DEFAULT_SSH_PORT)" 7)
      P2P_PORT=$(strFixC "$(globGet CUSTOM_P2P_PORT)" 7)
      RPC_PORT=$(strFixC "$(globGet CUSTOM_RPC_PORT)" 7)
      GRPC_PORT=$(strFixC "$(globGet CUSTOM_GRPC_PORT)" 7)
      PRTH_PORT=$(strFixC "$(globGet CUSTOM_PROMETHEUS_PORT)" 7)
      INEX_PORT=$(strFixC "$(globGet CUSTOM_INTERX_PORT)" 7)
    elif [ "$(globGet OPTION)" == "e" ] ; then 
      # SSH
      echoInfo "INFO: Default SSH port number: $SSH_PORT"
      PORT="." && while (! $(isPort "$PORT")) || [ -z "$PORT" ]; do echoNErr "Input SSH port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && SSH_PORT=$PORT
      # P2P
      echoInfo "INFO: Default P2P port number: $P2P_PORT"
      PORT="." && while (! $(isPort "$PORT")) || [ -z "$PORT" ]; do echoNErr "Input P2P port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && P2P_PORT=$PORT
      # RPC
      echoInfo "INFO: Default RPC port number: $RPC_PORT"
      PORT="." && while (! $(isPort "$PORT")) || [ -z "$PORT" ]; do echoNErr "Input RPC port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && RPC_PORT=$PORT
      # GRPC
      echoInfo "INFO: Default GRPC port number: $GRPC_PORT"
      PORT="." && while (! $(isPort "$PORT")) || [ -z "$PORT" ]; do echoNErr "Input GRPC port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && GRPC_PORT=$PORT
      # PROMETHEUS
      echoInfo "INFO: Default PROMETHEUS port number: $PRTH_PORT"
      PORT="." && while (! $(isPort "$PORT")) || [ -z "$PORT" ]; do echoNErr "Input PROMETHEUS port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && PRTH_PORT=$PORT
      # INTERX
      echoInfo "INFO: Default INTERX port number: $INEX_PORT"
      PORT="." && while (! $(isPort "$PORT")) || [ -z "$PORT" ]; do echoNErr "Input INTERX port number or press [ENTER] for default: " && read PORT ; done
      [ ! -z "$PORT" ] && INEX_PORT=$PORT
    fi
    set -x
    globSet DEFAULT_SSH_PORT "$SSH_PORT"
    globSet CUSTOM_P2P_PORT "$P2P_PORT"
    globSet CUSTOM_RPC_PORT "$RPC_PORT"
    globSet CUSTOM_GRPC_PORT "$GRPC_PORT"
    globSet CUSTOM_PROMETHEUS_PORT "$PRTH_PORT"
    globSet CUSTOM_INTERX_PORT "$INEX_PORT"
    continue
    ;;
  3*)
    $KIRA_MANAGER/menu/base-image-select.sh
    continue
    ;;
  4*)
    $KIRA_MANAGER/menu/menu.sh "false"
    exit 0
    ;;
  5*)
    set +x
    echoWarn "WARNING: Nodes launched in the private mode can only communicate via P2P with other nodes deployed in their local/private network"
    echoNErr "Launch $(globGet INFRA_MODE) node in [P]ublic or Pri[V]ate networking mode: " && pressToContinue p v && MODE=$(globGet OPTION)
    set -x

    [ "${MODE,,}" == "p" ] && globSet PRIVATE_MODE "false"
    [ "${MODE,,}" == "v" ] && globSet PRIVATE_MODE "true"
    ;;
  6*)
    $KIRA_MANAGER/kira/kira-backup.sh
    continue
    ;;
  x*)
    exit 0
    ;;
  *)
    echo "Try again."
    sleep 1
    ;;
  esac
done
set -x

globDel "ESSENAILS_UPDATED_$KIRA_SETUP_VER" "CLEANUPS_UPDATED_$KIRA_SETUP_VER" "CONTAINERS_UPDATED_$KIRA_SETUP_VER" UPGRADE_PLAN
globDel "sentry_SEKAID_STATUS" "validator_SEKAID_STATUS" "seed_SEKAID_STATUS" "interx_SEKAID_STATUS"
globDel VALIDATOR_ADDR UPDATE_FAIL_COUNTER SETUP_END_DT UPDATE_CONTAINERS_LOG UPDATE_CLEANUP_LOG UPDATE_TOOLS_LOG LATEST_STATUS SNAPSHOT_TARGET
[ -z "$(globGet SNAP_EXPOSE)" ] && globSet SNAP_EXPOSE "true"
[ -z "$(globGet SNAPSHOT_KEEP_OLD)" ] && globSet SNAPSHOT_KEEP_OLD "true"
globSet UPDATE_DONE "false"
globSet UPDATE_FAIL "false"
globSet SYSTEM_REBOOT "false"

SETUP_START_DT="$(date +'%Y-%m-%d %H:%M:%S')"
globSet SETUP_START_DT "$SETUP_START_DT"
globSet PORTS_EXPOSURE "enabled"

rm -fv $(globFile validator_SEKAID_STATUS) $(globFile sentry_SEKAID_STATUS) 
rm -fv $(globFile seed_SEKAID_STATUS) $(globFile interx_SEKAID_STATUS)

globDel UPGRADE_INSTATE
globSet UPGRADE_DONE "true"
globSet UPGRADE_TIME "$(date2unix $(date))"
globSet AUTO_UPGRADES "true"
globSet PLAN_DONE "true"
globSet PLAN_FAIL "false"
globSet PLAN_FAIL_COUNT "0"
globSet PLAN_START_DT "$(date +'%Y-%m-%d %H:%M:%S')"
globSet PLAN_END_DT "$(date +'%Y-%m-%d %H:%M:%S')"

mkdir -p $KIRA_LOGS
echo -n "" > $KIRA_LOGS/kiraup.log || echoWarn "WARNING: Failed to wipe '$KIRA_LOGS/kiraup.log'"
echo -n "" > $KIRA_LOGS/kiraplan.log || echoWarn "WARNING: Failed to wipe '$KIRA_LOGS/kiraplan.log'"

$KIRA_MANAGER/setup/services.sh
systemctl daemon-reload
systemctl enable kiraup
systemctl enable kiraplan
systemctl start kiraup
systemctl stop kiraplan || echoWarn "WARNING: Failed to stop KIRA Plan!"
systemctl restart systemd-journald

echoInfo "INFO: Starting install logs preview, to exit type Ctrl+c"
sleep 2

if [ "$(isServiceActive kiraup)" == "true" ] ; then
  cat $KIRA_LOGS/kiraup.log
else
  systemctl status kiraup
  echoErr "ERROR: Failed to launch kiraup service!"
  exit 1
fi

$KIRA_MANAGER/kira/kira.sh

exit 0
